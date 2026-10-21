-- DL-071: students buy Studafy Plus and Max themselves, with no guardian
-- approval in Studafy; Family+ still needs a verified guardian link; the
-- school switch is on unless a school opts out; the retired approval
-- functions create, list and decide nothing.
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

create temporary table sdp_body(name text primary key, body jsonb) on commit drop;
insert into sdp_body values
  ('plus', jsonb_build_object(
    'platform','play_store','environment','synthetic',
    'productFeatureKey','studafy_plus','storeProductId','studafy_plus_monthly',
    'originalTransactionId','sdp-plus-lineage','transactionId','sdp-plus-txn-1',
    'signedDataHash', repeat('1',64), 'state','active',
    'purchasedAt', now()::text, 'effectiveUntil', (now()+interval '30 days')::text)),
  ('max', jsonb_build_object(
    'platform','app_store','environment','synthetic',
    'productFeatureKey','studafy_max','storeProductId','studafy_max_monthly',
    'originalTransactionId','sdp-max-lineage','transactionId','sdp-max-txn-1',
    'signedDataHash', repeat('2',64), 'state','active',
    'purchasedAt', now()::text, 'effectiveUntil', (now()+interval '30 days')::text)),
  ('family', jsonb_build_object(
    'platform','play_store','environment','synthetic',
    'productFeatureKey','family_plus','storeProductId','studafy_family_plus_monthly',
    'originalTransactionId','sdp-family-lineage','transactionId','sdp-family-txn-1',
    'signedDataHash', repeat('3',64), 'state','active',
    'purchasedAt', now()::text, 'effectiveUntil', (now()+interval '30 days')::text));

-- 1. The school switch is on unless a school opts out.
select col_default_is('public', 'school_billing_settings', 'self_purchase_enabled', 'true',
  'a new school settings row allows student purchases');
select is((select count(*) from public.school_billing_settings where not self_purchase_enabled),
  0::bigint, 'no school is left switched off by the old default');
delete from public.school_billing_settings where school_id = :'school_id';
select set_config('request.jwt.claim.sub', :'second_student_user', true);
select is(private.billing_self_purchase_status(),
  jsonb_build_array(jsonb_build_object('schoolId', :'school_id', 'selfPurchaseEnabled', true)),
  'the catalogue reports self-purchase enabled for a school with no settings row');

-- 2. A student with no guardian at all buys Plus, then Max, on their own.
select is((select count(*) from public.guardian_links gl
  join public.students s on s.id = gl.student_id
  where s.user_id = :'second_student_user'), 0::bigint,
  'the buying student has no guardian link of any kind');
select is(private.study_plan(:'second_student_user'), 'free', 'the student starts on Free');
select is(private.billing_submit_verification((select body from sdp_body where name='plus'))->>'outcome',
  'ok', 'a student with no guardian link buys Studafy Plus');
select is(private.study_plan(:'second_student_user'), 'plus',
  'the verified purchase grants the plus plan');
select ok((select purchaser_id = :'second_student_user'::uuid
    and beneficiary_id = :'second_student_user'::uuid
    and guardian_link_id is null and purchase_approval_id is null
    and parental_gate_confirmed_at is null
  from public.store_transactions where transaction_id = 'sdp-plus-txn-1'),
  'the student pays for and holds the plan; no approval is recorded');
select is(private.billing_submit_verification((select body from sdp_body where name='plus')
    || '{"transactionId":"sdp-plus-txn-2"}'::jsonb)->>'outcome', 'ok',
  'a renewal of the student''s own lineage verifies');
select is(private.billing_submit_verification((select body from sdp_body where name='max'))->>'outcome',
  'ok', 'the same student buys Studafy Max on the App Store');
select is(private.study_plan(:'second_student_user'), 'max',
  'the verified purchase grants the max plan');
select is((select count(*) from public.billing_purchase_approvals
  where student_user_id = :'second_student_user'), 0::bigint,
  'no approval row is created by a purchase');

