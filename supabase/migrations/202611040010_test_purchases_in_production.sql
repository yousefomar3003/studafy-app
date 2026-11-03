-- Production takes App Review, TestFlight and license-tester purchases, and
-- records them as test purchases (DL-080, owner decision 2026-11-03).
--
-- App Review, TestFlight testers and sandbox testers always buy in Apple's
-- Sandbox, and Google Play license testers always make test purchases, even
-- with the production build against the production server. Until now the
-- production API refused both, so a reviewer's purchase failed (a rejection
-- risk) and TestFlight could not buy at all. Apple's own guidance is to
-- verify in production and, for Sandbox data, verify it against the Sandbox
-- and accept it. The API and worker now do that (a second, Sandbox verifier
-- on production servers only); this migration records which purchases they
-- were.
--
--   1. public.store_transactions.sandbox: true for a purchase made in the
--      store's test environment. It is set by the verified store data, never
--      by the client, and never changes. `environment` stays the server's
--      environment, so a test purchase on production grants the plan there
--      exactly like a real one (that is the point: reviewers must see the
--      plan work), and every plan check that compares
--      `environment = notebook_runtime.environment` is unchanged.
--      Development, staging and synthetic servers only ever took test
--      purchases, so their existing rows are marked as such.
--   2. A test purchase never joins a real purchase's lineage, or the
--      reverse. Apple's original transaction ids differ between its
--      environments anyway; this is the guard if they ever did not. Client
--      submit and restore answer `store_environment_mismatch`; a store event
--      is dead-lettered with STORE_ENVIRONMENT_MISMATCH; the reconciliation
--      sweep leaves the row as it is. The checks that a lineage belongs to
--      the caller (`owned_by_other_account`) come first, unchanged.
--   3. A store event that records a new transaction in a lineage (a Google
--      replacement token, an Apple plan change) copies the lineage's flag.
--   4. The reconciliation sweep reports the flag, so the worker re-reads an
--      Apple test purchase from the Sandbox App Store Server API.
--
-- Nothing in the codebase reports revenue or subscriber counts today; any
-- such report must leave out (or show separately) rows with sandbox = true.

-- ---------------------------------------------------------------------------
-- 1. The column.
-- ---------------------------------------------------------------------------
alter table public.store_transactions
  add column if not exists sandbox boolean not null default false;

comment on column public.store_transactions.sandbox is
  'DL-080: bought in the store''s test environment (Apple Sandbox: App Review, TestFlight, sandbox testers; a Google Play license tester). Grants access like any purchase in this server''s environment; set from verified store data only, never changes, and never shares a lineage with a real purchase. Leave these rows out of revenue and subscriber counts.';

-- Servers other than production never took a real purchase.
update public.store_transactions
  set sandbox = true
  where environment <> 'production' and not sandbox;

-- The flag is part of the record, like the environment itself.
drop trigger pay071_immutable_ledger_columns on public.store_transactions;
create trigger pay071_immutable_ledger_columns
before update on public.store_transactions
for each row execute function private.reject_immutable_columns(
  'id', 'platform', 'environment', 'purchaser_id', 'product_id',
  'original_transaction_id', 'transaction_id', 'signed_data_hash',
  'purchased_at', 'created_at', 'beneficiary_id', 'guardian_link_id',
  'parental_gate_confirmed_at', 'purchase_approval_id', 'sandbox'
);

