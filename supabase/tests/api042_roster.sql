begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(12);

select ok(
  has_function_privilege('studafy_api_runtime', 'private.api042_command(text,uuid,jsonb,uuid,bigint)', 'execute'),
  'runtime can execute the roster command entry point'
);

create temporary table api042_roster_results(name text primary key, result jsonb);

-- --------------------------------------------------------------------------
-- createTerm
-- --------------------------------------------------------------------------

select set_config('request.jwt.claim.sub', :'teacher_user', true);
select set_config('studafy.school_id', :'school_id', true);
select set_config('studafy.request_id', 'api042-roster-term-not-admin', true);
insert into api042_roster_results values('term-not-admin-reservation', private.api_idempotency_reserve(
  :'school_id', 'v1.createTerm', 'api042-roster-term-not-admin-1', repeat('a', 64)));
insert into api042_roster_results values('term-not-admin', private.api042_command(
  'createTerm', null, jsonb_build_object('responseStatus', 201, 'body', jsonb_build_object(
    'name', 'Rogue Term', 'startsOn', '2026-09-01', 'endsOn', '2026-12-31')),
  ((select result->>'id' from api042_roster_results where name = 'term-not-admin-reservation')::uuid), 1));
select is((select result->>'outcome' from api042_roster_results where name = 'term-not-admin'), 'forbidden',
  'a teacher cannot create a term');

select set_config('request.jwt.claim.sub', :'admin_user', true);
select set_config('studafy.school_id', :'fresh_school_id', true);
select set_config('studafy.request_id', 'api042-roster-term-fresh-school', true);
insert into api042_roster_results values('term-fresh-reservation', private.api_idempotency_reserve(
  :'fresh_school_id', 'v1.createTerm', 'api042-roster-term-fresh-1', repeat('b', 64)));
insert into api042_roster_results values('term-fresh', private.api042_command(
  'createTerm', null, jsonb_build_object('responseStatus', 201, 'body', jsonb_build_object(
    'name', 'First Term', 'startsOn', '2026-09-01', 'endsOn', '2026-12-31')),
  ((select result->>'id' from api042_roster_results where name = 'term-fresh-reservation')::uuid), 1));
select is((select result->>'outcome' from api042_roster_results where name = 'term-fresh'), 'ok',
  'a school admin creates a term for a school that had none');
select is((select result->'response'->>'status' from api042_roster_results where name = 'term-fresh'), 'active',
  'the new term starts active');

-- The gap this migration closes: createClassroom used to be permanently
-- unreachable for a school with zero terms (invalid_state). It now succeeds
-- once createTerm has run above, using the term it just created.
select set_config('studafy.request_id', 'api042-roster-classroom-fresh', true);
insert into api042_roster_results values('classroom-fresh-reservation', private.api_idempotency_reserve(
  :'fresh_school_id', 'v1.createClassroom', 'api042-roster-classroom-fresh-1', repeat('9', 64)));
insert into api042_roster_results values('classroom-fresh', private.api041_command(
  'createClassroom', null, jsonb_build_object('responseStatus', 201, 'body', jsonb_build_object(
    'schoolId', :'fresh_school_id', 'name', 'Reviewer Classroom', 'grade', 'G6', 'section', 'A',
    'room', null, 'schedule', '[]'::jsonb)),
  ((select result->>'id' from api042_roster_results where name = 'classroom-fresh-reservation')::uuid), 1));
select is((select result->>'outcome' from api042_roster_results where name = 'classroom-fresh'), 'ok',
  'createClassroom now succeeds for a school that only just got its first term');

-- --------------------------------------------------------------------------
-- createStudent
-- --------------------------------------------------------------------------

select set_config('request.jwt.claim.sub', :'teacher_user', true);
select set_config('studafy.school_id', :'school_id', true);
select set_config('studafy.request_id', 'api042-roster-student-not-admin', true);
insert into api042_roster_results values('student-not-admin-reservation', private.api_idempotency_reserve(
  :'school_id', 'v1.createStudent', 'api042-roster-student-not-admin-1', repeat('c', 64)));
insert into api042_roster_results values('student-not-admin', private.api042_command(
  'createStudent', null, jsonb_build_object('responseStatus', 201, 'body', jsonb_build_object('displayName', 'Rogue Student')),
  ((select result->>'id' from api042_roster_results where name = 'student-not-admin-reservation')::uuid), 1));
select is((select result->>'outcome' from api042_roster_results where name = 'student-not-admin'), 'forbidden',
  'a teacher cannot create a student roster record');

select set_config('request.jwt.claim.sub', :'admin_user', true);
select set_config('studafy.request_id', 'api042-roster-student-provisional', true);
insert into api042_roster_results values('student-provisional-reservation', private.api_idempotency_reserve(
  :'school_id', 'v1.createStudent', 'api042-roster-student-provisional-1', repeat('d', 64)));
insert into api042_roster_results values('student-provisional', private.api042_command(
  'createStudent', null, jsonb_build_object('responseStatus', 201, 'body', jsonb_build_object('displayName', 'Provisional Student')),
  ((select result->>'id' from api042_roster_results where name = 'student-provisional-reservation')::uuid), 1));
select is((select result->>'outcome' from api042_roster_results where name = 'student-provisional'), 'ok',
  'a school admin creates a provisional student with no linked account');
select is((select result->'response'->>'provisional' from api042_roster_results where name = 'student-provisional')::boolean, true,
  'a student created with no userId is provisional');
select ok(
  (select result->'response'->>'studafyId' from api042_roster_results where name = 'student-provisional') ~ '^STU-',
  'the studafy locator is server-generated with the expected prefix'
);

select set_config('studafy.request_id', 'api042-roster-student-linked', true);
insert into api042_roster_results values('student-linked-reservation', private.api_idempotency_reserve(
  :'school_id', 'v1.createStudent', 'api042-roster-student-linked-1', repeat('e', 64)));
insert into api042_roster_results values('student-linked', private.api042_command(
  'createStudent', null, jsonb_build_object('responseStatus', 201, 'body', jsonb_build_object(
    'displayName', 'Linked Student', 'userId', :'student_user')),
  ((select result->>'id' from api042_roster_results where name = 'student-linked-reservation')::uuid), 1));
select is((select result->'response'->>'userId' from api042_roster_results where name = 'student-linked'), :'student_user',
  'a student created with a valid userId is linked to that account');
select is((select result->'response'->>'provisional' from api042_roster_results where name = 'student-linked')::boolean, false,
  'a student created with a userId is not provisional');

select set_config('studafy.request_id', 'api042-roster-student-bad-user', true);
insert into api042_roster_results values('student-bad-user-reservation', private.api_idempotency_reserve(
  :'school_id', 'v1.createStudent', 'api042-roster-student-bad-user-1', repeat('f', 64)));
insert into api042_roster_results values('student-bad-user', private.api042_command(
  'createStudent', null, jsonb_build_object('responseStatus', 201, 'body', jsonb_build_object(
    'displayName', 'Ghost Student', 'userId', '00000000-0000-4000-8000-000000000000')),
  ((select result->>'id' from api042_roster_results where name = 'student-bad-user-reservation')::uuid), 1));
select is((select result->>'outcome' from api042_roster_results where name = 'student-bad-user'), 'invalid',
  'creating a student with a nonexistent userId is rejected');

select * from finish();
rollback;
