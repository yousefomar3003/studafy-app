-- Decision-level proof for capacity fix 1: the set-based rules in
-- api041_query_before_notebook give the same answer as is_class_staff,
-- can_view_classroom and can_view_class_student for every class and every
-- enrolment a sampled person could ask about, after planting the edge cases
-- the synthetic data lacks. One transaction, rolled back.
--   psql -v sample=<N> -f access-differential.sql <db>
\set ON_ERROR_STOP on
\pset pager off
begin;
set local statement_timeout = 0;

-- Edge cases, spread deterministically over the data.
update public.enrollments set active = false
  where abs(hashtext(classroom_id::text || student_id::text)) % 37 = 0;
update public.enrollments set status = 'withdrawn'
  where abs(hashtext(classroom_id::text || student_id::text)) % 41 = 1;
update public.enrollments set starts_on = current_date - 30, ends_on = current_date - 1
  where abs(hashtext(classroom_id::text || student_id::text)) % 43 = 2;
update public.enrollments set starts_on = current_date + 5
  where abs(hashtext(classroom_id::text || student_id::text)) % 47 = 3 and ends_on is null;
update public.guardian_links
  set verified_at = case when status = 'verified' then now() - interval '30 days' else verified_at end,
      expires_at = now() - interval '1 day'
  where abs(hashtext(id::text)) % 29 = 0 and (verified_at is null or status = 'verified');
update public.guardian_links set status = 'pending'
  where abs(hashtext(id::text)) % 31 = 1;
update public.memberships set valid_from = now() - interval '30 days',
    valid_until = now() - interval '1 day'
  where abs(hashtext(id::text)) % 53 = 0;
update public.memberships set active = false, status = 'suspended'
  where abs(hashtext(id::text)) % 59 = 1;
update public.classrooms set status = 'archived', archived_at = now()
  where abs(hashtext(id::text)) % 23 = 0;
update public.classroom_staff set starts_at = now() - interval '30 days',
    status = 'ended', ends_at = now() - interval '1 day'
  where abs(hashtext(id::text)) % 19 = 0;
update public.classroom_staff set starts_at = now() + interval '1 day'
  where abs(hashtext(id::text)) % 17 = 1 and status = 'active';
update public.profiles set status = 'suspended'
  where abs(hashtext(id::text)) % 61 = 0;
update public.students set deleted_at = now()
  where abs(hashtext(id::text)) % 67 = 0;
update public.terms set status = 'closed'
  where abs(hashtext(id::text)) % 13 = 0;
-- One school admin per school, for the admin branch.
insert into public.memberships (school_id, user_id, role, active)
select distinct on (m.school_id) m.school_id, m.user_id, 'school_admin', true
from public.memberships m where m.role = 'teacher'
order by m.school_id, m.user_id
on conflict do nothing;

create temp table people as
select u.id as uid from auth.users u where abs(hashtext(u.id::text)) % :sample = 0
union
select m.user_id from public.memberships m where m.role = 'school_admin';

