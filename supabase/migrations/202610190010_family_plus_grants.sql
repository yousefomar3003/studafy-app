-- Complimentary Family+ for a parent, without a store purchase.
--
-- The student plans have had comp grants since 202609270008
-- (private.study_plan_grants). Family+ is the parent's own plan and had
-- none, so a parent account could only reach it through a real store
-- purchase - which an app-store reviewer, or a parent given the plan as
-- support credit, cannot make. This adds the same thing for Family+:
--
--   * private.family_plus_grants - written only by an operator with direct
--     database access, exactly like study_plan_grants; no API writes here;
--   * private.family_plus_seats counts a live grant as well as a live store
--     entitlement (the larger wins), so family_plus_covered, the
--     parent_insights_has_access gate and getFamilyInsights all honour it
--     with no change of their own;
--   * the app is told, in both places it learns the parent's plan:
--       - GET /v1/billing/entitlements (billing_list_entitlements) lists a
--         live grant as a family plan row marked `granted`, with no store
--         or product, so the app offers no store management for it;
--       - GET /v1/me/guardian-links (ops_query_my_guardian_links) now says,
--         per link, whether Family+ is unlocked for that child, and the
--         parent's current family plan. This read is always mounted, so the
--         app learns a granted plan even where billing is not (the test
--         copy runs with PAY071_BILLING_ENABLED=false).
--
-- Whether a parent has Family+ is still decided only here, on every read.

-- ---------------------------------------------------------------------------
-- 1. The grants.
-- ---------------------------------------------------------------------------
create table if not exists private.family_plus_grants (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  tier text not null check (tier in ('family_plus', 'family_plus_large')),
  reason text not null check (length(trim(reason)) between 3 and 200),
  starts_at timestamptz not null default now(),
  ends_at timestamptz not null,
  created_at timestamptz not null default now(),
  check (ends_at > starts_at)
);
create index if not exists family_plus_grants_user_idx
  on private.family_plus_grants (user_id, ends_at);
revoke all on private.family_plus_grants
  from public, anon, authenticated, service_role, studafy_api_runtime,
  studafy_worker_runtime;

-- ---------------------------------------------------------------------------
-- 2. Seats: a live grant counts like a live store entitlement.
--
-- Copied from 202609300007_family_plus_tiers.sql with the grant branch
-- added. The larger of the two wins: a parent granted 8 who also bought 4
-- is covered for 8.
-- ---------------------------------------------------------------------------
create or replace function private.family_plus_seats(p_guardian uuid)
returns integer
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(max(held.seats), 0)::integer
  from (
    select case e.feature_key
        when 'family_plus_large' then 8
        when 'family_plus' then 4
      end as seats
    from public.entitlements e
    join public.store_transactions st on st.id = e.source_transaction_id
    join private.notebook_runtime runtime on runtime.singleton
    where e.user_id = p_guardian
      and e.feature_key in ('family_plus', 'family_plus_large')
      and e.status in ('active', 'grace_period')
      and e.starts_at <= now() and e.ends_at > now()
      and st.environment = runtime.environment
    union all
    select case g.tier when 'family_plus_large' then 8 else 4 end
    from private.family_plus_grants g
    where g.user_id = p_guardian
      and g.starts_at <= now() and g.ends_at > now()
  ) held;
$$;

