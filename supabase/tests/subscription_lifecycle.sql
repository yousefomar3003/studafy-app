-- Subscription lifecycle (202609290004): renewal status, events that land on
-- the transaction they are about, lost renewals, and verified-only
-- subscription notifications.
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

create temporary table lifecycle_event(id bigint);
create or replace function pg_temp.event(p_hash text) returns bigint language sql as $$
  insert into public.store_events(platform, environment, payload_hash, state)
  values ('play_store', 'synthetic', p_hash, 'processing') returning id;
$$;
create or replace function pg_temp.apple_event(p_hash text) returns bigint language sql as $$
  insert into public.store_events(platform, environment, payload_hash, state)
  values ('app_store', 'synthetic', p_hash, 'processing') returning id;
$$;
create or replace function pg_temp.status(p_user uuid, p_feature text) returns text language sql as $$
  select status::text from public.entitlements
  where user_id = p_user and feature_key = p_feature order by updated_at desc limit 1;
$$;
create or replace function pg_temp.notified(p_user uuid, p_kind text) returns bigint language sql as $$
  select count(*) from public.notification_outbox
  where recipient_id = p_user and template_key = p_kind;
$$;

-- 0. The worker can claim and dead-letter a recorded webhook event. Before
-- 202609290004 every update of store_events failed on a missing column.
insert into public.store_events(platform, environment, payload_hash)
  values ('play_store', 'synthetic', repeat('0',64));
select ok(private.billing_claim_events_for_dispatch('pgtap-worker', 50) @> jsonb_build_array(
  jsonb_build_object('eventId', (select id from public.store_events where payload_hash=repeat('0',64)))),
  'a recorded store event is claimed for processing');
select lives_ok($$select private.billing_fail_event(
  (select id from public.store_events where payload_hash=repeat('0',64)), 'PGTAP')$$,
  'a store event that cannot be processed is dead-lettered');

-- 1. A client purchase records what happens at the end of the period.
select set_config('request.jwt.claim.sub', :'guardian_user', true);
select is(private.billing_submit_verification(jsonb_build_object(
  'platform','play_store','environment','synthetic','productFeatureKey','studafy_plus',
  'storeProductId','studafy_plus_monthly','originalTransactionId','lifecycle-lineage',
  'transactionId','lifecycle-plus','signedDataHash',repeat('a',64),'state','active',
  'purchasedAt',now()::text,'effectiveUntil',(now()+interval '1 month')::text,
  'renewalStatus','renewing','beneficiaryStudentId',:'student_id')) ->> 'outcome', 'ok',
  'a guardian buys Studafy Plus for their child');
select is((select renewal_status from public.store_transactions where transaction_id='lifecycle-plus'),
  'renewing', 'the renewal status is stored with the transaction');
select is(pg_temp.notified(:'guardian_user', 'billing.subscription_active'), 1::bigint,
  'the payer is told the verified subscription is active');
select is(pg_temp.notified(:'student_user', 'billing.subscription_active'), 0::bigint,
  'the child who did not pay is not sent the payment notice');

select set_config('request.jwt.claim.sub', :'student_user', true);
select is((select e->>'renewalStatus' || '/' || (e->>'platform') || '/' || (e->>'storeProductId')
  from jsonb_array_elements(private.billing_list_entitlements('synthetic')) e
  where e->>'featureKey' = 'studafy_plus'),
  'renewing/play_store/studafy_plus_monthly',
  'the app reads the renewal status and where to manage it');
select is((select (e->>'purchasedByMe')::boolean
  from jsonb_array_elements(private.billing_list_entitlements('synthetic')) e
  where e->>'featureKey' = 'studafy_plus'), false,
  'the child sees that a parent pays, so the app sends them to the parent');

-- 2. Google upgrade: the new Max token is linked to the Plus lineage. The old
-- token's expiry must not take Max away.
select set_config('request.jwt.claim.sub', :'guardian_user', true);
select is(private.billing_submit_verification(jsonb_build_object(
  'platform','play_store','environment','synthetic','productFeatureKey','studafy_max',
  'storeProductId','studafy_max_monthly','originalTransactionId','lifecycle-lineage',
  'transactionId','lifecycle-max','signedDataHash',repeat('b',64),'state','active',
  'purchasedAt',now()::text,'effectiveUntil',(now()+interval '1 month')::text,
  'renewalStatus','renewing','beneficiaryStudentId',:'student_id')) ->> 'outcome', 'ok',
  'the upgrade to Max is verified in the same lineage');
select is(private.billing_finish_event(pg_temp.event(repeat('1',64)), jsonb_build_object(
  'platform','play_store','environment','synthetic','originalTransactionId','lifecycle-lineage',
  'transactionId','lifecycle-plus','state','expired','purchasedAt',(now()-interval '1 month')::text,
  'effectiveUntil',(now()-interval '1 minute')::text)), 'completed',
  'the replaced Plus token''s expiry is processed');
select is(pg_temp.status(:'student_user', 'studafy_max'), 'active',
  'the old token''s expiry leaves the new Max plan active');
select is(pg_temp.status(:'student_user', 'studafy_plus'), 'expired',
  'the expiry lands on the Plus plan it was about');
select is(private.study_plan(:'student_user'), 'max', 'the student is on Max');

