-- DL-080 (202611040010): production takes App Review, TestFlight and
-- license-tester purchases and records them as test purchases. They grant
-- the plan in production like any purchase, never join a real purchase's
-- lineage (or the reverse) through submit, restore, a store event or the
-- reconciliation sweep, and the flag never changes.
-- Transactional fixtures: this test leaves existing local users/data intact.
begin;
\set auth031_fixture_only true
\ir rls_access_seed.sql
\ir db021_access_seed.sql
\unset auth031_fixture_only
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select plan(28);
update private.notebook_runtime set environment='production';
select set_config('studafy.school_id', :'school_id', true);
-- Student purchases are on unless a school opts out (DL-071).
delete from public.school_billing_settings where school_id = :'school_id';

create temporary table tpp_body(name text primary key, body jsonb) on commit drop;
insert into tpp_body values
  -- An App Reviewer's (or TestFlight tester's) Plus, bought in Apple's Sandbox.
  ('sandbox_plus', jsonb_build_object(
    'platform','app_store','environment','production',
    'productFeatureKey','studafy_plus','storeProductId','studafy_plus_monthly',
    'originalTransactionId','tpp-sandbox-lineage','transactionId','tpp-sandbox-txn-1',
    'signedDataHash', repeat('a',64), 'state','active',
    'purchasedAt', now()::text, 'effectiveUntil', (now()+interval '30 days')::text,
    'renewalStatus','renewing','sandbox',true)),
  -- A real Max purchase on Google Play.
  ('real_max', jsonb_build_object(
    'platform','play_store','environment','production',
    'productFeatureKey','studafy_max','storeProductId','studafy_max_monthly',
    'originalTransactionId','tpp-real-lineage','transactionId','tpp-real-txn-1',
    'signedDataHash', repeat('b',64), 'state','active',
    'purchasedAt', now()::text, 'effectiveUntil', (now()+interval '30 days')::text,
    'renewalStatus','renewing','sandbox',false));

create or replace function pg_temp.event(p_hash text) returns bigint language sql as $$
  insert into public.store_events(platform, environment, payload_hash, state)
  values ('app_store', 'production', p_hash, 'processing') returning id;
$$;
create or replace function pg_temp.txn(p_transaction text) returns public.store_transactions
language sql as $$
  select * from public.store_transactions
  where environment = 'production' and transaction_id = p_transaction;
$$;

-- 1. The column.
select col_not_null('public', 'store_transactions', 'sandbox',
  'every store transaction says whether it was a test purchase');
select col_default_is('public', 'store_transactions', 'sandbox', 'false',
  'a transaction is a real purchase unless the verified store data says otherwise');

-- 2. A test purchase on production grants the plan there.
select set_config('request.jwt.claim.sub', :'second_student_user', true);
select is(private.study_plan(:'second_student_user'), 'free', 'the student starts on Free');
select is(private.billing_submit_verification((select body from tpp_body where name='sandbox_plus'))->>'outcome',
  'ok', 'production takes an Apple Sandbox purchase');
select is((pg_temp.txn('tpp-sandbox-txn-1')).sandbox, true, 'it is recorded as a test purchase');
select is((pg_temp.txn('tpp-sandbox-txn-1')).environment, 'production',
  'in the server''s own environment');
select is((pg_temp.txn('tpp-sandbox-txn-1')).renewal_status, 'renewing',
  'with its renewal status');
select is(private.study_plan(:'second_student_user'), 'plus',
  'and it grants Plus in production, so a reviewer sees the plan work');

-- 3. A real purchase is recorded as one; a body without the flag is real.
select is(private.billing_submit_verification((select body from tpp_body where name='real_max'))->>'outcome',
  'ok', 'a real purchase is taken');
select is((pg_temp.txn('tpp-real-txn-1')).sandbox, false, 'and recorded as real');
select is(private.billing_submit_verification((select body from tpp_body where name='real_max')
    - 'sandbox' || '{"transactionId":"tpp-real-txn-2"}'::jsonb)->>'outcome',
  'ok', 'a renewal from an API that sends no flag is taken as real');
select is((pg_temp.txn('tpp-real-txn-2')).sandbox, false, 'and recorded as real');

-- 4. Test and real purchases never share a lineage.
select is(private.billing_submit_verification((select body from tpp_body where name='real_max')
    || '{"transactionId":"tpp-forged-1","sandbox":true}'::jsonb)->>'outcome',
  'store_environment_mismatch', 'a test purchase cannot extend a real lineage');
select is((select count(*) from public.store_transactions where transaction_id = 'tpp-forged-1'),
  0::bigint, 'nothing is recorded for it');
select is(private.billing_restore((select body from tpp_body where name='sandbox_plus')
    || '{"transactionId":"tpp-forged-2","sandbox":false}'::jsonb)->>'outcome',
  'store_environment_mismatch', 'a real purchase cannot be restored onto a test lineage');
