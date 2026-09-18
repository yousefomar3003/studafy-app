-- PAY-071: store billing and entitlement lifecycle schema. ADR-0009 requires
-- purchaser and beneficiary to be recorded separately, a per-school switch
-- for student self-purchase (default off), and a parental gate confirmation
-- before any student-initiated purchase completes. `store_products`,
-- `store_transactions`, `store_events` and `entitlements` already exist from
-- DB-020; this migration adds the columns/tables the beneficiary model and
-- the worker-driven webhook dispatch need. No production data exists yet, so
-- new NOT NULL columns are added directly rather than staged through a
-- backfill migration.

alter table public.store_transactions
  -- The beneficiary is a profile: the purchasing teacher for Teacher AI
  -- grading, or a student (self or guardian-linked) for the other three
  -- products. `entitlements.user_id` is derived from this column.
  add column beneficiary_id uuid not null references public.profiles(id) on delete restrict,
  -- Set only when a guardian purchased for a linked child, so the ledger
  -- records which verified link authorized the purchase.
  add column guardian_link_id uuid references public.guardian_links(id) on delete restrict,
  -- Set only when the purchaser is the beneficiary's own student account and
  -- ADR-0009's parental gate was presented and confirmed before submission.
  add column parental_gate_confirmed_at timestamptz,
  -- Google's 3-day auto-refund window: when the worker acknowledged the
  -- purchase with the Play Developer API. Null means "not yet acknowledged",
  -- which the reconciliation sweep watches.
  add column acknowledged_at timestamptz;

alter table public.store_products
  -- Catalogue listing is the gate for what `/v1/billing/catalogue` returns.
  -- Two AI products (blocked on AI-072) and Parent Insights (blocked on
  -- legal sign-off, §29) stay unlisted in every non-synthetic environment
  -- even though their ledger/derivation code paths are fully built.
  add column storefront_listed boolean not null default false;

-- Worker dispatch columns for store_events, mirroring OPS-061's additions to
-- notification_outbox exactly: a webhook route durably records the event and
-- acks the provider; a BullMQ-backed dispatcher claims/leases/enqueues from
-- this table so provider availability never blocks the webhook response.
alter table public.store_events
  add column dispatched_at timestamptz,
  add column bullmq_job_id text,
  add column lease_token text,
  add column lease_until timestamptz,
  -- The provider's signed notification payload, needed by the worker to
  -- reverify authoritative state through the official API. Never logged
  -- (platform/logging.ts already redacts a "receipt" key; this column is
  -- read only by the billing repository/processor, never surfaced in an API
  -- response). Column-level envelope encryption is tracked as a follow-up in
  -- docs/evidence/pay-071/README.md rather than built in this pass.
  add column raw_payload text;

-- ADR-0009: a per-school switch for student self-purchase, default off. No
-- existing per-school flags table/column exists to extend; billing keeps its
-- settings isolated the way notification_outbox/support_access do.
create table public.school_billing_settings (
  school_id uuid primary key references public.schools(id) on delete cascade,
  self_purchase_enabled boolean not null default false,
  updated_at timestamptz not null default now()
);

do $pay071$
begin
  if not exists (
    select 1 from information_schema.triggers
    where event_object_schema = 'public'
      and event_object_table = 'school_billing_settings'
      and trigger_name = 'pay071_set_updated_at'
  ) then
    create trigger pay071_set_updated_at before update on public.school_billing_settings
      for each row execute function private.set_updated_at();
  end if;
end
$pay071$;

alter table public.school_billing_settings enable row level security;
revoke all on table public.school_billing_settings from anon, authenticated;
