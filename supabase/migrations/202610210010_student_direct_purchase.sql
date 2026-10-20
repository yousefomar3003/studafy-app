-- Students buy Studafy Plus and Max themselves (DL-071, owner 2026-10-20).
--
-- The owner: "the students pay for it with their parents card", and "I would
-- never let student ask the parents to purchase - just take it off and update
-- the policies to include it." So:
--
--   * A student's own purchase of `studafy_plus` or `studafy_max` is verified
--     and granted with no guardian approval. Payment is whatever the store
--     account on the phone holds; for a child, the stores' own family tools
--     (Google Family Link purchase approval, Apple Ask to Buy) are the
--     parent's control. Studafy adds no step of its own.
--   * The in-app approval flow of DL-048 is retired. Its table and the
--     ledger's `purchase_approval_id` stay, read-only history; nothing writes
--     either again. The three approval functions answer as retired (see
--     below), so an API still running the previous release during a deploy
--     refuses cleanly instead of failing.
--   * Student purchases are allowed by default. There is no school
--     administrator in this release, and the per-school switch could only be
--     turned on by one, so no student could ever buy. A school with no
--     settings row now counts as enabled, every existing row is set to true,
--     and the column's default becomes true. The column stays for a future
--     opt-out; nothing requires an administrator to sell.
--   * Family+ is unchanged: only a verified guardian of at least one child
--     may buy it, and it is held by the parent who pays.

-- ---------------------------------------------------------------------------
-- 1. Purchases are on unless a school opts out.
-- ---------------------------------------------------------------------------
alter table public.school_billing_settings
  alter column self_purchase_enabled set default true;
update public.school_billing_settings
  set self_purchase_enabled = true, updated_at = now()
  where not self_purchase_enabled;

comment on column public.school_billing_settings.self_purchase_enabled is
  'Whether students of this school may buy their own study plan. Default true; a school with no row counts as true (DL-071). Kept for a future opt-out.';

create or replace function private.billing_self_purchase_status()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(jsonb_agg(jsonb_build_object(
      'schoolId', m.school_id,
      'selfPurchaseEnabled', coalesce(s.self_purchase_enabled, true)
    ) order by m.school_id), '[]'::jsonb)
  from public.memberships m
  left join public.school_billing_settings s on s.school_id = m.school_id
  where m.user_id = auth.uid() and m.role = 'student'
    and m.active and m.status = 'active';
$$;

