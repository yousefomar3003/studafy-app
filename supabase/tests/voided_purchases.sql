-- Google Play voided purchases (202610150090): a refund or revocation found
-- by its purchase token ends the access that purchase granted, once, with an
-- audit trail, whichever of the voided purchase and SUBSCRIPTION_REVOKED
-- notifications comes first.
-- Transactional fixtures: this test leaves existing local users/data intact.
begin;
\set auth031_fixture_only true
\ir rls_access_seed.sql
\ir db021_access_seed.sql
\unset auth031_fixture_only
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select plan(24);
update private.notebook_runtime set environment='synthetic';

create or replace function pg_temp.event(p_hash text) returns bigint language sql as $$
  insert into public.store_events(platform, environment, payload_hash, state)
  values ('play_store', 'synthetic', p_hash, 'processing') returning id;
$$;
create or replace function pg_temp.voided(p_token text, p_state text) returns jsonb language sql as $$
  select jsonb_build_object('platform','play_store','environment','synthetic',
    'voided',true,'transactionId',p_token,'state',p_state);
$$;
create or replace function pg_temp.entitlements(p_user uuid, p_feature text) returns text language sql as $$
  select string_agg(status::text, ',' order by created_at) from public.entitlements
  where user_id = p_user and feature_key = p_feature;
$$;
create or replace function pg_temp.txn_state(p_token text) returns text language sql as $$
  select state::text from public.store_transactions
  where platform = 'play_store' and environment = 'synthetic' and transaction_id = p_token;
$$;
create or replace function pg_temp.history(p_token text) returns text language sql as $$
  select string_agg(h.previous_state::text || '>' || h.new_state::text, ',' order by h.id)
  from public.store_transaction_history h
  join public.store_transactions st on st.id = h.store_transaction_id
  where st.platform = 'play_store' and st.environment = 'synthetic' and st.transaction_id = p_token;
$$;
create or replace function pg_temp.notified(p_user uuid, p_kind text) returns bigint language sql as $$
  select count(*) from public.notification_outbox
  where recipient_id = p_user and template_key = p_kind;
$$;
create temporary table void_event(name text primary key, id bigint);

-- 1. A guardian buys Plus for their child on Google Play.
select set_config('request.jwt.claim.sub', :'guardian_user', true);
select is(private.billing_submit_verification(jsonb_build_object(
  'platform','play_store','environment','synthetic','productFeatureKey','studafy_plus',
  'storeProductId','studafy_plus_monthly','originalTransactionId','void-lineage-plus',
  'transactionId','void-plus','signedDataHash',repeat('d',64),'state','active',
  'purchasedAt',now()::text,'effectiveUntil',(now()+interval '1 month')::text,
  'renewalStatus','renewing','beneficiaryStudentId',:'student_id')) ->> 'outcome', 'ok',
  'a guardian buys Studafy Plus on Google Play');
select is(pg_temp.entitlements(:'student_user', 'studafy_plus'), 'active',
  'the child has Plus');

-- 2. A token the ledger has never seen waits, like any unknown transaction.
select is(private.billing_finish_event(pg_temp.event(repeat('e',64)),
  pg_temp.voided('void-unknown-token', 'refunded')), 'retry',
  'a voided purchase for an unknown token is retried, not dropped');
select is((select last_error_code from public.store_events where payload_hash = repeat('e',64)),
  'ORIGINAL_TRANSACTION_UNKNOWN', 'with the unknown-transaction reason');

-- 3. The purchase is refunded: the void is found by its token.
insert into void_event values ('plus', pg_temp.event(repeat('f',64)));
select is(private.billing_finish_event((select id from void_event where name='plus'),
  pg_temp.voided('void-plus', 'refunded')), 'completed',
  'the voided purchase is processed');
select is(pg_temp.txn_state('void-plus'), 'refunded', 'the transaction is refunded');
select is(pg_temp.entitlements(:'student_user', 'studafy_plus'), 'revoked',
  'the access it granted is revoked');
select is(private.study_plan(:'student_user'), 'free', 'the child is back on the free plan');
select is(pg_temp.history('void-plus'), 'active>refunded',
  'the refund is in the ledger''s audit history');
