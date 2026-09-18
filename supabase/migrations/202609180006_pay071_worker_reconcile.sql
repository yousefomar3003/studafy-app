-- PAY-071 worker reconciliation patches. Three gaps surfaced while wiring
-- apps/worker/src/billing:
--
-- 1. `private.billing_event_payload` was left out of the original worker
--    grant: the processor re-fetches the raw notification payload through it
--    (scoped to a `processing` event), so the worker role must be able to
--    call it.
-- 2. `private.billing_finish_event` assumed every notification ends in a
--    ledger change. Provider notifications that carry no transaction and no
--    state (e.g. Apple CONSUMPTION_REQUEST, Google test notifications) must
--    be able to complete the event without touching `store_transactions`,
--    otherwise they retry into the dead letter. A `noop` marker in the body
--    short-circuits to a completed event.
-- 3. `private.billing_reconciliation_scan` returned the DB transaction uuid
--    but not the store purchase token / `transaction_id`, which is exactly
--    what a Google acknowledgement needs. Added
--    `'storeTransactionId', t.transaction_id` (the current Play purchase
--    token; for Apple it is the latest signed transaction id) and a new
--    `private.billing_reconcile_transaction` that the scheduled sweep calls
--    to re-verify a stuck/unacknowledged transaction and derive the
--    entitlement without a webhook event row.
--
-- Also fixes a latent ambiguity in the 202609180004 `billing_finish_event`:
-- `effective_until = effective_until` in the UPDATE SET list resolves
-- ambiguously between the column and the PL/pgSQL variable (Postgres raises
-- "column reference is ambiguous" at first call). The variable is renamed to
-- `v_effective_until` here; since this migration redefines the function, the
-- fix applies to the deployed definition.

grant execute on function private.billing_event_payload(bigint) to studafy_worker_runtime;

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
  product_row public.store_products%rowtype;
  applied jsonb;
  purchased_at timestamptz := (p_body->>'purchasedAt')::timestamptz;
  v_effective_until timestamptz := nullif(p_body->>'effectiveUntil', '')::timestamptz;
  txn_state public.store_transaction_state := (p_body->>'state')::public.store_transaction_state;
  ack boolean := coalesce((p_body->>'acknowledged')::boolean, false);
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

  select * into existing from public.store_transactions
  where platform = (p_body->>'platform')::public.store_platform
    and environment = p_body->>'environment'
    and original_transaction_id = p_body->>'originalTransactionId'
  order by created_at desc
  limit 1
  for update;

  if existing.id is null then
    update public.store_events
      set state = 'retry',
          next_attempt_at = now()
            + make_interval(secs => least(3600, 30 * (2 ^ least(attempt_count, 8))::integer)),
          last_error_code = 'ORIGINAL_TRANSACTION_UNKNOWN'
      where id = row_state.id;
    return 'retry';
  end if;

  select * into product_row from public.store_products where id = existing.product_id;

  update public.store_transactions
    set state = txn_state,
        effective_until = v_effective_until,
        acknowledged_at = case when ack then coalesce(acknowledged_at, now()) else acknowledged_at end
    where id = existing.id;

  applied := private.billing_derive_entitlement(
    existing.beneficiary_id, product_row.feature_key, existing.platform, existing.id,
    p_body->>'originalTransactionId', txn_state, purchased_at, v_effective_until
  );

  update public.store_events
    set state = 'completed', processed_at = now(), lease_token = null, lease_until = null,
        last_error_code = null
    where id = row_state.id;

  return 'completed';
end;
$$;

-- Reconciliation sweep finish for a *transaction* not tied to a webhook
-- event: re-verify authoritative state and derive entitlements exactly like
-- billing_finish_event, minus the store_events transition. Callers must own
-- the verification (worker runtime); this function never invents a
-- purchaser/beneficiary, it only refreshes an existing row.
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
  product_row public.store_products%rowtype;
  applied jsonb;
  purchased_at timestamptz := (p_body->>'purchasedAt')::timestamptz;
  v_effective_until timestamptz := nullif(p_body->>'effectiveUntil', '')::timestamptz;
  txn_state public.store_transaction_state := (p_body->>'state')::public.store_transaction_state;
  ack boolean := coalesce((p_body->>'acknowledged')::boolean, false);
begin
  select * into existing from public.store_transactions where id = p_transaction_id for update;
  if existing.id is null then return 'lost'; end if;

  select * into product_row from public.store_products where id = existing.product_id;

  update public.store_transactions
    set state = txn_state,
        effective_until = v_effective_until,
        acknowledged_at = case when ack then coalesce(acknowledged_at, now()) else acknowledged_at end
    where id = existing.id;

  applied := private.billing_derive_entitlement(
    existing.beneficiary_id, product_row.feature_key, existing.platform, existing.id,
    p_body->>'originalTransactionId', txn_state, purchased_at, v_effective_until
  );

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
    order by purchased_at
    limit p_limit
  ) t;
$$;

alter function private.billing_reconcile_transaction(uuid, jsonb) owner to postgres;
alter function private.billing_event_payload(bigint) owner to postgres;

revoke all on function private.billing_reconcile_transaction(uuid, jsonb) from public, anon, authenticated, service_role, studafy_api_runtime;
grant execute on function private.billing_reconcile_transaction(uuid, jsonb) to studafy_worker_runtime;