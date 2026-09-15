begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(26);

select ok(
  has_function_privilege('studafy_api_runtime', 'private.api042_command(text,uuid,jsonb,uuid,bigint)', 'execute')
  and has_function_privilege('studafy_api_runtime', 'private.api042_query(text,uuid,jsonb)', 'execute'),
  'runtime can execute the invitations query and command entry points'
);
select ok(
  not has_function_privilege('authenticated', 'private.api042_query(text,uuid,jsonb)', 'execute'),
  'mobile authenticated role cannot invoke the query function directly'
);

create temporary table api042_inv_results(name text primary key, result jsonb);

-- --------------------------------------------------------------------------
-- issueInvitation
-- --------------------------------------------------------------------------

select set_config('request.jwt.claim.sub', :'teacher_user', true);
select set_config('studafy.school_id', :'school_id', true);
select set_config('studafy.request_id', 'api042-issue-denied', true);
insert into api042_inv_results values('issue-denied-reservation', private.api_idempotency_reserve(
  :'school_id', 'v1.issueInvitation', 'api042-issue-denied-1', repeat('a', 64)));
insert into api042_inv_results values('issue-denied', private.api042_command(
  'issueInvitation', :'school_id', jsonb_build_object('responseStatus', 201, 'body', jsonb_build_object(
    'email', 'seed.invitee@synthetic.studafy.test', 'role', 'teacher', 'tokenHash', 'fixture-hash-denied')),
  ((select result->>'id' from api042_inv_results where name = 'issue-denied-reservation')::uuid), 1));
select is((select result->>'outcome' from api042_inv_results where name = 'issue-denied'), 'forbidden',
  'a non-admin cannot issue an invitation');

select set_config('request.jwt.claim.sub', :'admin_user', true);
select set_config('studafy.request_id', 'api042-issue', true);
insert into api042_inv_results values('issue-reservation', private.api_idempotency_reserve(
  :'school_id', 'v1.issueInvitation', 'api042-issue-key-01', repeat('b', 64)));
insert into api042_inv_results values('issue', private.api042_command(
  'issueInvitation', :'school_id', jsonb_build_object('responseStatus', 201, 'body', jsonb_build_object(
    'email', 'Seed.Invitee@synthetic.studafy.test', 'role', 'teacher', 'tokenHash', 'fixture-hash-issue-001')),
  ((select result->>'id' from api042_inv_results where name = 'issue-reservation')::uuid), 1));
select is((select result->>'outcome' from api042_inv_results where name = 'issue'), 'ok',
  'a school admin issues an invitation');
select is((select result->'response'->>'status' from api042_inv_results where name = 'issue'), 'pending',
  'a fresh invitation is pending');
select is((select result->'response'->>'email' from api042_inv_results where name = 'issue'), 'seed.invitee@synthetic.studafy.test',
  'the stored email is normalized to lowercase regardless of client casing');
select is((select result->'response' ? 'tokenHash' from api042_inv_results where name = 'issue'), false,
  'the response never echoes the token hash back to the caller');

select (result->'response'->>'id')::uuid as invitation_id from api042_inv_results where name = 'issue' \gset

select set_config('studafy.request_id', 'api042-issue-duplicate', true);
insert into api042_inv_results values('issue-dup-reservation', private.api_idempotency_reserve(
  :'school_id', 'v1.issueInvitation', 'api042-issue-dup-1', repeat('c', 64)));
insert into api042_inv_results values('issue-dup', private.api042_command(
  'issueInvitation', :'school_id', jsonb_build_object('responseStatus', 201, 'body', jsonb_build_object(
    'email', 'seed.invitee@synthetic.studafy.test', 'role', 'teacher', 'tokenHash', 'fixture-hash-issue-002')),
  ((select result->>'id' from api042_inv_results where name = 'issue-dup-reservation')::uuid), 1));
select is((select result->>'outcome' from api042_inv_results where name = 'issue-dup'), 'invalid',
  'a second live invitation for the same school/email/role is rejected');

select is(private.api_idempotency_reserve(:'school_id', 'v1.issueInvitation', 'api042-issue-key-01', repeat('b', 64))->>'outcome',
  'replay', 'a retried issue request replays the stored response rather than creating a second invitation');

