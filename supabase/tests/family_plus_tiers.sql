-- Family+ as a family plan: up to 4 children, or up to 8.
--
-- The plan is held by the parent who pays, and which children it covers is
-- worked out on every read from the parent's own verified links. These
-- tests pin the seat count, which children hold the seats, that a seat
-- frees the moment a link goes, and that nothing about the plan widens what
-- a parent can see. Seeds its own fixtures and rolls back.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(26);

\set school   '7b000000-0000-4000-8000-000000000001'
\set term     '7b000000-0000-4000-8000-000000000002'
\set class    '7b000000-0000-4000-8000-000000000003'
\set teacher  '7b000000-0000-4000-8000-0000000000a1'
\set parent   '7b000000-0000-4000-8000-0000000000a2'
\set loner    '7b000000-0000-4000-8000-0000000000a3'
\set other    '7b000000-0000-4000-8000-0000000000a4'
\set txn4     '7b000000-0000-4000-8000-0000000000c1'
\set txn8     '7b000000-0000-4000-8000-0000000000c2'
\set sandbox  '7b000000-0000-4000-8000-0000000000c3'
\set exam     '7b000000-0000-4000-8000-0000000000d1'
\set quiz     '7b000000-0000-4000-8000-0000000000d2'
\set session1 '7b000000-0000-4000-8000-0000000000e1'
\set session2 '7b000000-0000-4000-8000-0000000000e2'

-- ---------------------------------------------------------------------------
-- The helpers are internal: only the gate is callable, and only by the API.
-- ---------------------------------------------------------------------------
select ok(
  not has_function_privilege('studafy_api_runtime',
    'private.family_plus_seats(uuid)', 'execute')
  and not has_function_privilege('authenticated',
    'private.family_plus_seats(uuid)', 'execute'),
  'nobody but the gate may count a parent''s seats');
select ok(
  not has_function_privilege('studafy_api_runtime',
    'private.family_plus_covered(uuid)', 'execute')
  and not has_function_privilege('authenticated',
    'private.family_plus_covered(uuid)', 'execute'),
  'nobody but the gate may list which children are covered');

-- ---------------------------------------------------------------------------
-- Catalogue: the two family products are on sale, the per-child one is not.
-- ---------------------------------------------------------------------------
select is(
  (select count(*)::int from public.store_products
    where feature_key in ('family_plus', 'family_plus_large') and active),
  16, 'both family plans exist on both stores in every environment');
select is(
  (select array_agg(distinct environment order by environment)
    from public.store_products
    where feature_key in ('family_plus', 'family_plus_large')
      and storefront_listed),
  -- On sale everywhere from launch (ADR-0034, 202610020002).
  array['development', 'production', 'staging', 'synthetic'],
  'and are on sale in every environment from launch');
select ok(
  not exists (select 1 from public.store_products
    where feature_key = 'parent_insights' and storefront_listed
      and environment <> 'synthetic'),
  'the per-child Family+ is no longer sold in any real store');
select ok(
  exists (select 1 from public.store_products
    where feature_key = 'parent_insights' and active),
  'but stays active, so a subscription bought before still renews');

-- ---------------------------------------------------------------------------
-- Fixtures: one parent with five children, one parent with none.
-- ---------------------------------------------------------------------------
insert into auth.users (id, email, aud, role) values
  (:'teacher', 'tt@synthetic.studafy.test', 'authenticated', 'authenticated'),
  (:'parent',  'tp@synthetic.studafy.test', 'authenticated', 'authenticated'),
  (:'loner',   'tl@synthetic.studafy.test', 'authenticated', 'authenticated'),
  (:'other',   'to@synthetic.studafy.test', 'authenticated', 'authenticated')
on conflict (id) do nothing;
insert into public.profiles (id, display_name, status) values
  (:'teacher', 'Teacher', 'active'), (:'parent', 'Parent', 'active'),
  (:'loner', 'Loner', 'active'), (:'other', 'Other', 'active')
on conflict (id) do update set status = 'active';
insert into public.schools (id, name, timezone, locale, status)
  values (:'school', 'Tier Test School', 'Asia/Amman', 'en', 'active');
insert into public.memberships (school_id, user_id, role, active, status) values
  (:'school', :'teacher', 'teacher', true, 'active'),
  (:'school', :'parent', 'parent', true, 'active'),
  (:'school', :'loner', 'parent', true, 'active'),
  (:'school', :'other', 'parent', true, 'active');
insert into public.terms (id, school_id, name, starts_on, ends_on, active, status)
  values (:'term', :'school', 'T', current_date - 60, current_date + 300, true, 'active');
insert into public.classrooms (id, school_id, term_id, name, grade, section, room, teacher_id, status)
  values (:'class', :'school', :'term', 'Maths 9A', '9', 'A', 'R', :'teacher', 'active');