-- ---------------------------------------------------------------------------
-- 2. Client submit and restore (re-issued from 202610210010 with the flag).
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
  v_sandbox boolean := coalesce((p_body->>'sandbox')::boolean, false);
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
  -- DL-080: a test purchase never extends a real purchase's lineage, or
  -- the reverse.
  if lineage.id is not null and lineage.sandbox <> v_sandbox then
    return jsonb_build_object('outcome', 'store_environment_mismatch');
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
    if existing.sandbox <> v_sandbox then
      return jsonb_build_object('outcome', 'store_environment_mismatch');
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
      state, purchased_at, effective_until, sandbox
    ) values (
      product_row.platform, p_body->>'environment', purchaser, product_row.id,
      beneficiary, guardian_link,
      lineage.parental_gate_confirmed_at,
      lineage.purchase_approval_id,
      p_body->>'originalTransactionId', p_body->>'transactionId', p_body->>'signedDataHash',
      txn_state, purchased_at, resolved_effective_until, v_sandbox
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
-- 3. A new transaction found by a store event inherits its lineage's flag
--    (re-issued from 202609290004).
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
    state, purchased_at, effective_until, sandbox
  ) values (
    lineage.platform, lineage.environment, lineage.purchaser_id,
    coalesce(event_product.id, lineage.product_id), lineage.beneficiary_id,
    lineage.guardian_link_id, lineage.parental_gate_confirmed_at,
    lineage.purchase_approval_id, lineage.original_transaction_id, v_transaction,
    p_signed_data_hash, (p_body->>'state')::public.store_transaction_state,
    coalesce((p_body->>'purchasedAt')::timestamptz, now()),
    nullif(p_body->>'effectiveUntil', '')::timestamptz,
    lineage.sandbox
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

-- ---------------------------------------------------------------------------
-- 4. A store event for the other environment's lineage is dead-lettered
--    (re-issued from 202610150090). A Google voided purchase names only its
--    token, carries no flag, and can only end access, so it is matched by
--    the token as before.
-- ---------------------------------------------------------------------------
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
  voided boolean := coalesce((p_body->>'voided')::boolean, false);
  v_sandbox boolean := coalesce((p_body->>'sandbox')::boolean, false);
begin
  select * into row_state from public.store_events where id = p_event_id for update;
  if row_state.state = 'completed' then return 'completed'; end if;
  if row_state.state = 'dead_letter' then return 'terminal'; end if;
  if row_state.id is null or row_state.state <> 'processing' then return 'lost'; end if;

  if voided and not noop then
    if nullif(p_body->>'transactionId', '') is not null then
      select * into existing from public.store_transactions st
      where st.platform = (p_body->>'platform')::public.store_platform
        and st.environment = p_body->>'environment'
        and st.transaction_id = p_body->>'transactionId'
      for update;
    end if;
  elsif noop or p_body->>'originalTransactionId' is null then
    -- Ignorable notification (no transaction, no ledger effect): complete
    -- the event so the provider does not keep redelivering, but record no
    -- change.
    update public.store_events
      set state = 'completed', processed_at = now(), lease_token = null,
          lease_until = null, last_error_code = null
      where id = row_state.id;
    return 'completed';
  elsif exists (
    select 1 from public.store_transactions st
    where st.platform = (p_body->>'platform')::public.store_platform
      and st.environment = p_body->>'environment'
      and st.original_transaction_id = p_body->>'originalTransactionId'
      and st.sandbox <> v_sandbox
  ) then
    -- DL-080: a test purchase's event never moves a real purchase's
    -- lineage, or the reverse. Retrying cannot change that.
    update public.store_events
      set state = 'dead_letter', lease_token = null, lease_until = null,
          last_error_code = 'STORE_ENVIRONMENT_MISMATCH'
      where id = row_state.id;
    return 'terminal';
  else
    existing := private.billing_event_transaction(p_body, row_state.payload_hash);
  end if;

  if existing.id is null then
    update public.store_events
      set state = 'retry',
          next_attempt_at = now()
            + make_interval(secs => least(3600, 30 * (2 ^ least(attempt_count, 8))::integer)),
          last_error_code = 'ORIGINAL_TRANSACTION_UNKNOWN'
      where id = row_state.id;
    return 'retry';
  end if;

  if voided then
    perform private.billing_void_transaction(existing,
      case p_body->>'state' when 'refunded' then 'refunded' else 'revoked' end
        ::public.store_transaction_state);
  else
    perform private.billing_apply_event_state(existing, p_body);
  end if;

  update public.store_events
    set state = 'completed', processed_at = now(), lease_token = null, lease_until = null,
        last_error_code = null
    where id = row_state.id;

  return 'completed';
end;
$$;

-- ---------------------------------------------------------------------------
-- 5. The reconciliation sweep (re-issued from 202609290004).
-- ---------------------------------------------------------------------------
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

  -- DL-080: the store answered for the other environment. The row is left
  -- as it is; only the time it was looked at moves, so a lapsed row is not
  -- re-read on every poll.
  if existing.sandbox <> coalesce((p_body->>'sandbox')::boolean, false) then
    update public.store_transactions set reconciled_at = now() where id = existing.id;
    return 'store_environment_mismatch';
  end if;

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
      'state', t.state, 'acknowledgedAt', t.acknowledged_at, 'purchasedAt', t.purchased_at,
      'sandbox', t.sandbox
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
-- Ownership and grants, as before: nothing here is callable by clients.
-- ---------------------------------------------------------------------------
alter function private.billing_apply_verification(jsonb, boolean) owner to postgres;
alter function private.billing_event_transaction(jsonb, text) owner to postgres;
alter function private.billing_finish_event(bigint, jsonb) owner to postgres;
alter function private.billing_reconcile_transaction(uuid, jsonb) owner to postgres;
alter function private.billing_reconciliation_scan(integer) owner to postgres;

revoke all on function private.billing_apply_verification(jsonb, boolean),
  private.billing_event_transaction(jsonb, text)
from public, anon, authenticated, service_role, studafy_api_runtime, studafy_worker_runtime;
revoke all on function private.billing_finish_event(bigint, jsonb),
  private.billing_reconcile_transaction(uuid, jsonb),
  private.billing_reconciliation_scan(integer)
from public, anon, authenticated, service_role, studafy_api_runtime;
grant execute on function private.billing_finish_event(bigint, jsonb),
  private.billing_reconcile_transaction(uuid, jsonb),
  private.billing_reconciliation_scan(integer)
to studafy_worker_runtime;
