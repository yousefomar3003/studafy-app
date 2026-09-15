begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(45);

select ok(
  has_function_privilege('studafy_api_runtime', 'private.api042_command(text,uuid,jsonb,uuid,bigint)', 'execute'),
  'runtime can execute the school-operations command entry point'
);
select ok(
  not has_function_privilege('authenticated', 'private.api042_command(text,uuid,jsonb,uuid,bigint)', 'execute'),
  'mobile authenticated role cannot invoke the command function directly'
);

create temporary table api042_results(name text primary key, result jsonb);

-- --------------------------------------------------------------------------
-- provisionSchool: platform-operator only, no client-selected ownership.
-- --------------------------------------------------------------------------

select set_config('request.jwt.claim.sub', :'admin_user', true);
select set_config('studafy.request_id', 'api042-provision-denied', true);
insert into api042_results values('provision-denied-reservation', private.api_idempotency_reserve(
  null, 'v1.provisionSchool', 'api042-provision-denied-1', repeat('a', 64)));
insert into api042_results values('provision-denied', private.api042_command(
  'provisionSchool', null, jsonb_build_object('responseStatus', 201, 'body', jsonb_build_object(
    'name', 'Rogue School', 'initialAdminUserId', :'admin_user')),
  ((select result->>'id' from api042_results where name = 'provision-denied-reservation')::uuid), 1));
select is((select result->>'outcome' from api042_results where name = 'provision-denied'), 'forbidden',
  'an ordinary school admin cannot provision a new school');

select set_config('request.jwt.claim.sub', :'operator_user', true);
select set_config('studafy.request_id', 'api042-provision-invalid', true);
insert into api042_results values('provision-invalid-reservation', private.api_idempotency_reserve(
  null, 'v1.provisionSchool', 'api042-provision-invalid-1', repeat('b', 64)));
insert into api042_results values('provision-invalid', private.api042_command(
  'provisionSchool', null, jsonb_build_object('responseStatus', 201, 'body', jsonb_build_object(
    'name', 'Ghost School', 'initialAdminUserId', '99999999-0000-4000-8000-000000000099')),
  ((select result->>'id' from api042_results where name = 'provision-invalid-reservation')::uuid), 1));
select is((select result->>'outcome' from api042_results where name = 'provision-invalid'), 'invalid',
  'provisioning refuses a designated admin that has no profile');

select set_config('studafy.request_id', 'api042-provision', true);
insert into api042_results values('provision-reservation', private.api_idempotency_reserve(
  null, 'v1.provisionSchool', 'api042-provision-key-01', repeat('c', 64)));
insert into api042_results values('provision', private.api042_command(
  'provisionSchool', null, jsonb_build_object('responseStatus', 201, 'body', jsonb_build_object(
    'name', 'Fresh Approved School', 'timezone', 'Asia/Riyadh', 'locale', 'en',
    'initialAdminUserId', :'second_teacher')),
  ((select result->>'id' from api042_results where name = 'provision-reservation')::uuid), 1));
select is((select result->>'outcome' from api042_results where name = 'provision'), 'ok',
  'a platform operator provisions a fresh school');
select is((select result->'response'->>'status' from api042_results where name = 'provision'), 'active',
  'a provisioned school is immediately active, not stuck in a manual activation step');
select is((select result->'response'->>'version' from api042_results where name = 'provision'), '1',
  'a fresh school starts at version 1');

select (result->'response'->>'id')::uuid as new_school_id from api042_results where name = 'provision' \gset
select is(
  (select role::text from public.memberships where school_id = :'new_school_id' and user_id = :'second_teacher'),
  'school_admin', 'the designated admin receives an active school_admin membership atomically with provisioning');
select is(
  (select count(*) from public.membership_events me
   join public.memberships m on m.id = me.membership_id
   where m.school_id = :'new_school_id' and me.event_type = 'granted'),
  1::bigint, 'provisioning writes exactly one membership-granted event');

select is(private.api_idempotency_reserve(null, 'v1.provisionSchool', 'api042-provision-key-01', repeat('c', 64))->>'outcome',
  'replay', 'a retried provisioning request replays the stored response rather than creating a second school');

