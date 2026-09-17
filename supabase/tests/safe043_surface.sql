-- SAFE-043 surface: reporter reporting (dedupe + rate window + reporter
-- privacy), moderator masking, the blocks gate backstop on conversations, the
-- moderation lifecycle (triage/resolve/appeal/escalate/hold/evidence), the
-- JIT two-person MFA-gated moderator session, and school content controls.
-- Runs inside the shared fixture graph. Each private.api042_command call is
-- scoped by a fresh idempotency reservation, exactly like the API-042 suites.

begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(69);

create temporary table safe043_results (name text primary key, result jsonb);

-- Fixture: an active student<->teacher conversation with one message so the
-- reporter can file a message-kind report whose snapshot is preserved.
insert into public.conversations (id, school_id, subject, state, created_by)
values ('bf01c000-0000-4000-8000-000000000001', :'school_id', 'Seed safety conversation', 'active', :'student_user');
insert into public.conversation_participants (school_id, conversation_id, user_id) values
  (:'school_id', 'bf01c000-0000-4000-8000-000000000001', :'student_user'),
  (:'school_id', 'bf01c000-0000-4000-8000-000000000001', :'teacher_user');
insert into public.messages (id, school_id, conversation_id, sender_id, client_message_id, body)
values ('bf02c000-0000-4000-8000-000000000002', :'school_id',
  'bf01c000-0000-4000-8000-000000000001', :'teacher_user',
  'bf03c000-0000-4000-8000-000000000003', 'the message contains threats of violence');

-- ---------------------------------------------------------------------------
-- Phase A: entry point privileges survive the SAFE-043 wrapper layer.
-- ---------------------------------------------------------------------------

select ok(
  has_function_privilege('studafy_api_runtime', 'private.api042_command(text,uuid,jsonb,uuid,bigint)', 'execute')
  and has_function_privilege('studafy_api_runtime', 'private.api042_query(text,uuid,jsonb)', 'execute')
  and has_function_privilege('studafy_api_runtime', 'private.authz_authorize(text,uuid)', 'execute'),
  'runtime keeps executing the SAFE-043 entry points'
);

select is((select count(*) from public.audit_events
  where action = 'fixture.seed'), 1::bigint,
  'appended fixture audit row is present for later drift checking');

-- ---------------------------------------------------------------------------
-- Phase B: a student files a user-kind report; dedupe and cross-school scope
-- hold; only the reporter can read their own report, and moderator fields are
-- never exposed through the reporter view.
-- ---------------------------------------------------------------------------

select set_config('request.jwt.claim.sub', :'student_user', true);
select set_config('studafy.school_id', :'school_id', true);
select set_config('studafy.request_id', 'safe043-report1', true);
insert into safe043_results values ('reporter1-res', private.api_idempotency_reserve(
  :'school_id', 'v1.createReport', 'safe043-create-report1', repeat('d', 64)));
insert into safe043_results values ('reporter1', private.api042_command(
  'createReport', null,
  jsonb_build_object('responseStatus', 201, 'body', jsonb_build_object(
    'schoolId', :'school_id', 'kind', 'user', 'subjectUserId', :'teacher_user',
    'details', 'She said she would hurt you if you keep talking to me')),
  (select (result->>'id')::uuid from safe043_results where name = 'reporter1-res'), 1));

select (result->'response'->>'id')::text as report_id from safe043_results where name = 'reporter1' \gset

select is((select result->>'outcome' from safe043_results where name = 'reporter1'),
  'ok', 'student can file a report');
select is((select result->'response'->>'priority' from safe043_results where name = 'reporter1'),
  'critical', 'rule matcher pre-flags the hurt-you phrase as critical');
select is((select result->'response'->>'status' from safe043_results where name = 'reporter1'),
  'queued', 'report enters the queue');
select is((select jsonb_array_length(result->'response'->'events')
  from safe043_results where name = 'reporter1'), 2,
  'submitted + queued timeline events are recorded');
