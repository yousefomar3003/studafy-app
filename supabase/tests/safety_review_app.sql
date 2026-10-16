-- The platform operator reviews safety reports in the app (DL-063;
-- 202610160050). The queue is metadata only and for platform operators
-- only; opening a report needs an active grant covering it and is audited
-- like the review script's read; triage and resolution go through the
-- existing commands with no school membership. GET /v1/me learns who is an
-- operator from auth_context.
-- Transactional fixtures: this test leaves existing local users/data intact.
begin;
\set auth031_fixture_only true
\ir rls_access_seed.sql
\unset auth031_fixture_only
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(33);

\set operator 'f0700000-0000-4000-8000-000000000001'
\set report_high 'f0700000-0000-4000-8000-0000000000a1'
\set report_critical 'f0700000-0000-4000-8000-0000000000a2'
\set report_closed 'f0700000-0000-4000-8000-0000000000a3'

create temporary table ra_results (name text primary key, result jsonb);

\set QUIET on
insert into auth.users (
  id, email, encrypted_password, aud, role, email_confirmed_at, created_at,
  updated_at, instance_id, confirmation_token, recovery_token, email_change,
  email_change_token_new, email_change_token_current, phone_change_token,
  raw_app_meta_data, raw_user_meta_data
) values
  (:'operator', 'review-app.operator@synthetic.studafy.test', 'synthetic-not-a-secret', 'authenticated', 'authenticated', now(), now(), now(), '00000000-0000-0000-0000-000000000000', '', '', '', '', '', '', '{}'::jsonb, '{}'::jsonb)
on conflict (id) do nothing;
insert into public.profiles (id, display_name, created_at) values
  (:'operator', 'Review App Operator', now())
on conflict (id) do nothing;
-- Other suites' committed fixtures add operators and reports; inside this
-- transaction there is one operator and these three reports (rolled back).
delete from public.platform_operators;
insert into public.platform_operators (user_id, note)
values (:'operator', 'review app fixture');
update public.reports set status = 'withdrawn'
where status not in ('resolved', 'withdrawn');
insert into public.reports (id, school_id, reported_by, kind, subject_user_id, details, priority)
values
  (:'report_high', :'school_id', :'student_user', 'user', :'teacher_user',
    'Synthetic report for the app review path', 'high'),
  (:'report_critical', :'school_id', :'student_user', 'user', :'teacher_user',
    'A second synthetic report, more urgent', 'critical'),
  (:'report_closed', :'school_id', :'student_user', 'user', :'teacher_user',
    'A third synthetic report, already closed', 'low');
update public.reports set status = 'resolved', resolution = 'no_action',
  resolved_at = now() where id = :'report_closed';
\set QUIET off

-- A command through the API's own dispatcher, as the current subject.
create function pg_temp.ra_command(
  p_name text, p_operation text, p_resource uuid, p_input jsonb
) returns jsonb language plpgsql as $$
declare
  v_reservation jsonb;
  v_result jsonb;
begin
  perform set_config('studafy.request_id', 'review-app-' || p_name, true);
  v_reservation := private.api_idempotency_reserve(
    nullif(current_setting('studafy.school_id', true), '')::uuid,
    'v1.' || p_operation, 'review-app-' || p_name || '-key',
    encode(extensions.digest(p_name, 'sha256'), 'hex'));
  v_result := private.api042_command(p_operation, p_resource, p_input,
    (v_reservation->>'id')::uuid, coalesce((v_reservation->>'generation')::bigint, 1));
  insert into ra_results values (p_name, v_result);
  return v_result;
end;
$$;

-- 1. Who can reach what.
select ok(has_function_privilege('studafy_api_runtime', 'private.safety_review_query(text, uuid, jsonb)', 'execute'),
  'the API reaches the review area through safety_review_query');
select ok(not has_function_privilege('authenticated', 'private.safety_review_query(text, uuid, jsonb)', 'execute')
  and not has_function_privilege('studafy_worker_runtime', 'private.safety_review_query(text, uuid, jsonb)', 'execute')
  and not has_function_privilege('service_role', 'private.safety_review_query(text, uuid, jsonb)', 'execute'),
  'no client, worker or service role can call it');