-- --------------------------------------------------------------------------
-- suspendSchool / closeSchool
-- --------------------------------------------------------------------------

select set_config('request.jwt.claim.sub', :'second_teacher', true);
select set_config('studafy.school_id', :'new_school_id', true);
select set_config('studafy.request_id', 'api042-suspend-stale', true);
insert into api042_results values('suspend-stale-reservation', private.api_idempotency_reserve(
  :'new_school_id', 'v1.suspendSchool', 'api042-suspend-stale-1', repeat('d', 64)));
insert into api042_results values('suspend-stale', private.api042_command(
  'suspendSchool', :'new_school_id', jsonb_build_object('responseStatus', 200, 'body', jsonb_build_object('expectedVersion', 99)),
  ((select result->>'id' from api042_results where name = 'suspend-stale-reservation')::uuid), 1));
select is((select result->>'outcome' from api042_results where name = 'suspend-stale'), 'version_conflict',
  'suspending with a stale expectedVersion is rejected');

-- Simulated ID-substitution attack: the actor is only admin of new_school_id
-- (so a middleware bug could resolve tenant to it), but the resourceId names
-- a different school entirely. The command must refuse on its own.
select set_config('studafy.request_id', 'api042-suspend-substitution', true);
insert into api042_results values('suspend-sub-reservation', private.api_idempotency_reserve(
  :'new_school_id', 'v1.suspendSchool', 'api042-suspend-sub-1', repeat('e', 64)));
insert into api042_results values('suspend-sub', private.api042_command(
  'suspendSchool', :'school_id', jsonb_build_object('responseStatus', 200, 'body', jsonb_build_object('expectedVersion', 1)),
  ((select result->>'id' from api042_results where name = 'suspend-sub-reservation')::uuid), 1));
select is((select result->>'outcome' from api042_results where name = 'suspend-sub'), 'forbidden',
  'a resourceId naming a different school than the resolved tenant is refused, not silently retargeted');
select is((select status::text from public.schools where id = :'school_id'), 'active',
  'the substitution attempt never touched the unrelated school');

select set_config('studafy.request_id', 'api042-suspend', true);
insert into api042_results values('suspend-reservation', private.api_idempotency_reserve(
  :'new_school_id', 'v1.suspendSchool', 'api042-suspend-key-01', repeat('f', 64)));
insert into api042_results values('suspend', private.api042_command(
  'suspendSchool', :'new_school_id', jsonb_build_object('responseStatus', 200, 'body', jsonb_build_object('expectedVersion', 1)),
  ((select result->>'id' from api042_results where name = 'suspend-reservation')::uuid), 1));
select is((select result->'response'->>'status' from api042_results where name = 'suspend'), 'suspended',
  'the school admin can suspend their own school');
select is((select result->'response'->>'version' from api042_results where name = 'suspend'), '2',
  'suspension bumps the optimistic version');

-- Once suspended, has_active_membership (and therefore is_school_admin)
-- cannot see the school's own admin anymore -- the school itself is no
-- longer 'active'. This is intentional: suspension is a platform-level
-- restriction that a school's own admin cannot self-service around: only a
-- platform operator can close (or, in future work, reinstate) it from here.
select set_config('studafy.request_id', 'api042-close-denied', true);
insert into api042_results values('close-denied-reservation', private.api_idempotency_reserve(
  :'new_school_id', 'v1.closeSchool', 'api042-close-denied-1', repeat('0', 64)));
insert into api042_results values('close-denied', private.api042_command(
  'closeSchool', :'new_school_id', jsonb_build_object('responseStatus', 200, 'body', jsonb_build_object('expectedVersion', 2)),
  ((select result->>'id' from api042_results where name = 'close-denied-reservation')::uuid), 1));
select is((select result->>'outcome' from api042_results where name = 'close-denied'), 'forbidden',
  'a suspended school''s own admin cannot close it; only a platform operator can act on a non-active school');

select set_config('request.jwt.claim.sub', :'operator_user', true);
select set_config('studafy.request_id', 'api042-operator-close', true);
insert into api042_results values('operator-close-reservation', private.api_idempotency_reserve(
  :'new_school_id', 'v1.closeSchool', 'api042-operator-close-1', repeat('1', 64)));
