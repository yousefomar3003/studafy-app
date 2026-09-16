begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(20);

select ok(
  has_function_privilege('studafy_api_runtime', 'private.api042_command(text,uuid,jsonb,uuid,bigint)', 'execute')
  and has_function_privilege('studafy_api_runtime', 'private.api042_query(text,uuid,jsonb)', 'execute'),
  'runtime can execute the meetings query and command entry points'
);
select ok(
  has_function_privilege('studafy_worker_runtime', 'private.meeting_recipient_emails(uuid)', 'execute')
  and not has_function_privilege('studafy_api_runtime', 'private.meeting_recipient_emails(uuid)', 'execute'),
  'only the worker role can bulk-resolve recipient emails; the ordinary API role never can'
);

create temporary table api042_meet_results(name text primary key, result jsonb);

-- --------------------------------------------------------------------------
-- requestMeeting: one set-based recipient resolution, not a per-student
-- guardian lookup followed by a per-recipient loop.
-- --------------------------------------------------------------------------

select set_config('request.jwt.claim.sub', :'student_user', true);
select set_config('studafy.school_id', :'school_id', true);
select set_config('studafy.request_id', 'api042-request-meeting-denied', true);
insert into api042_meet_results values('request-denied-reservation', private.api_idempotency_reserve(
  :'school_id', 'v1.requestMeeting', 'api042-request-denied-1', repeat('a', 64)));
insert into api042_meet_results values('request-denied', private.api042_command(
  'requestMeeting', :'classroom_id', jsonb_build_object('responseStatus', 201, 'body', jsonb_build_object(
    'title', 'Rogue meeting', 'startsAt', (now() + interval '1 day'), 'endsAt', (now() + interval '1 day 30 minutes'))),
  ((select result->>'id' from api042_meet_results where name = 'request-denied-reservation')::uuid), 1));
select is((select result->>'outcome' from api042_meet_results where name = 'request-denied'), 'forbidden',
  'a student cannot request a meeting');

select set_config('request.jwt.claim.sub', :'teacher_user', true);
select set_config('studafy.request_id', 'api042-request-meeting-both', true);
insert into api042_meet_results values('request-both-reservation', private.api_idempotency_reserve(
  :'school_id', 'v1.requestMeeting', 'api042-request-both-1', repeat('b', 64)));
insert into api042_meet_results values('request-both', private.api042_command(
  'requestMeeting', :'classroom_id', jsonb_build_object('responseStatus', 201, 'body', jsonb_build_object(
    'title', 'Parent-teacher conference', 'startsAt', (now() + interval '1 day'), 'endsAt', (now() + interval '1 day 30 minutes'),
    'audience', 'both')),
  ((select result->>'id' from api042_meet_results where name = 'request-both-reservation')::uuid), 1));
select is((select result->>'outcome' from api042_meet_results where name = 'request-both'), 'ok',
  'the classroom''s lead teacher requests a meeting');
-- The shared db021 fixture adds its own extra enrolled student and
-- co-teacher to this same classroom, plus a verified-but-expired guardian
-- link, so the exact total here is fixture-wide, not just this file's own
-- additions: 3 students + 2 currently-verified guardians + 2 staff = 7,
-- with the 2 unverified and 1 expired guardian all correctly excluded.
select is((select result->'response'->>'recipientCount' from api042_meet_results where name = 'request-both'), '7',
  'audience=both excludes the 2 unverified guardians and the 1 expired-but-verified guardian');
select (result->'response'->>'id')::uuid as meeting_both_id from api042_meet_results where name = 'request-both' \gset
select is(
  (select count(*) from public.meeting_deliveries where meeting_id = :'meeting_both_id' and recipient_id in (:'unverified_guardian', :'third_guardian_unverified')),
  0::bigint, 'unverified guardians never receive a meeting delivery row'
);
select is(
  (select count(*) from public.meeting_deliveries where meeting_id = :'meeting_both_id' and state = 'queued'),
  7::bigint, 'every resolved recipient starts in the queued delivery state'
);
select is(
  (select count(*) from public.meeting_deliveries where meeting_id = :'meeting_both_id' and recipient_id = :'expired_guardian_user'),
  0::bigint, 'a verified but expired guardian link is excluded from the meeting delivery list'
);

select set_config('studafy.request_id', 'api042-request-meeting-guardians', true);
insert into api042_meet_results values('request-guardians-reservation', private.api_idempotency_reserve(
  :'school_id', 'v1.requestMeeting', 'api042-request-guardians-1', repeat('c', 64)));
insert into api042_meet_results values('request-guardians', private.api042_command(
  'requestMeeting', :'classroom_id', jsonb_build_object('responseStatus', 201, 'body', jsonb_build_object(
    'title', 'Guardians only', 'startsAt', (now() + interval '2 day'), 'endsAt', (now() + interval '2 day 30 minutes'),
    'audience', 'guardians')),
  ((select result->>'id' from api042_meet_results where name = 'request-guardians-reservation')::uuid), 1));
select is((select result->'response'->>'recipientCount' from api042_meet_results where name = 'request-guardians'), '4',
  'audience=guardians resolves the 2 currently-verified guardians plus the classroom''s 2 staff, no students');
select (result->'response'->>'id')::uuid as meeting_guardians_id from api042_meet_results where name = 'request-guardians' \gset

select set_config('studafy.request_id', 'api042-request-meeting-invalid-times', true);
insert into api042_meet_results values('request-invalid-reservation', private.api_idempotency_reserve(
  :'school_id', 'v1.requestMeeting', 'api042-request-invalid-1', repeat('d', 64)));
