-- Zero-difference proof for a list/access migration (capacity fixes,
-- 2026-10-14). In ONE transaction: record every case's answer, apply the
-- migration, record again, compare, roll back. now() is fixed inside a
-- transaction, so time-dependent fields compare fairly.
--
-- psql -v migration=<file> -v sample=<N> -f differential.sql <db>
--   sample: keep users whose id hashes to 0 mod N (1 = every user).
\set ON_ERROR_STOP on
\pset pager off
begin;
set local statement_timeout = 0;
-- Earlier fixes this one builds on, applied before "before" is recorded.
\if :{?pre1}
\i :pre1
\endif
\if :{?pre2}
\i :pre2
\endif
-- Data the synthetic seed lacks, planted for this proof only.
\if :{?plant}
\i :plant
\endif

create temp table subjects as
select u.id as uid from auth.users u
where (abs(hashtext(u.id::text)) % :sample) = 0;

-- Every school the person belongs to, in any membership state, and the
-- tenant-less path (a guardian reading a linked child).
create temp table cases (n bigserial primary key, uid uuid, school uuid, op text, input jsonb);

insert into cases(uid, school, op, input)
select s.uid, m.school_id, op, '{"pageSize":20}'::jsonb
from subjects s
join (select distinct user_id, school_id from public.memberships) m on m.user_id = s.uid
cross join unnest(array['listClassrooms','listLessonSessions','listResources','listAssignments',
  'listAssessments','listGradeResults','listAttendance']) op;

-- Filtered by a class the person is related to (taught, enrolled, a child's).
insert into cases(uid, school, op, input)
select x.uid, x.school_id, op, jsonb_build_object('pageSize', 20, 'classroomId', x.classroom_id)
from (
  select distinct on (s.uid, c.id) s.uid, c.school_id, c.id as classroom_id
  from subjects s
  join lateral (
    select cs.classroom_id from public.classroom_staff cs where cs.user_id = s.uid
    union select e.classroom_id from public.enrollments e
      join public.students st on st.id = e.student_id where st.user_id = s.uid
    union select e.classroom_id from public.enrollments e
      join public.guardian_links gl on gl.student_id = e.student_id where gl.guardian_id = s.uid
    limit 3) rel on true
  join public.classrooms c on c.id = rel.classroom_id
) x
cross join unnest(array['listResources','listAssignments','listAssessments','listGradeResults',
  'listAttendance','listLessonSessions']) op;

-- Filtered by a student the person is, or is linked to; in each school they
-- belong to and on the tenant-less guardian path.
insert into cases(uid, school, op, input)
select x.uid, sch.school_id, op, jsonb_build_object('pageSize', 20, 'studentId', x.student_id)
from (
  select s.uid, st.id as student_id from subjects s
  join public.students st on st.user_id = s.uid
  union
  select s.uid, gl.student_id from subjects s
  join public.guardian_links gl on gl.guardian_id = s.uid
) x
cross join lateral (
  select m.school_id from public.memberships m where m.user_id = x.uid
  union select null::uuid) sch
cross join unnest(array['listAssignments','listAssessments','listResources','listGradeResults','listAttendance']) op;

select count(*) as cases, count(distinct uid) as people from cases \gset
\echo cases :cases people :people

create function pg_temp.run(p_uid uuid, p_school uuid, p_op text, p_input jsonb)
returns jsonb language plpgsql as $$
declare r jsonb; pages jsonb := '[]'; inp jsonb := p_input; i int := 0;
begin
  perform set_config('request.jwt.claim.sub', p_uid::text, true);
  perform set_config('studafy.school_id', coalesce(p_school::text, ''), true);
  loop
    begin
      r := private.api041_query(p_op, coalesce(p_school, (p_input->>'studentId')::uuid), inp);
    exception when others then
      r := jsonb_build_object('error', sqlstate);
    end;
    pages := pages || jsonb_build_array(r);
    i := i + 1;
    exit when i >= 3 or r->>'nextPosition' is null;
    inp := inp || jsonb_build_object('position', r->>'nextPosition');
  end loop;
  return pages;
end $$;

\timing on
create temp table before_out as select n, pg_temp.run(uid, school, op, input) as out from cases;
\timing off

\i :migration

\timing on
create temp table after_out as select n, pg_temp.run(uid, school, op, input) as out from cases;
\timing off

select count(*) as compared,
  count(*) filter (where b.out is distinct from a.out) as differences,
  sum(jsonb_array_length(b.out)) as pages,
  sum((select coalesce(sum(jsonb_array_length(p->'items')), 0)
       from jsonb_array_elements(b.out) p where jsonb_typeof(p->'items') = 'array')) as rows_compared,
  count(*) filter (where b.out::text like '%"error"%') as error_cases
from before_out b join after_out a using (n);

-- What the homework rows compared actually contained.
select count(*) as homework_rows,
  count(*) filter (where jsonb_array_length(i->'links') > 0) as with_links,
  count(*) filter (where jsonb_array_length(i->'attachments') > 0) as with_files,
  count(*) filter (where i ? 'deadlineAt') as with_student_deadline,
  count(*) filter (where jsonb_typeof(i->'extension') = 'object') as with_extension,
  count(*) filter (where i->>'submissionState' = 'closed') as closed,
  count(*) filter (where i->>'submissionState' = 'graded_locked') as graded_locked,
  count(*) filter (where i->>'maximumScore' is not null) as marked,
  count(*) filter (where i->>'closesLocal' is not null) as with_closing
from cases c join before_out b using (n)
cross join lateral jsonb_array_elements(b.out) pg
cross join lateral jsonb_array_elements(case when jsonb_typeof(pg->'items') = 'array' then pg->'items' else '[]' end) i
where c.op = 'listAssignments';

select c.op, c.school is null as tenantless, count(*) as cases,
  count(*) filter (where b.out is distinct from a.out) as differences
from cases c join before_out b using (n) join after_out a using (n)
group by 1, 2 order by 1, 2;

select c.n, c.uid, c.school, c.op, c.input, left(b.out::text, 300) as before, left(a.out::text, 300) as after
from cases c join before_out b using (n) join after_out a using (n)
where b.out is distinct from a.out limit 5;

rollback;
