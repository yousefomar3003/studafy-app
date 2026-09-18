-- PAY-071 constraints/indexes.
--
-- Duplicate active entitlement for one beneficiary is a hard backstop here
-- (a partial unique index), but derivation logic in private.billing_* checks
-- first and collapses the older entitlement rather than relying on this
-- constraint to fail loudly in the ordinary path.
create unique index pay071_entitlements_one_active_per_feature
  on public.entitlements (user_id, feature_key)
  where status in ('active', 'grace_period', 'on_hold');

create index pay071_store_transactions_beneficiary_idx
  on public.store_transactions (beneficiary_id);

create index pay071_store_transactions_purchaser_idx
  on public.store_transactions (purchaser_id);

-- Not-yet-acknowledged Google purchases: the reconciliation sweep's primary
-- query. Google auto-refunds anything unacknowledged after 3 days.
create index pay071_store_transactions_unacknowledged_idx
  on public.store_transactions (purchased_at)
  where platform = 'play_store' and acknowledged_at is null;

-- Durable webhook dedupe. Apple's notificationUUID and Google's Pub/Sub
-- messageId are both stable per delivery; a provider that redelivers the
-- same event must hit this constraint, not a second row.
create unique index pay071_store_events_external_id_idx
  on public.store_events (platform, environment, external_event_id)
  where external_event_id is not null;

-- Dispatch claim query, mirroring OPS-061's notification_outbox partial
-- index exactly: only pending/retry rows due now, or stale processing rows,
-- are ever scanned.
create index pay071_store_events_dispatch_idx
  on public.store_events (next_attempt_at, id)
  where state in ('pending', 'retry');