select is((select result->'response'->'events'->0->>'event'
  from safe043_results where name = 'reporter1'), 'submitted',
  'first timeline event is submitted');

select set_config('studafy.request_id', 'safe043-report1-dup', true);
insert into safe043_results values ('reporter1-dup-res', private.api_idempotency_reserve(
  :'school_id', 'v1.createReport', 'safe043-create-report1-dup', repeat('e', 64)));
insert into safe043_results values ('reporter1-dup', private.api042_command(
  'createReport', null,
  jsonb_build_object('responseStatus', 201, 'body', jsonb_build_object(
    'schoolId', :'school_id', 'kind', 'user', 'subjectUserId', :'teacher_user',
    'details', 'She said she would hurt you if you keep talking to me')),
  (select (result->>'id')::uuid from safe043_results where name = 'reporter1-dup-res'), 1));
select is((select result->>'outcome' from safe043_results where name = 'reporter1-dup'),
  'invalid_state', 'duplicate report in the live window is refused');

select set_config('request.jwt.claim.sub', :'other_school_user', true);
select set_config('studafy.request_id', 'safe043-report-out', true);
insert into safe043_results values ('reporter-out-res', private.api_idempotency_reserve(
  :'school_id', 'v1.createReport', 'safe043-create-report-out', repeat('f', 64)));
insert into safe043_results values ('reporter-out', private.api042_command(
  'createReport', null,
  jsonb_build_object('responseStatus', 201, 'body', jsonb_build_object(
    'schoolId', :'school_id', 'kind', 'user', 'subjectUserId', :'teacher_user',
    'details', 'totally different concern')),
  (select (result->>'id')::uuid from safe043_results where name = 'reporter-out-res'), 1));
select is((select result->>'outcome' from safe043_results where name = 'reporter-out'),
  'forbidden', 'a user with no active membership here cannot file into this school');

select set_config('request.jwt.claim.sub', :'student_user', true);
select is(private.api042_query('getReport', :'report_id', '{}'::jsonb)->>'id',
  :'report_id', 'reporter can read their own report');
select is(private.api042_query('getReport', :'report_id', '{}'::jsonb)->>'subjectUserId',
  :'teacher_user', 'user-kind report carries the subject id for the reporter');
select ok(nullif(private.api042_query('getReport', :'report_id', '{}'::jsonb)->>'assignedTo', '') is null,
  'moderator assignment is never in the reporter view');
select ok(private.api042_query('getReport', :'report_id', '{}'::jsonb)->'reporterId' is null,
  'reporter view exposes no moderation fields');

select set_config('request.jwt.claim.sub', :'co_teacher_user', true);
select is(private.api042_query('getReport', :'report_id', '{}'::jsonb)->>'outcome',
  'not_found', 'someone who is not the reporter cannot read the report');

-- ---------------------------------------------------------------------------
-- Phase C: message-kind report snapshots the evidence at submission time.
-- ---------------------------------------------------------------------------

select set_config('request.jwt.claim.sub', :'student_user', true);
select set_config('studafy.request_id', 'safe043-report2', true);
insert into safe043_results values ('reporter2-res', private.api_idempotency_reserve(
  :'school_id', 'v1.createReport', 'safe043-create-report2', repeat('a', 64)));
insert into safe043_results values ('reporter2', private.api042_command(
  'createReport', null,
  jsonb_build_object('responseStatus', 201, 'body', jsonb_build_object(
    'schoolId', :'school_id', 'kind', 'message',
    'messageId', 'bf02c000-0000-4000-8000-000000000002',
    'details', 'the message contains threats of violence')),
  (select (result->>'id')::uuid from safe043_results where name = 'reporter2-res'), 1));

select (result->'response'->>'id')::text as report2_id from safe043_results where name = 'reporter2' \gset

select is((select result->>'outcome' from safe043_results where name = 'reporter2'),
  'ok', 'student can report a message conversation');
select is((select result->'response'->>'kind' from safe043_results where name = 'reporter2'),
  'message', 'message-kind report is recorded as such');
