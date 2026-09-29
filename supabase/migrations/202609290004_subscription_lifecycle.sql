-- Subscription lifecycle: renewal status, per-token event matching, lost
-- renewals, and verified-only subscription notifications (2026-09-29).
--
-- 0. Store webhook events could not be processed at all (section 0).
--
-- 1. Renewal status. The ledger knew whether a subscription grants access,
--    not what happens at the end of the period, so the app could not say
--    "cancelled - access until 3 Nov", "paused" or "payment problem". The
--    API and worker now derive it from the store (Apple renewal info,
--    Google's state and autoRenewEnabled) and store it on the transaction.
--    It is display only: access still comes from state and effective_until.
--
-- 2. Events land on the transaction they are about. billing_finish_event
--    applied every event to the newest row of a lineage. On Google Play an
--    upgrade from Plus to Max issues a new purchase token linked to the old
--    one, so the old token's later EXPIRED notification was applied to the
--    new Max row and took away the plan the user had just paid for. The
--    exact transaction now wins, and a store transaction the ledger has not
--    seen (a Google resubscribe or replacement, an Apple plan change made in
--    the device's subscription settings) is recorded as a new row of the
--    same lineage, with the lineage's purchaser, beneficiary and approval.
--
-- 3. Lost renewals. The reconciliation sweep only re-read pending and
--    unacknowledged rows, so a renewal whose webhook never arrived left a
--    paying subscriber without access once the old period ended. Rows whose
--    access ended in the last 30 days are now re-verified, at most hourly.
--
-- 4. Notifications. The payer is told when a subscription becomes active,
--    renews, has a payment problem, or ends. They fire from entitlement
--    changes, which only verified store data can make, so nothing claims a
--    payment before the store has confirmed it. The store itself sends the
--    receipt for every charge; these messages do not replace it.

-- ---------------------------------------------------------------------------
-- 0. Store events could never be processed.
--
-- DB-020 attached its updated_at trigger to public.store_events, which was
-- created without an updated_at column, so every UPDATE of the table raised
-- 'record "new" has no field "updated_at"'. The dispatcher's claim, the
-- finish, the retry and the dead-letter are all updates: webhook events
-- were recorded and then never processed, so no renewal, cancellation or
-- refund reached the ledger. The column the trigger expects is added.
-- ---------------------------------------------------------------------------
alter table public.store_events
  add column if not exists updated_at timestamptz not null default now();

-- ---------------------------------------------------------------------------
-- 1. Columns.
-- ---------------------------------------------------------------------------
alter table public.store_transactions
  add column if not exists renewal_status text
    check (renewal_status in ('renewing', 'cancelled', 'paused', 'payment_issue')),
  -- When the reconciliation sweep last re-verified this row, so a lapsed
  -- row is re-read hourly rather than on every poll.
  add column if not exists reconciled_at timestamptz;

create index if not exists subscription_lifecycle_lapsed_idx
  on public.store_transactions (effective_until)
  where state in ('active', 'grace_period', 'on_hold');

-- ---------------------------------------------------------------------------
-- 2. Client submit and restore record the renewal status too.
--
-- billing_apply_verification is unchanged; the wrappers set the status on
-- the row it just wrote, which the caller's own verified payload names.
-- ---------------------------------------------------------------------------
create or replace function private.billing_set_renewal_status(p_body jsonb, p_result jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
begin
  if p_result->>'outcome' = 'ok' and nullif(p_body->>'renewalStatus', '') is not null then
    update public.store_transactions st
      set renewal_status = p_body->>'renewalStatus'
      where st.platform = (p_body->>'platform')::public.store_platform
        and st.environment = p_body->>'environment'
        and st.transaction_id = p_body->>'transactionId'
        and st.purchaser_id = auth.uid()
        and st.renewal_status is distinct from p_body->>'renewalStatus';
  end if;
  return p_result;
end;
$$;

create or replace function private.billing_submit_verification(p_body jsonb)
returns jsonb language sql security definer set search_path = '' as $$
  select private.billing_set_renewal_status(
    p_body, private.billing_apply_verification(p_body, false));
$$;

create or replace function private.billing_restore(p_body jsonb)
returns jsonb language sql security definer set search_path = '' as $$
  select private.billing_set_renewal_status(
    p_body, private.billing_apply_verification(p_body, true));
$$;

-- ---------------------------------------------------------------------------
-- 3. Finding and extending the transaction a store event is about.
--
-- Shared by the webhook finish and the reconciliation sweep.
-- ---------------------------------------------------------------------------
create or replace function private.billing_event_transaction(
  p_body jsonb,
  p_signed_data_hash text
)
returns public.store_transactions
language plpgsql security definer set search_path = '' as $$
declare
  v_platform public.store_platform := (p_body->>'platform')::public.store_platform;
  v_environment text := p_body->>'environment';
  v_transaction text := nullif(p_body->>'transactionId', '');
  lineage public.store_transactions%rowtype;
  event_product public.store_products%rowtype;
  created public.store_transactions%rowtype;
begin
  select * into lineage from public.store_transactions st
  where st.platform = v_platform and st.environment = v_environment
    and st.original_transaction_id = p_body->>'originalTransactionId'
  order by (st.transaction_id = v_transaction) desc nulls last, st.created_at desc
  limit 1
  for update;
  if lineage.id is null or v_transaction is null
     or lineage.transaction_id = v_transaction then
    return lineage;
  end if;

  if nullif(p_body->>'storeProductId', '') is not null then
    select * into event_product from public.store_products sp
    where sp.platform = v_platform and sp.environment = v_environment
      and sp.store_product_id = p_body->>'storeProductId';
  end if;

  -- Apple renews under a new transaction id every period; only a change of
  -- product (a plan change) is a new row there. On Google Play a token the
  -- ledger has not seen is always a new purchase: a replacement, an upgrade
  -- or a resubscribe, each linked to this lineage by the store.
  if v_platform = 'app_store'
     and (event_product.id is null or event_product.id = lineage.product_id) then
    return lineage;
  end if;

  insert into public.store_transactions(
    platform, environment, purchaser_id, product_id, beneficiary_id,
    guardian_link_id, parental_gate_confirmed_at, purchase_approval_id,
    original_transaction_id, transaction_id, signed_data_hash,
    state, purchased_at, effective_until
  ) values (
    lineage.platform, lineage.environment, lineage.purchaser_id,
    coalesce(event_product.id, lineage.product_id), lineage.beneficiary_id,
    lineage.guardian_link_id, lineage.parental_gate_confirmed_at,
    lineage.purchase_approval_id, lineage.original_transaction_id, v_transaction,
    p_signed_data_hash, (p_body->>'state')::public.store_transaction_state,
    coalesce((p_body->>'purchasedAt')::timestamptz, now()),
    nullif(p_body->>'effectiveUntil', '')::timestamptz
  )
  on conflict (platform, environment, transaction_id) do nothing
  returning * into created;
  if created.id is null then
    select * into created from public.store_transactions st
    where st.platform = v_platform and st.environment = v_environment
      and st.transaction_id = v_transaction
    for update;
  end if;
  return created;
end;
$$;

create or replace function private.billing_apply_event_state(
  p_row public.store_transactions,
  p_body jsonb
)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  product_row public.store_products%rowtype;
  v_effective_until timestamptz := nullif(p_body->>'effectiveUntil', '')::timestamptz;
  txn_state public.store_transaction_state := (p_body->>'state')::public.store_transaction_state;
  ack boolean := coalesce((p_body->>'acknowledged')::boolean, false);
  v_renewal text := nullif(p_body->>'renewalStatus', '');
begin
  select * into product_row from public.store_products where id = p_row.product_id;

  -- The store's current product for this lineage is another one: this row's
  -- plan was replaced (an Apple plan change), so it stops granting access at
  -- the end of what was already paid for, and never renews again.
  if p_row.platform = 'app_store'
     and nullif(p_body->>'storeProductId', '') is not null
     and p_body->>'storeProductId' <> product_row.store_product_id then
    txn_state := case
      when p_row.effective_until is not null and p_row.effective_until > now()
        then p_row.state else 'expired' end;
    v_effective_until := p_row.effective_until;
    v_renewal := 'cancelled';
  end if;

  update public.store_transactions
    set state = txn_state,
        effective_until = v_effective_until,
        acknowledged_at = case when ack then coalesce(acknowledged_at, now()) else acknowledged_at end,
        renewal_status = coalesce(v_renewal, renewal_status),
        reconciled_at = now()
    where id = p_row.id;

  return private.billing_derive_entitlement(
    p_row.beneficiary_id, product_row.feature_key, p_row.platform, p_row.id,
    p_row.original_transaction_id, txn_state,
    coalesce((p_body->>'purchasedAt')::timestamptz, p_row.purchased_at),
    v_effective_until
  );
end;
$$;

create or replace function private.billing_finish_event(
  p_event_id bigint,
  p_body jsonb
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  row_state public.store_events%rowtype;
  existing public.store_transactions%rowtype;
  noop boolean := coalesce((p_body->>'noop')::boolean, false);
begin
  select * into row_state from public.store_events where id = p_event_id for update;
  if row_state.state = 'completed' then return 'completed'; end if;
  if row_state.state = 'dead_letter' then return 'terminal'; end if;
  if row_state.id is null or row_state.state <> 'processing' then return 'lost'; end if;

  -- Ignorable notification (no transaction, no ledger effect): complete the
  -- event so the provider does not keep redelivering, but record no change.
  if noop or p_body->>'originalTransactionId' is null then
    update public.store_events
      set state = 'completed', processed_at = now(), lease_token = null,
          lease_until = null, last_error_code = null
      where id = row_state.id;
    return 'completed';
  end if;

  existing := private.billing_event_transaction(p_body, row_state.payload_hash);

  if existing.id is null then
    update public.store_events
      set state = 'retry',
          next_attempt_at = now()
            + make_interval(secs => least(3600, 30 * (2 ^ least(attempt_count, 8))::integer)),
          last_error_code = 'ORIGINAL_TRANSACTION_UNKNOWN'
      where id = row_state.id;
    return 'retry';
  end if;

  perform private.billing_apply_event_state(existing, p_body);

  update public.store_events
    set state = 'completed', processed_at = now(), lease_token = null, lease_until = null,
        last_error_code = null
    where id = row_state.id;

  return 'completed';
end;
$$;

-- The sweep re-verifies one row by id. A Google row is verified by its own
-- token, so it is always the row the answer is about. An Apple status
-- lookup answers for the whole lineage: if it names another product, this
-- row's plan was replaced (billing_apply_event_state), and a transaction the
-- ledger has not seen is recorded as for a webhook.
create or replace function private.billing_reconcile_transaction(
  p_transaction_id uuid,
  p_body jsonb
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  existing public.store_transactions%rowtype;
  applied jsonb;
begin
  select * into existing from public.store_transactions where id = p_transaction_id for update;
  if existing.id is null then return 'lost'; end if;

  applied := private.billing_apply_event_state(existing, p_body);
  return applied->>'outcome';
end;
$$;

create or replace function private.billing_reconciliation_scan(
  p_limit integer default 100
)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(jsonb_agg(jsonb_build_object(
      'transactionId', t.id, 'platform', t.platform, 'environment', t.environment,
      'storeTransactionId', t.transaction_id, 'originalTransactionId', t.original_transaction_id,
      'state', t.state, 'acknowledgedAt', t.acknowledged_at, 'purchasedAt', t.purchased_at
    ) order by t.purchased_at), '[]'::jsonb)
  from (
    select * from public.store_transactions
    where (
        platform = 'play_store' and acknowledged_at is null
        and purchased_at > now() - interval '3 days'
      )
      or state = 'pending'
      -- Access ended without a renewal, expiry or refund event reaching us.
      or (
        state in ('active', 'grace_period', 'on_hold')
        and effective_until < now()
        and effective_until > now() - interval '30 days'
        and (reconciled_at is null or reconciled_at < now() - interval '1 hour')
      )
    order by purchased_at
    limit p_limit
  ) t;
$$;

-- ---------------------------------------------------------------------------
-- 4. What the app reads: renewal status and where to manage it.
-- ---------------------------------------------------------------------------
create or replace function private.billing_list_entitlements(p_environment text)
returns jsonb language sql stable security definer set search_path = '' as $$
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
      ) as row_json, e.feature_key as sort_feature, '' as sort_student
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
  ) visible
  where private.is_active_user();
$$;

-- ---------------------------------------------------------------------------
-- 5. Subscription notifications, to the person who pays.
--
-- In-app always; push and email by the recipient's "billing" preferences
-- (push on by default, email off). The payload carries the plan and the
-- access date, never an amount, a store id or a receipt.
-- ---------------------------------------------------------------------------
create or replace function private.billing_notify_entitlement_change()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  kind text;
  payer uuid;
  school uuid;
begin
  if new.feature_key not in ('studafy_plus', 'studafy_max', 'parent_insights') then
    return null;
  end if;

  kind := case
    when new.status = 'active' and (tg_op = 'INSERT'
        or old.status not in ('active', 'grace_period'))
      then 'billing.subscription_active'
    when tg_op = 'UPDATE' and new.status = 'active' and old.status = 'active'
        and new.ends_at > coalesce(old.ends_at, '-infinity'::timestamptz) + interval '1 day'
      then 'billing.subscription_renewed'
    when tg_op = 'UPDATE' and new.status in ('grace_period', 'on_hold')
        and old.status = 'active'
      then 'billing.payment_problem'
    when tg_op = 'UPDATE' and new.status in ('expired', 'revoked')
        and old.status in ('active', 'grace_period', 'on_hold')
      then 'billing.subscription_ended'
  end;
  if kind is null then return null; end if;

  select st.purchaser_id into payer from public.store_transactions st
  where st.id = new.source_transaction_id;
  if payer is null then return null; end if;

  -- Notifications are held per school. The beneficiary's school first (a
  -- guardian's purchase is for a child's), then any school of the payer's.
  select s.school_id into school from public.students s
  where s.user_id = new.user_id and s.deleted_at is null
  order by s.created_at limit 1;
  if school is null then
    select m.school_id into school from public.memberships m
    where m.user_id = payer and m.active
    order by m.created_at limit 1;
  end if;
  if school is null then return null; end if;

  perform private.notify_recipient(
    school, payer, kind,
    jsonb_build_object('featureKey', new.feature_key, 'endsAt', new.ends_at),
    'entitlement:' || new.id,
    kind || ':' || new.id || ':' || new.version
  );
  return null;
end;
$$;

drop trigger if exists subscription_lifecycle_notify on public.entitlements;
create trigger subscription_lifecycle_notify
after insert or update of status, ends_at on public.entitlements
for each row execute function private.billing_notify_entitlement_change();

-- ---------------------------------------------------------------------------
-- Ownership and grants. Nothing here is callable by clients directly.
-- ---------------------------------------------------------------------------
alter function private.billing_set_renewal_status(jsonb, jsonb) owner to postgres;
alter function private.billing_submit_verification(jsonb) owner to postgres;
alter function private.billing_restore(jsonb) owner to postgres;
alter function private.billing_event_transaction(jsonb, text) owner to postgres;
alter function private.billing_apply_event_state(public.store_transactions, jsonb) owner to postgres;
alter function private.billing_finish_event(bigint, jsonb) owner to postgres;
alter function private.billing_reconcile_transaction(uuid, jsonb) owner to postgres;
alter function private.billing_reconciliation_scan(integer) owner to postgres;
alter function private.billing_list_entitlements(text) owner to postgres;
alter function private.billing_notify_entitlement_change() owner to postgres;

revoke all on function private.billing_set_renewal_status(jsonb, jsonb),
  private.billing_event_transaction(jsonb, text),
  private.billing_apply_event_state(public.store_transactions, jsonb),
  private.billing_notify_entitlement_change()
from public, anon, authenticated, service_role, studafy_api_runtime, studafy_worker_runtime;