-- The new rules, exactly as written in the migration.
create function pg_temp.new_sets(out staff_all uuid[], out admin_schools uuid[], out own_pairs text[])
language plpgsql as $$
declare v_active boolean := private.is_active_user();
begin
  staff_all := array(
    select cs.classroom_id from public.classroom_staff cs
    join public.memberships m
      on m.id = cs.membership_id and m.school_id = cs.school_id and m.user_id = cs.user_id
    join public.schools s on s.id = cs.school_id
    where v_active and cs.user_id = auth.uid() and cs.status = 'active'
      and cs.starts_at <= now() and (cs.ends_at is null or cs.ends_at > now())
      and m.active and m.status = 'active' and m.valid_from <= now()
      and (m.valid_until is null or m.valid_until > now())
      and m.role in ('teacher', 'school_admin')
      and s.status = 'active' and s.deleted_at is null);
  admin_schools := array(
    select m.school_id from public.memberships m
    join public.schools s on s.id = m.school_id
    where v_active and m.user_id = auth.uid() and m.active and m.status = 'active'
      and m.valid_from <= now() and (m.valid_until is null or m.valid_until > now())
      and s.status = 'active' and s.deleted_at is null
      and m.role = 'school_admin');
  own_pairs := array(
    select e.classroom_id::text || '/' || e.student_id::text
    from public.enrollments e
    join public.students st on st.id = e.student_id and st.school_id = e.school_id
    join public.classrooms c on c.id = e.classroom_id and c.school_id = e.school_id
    join public.terms t on t.id = c.term_id and t.school_id = c.school_id
    where v_active and st.user_id = auth.uid() and st.deleted_at is null
      and e.active and e.status = 'active' and e.starts_on <= current_date
      and (e.ends_on is null or e.ends_on >= current_date)
      and c.status = 'active' and t.status = 'active'
      and private.has_active_membership(e.school_id, array['student']::public.app_role[])
    union
    select e.classroom_id::text || '/' || e.student_id::text
    from public.guardian_links gl
    join public.enrollments e on e.student_id = gl.student_id and e.school_id = gl.school_id
    join public.classrooms c on c.id = e.classroom_id and c.school_id = e.school_id
    join public.terms t on t.id = c.term_id and t.school_id = c.school_id
    where v_active and gl.guardian_id = auth.uid() and gl.status = 'verified'
      and (gl.expires_at is null or gl.expires_at > now())
      and e.active and e.status = 'active' and e.starts_on <= current_date
      and (e.ends_on is null or e.ends_on >= current_date)
      and c.status = 'active' and t.status = 'active'
      and private.has_active_membership(gl.school_id, array['parent', 'guardian']::public.app_role[]));
end $$;

create temp table decisions (uid uuid, kind text, subject text, old boolean, new boolean);

create function pg_temp.check_person(p_uid uuid) returns void language plpgsql as $$
declare ns record;
begin
  perform set_config('request.jwt.claim.sub', p_uid::text, true);
  select * into ns from pg_temp.new_sets();
  -- Every class in every school the person belongs to, or a child attends.
  insert into decisions
  select p_uid, 'is_class_staff', c.id::text, private.is_class_staff(c.id), c.id = any(ns.staff_all)
  from public.classrooms c
  where c.school_id in (select school_id from public.memberships where user_id = p_uid
    union select st.school_id from public.guardian_links gl join public.students st on st.id = gl.student_id
      where gl.guardian_id = p_uid);
  insert into decisions
  select p_uid, 'can_view_classroom', c.id::text, private.can_view_classroom(c.id),
    (c.school_id = any(ns.admin_schools) or c.id = any(ns.staff_all)
      or exists (select 1 from unnest(ns.own_pairs) p where split_part(p, '/', 1) = c.id::text))
  from public.classrooms c
  where c.school_id in (select school_id from public.memberships where user_id = p_uid
    union select st.school_id from public.guardian_links gl join public.students st on st.id = gl.student_id
      where gl.guardian_id = p_uid);
  -- Every enrolment of the person's own and linked students, and of the
  -- classes they are staff of.
  insert into decisions
  select p_uid, 'can_view_class_student', e.classroom_id::text || '/' || e.student_id::text,
    private.can_view_class_student(e.classroom_id, e.student_id),
    (e.active and e.status = 'active' and e.starts_on <= current_date
      and (e.ends_on is null or e.ends_on >= current_date)
      and (e.school_id = any(ns.admin_schools) or e.classroom_id = any(ns.staff_all)
        or (e.classroom_id::text || '/' || e.student_id::text) = any(ns.own_pairs)))
  from public.enrollments e
  where e.student_id in (select st.id from public.students st where st.user_id = p_uid
      union select gl.student_id from public.guardian_links gl where gl.guardian_id = p_uid)
     or e.classroom_id in (select cs.classroom_id from public.classroom_staff cs where cs.user_id = p_uid);
end $$;

\timing on
select count(*) as people from (select pg_temp.check_person(uid) from people) x;
\timing off

select kind, count(*) as decisions, count(*) filter (where old) as yes,
  count(*) filter (where old is distinct from new) as differences
from decisions group by kind order by kind;
select * from decisions where old is distinct from new limit 10;
rollback;