-- ---------------------------------------------------------------------------
-- 2. Who a purchase is for.
--
-- Re-issued from 202609300007 with only the self-purchase tail changed: a
-- study plan needs no approval, and a missing settings row counts as on.
-- `p_parental_gate_confirmed` stays for the signature; it is now only ever
-- false, so a retired student product (`student_notebook`, `student_ai`)
-- still cannot be newly bought by a student.
-- ---------------------------------------------------------------------------
create or replace function private.billing_resolve_beneficiary(p_purchaser uuid, p_feature_key text, p_beneficiary_student_id uuid, p_parental_gate_confirmed boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  student_row public.students%rowtype;
  guardian_link uuid;
  purchaser_school uuid;
begin
  if p_feature_key = 'teacher_ai_grading' then
    if p_beneficiary_student_id is not null then
      return jsonb_build_object('ok', false, 'outcome', 'invalid_beneficiary');
    end if;
    if not exists (
      select 1 from public.memberships m
      where m.user_id = p_purchaser and m.role = 'teacher'
        and m.active and m.status = 'active'
        and m.valid_from <= now() and (m.valid_until is null or m.valid_until > now())
    ) then
      return jsonb_build_object('ok', false, 'outcome', 'not_eligible');
    end if;
    return jsonb_build_object(
      'ok', true, 'beneficiaryId', p_purchaser, 'guardianLinkId', null
    );
  end if;

  -- Family+ is the parent's own plan, covering their linked children up to
  -- the plan's size. It is held by the guardian who pays, so no child is
  -- named at purchase; only somebody who is already a verified guardian of
  -- at least one child may buy it.
  if p_feature_key in ('family_plus', 'family_plus_large') then
    if p_beneficiary_student_id is not null then
      return jsonb_build_object('ok', false, 'outcome', 'invalid_beneficiary');
    end if;
    if not exists (
      select 1 from public.guardian_links gl
      join public.students s on s.id = gl.student_id and s.deleted_at is null
      where gl.guardian_id = p_purchaser and gl.status = 'verified'
        and (gl.expires_at is null or gl.expires_at > now())
    ) then
      return jsonb_build_object('ok', false, 'outcome', 'not_eligible');
    end if;
    return jsonb_build_object(
      'ok', true, 'beneficiaryId', p_purchaser, 'guardianLinkId', null
    );
  end if;

  if p_feature_key = 'parent_insights' and p_beneficiary_student_id is null then
    return jsonb_build_object('ok', false, 'outcome', 'beneficiary_required');
  end if;

  if p_beneficiary_student_id is not null then
    select * into student_row from public.students
    where id = p_beneficiary_student_id and deleted_at is null;
    if student_row.id is null then
      return jsonb_build_object('ok', false, 'outcome', 'beneficiary_link_invalid');
    end if;
    select gl.id into guardian_link
      from public.guardian_links gl
      where gl.student_id = student_row.id
        and gl.guardian_id = p_purchaser
        and gl.status = 'verified'
        and (gl.expires_at is null or gl.expires_at > now())
      limit 1;
    if guardian_link is null then
      return jsonb_build_object('ok', false, 'outcome', 'beneficiary_link_invalid');
    end if;
    return jsonb_build_object(
      'ok', true, 'beneficiaryId', student_row.user_id, 'guardianLinkId', guardian_link
    );
  end if;

  -- Self-purchase: a student buying their own plan. The store account on
  -- the phone pays; for a child, the store's own family controls (Family
  -- Link, Ask to Buy) are where a parent approves (DL-071).
  select st.* into student_row from public.students st
  where st.user_id = p_purchaser and st.deleted_at is null;
  if student_row.id is null then
    return jsonb_build_object('ok', false, 'outcome', 'not_eligible');
  end if;
  if p_feature_key not in ('studafy_plus', 'studafy_max')
     and not p_parental_gate_confirmed then
    return jsonb_build_object('ok', false, 'outcome', 'parental_gate_required');
  end if;
  select m.school_id into purchaser_school from public.memberships m
  where m.user_id = p_purchaser and m.role = 'student'
    and m.active and m.status = 'active'
    and m.valid_from <= now() and (m.valid_until is null or m.valid_until > now())
  limit 1;
  if purchaser_school is null or not coalesce(
    (select s.self_purchase_enabled from public.school_billing_settings s
      where s.school_id = purchaser_school),
    true
  ) then
    return jsonb_build_object('ok', false, 'outcome', 'student_purchase_disabled');
  end if;
  return jsonb_build_object(
    'ok', true, 'beneficiaryId', p_purchaser, 'guardianLinkId', null
  );
end;
$function$;