-- ---------------------------------------------------------------------------
-- 3. The parent's current family plan, as the app shows it.
--
-- The largest live plan, store or grant. At the same size a store
-- subscription is preferred, so the app still offers to manage one the
-- parent pays for. `granted` means the plan shown has no store subscription
-- behind it: nothing to manage, cancel or restore.
-- ---------------------------------------------------------------------------
create or replace function private.family_plus_plan(p_guardian uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  with held as (
    select e.feature_key as tier, e.ends_at, false as granted
    from public.entitlements e
    join public.store_transactions st on st.id = e.source_transaction_id
    join private.notebook_runtime runtime on runtime.singleton
    where e.user_id = p_guardian
      and e.feature_key in ('family_plus', 'family_plus_large')
      and e.status in ('active', 'grace_period')
      and e.starts_at <= now() and e.ends_at > now()
      and st.environment = runtime.environment
    union all
    select g.tier, g.ends_at, true
    from private.family_plus_grants g
    where g.user_id = p_guardian
      and g.starts_at <= now() and g.ends_at > now()
  )
  select jsonb_build_object(
    'featureKey', best.tier,
    'endsAt', best.ends_at,
    'granted', best.granted,
    'coveredStudentIds', coalesce((
      select jsonb_agg(covered.student_id)
      from private.family_plus_covered(p_guardian) covered
    ), '[]'::jsonb)
  )
  from (
    select held.tier, held.ends_at, held.granted
    from held
    order by case held.tier when 'family_plus_large' then 8 else 4 end desc,
      held.granted, held.ends_at desc
    limit 1
  ) best;
$$;

do $$
declare
  fn text;
begin
  foreach fn in array array[
    'private.family_plus_seats(uuid)',
    'private.family_plus_plan(uuid)'
  ] loop
    execute format('alter function %s owner to postgres', fn);
    execute format(
      'revoke all on function %s from public, anon, authenticated, '
      'service_role, studafy_worker_runtime, studafy_api_runtime', fn);
  end loop;
end;
$$;

-- ---------------------------------------------------------------------------
-- 4. What the billing read tells the app: a live grant is a family plan row.
--
-- Copied from 202609300007_family_plus_tiers.sql with the third branch
-- added. A grant row carries no platform, product or renewal status - there
-- is no store subscription to manage - and is marked `granted`.
-- ---------------------------------------------------------------------------
create or replace function private.billing_list_entitlements(p_environment text)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(jsonb_agg(row_json order by sort_feature, sort_student), '[]'::jsonb)
  from (
    select jsonb_build_object(
        'featureKey', e.feature_key, 'status', e.status,
        'startsAt', e.starts_at, 'endsAt', e.ends_at,
        'beneficiaryStudentId', null,
        'renewalStatus', st.renewal_status,
        'platform', st.platform,
        'storeProductId', sp.store_product_id,
        'purchasedByMe', st.purchaser_id = auth.uid()
      ) || case when e.feature_key in ('family_plus', 'family_plus_large')
        then jsonb_build_object(
          'coveredStudentIds', coalesce((
            select jsonb_agg(covered.student_id)
            from private.family_plus_covered(auth.uid()) covered
          ), '[]'::jsonb))
        else '{}'::jsonb end
        as row_json,
      e.feature_key as sort_feature, '' as sort_student
    from public.entitlements e
    join public.store_transactions st on st.id = e.source_transaction_id
    join public.store_products sp on sp.id = st.product_id
    where e.user_id = auth.uid() and st.environment = p_environment
    union all
    select jsonb_build_object(
        'featureKey', e.feature_key, 'status', e.status,
        'startsAt', e.starts_at, 'endsAt', e.ends_at,
        'beneficiaryStudentId', s.id,
        'renewalStatus', st.renewal_status,
        'platform', st.platform,
        'storeProductId', sp.store_product_id,
        'purchasedByMe', st.purchaser_id = auth.uid()
      ), e.feature_key, s.id::text
    from public.guardian_links gl
    join public.students s on s.id = gl.student_id and s.deleted_at is null
    join public.entitlements e on e.user_id = s.user_id
      and e.feature_key = 'parent_insights'
    join public.store_transactions st on st.id = e.source_transaction_id
    join public.store_products sp on sp.id = st.product_id
    where gl.guardian_id = auth.uid() and gl.status = 'verified'
      and (gl.expires_at is null or gl.expires_at > now())
      and st.environment = p_environment
    union all
    -- A live comp grant of Family+. Not tied to a store environment: it was
    -- given by an operator of this database, not bought anywhere.
    select jsonb_build_object(
        'featureKey', g.tier, 'status', 'active',
        'startsAt', g.starts_at, 'endsAt', g.ends_at,
        'beneficiaryStudentId', null,
        'renewalStatus', null,
        'purchasedByMe', false,
        'granted', true,
        'coveredStudentIds', coalesce((
          select jsonb_agg(covered.student_id)
          from private.family_plus_covered(auth.uid()) covered
        ), '[]'::jsonb)
      ), g.tier, g.id::text
    from private.family_plus_grants g
    where g.user_id = auth.uid()
      and g.starts_at <= now() and g.ends_at > now()
  ) visible
  where private.is_active_user();
$$;

alter function private.billing_list_entitlements(text) owner to postgres;
revoke all on function private.billing_list_entitlements(text)
  from public, anon, authenticated, service_role, studafy_worker_runtime;
grant execute on function private.billing_list_entitlements(text)
  to studafy_api_runtime;

-- ---------------------------------------------------------------------------
-- 5. A guardian's own links say whether Family+ is unlocked for each child,
--    and what the parent's family plan is.
--
-- Copied from 202610160020_guardian_link_messaging.sql with `familyPlus`
-- (per link) and `familyPlan` (top level) added. `familyPlus` is the very
-- gate getFamilyInsights applies (parent_insights_has_access), so the app
-- never shows the insights tab open for a child the server would refuse.
-- A guardian has a handful of links, so the per-link check stays a few
-- index lookups.
-- ---------------------------------------------------------------------------
create or replace function private.ops_query_my_guardian_links(p_operation text, p_resource_id uuid, p_input jsonb)
 returns jsonb
 language plpgsql
 stable security definer
 set search_path to ''
as $function$
declare
  v_actor uuid := auth.uid();
  result jsonb;
begin

  if v_actor is null or not private.is_active_user() then
    return jsonb_build_object('outcome', 'forbidden');
  end if;
  select coalesce(jsonb_agg(jsonb_build_object(
      'id', gl.id,
      'schoolId', st.school_id,
      'schoolName', s.name,
      'studentId', st.id,
      'studentName', st.display_name,
      'relationship', gl.relationship,
      'status', gl.status,
      'expiresAt', gl.expires_at,
      'messagingEnabled', private.school_messaging_enabled(st.school_id),
      'familyPlus', gl.status = 'verified'
        and private.parent_insights_has_access(st.id)
    ) order by gl.updated_at desc, gl.id), '[]'::jsonb)
  into result
  from public.guardian_links gl
  join public.students st on st.id = gl.student_id and st.deleted_at is null
  join public.schools s on s.id = st.school_id
  where gl.guardian_id = v_actor;
  return jsonb_build_object(
    'items', result,
    'familyPlan', private.family_plus_plan(v_actor)
  );
end;
$function$;

revoke all on function private.ops_query_my_guardian_links(text, uuid, jsonb)
  from public, anon, authenticated, service_role, studafy_api_runtime,
  studafy_worker_runtime;
