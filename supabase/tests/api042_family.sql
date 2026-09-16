begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(21);

select ok(
  has_function_privilege('studafy_api_runtime', 'private.api042_command(text,uuid,jsonb,uuid,bigint)', 'execute'),
  'runtime can execute the family command entry point'
);

create temporary table api042_fam_results(name text primary key, result jsonb);

-- --------------------------------------------------------------------------
-- locateStudent: uniform shape, rate-limited.
-- --------------------------------------------------------------------------

select set_config('request.jwt.claim.sub', :'second_guardian', true);
select set_config('studafy.school_id', '', true);
select set_config('studafy.request_id', 'api042-locate-found', true);
insert into api042_fam_results values('locate-found-reservation', private.api_idempotency_reserve(
  null, 'v1.locateStudent', 'api042-locate-found-1', repeat('a', 64)));
insert into api042_fam_results values('locate-found', private.api042_command(
  'locateStudent', null, jsonb_build_object('responseStatus', 200, 'body', jsonb_build_object('studafyId', 'STU-SEED-0001')),
  ((select result->>'id' from api042_fam_results where name = 'locate-found-reservation')::uuid), 1));
select is((select result->'response'->>'found' from api042_fam_results where name = 'locate-found'), 'true',
  'locating an existing student''s code succeeds');
select is((select result->'response'->>'studentId' from api042_fam_results where name = 'locate-found'), :'student_id',
  'the located student matches the seeded fixture');

select set_config('studafy.request_id', 'api042-locate-missing', true);
insert into api042_fam_results values('locate-missing-reservation', private.api_idempotency_reserve(
  null, 'v1.locateStudent', 'api042-locate-missing-1', repeat('b', 64)));
insert into api042_fam_results values('locate-missing', private.api042_command(
  'locateStudent', null, jsonb_build_object('responseStatus', 200, 'body', jsonb_build_object('studafyId', 'STU-DOES-NOT-EXIST')),
  ((select result->>'id' from api042_fam_results where name = 'locate-missing-reservation')::uuid), 1));
select is((select result->'response'->>'found' from api042_fam_results where name = 'locate-missing'), 'false',
  'locating a nonexistent code reports not found');
select is(
  (select array(select jsonb_object_keys(result->'response')) from api042_fam_results where name = 'locate-found') =
  (select array(select jsonb_object_keys(result->'response')) from api042_fam_results where name = 'locate-missing'),
  true, 'the found and not-found responses share exactly the same shape'
);

-- Two attempts already spent above; eight more reaches the ten-per-hour cap.
do $fill$
declare i int; reservation jsonb;
begin
  for i in 1..8 loop
    perform set_config('studafy.request_id', 'api042-locate-fill-' || i, true);
    reservation := private.api_idempotency_reserve(
      null, 'v1.locateStudent', 'api042-locate-fill-key-' || i, repeat('c', 64));
    perform private.api042_command(
      'locateStudent', null, jsonb_build_object('responseStatus', 200, 'body', jsonb_build_object('studafyId', 'STU-SEED-0001')),
      (reservation->>'id')::uuid, 1);
  end loop;
end;
$fill$;

select set_config('studafy.request_id', 'api042-locate-throttled', true);
insert into api042_fam_results values('locate-throttled-reservation', private.api_idempotency_reserve(
  null, 'v1.locateStudent', 'api042-locate-throttled-1', repeat('e', 64)));
insert into api042_fam_results values('locate-throttled', private.api042_command(
  'locateStudent', null, jsonb_build_object('responseStatus', 200, 'body', jsonb_build_object('studafyId', 'STU-SEED-0001')),
  ((select result->>'id' from api042_fam_results where name = 'locate-throttled-reservation')::uuid), 1));
select is((select result->>'outcome' from api042_fam_results where name = 'locate-throttled'), 'invalid_state',
  'the tenth locator attempt in an hour is throttled');

-- --------------------------------------------------------------------------
-- requestGuardianLink
-- --------------------------------------------------------------------------

select set_config('studafy.request_id', 'api042-request-link', true);
insert into api042_fam_results values('request-link-reservation', private.api_idempotency_reserve(
  null, 'v1.requestGuardianLink', 'api042-request-link-1', repeat('f', 64)));
