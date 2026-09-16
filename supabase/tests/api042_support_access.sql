begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(20);

select ok(
  has_function_privilege('studafy_api_runtime', 'private.api042_command(text,uuid,jsonb,uuid,bigint)', 'execute')
  and has_function_privilege('studafy_api_runtime', 'private.api042_query(text,uuid,jsonb)', 'execute'),
  'runtime can execute the support-access query and command entry points'
);

create temporary table api042_sup_results(name text primary key, result jsonb);

-- --------------------------------------------------------------------------
-- requestSupportAccess
-- --------------------------------------------------------------------------

select set_config('request.jwt.claim.sub', :'teacher_user', true);
select set_config('studafy.school_id', '', true);
select set_config('studafy.request_id', 'api042-request-support-not-operator', true);
insert into api042_sup_results values('request-not-operator-reservation', private.api_idempotency_reserve(
  null, 'v1.requestSupportAccess', 'api042-request-not-op-1', repeat('a', 64)));
insert into api042_sup_results values('request-not-operator', private.api042_command(
  'requestSupportAccess', null, jsonb_build_object('responseStatus', 201, 'aal2', true, 'body', jsonb_build_object(
    'schoolId', :'school_id', 'reason', 'Investigating a support ticket', 'ticketRef', 'TICK-1')),
  ((select result->>'id' from api042_sup_results where name = 'request-not-operator-reservation')::uuid), 1));
select is((select result->>'outcome' from api042_sup_results where name = 'request-not-operator'), 'forbidden',
  'a non-operator cannot request support access');

select set_config('request.jwt.claim.sub', :'operator_a', true);
select set_config('studafy.request_id', 'api042-request-support-no-mfa', true);
insert into api042_sup_results values('request-no-mfa-reservation', private.api_idempotency_reserve(
  null, 'v1.requestSupportAccess', 'api042-request-no-mfa-1', repeat('b', 64)));
insert into api042_sup_results values('request-no-mfa', private.api042_command(
  'requestSupportAccess', null, jsonb_build_object('responseStatus', 201, 'aal2', false, 'body', jsonb_build_object(
    'schoolId', :'school_id', 'reason', 'Investigating a support ticket', 'ticketRef', 'TICK-2')),
  ((select result->>'id' from api042_sup_results where name = 'request-no-mfa-reservation')::uuid), 1));
select is((select result->>'outcome' from api042_sup_results where name = 'request-no-mfa'), 'forbidden',
  'an operator session that never presented a second factor cannot request support access');

select set_config('studafy.request_id', 'api042-request-support', true);
insert into api042_sup_results values('request-reservation', private.api_idempotency_reserve(
  null, 'v1.requestSupportAccess', 'api042-request-key-01', repeat('c', 64)));
insert into api042_sup_results values('request', private.api042_command(
  'requestSupportAccess', null, jsonb_build_object('responseStatus', 201, 'aal2', true, 'body', jsonb_build_object(
    'schoolId', :'school_id', 'reason', 'Investigating a support ticket', 'ticketRef', 'TICK-3', 'durationMinutes', 60)),
  ((select result->>'id' from api042_sup_results where name = 'request-reservation')::uuid), 1));
select is((select result->>'outcome' from api042_sup_results where name = 'request'), 'ok',
  'a platform operator with a verified second factor requests support access');
select is((select result->'response'->>'status' from api042_sup_results where name = 'request'), 'pending',
  'a fresh request starts pending');
select (result->'response'->>'id')::uuid as grant_id from api042_sup_results where name = 'request' \gset