insert into api042_results values('operator-close', private.api042_command(
  'closeSchool', :'new_school_id', jsonb_build_object('responseStatus', 200, 'body', jsonb_build_object('expectedVersion', 2)),
  ((select result->>'id' from api042_results where name = 'operator-close-reservation')::uuid), 1));
select is((select result->'response'->>'status' from api042_results where name = 'operator-close'), 'closed',
  'a platform operator closes the suspended school');

select set_config('studafy.request_id', 'api042-suspend-after-close', true);
insert into api042_results values('suspend-after-close-reservation', private.api_idempotency_reserve(
  :'new_school_id', 'v1.suspendSchool', 'api042-suspend-after-close-1', repeat('2', 64)));
insert into api042_results values('suspend-after-close', private.api042_command(
  'suspendSchool', :'new_school_id', jsonb_build_object('responseStatus', 200, 'body', jsonb_build_object('expectedVersion', 3)),
  ((select result->>'id' from api042_results where name = 'suspend-after-close-reservation')::uuid), 1));
select is((select result->>'outcome' from api042_results where name = 'suspend-after-close'), 'invalid_state',
  'a closed school cannot be suspended, even by a platform operator');

-- The 'operator-close' assertion above already proves the platform-operator
-- override: operator_user holds no membership at all in new_school_id, yet
-- closed it, so the operator-without-membership path is covered without
-- mutating the shared school_id fixture other tests below still depend on.

-- --------------------------------------------------------------------------
-- grantMembership
-- --------------------------------------------------------------------------

select set_config('request.jwt.claim.sub', :'teacher_user', true);
select set_config('studafy.school_id', :'school_id', true);
select set_config('studafy.request_id', 'api042-grant-denied', true);
insert into api042_results values('grant-denied-reservation', private.api_idempotency_reserve(
  :'school_id', 'v1.grantMembership', 'api042-grant-denied-1', repeat('3', 64)));
insert into api042_results values('grant-denied', private.api042_command(
  'grantMembership', :'school_id', jsonb_build_object('responseStatus', 201, 'body', jsonb_build_object(
    'userId', :'second_teacher', 'role', 'school_admin')),
  ((select result->>'id' from api042_results where name = 'grant-denied-reservation')::uuid), 1));
select is((select result->>'outcome' from api042_results where name = 'grant-denied'), 'forbidden',
  'a non-admin teacher cannot grant memberships');

select set_config('request.jwt.claim.sub', :'admin_user', true);
select set_config('studafy.request_id', 'api042-grant-unknown', true);
insert into api042_results values('grant-unknown-reservation', private.api_idempotency_reserve(
  :'school_id', 'v1.grantMembership', 'api042-grant-unknown-1', repeat('4', 64)));
insert into api042_results values('grant-unknown', private.api042_command(
  'grantMembership', :'school_id', jsonb_build_object('responseStatus', 201, 'body', jsonb_build_object(
    'userId', :'fresh_student_user', 'role', 'teacher')),
  ((select result->>'id' from api042_results where name = 'grant-unknown-reservation')::uuid), 1));
select is((select result->>'outcome' from api042_results where name = 'grant-unknown'), 'invalid_state',
  'grantMembership refuses someone with no existing membership in the school; onboarding uses invitations instead');

select set_config('studafy.request_id', 'api042-grant', true);
insert into api042_results values('grant-reservation', private.api_idempotency_reserve(
  :'school_id', 'v1.grantMembership', 'api042-grant-key-01', repeat('5', 64)));
insert into api042_results values('grant', private.api042_command(
  'grantMembership', :'school_id', jsonb_build_object('responseStatus', 201, 'body', jsonb_build_object(
    'userId', :'teacher_user', 'role', 'school_admin')),
  ((select result->>'id' from api042_results where name = 'grant-reservation')::uuid), 1));
select is((select result->>'outcome' from api042_results where name = 'grant'), 'ok',
  'an admin grants an additional role to an existing member');
select (result->'response'->>'id')::uuid as second_admin_membership from api042_results where name = 'grant' \gset

