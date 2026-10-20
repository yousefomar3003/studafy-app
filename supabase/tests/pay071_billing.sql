-- PAY-071 ledger trust boundary, exercised through the same SECURITY DEFINER
-- commands the API runtime calls. The API has already verified the store
-- signature, account binding and environment; these tests prove what SQL
-- still owns: lineage ownership, the storefront gate, beneficiary links,
-- the self-purchase switch (on unless a school opts out, DL-071) and
-- environment-scoped reads.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select plan(31);

\set school_id '11111111-1111-4111-8111-111111111111'
\set student_user 'bbbb0000-0000-4000-8000-000000000002'
\set guardian_user 'cccc0000-0000-4000-8000-000000000003'
\set unverified_guardian 'dddd0000-0000-4000-8000-000000000004'
\set expired_guardian_user 'ffff0000-0000-4000-8000-000000000004'
\set second_student_user 'ffff0000-0000-4000-8000-000000000003'
\set student_id 'abcf0000-0000-4000-8000-000000000008'

create temporary table pay071_body(name text primary key, body jsonb) on commit drop;
insert into pay071_body values
  ('insights', jsonb_build_object(
    'platform','play_store','environment','synthetic',
    'productFeatureKey','parent_insights',
    'storeProductId','studafy_parent_insights_monthly',
    'originalTransactionId','pay071-lineage-1','transactionId','pay071-txn-1',
    'signedDataHash', repeat('a',64), 'state','active',
    'purchasedAt', now()::text, 'effectiveUntil', (now()+interval '30 days')::text,
    'beneficiaryStudentId','abcf0000-0000-4000-8000-000000000008')),
  ('plus', jsonb_build_object(
    'platform','play_store','environment','synthetic',
    'productFeatureKey','studafy_plus',
    'storeProductId','studafy_plus_monthly',
    'originalTransactionId','pay071-lineage-2','transactionId','pay071-txn-2',
    'signedDataHash', repeat('b',64), 'state','active',
    'purchasedAt', now()::text, 'effectiveUntil', (now()+interval '30 days')::text));


-- Commands run as the table owner here; auth.uid() comes from the claim,
-- exactly as the API sets it. Execute privileges are asserted separately.

-- 1. A guardian with a verified link buys Parent Insights for the child.
select set_config('request.jwt.claim.sub', :'guardian_user', true);
select is(private.billing_submit_verification((select body from pay071_body where name='insights'))->>'outcome', 'ok',
  'a verified guardian can buy Parent Insights for the linked child');
select is((select count(*) from jsonb_array_elements(private.billing_list_entitlements('synthetic')) r
  where r->>'featureKey'='parent_insights' and r->>'beneficiaryStudentId'=:'student_id'
    and r->>'status'='active'), 1::bigint,
  'the purchasing guardian reads the child''s Parent Insights entitlement by student id');
select is(jsonb_array_length(private.billing_list_entitlements('production')), 0,
  'a synthetic purchase is invisible to a production entitlement read');

-- 2. The child holds the entitlement as its own row.
select set_config('request.jwt.claim.sub', :'student_user', true);
select is((select count(*) from jsonb_array_elements(private.billing_list_entitlements('synthetic')) r
  where r->>'featureKey'='parent_insights' and r->'beneficiaryStudentId' = 'null'::jsonb), 1::bigint,
  'the beneficiary child holds the entitlement, not the purchaser');

-- 3. Lineage ownership (audit H4): a renewal of an owned lineage presented by
-- another account is refused on both submit and restore.
select set_config('request.jwt.claim.sub', :'unverified_guardian', true);
select is(private.billing_submit_verification((select body || '{"transactionId":"pay071-txn-1-renewal"}'::jsonb from pay071_body where name='insights'))->>'outcome', 'owned_by_other_account',
  'a different renewal transaction of a claimed lineage cannot be submitted by another account');
select is(private.billing_restore((select body || '{"transactionId":"pay071-txn-1-renewal"}'::jsonb from pay071_body where name='insights'))->>'outcome', 'owned_by_other_account',
  'nor restored by another account');
