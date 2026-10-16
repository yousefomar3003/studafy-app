-- Safety reports with one reviewer (DL-063; 202610160041). With the setting
-- on and exactly one platform operator, that operator approves their own
-- moderation grant (requested with requiresSecondApprover false), reads the
-- report and resolves it, every step audited. Any other case keeps the
-- two-person approval.
-- Transactional fixtures: this test leaves existing local users/data intact.
begin;
\set auth031_fixture_only true
\ir rls_access_seed.sql
\unset auth031_fixture_only
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(31);

\set operator_a 'f0600000-0000-4000-8000-000000000001'
\set operator_b 'f0600000-0000-4000-8000-000000000002'
\set report_id 'f0600000-0000-4000-8000-0000000000a1'

create temporary table sr_results (name text primary key, result jsonb);

\set QUIET on
insert into auth.users (
  id, email, encrypted_password, aud, role, email_confirmed_at, created_at,
  updated_at, instance_id, confirmation_token, recovery_token, email_change,
  email_change_token_new, email_change_token_current, phone_change_token,
  raw_app_meta_data, raw_user_meta_data
) values
  (:'operator_a', 'single-reviewer.operator-a@synthetic.studafy.test', 'synthetic-not-a-secret', 'authenticated', 'authenticated', now(), now(), now(), '00000000-0000-0000-0000-000000000000', '', '', '', '', '', '', '{}'::jsonb, '{}'::jsonb),
  (:'operator_b', 'single-reviewer.operator-b@synthetic.studafy.test', 'synthetic-not-a-secret', 'authenticated', 'authenticated', now(), now(), now(), '00000000-0000-0000-0000-000000000000', '', '', '', '', '', '', '{}'::jsonb, '{}'::jsonb)
on conflict (id) do nothing;
insert into public.profiles (id, display_name, created_at) values
  (:'operator_a', 'Single Reviewer Operator A', now()),
  (:'operator_b', 'Single Reviewer Operator B', now())
on conflict (id) do nothing;
-- Other suites' committed fixtures add operators; inside this transaction
-- operator A is the only one (rolled back at the end).
delete from public.platform_operators;
insert into public.platform_operators (user_id, note)
values (:'operator_a', 'single reviewer fixture');
insert into public.reports (id, school_id, reported_by, kind, subject_user_id, details, priority)
values (:'report_id', :'school_id', :'student_user', 'user', :'teacher_user',
  'Synthetic report for the single-reviewer path', 'high');
\set QUIET off

-- Requests and approves a grant as the current subject, through the API's
-- own dispatcher, each call with its own idempotency reservation.
create function pg_temp.sr_command(
  p_name text, p_operation text, p_resource uuid, p_input jsonb
) returns jsonb language plpgsql as $$
declare
  v_reservation jsonb;
  v_result jsonb;
begin
  perform set_config('studafy.request_id', 'single-reviewer-' || p_name, true);
  v_reservation := private.api_idempotency_reserve(
    nullif(current_setting('studafy.school_id', true), '')::uuid,
    'v1.' || p_operation, 'single-reviewer-' || p_name || '-key',
    encode(extensions.digest(p_name, 'sha256'), 'hex'));
  v_result := private.api042_command(p_operation, p_resource, p_input,
    (v_reservation->>'id')::uuid, coalesce((v_reservation->>'generation')::bigint, 1));
  insert into sr_results values (p_name, v_result);
  return v_result;
end;
$$;

-- 1. The setting: on from the migration, reachable by no runtime or client.
select ok((select single_reviewer from private.safety_review_settings),
  'single-reviewer mode is configured on (DL-063)');
select ok(not has_table_privilege('studafy_api_runtime', 'private.safety_review_settings', 'select')
  and not has_table_privilege('studafy_worker_runtime', 'private.safety_review_settings', 'select')
  and not has_table_privilege('authenticated', 'private.safety_review_settings', 'update')
  and not has_table_privilege('service_role', 'private.safety_review_settings', 'update'),
  'no runtime or client role can read or change the setting');