select is(pg_temp.notified(:'guardian_user', 'billing.subscription_ended'), 1::bigint,
  'the payer is told the subscription ended');

-- 4. Redelivery of the same message changes nothing.
select is(private.billing_finish_event((select id from void_event where name='plus'),
  pg_temp.voided('void-plus', 'refunded')), 'completed',
  'a redelivered voided purchase completes again');
select is(pg_temp.history('void-plus'), 'active>refunded', 'without another ledger change');

-- 5. Google also sends SUBSCRIPTION_REVOKED for the refund. The worker
-- re-verifies it and the store says expired: no second revocation.
select is(private.billing_finish_event(pg_temp.event(repeat('1',63) || 'a'), jsonb_build_object(
  'platform','play_store','environment','synthetic','originalTransactionId','void-lineage-plus',
  'transactionId','void-plus','state','expired','purchasedAt',(now()-interval '1 month')::text,
  'effectiveUntil',(now()-interval '1 minute')::text)), 'completed',
  'the revocation that follows the refund is processed');
select is(pg_temp.entitlements(:'student_user', 'studafy_plus'), 'revoked',
  'it does not add a second, ended entitlement');
select is(pg_temp.txn_state('void-plus'), 'refunded', 'the transaction stays refunded');
select is(pg_temp.notified(:'guardian_user', 'billing.subscription_ended'), 1::bigint,
  'the payer is not told twice');

-- 6. The other order: SUBSCRIPTION_REVOKED (store says expired) first, then
-- the voided purchase.
select is(private.billing_submit_verification(jsonb_build_object(
  'platform','play_store','environment','synthetic','productFeatureKey','studafy_max',
  'storeProductId','studafy_max_monthly','originalTransactionId','void-lineage-max',
  'transactionId','void-max','signedDataHash',repeat('9',64),'state','active',
  'purchasedAt',now()::text,'effectiveUntil',(now()+interval '1 month')::text,
  'renewalStatus','renewing','beneficiaryStudentId',:'student_id')) ->> 'outcome', 'ok',
  'the guardian buys Max');
select is(private.billing_finish_event(pg_temp.event(repeat('2',63) || 'a'), jsonb_build_object(
  'platform','play_store','environment','synthetic','originalTransactionId','void-lineage-max',
  'transactionId','void-max','state','expired','purchasedAt',(now()-interval '1 month')::text,
  'effectiveUntil',(now()-interval '1 minute')::text)), 'completed',
  'the revocation is processed first');
select is(private.billing_finish_event(pg_temp.event(repeat('3',63) || 'a'),
  pg_temp.voided('void-max', 'revoked')), 'completed',
  'then the voided purchase');
select is(pg_temp.entitlements(:'student_user', 'studafy_max'), 'expired',
  'the access ended once, with no second entitlement row');
select is(pg_temp.history('void-max'), 'active>expired,expired>revoked',
  'the void is still recorded on the transaction');

-- 7. A one-time product void is a no-op the worker completes.
select is(private.billing_finish_event(pg_temp.event(repeat('4',63) || 'a'), jsonb_build_object(
  'platform','play_store','environment','synthetic','noop',true)), 'completed',
  'a skipped one-time product void completes without a ledger change');
select is((select state::text from public.store_events where payload_hash = repeat('4',63) || 'a'),
  'completed', 'and is not left to retry');

-- 8. Nothing new is callable by a client, the API or the worker directly.
select ok(not has_function_privilege('authenticated',
    'private.billing_void_transaction(public.store_transactions,public.store_transaction_state)','execute')
  and not has_function_privilege('studafy_api_runtime',
    'private.billing_void_transaction(public.store_transactions,public.store_transaction_state)','execute')
  and not has_function_privilege('studafy_worker_runtime',
    'private.billing_void_transaction(public.store_transactions,public.store_transaction_state)','execute')
  and has_function_privilege('studafy_worker_runtime','private.billing_finish_event(bigint,jsonb)','execute')
  and not has_function_privilege('studafy_api_runtime','private.billing_finish_event(bigint,jsonb)','execute'),
  'only the worker drives voids, through billing_finish_event');

select * from finish();
rollback;
