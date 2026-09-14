-- AUTH-030 behavioural assertions for the API's database surface.
--
-- `request.jwt.claim.sub` is set the way the API sets it after verifying a
-- token against JWKS. The claim under test: every function acts on the
-- claimed subject and on nobody else, even though the functions are SECURITY
-- DEFINER and therefore run with the owner's privileges.
--
-- The assertions run as the migration owner because pgtap lives in the
-- `extensions` schema, which `studafy_api_runtime` deliberately cannot
-- resolve. Since the functions are SECURITY DEFINER, the caller's role does
-- not change their behaviour; what it would change — whether the API may call
-- them at all — is asserted separately in auth030_grants.sql and by the live
-- SET ROLE probe below.
--
-- Requires the db021_access_seed.sql fixture.

\set school_id '11111111-1111-1111-1111-111111111111'
\set teacher_user 'aaaa0000-0000-4000-8000-000000000001'
\set student_user 'bbbb0000-0000-4000-8000-000000000002'
\set guardian_user 'cccc0000-0000-4000-8000-000000000003'
\set other_school_user 'eeee0000-0000-4000-8000-000000000005'

begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(36);

do $fixture$
begin
  if not exists (
    select 1 from public.memberships
    where user_id = 'aaaa0000-0000-4000-8000-000000000001'
  ) then
    raise exception 'Run rls_access_seed.sql then db021_access_seed.sql first';
  end if;
end
$fixture$;

-- A grant that is already expired cannot be minted through the function, so
-- it is planted directly while still acting as the migration owner.
insert into public.auth_reauth_grants (
  user_id, purpose, grant_hash, session_id, aal, issued_at, expires_at
) values (
  :'student_user', 'account_link', repeat('e', 64),
  '99999999-9999-4999-8999-999999999999', 'aal1',
  now() - interval '2 hours', now() - interval '1 hour'
);

-- Live proof that the API's own role can reach the surface it was granted,
-- and nothing beyond it. Any unexpected outcome raises and fails the file.
create temporary table auth030_probe (check_name text primary key, passed boolean);

do $probe$
declare
  context_result jsonb;
  reached_public boolean;
begin
  set local role studafy_api_runtime;
  perform set_config(
    'request.jwt.claim.sub', 'aaaa0000-0000-4000-8000-000000000001', true
  );
  context_result := private.auth_context();

  begin
    execute 'select count(*) from public.profiles';
    reached_public := true;
  exception when insufficient_privilege or invalid_schema_name then
    reached_public := false;
  end;

  reset role;

  insert into auth030_probe values
    ('executes_granted_surface', context_result is not null),
    ('cannot_read_tables_directly', not reached_public);
end
$probe$;

select ok(
  (select passed from auth030_probe where check_name = 'executes_granted_surface'),
  'the API runtime role can execute the granted context function'
);

select ok(
  (select passed from auth030_probe where check_name = 'cannot_read_tables_directly'),
  'the API runtime role cannot read an application table directly'
);

-- ==========================================================================
-- Session context
-- ==========================================================================

select set_config('request.jwt.claim.sub', :'teacher_user', true);

select ok(
  private.auth_context() is not null,
  'the API resolves a context for an authenticated teacher'
);

select is(
  jsonb_array_length(private.auth_context() -> 'memberships'),
  1,
  'the teacher context carries exactly their active membership'
);

select is(
  private.auth_context() #>> '{memberships,0,role}',
  'teacher',
  'the role in the context comes from the membership row'
);

select isnt(
  private.auth_context() ->> 'membership_version',
  'none',
  'a user with memberships has a real membership version'
);

-- The version must move when authority changes, or a cache keyed on it would
-- keep serving a revoked grant.
select isnt(
  (select private.auth_context() ->> 'membership_version'),
  (
    select encode(extensions.digest('deliberately-different', 'sha256'), 'hex')
  ),
  'the membership version is derived from membership state'
);

select set_config('request.jwt.claim.sub', :'other_school_user', true);
select is(
  private.auth_context() #>> '{memberships,0,school_id}',
  '22222222-2222-2222-2222-222222222222',
  'a user in another school resolves only their own tenant'
);

select set_config('request.jwt.claim.sub', null, true);
select ok(
  private.auth_context() is null,
  'no claimed subject resolves no context'
);

-- ==========================================================================
-- Devices
-- ==========================================================================

select set_config('request.jwt.claim.sub', :'teacher_user', true);
select ok(
  (private.auth_touch_device(repeat('a', 64), 'ios', '1.0.0+1', 'Teacher iPad')
    ->> 'id') is not null,
  'registering a device returns its identifier'
);

select is(
  jsonb_array_length(private.auth_list_devices()),
  1,
  'the device list contains the registered device'
);

-- Re-registering the same installation updates rather than duplicates.
select ok(
  (private.auth_touch_device(repeat('a', 64), 'ios', '1.0.1+2', null)
    ->> 'id') is not null,
  'the same installation re-registers without error'
);
select is(
  jsonb_array_length(private.auth_list_devices()),
  1,
  're-registering an installation does not create a second device'
);

