-- DL-076: AI outputs can be reported (202611030040). Any signed-in, active
-- account files one for itself, with or without a school; the alert carries
-- the report id, feature and reason only; reports are exported, purged after
-- 180 days, and leave with a deleted account; nothing is reachable except
-- through its functions.
-- Transactional fixtures: this test leaves existing local users/data intact.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select plan(33);

\set reporter 'f0760000-0000-4000-8000-000000000001'
\set other 'f0760000-0000-4000-8000-000000000002'
\set leaver 'f0760000-0000-4000-8000-000000000003'

\set QUIET on
-- Three accounts with no school at all: a student with no class files
-- reports like anyone else.
insert into auth.users (id, email, aud, role, created_at, updated_at,
  instance_id, raw_app_meta_data, raw_user_meta_data)
select u.id::uuid, u.id || '@synthetic.studafy.test', 'authenticated', 'authenticated',
  now(), now(), '00000000-0000-0000-0000-000000000000', '{}'::jsonb,
  jsonb_build_object('full_name', 'AI report ' || u.n)
from (values
  (:'reporter', 'Reporter'),
  (:'other', 'Other'),
  (:'leaver', 'Leaver')
) as u(id, n)
on conflict (id) do nothing;
insert into public.profiles (id, display_name, created_at)
select u.id::uuid, 'AI report fixture', now()
from (values (:'reporter'), (:'other'), (:'leaver')) as u(id)
on conflict (id) do nothing;
-- Alerts from other suites' committed fixtures are out of this test's way.
update private.ai_output_report_alerts set sent_at = now() where sent_at is null;
select set_config('studafy.request_id', 'ai-output-report-test', true);

-- Files a report as p_actor inside a fresh idempotency reservation, as the
-- API does.
create function pg_temp.file(p_actor uuid, p_input jsonb)
returns jsonb language plpgsql as $$
declare r jsonb;
begin
  perform set_config('request.jwt.claim.sub', p_actor::text, true);
  r := private.api_idempotency_reserve(null, 'v1.reportAiOutput', gen_random_uuid()::text,
    encode(extensions.digest(gen_random_uuid()::text, 'sha256'), 'hex'), 3600, 60);
  return private.ai_output_report_file(p_input,
    (r->>'id')::uuid, (r->>'generation')::bigint);
end $$;
\set QUIET off

-- 1. Filing.
create temp table filed on commit drop as
  select pg_temp.file(:'reporter', jsonb_build_object(
    'feature', 'tutor', 'reason', 'offensive',
    'details', '  It said something cruel.  ',
    'excerpt', 'Synthetic AI answer that must never leave the database')) as r;
select is((select r->>'outcome' from filed), 'ok', 'an account with no school files a report');
select ok((select (r->'response'->>'id')::uuid is not null
    and r->'response'->>'createdAt' ~ '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$'
  from filed), 'the response is the report id and an ISO time');
select is((select array[feature, reason, details, excerpt, status]
    from private.ai_output_reports where id = (select (r->'response'->>'id')::uuid from filed)),
  array['tutor', 'offensive', 'It said something cruel.',
    'Synthetic AI answer that must never leave the database', 'open'],
  'the report is stored for its reporter, details trimmed');
select is((select reporter_id from private.ai_output_reports
    where id = (select (r->'response'->>'id')::uuid from filed)),
  :'reporter'::uuid, 'the reporter is the caller, never a body field');
select is((select response_body from public.idempotency_records
    where actor_id = :'reporter' and status = 'completed' order by created_at desc limit 1),
  (select r->'response' from filed),
  'the idempotency record holds the response, completed in the same transaction');
select ok((select response_body::text not like '%Synthetic AI answer%'
    from public.idempotency_records where actor_id = :'reporter'
    order by created_at desc limit 1),
  'and not the reported output');

select is(pg_temp.file(:'reporter', jsonb_build_object(
    'feature', 'quiz', 'reason', 'wrong', 'excerpt', repeat('x', 5000)))->>'outcome',
  'ok', 'a long output is accepted');
select is((select char_length(excerpt) from private.ai_output_reports
    where reporter_id = :'reporter' and feature = 'quiz'), 4000,
  'and kept to its first 4,000 characters');
select is((select details from private.ai_output_reports
    where reporter_id = :'reporter' and feature = 'quiz'), null,
  'no details is stored as none');

-- 2. Refusals.
select is(pg_temp.file(:'reporter', '{"feature":"chat","reason":"wrong","excerpt":"x"}')->>'outcome',
  'invalid', 'an unknown feature is refused');
select is(pg_temp.file(:'reporter', '{"feature":"notes","reason":"rude","excerpt":"x"}')->>'outcome',
  'invalid', 'an unknown reason is refused');
select is(pg_temp.file(:'reporter', '{"feature":"notes","reason":"other","excerpt":"   "}')->>'outcome',
  'invalid', 'an empty output is refused');
select is(pg_temp.file(:'reporter', jsonb_build_object('feature', 'notes', 'reason', 'other',
    'excerpt', 'x', 'details', repeat('d', 1001)))->>'outcome',
  'invalid', 'details over 1,000 characters are refused');
