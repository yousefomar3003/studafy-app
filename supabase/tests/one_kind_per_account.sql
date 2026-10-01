-- One kind of account per email (202610010002).
-- Transactional fixtures: this test leaves existing local users/data intact.
begin;
\set auth031_fixture_only true
\ir rls_access_seed.sql
\ir db021_access_seed.sql
\unset auth031_fixture_only
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select plan(16);

\set fresh_user 'abcf0000-0000-4000-8000-0000000002a1'
insert into auth.users (id, email, encrypted_password, aud, role, email_confirmed_at, created_at,
  updated_at, instance_id, confirmation_token, recovery_token, email_change,
  email_change_token_new, email_change_token_current, phone_change_token,
  raw_app_meta_data, raw_user_meta_data)
values (:'fresh_user', 'one-kind.fresh@synthetic.studafy.test',
  'synthetic-not-a-secret', 'authenticated', 'authenticated', now(), now(), now(),
  '00000000-0000-0000-0000-000000000000', '', '', '', '', '', '', '{}', '{}');

create temporary table results(name text primary key, result jsonb);
create or replace function pg_temp.run(
  p_name text, p_dispatch text, p_operation text, p_body jsonb)
returns jsonb language plpgsql as $$
declare reservation jsonb; outcome jsonb;
begin
  perform set_config('studafy.request_id', 'one-kind-' || p_name, true);
  reservation := private.api_idempotency_reserve(
    null, 'v1.' || p_operation, 'one-kind-account-key-' || p_name, repeat('d', 64));
  execute format('select private.%I($1, null, $2, $3, 1)', p_dispatch)
    into outcome
    using p_operation, jsonb_build_object('responseStatus', 200, 'body', p_body),
      (reservation->>'id')::uuid;
  insert into results values (p_name, outcome);
  return outcome;
end;
$$;
select set_config('studafy.school_id', '', true);

-- 1. What each account is.
select is(private.account_kind(:'student_user'), 'student', 'a pupil in a class is a student account');
select is(private.account_kind(:'teacher_user'), 'adult', 'a teacher is an adult account');
select is(private.account_kind(:'guardian_user'), 'adult', 'a linked parent is an adult account');
select is(private.account_kind(:'fresh_user'), null, 'a brand-new account is not decided yet');
select is(private.profile_json(:'student_user') ->> 'accountKind', 'student',
  'the profile tells the app which kind it is');

-- 2. A new account takes the kind of the door it first came through, once.
select set_config('request.jwt.claim.sub', :'fresh_user', true);
select is(pg_temp.run('record', 'api042_command', 'updateProfile',
  jsonb_build_object('accountKind', 'student')) -> 'response' ->> 'accountKind', 'student',
  'signing in as a student records a student account');
select is(pg_temp.run('re-record', 'api042_command', 'updateProfile',
  jsonb_build_object('accountKind', 'adult')) -> 'response' ->> 'accountKind', 'student',
  'and asking again changes nothing');

-- 3. A student account cannot set up teaching, nor find or link to a child.
select is(pg_temp.run('workspace', 'api045_command', 'createTeacherWorkspace',
  jsonb_build_object('name', 'Not a school')) ->> 'outcome', 'invalid_state',
  'a student account cannot set up a teaching space');
select is((select count(*) from public.memberships where user_id = :'fresh_user'), 0::bigint,
  'and no role is created');
select is(pg_temp.run('locate', 'api042_command', 'locateStudent',
  jsonb_build_object('studafyId', 'STU-SEED-0001')) ->> 'outcome', 'forbidden',
  'a student account cannot look a child up');

-- 4. An adult account cannot join a class as a pupil.
select set_config('request.jwt.claim.sub', :'teacher_user', true);
select is(pg_temp.run('join', 'api044_command', 'redeemClassJoinLink',
  jsonb_build_object('token', repeat('x', 43))) ->> 'outcome', 'forbidden',
  'a teacher cannot join a class as a student');

-- 5. Whatever path writes a role, the tables keep the rule.
select throws_ok(format($$insert into public.memberships(school_id, user_id, role, active, status)
  values (%L, %L, 'teacher', true, 'active')$$, :'other_school_id', :'student_user'),
  '23514', 'A student account cannot hold another role',
  'a student account never gains a staff role');
select throws_ok(format($$insert into public.memberships(school_id, user_id, role, active, status)
  values (%L, %L, 'student', true, 'active')$$, :'other_school_id', :'teacher_user'),
  '23514', 'An adult account cannot be a student',
  'an adult account never becomes a pupil');
select throws_ok(format($$insert into public.guardian_links(school_id, student_id, guardian_id, status)
  values (%L, %L, %L, 'pending')$$, :'school_id', :'student_id', :'fresh_user'),
  '23514', 'A student account cannot be a parent',
  'a student account is never anyone''s parent');

-- 6. A teacher may also be a parent.
select lives_ok(format($$insert into public.guardian_links(school_id, student_id, guardian_id, status)
  values (%L, %L, %L, 'pending')$$, :'school_id', :'student_id', :'teacher_user'),
  'a teacher may also be a parent');
select is(private.account_kind(:'teacher_user'), 'adult', 'and is still one adult account');

select * from finish();
rollback;