select is((select result->'response'->>'priority' from safe043_results where name = 'reporter2'),
  'high', 'violence phrase is pre-flagged high');

-- ---------------------------------------------------------------------------
-- Phase D: moderation lifecycle with reporter masking until escalation.
-- ---------------------------------------------------------------------------

select set_config('request.jwt.claim.sub', :'admin_user', true);
select is(jsonb_typeof(private.api042_query('listModerationQueue', :'school_id',
  jsonb_build_object('schoolId', :'school_id', 'pageSize', 50))->'items'), 'array',
  'school admin can open the queue');
select is((select jsonb_array_length(private.api042_query('listModerationQueue', :'school_id',
  jsonb_build_object('schoolId', :'school_id', 'pageSize', 50))->'items')), 2,
  'queue lists both open reports');
select ok(nullif((select private.api042_query('listModerationQueue', :'school_id',
  jsonb_build_object('schoolId', :'school_id', 'pageSize', 50))->'items'->0->>'reporterId'), '') is null,
  'queue rows mask the reporter until escalation');
select is((select private.api042_query('getModerationOverview', :'school_id',
  '{}'::jsonb)->>'submitted'), '2', 'overview counts queued reports');
select is((select private.api042_query('getModerationOverview', :'school_id',
  '{}'::jsonb)->>'escalated'), '0', 'nothing escalated yet');

select set_config('studafy.request_id', 'safe043-triage', true);
insert into safe043_results values ('triage-res', private.api_idempotency_reserve(
  :'school_id', 'v1.triageReport', 'safe043-triage-r', repeat('1', 64)));
insert into safe043_results values ('triage', private.api042_command(
  'triageReport', :'report_id',
  jsonb_build_object('responseStatus', 200, 'body', jsonb_build_object(
    'expectedVersion', 1, 'priority', 'critical', 'note', 'assigned to reviewer')),
  (select (result->>'id')::uuid from safe043_results where name = 'triage-res'), 1));
select is((select result->>'outcome' from safe043_results where name = 'triage'),
  'ok', 'admin can triage the report');
select is((select result->'response'->>'status' from safe043_results where name = 'triage'),
  'under_review', 'triaged report moves to under review');

select set_config('studafy.request_id', 'safe043-resolve', true);
insert into safe043_results values ('resolve-res', private.api_idempotency_reserve(
  :'school_id', 'v1.resolveReport', 'safe043-resolve-r', repeat('2', 64)));
insert into safe043_results values ('resolve', private.api042_command(
  'resolveReport', :'report_id',
  jsonb_build_object('responseStatus', 200, 'body', jsonb_build_object(
    'expectedVersion', 2, 'resolution', 'upheld', 'note', 'upskilling note')),
  (select (result->>'id')::uuid from safe043_results where name = 'resolve-res'), 1));
select is((select result->>'outcome' from safe043_results where name = 'resolve'),
  'ok', 'admin can resolve the report');
select is((select result->'response'->>'resolution' from safe043_results where name = 'resolve'),
  'upheld', 'resolution is recorded');
select ok(exists (
  select 1 from public.notification_outbox n
  where n.school_id=:'school_id' and n.template_key='safety.report_resolved'
    and n.recipient_id=:'student_user'),
  'reporter receives a resolution notification');

select set_config('request.jwt.claim.sub', :'student_user', true);
select set_config('studafy.request_id', 'safe043-appeal', true);
insert into safe043_results values ('appeal-res', private.api_idempotency_reserve(
  :'school_id', 'v1.appealReport', 'safe043-appeal-r', repeat('3', 64)));
insert into safe043_results values ('appeal', private.api042_command(
  'appealReport', :'report_id',
  jsonb_build_object('responseStatus', 200, 'body', jsonb_build_object(
    'expectedVersion', 3, 'reason', 'the message was never actionable')),
  (select (result->>'id')::uuid from safe043_results where name = 'appeal-res'), 1));
