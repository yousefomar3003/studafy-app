-- PAY-071 billing decision surface. Provider verification (Apple App Store
-- Server API / JWS, Google Play Developer API) happens in TypeScript before
-- any of these functions are called - they receive already-verified,
-- normalized fields and own the transactional ledger write + entitlement
-- derivation, exactly like private.api050_issue_intent separates "TS does
-- I/O" from "SQL does the transactional business logic".
--
-- Eligibility (guardian link verified+unexpired, per-school self-purchase
-- switch, parental gate) is enforced here, not just at the client, because
-- the client's opinion of eligibility is not authoritative.

create or replace function private.billing_derive_entitlement(
  p_beneficiary uuid,
  p_feature_key text,
  p_platform public.store_platform,
  p_transaction_id uuid,
  p_original_transaction_id text,
  p_state public.store_transaction_state,
  p_starts_at timestamptz,
  p_ends_at timestamptz
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  target_status public.entitlement_status;
  current_row public.entitlements%rowtype;
  current_original text;
begin
  target_status := case p_state
    when 'pending' then 'pending'::public.entitlement_status
    when 'active' then 'active'::public.entitlement_status
    when 'grace_period' then 'grace_period'::public.entitlement_status
    when 'on_hold' then 'on_hold'::public.entitlement_status
    when 'expired' then 'expired'::public.entitlement_status
    when 'refunded' then 'revoked'::public.entitlement_status
    when 'revoked' then 'revoked'::public.entitlement_status
  end;

  select e.* into current_row
  from public.entitlements e
  where e.user_id = p_beneficiary and e.feature_key = p_feature_key
    and e.status in ('pending', 'active', 'grace_period', 'on_hold')
  order by e.updated_at desc
  limit 1
  for update;

  if current_row.id is not null then
    select st.original_transaction_id into current_original
    from public.store_transactions st
    where st.id = current_row.source_transaction_id;

    if current_original is not null and current_original = p_original_transaction_id then
      -- Same subscription lineage (renewal/state update), not a second
      -- purchase: update the existing entitlement in place.
      update public.entitlements
        set status = target_status,
            source_transaction_id = p_transaction_id,
            starts_at = least(current_row.starts_at, p_starts_at),
            ends_at = p_ends_at,
            version = current_row.version + 1,
            updated_at = now()
        where id = current_row.id;
      return jsonb_build_object(
        'outcome', 'updated', 'entitlementId', current_row.id
      );
    end if;

    -- A different transaction already holds the current entitlement for this
    -- beneficiary/feature. Collapse rather than double-grant: the first
    -- purchase keeps access, this one is recorded in the ledger (full audit
    -- trail) but does not grant a second entitlement. Flagged for a
    -- support/refund review, which is a store-side action this API cannot
    -- perform on its own.
    return jsonb_build_object(
      'outcome', 'duplicate_entitlement', 'entitlementId', current_row.id
    );
  end if;

  insert into public.entitlements(
    user_id, school_id, feature_key, source, source_transaction_id,
    status, starts_at, ends_at
  ) values (
    p_beneficiary, null, p_feature_key, p_platform, p_transaction_id,
    target_status, p_starts_at, p_ends_at
  );
  return jsonb_build_object(
    'outcome', case when target_status = 'pending' then 'pending' else 'granted' end
  );
end;
$$;

-- ADR-0009 beneficiary resolution. Every purchase path funnels through this
-- so eligibility (guardian link, self-purchase switch, parental gate) is
-- enforced once, identically, for submit and restore.
create or replace function private.billing_resolve_beneficiary(
  p_purchaser uuid,
  p_feature_key text,
  p_beneficiary_student_id uuid,
  p_parental_gate_confirmed boolean
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
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

  -- Self-purchase: only student_notebook/student_ai reach here (the two
  -- branches above already returned for teacher_ai_grading/parent_insights).
  select st.* into student_row from public.students st
  where st.user_id = p_purchaser and st.deleted_at is null;
  if student_row.id is null then
    return jsonb_build_object('ok', false, 'outcome', 'not_eligible');
  end if;
  if not p_parental_gate_confirmed then
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
    false
  ) then
    return jsonb_build_object('ok', false, 'outcome', 'student_purchase_disabled');
  end if;
  return jsonb_build_object(
    'ok', true, 'beneficiaryId', p_purchaser, 'guardianLinkId', null
  );
end;
$$;

-- Products currently offered. Environment-scoped; storefront_listed is the
-- gate that keeps the two AI products and Parent Insights out of the
-- catalogue outside `synthetic` until AI-072/legal sign-off, while their
-- ledger/derivation code remains fully exercised by synthetic tests.
create or replace function private.billing_catalogue(p_environment text)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(jsonb_agg(jsonb_build_object(
      'featureKey', p.feature_key, 'platform', p.platform,
      'storeProductId', p.store_product_id
    ) order by p.feature_key, p.platform), '[]'::jsonb)
  from public.store_products p
  where p.environment = p_environment
    and p.active and p.storefront_listed
    and p.effective_from <= now()
    and (p.effective_until is null or p.effective_until > now());
$$;

-- Whether the caller's own school membership currently allows student
-- self-purchase. Not tenantRequired at the API permission layer (self scope,
-- like account.profile.read): this function only ever answers for a school
-- the caller actually belongs to, never an arbitrary id.
create or replace function private.billing_self_purchase_status()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(jsonb_agg(jsonb_build_object(
      'schoolId', m.school_id,
      'selfPurchaseEnabled', coalesce(s.self_purchase_enabled, false)
    ) order by m.school_id), '[]'::jsonb)
  from public.memberships m
  left join public.school_billing_settings s on s.school_id = m.school_id
  where m.user_id = auth.uid() and m.role = 'student'
    and m.active and m.status = 'active';
$$;

-- School-admin write path for the switch. Self-scoped at the API permission
-- layer; is_school_admin is the real guard, the same reasoning already
-- documented for guardian_link.revoke/support_access.*.
create or replace function private.billing_set_self_purchase(
  p_school_id uuid,
  p_enabled boolean
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not private.is_school_admin(p_school_id) then
    return false;
  end if;
  insert into public.school_billing_settings(school_id, self_purchase_enabled)
  values (p_school_id, p_enabled)
  on conflict (school_id) do update set self_purchase_enabled = p_enabled;
  return true;
end;
$$;

-- Client-submitted purchase verification. `p_body` carries fields already
-- verified against Apple/Google by the caller (apps/api/src/billing).
create or replace function private.billing_submit_verification(p_body jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  purchaser uuid := auth.uid();
  product_row public.store_products%rowtype;
  resolved jsonb;
  beneficiary uuid;
  guardian_link uuid;
  gate_confirmed_at timestamptz;
  existing public.store_transactions%rowtype;
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
    and sp.active
    and sp.effective_from <= now()
    and (sp.effective_until is null or sp.effective_until > now());
  if product_row.id is null or product_row.feature_key <> p_body->>'productFeatureKey' then
    return jsonb_build_object('outcome', 'product_not_found');
  end if;

  resolved := private.billing_resolve_beneficiary(
    purchaser, product_row.feature_key,
    nullif(p_body->>'beneficiaryStudentId', '')::uuid,
    coalesce((p_body->>'parentalGateConfirmed')::boolean, false)
  );
  if not (resolved->>'ok')::boolean then
    return jsonb_build_object('outcome', resolved->>'outcome');
  end if;
  beneficiary := (resolved->>'beneficiaryId')::uuid;
  guardian_link := nullif(resolved->>'guardianLinkId', '')::uuid;
  gate_confirmed_at := case
    when guardian_link is null and beneficiary = purchaser
      and product_row.feature_key <> 'teacher_ai_grading'
    then now() else null
  end;

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
      where id = existing.id;
  else
    insert into public.store_transactions(
      platform, environment, purchaser_id, product_id, beneficiary_id,
      guardian_link_id, parental_gate_confirmed_at,
      original_transaction_id, transaction_id, signed_data_hash,
      state, purchased_at, effective_until
    ) values (
      product_row.platform, p_body->>'environment', purchaser, product_row.id,
      beneficiary, guardian_link, gate_confirmed_at,
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
$$;

-- Restore: keyed on `originalTransactionId` (the store's stable subscription
-- identifier) rather than the exact renewal `transactionId`, matching how
-- Apple/Google restore semantics work. A transaction already on file for a
-- beneficiary the caller cannot claim returns `owned_by_other_account`
-- rather than transferring it. Not found on file at all falls through to the
-- same verification path as a first submission (a legitimate restore can be
-- the first time our server ever sees the transaction, e.g. reinstall before
-- the original purchase was ever verified).
create or replace function private.billing_restore(p_body jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  purchaser uuid := auth.uid();
  existing public.store_transactions%rowtype;
begin
  if not private.is_active_user() then
    return jsonb_build_object('outcome', 'forbidden');
  end if;

  select * into existing from public.store_transactions
  where platform = (p_body->>'platform')::public.store_platform
    and environment = p_body->>'environment'
    and original_transaction_id = p_body->>'originalTransactionId'
  order by created_at desc
  limit 1;

  if existing.id is not null then
    if existing.purchaser_id <> purchaser and existing.beneficiary_id <> purchaser then
      return jsonb_build_object('outcome', 'owned_by_other_account');
    end if;
    return jsonb_build_object(
      'outcome', 'ok',
      'response', jsonb_build_object('restored', true)
    );
  end if;

  return private.billing_submit_verification(p_body);
end;
$$;

-- The caller's own entitlements (as beneficiary), across every school.
create or replace function private.billing_list_entitlements()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(jsonb_agg(jsonb_build_object(
      'featureKey', e.feature_key, 'status', e.status,
      'startsAt', e.starts_at, 'endsAt', e.ends_at
    ) order by e.feature_key), '[]'::jsonb)
  from public.entitlements e
  where e.user_id = auth.uid();
$$;

-- Durable webhook dedupe. Called by the API route before it acks the
-- provider with 200 - a duplicate delivery is a no-op here, never a second
-- row and never a second dispatch.
create or replace function private.billing_record_event(
  p_platform public.store_platform,
  p_environment text,
  p_external_event_id text,
  p_payload_hash text,
  p_raw_payload text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  new_id bigint;
begin
  insert into public.store_events(
    platform, environment, external_event_id, payload_hash, raw_payload
  ) values (
    p_platform, p_environment, p_external_event_id, p_payload_hash, p_raw_payload
  )
  on conflict (platform, environment, external_event_id) where external_event_id is not null
    do nothing
  returning id into new_id;
  if new_id is null then
    return jsonb_build_object('outcome', 'duplicate');
  end if;
  return jsonb_build_object('outcome', 'new', 'eventId', new_id);
end;
$$;

alter function private.billing_derive_entitlement(uuid, text, public.store_platform, uuid, text, public.store_transaction_state, timestamptz, timestamptz) owner to postgres;
alter function private.billing_resolve_beneficiary(uuid, text, uuid, boolean) owner to postgres;
alter function private.billing_catalogue(text) owner to postgres;
alter function private.billing_self_purchase_status() owner to postgres;
alter function private.billing_set_self_purchase(uuid, boolean) owner to postgres;
alter function private.billing_submit_verification(jsonb) owner to postgres;
alter function private.billing_restore(jsonb) owner to postgres;
alter function private.billing_list_entitlements() owner to postgres;
alter function private.billing_record_event(public.store_platform, text, text, text, text) owner to postgres;

revoke all on function private.billing_catalogue(text),
  private.billing_self_purchase_status(),
  private.billing_set_self_purchase(uuid, boolean),
  private.billing_submit_verification(jsonb),
  private.billing_restore(jsonb),
  private.billing_list_entitlements(),
  private.billing_record_event(public.store_platform, text, text, text, text)
  from public, anon, authenticated, service_role, studafy_worker_runtime;

grant execute on function private.billing_catalogue(text),
  private.billing_self_purchase_status(),
  private.billing_set_self_purchase(uuid, boolean),
  private.billing_submit_verification(jsonb),
  private.billing_restore(jsonb),
  private.billing_list_entitlements(),
  private.billing_record_event(public.store_platform, text, text, text, text)
  to studafy_api_runtime;