select set_config('studafy.request_id', 'api042-grant-duplicate', true);
insert into api042_results values('grant-dup-reservation', private.api_idempotency_reserve(
  :'school_id', 'v1.grantMembership', 'api042-grant-dup-1', repeat('6', 64)));
insert into api042_results values('grant-dup', private.api042_command(
  'grantMembership', :'school_id', jsonb_build_object('responseStatus', 201, 'body', jsonb_build_object(
    'userId', :'teacher_user', 'role', 'school_admin')),
  ((select result->>'id' from api042_results where name = 'grant-dup-reservation')::uuid), 1));
select is((select result->>'outcome' from api042_results where name = 'grant-dup'), 'invalid',
  'granting a role the member already actively holds is rejected');

-- --------------------------------------------------------------------------
-- membership lifecycle: activate / suspend / revoke, including the
-- last-active-admin guard.
-- --------------------------------------------------------------------------

select (id) as teacher_membership_id from public.memberships
  where school_id = :'school_id' and user_id = :'teacher_user' and role = 'teacher' \gset

select set_config('studafy.request_id', 'api042-suspend-membership', true);
insert into api042_results values('suspend-mem-reservation', private.api_idempotency_reserve(
  :'school_id', 'v1.suspendMembership', 'api042-suspend-mem-1', repeat('7', 64)));
insert into api042_results values('suspend-mem', private.api042_command(
  'suspendMembership', :'teacher_membership_id', jsonb_build_object('responseStatus', 200, 'body', jsonb_build_object('expectedVersion', 1)),
  ((select result->>'id' from api042_results where name = 'suspend-mem-reservation')::uuid), 1));
select is((select result->'response'->>'status' from api042_results where name = 'suspend-mem'), 'suspended',
  'an admin suspends a member');
select is((select count(*) from public.membership_events where membership_id = :'teacher_membership_id' and event_type = 'suspended'),
  1::bigint, 'suspension writes a membership event');

select set_config('studafy.request_id', 'api042-activate-membership', true);
insert into api042_results values('activate-mem-reservation', private.api_idempotency_reserve(
  :'school_id', 'v1.activateMembership', 'api042-activate-mem-1', repeat('8', 64)));
insert into api042_results values('activate-mem', private.api042_command(
  'activateMembership', :'teacher_membership_id', jsonb_build_object('responseStatus', 200, 'body', jsonb_build_object('expectedVersion', 2)),
  ((select result->>'id' from api042_results where name = 'activate-mem-reservation')::uuid), 1));
select is((select result->'response'->>'status' from api042_results where name = 'activate-mem'), 'active',
  'a suspended member is reactivated');

-- Now revoke the newly granted second admin, leaving admin_user as the sole
-- active school_admin, then prove that sole admin cannot be revoked.
select set_config('studafy.request_id', 'api042-revoke-second-admin', true);
insert into api042_results values('revoke-second-admin-reservation', private.api_idempotency_reserve(
  :'school_id', 'v1.revokeMembership', 'api042-revoke-second-admin-1', repeat('9', 64)));
insert into api042_results values('revoke-second-admin', private.api042_command(
  'revokeMembership', :'second_admin_membership', jsonb_build_object('responseStatus', 200, 'body', jsonb_build_object('expectedVersion', 1)),
  ((select result->>'id' from api042_results where name = 'revoke-second-admin-reservation')::uuid), 1));
select is((select result->>'outcome' from api042_results where name = 'revoke-second-admin'), 'ok',
  'the second admin can be revoked while another active admin remains');

select (id) as admin_membership_id from public.memberships
  where school_id = :'school_id' and user_id = :'admin_user' and role = 'school_admin' \gset
select set_config('studafy.request_id', 'api042-revoke-last-admin', true);
insert into api042_results values('revoke-last-reservation', private.api_idempotency_reserve(
  :'school_id', 'v1.revokeMembership', 'api042-revoke-last-1', repeat('a', 64)));
insert into api042_results values('revoke-last', private.api042_command(
  'revokeMembership', :'admin_membership_id', jsonb_build_object('responseStatus', 200, 'body', jsonb_build_object('expectedVersion', 1)),
  ((select result->>'id' from api042_results where name = 'revoke-last-reservation')::uuid), 1));