select is((select result->>'outcome' from safe043_results where name = 'appeal'),
  'ok', 'reporter can appeal a resolution');
select is((select result->'response'->>'status' from safe043_results where name = 'appeal'),
  'under_review', 'appeal reopens the report');

select set_config('request.jwt.claim.sub', :'admin_user', true);
select set_config('studafy.request_id', 'safe043-escalate', true);
insert into safe043_results values ('escalate-res', private.api_idempotency_reserve(
  :'school_id', 'v1.escalateReport', 'safe043-escalate-r', repeat('4', 64)));
insert into safe043_results values ('escalate', private.api042_command(
  'escalateReport', :'report_id',
  jsonb_build_object('responseStatus', 200, 'body', jsonb_build_object(
    'expectedVersion', 4, 'note', 'requires platform operator review')),
  (select (result->>'id')::uuid from safe043_results where name = 'escalate-res'), 1));
select is((select result->>'outcome' from safe043_results where name = 'escalate'),
  'ok', 'admin can escalate a reopened report');
select is(private.api042_query('getModerationReport', :'report_id', '{}'::jsonb)->>'reporterId',
  :'student_user', 'escalation explicitly unmasks the reporter to moderators');
select ok(exists (
  select 1 from public.notification_outbox n
  where n.school_id=:'school_id' and n.template_key='safety.report_escalated'
    and n.recipient_id=:'student_user'),
  'reporter is notified when the report is escalated');
select is((select private.api042_query('getModerationOverview', :'school_id',
  '{}'::jsonb)->>'escalated'), '1', 'overview reflects the escalated report');

-- ---------------------------------------------------------------------------
-- Phase E: legal hold by a platform operator, release by the school admin.
-- ---------------------------------------------------------------------------

select set_config('request.jwt.claim.sub', :'admin_user', true);
select set_config('studafy.request_id', 'safe043-hold-admin-denied', true);
insert into safe043_results values ('hold-admin-denied-res', private.api_idempotency_reserve(
  :'school_id', 'v1.holdReport', 'safe043-hold-admin-denied', repeat('5', 64)));
insert into safe043_results values ('hold-admin-denied', private.api042_command(
  'holdReport', :'report2_id',
  jsonb_build_object('responseStatus', 200, 'body', jsonb_build_object(
    'schoolId', :'school_id', 'expectedVersion', 1, 'reason', 'court order retention',
    'ticketRef', 'LEG-0001', 'appliedTo', 'report')),
  (select (result->>'id')::uuid from safe043_results where name = 'hold-admin-denied-res'), 1));
select is((select result->>'outcome' from safe043_results where name = 'hold-admin-denied'),
  'forbidden', 'a school admin cannot apply a legal hold');

select set_config('request.jwt.claim.sub', :'operator_a', true);
select set_config('studafy.school_id', '', true);
select set_config('studafy.request_id', 'safe043-hold', true);
insert into safe043_results values ('hold-res', private.api_idempotency_reserve(
  null, 'v1.holdReport', 'safe043-hold-req', repeat('5', 64)));
insert into safe043_results values ('hold', private.api042_command(
  'holdReport', :'report2_id',
  jsonb_build_object('responseStatus', 200, 'body', jsonb_build_object(
    'schoolId', :'school_id', 'expectedVersion', 1, 'reason', 'court order retention',
    'ticketRef', 'LEG-0001', 'appliedTo', 'report')),
  (select (result->>'id')::uuid from safe043_results where name = 'hold-res'), 1));

select (result->'response'->>'id')::text as hold_id from safe043_results where name = 'hold' \gset

select is((select result->>'outcome' from safe043_results where name = 'hold'),
  'ok', 'platform operator can apply a legal hold');
select is((select result->'response'->>'appliedTo' from safe043_results where name = 'hold'),
  'report', 'hold is scoped to the report by default');
select is(private.api042_query('getModerationReport', :'report2_id', '{}'::jsonb)->>'status',
  'on_hold', 'held report leaves the queue');

