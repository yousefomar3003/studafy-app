-- Studafy Plus and Studafy Max; Lessons become free.
--
-- The owner's decision of 2026-09-27, replacing the paid "Student Notebook"
-- of PAY-071:
--
--   * Lessons - the class material a teacher publishes, which the app called
--     the Notebook - is free. No payment of any kind stands between an
--     enrolled student and their class's lessons.
--   * Studafy Plus  ($3.99/month) turns a photo of the lesson whiteboard into
--     notebook notes.
--   * Studafy Max   ($5.99/month) is Plus, and generates quizzes and
--     flashcards from the class's lessons.
--
-- Prices are the stores' to hold (App Store Connect / Play Console); nothing
-- here stores a price. What is stored is which product unlocks which plan.
--
-- Both are student products, bought by the student with a guardian's
-- approval or by a verified guardian for their child, through exactly the
-- PAY-071 machinery the notebook used - ledger, verification, entitlements -
-- which is extended here rather than duplicated.

-- ---------------------------------------------------------------------------
-- 1. Lessons are free.
--
-- private.notebook_reader_allowed was the single gate every lesson read went
-- through (the listResources query, resource publications, attachment
-- delivery). It now admits any signed-in user; everything that decides
-- *which* lessons a person may see - enrolment, publication, audience - is
-- untouched and still applies.
-- ---------------------------------------------------------------------------
create or replace function private.notebook_reader_allowed(p_school uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select auth.uid() is not null;
$$;

-- ---------------------------------------------------------------------------
-- 2. The catalogue.
--
-- The notebook product stops being offered anywhere. Plus and Max are listed
-- where the store listing can be exercised (synthetic, development); staging
-- and production carry them unlisted until the product ids are confirmed
-- against App Store Connect and Play Console, as PAY-071 requires of every
-- product before it is listed.
-- ---------------------------------------------------------------------------
update public.store_products set active = false, storefront_listed = false
where feature_key = 'student_notebook';

insert into public.store_products
  (feature_key, platform, environment, store_product_id, active, storefront_listed)
select f.key, p.platform::public.store_platform, e.env,
  'studafy_' || f.slug || '_monthly', true, e.env in ('synthetic', 'development')
from (values ('studafy_plus', 'plus'), ('studafy_max', 'max')) as f(key, slug)
cross join (values ('app_store'), ('play_store')) as p(platform)
cross join (values ('synthetic'), ('development'), ('staging'), ('production')) as e(env)
on conflict (platform, environment, store_product_id) do nothing;

alter table public.billing_purchase_approvals
  drop constraint if exists billing_purchase_approvals_feature_key_check;
alter table public.billing_purchase_approvals
  add constraint billing_purchase_approvals_feature_key_check
  check (feature_key in ('student_notebook', 'studafy_plus', 'studafy_max'));

-- ---------------------------------------------------------------------------
-- 3. The purchase path treats Plus and Max as student products.
--
-- Re-issued from their current definitions with only the product lists
-- changed: a self-purchase of either needs the same guardian approval the
-- notebook did, and only these two may be newly requested.
-- ---------------------------------------------------------------------------
create or replace function private.billing_apply_verification(p_body jsonb, p_restore boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  purchaser uuid := auth.uid();
  product_row public.store_products%rowtype;
  resolved jsonb;
  beneficiary uuid;
  guardian_link uuid;
  gate_confirmed_at timestamptz;
  approval public.billing_purchase_approvals%rowtype;
  existing public.store_transactions%rowtype;
  lineage public.store_transactions%rowtype;
  purchased_at timestamptz := (p_body->>'purchasedAt')::timestamptz;
  resolved_effective_until timestamptz := nullif(p_body->>'effectiveUntil', '')::timestamptz;
  txn_state public.store_transaction_state := (p_body->>'state')::public.store_transaction_state;
  self_purchase boolean;
  applied jsonb;
begin
  if not private.is_active_user() then
    return jsonb_build_object('outcome', 'forbidden');
  end if;

  select * into product_row from public.store_products sp
  where sp.platform = (p_body->>'platform')::public.store_platform
    and sp.environment = p_body->>'environment'
    and sp.store_product_id = p_body->>'storeProductId'
    and (sp.active or p_restore)
    and sp.effective_from <= now()
    and (sp.effective_until is null or sp.effective_until > now());
  if product_row.id is null or product_row.feature_key <> p_body->>'productFeatureKey' then
    return jsonb_build_object('outcome', 'product_not_found');
  end if;

  perform pg_advisory_xact_lock(hashtextextended(
    (p_body->>'platform') || ':' || (p_body->>'environment') || ':' ||
    (p_body->>'originalTransactionId'), 0));
  select st.* into lineage from public.store_transactions st
  where st.platform = product_row.platform
    and st.environment = p_body->>'environment'
    and st.original_transaction_id = p_body->>'originalTransactionId'
  order by st.created_at limit 1 for update;
  if lineage.id is not null and lineage.purchaser_id <> purchaser then
    return jsonb_build_object('outcome', 'owned_by_other_account');
  end if;
  if lineage.id is null and not product_row.storefront_listed then
    return jsonb_build_object('outcome', 'product_not_found');
  end if;

  if lineage.id is not null then
    -- A renewal or restore of a lineage this account already owns keeps
    -- its original beneficiary and approval; nothing in the body can
    -- redirect it. A guardian purchase still needs a live link.
    beneficiary := lineage.beneficiary_id;
    guardian_link := lineage.guardian_link_id;
    if guardian_link is not null and not exists (
      select 1 from public.guardian_links gl
      where gl.id = guardian_link and gl.guardian_id = purchaser
        and gl.status = 'verified' and (gl.expires_at is null or gl.expires_at > now())
    ) then return jsonb_build_object('outcome', 'beneficiary_link_invalid'); end if;
  else
    self_purchase := nullif(p_body->>'beneficiaryStudentId', '') is null
      and product_row.feature_key in (
        'student_notebook', 'student_ai', 'studafy_plus', 'studafy_max');
    if self_purchase then
      select * into approval from public.billing_purchase_approvals a
      where a.student_user_id = purchaser and a.feature_key = product_row.feature_key
        and a.status = 'approved' and a.approval_expires_at > now()
        and exists (
          select 1 from public.guardian_links gl
          where gl.id = a.guardian_link_id and gl.status = 'verified'
            and (gl.expires_at is null or gl.expires_at > now())
        )
      order by a.decided_at desc limit 1
      for update;
    end if;
    resolved := private.billing_resolve_beneficiary(
      purchaser, product_row.feature_key,
      nullif(p_body->>'beneficiaryStudentId', '')::uuid,
      approval.id is not null
    );
    if not (resolved->>'ok')::boolean then
      return jsonb_build_object('outcome', resolved->>'outcome');
    end if;
    beneficiary := (resolved->>'beneficiaryId')::uuid;
    guardian_link := nullif(resolved->>'guardianLinkId', '')::uuid;
    gate_confirmed_at := approval.decided_at;
  end if;

  perform pg_advisory_xact_lock(hashtextextended(beneficiary::text || ':' || product_row.feature_key, 0));

  select * into existing from public.store_transactions
  where platform = product_row.platform and environment = p_body->>'environment'
    and transaction_id = p_body->>'transactionId'
  for update;

  if existing.id is not null then
    if existing.purchaser_id <> purchaser or existing.beneficiary_id <> beneficiary then
      return jsonb_build_object('outcome', 'owned_by_other_account');
    end if;
    update public.store_transactions
      set state = txn_state, effective_until = resolved_effective_until
      where id = existing.id
        and (state is distinct from txn_state
          or effective_until is distinct from resolved_effective_until);
  else
    insert into public.store_transactions(
      platform, environment, purchaser_id, product_id, beneficiary_id,
      guardian_link_id, parental_gate_confirmed_at, purchase_approval_id,
      original_transaction_id, transaction_id, signed_data_hash,
      state, purchased_at, effective_until
    ) values (
      product_row.platform, p_body->>'environment', purchaser, product_row.id,
      beneficiary, guardian_link,
      case when lineage.id is null then gate_confirmed_at else lineage.parental_gate_confirmed_at end,
      case when lineage.id is null then approval.id else lineage.purchase_approval_id end,
      p_body->>'originalTransactionId', p_body->>'transactionId', p_body->>'signedDataHash',
      txn_state, purchased_at, resolved_effective_until
    ) returning * into existing;
    if approval.id is not null then
      update public.billing_purchase_approvals
        set status = 'consumed', consumed_at = now()
        where id = approval.id;
    end if;
  end if;

  applied := private.billing_derive_entitlement(
    beneficiary, product_row.feature_key, product_row.platform, existing.id,
    p_body->>'originalTransactionId', txn_state, purchased_at, resolved_effective_until
  );

  return jsonb_build_object(
    'outcome', 'ok',
    'response', jsonb_build_object(
      'featureKey', product_row.feature_key,
      'derivation', applied->>'outcome'
    )
  );
end;
$function$;

create or replace function private.billing_request_purchase_approval(p_feature_key text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  requester uuid := auth.uid();
  student_row public.students%rowtype;
  existing public.billing_purchase_approvals%rowtype;
  created public.billing_purchase_approvals%rowtype;
  guardian record;
begin
  if not private.is_active_user() then
    return jsonb_build_object('outcome', 'forbidden');
  end if;
  if p_feature_key is null
     or p_feature_key not in ('studafy_plus', 'studafy_max') then
    return jsonb_build_object('outcome', 'product_not_found');
  end if;
  select st.* into student_row from public.students st
  where st.user_id = requester and st.deleted_at is null
    and exists (
      select 1 from public.memberships m
      where m.user_id = requester and m.school_id = st.school_id
        and m.role = 'student' and m.active and m.status = 'active'
        and m.valid_from <= now() and (m.valid_until is null or m.valid_until > now())
    )
  limit 1;
  if student_row.id is null then
    return jsonb_build_object('outcome', 'not_eligible');
  end if;
  if not coalesce((select s.self_purchase_enabled from public.school_billing_settings s
      where s.school_id = student_row.school_id), false) then
    return jsonb_build_object('outcome', 'student_purchase_disabled');
  end if;
  if not exists (
    select 1 from public.guardian_links gl
    where gl.student_id = student_row.id and gl.status = 'verified'
      and (gl.expires_at is null or gl.expires_at > now())
  ) then
    return jsonb_build_object('outcome', 'guardian_link_required');
  end if;

  perform pg_advisory_xact_lock(hashtextextended(requester::text || ':approval:' || p_feature_key, 0));

  -- Lapse stale open rows so the partial unique index admits a new request.
  update public.billing_purchase_approvals a
    set status = 'expired'
    where a.student_user_id = requester and a.feature_key = p_feature_key
      and ((a.status = 'requested' and a.request_expires_at <= now())
        or (a.status = 'approved' and a.approval_expires_at <= now()));

  select * into existing from public.billing_purchase_approvals a
  where a.student_user_id = requester and a.feature_key = p_feature_key
    and a.status in ('requested', 'approved');
  if existing.id is not null then
    return jsonb_build_object('outcome', 'ok', 'response', private.billing_approval_json(existing));
  end if;

  insert into public.billing_purchase_approvals(school_id, student_id, student_user_id, feature_key)
  values (student_row.school_id, student_row.id, requester, p_feature_key)
  returning * into created;

  for guardian in
    select gl.guardian_id from public.guardian_links gl
    where gl.student_id = student_row.id and gl.status = 'verified'
      and (gl.expires_at is null or gl.expires_at > now())
  loop
    perform private.notify_recipient(
      student_row.school_id, guardian.guardian_id,
      'billing.purchase_approval_requested',
      jsonb_build_object('approvalId', created.id, 'featureKey', p_feature_key),
      'billing_purchase_approval:' || created.id,
      'billing.purchase_approval_requested:' || created.id || ':' || guardian.guardian_id
    );
  end loop;

  return jsonb_build_object('outcome', 'ok', 'response', private.billing_approval_json(created));
end;
$function$;

-- ---------------------------------------------------------------------------
-- 4. Complimentary plans.
--
-- For support credits, school pilots and local testing, granted by an
-- operator with direct database access - there is no API that writes here.
-- A comp grant confers the plan exactly as a store subscription does, and is
-- metered and capped the same way.
-- ---------------------------------------------------------------------------
create table if not exists private.study_plan_grants (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  plan text not null check (plan in ('plus', 'max')),
  reason text not null check (length(trim(reason)) between 3 and 200),
  starts_at timestamptz not null default now(),
  ends_at timestamptz not null,
  created_at timestamptz not null default now(),
  check (ends_at > starts_at)
);
create index if not exists study_plan_grants_user_idx
  on private.study_plan_grants (user_id, ends_at);
revoke all on private.study_plan_grants
  from public, anon, authenticated, service_role, studafy_api_runtime,
  studafy_worker_runtime;

-- ---------------------------------------------------------------------------
-- 5. Which plan a student is on.
--
-- 'max' beats 'plus' beats 'free'. A store entitlement counts only in the
-- store environment this database trusts (the same rule the notebook used),
-- and only for the account it was bought for.
-- ---------------------------------------------------------------------------
create or replace function private.study_plan(p_user uuid)
returns text language sql stable security definer set search_path = '' as $$
  with held as (
    select case e.feature_key when 'studafy_max' then 'max' else 'plus' end as plan
    from public.entitlements e
    join public.store_transactions st on st.id = e.source_transaction_id
    join private.notebook_runtime runtime on runtime.singleton
    where e.user_id = p_user
      and e.feature_key in ('studafy_plus', 'studafy_max')
      and e.status in ('active', 'grace_period')
      and e.starts_at <= now() and e.ends_at > now()
      and st.environment = runtime.environment
      and st.beneficiary_id = p_user
    union all
    select g.plan from private.study_plan_grants g
    where g.user_id = p_user and g.starts_at <= now() and g.ends_at > now()
  )
  select case
    when exists (select 1 from held where plan = 'max') then 'max'
    when exists (select 1 from held where plan = 'plus') then 'plus'
    else 'free' end;
$$;

revoke all on function private.study_plan(uuid)
  from public, anon, authenticated, service_role, studafy_worker_runtime,
  studafy_api_runtime;
alter function private.study_plan(uuid) owner to postgres;
