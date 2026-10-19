-- Family+ given without a purchase (202610190010).
--
-- An operator with direct database access can give a parent Family+ - for
-- the app-store reviewer account, or as support credit - exactly as
-- study_plan_grants gives a student a plan. These tests pin that a live
-- grant gives the seats of its tier, that it reaches every place the plan
-- is read (coverage, the insights gate, the billing read and the guardian
-- links the app reads with billing off), that the larger of a grant and a
-- store plan wins, and that an expired or future grant counts for nothing.
-- Seeds its own fixtures and rolls back.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(40);

\set school   '7c000000-0000-4000-8000-000000000001'
\set term     '7c000000-0000-4000-8000-000000000002'
\set class    '7c000000-0000-4000-8000-000000000003'
\set teacher  '7c000000-0000-4000-8000-0000000000a1'
\set parent   '7c000000-0000-4000-8000-0000000000a2'
\set other    '7c000000-0000-4000-8000-0000000000a4'
\set txn8     '7c000000-0000-4000-8000-0000000000c2'
\set child1   '7c000000-0000-4000-8000-0000000000b1'
\set child5   '7c000000-0000-4000-8000-0000000000b5'

-- ---------------------------------------------------------------------------
-- Nobody but an operator writes or reads grants; only the gate reads plans.
-- ---------------------------------------------------------------------------
select ok(
  not has_table_privilege('studafy_api_runtime', 'private.family_plus_grants', 'select')
  and not has_table_privilege('studafy_api_runtime', 'private.family_plus_grants', 'insert')
  and not has_table_privilege('authenticated', 'private.family_plus_grants', 'select')
  and not has_table_privilege('studafy_worker_runtime', 'private.family_plus_grants', 'select'),
  'no runtime role may read or write Family+ grants');
select ok(
  not has_function_privilege('studafy_api_runtime',
    'private.family_plus_plan(uuid)', 'execute')
  and not has_function_privilege('authenticated',
    'private.family_plus_plan(uuid)', 'execute')
  and not has_function_privilege('studafy_api_runtime',
    'private.family_plus_seats(uuid)', 'execute'),
  'the plan and seat helpers are internal');
select ok(
  has_function_privilege('studafy_api_runtime',
    'private.parent_insights_has_access(uuid)', 'execute')
  and has_function_privilege('studafy_api_runtime',
    'private.billing_list_entitlements(text)', 'execute'),
  'the API keeps the gate and the billing read');

-- ---------------------------------------------------------------------------
-- Fixtures: one parent with five children, another parent of child 1.
-- ---------------------------------------------------------------------------
insert into auth.users (id, email, aud, role) values
  (:'teacher', 'gt@synthetic.studafy.test', 'authenticated', 'authenticated'),
  (:'parent',  'gp@synthetic.studafy.test', 'authenticated', 'authenticated'),
  (:'other',   'go@synthetic.studafy.test', 'authenticated', 'authenticated')
on conflict (id) do nothing;
insert into public.profiles (id, display_name, status) values
  (:'teacher', 'Teacher', 'active'), (:'parent', 'Parent', 'active'),
  (:'other', 'Other', 'active')
on conflict (id) do update set status = 'active';
insert into public.schools (id, name, timezone, locale, status)
  values (:'school', 'Grant Test School', 'Asia/Amman', 'en', 'active');
insert into public.memberships (school_id, user_id, role, active, status) values
  (:'school', :'teacher', 'teacher', true, 'active'),
  (:'school', :'parent', 'parent', true, 'active'),
  (:'school', :'other', 'parent', true, 'active');
insert into public.terms (id, school_id, name, starts_on, ends_on, active, status)
  values (:'term', :'school', 'T', current_date - 60, current_date + 300, true, 'active');
insert into public.classrooms (id, school_id, term_id, name, grade, section, room, teacher_id, status)
  values (:'class', :'school', :'term', 'Maths 9A', '9', 'A', 'R', :'teacher', 'active');
insert into public.students (id, school_id, studafy_id, display_name, created_by)
select ('7c000000-0000-4000-8000-0000000000b' || n)::uuid, :'school',
  'SJ-GRNT0' || n, 'Child ' || n, :'teacher'
from generate_series(1, 5) as n;
insert into public.enrollments (school_id, classroom_id, student_id, active, status, starts_on)
select :'school', :'class', ('7c000000-0000-4000-8000-0000000000b' || n)::uuid,
  true, 'active', current_date - 50
