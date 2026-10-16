-- Reviewer access (202610150050): email sign-up stays refused; only an
-- address the service role registered minutes before can become an email
-- account, once. Transactional: everything here is rolled back.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(15);

create or replace function pg_temp.add_user(
  p_id uuid, p_email text, p_app jsonb)
returns void language sql as $$
  insert into auth.users (id, email, encrypted_password, aud, role,
    email_confirmed_at, created_at, updated_at, instance_id,
    confirmation_token, recovery_token, email_change, email_change_token_new,
    email_change_token_current, phone_change_token, raw_app_meta_data,
    raw_user_meta_data)
  values (p_id, p_email, 'synthetic-not-a-secret', 'authenticated',
    'authenticated', now(), now(), now(),
    '00000000-0000-0000-0000-000000000000', '', '', '', '', '', '', p_app,
    '{}');
$$;

-- 1. Sign-up through the email provider is refused: this is the row
--    Supabase Auth inserts for /signup and for an OTP that creates a user.
select throws_ok(
  $$ select pg_temp.add_user('7e510000-0000-4000-8000-000000000001',
       'someone@example.com', '{"provider":"email","providers":["email"]}') $$,
  '42501', 'email sign-up is disabled',
  'an email sign-up nobody registered is refused');

-- 2. The other ways an account appears are untouched.
select lives_ok(
  $$ select pg_temp.add_user('7e510000-0000-4000-8000-000000000002',
       'someone@gmail.com', '{"provider":"google","providers":["google"]}') $$,
  'a new Google account is still created');
select lives_ok(
  $$ select pg_temp.add_user('7e510000-0000-4000-8000-000000000003',
       'someone@icloud.com', '{"provider":"apple","providers":["apple"]}') $$,
  'a new Apple account is still created');
select lives_ok(
  $$ select pg_temp.add_user('7e510000-0000-4000-8000-000000000004',
       'someone@outlook.com', '{"provider":"azure","providers":["azure"]}') $$,
  'a new Microsoft account is still created');
select lives_ok(
  $$ select pg_temp.add_user('7e510000-0000-4000-8000-000000000005',
       'child-1@managed.studafy.invalid',
       '{"provider":"email","providers":["email"]}') $$,
  'a managed child account, under the reserved domain, is still created');
select lives_ok(
  $$ select pg_temp.add_user('7e510000-0000-4000-8000-000000000006',
       'mirror@synthetic.studafy.test', '{}') $$,
  'an identity mirrored by SQL, with no provider, is still created');

-- 3. Registered by the service role, the address may be created - once.
set local role service_role;
select lives_ok(
  $$ select public.allow_provisioned_email_account(' Teacher@Review.Studafy.com ') $$,
  'the service role registers an address');
reset role;
select is(
  (select email from private.provisioned_email_accounts),
  'teacher@review.studafy.com',
  'the registration is kept lower-cased and trimmed');
select lives_ok(
  $$ select pg_temp.add_user('7e510000-0000-4000-8000-000000000007',
       'teacher@review.studafy.com',
       '{"provider":"email","providers":["email"]}') $$,
  'the registered address becomes an account');
select is(
  (select count(*) from private.provisioned_email_accounts),
  0::bigint,
  'the registration is used up');

-- 4. An expired registration counts for nothing.
insert into private.provisioned_email_accounts (email, allowed_until)
values ('late@review.studafy.com', now() - interval '1 second');
select throws_ok(
  $$ select pg_temp.add_user('7e510000-0000-4000-8000-000000000008',
       'late@review.studafy.com', '{"provider":"email","providers":["email"]}') $$,
  '42501', 'email sign-up is disabled',
  'an expired registration does not let an account through');

-- 5. Nobody but the service role can register an address or read the list.
select ok(
  not has_function_privilege('anon',
    'public.allow_provisioned_email_account(text)', 'execute')
  and not has_function_privilege('authenticated',
    'public.allow_provisioned_email_account(text)', 'execute')
  and not has_function_privilege('studafy_api_runtime',
    'public.allow_provisioned_email_account(text)', 'execute'),
  'clients and the API cannot register an address');
select ok(
  has_function_privilege('service_role',
    'public.allow_provisioned_email_account(text)', 'execute'),
  'the service role can');
select ok(
  not has_table_privilege('authenticated',
    'private.provisioned_email_accounts', 'select')
  and not has_table_privilege('service_role',
    'private.provisioned_email_accounts', 'select'),
  'the registrations are not readable by any client role');
set local role service_role;
select throws_ok(
  $$ select public.allow_provisioned_email_account('not an address') $$,
  '22023', 'not an email address',
  'something that is not an address is refused');
reset role;

select * from finish();
rollback;