insert into api042_fam_results values('request-link', private.api042_command(
  'requestGuardianLink', null, jsonb_build_object('responseStatus', 201, 'body', jsonb_build_object(
    'studentId', :'student_id', 'relationship', 'aunt')),
  ((select result->>'id' from api042_fam_results where name = 'request-link-reservation')::uuid), 1));
select is((select result->'response'->>'status' from api042_fam_results where name = 'request-link'), 'pending',
  'a new guardian link request starts pending');
select (result->'response'->>'id')::uuid as second_guardian_link_id from api042_fam_results where name = 'request-link' \gset

select set_config('studafy.request_id', 'api042-request-link-dup', true);
insert into api042_fam_results values('request-link-dup-reservation', private.api_idempotency_reserve(
  null, 'v1.requestGuardianLink', 'api042-request-link-dup-1', repeat('0', 64)));
insert into api042_fam_results values('request-link-dup', private.api042_command(
  'requestGuardianLink', null, jsonb_build_object('responseStatus', 201, 'body', jsonb_build_object(
    'studentId', :'student_id', 'relationship', 'aunt')),
  ((select result->>'id' from api042_fam_results where name = 'request-link-dup-reservation')::uuid), 1));
select is((select result->>'outcome' from api042_fam_results where name = 'request-link-dup'), 'invalid',
  'requesting a link that is already pending is rejected');

select is(private.api_idempotency_reserve(null, 'v1.requestGuardianLink', 'api042-request-link-1', repeat('f', 64))->>'outcome',
  'replay', 'a retried link request replays the stored response rather than creating a duplicate');

-- --------------------------------------------------------------------------
-- verifyGuardianLink
-- --------------------------------------------------------------------------

select set_config('request.jwt.claim.sub', :'teacher_user', true);
select set_config('studafy.school_id', :'school_id', true);
select set_config('studafy.request_id', 'api042-verify-denied', true);
insert into api042_fam_results values('verify-denied-reservation', private.api_idempotency_reserve(
  :'school_id', 'v1.verifyGuardianLink', 'api042-verify-denied-1', repeat('1', 64)));
insert into api042_fam_results values('verify-denied', private.api042_command(
  'verifyGuardianLink', :'second_guardian_link_id', jsonb_build_object('responseStatus', 200, 'body', '{}'::jsonb),
  ((select result->>'id' from api042_fam_results where name = 'verify-denied-reservation')::uuid), 1));
select is((select result->>'outcome' from api042_fam_results where name = 'verify-denied'), 'forbidden',
  'a teacher cannot verify a guardian link');

select set_config('request.jwt.claim.sub', :'admin_user', true);
select set_config('studafy.request_id', 'api042-verify', true);
insert into api042_fam_results values('verify-reservation', private.api_idempotency_reserve(
  :'school_id', 'v1.verifyGuardianLink', 'api042-verify-key-01', repeat('2', 64)));
insert into api042_fam_results values('verify', private.api042_command(
  'verifyGuardianLink', :'second_guardian_link_id', jsonb_build_object('responseStatus', 200, 'body', jsonb_build_object('expiresInDays', 30)),
  ((select result->>'id' from api042_fam_results where name = 'verify-reservation')::uuid), 1));
select is((select result->'response'->>'status' from api042_fam_results where name = 'verify'), 'verified',
  'a school admin verifies a pending guardian link');
select ok(
  (select expires_at from public.guardian_links where id = :'second_guardian_link_id') > now() + interval '29 days',
  'verification sets a future expiry from the requested window'
);

select set_config('studafy.request_id', 'api042-verify-again', true);
insert into api042_fam_results values('verify-again-reservation', private.api_idempotency_reserve(
  :'school_id', 'v1.verifyGuardianLink', 'api042-verify-again-1', repeat('3', 64)));
insert into api042_fam_results values('verify-again', private.api042_command(
  'verifyGuardianLink', :'second_guardian_link_id', jsonb_build_object('responseStatus', 200, 'body', '{}'::jsonb),
  ((select result->>'id' from api042_fam_results where name = 'verify-again-reservation')::uuid), 1));
select is((select result->>'outcome' from api042_fam_results where name = 'verify-again'), 'invalid_state',
  'an already-verified link cannot be verified again');

-- --------------------------------------------------------------------------
-- revokeGuardianLink
-- --------------------------------------------------------------------------

select set_config('request.jwt.claim.sub', :'second_guardian', true);
select set_config('studafy.request_id', 'api042-revoke-own-link', true);
insert into api042_fam_results values('revoke-own-reservation', private.api_idempotency_reserve(
  :'school_id', 'v1.revokeGuardianLink', 'api042-revoke-own-1', repeat('4', 64)));