-- --------------------------------------------------------------------------
-- listInvitations
-- --------------------------------------------------------------------------

select set_config('request.jwt.claim.sub', :'teacher_user', true);
select is(private.api042_query('listInvitations', :'school_id', '{}'::jsonb)->>'outcome', 'forbidden',
  'a non-admin cannot list invitations');

select set_config('request.jwt.claim.sub', :'admin_user', true);
select ok(
  (private.api042_query('listInvitations', :'school_id', '{}'::jsonb)->'items')::text like '%' || :'invitation_id' || '%',
  'an admin lists the issued invitation'
);

-- --------------------------------------------------------------------------
-- acceptInvitation
-- --------------------------------------------------------------------------

-- acceptInvitation is self-scoped like provisionSchool: no resolved tenant.
select set_config('studafy.school_id', '', true);
select set_config('request.jwt.claim.sub', :'invitee_user', true);
select set_config('studafy.request_id', 'api042-accept-wrong-token', true);
insert into api042_inv_results values('accept-wrong-reservation', private.api_idempotency_reserve(
  null, 'v1.acceptInvitation', 'api042-accept-wrong-1', repeat('d', 64)));
insert into api042_inv_results values('accept-wrong', private.api042_command(
  'acceptInvitation', null, jsonb_build_object('responseStatus', 200, 'body', jsonb_build_object('tokenHash', 'not-a-real-hash')),
  ((select result->>'id' from api042_inv_results where name = 'accept-wrong-reservation')::uuid), 1));
select is((select result->>'outcome' from api042_inv_results where name = 'accept-wrong'), 'not_found',
  'accepting with a token hash that matches nothing is rejected');

select set_config('studafy.request_id', 'api042-accept', true);
insert into api042_inv_results values('accept-reservation', private.api_idempotency_reserve(
  null, 'v1.acceptInvitation', 'api042-accept-key-01', repeat('e', 64)));
insert into api042_inv_results values('accept', private.api042_command(
  'acceptInvitation', null, jsonb_build_object('responseStatus', 200, 'body', jsonb_build_object('tokenHash', 'fixture-hash-issue-001')),
  ((select result->>'id' from api042_inv_results where name = 'accept-reservation')::uuid), 1));
select is((select result->>'outcome' from api042_inv_results where name = 'accept'), 'ok',
  'the invitee accepts the invitation with the correct token hash');
select is((select result->'response'->>'role' from api042_inv_results where name = 'accept'), 'teacher',
  'the created membership carries the invited role');
select is((select result->'response'->>'status' from api042_inv_results where name = 'accept'), 'active',
  'the created membership is immediately active');
select is(
  (select status::text from public.invitations where id = :'invitation_id'),
  'accepted', 'the invitation itself is marked accepted');
select is(
  (select role::text from public.memberships where school_id = :'school_id' and user_id = :'invitee_user'),
  'teacher', 'the invitee now holds a real teacher membership in the school');

select set_config('studafy.request_id', 'api042-accept-again', true);
insert into api042_inv_results values('accept-again-reservation', private.api_idempotency_reserve(
  null, 'v1.acceptInvitation', 'api042-accept-again-1', repeat('f', 64)));
insert into api042_inv_results values('accept-again', private.api042_command(
  'acceptInvitation', null, jsonb_build_object('responseStatus', 200, 'body', jsonb_build_object('tokenHash', 'fixture-hash-issue-001')),
  ((select result->>'id' from api042_inv_results where name = 'accept-again-reservation')::uuid), 1));
select is((select result->>'outcome' from api042_inv_results where name = 'accept-again'), 'invalid_state',
  'the same token cannot be accepted twice');

-- An existing member presented with an invitation is refused, not silently
-- granted a duplicate membership.
select set_config('studafy.school_id', :'school_id', true);
select set_config('request.jwt.claim.sub', :'admin_user', true);
select set_config('studafy.request_id', 'api042-issue-for-existing-member', true);
insert into api042_inv_results values('issue-existing-reservation', private.api_idempotency_reserve(
  :'school_id', 'v1.issueInvitation', 'api042-issue-existing-1', repeat('0', 64)));