-- 3. A token the ledger has not seen is a new purchase in the same lineage.
select is(private.billing_finish_event(pg_temp.event(repeat('2',64)), jsonb_build_object(
  'platform','play_store','environment','synthetic','originalTransactionId','lifecycle-lineage',
  'transactionId','lifecycle-resubscribe','storeProductId','studafy_max_monthly',
  'state','active','purchasedAt',now()::text,
  'effectiveUntil',(now()+interval '1 month')::text)), 'completed',
  'an unseen token in a known lineage is processed');
select is((select purchaser_id::text || '/' || beneficiary_id::text
  from public.store_transactions where transaction_id='lifecycle-resubscribe'),
  :'guardian_user' || '/' || :'student_user',
  'it is recorded for the lineage''s own payer and child, not guessed');

-- 4. Renewal, payment problem and cancellation, as the store reports them.
select is(private.billing_finish_event(pg_temp.event(repeat('3',64)), jsonb_build_object(
  'platform','play_store','environment','synthetic','originalTransactionId','lifecycle-lineage',
  'transactionId','lifecycle-max','state','active','renewalStatus','renewing',
  'purchasedAt',now()::text,'effectiveUntil',(now()+interval '2 months')::text)), 'completed',
  'a renewal is processed');
select is(pg_temp.notified(:'guardian_user', 'billing.subscription_renewed'), 1::bigint,
  'the payer is told the subscription renewed');
select is(private.billing_finish_event(pg_temp.event(repeat('4',64)), jsonb_build_object(
  'platform','play_store','environment','synthetic','originalTransactionId','lifecycle-lineage',
  'transactionId','lifecycle-max','state','on_hold','renewalStatus','payment_issue',
  'purchasedAt',(now()-interval '1 month')::text,
  'effectiveUntil',(now()-interval '1 minute')::text)), 'completed',
  'a failed renewal is processed');
select is(pg_temp.notified(:'guardian_user', 'billing.payment_problem'), 1::bigint,
  'the payer is told about the payment problem');
select is(private.study_plan(:'student_user'), 'free',
  'a subscription on hold grants nothing');

-- 5. A renewal whose webhook never came is re-verified by the sweep, hourly.
update public.store_transactions set state='active', reconciled_at=null,
  effective_until=now()-interval '1 day' where transaction_id='lifecycle-resubscribe';
select ok(private.billing_reconciliation_scan(100) @> jsonb_build_array(
  jsonb_build_object('storeTransactionId','lifecycle-resubscribe')),
  'a lapsed active row is picked up by the sweep');
select is(private.billing_reconcile_transaction(
  (select id from public.store_transactions where transaction_id='lifecycle-resubscribe'),
  jsonb_build_object('platform','play_store','environment','synthetic',
    'originalTransactionId','lifecycle-lineage','state','active','renewalStatus','renewing',
    'acknowledged',true,
    'purchasedAt',now()::text,'effectiveUntil',(now()+interval '1 month')::text)),
  'updated', 'the store''s renewal is applied');
update public.store_transactions set effective_until=now()-interval '1 day'
  where transaction_id='lifecycle-resubscribe';
select ok(not private.billing_reconciliation_scan(100) @> jsonb_build_array(
  jsonb_build_object('storeTransactionId','lifecycle-resubscribe')),
  'a row re-verified in the last hour waits for the next hour');

-- 6. An Apple plan change made in the device's settings.
insert into public.guardian_links (student_id, guardian_id, status, relationship, verified_by, verified_at)
values (:'second_student_id', :'guardian_user', 'verified', 'parent', :'teacher_user', now())
on conflict (student_id, guardian_id) do nothing;
select is(private.billing_submit_verification(jsonb_build_object(
  'platform','app_store','environment','synthetic','productFeatureKey','studafy_plus',
  'storeProductId','studafy_plus_monthly','originalTransactionId','lifecycle-apple',
  'transactionId','lifecycle-apple-1','signedDataHash',repeat('c',64),'state','active',
  'purchasedAt',now()::text,'effectiveUntil',(now()+interval '1 month')::text,
  'beneficiaryStudentId',:'second_student_id')) ->> 'outcome', 'ok',
  'Plus is bought on the App Store');
select is(private.billing_finish_event(pg_temp.apple_event(repeat('5',64)), jsonb_build_object(
  'platform','app_store','environment','synthetic','originalTransactionId','lifecycle-apple',
  'transactionId','lifecycle-apple-2','storeProductId','studafy_max_monthly','state','active',
  'renewalStatus','renewing','purchasedAt',now()::text,
  'effectiveUntil',(now()+interval '1 month')::text)), 'completed',
  'the renewal into Max is processed');
select is(pg_temp.status(:'second_student_user', 'studafy_max'), 'active',
  'Max is granted for the product the store now bills');

-- 7. Nothing new is callable by a client or the API role.
select ok(not has_function_privilege('authenticated','private.billing_event_transaction(jsonb,text)','execute')
  and not has_function_privilege('studafy_api_runtime','private.billing_apply_event_state(public.store_transactions,jsonb)','execute')
  and not has_function_privilege('studafy_api_runtime','private.billing_finish_event(bigint,jsonb)','execute')
  and has_function_privilege('studafy_worker_runtime','private.billing_finish_event(bigint,jsonb)','execute'),
  'only the worker drives the ledger from store events');

select * from finish();
rollback;