-- approve/start/revoke/list all act within the school, so the session tenant
-- must match the school_id every reservation below is made against - it was
-- left at '' (matching requestSupportAccess's tenant-less reservations)
-- until now.
select set_config('studafy.school_id', :'school_id', true);

-- --------------------------------------------------------------------------
-- approveSupportAccess: two-person rule.
-- --------------------------------------------------------------------------

select set_config('studafy.request_id', 'api042-approve-self', true);
insert into api042_sup_results values('approve-self-reservation', private.api_idempotency_reserve(
  :'school_id', 'v1.approveSupportAccess', 'api042-approve-self-1', repeat('d', 64)));
insert into api042_sup_results values('approve-self', private.api042_command(
  'approveSupportAccess', :'grant_id', jsonb_build_object('responseStatus', 200, 'aal2', true, 'body', jsonb_build_object('expectedVersion', 1)),
  ((select result->>'id' from api042_sup_results where name = 'approve-self-reservation')::uuid), 1));
select is((select result->>'outcome' from api042_sup_results where name = 'approve-self'), 'forbidden',
  'the requester cannot approve their own request');

select set_config('request.jwt.claim.sub', :'operator_b', true);
select set_config('studafy.request_id', 'api042-approve-no-mfa', true);
insert into api042_sup_results values('approve-no-mfa-reservation', private.api_idempotency_reserve(
  :'school_id', 'v1.approveSupportAccess', 'api042-approve-no-mfa-1', repeat('e', 64)));
insert into api042_sup_results values('approve-no-mfa', private.api042_command(
  'approveSupportAccess', :'grant_id', jsonb_build_object('responseStatus', 200, 'aal2', false, 'body', jsonb_build_object('expectedVersion', 1)),
  ((select result->>'id' from api042_sup_results where name = 'approve-no-mfa-reservation')::uuid), 1));
select is((select result->>'outcome' from api042_sup_results where name = 'approve-no-mfa'), 'forbidden',
  'a second approver without a verified second factor cannot approve');

select set_config('studafy.request_id', 'api042-approve-stale', true);
insert into api042_sup_results values('approve-stale-reservation', private.api_idempotency_reserve(
  :'school_id', 'v1.approveSupportAccess', 'api042-approve-stale-1', repeat('f', 64)));
insert into api042_sup_results values('approve-stale', private.api042_command(
  'approveSupportAccess', :'grant_id', jsonb_build_object('responseStatus', 200, 'aal2', true, 'body', jsonb_build_object('expectedVersion', 99)),
  ((select result->>'id' from api042_sup_results where name = 'approve-stale-reservation')::uuid), 1));
select is((select result->>'outcome' from api042_sup_results where name = 'approve-stale'), 'version_conflict',
  'approving with a stale expectedVersion is rejected');

select set_config('studafy.request_id', 'api042-approve', true);
insert into api042_sup_results values('approve-reservation', private.api_idempotency_reserve(
  :'school_id', 'v1.approveSupportAccess', 'api042-approve-key-01', repeat('0', 64)));
insert into api042_sup_results values('approve', private.api042_command(
  'approveSupportAccess', :'grant_id', jsonb_build_object('responseStatus', 200, 'aal2', true, 'body', jsonb_build_object('expectedVersion', 1)),
  ((select result->>'id' from api042_sup_results where name = 'approve-reservation')::uuid), 1));
select is((select result->'response'->>'status' from api042_sup_results where name = 'approve'), 'approved',
  'a different operator with a verified second factor approves the request');

select set_config('studafy.request_id', 'api042-approve-again', true);
insert into api042_sup_results values('approve-again-reservation', private.api_idempotency_reserve(
  :'school_id', 'v1.approveSupportAccess', 'api042-approve-again-1', repeat('1', 64)));
insert into api042_sup_results values('approve-again', private.api042_command(
  'approveSupportAccess', :'grant_id', jsonb_build_object('responseStatus', 200, 'aal2', true, 'body', jsonb_build_object('expectedVersion', 2)),
  ((select result->>'id' from api042_sup_results where name = 'approve-again-reservation')::uuid), 1));
select is((select result->>'outcome' from api042_sup_results where name = 'approve-again'), 'invalid_state',
  'an already-approved request cannot be approved again');

-- --------------------------------------------------------------------------
-- startSupportAccess: only the original requester.
-- --------------------------------------------------------------------------

select set_config('studafy.request_id', 'api042-start-wrong-actor', true);
insert into api042_sup_results values('start-wrong-reservation', private.api_idempotency_reserve(
  :'school_id', 'v1.startSupportAccess', 'api042-start-wrong-1', repeat('2', 64)));
insert into api042_sup_results values('start-wrong', private.api042_command(
  'startSupportAccess', :'grant_id', jsonb_build_object('responseStatus', 200, 'aal2', true, 'body', jsonb_build_object('expectedVersion', 2)),
  ((select result->>'id' from api042_sup_results where name = 'start-wrong-reservation')::uuid), 1));
select is((select result->>'outcome' from api042_sup_results where name = 'start-wrong'), 'forbidden',
  'the approving operator cannot start the session; only the original requester can');

select set_config('request.jwt.claim.sub', :'operator_a', true);
select set_config('studafy.request_id', 'api042-start', true);
insert into api042_sup_results values('start-reservation', private.api_idempotency_reserve(
  :'school_id', 'v1.startSupportAccess', 'api042-start-key-01', repeat('3', 64)));
insert into api042_sup_results values('start', private.api042_command(
  'startSupportAccess', :'grant_id', jsonb_build_object('responseStatus', 200, 'aal2', true, 'body', jsonb_build_object('expectedVersion', 2)),
  ((select result->>'id' from api042_sup_results where name = 'start-reservation')::uuid), 1));
select is((select result->'response'->>'status' from api042_sup_results where name = 'start'), 'active',
  'the original requester starts the approved session');
select ok((select started_at from public.support_access_grants where id = :'grant_id') is not null,
  'startedAt is recorded');

-- --------------------------------------------------------------------------
-- revokeSupportAccess
-- --------------------------------------------------------------------------

select set_config('request.jwt.claim.sub', :'teacher_user', true);
select set_config('studafy.request_id', 'api042-revoke-denied', true);
insert into api042_sup_results values('revoke-denied-reservation', private.api_idempotency_reserve(
  :'school_id', 'v1.revokeSupportAccess', 'api042-revoke-denied-1', repeat('4', 64)));
insert into api042_sup_results values('revoke-denied', private.api042_command(
  'revokeSupportAccess', :'grant_id', jsonb_build_object('responseStatus', 200, 'body', jsonb_build_object('expectedVersion', 3)),
  ((select result->>'id' from api042_sup_results where name = 'revoke-denied-reservation')::uuid), 1));
select is((select result->>'outcome' from api042_sup_results where name = 'revoke-denied'), 'forbidden',
  'an ordinary teacher cannot revoke a support-access grant');

select set_config('request.jwt.claim.sub', :'admin_user', true);
select set_config('studafy.request_id', 'api042-revoke', true);
insert into api042_sup_results values('revoke-reservation', private.api_idempotency_reserve(
  :'school_id', 'v1.revokeSupportAccess', 'api042-revoke-key-01', repeat('5', 64)));
insert into api042_sup_results values('revoke', private.api042_command(
  'revokeSupportAccess', :'grant_id', jsonb_build_object('responseStatus', 200, 'body', jsonb_build_object(
    'expectedVersion', 3, 'reason', 'Investigation complete')),
  ((select result->>'id' from api042_sup_results where name = 'revoke-reservation')::uuid), 1));
select is((select result->'response'->>'status' from api042_sup_results where name = 'revoke'), 'revoked',
  'the school''s own admin revokes the active session');
select ok((select ended_at from public.support_access_grants where id = :'grant_id') is not null,
  'endedAt is recorded on revoke');

select set_config('studafy.request_id', 'api042-revoke-again', true);
insert into api042_sup_results values('revoke-again-reservation', private.api_idempotency_reserve(
  :'school_id', 'v1.revokeSupportAccess', 'api042-revoke-again-1', repeat('6', 64)));
insert into api042_sup_results values('revoke-again', private.api042_command(
  'revokeSupportAccess', :'grant_id', jsonb_build_object('responseStatus', 200, 'body', jsonb_build_object('expectedVersion', 4)),
  ((select result->>'id' from api042_sup_results where name = 'revoke-again-reservation')::uuid), 1));
select is((select result->>'outcome' from api042_sup_results where name = 'revoke-again'), 'invalid_state',
  'an already-revoked grant cannot be revoked again');

-- --------------------------------------------------------------------------
-- listSupportAccessGrants
-- --------------------------------------------------------------------------

select set_config('request.jwt.claim.sub', :'teacher_user', true);
select is(private.api042_query('listSupportAccessGrants', :'school_id', '{}'::jsonb)->>'outcome', 'forbidden',
  'an ordinary teacher cannot list support-access grants');

select set_config('request.jwt.claim.sub', :'admin_user', true);
select ok(
  (private.api042_query('listSupportAccessGrants', :'school_id', '{}'::jsonb)->'items')::text like '%' || :'grant_id' || '%',
  'the school admin lists the grant'
);

-- --------------------------------------------------------------------------
-- Lazy expiry: a stale pending request is expired before a new one can be
-- read as still live, the same honest OPS-061-shaped gap S2 documents.
-- --------------------------------------------------------------------------

select set_config('request.jwt.claim.sub', :'operator_b', true);
select set_config('studafy.school_id', '', true);
select set_config('studafy.request_id', 'api042-request-support-expiring', true);
insert into api042_sup_results values('request-expiring-reservation', private.api_idempotency_reserve(
  null, 'v1.requestSupportAccess', 'api042-request-expiring-1', repeat('7', 64)));
insert into api042_sup_results values('request-expiring', private.api042_command(
  'requestSupportAccess', null, jsonb_build_object('responseStatus', 201, 'aal2', true, 'body', jsonb_build_object(
    'schoolId', :'school_id', 'reason', 'Second investigation', 'ticketRef', 'TICK-4', 'durationMinutes', 1)),
  ((select result->>'id' from api042_sup_results where name = 'request-expiring-reservation')::uuid), 1));
select (result->'response'->>'id')::uuid as expiring_grant_id from api042_sup_results where name = 'request-expiring' \gset
update public.support_access_grants set created_at = now() - interval '2 minutes', expires_at = now() - interval '1 minute'
where id = :'expiring_grant_id';

select set_config('studafy.request_id', 'api042-request-support-triggers-expiry', true);
insert into api042_sup_results values('request-trigger-reservation', private.api_idempotency_reserve(
  null, 'v1.requestSupportAccess', 'api042-request-trigger-1', repeat('8', 64)));
insert into api042_sup_results values('request-trigger', private.api042_command(
  'requestSupportAccess', null, jsonb_build_object('responseStatus', 201, 'aal2', true, 'body', jsonb_build_object(
    'schoolId', :'school_id', 'reason', 'Third investigation', 'ticketRef', 'TICK-5')),
  ((select result->>'id' from api042_sup_results where name = 'request-trigger-reservation')::uuid), 1));
select is((select status from public.support_access_grants where id = :'expiring_grant_id'), 'expired',
  'a stale pending grant is lazily expired the next time this school''s grants are touched');

select * from finish();
rollback;