insert into api042_inv_results values('issue-existing', private.api042_command(
  'issueInvitation', :'school_id', jsonb_build_object('responseStatus', 201, 'body', jsonb_build_object(
    'email', 'seed.teacher@synthetic.studafy.test', 'role', 'student', 'tokenHash', 'fixture-hash-existing-member')),
  ((select result->>'id' from api042_inv_results where name = 'issue-existing-reservation')::uuid), 1));
select set_config('studafy.school_id', '', true);
select set_config('request.jwt.claim.sub', :'teacher_user', true);
select set_config('studafy.request_id', 'api042-accept-existing-member', true);
insert into api042_inv_results values('accept-existing-reservation', private.api_idempotency_reserve(
  null, 'v1.acceptInvitation', 'api042-accept-existing-1', repeat('1', 64)));
insert into api042_inv_results values('accept-existing', private.api042_command(
  'acceptInvitation', null, jsonb_build_object('responseStatus', 200, 'body', jsonb_build_object('tokenHash', 'fixture-hash-existing-member')),
  ((select result->>'id' from api042_inv_results where name = 'accept-existing-reservation')::uuid), 1));
select is((select result->>'outcome' from api042_inv_results where name = 'accept-existing'), 'invalid_state',
  'an existing member presented with an invitation is refused rather than granted a duplicate membership');
select is(
  (select count(*) from public.memberships where school_id = :'school_id' and user_id = :'teacher_user' and role = 'student'),
  0::bigint, 'no duplicate membership was created for the existing member');

-- Expiry: force an issued invitation into the past, prove it can no longer
-- be accepted, and prove issuing again for the same school/email/role now
-- succeeds because the lazy-expire step frees the live-invite slot.
select set_config('studafy.school_id', :'school_id', true);
select set_config('request.jwt.claim.sub', :'admin_user', true);
select set_config('studafy.request_id', 'api042-issue-expiring', true);
insert into api042_inv_results values('issue-expiring-reservation', private.api_idempotency_reserve(
  :'school_id', 'v1.issueInvitation', 'api042-issue-expiring-1', repeat('2', 64)));
insert into api042_inv_results values('issue-expiring', private.api042_command(
  'issueInvitation', :'school_id', jsonb_build_object('responseStatus', 201, 'body', jsonb_build_object(
    'email', 'seed.expiring@synthetic.studafy.test', 'role', 'teacher', 'tokenHash', 'fixture-hash-expiring')),
  ((select result->>'id' from api042_inv_results where name = 'issue-expiring-reservation')::uuid), 1));
update public.invitations set created_at = now() - interval '2 hours', expires_at = now() - interval '1 hour'
where token_hash = 'fixture-hash-expiring';

select set_config('studafy.school_id', '', true);
select set_config('request.jwt.claim.sub', :'invitee_user', true);
select set_config('studafy.request_id', 'api042-accept-expired', true);
insert into api042_inv_results values('accept-expired-reservation', private.api_idempotency_reserve(
  null, 'v1.acceptInvitation', 'api042-accept-expired-1', repeat('3', 64)));
insert into api042_inv_results values('accept-expired', private.api042_command(
  'acceptInvitation', null, jsonb_build_object('responseStatus', 200, 'body', jsonb_build_object('tokenHash', 'fixture-hash-expiring')),
  ((select result->>'id' from api042_inv_results where name = 'accept-expired-reservation')::uuid), 1));
select is((select result->>'outcome' from api042_inv_results where name = 'accept-expired'), 'invalid_state',
  'an expired invitation cannot be accepted');

select set_config('studafy.school_id', :'school_id', true);
select set_config('request.jwt.claim.sub', :'admin_user', true);
select set_config('studafy.request_id', 'api042-issue-after-expiry', true);
insert into api042_inv_results values('issue-after-expiry-reservation', private.api_idempotency_reserve(
  :'school_id', 'v1.issueInvitation', 'api042-issue-after-expiry-1', repeat('4', 64)));