insert into api042_meet_results values('request-invalid', private.api042_command(
  'requestMeeting', :'classroom_id', jsonb_build_object('responseStatus', 201, 'body', jsonb_build_object(
    'title', 'Backwards', 'startsAt', (now() + interval '1 day'), 'endsAt', now())),
  ((select result->>'id' from api042_meet_results where name = 'request-invalid-reservation')::uuid), 1));
select is((select result->>'outcome' from api042_meet_results where name = 'request-invalid'), 'invalid',
  'a meeting ending before it starts is rejected');

select is(private.api_idempotency_reserve(:'school_id', 'v1.requestMeeting', 'api042-request-both-1', repeat('b', 64))->>'outcome',
  'replay', 'retrying the same request replays the stored response rather than creating a second meeting');

-- --------------------------------------------------------------------------
-- cancelMeeting
-- --------------------------------------------------------------------------

select set_config('request.jwt.claim.sub', :'other_school_user', true);
select set_config('studafy.school_id', :'other_school_id', true);
select set_config('studafy.request_id', 'api042-cancel-cross-school', true);
insert into api042_meet_results values('cancel-cross-reservation', private.api_idempotency_reserve(
  :'other_school_id', 'v1.cancelMeeting', 'api042-cancel-cross-1', repeat('e', 64)));
insert into api042_meet_results values('cancel-cross', private.api042_command(
  'cancelMeeting', :'meeting_both_id', jsonb_build_object('responseStatus', 200, 'body', jsonb_build_object('expectedVersion', 1)),
  ((select result->>'id' from api042_meet_results where name = 'cancel-cross-reservation')::uuid), 1));
select is((select result->>'outcome' from api042_meet_results where name = 'cancel-cross'), 'forbidden',
  'a different school''s member cannot cancel this meeting');

select set_config('request.jwt.claim.sub', :'teacher_user', true);
select set_config('studafy.school_id', :'school_id', true);
select set_config('studafy.request_id', 'api042-cancel-stale', true);
insert into api042_meet_results values('cancel-stale-reservation', private.api_idempotency_reserve(
  :'school_id', 'v1.cancelMeeting', 'api042-cancel-stale-1', repeat('f', 64)));
insert into api042_meet_results values('cancel-stale', private.api042_command(
  'cancelMeeting', :'meeting_both_id', jsonb_build_object('responseStatus', 200, 'body', jsonb_build_object('expectedVersion', 99)),
  ((select result->>'id' from api042_meet_results where name = 'cancel-stale-reservation')::uuid), 1));
select is((select result->>'outcome' from api042_meet_results where name = 'cancel-stale'), 'version_conflict',
  'cancelling with a stale expectedVersion is rejected');

select set_config('studafy.request_id', 'api042-cancel', true);
insert into api042_meet_results values('cancel-reservation', private.api_idempotency_reserve(
  :'school_id', 'v1.cancelMeeting', 'api042-cancel-key-01', repeat('0', 64)));
insert into api042_meet_results values('cancel', private.api042_command(
  'cancelMeeting', :'meeting_both_id', jsonb_build_object('responseStatus', 200, 'body', jsonb_build_object('expectedVersion', 1)),
  ((select result->>'id' from api042_meet_results where name = 'cancel-reservation')::uuid), 1));
select is((select result->'response'->>'state' from api042_meet_results where name = 'cancel'), 'cancelled',
  'the lead teacher cancels the meeting');
select is(
  (select count(*) from public.meeting_deliveries where meeting_id = :'meeting_both_id' and state <> 'cancelled'),
  0::bigint, 'every delivery row was cancelled by the one bulk update, none left queued'
);

select set_config('studafy.request_id', 'api042-cancel-again', true);
insert into api042_meet_results values('cancel-again-reservation', private.api_idempotency_reserve(
  :'school_id', 'v1.cancelMeeting', 'api042-cancel-again-1', repeat('1', 64)));
insert into api042_meet_results values('cancel-again', private.api042_command(
  'cancelMeeting', :'meeting_both_id', jsonb_build_object('responseStatus', 200, 'body', jsonb_build_object('expectedVersion', 2)),
  ((select result->>'id' from api042_meet_results where name = 'cancel-again-reservation')::uuid), 1));
select is((select result->>'outcome' from api042_meet_results where name = 'cancel-again'), 'invalid_state',
  'an already-cancelled meeting cannot be cancelled again');

-- --------------------------------------------------------------------------
-- getMeetingStatus
-- --------------------------------------------------------------------------

select ok(
  (private.api042_query('getMeetingStatus', :'meeting_both_id', '{}'::jsonb) ? 'meeting'),
  'the lead teacher reads meeting status'
);

select set_config('request.jwt.claim.sub', :'guardian_user', true);
select ok(
  (private.api042_query('getMeetingStatus', :'meeting_both_id', '{}'::jsonb) ? 'meeting'),
  'a recipient guardian reads meeting status even though they are not staff'
);

select set_config('request.jwt.claim.sub', :'other_school_user', true);
select is(private.api042_query('getMeetingStatus', :'meeting_both_id', '{}'::jsonb)->>'outcome', 'forbidden',
  'a different school''s member cannot read this meeting''s status');

-- --------------------------------------------------------------------------
-- Bulk email resolution: exactly the queued recipients, one query.
-- --------------------------------------------------------------------------

select is(
  (select count(*) from private.meeting_recipient_emails(:'meeting_guardians_id'))::text,
  (select count(*)::text from public.meeting_deliveries where meeting_id = :'meeting_guardians_id' and state = 'queued'),
  'the bulk email resolver returns exactly one row per queued delivery'
);

select * from finish();
rollback;
