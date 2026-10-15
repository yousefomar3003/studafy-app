-- DPIA D7 report alerts and the audited reviewer read (202610150080).
-- Transactional fixtures: this test leaves existing local users/data intact.
begin;
\set auth031_fixture_only true
\ir rls_access_seed.sql
\unset auth031_fixture_only
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select plan(25);

\set operator_a 'f0500000-0000-4000-8000-000000000001'
\set operator_b 'f0500000-0000-4000-8000-000000000002'
\set report_one 'f0500000-0000-4000-8000-0000000000a1'
\set report_two 'f0500000-0000-4000-8000-0000000000a2'

\set QUIET on
insert into auth.users (
  id, email, encrypted_password, aud, role, email_confirmed_at, created_at,
  updated_at, instance_id, confirmation_token, recovery_token, email_change,
  email_change_token_new, email_change_token_current, phone_change_token,
  raw_app_meta_data, raw_user_meta_data
) values
  (:'operator_a', 'report-alerts.operator-a@synthetic.studafy.test', 'synthetic-not-a-secret', 'authenticated', 'authenticated', now(), now(), now(), '00000000-0000-0000-0000-000000000000', '', '', '', '', '', '', '{}'::jsonb, '{}'::jsonb),
  (:'operator_b', 'report-alerts.operator-b@synthetic.studafy.test', 'synthetic-not-a-secret', 'authenticated', 'authenticated', now(), now(), now(), '00000000-0000-0000-0000-000000000000', '', '', '', '', '', '', '{}'::jsonb, '{}'::jsonb)
on conflict (id) do nothing;
insert into public.profiles (id, display_name, created_at) values
  (:'operator_a', 'Report Alerts Operator A', now()),
  (:'operator_b', 'Report Alerts Operator B', now())
on conflict (id) do nothing;
insert into public.platform_operators (user_id, note) values
  (:'operator_a', 'report alerts fixture'),
  (:'operator_b', 'report alerts fixture')
on conflict (user_id) do nothing;
-- Alerts from other suites' committed fixtures are out of this test's way.
update private.report_alerts set sent_at = now() where sent_at is null;
\set QUIET off

-- 1. Filing a report queues exactly one alert.
insert into public.reports (id, school_id, reported_by, kind, subject_user_id, details, priority)
values (:'report_one', :'school_id', :'student_user', 'user', :'teacher_user',
  'Synthetic report details that must never leave the database', 'high');
select is((select count(*) from private.report_alerts where report_id = :'report_one'),
  1::bigint, 'a new report queues one alert');
select is((private.report_alerts_backlog()->>'unsent')::int, 1,
  'the backlog counts the unsent alert');

-- 2. The claim carries only id, kind, priority, a school hash and timing.
create temp table claimed on commit drop as
  select * from private.report_alerts_claim(10, 120);
select is((select count(*) from claimed), 1::bigint, 'the worker claims it');
select is(
  (select array_agg(attname::text order by attnum) from pg_attribute
   where attrelid = 'pg_temp.claimed'::regclass and attnum > 0 and not attisdropped),
  array['report_id', 'kind', 'priority', 'school_hash', 'reported_at', 'attempts'],
  'the claim returns no content, names or account ids');
select is((select kind || '/' || priority from claimed), 'user/high',
  'kind and priority are the report''s');
select is((select school_hash from claimed),
  left(encode(digest('studafy-report-alert:' || :'school_id', 'sha256'), 'hex'), 16),
  'the school is a 16-hex hash of its id');
select isnt((select school_hash from claimed), :'school_id',
  'the school id itself is not sent');
select is((select count(*) from private.report_alerts_claim(10, 120)), 0::bigint,
  'a claimed alert is leased, not claimed twice');

-- 3. Sent once, never again.
select ok(private.report_alerts_finish(:'report_one', true, null), 'marking it sent succeeds');
select is((private.report_alerts_backlog()->>'unsent')::int, 0, 'nothing is left unsent');
select ok(not private.report_alerts_finish(:'report_one', true, null),
  'a sent alert cannot be finished again');

