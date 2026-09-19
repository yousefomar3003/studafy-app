-- Audit remediation: forward-only billing trust/ownership boundary.
-- API verifies store authenticity, current state, account binding and runtime
-- environment. SQL serializes lineage ownership and enforces product policy.
create or replace function private.billing_apply_verification(p_body jsonb, p_restore boolean)
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

  -- Serialize every renewal in a subscription lineage before deciding its
  -- owner, including two concurrent first submissions from different actors.
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
  -- An existing purchase can be restored after delisting. A first-seen
  -- receipt cannot bypass a policy/legal gate by calling itself a restore.
  if (not p_restore or lineage.id is null) and not product_row.storefront_listed then
    return jsonb_build_object('outcome', 'product_not_found');
  end if;
  if p_restore and lineage.id is not null then
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
      coalesce((p_body->>'parentalGateConfirmed')::boolean, false)
    );
    if not (resolved->>'ok')::boolean then
      return jsonb_build_object('outcome', resolved->>'outcome');
    end if;
    beneficiary := (resolved->>'beneficiaryId')::uuid;
    guardian_link := nullif(resolved->>'guardianLinkId', '')::uuid;
  end if;
  if lineage.id is not null and lineage.beneficiary_id <> beneficiary then
    return jsonb_build_object('outcome', 'owned_by_other_account');
  end if;
  perform pg_advisory_xact_lock(hashtextextended(beneficiary::text || ':' || product_row.feature_key, 0));
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


revoke all on function private.billing_apply_verification(jsonb, boolean)
  from public, anon, authenticated, service_role, studafy_api_runtime, studafy_worker_runtime;

create or replace function private.billing_submit_verification(p_body jsonb)
returns jsonb language sql security definer set search_path = '' as $$
  select private.billing_apply_verification(p_body, false);
$$;

create or replace function private.billing_restore(p_body jsonb)
returns jsonb language sql security definer set search_path = '' as $$
  select private.billing_apply_verification(p_body, true);
$$;

-- Retire the unscoped reader so API credentials cannot accidentally query it.
revoke all on function private.billing_list_entitlements()
  from public, anon, authenticated, service_role, studafy_api_runtime, studafy_worker_runtime;
create or replace function private.billing_list_entitlements(p_environment text)
returns jsonb language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'featureKey', e.feature_key, 'status', e.status,
    'startsAt', e.starts_at, 'endsAt', e.ends_at
  ) order by e.feature_key), '[]'::jsonb)
  from public.entitlements e
  join public.store_transactions st on st.id = e.source_transaction_id
  where e.user_id = auth.uid() and st.environment = p_environment
    and private.is_active_user();
$$;
revoke all on function private.billing_list_entitlements(text)
  from public, anon, authenticated, service_role, studafy_worker_runtime;
grant execute on function private.billing_list_entitlements(text) to studafy_api_runtime;