select set_config('request.jwt.claim.sub', :'admin_user', true);
select set_config('studafy.school_id', :'school_id', true);
select set_config('studafy.request_id', 'safe043-release-admin-denied', true);
insert into safe043_results values ('release-admin-res', private.api_idempotency_reserve(
  :'school_id', 'v1.releaseLegalHold', 'safe043-release-admin-r', repeat('6', 64)));
insert into safe043_results values ('release-admin', private.api042_command(
  'releaseLegalHold', :'hold_id',
  jsonb_build_object('responseStatus', 200, 'body', jsonb_build_object(
    'expectedVersion', 1, 'reason', 'lifting after resolution')),
  (select (result->>'id')::uuid from safe043_results where name = 'release-admin-res'), 1));
select is((select result->>'outcome' from safe043_results where name = 'release-admin'),
  'forbidden', 'a school admin cannot release a report-scoped hold');

select set_config('request.jwt.claim.sub', :'operator_a', true);
select set_config('studafy.school_id', '', true);
select set_config('studafy.request_id', 'safe043-release', true);
insert into safe043_results values ('release-res', private.api_idempotency_reserve(
  null, 'v1.releaseLegalHold', 'safe043-release-r', repeat('6', 64)));
insert into safe043_results values ('release', private.api042_command(
  'releaseLegalHold', :'hold_id',
  jsonb_build_object('responseStatus', 200, 'body', jsonb_build_object(
    'expectedVersion', 1, 'reason', 'lifting after resolution')),
  (select (result->>'id')::uuid from safe043_results where name = 'release-res'), 1));
select is((select result->>'outcome' from safe043_results where name = 'release'),
  'ok', 'the platform operator releases the hold');

-- ---------------------------------------------------------------------------
-- Phase F: symmetric blocks gate the messaging surface both directions.
-- ---------------------------------------------------------------------------

select set_config('request.jwt.claim.sub', :'teacher_user', true);
select set_config('studafy.request_id', 'safe043-block', true);
insert into safe043_results values ('block-res', private.api_idempotency_reserve(
  :'school_id', 'v1.createBlock', 'safe043-block-r', repeat('7', 64)));
insert into safe043_results values ('block', private.api042_command(
  'createBlock', null,
  jsonb_build_object('responseStatus', 201, 'body', jsonb_build_object(
    'schoolId', :'school_id', 'blockedUserId', :'student_user',
    'scope', 'messages', 'reason', 'avoiding off-topic pings', 'durationHours', 24)),
  (select (result->>'id')::uuid from safe043_results where name = 'block-res'), 1));
select is((select result->>'outcome' from safe043_results where name = 'block'),
  'ok', 'teacher can block a student');

select set_config('request.jwt.claim.sub', :'student_user', true);
select set_config('studafy.request_id', 'safe043-convo-blocked', true);
insert into safe043_results values ('convo-blocked-res', private.api_idempotency_reserve(
  :'school_id', 'v1.createConversation', 'safe043-c2s-blocked', repeat('8', 64)));
insert into safe043_results values ('convo-blocked', private.api042_command(
  'createConversation', null,
  jsonb_build_object('responseStatus', 201, 'body', jsonb_build_object(
    'schoolId', :'school_id', 'participantIds', jsonb_build_array(:'teacher_user'),
    'subject', 'ping')),
  (select (result->>'id')::uuid from safe043_results where name = 'convo-blocked-res'), 1));
select is((select result->>'outcome' from safe043_results where name = 'convo-blocked'),
  'forbidden', 'the blocked student cannot start a conversation with the teacher');

select set_config('request.jwt.claim.sub', :'teacher_user', true);
select set_config('studafy.request_id', 'safe043-convo-blocked2', true);
insert into safe043_results values ('convo-blocked2-res', private.api_idempotency_reserve(
  :'school_id', 'v1.createConversation', 'safe043-t2s-blocked', repeat('9', 64)));
