-- Audit follow-up (2026-09-19): store_transactions carries DB-020's
-- db020_reject_mutation trigger, which refuses every UPDATE, yet PAY-071's
-- submit/restore, webhook completion (billing_finish_event) and
-- reconciliation (billing_reconcile_transaction) all move a transaction's
-- state, expiry and acknowledgement in place. Each of those paths therefore
-- raised and rolled back: a refund, revocation or expiry notification could
-- never revoke an entitlement, and a Google acknowledgement could never be
-- recorded, so reconciliation would retry it forever. No test ran these
-- functions against a real database.
--
-- The ledger stays append-only in the sense that matters. Identity,
-- ownership, beneficiary, product, amounts-of-record and hashes are pinned;
-- deletes are still refused; the acknowledgement time can only be set once.
-- Only the three lifecycle columns may move, and every change is written to
-- an append-only history table in the same transaction, so the full store
-- lifecycle remains reconstructable and tamper-evident.

create table public.store_transaction_history (
  id bigint generated always as identity primary key,
  store_transaction_id uuid not null
    references public.store_transactions(id) on delete restrict,
  previous_state public.store_transaction_state not null,
  new_state public.store_transaction_state not null,
  previous_effective_until timestamptz,
  new_effective_until timestamptz,
  acknowledged_at timestamptz,
  recorded_at timestamptz not null default now()
);
create index store_transaction_history_txn_idx
  on public.store_transaction_history(store_transaction_id, recorded_at);

alter table public.store_transaction_history enable row level security;
revoke all on public.store_transaction_history
  from public, anon, authenticated, service_role,
    studafy_api_runtime, studafy_worker_runtime;

create trigger db020_reject_mutation
before update or delete on public.store_transaction_history
for each row execute function private.reject_append_only_mutation();

drop trigger db020_reject_mutation on public.store_transactions;

create trigger pay071_reject_delete
before delete on public.store_transactions
for each row execute function private.reject_append_only_mutation();

create trigger pay071_immutable_ledger_columns
before update on public.store_transactions
for each row execute function private.reject_immutable_columns(
  'id', 'platform', 'environment', 'purchaser_id', 'product_id',
  'original_transaction_id', 'transaction_id', 'signed_data_hash',
  'purchased_at', 'created_at', 'beneficiary_id', 'guardian_link_id',
  'parental_gate_confirmed_at'
);

create or replace function private.billing_record_ledger_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if old.acknowledged_at is not null
     and new.acknowledged_at is distinct from old.acknowledged_at then
    raise exception using errcode = '22000',
      message = 'A store acknowledgement cannot be cleared or rewritten';
  end if;
  if new.state is distinct from old.state
     or new.effective_until is distinct from old.effective_until
     or new.acknowledged_at is distinct from old.acknowledged_at then
    insert into public.store_transaction_history(
      store_transaction_id, previous_state, new_state,
      previous_effective_until, new_effective_until, acknowledged_at
    ) values (
      old.id, old.state, new.state,
      old.effective_until, new.effective_until, new.acknowledged_at
    );
  end if;
  return new;
end;
$$;
alter function private.billing_record_ledger_change() owner to postgres;
revoke all on function private.billing_record_ledger_change()
  from public, anon, authenticated, service_role,
    studafy_api_runtime, studafy_worker_runtime;

create trigger pay071_record_ledger_change
before update on public.store_transactions
for each row execute function private.billing_record_ledger_change();
