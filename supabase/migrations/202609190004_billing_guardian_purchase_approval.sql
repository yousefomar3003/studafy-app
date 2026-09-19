-- Audit follow-up (2026-09-19): replace the arithmetic "parental gate" with
-- real guardian approval (ADR-0009, DL-048).
--
-- The previous gate was a signed single-digit multiplication whose token
-- carried both operands in readable base64. It proved nothing about who was
-- holding the device: any child, or a three-line script, could answer it.
-- A student self-purchase now requires an approval decided by a guardian
-- who holds a verified, unexpired link to that student, from the guardian's
-- own authenticated session after a fresh recent-auth challenge. The server
-- consumes the approval exactly once when it records the first store
-- transaction of the subscription lineage; renewals of that lineage inherit
-- it and never need a second approval.

alter table public.auth_reauth_grants drop constraint auth_reauth_grants_purpose_check;
alter table public.auth_reauth_grants add constraint auth_reauth_grants_purpose_check check (
  purpose in (
    'account_deletion',
    'account_deletion_cancel',
    'account_link',
    'all_device_sign_out',
    'device_revoke',
    'school_admin_privileged',
    'account_data_export',
    'billing_purchase_approval'
  )
) not valid;
alter table public.auth_reauth_grants validate constraint auth_reauth_grants_purpose_check;

create type public.billing_approval_status as enum (
  'requested', 'approved', 'declined', 'consumed', 'expired'
);

create table public.billing_purchase_approvals (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  student_id uuid not null references public.students(id) on delete cascade,
  student_user_id uuid not null references public.profiles(id) on delete cascade,
  feature_key text not null check (feature_key in ('student_notebook')),
  status public.billing_approval_status not null default 'requested',
  requested_at timestamptz not null default now(),
  request_expires_at timestamptz not null default now() + interval '7 days',
  decided_by uuid references public.profiles(id) on delete set null,
  guardian_link_id uuid references public.guardian_links(id) on delete set null,
  decided_at timestamptz,
  -- An approval is spendable for 72 hours after the decision: long enough
  -- for a purchase interrupted by an app kill to be replayed and verified,
  -- short enough that a forgotten approval does not become a standing grant.
  approval_expires_at timestamptz,
  consumed_at timestamptz,
  constraint billing_purchase_approvals_spendable_check
    check (status not in ('approved', 'consumed') or approval_expires_at is not null),
  check ((status = 'consumed') = (consumed_at is not null))
);

-- At most one open (requested or approved) approval per student and product.
create unique index billing_purchase_approvals_open_idx
  on public.billing_purchase_approvals(student_user_id, feature_key)
  where status in ('requested', 'approved');
create index billing_purchase_approvals_student_idx
  on public.billing_purchase_approvals(student_id, requested_at desc);

alter table public.billing_purchase_approvals enable row level security;
revoke all on public.billing_purchase_approvals
  from public, anon, authenticated, service_role,
    studafy_api_runtime, studafy_worker_runtime;

create trigger billing_purchase_approval_pinned
before update on public.billing_purchase_approvals
for each row execute function private.reject_immutable_columns(
  'id', 'school_id', 'student_id', 'student_user_id', 'feature_key', 'requested_at'
);

alter table public.store_transactions
  add column purchase_approval_id uuid
    references public.billing_purchase_approvals(id) on delete restrict;

drop trigger pay071_immutable_ledger_columns on public.store_transactions;
create trigger pay071_immutable_ledger_columns
before update on public.store_transactions
for each row execute function private.reject_immutable_columns(
  'id', 'platform', 'environment', 'purchaser_id', 'product_id',
  'original_transaction_id', 'transaction_id', 'signed_data_hash',
  'purchased_at', 'created_at', 'beneficiary_id', 'guardian_link_id',
  'parental_gate_confirmed_at', 'purchase_approval_id'
);

create or replace function private.billing_approval_json(p_row public.billing_purchase_approvals)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'id', p_row.id,
    'studentId', p_row.student_id,
    'studentName', (select s.display_name from public.students s where s.id = p_row.student_id),
    'featureKey', p_row.feature_key,
    'status', case
      when p_row.status = 'requested' and p_row.request_expires_at <= now() then 'expired'
      when p_row.status = 'approved' and p_row.approval_expires_at <= now() then 'expired'
      else p_row.status::text end,
    'requestedAt', p_row.requested_at,
    'decidedAt', p_row.decided_at,
    'expiresAt', coalesce(p_row.approval_expires_at, p_row.request_expires_at)
  );