insert into safe043_results values ('convo-blocked2', private.api042_command(
  'createConversation', null,
  jsonb_build_object('responseStatus', 201, 'body', jsonb_build_object(
    'schoolId', :'school_id', 'participantIds', jsonb_build_array(:'student_user'),
    'subject', 'ping')),
  (select (result->>'id')::uuid from safe043_results where name = 'convo-blocked-res'), 1));
select is((select result->>'outcome' from safe043_results where name = 'convo-blocked2'),
  'forbidden', 'the blocker is also refused: blocks are symmetric');

select set_config('studafy.request_id', 'safe043-unblock', true);
insert into safe043_results values ('unblock-res', private.api_idempotency_reserve(
  :'school_id', 'v1.unblockUser', 'safe043-unblock-r', repeat('a', 64)));
insert into safe043_results values ('unblock', private.api042_command(
  'unblockUser', (select result->'response'->>'id' from safe043_results where name = 'block')::uuid,
  jsonb_build_object('responseStatus', 200, 'body', jsonb_build_object()),
  (select (result->>'id')::uuid from safe043_results where name = 'unblock-res'), 1));
select is((select result->>'outcome' from safe043_results where name = 'unblock'),
  'ok', 'the blocker can lift the block');

select set_config('studafy.request_id', 'safe043-convo-after', true);
insert into safe043_results values ('convo-after-res', private.api_idempotency_reserve(
  :'school_id', 'v1.createConversation', 'safe043-after-unblock', repeat('b', 64)));
insert into safe043_results values ('convo-after', private.api042_command(
  'createConversation', null,
  jsonb_build_object('responseStatus', 201, 'body', jsonb_build_object(
    'schoolId', :'school_id', 'participantIds', jsonb_build_array(:'student_user'),
    'subject', 'classes resume')),
  (select (result->>'id')::uuid from safe043_results where name = 'convo-after-res'), 1));
select is((select result->>'outcome' from safe043_results where name = 'convo-after'),
  'ok', 'a new conversation is allowed once the block is lifted');

-- ---------------------------------------------------------------------------
-- Phase G: JIT two-person MFA-gated moderator sessions.
-- ---------------------------------------------------------------------------

select set_config('request.jwt.claim.sub', :'student_user', true);
select set_config('studafy.school_id', '', true);
select set_config('studafy.request_id', 'safe043-request-nonop', true);
insert into safe043_results values ('req-nonop-res', private.api_idempotency_reserve(
  null, 'v1.requestModerationAccess', 'safe043-req-nonop-000000000000000000', repeat('c', 64)));
insert into safe043_results values ('req-nonop', private.api042_command(
  'requestModerationAccess', null,
  jsonb_build_object('responseStatus', 201, 'aal2', true, 'body', jsonb_build_object(
    'schoolId', :'school_id', 'reason', 'i want in', 'ticketRef', 'T-1',
    'durationMinutes', 60)),
  (select (result->>'id')::uuid from safe043_results where name = 'req-nonop-res'), 1));
select is((select result->>'outcome' from safe043_results where name = 'req-nonop'),
  'forbidden', 'only a platform operator can request moderation access');

select set_config('request.jwt.claim.sub', :'operator_a', true);
select set_config('studafy.request_id', 'safe043-request-no-mfa', true);
insert into safe043_results values ('req-nomfa-res', private.api_idempotency_reserve(
  null, 'v1.requestModerationAccess', 'safe043-req-nomfa-000000000000000000', repeat('d', 64)));
insert into safe043_results values ('req-nomfa', private.api042_command(
  'requestModerationAccess', null,
  jsonb_build_object('responseStatus', 201, 'aal2', false, 'body', jsonb_build_object(
    'schoolId', :'school_id', 'reason', 'uncovered review window', 'ticketRef', 'T-2',
    'durationMinutes', 60)),
  (select (result->>'id')::uuid from safe043_results where name = 'req-nomfa-res'), 1));
select is((select result->>'outcome' from safe043_results where name = 'req-nomfa'),
  'forbidden', 'requesting without a fresh MFA step is refused');

