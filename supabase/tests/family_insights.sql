-- Family+ : the entitlement gate and what it will not disclose.
--
-- This endpoint returns one child's record to somebody who paid for it, so
-- the tests that matter are the refusals. Seeds its own fixtures and rolls
-- back, so it needs no separate _seed.sql wrapper.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(15);

select ok(
  has_function_privilege('studafy_api_runtime',
    'private.parent_insights_has_access(uuid)', 'execute'),
  'the api runtime role may evaluate the entitlement gate');
select ok(
  not has_function_privilege('authenticated',
    'private.parent_insights_has_access(uuid)', 'execute'),
  'a signed-in client may not evaluate it directly');
-- The ungated previous generation must be unreachable, or the paywall could
-- be walked around by calling the older function name.
select ok(
  not has_function_privilege('studafy_api_runtime',
    'private.api042_query_pre_family_insights(text,uuid,jsonb)', 'execute'),
  'the pre-Family+ query surface is no longer callable by the runtime role');

\set school   '7a000000-0000-4000-8000-000000000001'
\set term     '7a000000-0000-4000-8000-000000000002'
\set class    '7a000000-0000-4000-8000-000000000003'
\set teacher  '7a000000-0000-4000-8000-0000000000a1'
\set parent   '7a000000-0000-4000-8000-0000000000a2'
\set stranger '7a000000-0000-4000-8000-0000000000a3'
\set kid      '7a000000-0000-4000-8000-0000000000a4'
\set student  '7a000000-0000-4000-8000-0000000000b1'
\set txn      '7a000000-0000-4000-8000-0000000000c1'

insert into auth.users (id, email, aud, role) values
  (:'teacher',  'ft@synthetic.studafy.test', 'authenticated', 'authenticated'),
  (:'parent',   'fp@synthetic.studafy.test', 'authenticated', 'authenticated'),
  (:'stranger', 'fs@synthetic.studafy.test', 'authenticated', 'authenticated'),
  (:'kid',      'fk@synthetic.studafy.test', 'authenticated', 'authenticated')
on conflict (id) do nothing;
insert into public.profiles (id, display_name, status) values
  (:'teacher', 'Teacher', 'active'), (:'parent', 'Parent', 'active'),
  (:'stranger', 'Stranger', 'active'), (:'kid', 'Kid', 'active')
on conflict (id) do update set status = 'active';

insert into public.schools (id, name, timezone, locale, status)
  values (:'school', 'Family Test School', 'Asia/Amman', 'en', 'active');
insert into public.memberships (school_id, user_id, role, active, status) values
  (:'school', :'teacher', 'teacher', true, 'active'),
  (:'school', :'parent', 'parent', true, 'active'),
  (:'school', :'stranger', 'parent', true, 'active'),
  (:'school', :'kid', 'student', true, 'active');
insert into public.terms (id, school_id, name, starts_on, ends_on, active, status)
  values (:'term', :'school', 'T', current_date - 30, current_date + 300, true, 'active');
insert into public.classrooms (id, school_id, term_id, name, grade, section, room, teacher_id, status)
  values (:'class', :'school', :'term', 'C', '9', 'A', 'R', :'teacher', 'active');
insert into public.students (id, school_id, user_id, studafy_id, display_name, created_by)
  values (:'student', :'school', :'kid', 'SJ-FAMILY01', 'Kid Student', :'teacher');
insert into public.enrollments (school_id, classroom_id, student_id, active, status, starts_on)
  values (:'school', :'class', :'student', true, 'active', current_date - 20);
-- A verified link must record who verified it and when (db020 check).
insert into public.guardian_links (
  school_id, student_id, guardian_id, status, relationship,
  verified_by, verified_at)
  values (:'school', :'student', :'parent', 'verified', 'parent',
          :'kid', now());

-- A pastoral note the school restricted to safeguarding staff. It must never
-- reach a parent through this endpoint, paid or not.
insert into public.wellbeing_events (
  school_id, student_id, classroom_id, kind, title, visibility, created_by)
