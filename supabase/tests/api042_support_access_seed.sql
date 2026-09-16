-- API-042 S8 fixture: reuse the shared graph, add a second platform
-- operator so the two-person approval rule has a real second approver to
-- test against.
\set auth031_fixture_only true
\ir rls_access_seed.sql
\ir db021_access_seed.sql
\unset auth031_fixture_only

\set operator_a 'f0480000-0000-4000-8000-000000000001'
\set operator_b 'f0480000-0000-4000-8000-000000000002'

\set QUIET on

insert into auth.users (
  id, email, encrypted_password, aud, role, email_confirmed_at, created_at,
  updated_at, instance_id, confirmation_token, recovery_token, email_change,
  email_change_token_new, email_change_token_current, phone_change_token,
  raw_app_meta_data, raw_user_meta_data
) values
  (:'operator_a', 'seed.support-operator-a@synthetic.studafy.test', 'synthetic-not-a-secret', 'authenticated', 'authenticated', now(), now(), now(), '00000000-0000-0000-0000-000000000000', '', '', '', '', '', '', '{}'::jsonb, '{"full_name":"Seed Support Operator A"}'::jsonb),
  (:'operator_b', 'seed.support-operator-b@synthetic.studafy.test', 'synthetic-not-a-secret', 'authenticated', 'authenticated', now(), now(), now(), '00000000-0000-0000-0000-000000000000', '', '', '', '', '', '', '{}'::jsonb, '{"full_name":"Seed Support Operator B"}'::jsonb)
on conflict (id) do nothing;

update auth.users set
  instance_id = '00000000-0000-0000-0000-000000000000',
  updated_at = coalesce(updated_at, now()),
  confirmation_token = '', recovery_token = '', email_change = '',
  email_change_token_new = '', email_change_token_current = '', phone_change_token = ''
where id in (:'operator_a', :'operator_b')
  and (instance_id is null or confirmation_token is null or recovery_token is null
    or email_change_token_new is null or updated_at is null);

insert into public.platform_operators (user_id, note) values
  (:'operator_a', 'api042 support-access fixture'),
  (:'operator_b', 'api042 support-access fixture')
on conflict (user_id) do nothing;

\ir api042_support_access.sql
