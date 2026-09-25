-- AUTH-031 API/RLS parity assertions. The companion seed loads the exact
-- DB-021 multi-role fixture before this transaction starts.

begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(20);

select id as draft_grade_result_id
from public.grade_results
where assessment_id = 'abd10000-0000-4000-8000-00000000000a'
  and student_id = 'abcf0000-0000-4000-8000-000000000008'
\gset

select ok(
  has_function_privilege(
    'studafy_api_runtime',
    'private.authz_authorize(text, uuid)',
    'execute'
  ),
  'API runtime can execute only the bounded authorization decision function'
);
select ok(
  not has_function_privilege(
    'authenticated',
    'private.authz_authorize(text, uuid)',
    'execute'
  ) and not has_function_privilege(
    'anon',
    'private.authz_authorize(text, uuid)',
    'execute'
  ) and not has_function_privilege(
    'service_role',
    'private.authz_authorize(text, uuid)',
    'execute'
  ),
  'clients and service role cannot call the API authorization oracle'
);
select is(
  (select count(*) from information_schema.role_table_grants
   where grantee = 'studafy_api_runtime'),
  0::bigint,
  'AUTH-031 adds no API table grant'
);

-- Assigned teacher: the API decision and direct DB-021 RLS both allow.
set local role studafy_api_runtime;
select set_config(
  'request.jwt.claim.sub', 'aaaa0000-0000-4000-8000-000000000001', true
);
select (private.authz_authorize(
  'classroom.read', 'abcd0000-0000-4000-8000-000000000007'
)->>'allowed')::boolean as api_allowed \gset
reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub', 'aaaa0000-0000-4000-8000-000000000001', true
);
select exists(
  select 1 from public.classrooms
  where id = 'abcd0000-0000-4000-8000-000000000007'
) as rls_allowed \gset
reset role;
select is(:'api_allowed'::boolean, :'rls_allowed'::boolean,
  'assigned teacher classroom API decision matches RLS');
select ok(:'api_allowed'::boolean,
  'assigned teacher is allowed for the exact classroom');

-- A same-school teacher without classroom_staff is not elevated by role.
set local role studafy_api_runtime;
select set_config(
  'request.jwt.claim.sub', 'ffff0000-0000-4000-8000-000000000005', true
);
select (private.authz_authorize(
  'grade_result.read', :'draft_grade_result_id'
)->>'allowed')::boolean as api_allowed \gset
reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub', 'ffff0000-0000-4000-8000-000000000005', true
);
select exists(
  select 1 from public.grade_results
  where id = :'draft_grade_result_id'
) as rls_allowed \gset
reset role;
select is(:'api_allowed'::boolean, :'rls_allowed'::boolean,
  'unassigned teacher grade API denial matches RLS');
select ok(not :'api_allowed'::boolean,
  'same-school teacher role alone grants no student grade access');

-- Cross-school identifier substitution is denied at both layers.
set local role studafy_api_runtime;
select set_config(
  'request.jwt.claim.sub', 'eeee0000-0000-4000-8000-000000000005', true
);
select (private.authz_authorize(
  'classroom.read', 'abcd0000-0000-4000-8000-000000000007'
)->>'allowed')::boolean as api_allowed \gset
reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub', 'eeee0000-0000-4000-8000-000000000005', true
);
select exists(
  select 1 from public.classrooms
  where id = 'abcd0000-0000-4000-8000-000000000007'
) as rls_allowed \gset
reset role;
select is(:'api_allowed'::boolean, :'rls_allowed'::boolean,
  'cross-school classroom API denial matches RLS');
select ok(not :'api_allowed'::boolean,
  'cross-school resource id does not establish tenant context');

-- Learner state gating agrees for published and draft assessments.
set local role studafy_api_runtime;
select set_config(
  'request.jwt.claim.sub', 'bbbb0000-0000-4000-8000-000000000002', true
);
select (private.authz_authorize(
  'assessment.read', 'abd00000-0000-4000-8000-000000000009'
)->>'allowed')::boolean as published_api \gset
select (private.authz_authorize(
  'assessment.read', 'abd10000-0000-4000-8000-00000000000a'
)->>'allowed')::boolean as draft_api \gset
reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub', 'bbbb0000-0000-4000-8000-000000000002', true
);
select exists(select 1 from public.assessments
  where id = 'abd00000-0000-4000-8000-000000000009') as published_rls \gset
select exists(select 1 from public.assessments
  where id = 'abd10000-0000-4000-8000-00000000000a') as draft_rls \gset
reset role;
select is(:'published_api'::boolean, :'published_rls'::boolean,
  'student published-assessment API decision matches RLS');
select is(:'draft_api'::boolean, :'draft_rls'::boolean,
  'student draft-assessment API decision matches RLS');