select is(private.billing_submit_verification((select body from pay071_body where name='insights'))->>'outcome', 'owned_by_other_account',
  'the exact claimed transaction cannot be replayed by another account');

-- 4. The owner can renew and restore their own lineage.
select set_config('request.jwt.claim.sub', :'guardian_user', true);
select is(private.billing_submit_verification((select body || '{"transactionId":"pay071-txn-1-renewal"}'::jsonb from pay071_body where name='insights'))->>'outcome', 'ok',
  'the owning guardian records a renewal of the same lineage');
select is(private.billing_restore((select body from pay071_body where name='insights'))->>'outcome', 'ok',
  'the owning guardian restores the lineage');

-- 5. Beneficiary links: unverified and expired guardians cannot buy.
select set_config('request.jwt.claim.sub', :'unverified_guardian', true);
select is(private.billing_submit_verification((select body || '{"originalTransactionId":"pay071-lineage-3","transactionId":"pay071-txn-3"}'::jsonb from pay071_body where name='insights'))->>'outcome',
  'beneficiary_link_invalid', 'a pending guardian link cannot purchase for the child');
select set_config('request.jwt.claim.sub', :'expired_guardian_user', true);
select is(private.billing_submit_verification((select body || '{"originalTransactionId":"pay071-lineage-4","transactionId":"pay071-txn-4"}'::jsonb from pay071_body where name='insights'))->>'outcome',
  'beneficiary_link_invalid', 'an expired guardian link cannot purchase for the child');

-- 6. The storefront gate (audit H2): an unlisted product cannot be granted by
-- a first-seen receipt, by submit or by restore.
--
-- Aimed at student_ai rather than Parent Insights. Parent Insights was the
-- unlisted product when this was written, but 202609240002 listed it once the
-- owner took the ADR-0009/§29 decision, which left these two assertions
-- testing nothing. student_ai is retired by ADR-0026 and cannot be listed
-- again without a new migration, so the gate is proved against something that
-- stays unlisted rather than against whichever product is awaiting a
-- commercial decision this month.
select set_config('request.jwt.claim.sub', :'guardian_user', true);
select ok((select not storefront_listed from public.store_products
  where feature_key = 'student_ai' and platform = 'play_store' limit 1),
  'the product behind the gate assertions is genuinely unlisted');
select is(private.billing_submit_verification(
  (select body || jsonb_build_object(
    'environment','production','productFeatureKey','student_ai',
    'storeProductId','studafy_student_ai_monthly',
    'originalTransactionId','pay071-lineage-5','transactionId','pay071-txn-5')
   from pay071_body where name='insights'))->>'outcome',
  'product_not_found', 'an unlisted product cannot be purchased with a valid production receipt');
select is(private.billing_restore(
  (select body || jsonb_build_object(
    'environment','production','productFeatureKey','student_ai',
    'storeProductId','studafy_student_ai_monthly',
    'originalTransactionId','pay071-lineage-6','transactionId','pay071-txn-6')
   from pay071_body where name='insights'))->>'outcome',
  'product_not_found', 'a first-seen receipt cannot bypass the storefront gate by calling itself a restore');

-- 7. Student self-purchase (DL-071): a student buys their own study plan
-- with no guardian approval. A caller-asserted confirmation flag changes
-- nothing, a school that opts out is refused, and the retired approval
-- functions create, list and decide nothing.
select set_config('request.jwt.claim.sub', :'student_user', true);
insert into public.school_billing_settings(school_id, self_purchase_enabled) values (:'school_id', false)
  on conflict (school_id) do update set self_purchase_enabled = false;
select is(private.billing_submit_verification((select body from pay071_body where name='plus'))->>'outcome',
  'student_purchase_disabled', 'a school that opted out refuses a student purchase');