$$;

-- A student asks their guardians to approve one product. Returns the open
-- approval if one already exists, so repeated taps notify nobody twice.
create or replace function private.billing_request_purchase_approval(p_feature_key text)
returns jsonb language plpgsql security definer set search_path = '' as $$
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
  if p_feature_key is distinct from 'student_notebook' then
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
$$;

-- Approvals the caller may see: their own requests as a student, and those
-- of every child they hold a verified, unexpired guardian link to.
create or replace function private.billing_list_purchase_approvals()
returns jsonb language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(private.billing_approval_json(a) order by a.requested_at desc), '[]'::jsonb)
  from (
    select a.* from public.billing_purchase_approvals a
    where a.student_user_id = auth.uid()
    union
    select a.* from public.billing_purchase_approvals a
    join public.guardian_links gl on gl.student_id = a.student_id
    where gl.guardian_id = auth.uid() and gl.status = 'verified'
      and (gl.expires_at is null or gl.expires_at > now())
    order by requested_at desc
    limit 50
  ) a
  where private.is_active_user();
$$;

-- Only a verified guardian of that student can decide, only while the
-- request is still open. The API requires a recent-auth grant for the
-- 'billing_purchase_approval' purpose before calling this.
create or replace function private.billing_decide_purchase_approval(p_approval_id uuid, p_approve boolean)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  decider uuid := auth.uid();
  row_state public.billing_purchase_approvals%rowtype;
  link_id uuid;
begin
  if not private.is_active_user() then
    return jsonb_build_object('outcome', 'forbidden');
  end if;
  select * into row_state from public.billing_purchase_approvals
  where id = p_approval_id for update;
  if row_state.id is not null then
    select gl.id into link_id from public.guardian_links gl
    where gl.student_id = row_state.student_id and gl.guardian_id = decider
      and gl.status = 'verified' and (gl.expires_at is null or gl.expires_at > now());
  end if;
  -- Unknown and not-yours are indistinguishable: no approval-id oracle.
  if row_state.id is null or link_id is null then
    return jsonb_build_object('outcome', 'not_found');
  end if;
  if row_state.status <> 'requested' or row_state.request_expires_at <= now() then
    return jsonb_build_object('outcome', 'invalid_state');
  end if;

  update public.billing_purchase_approvals
    set status = case when p_approve then 'approved' else 'declined' end::public.billing_approval_status,
        decided_by = decider, guardian_link_id = link_id, decided_at = now(),
        approval_expires_at = case when p_approve then now() + interval '72 hours' else null end
    where id = row_state.id
    returning * into row_state;

  perform private.notify_recipient(
    row_state.school_id, row_state.student_user_id,
    case when p_approve then 'billing.purchase_approval_approved'
      else 'billing.purchase_approval_declined' end,
    jsonb_build_object('approvalId', row_state.id, 'featureKey', row_state.feature_key),
    'billing_purchase_approval:' || row_state.id,
    'billing.purchase_approval_decided:' || row_state.id
  );

  return jsonb_build_object('outcome', 'ok', 'response', private.billing_approval_json(row_state));
end;
$$;

-- The self-purchase branch of beneficiary resolution no longer trusts a
-- caller-supplied confirmation. p_parental_gate_confirmed is retained only
-- for signature compatibility and is ignored; the approval is checked, and
-- consumed, by billing_apply_verification below.
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
      and product_row.feature_key in ('student_notebook', 'student_ai');
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
$$;

do $grants$
declare
  fn text;
begin
  foreach fn in array array[
    'private.billing_approval_json(public.billing_purchase_approvals)',
    'private.billing_request_purchase_approval(text)',
    'private.billing_list_purchase_approvals()',
    'private.billing_decide_purchase_approval(uuid, boolean)',
    'private.billing_apply_verification(jsonb, boolean)'
  ]
  loop
    execute format('alter function %s owner to postgres', fn);
    execute format(
      'revoke all on function %s from public, anon, authenticated, service_role, studafy_api_runtime, studafy_worker_runtime',
      fn
    );
  end loop;
end
$grants$;

grant execute on function
  private.billing_request_purchase_approval(text),
  private.billing_list_purchase_approvals(),
  private.billing_decide_purchase_approval(uuid, boolean)
to studafy_api_runtime;