-- A student with verified guardians buys the same way: nobody is asked.
select set_config('request.jwt.claim.sub', :'student_user', true);
select is(private.billing_submit_verification((select body from sdp_body where name='plus')
    || '{"originalTransactionId":"sdp-linked-lineage","transactionId":"sdp-linked-txn-1","platform":"app_store"}'::jsonb)->>'outcome',
  'ok', 'a student with linked parents buys without their approval');
select is((select count(*) from public.notification_outbox o
  where o.template_key like 'billing.purchase_approval%'), 0::bigint,
  'no approval notification is sent to anyone');

-- 3. A school that opts out is still respected for new purchases.
insert into public.school_billing_settings(school_id, self_purchase_enabled)
  values (:'school_id', false);
select set_config('request.jwt.claim.sub', :'second_student_user', true);
select is(private.billing_submit_verification((select body from sdp_body where name='plus')
    || '{"originalTransactionId":"sdp-optout-lineage","transactionId":"sdp-optout-txn-1"}'::jsonb)->>'outcome',
  'student_purchase_disabled', 'a school that opted out refuses a new student purchase');
select is(private.billing_submit_verification((select body from sdp_body where name='plus')
    || '{"transactionId":"sdp-plus-txn-3"}'::jsonb)->>'outcome', 'ok',
  'a subscription already bought keeps renewing after an opt-out');
delete from public.school_billing_settings where school_id = :'school_id';

-- 4. Family+ still needs a verified guardian link.
select set_config('request.jwt.claim.sub', :'second_student_user', true);
select is(private.billing_submit_verification((select body from sdp_body where name='family'))->>'outcome',
  'not_eligible', 'a student cannot buy Family+');
select set_config('request.jwt.claim.sub', :'unverified_guardian', true);
select is(private.billing_submit_verification((select body from sdp_body where name='family'))->>'outcome',
  'not_eligible', 'a guardian with only a pending link cannot buy Family+');
select set_config('request.jwt.claim.sub', :'expired_guardian_user', true);
select is(private.billing_submit_verification((select body from sdp_body where name='family'))->>'outcome',
  'not_eligible', 'a guardian whose only link expired cannot buy Family+');
select set_config('request.jwt.claim.sub', :'guardian_user', true);
select is(private.billing_submit_verification((select body from sdp_body where name='family'))->>'outcome',
  'ok', 'a verified guardian buys Family+');
select is(private.family_plus_seats(:'guardian_user'), 4,
  'the guardian''s Family+ covers four children');

-- 5. The retired approval functions do nothing. An API from the previous
-- release still calling them during a deploy gets outcomes it maps.
select set_config('request.jwt.claim.sub', :'student_user', true);
select is(private.billing_request_purchase_approval('studafy_plus')->>'outcome', 'not_eligible',
  'a request for approval is refused');
select set_config('request.jwt.claim.sub', :'guardian_user', true);
select is(private.billing_list_purchase_approvals(), '[]'::jsonb,
  'no approvals are listed to a guardian');
select is(private.billing_decide_purchase_approval(gen_random_uuid(), true)->>'outcome', 'not_found',
  'a decision is refused');

-- 6. A student in no class (ADR-0045) buys too: no student record, no
-- school, only a student account (202610210050).
\set loner 'f00d0000-0000-4000-8000-0000000000a9'
insert into auth.users (id, email, aud, role, email_confirmed_at, created_at,
  updated_at, instance_id, raw_app_meta_data, raw_user_meta_data)
values (:'loner', 'sdp.loner@synthetic.studafy.test', 'authenticated',
  'authenticated', now(), now(), now(),
  '00000000-0000-0000-0000-000000000000', '{}', '{"full_name":"Lone Buyer"}');
select is(private.billing_resolve_beneficiary(:'loner', 'studafy_plus', null, false)->>'outcome',
  'not_eligible', 'an account not yet known as a student cannot buy a student plan');
update public.profiles set account_kind = 'student' where id = :'loner';
select is(private.billing_resolve_beneficiary(:'loner', 'studafy_max', null, false)->>'beneficiaryId',
  :'loner', 'a student account in no class buys Studafy Max for itself');
select is(private.billing_resolve_beneficiary(:'teacher_user', 'studafy_plus', null, false)->>'outcome',
  'not_eligible', 'a teacher still cannot buy a student plan');

select * from finish();
rollback;
