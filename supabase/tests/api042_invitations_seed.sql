-- API-042 S2 fixture: reuse the shared DB-021/AUTH-031/API-042-S1 graph, add
-- one never-a-member invitee for acceptance tests.
\set auth031_fixture_only true
\ir rls_access_seed.sql
\ir db021_access_seed.sql
\unset auth031_fixture_only

\set invitee_user 'f0420001-0000-4000-8000-000000000001'

\set QUIET on

insert into auth.users (
  id, email, encrypted_password, aud, role, email_confirmed_at, created_at,
  updated_at, instance_id, confirmation_token, recovery_token, email_change,
  email_change_token_new, email_change_token_current, phone_change_token,
  raw_app_meta_data, raw_user_meta_data
) values
  (:'invitee_user', 'seed.invitee@synthetic.studafy.test', 'synthetic-not-a-secret', 'authenticated', 'authenticated', now(), now(), now(), '00000000-0000-0000-0000-000000000000', '', '', '', '', '', '', '{}'::jsonb, '{"full_name":"Seed Invitee"}'::jsonb)
on conflict (id) do nothing;

update auth.users set
  instance_id = '00000000-0000-0000-0000-000000000000',
  updated_at = coalesce(updated_at, now()),
  confirmation_token = '', recovery_token = '', email_change = '',
  email_change_token_new = '', email_change_token_current = '', phone_change_token = ''
where id = :'invitee_user'
  and (instance_id is null or confirmation_token is null or recovery_token is null
    or email_change_token_new is null or updated_at is null);

\ir api042_invitations.sql
