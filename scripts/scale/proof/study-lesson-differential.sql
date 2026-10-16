-- study_lesson before and after a migration (2026-10-17): for every sampled
-- person, every lesson published (in any state) to a class they are
-- related to in any way (taught, enrolled, a linked child's, current or
-- not), a share of the lessons of every school they have any membership
-- in, and lessons of schools they have nothing to do with, the same answer
-- as that person: the same lesson, version, class, title and body, or null
-- for both. Signed out and unknown callers too. In one transaction, rolled
-- back.
--
-- psql -v migration=<file> -v sample=<N> [-v resource_every=<M>]
--   [-v pre1=<file>] [-v plant=plant-study-lesson.sql]
--   -f study-lesson-differential.sql <db>
-- pre1: applied before "before" is recorded (on the pgTAP fixtures, which
-- already have the migration, the original definition).
\set ON_ERROR_STOP on
\pset pager off
\if :{?resource_every} \else \set resource_every 10 \endif
begin;
set local statement_timeout = 0;
\if :{?pre1}
\i :pre1
\endif
\if :{?plant}
\i :plant
\endif

create temp table subjects as
select u.id as uid from auth.users u
where (abs(hashtext(u.id::text)) % :sample) = 0
union
select m.user_id from public.memberships m
where m.role = 'school_admin' and (abs(hashtext(m.user_id::text)) % greatest(:sample / 100, 1)) = 0;

create temp table pairs as
select distinct s.uid, x.rid, x.relation
from subjects s
cross join lateral (
  -- Lessons published, in any state, to a class related to the person.
  select rv.resource_id as rid, 'class'::text as relation
  from (
    select cs.classroom_id from public.classroom_staff cs where cs.user_id = s.uid
    union select e.classroom_id from public.enrollments e
      join public.students st on st.id = e.student_id where st.user_id = s.uid
    union select e.classroom_id from public.enrollments e
      join public.guardian_links gl on gl.student_id = e.student_id where gl.guardian_id = s.uid
  ) c
  join public.resource_publications rp on rp.classroom_id = c.classroom_id
  join public.resource_versions rv on rv.id = rp.resource_version_id
  union all
  -- A share of every school they hold any membership in.
  select r.id, 'school'
  from (select distinct m.school_id from public.memberships m where m.user_id = s.uid) m
  join public.resources r on r.school_id = m.school_id
  where abs(hashtext(r.id::text || s.uid::text)) % :resource_every = 0
  union all
  -- Lessons of other schools.
  (select r.id, 'elsewhere'
   from public.resources r
   where not exists (select 1 from public.memberships m
     where m.user_id = s.uid and m.school_id = r.school_id)
   order by md5(r.id::text || s.uid::text) limit 5)
) x;
-- Signed out and an unknown person, on a few lessons each.
insert into pairs
select null::uuid, r.id, 'signed-out' from public.resources r order by md5(r.id::text) limit 50;
insert into pairs
select '00000000-0000-4000-8000-00000000dead'::uuid, r.id, 'unknown'
from public.resources r order by md5(r.id::text) limit 50;
create index on pairs (uid);

create function pg_temp.record(p_uid uuid)
returns table (rid uuid, answer jsonb) language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', coalesce(p_uid::text, ''), true);
  return query select p.rid, private.study_lesson(p.rid)
    from (select distinct x.rid from pairs x where x.uid is not distinct from p_uid) p;
end $$;

create temp table before as
select u.uid, r.rid, r.answer
from (select distinct uid from pairs) u cross join lateral pg_temp.record(u.uid) r;

\if :{?migration}
\i :migration
\endif

create temp table after as
select u.uid, r.rid, r.answer
from (select distinct uid from pairs) u cross join lateral pg_temp.record(u.uid) r;

select count(distinct b.uid) as people, count(*) as calls,
  count(*) filter (where b.answer is not null) as allowed_before,
  count(*) filter (where a.answer is not null) as allowed_after,
  count(*) filter (where a.answer is distinct from b.answer) as differences,
  count(*) filter (where a.rid is null) as missing_after
from before b left join after a on a.uid is not distinct from b.uid and a.rid = b.rid;

-- What the compared calls covered: by relation, by how the person stands
-- in the lesson's school, and by the lesson's state.
with c as (
  select b.uid, b.rid, b.answer, r.school_id,
    (select string_agg(distinct p.relation, '+') from pairs p
      where p.uid is not distinct from b.uid and p.rid = b.rid) as relation,
    exists (select 1 from public.memberships m where m.user_id = b.uid
      and m.school_id = r.school_id and m.role in ('school_admin', 'teacher')) as staff_member,
    exists (select 1 from public.memberships m where m.user_id = b.uid
      and m.school_id = r.school_id and m.role = 'school_admin') as admin_member,
    exists (select 1 from public.guardian_links gl where gl.guardian_id = b.uid) as guardian,
    exists (select 1 from public.students st where st.user_id = b.uid) as student,
    rv.file_object_id is not null as has_file,
    (select count(*) from public.resource_publications rp
      where rp.resource_version_id = rv.id and rp.state = 'published'
        and rp.withdrawn_at is null and rp.classroom_id is not null) as live_publications,
    (select string_agg(distinct rp.audience::text, '+') from public.resource_publications rp
      where rp.resource_version_id = rv.id) as audiences
  from before b
  join public.resources r on r.id = b.rid
  left join public.resource_versions rv on rv.resource_id = r.id and rv.version = r.current_version
)
select relation,
  count(*) as calls, count(*) filter (where answer is not null) as allowed,
  count(*) filter (where staff_member) as staff_calls,
  count(*) filter (where staff_member and answer is not null) as staff_allowed,
  count(*) filter (where admin_member and answer is not null) as admin_allowed,
  count(*) filter (where not staff_member and student and answer is not null) as student_allowed,
  count(*) filter (where not staff_member and guardian and answer is not null) as guardian_allowed,
  count(*) filter (where not staff_member and (student or guardian) and answer is null) as family_denied,
  count(*) filter (where has_file) as with_file,
  count(*) filter (where has_file and answer is not null) as with_file_allowed,
  count(*) filter (where live_publications > 1) as several_publications,
  count(*) filter (where audiences <> 'both') as one_audience
from c group by rollup(relation) order by relation;

rollback;