values
  (:'school', :'student', :'class', 'note', 'Shared with home',
   'guardian_shared', :'teacher'),
  (:'school', :'student', :'class', 'note', 'RESTRICTED SAFEGUARDING',
   'safeguarding_restricted', :'teacher');

create or replace function pg_temp.insights(p_actor uuid)
returns jsonb language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', p_actor::text, true);
  perform set_config('studafy.school_id', '', true);
  return private.api042_query('getFamilyInsights', null,
    jsonb_build_object('studentId', '7a000000-0000-4000-8000-0000000000b1'));
end;
$$;

-- No entitlement yet.
select is(pg_temp.insights(:'parent')->>'outcome', 'forbidden',
  'a verified guardian without a subscription is refused');

insert into public.store_transactions (
  id, platform, environment, transaction_id, original_transaction_id,
  product_id, beneficiary_id, purchaser_id, state,
  signed_data_hash, purchased_at)
values (:'txn', 'app_store',
  (select environment from private.notebook_runtime),
  'family-txn-1', 'family-txn-1',
  (select p.id from public.store_products p
    where p.feature_key = 'parent_insights' and p.platform = 'app_store'
      and p.environment = (select environment from private.notebook_runtime)
    limit 1),
  :'kid', :'parent', 'active', repeat('d', 64), now());
insert into public.entitlements (
  user_id, school_id, feature_key, source, source_transaction_id,
  status, starts_at, ends_at)
values (:'kid', :'school', 'parent_insights', 'app_store', :'txn',
  'active', now() - interval '1 day', now() + interval '30 days');

select is(pg_temp.insights(:'parent')->>'outcome', 'ok',
  'the same guardian with a live subscription is served');
select is(pg_temp.insights(:'parent')->>'studentName', 'Kid Student',
  'and the response is about their own child');

-- Everyone else, including another parent at the same school.
select is(pg_temp.insights(:'stranger')->>'outcome', 'forbidden',
  'a parent at the school with no link to this child is refused');
select is(pg_temp.insights(:'teacher')->>'outcome', 'forbidden',
  'a teacher is refused - this endpoint is the guardian surface only');

-- The refusal must look identical whether the child exists or not, so an
-- unpaid caller cannot use it to test student ids.
select is(
  (select private.api042_query('getFamilyInsights', null,
    jsonb_build_object('studentId', '7a000000-0000-4000-8000-00000000ffff'))
   ->>'outcome'),
  'forbidden', 'an unknown student id is refused the same way');

select is(
  jsonb_array_length(pg_temp.insights(:'parent')->'wellbeing'), 1,
  'only the note the school shared with guardians is returned');
select is(
  pg_temp.insights(:'parent')->'wellbeing'->0->>'title', 'Shared with home',
  'and it is the shared one');
select ok(
  pg_temp.insights(:'parent')::text not like '%RESTRICTED SAFEGUARDING%',
  'a safeguarding-restricted note never appears, at any subscription level');

-- Revocation bites immediately: a refund or a removed link ends access on the
-- next read, not at the end of a cached period.
update public.entitlements set status = 'revoked' where user_id = :'kid';
select is(pg_temp.insights(:'parent')->>'outcome', 'forbidden',
  'a revoked subscription ends access on the next read');
update public.entitlements set status = 'active' where user_id = :'kid';
update public.guardian_links set status = 'revoked' where guardian_id = :'parent';
select is(pg_temp.insights(:'parent')->>'outcome', 'forbidden',
  'a revoked guardian link ends access even with a live subscription');
update public.guardian_links set status = 'verified',
  verified_by = :'kid', verified_at = now() where guardian_id = :'parent';

-- An expired subscription is not a live one.
update public.entitlements set ends_at = now() - interval '1 second'
  where user_id = :'kid';
select is(pg_temp.insights(:'parent')->>'outcome', 'forbidden',
  'an expired subscription is refused');

select * from finish();
rollback;