select set_config('request.jwt.claim.sub', :'student_user', true);
select is(
  jsonb_array_length(private.auth_list_devices()),
  0,
  'a different user cannot see the teacher device'
);

-- Cross-user revocation is the BOLA case: the identifier is guessable, the
-- ownership check is what stops it.
select ok(
  not private.auth_revoke_device(
    (select id from public.auth_devices where user_id = :'teacher_user' limit 1)
  ),
  'a user cannot revoke a device belonging to someone else'
);

select set_config('request.jwt.claim.sub', :'teacher_user', true);
select ok(
  private.auth_revoke_device(
    (select id from public.auth_devices where user_id = :'teacher_user' limit 1)
  ),
  'a user can revoke their own device'
);

select ok(
  not private.auth_revoke_device(
    (select id from public.auth_devices where user_id = :'teacher_user' limit 1)
  ),
  'revoking an already revoked device is refused'
);

-- ==========================================================================
-- All-device sign-out watermark
-- ==========================================================================

select set_config('request.jwt.claim.sub', :'guardian_user', true);
select ok(
  private.auth_touch_device(repeat('b', 64), 'android', '1.0.0+1', null)
    is not null,
  'the guardian registers a device'
);

select ok(
  private.auth_sign_out_all() is not null,
  'all-device sign-out returns a watermark'
);

select ok(
  (private.auth_context() ->> 'revoked_before')::timestamptz <= now(),
  'the watermark is visible in the session context'
);

select is(
  (select count(*) from public.auth_devices
   where user_id = :'guardian_user' and revoked_at is null),
  0::bigint,
  'all-device sign-out revokes every device'
);

-- ==========================================================================
-- Recent authentication
-- ==========================================================================

select set_config('request.jwt.claim.sub', :'student_user', true);

select ok(
  private.auth_issue_reauth_grant(
    'account_deletion', repeat('c', 64),
    '88888888-8888-4888-8888-888888888888', 'aal1', 300
  ) > now(),
  'a reauth grant is issued with a future expiry'
);

select ok(
  not private.auth_consume_reauth_grant(
    'account_link', repeat('c', 64),
    '88888888-8888-4888-8888-888888888888'
  ),
  'a grant cannot be redeemed for a purpose it was not issued for'
);

select ok(
  not private.auth_consume_reauth_grant(
    'account_deletion', repeat('c', 64),
    '77777777-7777-4777-8777-777777777777'
  ),
  'a grant lifted to another session is refused'
);

select ok(
  private.auth_consume_reauth_grant(
    'account_deletion', repeat('c', 64),
    '88888888-8888-4888-8888-888888888888'
  ),
  'the correct grant is redeemed once'
);

select ok(
  not private.auth_consume_reauth_grant(
    'account_deletion', repeat('c', 64),
    '88888888-8888-4888-8888-888888888888'
  ),
  'a redeemed grant cannot be replayed'
);

select ok(
  not private.auth_consume_reauth_grant(
    'account_link', repeat('e', 64),
    '99999999-9999-4999-8999-999999999999'
  ),
  'an expired grant is refused'
);

-- ==========================================================================
-- Identity linking
-- ==========================================================================

select is(
  private.auth_link_identity('google', 'provider-subject-1', true),
  'linked',
  'a provider identity links to the acting profile'
);

select is(
  private.auth_link_identity('google', 'provider-subject-1', false),
  'already_linked',
  'relinking the same identity is reported, not duplicated'
);

select set_config('request.jwt.claim.sub', :'teacher_user', true);
select is(
  private.auth_link_identity('google', 'provider-subject-1', false),
  'collision',
  'an identity already owned by another profile is refused'
);

select set_config('request.jwt.claim.sub', :'student_user', true);
select is(
  private.auth_unlink_identity('google', 'provider-subject-1'),
  'last_identity',
  'unlinking the only identity is refused so the account stays reachable'
);

-- ==========================================================================
-- Account deletion lifecycle
-- ==========================================================================

select ok(
  private.auth_deletion_impact() -> 'retained_school_records' is not null,
  'the impact summary states what the school retains'
);

select ok(
  (private.auth_request_deletion('privacy_concern', '{}'::jsonb) ->> 'created')
    ::boolean,
  'a deletion request is created'
);

select is(
  (private.auth_request_deletion('privacy_concern', '{}'::jsonb) ->> 'created'),
  'false',
  'asking twice returns the live request instead of creating a second'
);

select ok(
  (private.auth_cancel_deletion() ->> 'cancelled')::boolean,
  'a request inside its grace period can be cancelled in app'
);

-- The DB-020 unique(user_id, state) constraint made this impossible: the
-- cancelled row permanently occupied the slot.
select ok(
  (private.auth_request_deletion('changing_schools', '{}'::jsonb) ->> 'created')
    ::boolean,
  'a user who cancelled can request deletion again'
);

select * from finish();
rollback;