select set_config('studafy.request_id', 'safe043-request', true);
insert into safe043_results values ('req-res', private.api_idempotency_reserve(
  null, 'v1.requestModerationAccess', 'safe043-req-res', repeat('e', 64)));
insert into safe043_results values ('req', private.api042_command(
  'requestModerationAccess', null,
  jsonb_build_object('responseStatus', 201, 'aal2', true, 'body', jsonb_build_object(
    'schoolId', :'school_id', 'reason', 'uncovered review window', 'ticketRef', 'T-2',
    'resourceScope', jsonb_build_object('reportIds', jsonb_build_array(:'report_id')),
    'durationMinutes', 60, 'requiresSecondApprover', true)),
  (select (result->>'id')::uuid from safe043_results where name = 'req-res'), 1));

select (result->'response'->>'id')::text as grant_id from safe043_results where name = 'req' \gset

select is((select result->>'outcome' from safe043_results where name = 'req'),
  'ok', 'operator request with MFA is accepted');
select is((select result->'response'->>'status' from safe043_results where name = 'req'),
  'pending', 'grant is pending a second approver');

select set_config('studafy.request_id', 'safe043-self-approve', true);
insert into safe043_results values ('self-approve-res', private.api_idempotency_reserve(
  null, 'v1.approveModerationAccess', 'safe043-self-approve-000000000000000000', repeat('f', 64)));
insert into safe043_results values ('self-approve', private.api042_command(
  'approveModerationAccess', :'grant_id',
  jsonb_build_object('responseStatus', 200, 'aal2', true, 'body', jsonb_build_object(
    'expectedVersion', 1)),
  (select (result->>'id')::uuid from safe043_results where name = 'self-approve-res'), 1));
select is((select result->>'outcome' from safe043_results where name = 'self-approve'),
  'forbidden', 'the requester cannot approve their own grant');

select set_config('request.jwt.claim.sub', :'operator_b', true);
select set_config('studafy.request_id', 'safe043-approve', true);
insert into safe043_results values ('approve-res', private.api_idempotency_reserve(
  null, 'v1.approveModerationAccess', 'safe043-approve-r', repeat('0', 64)));
insert into safe043_results values ('approve', private.api042_command(
  'approveModerationAccess', :'grant_id',
  jsonb_build_object('responseStatus', 200, 'aal2', true, 'body', jsonb_build_object(
    'expectedVersion', 1)),
  (select (result->>'id')::uuid from safe043_results where name = 'approve-res'), 1));
select is((select result->>'outcome' from safe043_results where name = 'approve'),
  'ok', 'a second operator with fresh MFA approves');
select is((select result->'response'->>'status' from safe043_results where name = 'approve'),
  'approved', 'grant moves to approved');

select set_config('request.jwt.claim.sub', :'operator_a', true);
select set_config('studafy.request_id', 'safe043-start', true);
insert into safe043_results values ('start-res', private.api_idempotency_reserve(
  null, 'v1.startModerationAccess', 'safe043-start-r', repeat('1', 64)));
insert into safe043_results values ('start', private.api042_command(
  'startModerationAccess', :'grant_id',
  jsonb_build_object('responseStatus', 200, 'body', jsonb_build_object(
    'expectedVersion', 1)),
  (select (result->>'id')::uuid from safe043_results where name = 'start-res'), 1));
select is((select result->>'outcome' from safe043_results where name = 'start'),
  'ok', 'the requester starts their approved session');
select is((select result->'response'->>'status' from safe043_results where name = 'start'),
  'active', 'session becomes active');

select set_config('studafy.school_id', :'school_id', true);
select is(jsonb_typeof(private.api042_query('listModerationQueue', :'school_id',
  jsonb_build_object('schoolId', :'school_id', 'pageSize', 50))->'items'), 'array',
  'an active grant opens the queue for the operator');
select is(private.api042_query('getModerationReport', :'report_id', '{}'::jsonb)->>'id',
  :'report_id', 'the grant scope includes report1');