from generate_series(1, 5) as n;
-- Linked one day apart: child 1 first, child 5 last.
insert into public.guardian_links (
  school_id, student_id, guardian_id, status, relationship, verified_by, verified_at)
select :'school', ('7c000000-0000-4000-8000-0000000000b' || n)::uuid, :'parent',
  'verified', 'parent', :'teacher', now() - make_interval(days => 10 - n)
from generate_series(1, 5) as n;
insert into public.guardian_links (
  school_id, student_id, guardian_id, status, relationship, verified_by, verified_at)
values (:'school', :'child1', :'other', 'verified', 'parent', :'teacher', now());

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
    ('7c000000-0000-4000-8000-0000000000b' || p_child)::uuid);
end;
$$;
-- The parent's own links, as the app reads them with billing off.
create or replace function pg_temp.links()
returns jsonb language plpgsql as $$
begin
  perform pg_temp.as_user('7c000000-0000-4000-8000-0000000000a2');
  return private.api042_query('listMyGuardianLinks', null, '{}'::jsonb);
end;
$$;
create or replace function pg_temp.link_unlocked(p_child int)
returns boolean language sql as $$
  select (item->>'familyPlus')::boolean
  from jsonb_array_elements(pg_temp.links()->'items') item
  where item->>'studentId' = '7c000000-0000-4000-8000-0000000000b' || p_child;
$$;
-- The parent's live grant rows from the billing read.
create or replace function pg_temp.granted_rows()
returns setof jsonb language plpgsql as $$
begin
  perform pg_temp.as_user('7c000000-0000-4000-8000-0000000000a2');
  return query
    select row_json
    from jsonb_array_elements(private.billing_list_entitlements(
      (select environment from private.notebook_runtime))) as rows(row_json)
    where (row_json->>'granted')::boolean;
end;
$$;
create or replace function pg_temp.insights(p_child int)
returns text language plpgsql as $$
begin
  perform pg_temp.as_user('7c000000-0000-4000-8000-0000000000a2');
  return private.api042_query('getFamilyInsights', null,
    jsonb_build_object('studentId',
      '7c000000-0000-4000-8000-0000000000b' || p_child))->>'outcome';
end;
$$;

-- ---------------------------------------------------------------------------
-- A grant is checked like a study-plan grant.
-- ---------------------------------------------------------------------------
select throws_ok(
  format($$insert into private.family_plus_grants (user_id, tier, reason, ends_at)
    values (%L, 'family_plus_huge', 'pgTAP grant', now() + interval '1 day')$$, :'parent'),
  '23514', null, 'only the two Family+ tiers can be given');
select throws_ok(
  format($$insert into private.family_plus_grants (user_id, tier, reason, ends_at)
    values (%L, 'family_plus', 'x', now() + interval '1 day')$$, :'parent'),
  '23514', null, 'a grant says why it was given');
select throws_ok(
  format($$insert into private.family_plus_grants (user_id, tier, reason, starts_at, ends_at)
    values (%L, 'family_plus', 'pgTAP grant', now(), now() - interval '1 day')$$, :'parent'),
  '23514', null, 'a grant ends after it starts');

-- ---------------------------------------------------------------------------
-- No grant, no plan.
-- ---------------------------------------------------------------------------
select is(private.family_plus_seats(:'parent'), 0, 'no plan, no seats');
select ok(not pg_temp.covered(:'parent', 1), 'no plan, no insights');
select is(pg_temp.links()->'familyPlan', 'null'::jsonb,
  'the links say there is no family plan');
select is(pg_temp.link_unlocked(1), false, 'and that no child is unlocked');

-- ---------------------------------------------------------------------------
-- A 4-child grant: the first four linked children, as a bought plan would.
-- ---------------------------------------------------------------------------
insert into private.family_plus_grants (user_id, tier, reason, ends_at)
  values (:'parent', 'family_plus', 'pgTAP grant', now() + interval '1 year');
select is(private.family_plus_seats(:'parent'), 4, 'a 4-child grant gives 4 seats');
select ok(pg_temp.covered(:'parent', 1), 'the first child is covered');
select ok(pg_temp.covered(:'parent', 4), 'the fourth child is covered');
select ok(not pg_temp.covered(:'parent', 5), 'the fifth child is not');
select ok(not pg_temp.covered(:'other', 1),
  'the grant is the parent''s own: another guardian of a covered child gets nothing');
select is(pg_temp.insights(1), 'ok', 'the insights read serves a covered child');
select is(pg_temp.insights(5), 'forbidden', 'and refuses one the grant does not cover');