insert into api042_fam_results values('revoke-own', private.api042_command(
  'revokeGuardianLink', :'second_guardian_link_id', jsonb_build_object('responseStatus', 200, 'body', '{}'::jsonb),
  ((select result->>'id' from api042_fam_results where name = 'revoke-own-reservation')::uuid), 1));
select is((select result->'response'->>'status' from api042_fam_results where name = 'revoke-own'), 'revoked',
  'a guardian revokes their own verified link');

select set_config('request.jwt.claim.sub', :'teacher_user', true);
select set_config('studafy.request_id', 'api042-revoke-others-denied', true);
insert into api042_fam_results values('revoke-others-reservation', private.api_idempotency_reserve(
  :'school_id', 'v1.revokeGuardianLink', 'api042-revoke-others-1', repeat('5', 64)));
insert into api042_fam_results values('revoke-others', private.api042_command(
  'revokeGuardianLink', :'second_guardian_link_id', jsonb_build_object('responseStatus', 200, 'body', '{}'::jsonb),
  ((select result->>'id' from api042_fam_results where name = 'revoke-others-reservation')::uuid), 1));
select is((select result->>'outcome' from api042_fam_results where name = 'revoke-others'), 'forbidden',
  'a non-admin non-owner cannot revoke a link that is not theirs, regardless of its current state');

-- Cross-school: other_school_user cannot revoke a link belonging to school_id.
select set_config('request.jwt.claim.sub', :'other_school_user', true);
select set_config('studafy.school_id', :'other_school_id', true);
select set_config('studafy.request_id', 'api042-revoke-cross-school', true);
insert into api042_fam_results values('revoke-cross-reservation', private.api_idempotency_reserve(
  :'other_school_id', 'v1.revokeGuardianLink', 'api042-revoke-cross-1', repeat('6', 64)));
insert into api042_fam_results values('revoke-cross', private.api042_command(
  'revokeGuardianLink', :'second_guardian_link_id', jsonb_build_object('responseStatus', 200, 'body', '{}'::jsonb),
  ((select result->>'id' from api042_fam_results where name = 'revoke-cross-reservation')::uuid), 1));
select is((select result->>'outcome' from api042_fam_results where name = 'revoke-cross'), 'forbidden',
  'a different school''s member cannot touch this guardian link at all');

-- Re-request after revoke: the table-wide unique(student_id, guardian_id)
-- constraint means this must reactivate the same row, not insert a new one.
select set_config('request.jwt.claim.sub', :'second_guardian', true);
select set_config('studafy.school_id', '', true);
select set_config('studafy.request_id', 'api042-re-request-link', true);
insert into api042_fam_results values('re-request-reservation', private.api_idempotency_reserve(
  null, 'v1.requestGuardianLink', 'api042-re-request-key-1', repeat('7', 64)));
insert into api042_fam_results values('re-request', private.api042_command(
  'requestGuardianLink', null, jsonb_build_object('responseStatus', 201, 'body', jsonb_build_object(
    'studentId', :'student_id', 'relationship', 'aunt')),
  ((select result->>'id' from api042_fam_results where name = 're-request-reservation')::uuid), 1));
select is((select result->'response'->>'status' from api042_fam_results where name = 're-request'), 'pending',
  'a revoked link can be re-requested and reactivates as pending');
select is((select result->'response'->>'id' from api042_fam_results where name = 're-request'), :'second_guardian_link_id'::text,
  'the re-request reuses the same row rather than creating a second one');
select is(
  (select count(*) from public.guardian_links where student_id = :'student_id' and guardian_id = :'second_guardian'),
  1::bigint, 'exactly one guardian_links row exists for this pair regardless of how many times it was requested/revoked');

-- The shared fixture's already-verified link (guardian_user) and
-- already-pending unverified link (unverified_guardian) are untouched by
-- any of the above.
select is((select status::text from public.guardian_links where student_id = :'student_id' and guardian_id = :'guardian_user'),
  'verified', 'the shared fixture''s pre-verified guardian link is unaffected');
select is((select status::text from public.guardian_links where student_id = :'student_id' and guardian_id = :'unverified_guardian'),
  'pending', 'the shared fixture''s pre-pending guardian link is unaffected');

select * from finish();
rollback;