-- Five children, linked one day apart: child 1 first, child 5 last.
insert into public.students (id, school_id, studafy_id, display_name, created_by)
select ('7b000000-0000-4000-8000-0000000000b' || n)::uuid, :'school',
  'SJ-TIER0' || n, 'Child ' || n, :'teacher'
from generate_series(1, 5) as n;
insert into public.enrollments (school_id, classroom_id, student_id, active, status, starts_on)
select :'school', :'class', ('7b000000-0000-4000-8000-0000000000b' || n)::uuid,
  true, 'active', current_date - 50
from generate_series(1, 5) as n;
insert into public.guardian_links (
  school_id, student_id, guardian_id, status, relationship, verified_by, verified_at)
select :'school', ('7b000000-0000-4000-8000-0000000000b' || n)::uuid, :'parent',
  'verified', 'parent', :'teacher', now() - make_interval(days => 10 - n)
from generate_series(1, 5) as n;
-- Another parent linked to child 1 only, with no plan.
insert into public.guardian_links (
  school_id, student_id, guardian_id, status, relationship, verified_by, verified_at)
values (:'school', '7b000000-0000-4000-8000-0000000000b1', :'other',
  'verified', 'parent', :'teacher', now());

create or replace function pg_temp.as_user(p_actor uuid)
returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', p_actor::text, true);
  perform set_config('studafy.school_id', '', true);
end;
$$;
create or replace function pg_temp.covered(p_actor uuid, p_child int)
returns boolean language plpgsql as $$
begin
  perform pg_temp.as_user(p_actor);
  return private.parent_insights_has_access(
    ('7b000000-0000-4000-8000-0000000000b' || p_child)::uuid);
end;
$$;
create or replace function pg_temp.plan(p_feature text, p_txn uuid, p_environment text)
returns void language plpgsql as $$
begin
  insert into public.store_transactions (
    id, platform, environment, transaction_id, original_transaction_id,
    product_id, beneficiary_id, purchaser_id, state, signed_data_hash, purchased_at)
  values (p_txn, 'app_store', p_environment, 'tier-' || p_txn, 'tier-' || p_txn,
    (select p.id from public.store_products p
      where p.feature_key = p_feature and p.platform = 'app_store'
        and p.environment = p_environment),
    '7b000000-0000-4000-8000-0000000000a2', '7b000000-0000-4000-8000-0000000000a2',
    'active', repeat('e', 64), now());
  insert into public.entitlements (
    user_id, school_id, feature_key, source, source_transaction_id,
    status, starts_at, ends_at)
  values ('7b000000-0000-4000-8000-0000000000a2', null, p_feature, 'app_store', p_txn,
    'active', now() - interval '1 day', now() + interval '30 days');
end;
$$;

-- ---------------------------------------------------------------------------
-- Buying: the parent is the beneficiary, and must be somebody's parent.
-- ---------------------------------------------------------------------------
select is(
  private.billing_resolve_beneficiary(:'parent', 'family_plus', null, false)->>'beneficiaryId',
  :'parent', 'a family plan is held by the parent who pays');
select is(
  private.billing_resolve_beneficiary(:'parent', 'family_plus_large',
    '7b000000-0000-4000-8000-0000000000b1', false)->>'outcome',
  'invalid_beneficiary', 'a family plan is never bought for one named child');
select is(
  private.billing_resolve_beneficiary(:'loner', 'family_plus', null, false)->>'outcome',
  'not_eligible', 'a parent with no linked child cannot buy it');

-- ---------------------------------------------------------------------------
-- Without a plan nothing is covered.
-- ---------------------------------------------------------------------------
select ok(not pg_temp.covered(:'parent', 1), 'no plan, no insights');

-- A sandbox receipt never unlocks another environment.
select pg_temp.plan('family_plus', :'sandbox',
  case (select environment from private.notebook_runtime)
    when 'synthetic' then 'development' else 'synthetic' end);
select ok(not pg_temp.covered(:'parent', 1),
  'a plan bought in another store environment covers nobody');
-- The ledger is append-only; the sandbox plan is simply ended.
update public.entitlements set status = 'expired'
  where source_transaction_id = :'sandbox';

-- ---------------------------------------------------------------------------
-- Up to 4: the first four children linked are covered, the fifth is not.
-- ---------------------------------------------------------------------------
select pg_temp.plan('family_plus', :'txn4',
  (select environment from private.notebook_runtime));
select ok(pg_temp.covered(:'parent', 1), 'the first child is covered');
select ok(pg_temp.covered(:'parent', 4), 'the fourth child is covered');
select ok(not pg_temp.covered(:'parent', 5), 'the fifth child is not');
select ok(not pg_temp.covered(:'other', 1),
  'the plan is the paying parent''s: another guardian of a covered child gets nothing');

