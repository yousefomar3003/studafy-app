-- Managed child accounts (202609280004): a parent creates a real student
-- account for a child with no email or phone, and signs in to it.
-- Transactional fixtures: this test leaves existing local users/data intact.
begin;
\set auth031_fixture_only true
\ir rls_access_seed.sql
\unset auth031_fixture_only
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select plan(22);

\set child 'f00d0000-0000-4000-8000-0000000000c1'
\set old_child 'f00d0000-0000-4000-8000-0000000000c2'

-- What the API does through Supabase Auth: an account with the parent in its
-- app metadata, which only the service role can write.
insert into auth.users (id, email, aud, role, email_confirmed_at, created_at,
  updated_at, instance_id, raw_app_meta_data, raw_user_meta_data)
values
  (:'child', 'child-c1@managed.studafy.invalid', 'authenticated',
   'authenticated', now(), now(), now(),
   '00000000-0000-0000-0000-000000000000',
   jsonb_build_object('studafy_managed_by', :'guardian_user'),
   '{"full_name":"Sara"}'),
  (:'old_child', 'child-c2@managed.studafy.invalid', 'authenticated',
   'authenticated', now(), now() - interval '1 hour', now(),
   '00000000-0000-0000-0000-000000000000',
   jsonb_build_object('studafy_managed_by', :'guardian_user'),
   '{"full_name":"Old"}');

create function pg_temp.as_user(u uuid, op text, input jsonb)
returns jsonb language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', u::text, true);
  return private.api048_managed_accounts(op, input);
end $$;

create function pg_temp.register(u uuid, child uuid, version text default '2026-09-09')
returns text language sql as $$
  select pg_temp.as_user(u, 'register', jsonb_build_object(
    'childId', child, 'policyVersion', version, 'locale', 'en')) ->> 'outcome'
$$;

-- 1. Creating.
select is(pg_temp.as_user(:'guardian_user', 'can_create', '{}') ->> 'outcome',
  'ok', 'a parent may create a child account');
select is(pg_temp.register(:'guardian_user', :'child', '1999-01-01'), 'invalid',
  'consent to a policy that was never published is refused');
select is((select count(*) from private.managed_accounts), 0::bigint,
  'and that refusal wrote nothing');
select is(pg_temp.register(:'guardian_user', :'child'), 'ok',
  'the parent registers the account made for them');
select is((select count(*) from public.consent_records
  where user_id = :'child' and purpose = 'terms_and_privacy'), 1::bigint,
  'the parent''s acceptance of the terms is recorded on the child');
select is((select action from public.audit_events
  where entity_id = :'child' order by id limit 1), 'managed_account_created',
  'creating a child account is audited');

-- 2. Nobody can claim an account that is not theirs to claim.
select is(pg_temp.register(:'guardian_user', :'child'), 'invalid',
  'an account is registered once');
select is(pg_temp.register(:'teacher_user', :'child'), 'invalid',
  'another adult cannot claim the child');
select is(pg_temp.register(:'guardian_user', :'student_user'), 'invalid',
  'a parent cannot turn an ordinary account into a child account');
select is(pg_temp.register(:'guardian_user', :'old_child'), 'invalid',
  'an account made more than a few minutes ago cannot be registered');

-- 3. Signing in as the child.
select is(pg_temp.as_user(:'guardian_user', 'authorize_session',
  jsonb_build_object('childId', :'child')) ->> 'outcome', 'ok',
  'the parent may sign in as their child');
select is(pg_temp.as_user(:'teacher_user', 'authorize_session',
  jsonb_build_object('childId', :'child')) ->> 'outcome', 'not_found',
  'nobody else may, and is not told the account exists');
select is(pg_temp.as_user(:'guardian_user', 'authorize_session',
  jsonb_build_object('childId', :'student_user')) ->> 'outcome', 'not_found',
  'a parent cannot sign in as an account they do not manage');
select ok(exists(select 1 from public.audit_events
  where entity_id = :'child' and action = 'managed_account_session_issued'),
  'every sign-in as a child is audited');

-- 4. A child account manages nobody.
select is(pg_temp.as_user(:'child', 'can_create', '{}') ->> 'outcome',
  'forbidden', 'a child cannot create accounts');
select is(pg_temp.as_user(:'child', 'authorize_session',
  jsonb_build_object('childId', :'child')) ->> 'outcome', 'forbidden',
  'a child cannot issue sign-ins');
select is(pg_temp.as_user(:'student_user', 'can_create', '{}') ->> 'outcome',
  'forbidden', 'a student cannot create child accounts');
select is(jsonb_array_length(pg_temp.as_user(:'guardian_user', 'list', '{}') -> 'items'),
  1, 'the parent lists their child');

-- 5. Joining a class makes the parent a verified guardian at that school.
insert into public.students (school_id, studafy_id, display_name, created_by, user_id)
values (:'school_id', 'STU-MANAGED-TEST', 'Sara', :'child', :'child');
select is((select gl.status::text from public.guardian_links gl
  join public.students st on st.id = gl.student_id
  where st.user_id = :'child' and gl.guardian_id = :'guardian_user'),
  'verified', 'the managing parent is a verified guardian where the child studies');

-- 6. The limit.
do $$
declare u uuid;
begin
  for i in 1..5 loop
    u := gen_random_uuid();
    insert into auth.users (id, email, aud, role, email_confirmed_at,
      created_at, updated_at, instance_id, raw_app_meta_data, raw_user_meta_data)
    values (u, 'child-' || u || '@managed.studafy.invalid', 'authenticated',
      'authenticated', now(), now(), now(),
      '00000000-0000-0000-0000-000000000000',
      jsonb_build_object('studafy_managed_by', 'cccc0000-0000-4000-8000-000000000003'),
      '{"full_name":"Kid"}');
    perform pg_temp.register('cccc0000-0000-4000-8000-000000000003', u);
  end loop;
end $$;
select is(pg_temp.as_user(:'guardian_user', 'can_create', '{}') ->> 'outcome',
  'limit_reached', 'one account manages at most six children');

-- 7. Only the API reaches any of this.
select ok(not has_function_privilege('authenticated',
  'private.api048_managed_accounts(text,jsonb)', 'execute')
  and not has_function_privilege('anon',
  'private.api048_managed_accounts(text,jsonb)', 'execute'),
  'clients cannot call the managed-account surface directly');
select ok(not has_table_privilege('studafy_api_runtime',
  'private.managed_accounts', 'select'),
  'the API reads managed accounts only through the function');

select * from finish();
rollback;
