-- A guardian links only to a student (202609290006).
-- Transactional fixtures: this test leaves existing local users/data intact.
begin;
\set auth031_fixture_only true
\ir rls_access_seed.sql
\ir db021_access_seed.sql
\unset auth031_fixture_only
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select plan(10);

-- A students row behind a teacher's account (accounts can hold several
-- roles), and a child the school created with no account yet.
\set teacher_student_id 'abcf0000-0000-4000-8000-0000000000f1'
\set provisional_id 'abcf0000-0000-4000-8000-0000000000f2'
insert into public.students (id, school_id, user_id, studafy_id, display_name, provisional, created_by)
values (:'teacher_student_id', :'school_id', :'teacher_user', 'STU-TEACHER-LINK', 'Teacher', false, :'teacher_user'),
       (:'provisional_id', :'school_id', null, 'STU-NO-ACCOUNT', 'Little one', true, :'teacher_user');

create temporary table results(name text primary key, result jsonb);
create or replace function pg_temp.run(p_name text, p_operation text, p_body jsonb)
returns jsonb language plpgsql as $$
declare reservation jsonb; outcome jsonb;
begin
  perform set_config('studafy.request_id', 'links-only-' || p_name, true);
  reservation := private.api_idempotency_reserve(
    null, 'v1.' || p_operation, 'links-only-key-' || p_name, repeat('d', 64));
  outcome := private.api042_command(p_operation, null,
    jsonb_build_object('responseStatus', 200, 'body', p_body),
    (reservation->>'id')::uuid, 1);
  insert into results values (p_name, outcome);
  return outcome;
end;
$$;

select set_config('request.jwt.claim.sub', :'unverified_guardian', true);
select set_config('studafy.school_id', '', true);

-- 1. Finding a child by Studafy ID.
select is(pg_temp.run('find-student', 'locateStudent',
  jsonb_build_object('studafyId', (select studafy_id from public.students where id = :'student_id')))
  -> 'response' ->> 'found', 'true', 'a student is found by their Studafy ID');
select is(pg_temp.run('find-teacher', 'locateStudent',
  jsonb_build_object('studafyId', 'STU-TEACHER-LINK')) -> 'response',
  jsonb_build_object('found', false, 'studentId', null, 'displayName', null),
  'a teacher''s account is answered exactly as an unknown ID');
select is(pg_temp.run('find-provisional', 'locateStudent',
  jsonb_build_object('studafyId', 'STU-NO-ACCOUNT')) -> 'response' ->> 'found', 'true',
  'a child the school created with no account yet can be found');

-- 2. Asking to link.
select is(pg_temp.run('link-teacher', 'requestGuardianLink',
  jsonb_build_object('studentId', :'teacher_student_id')) ->> 'outcome', 'not_found',
  'a link request to a teacher''s account is refused');
select is((select count(*) from public.guardian_links where student_id = :'teacher_student_id'),
  0::bigint, 'and no link is made');
select is(pg_temp.run('link-provisional', 'requestGuardianLink',
  jsonb_build_object('studentId', :'provisional_id')) ->> 'outcome', 'ok',
  'a link request to a real student still works');

-- 3. Every other path: the table itself refuses a staff account or oneself.
select throws_ok(format($$insert into public.guardian_links(school_id, student_id, guardian_id, status)
  values (%L, %L, %L, 'verified')$$, :'school_id', :'teacher_student_id', :'guardian_user'),
  '23514', 'A guardian can be linked only to a student',
  'no path can link a guardian to a teacher''s account');
select throws_ok(format($$insert into public.guardian_links(school_id, student_id, guardian_id, status)
  values (%L, %L, %L, 'pending')$$, :'school_id', :'student_id', :'student_user'),
  '23514', 'A guardian can be linked only to a student',
  'no one can be linked as their own guardian');
select lives_ok(format($$update public.guardian_links set status = 'revoked'
  where student_id = %L$$, :'student_id'),
  'existing links are left alone by the check');

select ok(not has_function_privilege('authenticated',
  'private.student_linkable(uuid,uuid)', 'execute'),
  'the rule is not callable by clients');

select * from finish();
rollback;