select ok(not has_function_privilege('studafy_api_runtime', 'private.safety_single_reviewer_mode()', 'execute')
  and not has_function_privilege('authenticated', 'private.safety_single_reviewer_mode()', 'execute'),
  'the mode is read only inside the grant functions');
select ok(private.safety_single_reviewer_mode(),
  'with the setting on and one operator, the mode applies');
select throws_ok($$insert into private.safety_review_settings (singleton) values (false)$$,
  '23514', null, 'the setting is a single row');

-- 2. The one operator grants themselves access to the report.
select set_config('request.jwt.claim.sub', :'operator_a', true);
select set_config('studafy.school_id', '', true);
select is(pg_temp.sr_command('req-default', 'requestModerationAccess', null,
  jsonb_build_object('responseStatus', 201, 'aal2', true, 'body', jsonb_build_object(
    'schoolId', :'school_id', 'reason', 'review a report alert', 'ticketRef', 'T-SR-1',
    'resourceScope', jsonb_build_object('reportIds', jsonb_build_array(:'report_id')),
    'durationMinutes', 60)))->>'outcome',
  'ok', 'a grant requested with the default still asks for a second approver');
select is(pg_temp.sr_command('self-approve-default', 'approveModerationAccess',
  (select (result->'response'->>'id')::uuid from sr_results where name = 'req-default'),
  jsonb_build_object('responseStatus', 200, 'aal2', true,
    'body', jsonb_build_object('expectedVersion', 1)))->>'outcome',
  'forbidden', 'so even in the mode its requester cannot approve it');

select is(pg_temp.sr_command('req', 'requestModerationAccess', null,
  jsonb_build_object('responseStatus', 201, 'aal2', true, 'body', jsonb_build_object(
    'schoolId', :'school_id', 'reason', 'review a report alert', 'ticketRef', 'T-SR-2',
    'resourceScope', jsonb_build_object('reportIds', jsonb_build_array(:'report_id')),
    'durationMinutes', 60, 'requiresSecondApprover', false)))->>'outcome',
  'ok', 'the operator requests a single-reviewer grant with MFA');
select (result->'response'->>'id') as grant_id from sr_results where name = 'req' \gset
select is((select result->'response'->>'requiresSecondApprover' from sr_results where name = 'req'),
  'false', 'the grant records that it has no second approver');

select ok((private.authz_authorize('moderation.access.approve', :'grant_id')->>'allowed')::boolean,
  'authorization lets the only operator approve their own single-reviewer grant');
select is(pg_temp.sr_command('self-approve-nomfa', 'approveModerationAccess', :'grant_id',
  jsonb_build_object('responseStatus', 200, 'aal2', false,
    'body', jsonb_build_object('expectedVersion', 1)))->>'outcome',
  'forbidden', 'approving still needs a fresh MFA step');
select is(pg_temp.sr_command('self-approve', 'approveModerationAccess', :'grant_id',
  jsonb_build_object('responseStatus', 200, 'aal2', true,
    'body', jsonb_build_object('expectedVersion', 1)))->>'outcome',
  'ok', 'the only operator approves their own grant');
select ok((select approved_by = requested_by and requested_by = :'operator_a'
  from public.moderation_access_grants where id = :'grant_id'),
  'the grant shows it was approved by its requester');
select is(pg_temp.sr_command('start', 'startModerationAccess', :'grant_id',
  jsonb_build_object('responseStatus', 200,
    'body', jsonb_build_object('expectedVersion', 2)))->>'outcome',
  'ok', 'and starts it');

-- 3. Read and resolve, exactly as scripts/review-report.ts does.
select is(private.report_review_open(:'report_id')->>'outcome', 'ok',
  'the reviewer opens the report');
select is(private.report_review_open(:'report_id')->'report'->'reporterId', 'null'::jsonb,
  'with the reporter masked');
select set_config('studafy.school_id', :'school_id', true);
select is(pg_temp.sr_command('triage', 'triageReport', :'report_id',
  jsonb_build_object('responseStatus', 200, 'aal2', false, 'body', jsonb_build_object(
    'expectedVersion', (select version from public.reports where id = :'report_id'),
    'note', 'Opened by review-report.ts')))->>'outcome',
  'ok', 'the reviewer triages it');