select is(private.billing_submit_verification((select body from tpp_body where name='sandbox_plus')
    || '{"sandbox":false}'::jsonb)->>'outcome',
  'store_environment_mismatch', 'a known test transaction cannot be resubmitted as real');
-- Ownership is still decided first.
select set_config('request.jwt.claim.sub', :'student_user', true);
select is(private.billing_submit_verification((select body from tpp_body where name='sandbox_plus')
    || '{"transactionId":"tpp-other-1","sandbox":false}'::jsonb)->>'outcome',
  'owned_by_other_account', 'another account''s lineage is still refused as owned by them');
select set_config('request.jwt.claim.sub', :'second_student_user', true);

-- 5. Store events: one for the other environment's lineage is dead-lettered.
select is(private.billing_finish_event(pg_temp.event(repeat('c',64)), jsonb_build_object(
  'platform','app_store','environment','production','originalTransactionId','tpp-sandbox-lineage',
  'transactionId','tpp-sandbox-txn-1','storeProductId','studafy_plus_monthly','state','expired',
  'purchasedAt',now()::text,'effectiveUntil',(now()-interval '1 minute')::text,'sandbox',false)),
  'terminal', 'a real event naming a test lineage is not applied');
select is((select state::text || ':' || last_error_code from public.store_events where payload_hash = repeat('c',64)),
  'dead_letter:STORE_ENVIRONMENT_MISMATCH', 'it is dead-lettered with the reason');
select is((pg_temp.txn('tpp-sandbox-txn-1')).state::text, 'active', 'and the test purchase is unchanged');

-- A matching event that records a new transaction (an Apple plan change in
-- the Sandbox) copies the lineage's flag.
select is(private.billing_finish_event(pg_temp.event(repeat('d',64)), jsonb_build_object(
  'platform','app_store','environment','production','originalTransactionId','tpp-sandbox-lineage',
  'transactionId','tpp-sandbox-txn-2','storeProductId','studafy_max_monthly','state','active',
  'purchasedAt',now()::text,'effectiveUntil',(now()+interval '30 days')::text,'sandbox',true)),
  'completed', 'a test event on a test lineage is applied');
select is((pg_temp.txn('tpp-sandbox-txn-2')).sandbox, true,
  'the new transaction it records is a test purchase too');

-- 6. The reconciliation sweep.
select ok((select bool_and(c ? 'sandbox') from jsonb_array_elements(
    private.billing_reconciliation_scan(1000)) c),
  'the sweep says whether each candidate is a test purchase');
select is((select (c->>'sandbox')::boolean from jsonb_array_elements(
    private.billing_reconciliation_scan(1000)) c where c->>'storeTransactionId' = 'tpp-real-txn-1'),
  false, 'an unacknowledged real Play purchase is a real candidate');
select is(private.billing_reconcile_transaction((pg_temp.txn('tpp-real-txn-1')).id, jsonb_build_object(
  'platform','play_store','environment','production','originalTransactionId','tpp-real-lineage',
  'state','expired','effectiveUntil',(now()-interval '1 minute')::text,'acknowledged',true,
  'sandbox',true)),
  'store_environment_mismatch', 'a test answer for a real purchase is not applied');
select ok((select state = 'active' and acknowledged_at is null from public.store_transactions
    where transaction_id = 'tpp-real-txn-1'),
  'the real purchase is left as it was');

-- 7. The flag never changes, and nothing new is callable by clients.
select throws_ok(
  $$update public.store_transactions set sandbox = false where transaction_id = 'tpp-sandbox-txn-1'$$,
  '22000', null, 'a test purchase can never be turned into a real one');
select ok(not has_function_privilege('authenticated', 'private.billing_apply_verification(jsonb,boolean)', 'execute')
  and not has_function_privilege('studafy_api_runtime', 'private.billing_apply_verification(jsonb,boolean)', 'execute')
  and not has_function_privilege('studafy_api_runtime', 'private.billing_finish_event(bigint,jsonb)', 'execute')
  and not has_function_privilege('studafy_api_runtime', 'private.billing_reconcile_transaction(uuid,jsonb)', 'execute')
  and has_function_privilege('studafy_worker_runtime', 'private.billing_finish_event(bigint,jsonb)', 'execute')
  and has_function_privilege('studafy_worker_runtime', 'private.billing_reconcile_transaction(uuid,jsonb)', 'execute')
  and has_function_privilege('studafy_worker_runtime', 'private.billing_reconciliation_scan(integer)', 'execute')
  and has_function_privilege('studafy_api_runtime', 'private.billing_submit_verification(jsonb)', 'execute'),
  'the grants are as before');

select * from finish();
rollback;