select is((select result->>'outcome' from api042_results where name = 'revoke-last'), 'invalid_state',
  'a school can never be left with zero active admins through this path');
select is((select status::text from public.memberships where id = :'admin_membership_id'), 'active',
  'the blocked revoke attempt left the sole admin membership untouched');

-- --------------------------------------------------------------------------
-- classroom staffing
-- --------------------------------------------------------------------------

select set_config('request.jwt.claim.sub', :'second_teacher', true);
select set_config('studafy.request_id', 'api042-assign-staff-denied', true);
insert into api042_results values('assign-denied-reservation', private.api_idempotency_reserve(
  :'school_id', 'v1.assignClassroomStaff', 'api042-assign-denied-1', repeat('b', 64)));
insert into api042_results values('assign-denied', private.api042_command(
  'assignClassroomStaff', :'classroom_id', jsonb_build_object('responseStatus', 201, 'body', jsonb_build_object(
    'userId', :'second_teacher', 'role', 'co_teacher')),
  ((select result->>'id' from api042_results where name = 'assign-denied-reservation')::uuid), 1));
select is((select result->>'outcome' from api042_results where name = 'assign-denied'), 'forbidden',
  'staff not assigned to the classroom cannot assign themselves to it');

select set_config('request.jwt.claim.sub', :'admin_user', true);
select set_config('studafy.request_id', 'api042-assign-staff', true);
insert into api042_results values('assign-reservation', private.api_idempotency_reserve(
  :'school_id', 'v1.assignClassroomStaff', 'api042-assign-key-01', repeat('c', 64)));
insert into api042_results values('assign', private.api042_command(
  'assignClassroomStaff', :'classroom_id', jsonb_build_object('responseStatus', 201, 'body', jsonb_build_object(
    'userId', :'second_teacher', 'role', 'co_teacher')),
  ((select result->>'id' from api042_results where name = 'assign-reservation')::uuid), 1));
select is((select result->>'outcome' from api042_results where name = 'assign'), 'ok',
  'a school admin assigns a co-teacher to a classroom');
select (result->'response'->>'id')::uuid as co_teacher_staff_id from api042_results where name = 'assign' \gset

select set_config('studafy.request_id', 'api042-assign-staff-dup', true);
insert into api042_results values('assign-dup-reservation', private.api_idempotency_reserve(
  :'school_id', 'v1.assignClassroomStaff', 'api042-assign-dup-1', repeat('d', 64)));
insert into api042_results values('assign-dup', private.api042_command(
  'assignClassroomStaff', :'classroom_id', jsonb_build_object('responseStatus', 201, 'body', jsonb_build_object(
    'userId', :'second_teacher', 'role', 'co_teacher')),
  ((select result->>'id' from api042_results where name = 'assign-dup-reservation')::uuid), 1));
select is((select result->>'outcome' from api042_results where name = 'assign-dup'), 'invalid',
  'assigning the same active staff role twice is rejected');

select (id) as lead_staff_id from public.classroom_staff
  where classroom_id = :'classroom_id' and user_id = :'teacher_user' and role = 'lead_teacher' \gset
select set_config('studafy.request_id', 'api042-remove-sole-lead', true);
insert into api042_results values('remove-sole-lead-reservation', private.api_idempotency_reserve(
  :'school_id', 'v1.removeClassroomStaff', 'api042-remove-sole-lead-1', repeat('e', 64)));
insert into api042_results values('remove-sole-lead', private.api042_command(
  'removeClassroomStaff', :'classroom_id', jsonb_build_object('responseStatus', 200, 'body', jsonb_build_object(
    'staffAssignmentId', :'lead_staff_id')),
  ((select result->>'id' from api042_results where name = 'remove-sole-lead-reservation')::uuid), 1));
select is((select result->>'outcome' from api042_results where name = 'remove-sole-lead'), 'invalid_state',
  'the sole active lead teacher of a classroom cannot be removed');

select set_config('studafy.request_id', 'api042-remove-co-teacher', true);
insert into api042_results values('remove-co-reservation', private.api_idempotency_reserve(
  :'school_id', 'v1.removeClassroomStaff', 'api042-remove-co-key-1', repeat('f', 64)));