-- 4. A failed send is retried after a backoff, with a code, not a message.
insert into public.reports (id, school_id, reported_by, kind, subject_user_id, details)
values (:'report_two', :'school_id', :'student_user', 'user', :'teacher_user',
  'Second synthetic report for the failure path');
select is((select count(*) from private.report_alerts_claim(10, 120)), 1::bigint,
  'the second report is claimed');
select ok(private.report_alerts_finish(:'report_two', false, 'TELEGRAM_REFUSED_500'),
  'a failure is recorded');
select ok((select claimed_until > now() + interval '50 seconds' and last_error = 'TELEGRAM_REFUSED_500'
  from private.report_alerts where report_id = :'report_two'),
  'the failure backs off and keeps its error code');
select ok(private.report_alerts_finish(:'report_two', false, 'https://api.telegram.org/bot123:secret'),
  'a free-text error is accepted');
select is((select last_error from private.report_alerts where report_id = :'report_two'),
  'SEND_FAILED', 'but stored only as a generic code');
select throws_ok($$select * from private.report_alerts_claim(0, 120)$$,
  'P0001', 'REPORT_ALERTS_INVALID_CLAIM', 'a nonsense claim is refused');

-- 5. Who may call what.
select ok(has_function_privilege('studafy_worker_runtime', 'private.report_alerts_claim(integer, integer)', 'execute')
  and has_function_privilege('studafy_worker_runtime', 'private.report_alerts_finish(uuid, boolean, text)', 'execute')
  and not has_function_privilege('studafy_api_runtime', 'private.report_alerts_claim(integer, integer)', 'execute')
  and not has_function_privilege('authenticated', 'private.report_alerts_claim(integer, integer)', 'execute')
  and not has_function_privilege('anon', 'private.report_alerts_backlog()', 'execute'),
  'only the worker claims and finishes alerts');
select ok(not has_function_privilege('studafy_worker_runtime', 'private.report_review_open(uuid)', 'execute')
  and not has_function_privilege('studafy_api_runtime', 'private.report_review_open(uuid)', 'execute')
  and not has_function_privilege('authenticated', 'private.report_review_open(uuid)', 'execute'),
  'no runtime or client role can open a report for review');
select ok(not has_table_privilege('studafy_worker_runtime', 'private.report_alerts', 'select')
  and not has_table_privilege('authenticated', 'private.report_alerts', 'select'),
  'the alert table is reachable only through its functions');

-- 6. The reviewer read: platform operator, live grant, audited either way.
select set_config('request.jwt.claim.sub', :'teacher_user', true);
select is(private.report_review_open(:'report_one')->>'outcome', 'forbidden',
  'a school member who is not an operator is refused');

select set_config('request.jwt.claim.sub', :'operator_a', true);
select is(private.report_review_open(:'report_one'),
  jsonb_build_object('outcome', 'no_grant', 'schoolId', :'school_id'::uuid,
    'schoolHash', private.report_alert_school_hash(:'school_id')),
  'an operator without a grant gets the school id to request one, and nothing else');

insert into public.moderation_access_grants (
  school_id, requested_by, approved_by, reason, ticket_ref, resource_scope,
  status, mfa_verified_at, expires_at, started_at
) values (
  :'school_id', :'operator_a', :'operator_b', 'Review report alert fixture',
  'TICKET-D7', jsonb_build_object('reportIds', jsonb_build_array(:'report_one')),
  'active', now(), now() + interval '30 minutes', now()
);
select ok(
  (select r->>'outcome' = 'ok' and r->'report'->>'id' = :'report_one'
     and r->'report'->'reporterId' = 'null'::jsonb
   from (select private.report_review_open(:'report_one') as r) s),
  'with a live grant the operator sees the report, reporter masked');
select is(private.report_review_open(:'report_two')->>'outcome', 'no_grant',
  'a grant scoped to one report does not open another');

select is(
  (select array_agg(action order by id) from public.audit_events
   where entity_type = 'report' and entity_id in (:'report_one', :'report_two')
     and action like 'report\_review\_%'),
  array['report_review_refused', 'report_review_opened', 'report_review_refused'],
  'every operator attempt is audited, allowed or refused');

select * from finish();
rollback;