update public.school_billing_settings set self_purchase_enabled = true where school_id = :'school_id';
select is(private.billing_submit_verification((select body || '{"parentalGateConfirmed":true}'::jsonb
    from pay071_body where name='plus'))->>'outcome', 'ok',
  'the student''s own purchase verifies with no approval');
select ok((select purchase_approval_id is null and parental_gate_confirmed_at is null
    and beneficiary_id = :'student_user'::uuid
    from public.store_transactions where transaction_id = 'pay071-txn-2'),
  'the ledger records the student as beneficiary and no approval');
select is(private.billing_submit_verification((select body from pay071_body where name='plus')
    || '{"transactionId":"pay071-txn-2-renewal"}'::jsonb)->>'outcome', 'ok',
  'a renewal of the student''s lineage verifies');
select is(private.billing_request_purchase_approval('studafy_plus')->>'outcome', 'not_eligible',
  'an approval can no longer be requested');
select set_config('request.jwt.claim.sub', :'guardian_user', true);
select is(private.billing_list_purchase_approvals(), '[]'::jsonb,
  'a guardian is listed no approvals');
select is(private.billing_decide_purchase_approval(gen_random_uuid(), true)->>'outcome',
  'not_found', 'nothing can be decided');
select set_config('request.jwt.claim.sub', :'second_student_user', true);
select is(private.billing_submit_verification((select body from pay071_body where name='plus')
    || '{"originalTransactionId":"pay071-lineage-7","transactionId":"pay071-txn-7"}'::jsonb)->>'outcome',
  'ok', 'a student with no verified guardian buys their own plan');
select is((select count(*) from public.billing_purchase_approvals
  where student_user_id in (:'student_user', :'second_student_user')), 0::bigint,
  'no approval rows are written');

-- 8. Lifecycle changes are recorded, identity is pinned, nothing is deleted.
select is((select count(*) from public.store_transaction_history h
  join public.store_transactions t on t.id = h.store_transaction_id
  where t.transaction_id = 'pay071-txn-1'), 0::bigint,
  'an unchanged restore writes no history row');
update public.store_transactions set state = 'refunded', effective_until = now()
  where transaction_id = 'pay071-txn-1';
select is((select h.new_state::text from public.store_transaction_history h
  join public.store_transactions t on t.id = h.store_transaction_id
  where t.transaction_id = 'pay071-txn-1'), 'refunded',
  'a refund moves the ledger state and is recorded in the append-only history');
select throws_ok($$ update public.store_transactions set beneficiary_id = 'ffff0000-0000-4000-8000-000000000003'
  where transaction_id = 'pay071-txn-1' $$, '22000', null,
  'the beneficiary of a ledger row cannot be rewritten');
select throws_ok($$ delete from public.store_transactions where transaction_id = 'pay071-txn-1' $$,
  'P0001', null, 'ledger rows cannot be deleted');
update public.store_transactions set acknowledged_at = now() where transaction_id = 'pay071-txn-1';
select throws_ok($$ update public.store_transactions set acknowledged_at = null
  where transaction_id = 'pay071-txn-1' $$, '22000', null,
  'a recorded store acknowledgement cannot be cleared');

-- 9. The worker's reconciliation path, which previously always raised on
-- the append-only trigger, now revokes access for an expired renewal.
select isnt(private.billing_reconcile_transaction(
    (select id from public.store_transactions where transaction_id = 'pay071-txn-1-renewal'),
    jsonb_build_object('originalTransactionId','pay071-lineage-1','state','expired',
      'purchasedAt', now()::text, 'effectiveUntil', now()::text, 'acknowledged', true)),
  null, 'reconciliation can record an expiry on the ledger');
select is((select acknowledged_at is not null from public.store_transactions
  where transaction_id = 'pay071-txn-1-renewal'), true,
  'reconciliation records the store acknowledgement once');

-- 10. The retired unscoped reader cannot be called by the API runtime.
select ok(not has_function_privilege('studafy_api_runtime',
    'private.billing_list_entitlements()', 'execute'),
  'the retired environment-blind entitlement reader is not executable by the API');

select * from finish();
rollback;