insert into api042_results values('remove-co', private.api042_command(
  'removeClassroomStaff', :'classroom_id', jsonb_build_object('responseStatus', 200, 'body', jsonb_build_object(
    'staffAssignmentId', :'co_teacher_staff_id')),
  ((select result->>'id' from api042_results where name = 'remove-co-reservation')::uuid), 1));
select is((select result->'response'->>'status' from api042_results where name = 'remove-co'), 'ended',
  'a co-teacher assignment is removed');

select set_config('studafy.request_id', 'api042-remove-wrong-classroom', true);
insert into api042_results values('remove-wrong-reservation', private.api_idempotency_reserve(
  :'school_id', 'v1.removeClassroomStaff', 'api042-remove-wrong-1', repeat('1', 64)));
insert into api042_results values('remove-wrong', private.api042_command(
  'removeClassroomStaff', :'second_classroom_id', jsonb_build_object('responseStatus', 200, 'body', jsonb_build_object(
    'staffAssignmentId', :'lead_staff_id')),
  ((select result->>'id' from api042_results where name = 'remove-wrong-reservation')::uuid), 1));
select is((select result->>'outcome' from api042_results where name = 'remove-wrong'), 'not_found',
  'a staff-assignment id from a different classroom cannot be removed through it');

-- --------------------------------------------------------------------------
-- enrollment transitions
-- --------------------------------------------------------------------------

select set_config('studafy.request_id', 'api042-enroll', true);
insert into api042_results values('enroll-reservation', private.api_idempotency_reserve(
  :'school_id', 'v1.enrollStudent', 'api042-enroll-key-01', repeat('2', 64)));
insert into api042_results values('enroll', private.api042_command(
  'enrollStudent', :'classroom_id', jsonb_build_object('responseStatus', 200, 'body', jsonb_build_object(
    'studentId', :'fresh_student_id')),
  ((select result->>'id' from api042_results where name = 'enroll-reservation')::uuid), 1));
select is((select result->'response'->>'status' from api042_results where name = 'enroll'), 'active',
  'a school admin enrolls a previously unenrolled student');

select set_config('studafy.request_id', 'api042-enroll-dup', true);
insert into api042_results values('enroll-dup-reservation', private.api_idempotency_reserve(
  :'school_id', 'v1.enrollStudent', 'api042-enroll-dup-1', repeat('3', 64)));
insert into api042_results values('enroll-dup', private.api042_command(
  'enrollStudent', :'classroom_id', jsonb_build_object('responseStatus', 200, 'body', jsonb_build_object(
    'studentId', :'fresh_student_id')),
  ((select result->>'id' from api042_results where name = 'enroll-dup-reservation')::uuid), 1));
select is((select result->>'outcome' from api042_results where name = 'enroll-dup'), 'invalid',
  'enrolling an already-active student in the same classroom is rejected');

select set_config('studafy.request_id', 'api042-withdraw', true);
insert into api042_results values('withdraw-reservation', private.api_idempotency_reserve(
  :'school_id', 'v1.withdrawStudent', 'api042-withdraw-key-1', repeat('4', 64)));
insert into api042_results values('withdraw', private.api042_command(
  'withdrawStudent', :'classroom_id', jsonb_build_object('responseStatus', 200, 'body', jsonb_build_object(
    'studentId', :'fresh_student_id')),
  ((select result->>'id' from api042_results where name = 'withdraw-reservation')::uuid), 1));
select is((select result->'response'->>'status' from api042_results where name = 'withdraw'), 'withdrawn',
  'a student is withdrawn from a classroom');

select set_config('studafy.request_id', 'api042-re-enroll', true);
insert into api042_results values('re-enroll-reservation', private.api_idempotency_reserve(
  :'school_id', 'v1.enrollStudent', 'api042-re-enroll-key-1', repeat('5', 64)));
insert into api042_results values('re-enroll', private.api042_command(
  'enrollStudent', :'classroom_id', jsonb_build_object('responseStatus', 200, 'body', jsonb_build_object(
    'studentId', :'fresh_student_id')),
  ((select result->>'id' from api042_results where name = 're-enroll-reservation')::uuid), 1));