-- ---------------------------------------------------------------------------
-- 3. Recording a verified purchase.
--
-- Re-issued from 202609270008 without the approval: no approval is looked up
-- or consumed, and a new lineage records no `purchase_approval_id`. A renewal
-- or restore of a lineage bought under DL-048 keeps the approval it was
-- recorded with; that history is never rewritten.
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
  existing public.store_transactions%rowtype;
  lineage public.store_transactions%rowtype;
  purchased_at timestamptz := (p_body->>'purchasedAt')::timestamptz;
  resolved_effective_until timestamptz := nullif(p_body->>'effectiveUntil', '')::timestamptz;
  txn_state public.store_transaction_state := (p_body->>'state')::public.store_transaction_state;
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
    -- its original beneficiary; nothing in the body can redirect it. A
    -- guardian purchase still needs a live link.
    beneficiary := lineage.beneficiary_id;
    guardian_link := lineage.guardian_link_id;
    if guardian_link is not null and not exists (
      select 1 from public.guardian_links gl
      where gl.id = guardian_link and gl.guardian_id = purchaser
        and gl.status = 'verified' and (gl.expires_at is null or gl.expires_at > now())
    ) then return jsonb_build_object('outcome', 'beneficiary_link_invalid'); end if;
  else
    resolved := private.billing_resolve_beneficiary(
      purchaser, product_row.feature_key,
      nullif(p_body->>'beneficiaryStudentId', '')::uuid,
      false
    );
    if not (resolved->>'ok')::boolean then
      return jsonb_build_object('outcome', resolved->>'outcome');
    end if;
    beneficiary := (resolved->>'beneficiaryId')::uuid;
    guardian_link := nullif(resolved->>'guardianLinkId', '')::uuid;
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
      lineage.parental_gate_confirmed_at,
      lineage.purchase_approval_id,
      p_body->>'originalTransactionId', p_body->>'transactionId', p_body->>'signedDataHash',
      txn_state, purchased_at, resolved_effective_until
    ) returning * into existing;
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

-- ---------------------------------------------------------------------------
-- 4. The approval flow is retired.
--
-- The current API no longer calls these (its approval routes answer
-- PURCHASE_APPROVAL_RETIRED, or an empty list, without the database). They
-- are kept, answering as retired, only so an API from the previous release
-- still running while this deploys refuses cleanly: `not_eligible` and
-- `not_found` are outcomes that release already maps. Nothing is created,
-- decided or notified, and no approval is listed.
-- ---------------------------------------------------------------------------
create or replace function private.billing_request_purchase_approval(p_feature_key text)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object('outcome', 'not_eligible');
$$;

create or replace function private.billing_list_purchase_approvals()
returns jsonb language sql stable security definer set search_path = '' as $$
  select '[]'::jsonb;
$$;

create or replace function private.billing_decide_purchase_approval(p_approval_id uuid, p_approve boolean)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object('outcome', 'not_found');
$$;

-- Requests still open can never be decided or spent now.
update public.billing_purchase_approvals
  set status = 'expired'
  where status in ('requested', 'approved');

comment on table public.billing_purchase_approvals is
  'Obsolete since DL-071 (2026-10-21): students buy their own study plans with no in-app approval. Kept read-only as history of purchases made under DL-048; nothing writes it.';
comment on column public.store_transactions.purchase_approval_id is
  'Obsolete since DL-071: the DL-048 approval a lineage was bought under. Null for every purchase since; kept as history.';

do $grants$
declare
  fn text;
begin
  foreach fn in array array[
    'private.billing_self_purchase_status()',
    'private.billing_resolve_beneficiary(uuid, text, uuid, boolean)',
    'private.billing_apply_verification(jsonb, boolean)',
    'private.billing_request_purchase_approval(text)',
    'private.billing_list_purchase_approvals()',
    'private.billing_decide_purchase_approval(uuid, boolean)'
  ]
  loop
    execute format('alter function %s owner to postgres', fn);
    execute format(
      'revoke all on function %s from public, anon, authenticated, service_role, studafy_worker_runtime',
      fn
    );
  end loop;
end
$grants$;

-- Unchanged from before: the API reads the switch and, until the previous
-- release is gone, may still call the retired approval functions. The
-- beneficiary and verification helpers stay unreachable from any runtime.
revoke execute on function
  private.billing_resolve_beneficiary(uuid, text, uuid, boolean),
  private.billing_apply_verification(jsonb, boolean)
from studafy_api_runtime;
grant execute on function
  private.billing_self_purchase_status(),
  private.billing_request_purchase_approval(text),
  private.billing_list_purchase_approvals(),
  private.billing_decide_purchase_approval(uuid, boolean)
to studafy_api_runtime;