insert into api042_inv_results values('issue-after-expiry', private.api042_command(
  'issueInvitation', :'school_id', jsonb_build_object('responseStatus', 201, 'body', jsonb_build_object(
    'email', 'seed.expiring@synthetic.studafy.test', 'role', 'teacher', 'tokenHash', 'fixture-hash-reissued')),
  ((select result->>'id' from api042_inv_results where name = 'issue-after-expiry-reservation')::uuid), 1));
select is((select result->>'outcome' from api042_inv_results where name = 'issue-after-expiry'), 'ok',
  'a lazily-expired invitation frees the live-invite slot for a fresh one');

-- --------------------------------------------------------------------------
-- revokeInvitation
-- --------------------------------------------------------------------------

select set_config('request.jwt.claim.sub', :'teacher_user', true);
select set_config('studafy.request_id', 'api042-revoke-denied', true);
insert into api042_inv_results values('revoke-denied-reservation', private.api_idempotency_reserve(
  :'school_id', 'v1.revokeInvitation', 'api042-revoke-denied-1', repeat('5', 64)));
insert into api042_inv_results values('revoke-denied', private.api042_command(
  'revokeInvitation', (select result->'response'->>'id' from api042_inv_results where name = 'issue-after-expiry')::uuid,
  jsonb_build_object('responseStatus', 200, 'body', '{}'::jsonb),
  ((select result->>'id' from api042_inv_results where name = 'revoke-denied-reservation')::uuid), 1));
select is((select result->>'outcome' from api042_inv_results where name = 'revoke-denied'), 'forbidden',
  'a non-admin cannot revoke an invitation');

select set_config('request.jwt.claim.sub', :'admin_user', true);
select set_config('studafy.request_id', 'api042-revoke', true);
insert into api042_inv_results values('revoke-reservation', private.api_idempotency_reserve(
  :'school_id', 'v1.revokeInvitation', 'api042-revoke-key-01', repeat('6', 64)));
insert into api042_inv_results values('revoke', private.api042_command(
  'revokeInvitation', (select result->'response'->>'id' from api042_inv_results where name = 'issue-after-expiry')::uuid,
  jsonb_build_object('responseStatus', 200, 'body', '{}'::jsonb),
  ((select result->>'id' from api042_inv_results where name = 'revoke-reservation')::uuid), 1));
select is((select result->'response'->>'status' from api042_inv_results where name = 'revoke'), 'revoked',
  'a school admin revokes a pending invitation');

select set_config('studafy.request_id', 'api042-revoke-again', true);
insert into api042_inv_results values('revoke-again-reservation', private.api_idempotency_reserve(
  :'school_id', 'v1.revokeInvitation', 'api042-revoke-again-1', repeat('7', 64)));
insert into api042_inv_results values('revoke-again', private.api042_command(
  'revokeInvitation', (select result->'response'->>'id' from api042_inv_results where name = 'issue-after-expiry')::uuid,
  jsonb_build_object('responseStatus', 200, 'body', '{}'::jsonb),
  ((select result->>'id' from api042_inv_results where name = 'revoke-again-reservation')::uuid), 1));
select is((select result->>'outcome' from api042_inv_results where name = 'revoke-again'), 'invalid_state',
  'an already-revoked invitation cannot be revoked again');

select set_config('studafy.school_id', :'other_school_id', true);
select set_config('request.jwt.claim.sub', :'other_school_user', true);
select set_config('studafy.request_id', 'api042-revoke-cross-school', true);
insert into api042_inv_results values('revoke-cross-reservation', private.api_idempotency_reserve(
  :'other_school_id', 'v1.revokeInvitation', 'api042-revoke-cross-1', repeat('8', 64)));
insert into api042_inv_results values('revoke-cross', private.api042_command(
  'revokeInvitation', :'invitation_id',
  jsonb_build_object('responseStatus', 200, 'body', '{}'::jsonb),
  ((select result->>'id' from api042_inv_results where name = 'revoke-cross-reservation')::uuid), 1));
select is((select result->>'outcome' from api042_inv_results where name = 'revoke-cross'), 'forbidden',
  'a different school''s admin cannot revoke an invitation belonging to another school');

select * from finish();
rollback;
