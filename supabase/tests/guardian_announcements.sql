-- A parent linked by the child's Studafy ID, with no membership, reads the
-- announcements meant for parents (202610050001).
-- Transactional fixtures: everything below rolls back.
begin;
\set auth031_fixture_only true
\ir rls_access_seed.sql
\unset auth031_fixture_only
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select plan(12);

\set school_wide 'a0450000-0000-4000-8000-000000000001'
\set for_students 'a0450000-0000-4000-8000-000000000002'
\set class_parents 'a0450000-0000-4000-8000-000000000003'
\set other_class 'a0450000-0000-4000-8000-000000000004'
\set other_classroom 'a0450000-0000-4000-8000-000000000005'
\set other_school_note 'a0450000-0000-4000-8000-000000000006'

-- The ordinary parent: linked to the child, and no membership at all.
delete from public.memberships where user_id = :'guardian_user';

insert into public.classrooms (id, school_id, term_id, name, grade, section, teacher_id)
values (:'other_classroom', :'school_id', :'term_id', 'Another class', 'G7', 'B', :'teacher_user');

insert into public.announcements (id, school_id, classroom_id, title, body, audience, created_by) values
  (:'school_wide', :'school_id', null, 'Term dates', 'See the calendar.', 'both', :'teacher_user'),
  (:'for_students', :'school_id', null, 'Lunch queue', 'Students only.', 'students', :'teacher_user'),
  (:'class_parents', :'school_id', :'classroom_id', 'Field trip', 'Bring a slip.', 'guardians', :'teacher_user'),
  (:'other_class', :'school_id', :'other_classroom', 'Not your class', 'x', 'both', :'teacher_user'),
  (:'other_school_note', :'other_school_id', null, 'Elsewhere', 'x', 'both', :'other_school_user');

create function pg_temp.list_as(actor uuid, school uuid) returns jsonb language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', actor::text, true);
  return private.api042_query('listAnnouncements', null, jsonb_build_object('schoolId', school));
end $$;
create function pg_temp.ids(page jsonb) returns text[] language sql as $$
  select coalesce(array_agg(item->>'id' order by item->>'id'), '{}')
  from jsonb_array_elements(page->'items') item $$;
create function pg_temp.allowed(actor uuid, school uuid) returns boolean language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', actor::text, true);
  return (private.authz_authorize('announcement.list', school)->>'allowed')::boolean;
end $$;

-- The decision.
select ok(pg_temp.allowed(:'guardian_user', :'school_id'),
  'a linked parent with no membership may list the child''s school''s announcements');
select ok(not pg_temp.allowed(:'guardian_user', :'other_school_id'),
  'but not another school''s');
select ok(not pg_temp.allowed(:'unverified_guardian', :'school_id'),
  'a parent whose link is not verified may not');

-- What the parent is served.
select ok(:'school_wide' = any(pg_temp.ids(pg_temp.list_as(:'guardian_user', :'school_id'))),
  'a linked parent sees a school-wide announcement for everyone');
select ok(:'class_parents' = any(pg_temp.ids(pg_temp.list_as(:'guardian_user', :'school_id'))),
  'and one for parents in the child''s class');
select ok(not (:'for_students' = any(pg_temp.ids(pg_temp.list_as(:'guardian_user', :'school_id')))),
  'but not one meant for students only');
select ok(not (:'other_class' = any(pg_temp.ids(pg_temp.list_as(:'guardian_user', :'school_id')))),
  'nor one for a class the child is not in');
select is(pg_temp.list_as(:'guardian_user', :'other_school_id')->>'outcome', 'forbidden',
  'another school''s announcements are refused');
select is(pg_temp.list_as(:'unverified_guardian', :'school_id')->>'outcome', 'forbidden',
  'a pending link reads nothing');

-- A link that has ended reads nothing.
update public.guardian_links
set verified_at = now() - interval '2 days', expires_at = now() - interval '1 minute'
where guardian_id = :'guardian_user';
select is(pg_temp.list_as(:'guardian_user', :'school_id')->>'outcome', 'forbidden',
  'an expired link reads nothing');
select ok(not pg_temp.allowed(:'guardian_user', :'school_id'),
  'and is refused by the decision');

-- Members are served as before: the student sees the school-wide one.
select ok(:'school_wide' = any(pg_temp.ids(pg_temp.list_as(:'student_user', :'school_id'))),
  'a member is served as before');

select * from finish();
rollback;