select is((select result->'response'->>'status' from api042_results where name = 're-enroll'), 'active',
  're-enrolling a withdrawn student reactivates the same enrollment row through the conflict path');

select set_config('studafy.request_id', 'api042-transfer', true);
insert into api042_results values('transfer-reservation', private.api_idempotency_reserve(
  :'school_id', 'v1.transferEnrollment', 'api042-transfer-key-1', repeat('6', 64)));
insert into api042_results values('transfer', private.api042_command(
  'transferEnrollment', :'classroom_id', jsonb_build_object('responseStatus', 200, 'body', jsonb_build_object(
    'studentId', :'fresh_student_id', 'targetClassroomId', :'second_classroom_id')),
  ((select result->>'id' from api042_results where name = 'transfer-reservation')::uuid), 1));
select is((select result->'response'->>'classroomId' from api042_results where name = 'transfer'), :'second_classroom_id',
  'the student transfers into the target classroom');
select is(
  (select status::text from public.enrollments where classroom_id = :'classroom_id' and student_id = :'fresh_student_id'),
  'withdrawn', 'the source classroom enrollment is withdrawn by the transfer');
select is(
  (select status::text from public.enrollments where classroom_id = :'second_classroom_id' and student_id = :'fresh_student_id'),
  'active', 'the target classroom enrollment is active after the transfer');

select set_config('studafy.request_id', 'api042-transfer-not-found', true);
insert into api042_results values('transfer-missing-reservation', private.api_idempotency_reserve(
  :'school_id', 'v1.transferEnrollment', 'api042-transfer-missing-1', repeat('7', 64)));
insert into api042_results values('transfer-missing', private.api042_command(
  'transferEnrollment', :'second_classroom_id', jsonb_build_object('responseStatus', 200, 'body', jsonb_build_object(
    'studentId', :'fresh_student_id', 'targetClassroomId', '99999999-0000-4000-8000-000000000098')),
  ((select result->>'id' from api042_results where name = 'transfer-missing-reservation')::uuid), 1));
select is((select result->>'outcome' from api042_results where name = 'transfer-missing'), 'not_found',
  'transferring into a classroom that does not exist in this school is rejected');

-- --------------------------------------------------------------------------
-- Transactional integrity: a forced audit-log failure rolls back the whole
-- command, same guarantee API-041 proved for its own dispatcher.
-- --------------------------------------------------------------------------

create function pg_temp.reject_api042_audit() returns trigger language plpgsql as $$
begin
  if new.request_id = 'api042-force-audit' then raise exception 'API042_FORCED_AUDIT'; end if;
  return new;
end $$;
create trigger api042_force_audit before insert on public.audit_events
for each row execute function pg_temp.reject_api042_audit();
select set_config('studafy.request_id', 'api042-force-audit', true);
insert into api042_results values('audit-reservation', private.api_idempotency_reserve(
  :'school_id', 'v1.withdrawStudent', 'api042-audit-key-01', repeat('8', 64)));
create function pg_temp.api042_audit_failure() returns jsonb language sql as $$
  select private.api042_command('withdrawStudent', 'f0420000-0000-4000-8000-000000000005',
    jsonb_build_object('responseStatus', 200, 'body', jsonb_build_object('studentId', 'f0420000-0000-4000-8000-000000000004')),
    ((select result->>'id' from api042_results where name = 'audit-reservation')::uuid), 1)
$$;
select throws_ok('select pg_temp.api042_audit_failure()', 'API042_FORCED_AUDIT', 'forced audit failure escapes the command');
select is(
  (select status::text from public.enrollments where classroom_id = :'second_classroom_id' and student_id = :'fresh_student_id'),
  'active', 'audit failure rolls back the withdrawal (the student stays enrolled, unchanged)');
select is((select status from public.idempotency_records where id = ((select result->>'id' from api042_results where name = 'audit-reservation')::uuid)),
  'reserved', 'audit failure also rolls back idempotency completion');
drop trigger api042_force_audit on public.audit_events;

select * from finish();
rollback;