select is(pg_temp.sr_command('resolve', 'resolveReport', :'report_id',
  jsonb_build_object('responseStatus', 200, 'aal2', false, 'body', jsonb_build_object(
    'expectedVersion', (select version from public.reports where id = :'report_id'),
    'resolution', 'not_upheld', 'note', 'Not a breach of the rules.')))->>'outcome',
  'ok', 'and resolves it');
select is((select status::text from public.reports where id = :'report_id'), 'resolved',
  'the report is resolved');

select is(
  (select array_agg(action order by id) from public.audit_events
   where entity_id = :'grant_id' and entity_type = 'moderation_access_grant'),
  array['moderation_access_requested', 'moderation_access_approved', 'moderation_access_started'],
  'the grant''s request, approval and start are audited');
select is(
  (select array_agg(action order by id) from public.audit_events
   where entity_type = 'report' and entity_id = :'report_id'),
  array['report_review_opened', 'report_review_opened', 'report_triaged', 'report_resolved'],
  'every read and the resolution are audited');
select is((select count(*) from private.report_alerts where report_id = :'report_id'),
  1::bigint, 'the report still raised its alert');

-- 4. The setting off: the two-person approval is back.
select set_config('studafy.school_id', '', true);
select is(pg_temp.sr_command('req-off', 'requestModerationAccess', null,
  jsonb_build_object('responseStatus', 201, 'aal2', true, 'body', jsonb_build_object(
    'schoolId', :'school_id', 'reason', 'review a report alert', 'ticketRef', 'T-SR-3',
    'durationMinutes', 60, 'requiresSecondApprover', false)))->>'outcome',
  'ok', 'a second single-reviewer grant is requested');
select (result->'response'->>'id') as grant_off_id from sr_results where name = 'req-off' \gset
update private.safety_review_settings set single_reviewer = false,
  note = 'test: off';
select ok(not private.safety_single_reviewer_mode(), 'with the setting off the mode ends');
select is(pg_temp.sr_command('self-approve-off', 'approveModerationAccess', :'grant_off_id',
  jsonb_build_object('responseStatus', 200, 'aal2', true,
    'body', jsonb_build_object('expectedVersion', 1)))->>'outcome',
  'forbidden', 'and the requester can no longer approve their own grant');
select is(
  (select array_agg(after_value->>'singleReviewer' order by id) from public.audit_events
   where action = 'safety_single_reviewer_changed'
     and created_at = now()),
  array['false'], 'turning the setting off is audited');

-- 5. A second operator: the mode ends by itself, whatever the setting says.
update private.safety_review_settings set single_reviewer = true, note = 'test: on';
insert into public.platform_operators (user_id, note)
values (:'operator_b', 'single reviewer fixture');
select ok(not private.safety_single_reviewer_mode(),
  'with two operators the mode does not apply, even with the setting on');
select ok(not (private.authz_authorize('moderation.access.approve', :'grant_off_id')->>'allowed')::boolean,
  'authorization refuses the requester');
select is(pg_temp.sr_command('self-approve-two', 'approveModerationAccess', :'grant_off_id',
  jsonb_build_object('responseStatus', 200, 'aal2', true,
    'body', jsonb_build_object('expectedVersion', 1)))->>'outcome',
  'forbidden', 'the requester cannot approve their own grant');
select set_config('request.jwt.claim.sub', :'operator_b', true);
select is(pg_temp.sr_command('approve-two', 'approveModerationAccess', :'grant_off_id',
  jsonb_build_object('responseStatus', 200, 'aal2', true,
    'body', jsonb_build_object('expectedVersion', 1)))->>'outcome',
  'ok', 'the second operator approves it, as before');

-- 6. A school member who is not an operator never approves anything.
select set_config('request.jwt.claim.sub', :'teacher_user', true);
select ok(not private.safe043_is_second_approver(:'grant_id'),
  'a non-operator is never an approver');

select * from finish();
rollback;
