-- Google Play voided purchases (refunds, chargebacks, revocations).
--
-- A Play `voidedPurchaseNotification` carries only the purchase token, the
-- order id, the product type and the refund type. Until now the worker
-- treated it as a malformed subscription notification, so it retried and
-- was dead-lettered, and a refunded purchase kept its access.
--
-- The worker now sends `billing_finish_event` a body with `voided: true`,
-- the purchase token as `transactionId` and the state (`refunded` for a full
-- refund, otherwise `revoked`). This migration:
--
--   1. looks the transaction up by that token (the token is the Play
--      transaction id in the ledger) and ends the access it granted the
--      same way a refund or revocation does: the transaction's state moves
--      (audited in store_transaction_history by pay071_record_ledger_change),
--      and the entitlement it is the source of becomes `revoked` (the payer
--      is told by subscription_lifecycle_notify). A token the ledger has not
--      seen waits and retries like any event whose transaction is unknown.
--   2. makes a refund or revocation final for that transaction. Google sends
--      both SUBSCRIPTION_REVOKED and a voided purchase for one refund, and
--      either may come first. A second revocation, or a later expiry, of a
--      refunded/revoked transaction changes nothing: before this, it found
--      no live entitlement and inserted a second, ended one.

-- ---------------------------------------------------------------------------
-- 2. A refund or revocation is final for its transaction.
-- ---------------------------------------------------------------------------
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
  -- Already refunded or revoked: another end-of-access event for the same
  -- transaction is a duplicate. Only a store acknowledgement is recorded, so
  -- the acknowledgement sweep stops picking the row up.
  if p_row.state in ('refunded', 'revoked')
     and txn_state in ('expired', 'refunded', 'revoked') then
    update public.store_transactions
      set acknowledged_at = case when ack then coalesce(acknowledged_at, now()) else acknowledged_at end,
          reconciled_at = now()
      where id = p_row.id;
    return jsonb_build_object('outcome', 'unchanged');
  end if;

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

-- ---------------------------------------------------------------------------
-- 1. A voided purchase, found by its token.
-- ---------------------------------------------------------------------------
create or replace function private.billing_void_transaction(
  p_row public.store_transactions,
  p_state public.store_transaction_state
)
returns text
language plpgsql security definer set search_path = '' as $$
begin
  if p_row.state in ('refunded', 'revoked') then
    -- Already ended by the other notification for the same refund.
    return 'unchanged';
  end if;

  if p_row.state in ('pending', 'active', 'grace_period', 'on_hold')
     and exists (
       select 1 from public.entitlements e
       where e.source_transaction_id = p_row.id
         and e.status in ('pending', 'active', 'grace_period', 'on_hold'))
  then
    -- This purchase is what grants the access: end it, exactly as a refund
    -- or revocation event does.
    perform private.billing_apply_event_state(p_row, jsonb_build_object(
      'platform', p_row.platform, 'environment', p_row.environment,
      'originalTransactionId', p_row.original_transaction_id,
      'transactionId', p_row.transaction_id,
      'state', p_state, 'effectiveUntil', p_row.effective_until));
    return 'revoked';
  end if;

  -- The access already ended, or comes from another purchase (a newer token
  -- in the lineage, or a purchase that was collapsed into an earlier one):
  -- record the void on this transaction only.
  update public.store_transactions
    set state = p_state, reconciled_at = now()
    where id = p_row.id;
  return 'recorded';
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
  voided boolean := coalesce((p_body->>'voided')::boolean, false);
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

alter function private.billing_apply_event_state(public.store_transactions, jsonb) owner to postgres;
alter function private.billing_void_transaction(public.store_transactions, public.store_transaction_state) owner to postgres;
alter function private.billing_finish_event(bigint, jsonb) owner to postgres;

revoke all on function private.billing_apply_event_state(public.store_transactions, jsonb),
  private.billing_void_transaction(public.store_transactions, public.store_transaction_state)
from public, anon, authenticated, service_role, studafy_api_runtime, studafy_worker_runtime;
revoke all on function private.billing_finish_event(bigint, jsonb)
from public, anon, authenticated, service_role, studafy_api_runtime;
grant execute on function private.billing_finish_event(bigint, jsonb) to studafy_worker_runtime;
