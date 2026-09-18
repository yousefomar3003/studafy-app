-- AUTH-030 database surface assertions.
--
-- The claim under test: activating the API runtime role did not widen any
-- client's reach, and the API's entire database authority is EXECUTE on a
-- named set of private functions.

begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(16);

-- --------------------------------------------------------------------------
-- The API role holds no data privilege of any kind.
-- --------------------------------------------------------------------------

select is(
  (select count(*) from information_schema.role_table_grants
   where grantee = 'studafy_api_runtime'),
  0::bigint,
  'API runtime role has no table grants'
);

select is(
  (select count(*) from information_schema.column_privileges
   where grantee = 'studafy_api_runtime'),
  0::bigint,
  'API runtime role has no column grants'
);

select ok(
  not has_schema_privilege('studafy_api_runtime', 'public', 'usage'),
  'API runtime role cannot resolve the public schema'
);

select ok(
  has_schema_privilege('studafy_api_runtime', 'private', 'usage'),
  'API runtime role can resolve the private function schema'
);

select ok(
  (select not rolbypassrls and not rolinherit and rolcanlogin
   from pg_roles where rolname = 'studafy_api_runtime'),
  'API runtime role logs in, inherits nothing, and cannot bypass RLS'
);

-- --------------------------------------------------------------------------
-- The executable surface is exactly the reviewed list.
-- --------------------------------------------------------------------------

select is(
  (select array_agg(p.proname::text order by p.proname)
   from pg_proc p
   join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'private'
     and has_function_privilege('studafy_api_runtime', p.oid, 'execute')),
  array[
    'api041_command',
    'api041_query',
    'api042_command',
    'api042_query',
    -- FILE-050. Five narrow upload/file commands; each independently
    -- re-validates actor, tenant, membership, relationship, purpose and state.
    'api050_complete_upload',
    'api050_issue_intent',
    'api050_prepare_completion',
    'api050_prepare_intent',
    'api050_query',
    -- FILE-051. Publication, download-grant issue and grant consumption;
    -- each re-derives authorization from current state before acting.
    'api051_consume_download_grant',
    'api051_create_download_grant',
    'api051_publish_file',
    'api_idempotency_complete',
    'api_idempotency_fail',
    'api_idempotency_reserve',
    'auth_cancel_deletion',
    'auth_consume_reauth_grant',
    'auth_context',
    'auth_deletion_impact',
    'auth_issue_reauth_grant',
    'auth_link_identity',
    'auth_list_devices',
    'auth_record_security_event',
    'auth_request_deletion',
    'auth_revoke_device',
    'auth_sign_out_all',
    'auth_touch_device',
    'auth_unlink_identity',
    'authz_authorize',
    'billing_catalogue',
    'billing_list_entitlements',
    'billing_record_event',
    'billing_restore',
    'billing_self_purchase_status',
    'billing_set_self_purchase',
    'billing_submit_verification'
  ],
  'API runtime role executes exactly the reviewed auth, idempotency, academic, file, and billing surface'
);

select is(
  (select count(*) from pg_proc p
   join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'private'
     and p.proname like 'auth\_%'
     and (has_function_privilege('anon', p.oid, 'execute')
       or has_function_privilege('authenticated', p.oid, 'execute')
       or has_function_privilege('service_role', p.oid, 'execute')
       or has_function_privilege('studafy_worker_runtime', p.oid, 'execute'))),
  0::bigint,
  'no client, service, or worker role can execute an auth function'
);

-- The hashing helper is the one function even the API may not call directly:
-- it would otherwise be an oracle for testing whether a given email is known.
select ok(
  not has_function_privilege(
    'studafy_api_runtime', 'private.auth_normalized_hash(text, text)', 'execute'
  ),
  'the account hashing helper is not directly callable by the API'
);

-- --------------------------------------------------------------------------
-- New relations are closed to every client role.
-- --------------------------------------------------------------------------

select is(
  (select count(*) from information_schema.role_table_grants
   where table_schema = 'public'
     and table_name like 'auth\_%'
     and grantee in ('anon', 'authenticated', 'service_role')),
  0::bigint,
  'no client or service role holds a grant on an AUTH-030 relation'
);

select is(
  (select count(*) from information_schema.column_privileges
   where table_schema = 'public'
     and table_name like 'auth\_%'
     and grantee in ('anon', 'authenticated', 'service_role')),
  0::bigint,
  'no client or service role holds a column grant on an AUTH-030 relation'
);

select is(
  (select count(*) from pg_class c
   join pg_namespace n on n.oid = c.relnamespace
   where n.nspname = 'public'
     and c.relname like 'auth\_%'
     and c.relkind = 'r'
     and not c.relrowsecurity),
  0::bigint,
  'every AUTH-030 relation has row level security enabled'
);

-- --------------------------------------------------------------------------
-- Append-only and immutability guarantees.
-- --------------------------------------------------------------------------

select ok(
  exists (
    select 1 from pg_trigger t
    join pg_class c on c.oid = t.tgrelid
    where c.relname = 'auth_security_events'
      and t.tgname = 'auth030_reject_mutation'
      and not t.tgisinternal
  ),
  'security events carry the append-only trigger'
);

insert into public.auth_security_events (event_type, outcome, reason_code)
values ('sign_in_failed', 'denied', 'invalid_credentials');

select throws_ok(
  $$update public.auth_security_events set reason_code = 'tampered'$$,
  'Append-only relation cannot be updated or deleted',
  'a security event cannot be rewritten'
);

select throws_ok(
  $$delete from public.auth_security_events$$,
  'Append-only relation cannot be updated or deleted',
  'a security event cannot be deleted'
);

-- --------------------------------------------------------------------------
-- Consent may only be recorded against a published policy.
-- --------------------------------------------------------------------------

select is(
  (select count(*) from public.consent_policies
   where purpose = 'terms_and_privacy' and policy_version = '2026-09-09'),
  2::bigint,
  'the shipped terms policy version exists in both locales'
);

select is(
  (select count(*) from information_schema.role_routine_grants
   where routine_schema = 'public'
     and grantee in ('anon', 'service_role')
     and routine_name = 'record_policy_consent'),
  0::bigint,
  'replacing the consent RPC did not reopen it to anon or service_role'
);

select * from finish();
rollback;