select is(pg_temp.link_unlocked(1), true, 'the links unlock a covered child');
select is(pg_temp.link_unlocked(5), false, 'and not the fifth');
select is(pg_temp.links()->'familyPlan'->>'featureKey', 'family_plus',
  'the links name the granted plan');
select is((pg_temp.links()->'familyPlan'->>'granted')::boolean, true,
  'as given, with no store subscription behind it');
select is(jsonb_array_length(pg_temp.links()->'familyPlan'->'coveredStudentIds'), 4,
  'covering four children');

select is((select count(*)::int from pg_temp.granted_rows()), 1,
  'the billing read lists the grant');
select is((select r->>'featureKey' from pg_temp.granted_rows() r), 'family_plus',
  'as the plan it gives');
select ok((select not (r ? 'platform') and not (r ? 'storeProductId')
    and r->>'status' = 'active' and r->'renewalStatus' = 'null'::jsonb
    and not (r->>'purchasedByMe')::boolean
  from pg_temp.granted_rows() r),
  'with no store, product or renewal to manage');
select is((select jsonb_array_length(r->'coveredStudentIds') from pg_temp.granted_rows() r),
  4, 'and the children it covers');

-- ---------------------------------------------------------------------------
-- An 8-child grant covers everyone; with a store plan the larger wins.
-- ---------------------------------------------------------------------------
update private.family_plus_grants set tier = 'family_plus_large'
  where user_id = :'parent';
select is(private.family_plus_seats(:'parent'), 8, 'an 8-child grant gives 8 seats');
select ok(pg_temp.covered(:'parent', 5), 'and covers the fifth child');
select is(pg_temp.link_unlocked(5), true, 'which the links say too');

-- A smaller store plan beside it does not shrink the grant.
insert into public.store_transactions (
  id, platform, environment, transaction_id, original_transaction_id,
  product_id, beneficiary_id, purchaser_id, state, signed_data_hash, purchased_at)
values (:'txn8', 'app_store', (select environment from private.notebook_runtime),
  'grant-' || :'txn8', 'grant-' || :'txn8',
  (select p.id from public.store_products p
    where p.feature_key = 'family_plus' and p.platform = 'app_store'
      and p.environment = (select environment from private.notebook_runtime)),
  :'parent', :'parent', 'active', repeat('e', 64), now());
insert into public.entitlements (
  user_id, school_id, feature_key, source, source_transaction_id,
  status, starts_at, ends_at)
values (:'parent', null, 'family_plus', 'app_store', :'txn8',
  'active', now() - interval '1 day', now() + interval '30 days');
select is(private.family_plus_seats(:'parent'), 8,
  'a 4-child purchase beside an 8-child grant leaves 8 seats');
select is(pg_temp.links()->'familyPlan'->>'featureKey', 'family_plus_large',
  'the larger plan is the one shown');

-- At the same size, the bought plan is shown, so it can be managed.
update private.family_plus_grants set tier = 'family_plus'
  where user_id = :'parent';
select is((pg_temp.links()->'familyPlan'->>'granted')::boolean, false,
  'at the same size the plan the parent pays for is shown');
update public.entitlements set status = 'expired'
  where source_transaction_id = :'txn8';
select is((pg_temp.links()->'familyPlan'->>'granted')::boolean, true,
  'and the grant once the purchase ends');

-- ---------------------------------------------------------------------------
-- Expiry: an ended or not-yet-started grant counts for nothing.
-- ---------------------------------------------------------------------------
update private.family_plus_grants
  set starts_at = now() - interval '2 days', ends_at = now() - interval '1 second'
  where user_id = :'parent';
select is(private.family_plus_seats(:'parent'), 0, 'an expired grant gives no seats');
select ok(not pg_temp.covered(:'parent', 1), 'and covers nobody');
select is(pg_temp.insights(1), 'forbidden', 'the insights read refuses at once');
select is(pg_temp.links()->'familyPlan', 'null'::jsonb, 'the links show no plan');
select is(pg_temp.link_unlocked(1), false, 'and no child unlocked');
select is((select count(*)::int from pg_temp.granted_rows()), 0,
  'the billing read no longer lists it');

update private.family_plus_grants
  set starts_at = now() + interval '1 day', ends_at = now() + interval '1 year'
  where user_id = :'parent';
select is(private.family_plus_seats(:'parent'), 0,
  'a grant that has not started yet gives nothing');

select * from finish();
rollback;