select pg_temp.as_user(:'parent');
select is(
  (select jsonb_array_length(row_json->'coveredStudentIds')
    from jsonb_array_elements(private.billing_list_entitlements(
      (select environment from private.notebook_runtime))) as rows(row_json)
    where row_json->>'featureKey' = 'family_plus'),
  4, 'the app is told which four children the plan covers');

-- A seat frees the moment a link goes: the fifth child moves up.
update public.guardian_links set status = 'revoked'
  where guardian_id = :'parent'
    and student_id = '7b000000-0000-4000-8000-0000000000b2';
select ok(not pg_temp.covered(:'parent', 2), 'an unlinked child loses access at once');
select ok(pg_temp.covered(:'parent', 5), 'and the next child takes the seat');
update public.guardian_links set status = 'verified', verified_by = :'teacher',
  verified_at = now() - interval '8 days'
  where guardian_id = :'parent'
    and student_id = '7b000000-0000-4000-8000-0000000000b2';

-- A deleted student never holds a seat.
update public.students set deleted_at = now()
  where id = '7b000000-0000-4000-8000-0000000000b1';
select ok(pg_temp.covered(:'parent', 5), 'a deleted child''s seat goes to the next');
update public.students set deleted_at = null
  where id = '7b000000-0000-4000-8000-0000000000b1';

-- ---------------------------------------------------------------------------
-- Up to 8: every child is covered.
-- ---------------------------------------------------------------------------
select pg_temp.plan('family_plus_large', :'txn8',
  (select environment from private.notebook_runtime));
select ok(pg_temp.covered(:'parent', 5), 'the larger plan covers the fifth child');

-- Ending the plan ends access on the next read.
update public.entitlements set status = 'expired' where user_id = :'parent';
select ok(not pg_temp.covered(:'parent', 1), 'an ended plan covers nobody');
update public.entitlements set status = 'active'
  where user_id = :'parent' and feature_key = 'family_plus_large';

-- ---------------------------------------------------------------------------
-- The richer insights: grouped by class, a missed paper exam shown as missed,
-- attendance as counts, and still only what a parent may see.
-- ---------------------------------------------------------------------------
insert into public.assessments (id, school_id, classroom_id, title, category,
  maximum_score, created_by, state, delivery, published_at)
values
  (:'exam', :'school', :'class', 'Paper exam 1', 'paper_exam', 50, :'teacher',
   'published', 'paper', now() - interval '3 days'),
  (:'quiz', :'school', :'class', 'Quiz 1', 'quiz', 10, :'teacher',
   'published', 'paper', now() - interval '3 days');
insert into public.grade_results (school_id, assessment_id, student_id, score,
  mark, state, reviewed_by, reviewed_at, published_by, published_at)
values
  (:'school', :'exam', '7b000000-0000-4000-8000-0000000000b5', null, 'absent',
   'published', :'teacher', now(), :'teacher', now() - interval '2 days'),
  (:'school', :'quiz', '7b000000-0000-4000-8000-0000000000b5', 7, null,
   'draft', null, null, null, null);
insert into public.lesson_sessions (id, school_id, classroom_id, starts_at, ends_at)
values
  (:'session1', :'school', :'class', now() - interval '7 days',
   now() - interval '7 days' + interval '45 minutes'),
  (:'session2', :'school', :'class', now() - interval '14 days',
   now() - interval '14 days' + interval '45 minutes');
insert into public.attendance_records (school_id, session_id, student_id, state, recorded_by)
values
  (:'school', :'session1', '7b000000-0000-4000-8000-0000000000b5', 'absent', :'teacher'),
  (:'school', :'session2', '7b000000-0000-4000-8000-0000000000b5', 'absent', :'teacher');

create or replace function pg_temp.insights()
returns jsonb language plpgsql as $$
begin
  perform pg_temp.as_user('7b000000-0000-4000-8000-0000000000a2');
  return private.api042_query('getFamilyInsights', null,
    jsonb_build_object('studentId', '7b000000-0000-4000-8000-0000000000b5'));
end;
$$;

select is(pg_temp.insights()->'grades'->0->>'mark', 'absent',
  'a missed paper exam reaches the parent as missed');
select is(jsonb_array_length(pg_temp.insights()->'grades'), 1,
  'a draft mark never does');
select is(pg_temp.insights()->'grades'->0->>'className', 'Maths 9A',
  'marks are grouped by class');
select is(
  (select sum((c->>'count')::int)::int
    from jsonb_array_elements(pg_temp.insights()->'attendanceCounts') c
    where c->>'state' = 'absent'),
  2, 'attendance arrives as counts, not a row per lesson');
select is(pg_temp.insights()->'classes'->0->>'className', 'Maths 9A',
  'the child''s classes are listed even before anything is marked');

select * from finish();
rollback;
