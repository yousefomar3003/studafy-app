-- Two small observability fixes (no behaviour change for any row).
--
-- 1. Why a dispatcher could not record its BullMQ job id.
--
--    `api061_record_dispatched` and `billing_record_event_dispatched` answer
--    false whenever the row is no longer `processing` under the caller's
--    lease, and the worker logged every false as a lost lease
--    (`outbox_dispatch_record_lost`, warn). In practice it is nearly always a
--    benign race: the job runs as soon as `queue.add` returns, and the
--    processor finishes the row (completed, dead_letter, or billing's retry)
--    before the dispatcher records the id. The `_v2` functions below do the
--    same thing and say why:
--
--      'recorded'          the id is recorded and the lease extended;
--      'already_finished'  the row has already left `processing` (the job
--                          finished it, or it was handed back for a retry);
--      'lease_lost'        the row is `processing` under another
--                          dispatcher's lease, or is gone.
--
--    The return type changes, so these are new functions (ADR-0030: no
--    rename-and-wrap). The originals are left as they are for a worker still
--    running the previous release; they can be dropped once every worker
--    calls `_v2`. Same owner and grants: the worker runtime only.
--
-- 2. Inactive-account warnings that can never be emailed.
--
--    A person with no school is warned only by email (202610150091). If that
--    email fails for good (no address, a refused address, or eight failed
--    tries) the warning row stays with `emailed_at` null, the account is never
--    deleted, and nobody is told. `inactive_warning_email_undeliverable`
--    counts those rows so the retention worker can log the number and alert
--    the operator (docs/security/inactive-account-warnings-runbook.md).
--    Counts only.

create or replace function private.api061_record_dispatched_v2(
  p_worker text,
  p_outbox_id bigint,
  p_job_id text
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare row_state public.notification_outbox%rowtype;
begin
  if p_worker is null or length(p_worker) not between 1 and 100
     or p_job_id is null or length(p_job_id) not between 1 and 120 then
    raise exception 'OPS061_INVALID_DISPATCH_RECORD';
  end if;
  select * into row_state from public.notification_outbox
  where id = p_outbox_id
  for update;
  if row_state.id is null then return 'lease_lost'; end if;
  if row_state.state <> 'processing' then return 'already_finished'; end if;
  if row_state.lease_token is distinct from p_worker then return 'lease_lost'; end if;
  update public.notification_outbox
    set bullmq_job_id = left(p_job_id, 120),
        dispatched_at = coalesce(dispatched_at, now()),
        lease_until = now() + interval '120 seconds',
        updated_at = now()
  where id = row_state.id;
  return 'recorded';
end;
$$;

create or replace function private.billing_record_event_dispatched_v2(
  p_worker text,
  p_event_id bigint,
  p_job_id text
)
returns text
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
  where id = p_event_id
  for update;
  if row_state.id is null then return 'lease_lost'; end if;
  if row_state.state <> 'processing' then return 'already_finished'; end if;
  if row_state.lease_token is distinct from p_worker then return 'lease_lost'; end if;
  update public.store_events
    set bullmq_job_id = left(p_job_id, 120),
        dispatched_at = coalesce(dispatched_at, now()),
        lease_until = now() + interval '120 seconds'
    where id = row_state.id;
  return 'recorded';
end;
$$;

-- Warnings to someone with no school whose email has stopped for good, for
-- a person who still exists and has no deletion request. These accounts are
-- kept, not deleted, until an operator acts.
create or replace function private.inactive_warning_email_undeliverable()
returns integer language sql stable security definer set search_path = '' as $$
  select count(*)::integer from private.inactive_account_warnings iw
  where iw.notified_school_id is null
    and iw.emailed_at is null
    and iw.email_attempts >= 8
    and iw.deletion_request_id is null
    and exists (select 1 from public.profiles p
      where p.id = iw.user_id and p.deleted_at is null and p.status <> 'deleted');
$$;

alter function private.api061_record_dispatched_v2(text, bigint, text) owner to postgres;
alter function private.billing_record_event_dispatched_v2(text, bigint, text) owner to postgres;
alter function private.inactive_warning_email_undeliverable() owner to postgres;

revoke all on function private.api061_record_dispatched_v2(text, bigint, text),
  private.billing_record_event_dispatched_v2(text, bigint, text),
  private.inactive_warning_email_undeliverable()
  from public, anon, authenticated, service_role, studafy_api_runtime;

grant execute on function private.api061_record_dispatched_v2(text, bigint, text),
  private.billing_record_event_dispatched_v2(text, bigint, text),
  private.inactive_warning_email_undeliverable()
  to studafy_worker_runtime;