select is((select count(*)::int from private.ai_output_reports where reporter_id = :'reporter'),
  2, 'nothing refused was stored');
select set_config('request.jwt.claim.sub', '', true);
select is(private.ai_output_report_file('{"feature":"notes","reason":"other","excerpt":"x"}',
    gen_random_uuid(), 1)->>'outcome',
  'forbidden', 'nobody signed in files nothing');

-- 3. The alert carries the id, feature and reason, and nothing else.
select is((select count(*)::int from private.ai_output_report_alerts a
    join private.ai_output_reports r on r.id = a.report_id
    where r.reporter_id = :'reporter'), 2, 'every report queues one alert');
create temp table claimed on commit drop as
  select * from private.ai_output_alerts_claim(10, 120);
select is((select count(*)::int from claimed), 2, 'the worker claims them');
select is(
  (select array_agg(attname::text order by attnum) from pg_attribute
   where attrelid = 'pg_temp.claimed'::regclass and attnum > 0 and not attisdropped),
  array['report_id', 'feature', 'reason', 'reported_at', 'attempts'],
  'the claim returns no output, details, names or account ids');
select is((select count(*)::int from private.ai_output_alerts_claim(10, 120)), 0,
  'a claimed alert is leased, not claimed twice');
select ok(private.ai_output_alerts_finish((select report_id from claimed where feature = 'tutor'), true, null),
  'marking one sent succeeds');
select ok(private.ai_output_alerts_finish((select report_id from claimed where feature = 'quiz'), false,
    'https://api.telegram.org/bot123:secret'), 'a failure is recorded');
select is((select last_error from private.ai_output_report_alerts
    where report_id = (select report_id from claimed where feature = 'quiz')),
  'SEND_FAILED', 'as a generic code, not the text it was given');
select is((private.ai_output_alerts_backlog()->>'unsent')::int, 1,
  'the backlog counts the one still unsent');

-- 4. Export: the person's own reports only.
select is(pg_temp.file(:'other', '{"feature":"flashcards","reason":"harmful","excerpt":"Other output"}')->>'outcome',
  'ok', 'another account files its own');
select is(jsonb_array_length(private.data_export_document(:'reporter')->'sections'->'aiOutputReports'),
  2, 'the export lists the reporter''s reports');
select ok((private.data_export_document(:'reporter')->'sections'->'aiOutputReports')::text
    not like '%Other output%'
  and private.data_export_document(:'reporter')->'sections'->'aiMarking' is not null,
  'and not anyone else''s, keeping every earlier section');

-- 5. Retention: 180 days.
update private.ai_output_reports set created_at = now() - interval '181 days'
  where reporter_id = :'reporter' and feature = 'quiz';
select ok((private.ai_output_reports_purge(5000)->>'ai_output_reports')::int >= 1,
  'reports older than 180 days are purged');
select is((select count(*)::int from private.ai_output_reports where reporter_id = :'reporter'),
  1, 'with their alerts, and the newer one stays');

-- 6. A deleted account takes its reports with it, and files no more.
select is(pg_temp.file(:'leaver', '{"feature":"notebook","reason":"other","excerpt":"Leaver output"}')->>'outcome',
  'ok', 'an account about to leave files one');
update public.profiles set status = 'deleted', deleted_at = now() where id = :'leaver';
select is((select count(*)::int from private.ai_output_reports where reporter_id = :'leaver'),
  0, 'a deleted account''s reports are gone');
select is(pg_temp.file(:'leaver', '{"feature":"notes","reason":"other","excerpt":"x"}')->>'outcome',
  'forbidden', 'and a deleted account files nothing');

-- 7. Who may call what.
select ok(has_function_privilege('studafy_api_runtime', 'private.ai_output_report_file(jsonb, uuid, bigint)', 'execute')
  and not has_function_privilege('authenticated', 'private.ai_output_report_file(jsonb, uuid, bigint)', 'execute')
  and not has_function_privilege('anon', 'private.ai_output_report_file(jsonb, uuid, bigint)', 'execute')
  and not has_function_privilege('studafy_worker_runtime', 'private.ai_output_report_file(jsonb, uuid, bigint)', 'execute')
  and has_function_privilege('studafy_worker_runtime', 'private.ai_output_alerts_claim(integer, integer)', 'execute')
  and has_function_privilege('studafy_worker_runtime', 'private.ai_output_reports_purge(integer)', 'execute')
  and not has_function_privilege('studafy_api_runtime', 'private.ai_output_alerts_claim(integer, integer)', 'execute'),
  'the API files, the worker alerts and purges, and nobody else does either');
select ok(not has_table_privilege('studafy_api_runtime', 'private.ai_output_reports', 'select')
  and not has_table_privilege('studafy_worker_runtime', 'private.ai_output_reports', 'select')
  and not has_table_privilege('authenticated', 'private.ai_output_reports', 'select')
  and not has_table_privilege('service_role', 'private.ai_output_reports', 'select')
  and not has_table_privilege('studafy_worker_runtime', 'private.ai_output_report_alerts', 'select'),
  'the reports and alerts are reachable only through their functions');

select * from finish();
rollback;