select ok(not has_function_privilege('studafy_api_runtime', 'private.safety_review_open(uuid, text)', 'execute')
  and not has_function_privilege('studafy_api_runtime', 'private.report_review_open(uuid)', 'execute')
  and not has_function_privilege('authenticated', 'private.safety_review_open(uuid, text)', 'execute'),
  'the audited read itself stays private');

-- 2. GET /v1/me learns who is an operator.
select set_config('request.jwt.claim.sub', :'operator', true);
select set_config('studafy.school_id', '', true);
select is(private.auth_context()->'platform_operator', 'true'::jsonb,
  'the session context marks a platform operator');
select set_config('request.jwt.claim.sub', :'teacher_user', true);
select is(private.auth_context()->'platform_operator', 'false'::jsonb,
  'and nobody else');

-- 3. The queue is for platform operators only.
select is(private.safety_review_query('listSafetyReviewReports', null, '{}'::jsonb),
  '{"outcome": "forbidden"}'::jsonb, 'a school member cannot list the queue');
select is(private.safety_review_query('openSafetyReviewReport', :'report_high', '{}'::jsonb),
  '{"outcome": "forbidden"}'::jsonb, 'or open a report');

select set_config('request.jwt.claim.sub', :'operator', true);
select private.safety_review_query('listSafetyReviewReports', null, '{}'::jsonb) as queue \gset
select is(jsonb_array_length(:'queue'::jsonb->'items'), 2,
  'the operator sees every open report, not the closed one');
select is((:'queue'::jsonb->'items'->0->>'id'), :'report_critical',
  'most urgent first');
select is(
  (select array_agg(k order by k) from jsonb_object_keys(:'queue'::jsonb->'items'->0) k),
  array['createdAt', 'grantActive', 'id', 'kind', 'priority', 'schoolId', 'status'],
  'metadata only: no details, evidence, names or account ids');
select ok(:'queue'::jsonb->'items'->1 @> jsonb_build_object(
    'id', :'report_high', 'schoolId', :'school_id', 'kind', 'user',
    'priority', 'high', 'status', 'submitted', 'grantActive', false),
  'each row says its school, kind, priority and status, and that no grant covers it');
select is(:'queue'::jsonb->'singleReviewer', 'true'::jsonb,
  'single-reviewer mode is reported');
select ok((:'queue'::jsonb->'nextPosition') = 'null'::jsonb, 'one page');

select is(jsonb_array_length(private.safety_review_query('listSafetyReviewReports', null,
    '{"pageSize": 1}'::jsonb)->'items'), 1, 'a page holds pageSize rows');
select private.safety_review_query('listSafetyReviewReports', null,
  '{"pageSize": 1}'::jsonb)->>'nextPosition' as next_position \gset
select is(private.safety_review_query('listSafetyReviewReports', null,
    jsonb_build_object('pageSize', 1, 'position', :'next_position'))->'items'->0->>'id',
  :'report_high', 'and the next page carries on after it');
select is(private.safety_review_query('listSafetyReviewReports', null,
    '{"position": "x; drop table"}'::jsonb),
  '{"outcome": "invalid"}'::jsonb, 'a malformed position is refused');

-- 4. Opening needs an active grant; the refusal is audited.
select is(private.safety_review_query('openSafetyReviewReport', :'report_high', '{}'::jsonb),
  '{"outcome": "forbidden"}'::jsonb, 'without a grant the report stays closed');
select is(private.safety_review_query('openSafetyReviewReport', 'f0700000-0000-4000-8000-0000000000ff', '{}'::jsonb),
  '{"outcome": "not_found"}'::jsonb, 'an unknown report is not found');

-- 5. The app's grant: requested with MFA, self-approved, started.
select is(pg_temp.ra_command('req', 'requestModerationAccess', null,
  jsonb_build_object('responseStatus', 201, 'aal2', true, 'body', jsonb_build_object(
    'schoolId', :'school_id', 'reason', 'Telegram alert for this report', 'ticketRef', :'report_high',
    'resourceScope', jsonb_build_object('reportIds', jsonb_build_array(:'report_high')),
    'durationMinutes', 60, 'requiresSecondApprover', false)))->>'outcome',
  'ok', 'the operator requests a grant for the one report');
