-- PAY-071 worker-side dispatch. Mirrors OPS-061's outbox dispatcher exactly
-- (claim with FOR UPDATE SKIP LOCKED, lease, record/release/fail, idempotent
-- finish) so `store_events` gets the same crash-safe, at-least-once, but
-- effects-at-most-once processing the notification outbox already has.
--
-- The webhook route only durably records an event (private.billing_record_event,
-- granted to studafy_api_runtime) and acks the provider fast; everything from
-- here down runs on studafy_worker_runtime, decoupled from provider/Redis
-- availability at the moment the webhook arrived.

create or replace function private.billing_claim_events_for_dispatch(
  p_worker text,
  p_limit integer default 50
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare claimed jsonb;
begin
  if p_worker is null or length(p_worker) not between 1 and 100
     or p_limit is null or p_limit not between 1 and 200 then
    raise exception 'PAY071_INVALID_DISPATCH_CLAIM';
  end if;
  with candidates as (
    select e.id from public.store_events e
    where (
      (e.state in ('pending', 'retry') and e.next_attempt_at <= now())
      or (e.state = 'processing' and e.lease_until < now() - interval '10 minutes')
    )
    order by e.next_attempt_at, e.id
    for update skip locked limit p_limit
  ), updated as (
    update public.store_events e
      set state = 'processing',
          attempt_count = e.attempt_count + 1,
          lease_token = p_worker,
          lease_until = now() + interval '120 seconds',
          dispatched_at = coalesce(e.dispatched_at, now())
      from candidates c where e.id = c.id
      returning e.id, e.platform, e.environment, e.raw_payload, e.bullmq_job_id,
        e.attempt_count
  )
  select coalesce(jsonb_agg(jsonb_build_object(
      'eventId', u.id, 'platform', u.platform, 'environment', u.environment,
      'rawPayload', u.raw_payload, 'bullmqJobId', u.bullmq_job_id,
      'attempt', u.attempt_count) order by u.id), '[]'::jsonb)
  into claimed
  from updated u;
  return claimed;
end;
$$;

create or replace function private.billing_record_event_dispatched(
  p_worker text,
  p_event_id bigint,
  p_job_id text
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare row_state public.store_events%rowtype;
begin
  if p_worker is null or length(p_worker) not between 1 and 100
     or p_job_id is null or length(p_job_id) not between 1 and 120 then
    raise exception 'PAY071_INVALID_DISPATCH_RECORD';
  end if;
  select * into row_state from public.store_events
  where id = p_event_id and state = 'processing' and lease_token = p_worker
  for update;
  if row_state.id is null then return false; end if;
  update public.store_events
    set bullmq_job_id = left(p_job_id, 120),
        dispatched_at = coalesce(dispatched_at, now()),
        lease_until = now() + interval '120 seconds'
    where id = row_state.id;
  return true;
end;
$$;

create or replace function private.billing_release_event(
  p_worker text,
  p_event_id bigint,
  p_error_code text
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare row_state public.store_events%rowtype;
begin
  if p_worker is null or length(p_worker) not between 1 and 100
     or p_error_code is null or length(p_error_code) not between 1 and 80 then
    raise exception 'PAY071_INVALID_DISPATCH_RELEASE';
  end if;
  select * into row_state from public.store_events
  where id = p_event_id and state = 'processing' and lease_token = p_worker
  for update;
  if row_state.id is null then return false; end if;
  update public.store_events
    set state = 'retry',
        next_attempt_at = now()
          + make_interval(secs => least(3600, 5 * (2 ^ least(attempt_count, 9))::integer)),
        lease_token = null, lease_until = null, last_error_code = p_error_code
    where id = row_state.id;
  return true;
end;
$$;

create or replace function private.billing_fail_event(
  p_event_id bigint,
  p_error_code text
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare row_state public.store_events%rowtype;
begin
  if p_error_code is null or length(p_error_code) not between 1 and 80 then
    raise exception 'PAY071_INVALID_DISPATCH_FAIL';
  end if;
  select * into row_state from public.store_events
  where id = p_event_id and state = 'processing' for update;
  if row_state.id is null then return false; end if;
  update public.store_events
    set state = 'dead_letter', lease_token = null, lease_until = null,
        last_error_code = p_error_code
    where id = row_state.id;
  return true;
end;
$$;

-- BullMQ job payloads carry opaque identifiers only, matching OPS-061's
-- policy ("workers re-fetch and re-authorize current state") - the provider's
-- raw notification payload is Restricted per §15 and is never put in a
-- Redis-resident job payload. The processor fetches it fresh, scoped to an
-- event it is actively processing.
create or replace function private.billing_event_payload(
  p_event_id bigint
)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'platform', e.platform, 'environment', e.environment,
    'rawPayload', e.raw_payload
  )
  from public.store_events e
  where e.id = p_event_id and e.state = 'processing';
$$;

-- The webhook processor's finish: re-verify against the official API happens
-- in TypeScript before this call; `p_body` carries the resulting normalized
-- fields (same shape as billing_submit_verification's input). Only ever
-- updates a transaction this server already knows about (found by
-- original_transaction_id) - a webhook is never allowed to originate a new
-- transaction with an unknown purchaser/beneficiary. If the original
-- transaction is not yet on file (the webhook raced ahead of the client's
-- submit), the event is retried with backoff; the reconciliation sweep is
-- the backstop if it never resolves.
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
  effective_until timestamptz := nullif(p_body->>'effectiveUntil', '')::timestamptz;
  txn_state public.store_transaction_state := (p_body->>'state')::public.store_transaction_state;
  ack boolean := coalesce((p_body->>'acknowledged')::boolean, false);
begin
  select * into row_state from public.store_events where id = p_event_id for update;
  if row_state.state = 'completed' then return 'completed'; end if;
  if row_state.state = 'dead_letter' then return 'terminal'; end if;
  if row_state.id is null or row_state.state <> 'processing' then return 'lost'; end if;

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
        effective_until = effective_until,
        acknowledged_at = case when ack then coalesce(acknowledged_at, now()) else acknowledged_at end
    where id = existing.id;

  applied := private.billing_derive_entitlement(
    existing.beneficiary_id, product_row.feature_key, existing.platform, existing.id,
    p_body->>'originalTransactionId', txn_state, purchased_at, effective_until
  );

  update public.store_events
    set state = 'completed', processed_at = now(), lease_token = null, lease_until = null,
        last_error_code = null
    where id = row_state.id;

  return 'completed';
end;
$$;

-- Scheduled reconciliation candidates: pending transactions stuck without a
-- terminal state, and Google purchases still unacknowledged within the
-- 3-day auto-refund window.
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
      'originalTransactionId', t.original_transaction_id, 'state', t.state,
      'acknowledgedAt', t.acknowledged_at, 'purchasedAt', t.purchased_at
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

alter function private.billing_claim_events_for_dispatch(text, integer) owner to postgres;
alter function private.billing_record_event_dispatched(text, bigint, text) owner to postgres;
alter function private.billing_release_event(text, bigint, text) owner to postgres;
alter function private.billing_fail_event(bigint, text) owner to postgres;
alter function private.billing_finish_event(bigint, jsonb) owner to postgres;
alter function private.billing_reconciliation_scan(integer) owner to postgres;

revoke all on function private.billing_claim_events_for_dispatch(text, integer),
  private.billing_record_event_dispatched(text, bigint, text),
  private.billing_release_event(text, bigint, text),
  private.billing_fail_event(bigint, text),
  private.billing_finish_event(bigint, jsonb),
  private.billing_reconciliation_scan(integer)
  from public, anon, authenticated, service_role, studafy_api_runtime;

grant execute on function private.billing_claim_events_for_dispatch(text, integer),
  private.billing_record_event_dispatched(text, bigint, text),
  private.billing_release_event(text, bigint, text),
  private.billing_fail_event(bigint, text),
  private.billing_finish_event(bigint, jsonb),
  private.billing_reconciliation_scan(integer)
  to studafy_worker_runtime;
