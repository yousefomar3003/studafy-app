-- Transactional fixtures: this test leaves existing local users/data intact.
begin;
\set auth031_fixture_only true
\ir rls_access_seed.sql
\ir db021_access_seed.sql
\unset auth031_fixture_only
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select plan(18);
update private.notebook_runtime set environment='synthetic';
delete from public.entitlements where user_id=:'student_user' and feature_key='student_notebook';
select set_config('studafy.school_id', :'school_id', true);
select set_config('request.jwt.claim.sub', :'student_user', true);
select is(private.notebook_has_access(), false, 'no local automatic trial');
select is(private.api041_query('listResources', :'school_id', '{}')->>'outcome','forbidden', 'unpaid API content read denied');
select is(private.can_view_resource(:'clean_resource_id'),false,'direct resource denied');
select is(private.can_view_resource_version('abd90000-0000-4000-8000-000000000116'),false,'direct version denied');
select is(private.can_view_resource_publication('abda0000-0000-4000-8000-000000000118'),false,'publication/attachment authorization denied');
select ok(private.api041_query('listAssignments', :'school_id', '{}') ? 'items','assignments remain free');
select set_config('request.jwt.claim.sub', :'teacher_user', true);
select ok(private.can_view_resource(:'clean_resource_id'),'teacher retains access');
select set_config('request.jwt.claim.sub', :'guardian_user', true);
select ok(private.can_view_resource(:'clean_resource_id'),'verified guardian retains existing content access');
select is(private.billing_submit_verification(jsonb_build_object(
  'platform','play_store','environment','synthetic','productFeatureKey','student_notebook',
  'storeProductId','studafy_student_notebook_monthly','originalTransactionId','notebook-access-lineage',
  'transactionId','notebook-access-trial','signedDataHash',repeat('c',64),'state','active',
  'purchasedAt',now()::text,'effectiveUntil',(now()+interval '1 month')::text,
  'beneficiaryStudentId',:'student_id')) ->> 'outcome', 'ok', 'verified store trial uses ordinary entitlement ledger');
select set_config('request.jwt.claim.sub', :'student_user', true);
select ok(private.notebook_has_access(),'verified unexpired trial unlocks');
select ok(private.api041_query('listResources', :'school_id', '{}') ? 'items','paid API reads available');
select ok(private.can_view_resource(:'clean_resource_id'),'paid direct content permission available');
update private.notebook_runtime set environment='production';
select is(private.notebook_has_access(),false,'sandbox cannot unlock production');
update private.notebook_runtime set environment='synthetic';
update public.entitlements set status='revoked' where user_id=:'student_user' and feature_key='student_notebook';
select is(private.notebook_has_access(),false,'refund/revocation locks immediately');
update public.entitlements set status='active', starts_at=now()-interval '2 months',ends_at=now()-interval '1 second'
  where user_id=:'student_user' and feature_key='student_notebook';
select is(private.notebook_has_access(),false,'expired active row cannot unlock');
update public.entitlements set status='grace_period',ends_at=now()+interval '1 day'
  where user_id=:'student_user' and feature_key='student_notebook';
select ok(private.notebook_has_access(),'verified unexpired billing grace retains access');
select set_config('request.jwt.claim.sub', :'second_student_user', true);
select is(private.notebook_has_access(),false,'another student cannot use this purchase');
select ok(not has_function_privilege('authenticated','private.api041_query_before_notebook(text,uuid,jsonb)','execute')
  and not has_function_privilege('studafy_api_runtime','private.api041_query_before_notebook(text,uuid,jsonb)','execute'),
  'old unguarded API function is not callable');
select * from finish();
rollback;