select (result->'response'->>'id') as grant_id from ra_results where name = 'req' \gset
select is(pg_temp.ra_command('approve', 'approveModerationAccess', :'grant_id',
  jsonb_build_object('responseStatus', 200, 'aal2', true,
    'body', jsonb_build_object('expectedVersion', 1)))->>'outcome',
  'ok', 'approves it in single-reviewer mode');
select is(pg_temp.ra_command('start', 'startModerationAccess', :'grant_id',
  jsonb_build_object('responseStatus', 200, 'aal2', true,
    'body', jsonb_build_object('expectedVersion', 2)))->>'outcome',
  'ok', 'and starts it');

select ok((select (i->>'grantActive')::boolean from jsonb_array_elements(
    private.safety_review_query('listSafetyReviewReports', null, '{}'::jsonb)->'items') i
  where i->>'id' = :'report_high'), 'the queue shows the grant covers the report');
select ok(not (select (i->>'grantActive')::boolean from jsonb_array_elements(
    private.safety_review_query('listSafetyReviewReports', null, '{}'::jsonb)->'items') i
  where i->>'id' = :'report_critical'), 'and not the report outside its scope');

select set_config('studafy.request_id', 'review-app-open', true);
select private.safety_review_query('openSafetyReviewReport', :'report_high', '{}'::jsonb) as opened \gset
select is(:'opened'::jsonb->>'id', :'report_high', 'the operator opens the report');
select is(:'opened'::jsonb->>'details', 'Synthetic report for the app review path',
  'with its content');
select is(:'opened'::jsonb->'reporterId', 'null'::jsonb, 'and the reporter masked');
select is(private.safety_review_query('openSafetyReviewReport', :'report_critical', '{}'::jsonb),
  '{"outcome": "forbidden"}'::jsonb, 'a report outside the grant stays closed');

-- 6. Triage and resolve with no school context, as the API sends them for
-- an operator who is not a member of the school.
select set_config('studafy.school_id', '', true);
select is(pg_temp.ra_command('triage', 'triageReport', :'report_high',
  jsonb_build_object('responseStatus', 200, 'aal2', true, 'body', jsonb_build_object(
    'expectedVersion', (select version from public.reports where id = :'report_high'),
    'note', 'Opened in the app')))->>'outcome',
  'ok', 'the operator triages it without a membership');
select is(pg_temp.ra_command('resolve', 'resolveReport', :'report_high',
  jsonb_build_object('responseStatus', 200, 'aal2', true, 'body', jsonb_build_object(
    'expectedVersion', (select version from public.reports where id = :'report_high'),
    'resolution', 'upheld', 'note', 'Message removed; sender warned.')))->>'outcome',
  'ok', 'and resolves it');

-- 7. Everything is audited, the app's reads marked as such.
select is(
  (select array_agg(action || ':' || coalesce(after_value->>'via', '-') order by id)
   from public.audit_events
   where entity_type = 'report' and entity_id = :'report_high'),
  array['report_review_refused:app', 'report_review_opened:app',
    'report_triaged:-', 'report_resolved:-'],
  'the refused and the allowed read, the triage and the resolution are audited');
select is(
  (select request_id from public.audit_events
   where entity_type = 'report' and entity_id = :'report_high'
     and action = 'report_review_opened'),
  'review-app-open', 'the read carries the request id');
select is(
  (select count(*) from public.audit_events
   where entity_type = 'report' and entity_id = :'report_critical'
     and action = 'report_review_refused' and after_value->>'via' = 'app'),
  1::bigint, 'the refused read outside the grant is audited too');

-- 8. The review script's read is the same function, marked as the script's.
select is(private.report_review_open(:'report_critical')->>'outcome', 'no_grant',
  'the script read still answers no_grant with the school id');

select * from finish();
rollback;
