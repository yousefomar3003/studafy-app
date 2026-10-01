-- One Studafy ID per student (202610010001).
-- Transactional fixtures: this test leaves existing local users/data intact.
begin;
\set auth031_fixture_only true
\ir rls_access_seed.sql
\ir db021_access_seed.sql
\unset auth031_fixture_only
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select plan(10);

\set second_record_id 'abcf0000-0000-4000-8000-0000000001a1'
\set newcomer_user 'abcf0000-0000-4000-8000-0000000001a2'
select studafy_id as seed_id from public.students where id = :'student_id' \gset

-- 1. The same child at another teacher's school keeps their one ID,
-- whatever the creating path asked for.
insert into public.students (id, school_id, user_id, studafy_id, display_name, provisional, created_by)
values (:'second_record_id', :'other_school_id', :'student_user', 'SJ-SECOND-SCHOOL',
  'Seed Student', true, :'student_user');
select is((select studafy_id from public.students where id = :'second_record_id'), :'seed_id',
  'a second school record of the same child takes the child''s existing ID');
select is((select count(distinct studafy_id) from public.students where user_id = :'student_user'),
  1::bigint, 'the child has exactly one Studafy ID');

-- 2. An ID belongs to one child only.
insert into auth.users (id, email, encrypted_password, aud, role, email_confirmed_at, created_at,
  updated_at, instance_id, confirmation_token, recovery_token, email_change,
  email_change_token_new, email_change_token_current, phone_change_token,
  raw_app_meta_data, raw_user_meta_data)
values (:'newcomer_user', 'one-id.newcomer@synthetic.studafy.test',
  'synthetic-not-a-secret', 'authenticated', 'authenticated', now(), now(), now(),
  '00000000-0000-0000-0000-000000000000', '', '', '', '', '', '', '{}', '{}');
select throws_ok(format($$insert into public.students(school_id, user_id, studafy_id, display_name, created_by)
  values (%L, %L, %L, 'Newcomer', %L)$$, :'other_school_id', :'newcomer_user', :'seed_id', :'newcomer_user'),
  '23505', 'A Studafy ID belongs to one student',
  'another child cannot be given someone else''s ID');
select throws_ok(format($$insert into public.students(school_id, user_id, studafy_id, display_name, created_by)
  values (%L, null, %L, 'Roster child', %L)$$, :'school_id', :'seed_id', :'teacher_user'),
  '23505', 'A Studafy ID belongs to one student',
  'a record with no account cannot share a child''s ID');
update public.students set studafy_id = 'SJ-CHANGED-0001' where id = :'second_record_id';
select is((select studafy_id from public.students where id = :'second_record_id'), :'seed_id',
  'one record of a child cannot drift to a different ID');

-- 3. The child's own family view shows the ID once.
select set_config('request.jwt.claim.sub', :'student_user', true);
select is(jsonb_array_length(private.ops_query_student_family('getStudentFamily', null, '{}'::jsonb)
  -> 'studentIds'), 1, 'the family view lists one Studafy ID');

-- 4. A parent finds the child by that one ID: the oldest live record.
create temporary table results(name text primary key, result jsonb);
create or replace function pg_temp.locate(p_name text, p_id text)
returns jsonb language plpgsql as $$
declare reservation jsonb; outcome jsonb;
begin
  perform set_config('studafy.request_id', 'one-id-' || p_name, true);
  reservation := private.api_idempotency_reserve(
    null, 'v1.locateStudent', 'one-id-key-' || p_name, repeat('d', 64));
  outcome := private.api042_command('locateStudent', null,
    jsonb_build_object('responseStatus', 200, 'body', jsonb_build_object('studafyId', p_id)),
    (reservation->>'id')::uuid, 1);
  insert into results values (p_name, outcome);
  return outcome;
end;
$$;
select set_config('request.jwt.claim.sub', :'unverified_guardian', true);
select set_config('studafy.school_id', '', true);
select is(pg_temp.locate('first', :'seed_id') -> 'response' ->> 'studentId', :'student_id',
  'the ID finds the child''s oldest record');
update public.students set deleted_at = now() where id = :'student_id';
select is(pg_temp.locate('after-delete', :'seed_id') -> 'response' ->> 'studentId', :'second_record_id',
  'a deleted record is never the one found; the child''s live record is');

-- 5. Adding an existing child to a roster reports the ID they keep.
select set_config('request.jwt.claim.sub', :'admin_user', true);
select set_config('studafy.school_id', :'school_id', true);
select set_config('studafy.request_id', 'one-id-create', true);
create temporary table created(name text primary key, result jsonb);
insert into created values ('reservation', private.api_idempotency_reserve(
  :'school_id', 'v1.createStudent', 'one-studafy-id-roster-create-1', repeat('e', 64)));
insert into created values ('create', private.api042_command('createStudent', null,
  jsonb_build_object('responseStatus', 201, 'body',
    jsonb_build_object('displayName', 'Seed Student', 'userId', :'student_user')),
  ((select result->>'id' from created where name = 'reservation')::uuid), 1));
select is((select result->>'outcome' from created where name = 'create'), 'ok',
  'an admin adds the child to the roster');
select is((select result->'response'->>'studafyId' from created where name = 'create'), :'seed_id',
  'and the response carries the child''s one ID, not a new one');

select * from finish();
rollback;
