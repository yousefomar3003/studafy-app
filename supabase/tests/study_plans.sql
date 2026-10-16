-- Free Lessons, Studafy Plus / Max, and the AI spending ledger (ADR-0029).
-- Transactional fixtures: this test leaves existing local users/data intact.
begin;
\set auth031_fixture_only true
\ir rls_access_seed.sql
\ir db021_access_seed.sql
\unset auth031_fixture_only
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select plan(27);
update private.notebook_runtime set environment='synthetic';
select set_config('studafy.school_id', :'school_id', true);

-- 1. Lessons are free: no entitlement stands between an enrolled student and
-- their class's published material.
select set_config('request.jwt.claim.sub', :'student_user', true);
select ok(private.notebook_reader_allowed(:'school_id'), 'every signed-in reader is allowed');
select ok(private.api041_query('listResources', :'school_id', '{}') ? 'items',
  'an unpaid student lists their class lessons');
select ok(private.can_view_resource(:'clean_resource_id'),
  'an unpaid student opens a published lesson');
select is((select count(*) from public.store_products
  where feature_key='student_notebook' and (active or storefront_listed)), 0::bigint,
  'the retired Student Notebook product is on sale nowhere');

-- 2. The plan is decided on the server, from store entitlements and grants.
select is(private.study_plan(:'student_user'), 'free', 'no entitlement is the free plan');
select set_config('request.jwt.claim.sub', :'guardian_user', true);
select is(private.billing_submit_verification(jsonb_build_object(
  'platform','play_store','environment','synthetic','productFeatureKey','studafy_plus',
  'storeProductId','studafy_plus_monthly','originalTransactionId','study-plan-lineage',
  'transactionId','study-plan-txn-1','signedDataHash',repeat('d',64),'state','active',
  'purchasedAt',now()::text,'effectiveUntil',(now()+interval '1 month')::text,
  'beneficiaryStudentId',:'student_id')) ->> 'outcome', 'ok',
  'a verified guardian buys Studafy Plus for their child');
select is(private.study_plan(:'student_user'), 'plus', 'a live Plus entitlement is the plus plan');
select is(private.study_plan(:'second_student_user'), 'free',
  'one child''s purchase never unlocks another student');
update private.notebook_runtime set environment='production';
select is(private.study_plan(:'student_user'), 'free',
  'a sandbox purchase cannot unlock production');
update private.notebook_runtime set environment='synthetic';
insert into private.study_plan_grants(user_id, plan, reason, ends_at)
  values (:'student_user', 'max', 'pgTAP comp grant', now() + interval '1 day');
select is(private.study_plan(:'student_user'), 'max', 'Max outranks Plus');
update private.study_plan_grants set starts_at = now() - interval '2 days',
  ends_at = now() - interval '1 second' where user_id = :'student_user';
select is(private.study_plan(:'student_user'), 'plus', 'an expired grant counts for nothing');
update public.entitlements set status='revoked'
  where user_id=:'student_user' and feature_key='studafy_plus';
select is(private.study_plan(:'student_user'), 'free', 'a refund or revocation locks at once');

-- 3. What each plan permits, in one place.
select is(private.ai_plan_limits('free')->>'capMicroUsd', '0', 'free has no money allowance');
select is(private.ai_plan_limits('plus')->>'capMicroUsd', '800000', 'Plus is capped at $0.80 a month');
select is(private.ai_plan_limits('max')->>'capMicroUsd', '1600000', 'Max is capped at $1.60 a month');
select ok(not (private.ai_plan_limits('plus')->'features') ? 'quiz'
  and (private.ai_plan_limits('max')->'features') ?& array['whiteboard','quiz','flashcards'],
  'quizzes are Max only, and Max includes everything in Plus');

-- The student has agreed to the AI notice (ADR-0043); without it the
-- ledger refuses before holding a token (ai_access_consent.sql).
insert into public.consent_records (user_id, purpose, policy_version, locale,
  policy_id, given_by, given_as)
select :'student_user', 'ai_features', p.policy_version, 'en', p.id,
  :'student_user', 'self'
from public.consent_policies p
where p.purpose = 'ai_features' and p.locale = 'en'
order by p.effective_at desc, p.policy_version desc limit 1
on conflict (user_id, purpose, policy_version) do update set withdrawn_at = null;

-- 4. The ledger refuses before any provider is called.
select set_config('request.jwt.claim.sub', :'student_user', true);
select is(private.api047_ai_usage('reserve', jsonb_build_object(
  'feature','whiteboard','estimateMicroUsd',5000,'estimateTokens',1000))->>'outcome', 'plan_required',
  'a free student cannot reserve a whiteboard call');
select is(private.api047_ai_usage('reserve', jsonb_build_object(
  'feature','ask','estimateMicroUsd',400,'estimateTokens',1000))->>'outcome', 'ok',
  'a free student can ask a question');
select is(private.api047_ai_usage('reserve', jsonb_build_object(
  'feature','ask','estimateMicroUsd',100001,'estimateTokens',1000))->>'outcome', 'invalid',
  'no single call may hold more than ten cents');
insert into private.study_plan_grants(user_id, plan, reason, ends_at)
  values (:'student_user', 'plus', 'pgTAP cap check', now() + interval '1 day');
insert into private.ai_usage(user_id, feature, plan, month, status, reserved_micro_usd, cost_micro_usd)
  values (:'student_user', 'whiteboard', 'plus', date_trunc('month', now() at time zone 'utc')::date,
    'settled', 0, 796000);
select is(private.api047_ai_usage('reserve', jsonb_build_object(
  'feature','whiteboard','estimateMicroUsd',5000,'estimateTokens',1000))->>'outcome', 'monthly_cap',
  'a reservation that would pass the monthly cap is refused');
select is(private.api047_ai_usage('reserve', jsonb_build_object(
  'feature','whiteboard','estimateMicroUsd',3000,'estimateTokens',1000))->>'outcome', 'ok',
  'a reservation that still fits is allowed');
select is(private.api047_ai_usage('summary', '{}')->>'committedMicroUsd', '799400',
  -- 796000 settled + the 400 question hold above + this 3000 hold.
  'a live hold counts against the cap before it settles');
select is(private.api047_ai_usage('reserve', jsonb_build_object(
  'feature','whiteboard','estimateMicroUsd',2000,'estimateTokens',1000))->>'outcome', 'monthly_cap',
  'the hold leaves no room for a second call that would pass the cap');
select is(private.api047_ai_usage('release', jsonb_build_object(
  'usageId', (select id from private.ai_usage where user_id=:'student_user'
    and status='reserved' and feature='whiteboard')))->>'outcome', 'ok',
  'a failed call releases its hold');
select is(private.api047_ai_usage('summary', '{}')->>'committedMicroUsd', '796400',
  'a released hold is charged nothing');

-- 5. Nobody but the API may drive the ledger or read plans directly.
select ok(not has_function_privilege('authenticated','private.api047_ai_usage(text,jsonb)','execute')
  and not has_function_privilege('anon','private.api047_ai_usage(text,jsonb)','execute'),
  'clients cannot call the ledger directly');
select ok(not has_function_privilege('studafy_api_runtime','private.study_plan(uuid)','execute')
  and not has_table_privilege('studafy_api_runtime','private.study_plan_grants','select'),
  'plans and grants are read only inside the ledger');

select * from finish();
rollback;