select is(private.api042_query('getModerationReport', :'report2_id', '{}'::jsonb)->>'outcome',
  'not_found', 'grant scope with reportIds excludes report2');
select is((select jsonb_array_length(private.api042_query('listModerationAccess', :'school_id',
  '{}'::jsonb)->'items')), 1, 'operator lists the single grant');

select set_config('studafy.school_id', '', true);
select set_config('studafy.request_id', 'safe043-revoke', true);
insert into safe043_results values ('revoke-res', private.api_idempotency_reserve(
  null, 'v1.revokeModerationAccess', 'safe043-revoke-r', repeat('2', 64)));
insert into safe043_results values ('revoke', private.api042_command(
  'revokeModerationAccess', :'grant_id',
  jsonb_build_object('responseStatus', 200, 'body', jsonb_build_object(
    'expectedVersion', 2, 'reason', 'coverage resolved')),
  (select (result->>'id')::uuid from safe043_results where name = 'revoke-res'), 1));
select is((select result->>'outcome' from safe043_results where name = 'revoke'),
  'ok', 'the operator can revoke the session');
select is((select result->'response'->>'status' from safe043_results where name = 'revoke'),
  'revoked', 'session ends revoked');
select is(private.api042_query('listModerationQueue', :'school_id',
  jsonb_build_object('schoolId', :'school_id', 'pageSize', 50))->>'outcome',
  'forbidden', 'the operator is cut off once the grant is revoked');

-- ---------------------------------------------------------------------------
-- Phase H: school content controls are asserted by admins, read by anyone
-- with an active membership in the school.
-- ---------------------------------------------------------------------------

select set_config('request.jwt.claim.sub', :'unverified_guardian', true);
select set_config('studafy.school_id', :'school_id', true);
select is(private.api042_query('getContentControls', :'school_id', '{}'::jsonb)->>'outcome',
  'forbidden', 'a non-member cannot read content controls');

select set_config('request.jwt.claim.sub', :'admin_user', true);
select is(private.api042_query('getContentControls', :'school_id', '{}'::jsonb)->>'contentFilterLevel',
  'strict', 'default filter level is strict');
select is(private.api042_query('getContentControls', :'school_id', '{}'::jsonb)->>'messagingEnabled',
  'false', 'messaging starts disabled by default');
select is(private.api042_query('getContentControls', :'school_id', '{}'::jsonb)->>'version',
  '1', 'baseline controls version 1');

select set_config('studafy.request_id', 'safe043-controls', true);
insert into safe043_results values ('controls-res', private.api_idempotency_reserve(
  :'school_id', 'v1.updateContentControls', 'safe043-controls-r', repeat('3', 64)));
insert into safe043_results values ('controls', private.api042_command(
  'updateContentControls', :'school_id',
  jsonb_build_object('responseStatus', 200, 'body', jsonb_build_object(
    'expectedVersion', 1, 'messagingEnabled', true, 'contentFilterLevel', 'moderate',
    'classifierAssistEnabled', true, 'supportContact', 'safeguarding@seed.test')),
  (select (result->>'id')::uuid from safe043_results where name = 'controls-res'), 1);
select is((select result->>'outcome' from safe043_results where name = 'controls'),
  'ok', 'school admin can update content controls');
select is((select result->'response'->>'contentFilterLevel' from safe043_results where name = 'controls'),
  'moderate', 'filter level is persisted');
select is((select result->'response'->>'version' from safe043_results where name = 'controls'),
  '2', 'controls version advances');

select set_config('request.jwt.claim.sub', :'teacher_user', true);
select is(private.api042_query('getContentControls', :'school_id', '{}'::jsonb)->>'supportContact',
  'safeguarding@seed.test', 'an active member reads the asserted controls');
select is(private.api042_query('getContentControls', :'school_id', '{}'::jsonb)->>'messagingEnabled',
  'true', 'member sees messaging flipped on');

select * from finish();
rollback;