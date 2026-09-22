-- SAFE-043 surface fixture: reuse the shared DB-021/AUTH-031/API-042 graph
-- and add two platform operators so the two-person moderation approval rule
-- has a real second approver, exactly like API-042 S8's support-access seed.
\set auth031_fixture_only true
\ir rls_access_seed.sql
\ir db021_access_seed.sql
\unset auth031_fixture_only

\set operator_a 'f0490000-0000-4000-8000-000000000001'
\set operator_b 'f0490000-0000-4000-8000-000000000002'

\set QUIET on

-- DL-049: messaging is off until a school turns it on. These suites exercise
-- messaging, so the seed school opts in explicitly.
insert into public.school_content_controls (school_id, messaging_enabled)
values ('11111111-1111-4111-8111-111111111111', true)
on conflict (school_id) do update set messaging_enabled = true;

insert into auth.users (
  id, email, encrypted_password, aud, role, email_confirmed_at, created_at,
  updated_at, instance_id, confirmation_token, recovery_token, email_change,
  email_change_token_new, email_change_token_current, phone_change_token,
  raw_app_meta_data, raw_user_meta_data
) values
  (:'operator_a', 'seed.moderation-operator-a@synthetic.studafy.test', 'synthetic-not-a-secret', 'authenticated', 'authenticated', now(), now(), now(), '00000000-0000-0000-0000-000000000000', '', '', '', '', '', '', '{}'::jsonb, '{"full_name":"Seed Moderation Operator A"}'::jsonb),
  (:'operator_b', 'seed.moderation-operator-b@synthetic.studafy.test', 'synthetic-not-a-secret', 'authenticated', 'authenticated', now(), now(), now(), '00000000-0000-0000-0000-000000000000', '', '', '', '', '', '', '{}'::jsonb, '{"full_name":"Seed Moderation Operator B"}'::jsonb)
on conflict (id) do nothing;

update auth.users set
  instance_id = '00000000-0000-0000-0000-000000000000',
  updated_at = coalesce(updated_at, now()),
  confirmation_token = '', recovery_token = '', email_change = '',
  email_change_token_new = '', email_change_token_current = '', phone_change_token = ''
where id in (:'operator_a', :'operator_b')
  and (instance_id is null or confirmation_token is null or recovery_token is null
    or email_change_token_new is null or email_change_token_current is null);

insert into public.profiles (id, display_name, created_at) values
  (:'operator_a', 'Seed Moderation Operator A', now()),
  (:'operator_b', 'Seed Moderation Operator B', now())
on conflict (id) do nothing;

insert into public.platform_operators (user_id, note) values
  (:'operator_a', 'SAFE-043 surface fixture'),
  (:'operator_b', 'SAFE-043 surface fixture')
on conflict (user_id) do nothing;

\set QUIET off

\ir safe043_surface.sql