select ok(:'published_api'::boolean and not :'draft_api'::boolean,
  'student publication state is enforced');

-- Verified and expired guardian relationships agree with DB-021.
set local role studafy_api_runtime;
select set_config(
  'request.jwt.claim.sub', 'cccc0000-0000-4000-8000-000000000003', true
);
select (private.authz_authorize(
  'student.read', 'abcf0000-0000-4000-8000-000000000008'
)->>'allowed')::boolean as guardian_api \gset
select set_config(
  'request.jwt.claim.sub', 'ffff0000-0000-4000-8000-000000000004', true
);
select (private.authz_authorize(
  'student.read', 'abcf0000-0000-4000-8000-000000000008'
)->>'allowed')::boolean as expired_api \gset
reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub', 'cccc0000-0000-4000-8000-000000000003', true
);
select exists(select 1 from public.students
  where id = 'abcf0000-0000-4000-8000-000000000008') as guardian_rls \gset
select set_config(
  'request.jwt.claim.sub', 'ffff0000-0000-4000-8000-000000000004', true
);
select exists(select 1 from public.students
  where id = 'abcf0000-0000-4000-8000-000000000008') as expired_rls \gset
reset role;
select is(:'guardian_api'::boolean, :'guardian_rls'::boolean,
  'verified guardian API decision matches RLS');
select is(:'expired_api'::boolean, :'expired_rls'::boolean,
  'expired guardian API denial matches RLS');
select ok(:'guardian_api'::boolean and not :'expired_api'::boolean,
  'guardian verification expiry is enforced');

-- Publication safety is a relationship/state decision, not tenant membership.
--
-- The student needs a live Student Notebook entitlement to reach published
-- content at all: 202609220001 put private.notebook_reader_allowed in front
-- of can_view_resource_publication, and notebook_subscription.sql asserts the
-- unpaid denial on this same fixture. Granting it here keeps this assertion
-- about what AUTH-031 owns - that a clean publication is visible and an
-- unsafe one is not - rather than about whether the student has paid.
update private.notebook_runtime set environment = 'synthetic';
insert into public.store_transactions(
  platform, environment, purchaser_id, product_id, original_transaction_id,
  transaction_id, signed_data_hash, state, purchased_at, effective_until,
  beneficiary_id)
select 'play_store', 'synthetic',
  'bbbb0000-0000-4000-8000-000000000002'::uuid, sp.id,
  'auth031-notebook-lineage', 'auth031-notebook-txn', repeat('d', 64),
  'active', now() - interval '1 day', now() + interval '30 days',
  'bbbb0000-0000-4000-8000-000000000002'::uuid
from public.store_products sp
where sp.feature_key = 'student_notebook' order by sp.id limit 1;
insert into public.entitlements(
  user_id, feature_key, source, source_transaction_id, status, starts_at,
  ends_at)
select 'bbbb0000-0000-4000-8000-000000000002'::uuid, 'student_notebook',
  'play_store', st.id, 'active', now() - interval '1 day',
  now() + interval '30 days'
from public.store_transactions st
where st.transaction_id = 'auth031-notebook-txn';

set local role studafy_api_runtime;
select set_config(
  'request.jwt.claim.sub', 'bbbb0000-0000-4000-8000-000000000002', true
);
select (private.authz_authorize(
  'resource.read', 'abd60000-0000-4000-8000-00000000010f'
)->>'allowed')::boolean as clean_api \gset
select (private.authz_authorize(
  'resource.read', 'abd60000-0000-4000-8000-000000000110'
)->>'allowed')::boolean as dirty_api \gset
reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub', 'bbbb0000-0000-4000-8000-000000000002', true
);
select exists(select 1 from public.resources
  where id = 'abd60000-0000-4000-8000-00000000010f') as clean_rls \gset
select exists(select 1 from public.resources
  where id = 'abd60000-0000-4000-8000-000000000110') as dirty_rls \gset
reset role;
select is(:'clean_api'::boolean, :'clean_rls'::boolean,
  'clean publication API decision matches RLS');
select is(:'dirty_api'::boolean, :'dirty_rls'::boolean,
  'quarantined publication API denial matches RLS');
select ok(:'clean_api'::boolean and not :'dirty_api'::boolean,
  'unsafe publication does not become visible through API authorization');

set local role studafy_api_runtime;
select set_config(
  'request.jwt.claim.sub', 'aaaa0000-0000-4000-8000-000000000001', true
);
select private.authz_authorize(
  'attacker.become_admin', 'abcd0000-0000-4000-8000-000000000007'
) as unknown_decision \gset
reset role;
select is((:'unknown_decision'::jsonb)->>'reason', 'unknown_action',
  'unknown actions fail closed');
select ok(not ((:'unknown_decision'::jsonb)->>'allowed')::boolean,
  'unknown actions never grant authority');

select * from finish();
rollback;
