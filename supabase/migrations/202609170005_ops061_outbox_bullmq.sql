-- OPS-061: BullMQ/outbox processing. The transactional outbox is the only
-- path from a command transaction to a side effect; this migration gives the
-- notification outbox the dispatch machinery a real queue drain needs:
--
--   dispatch columns (lease, BullMQ job id) on notification_outbox;
--   api061_* SECURITY DEFINER functions granted ONLY to studafy_worker_runtime
--   (the dispatcher claims rows FOR UPDATE SKIP LOCKED, records the queue job
--   id, and releases/reclaims safely; the processor finishes idempotently).
--
-- Audience rows (recipient_id null) were emitted by API-041/042/SAFE-043
-- commands and never expanded: without a worker they are audit/fan-out
-- records only (documented in api042_notifications.sql). The claim selects
-- exactly those rows; direct recipient_id rows are delivered inline by
-- notify_recipient and must never be double-sent.
--
-- Idempotency is enforced at the database invariant, not just the queue: the
-- expansion inserts deliveries ON CONFLICT DO NOTHING inside the same
-- transaction that completes the row, so a job that runs twice on any worker
-- (crash, failover, redrive) cannot double-apply.

alter table public.notification_outbox
  add column if not exists dispatched_at timestamptz,
  add column if not exists bullmq_job_id text,
  add column if not exists lease_token text,
  add column if not exists lease_until timestamptz;

-- Claim path: DB-020's `db020_notification_outbox_ready` partial index
-- ((next_attempt_at, id) where state in ('pending','retry')) already serves
-- the dispatcher's claim query, so no duplicate index is added here. A small
-- dedicated partial index keeps operator DLQ listing cheap at scale.
create index if not exists ops061_outbox_dlq_idx
  on public.notification_outbox(id)
  where recipient_id is null and audience is not null and state = 'dead_letter';

create or replace function private.api061_claim_outbox_dispatch(
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
    raise exception 'OPS061_INVALID_DISPATCH_CLAIM';
  end if;
  -- FOR UPDATE SKIP LOCKED so concurrent dispatchers never double-claim.
  -- Stale leases (a dispatcher died between claim and record) are reclaimable
  -- after a conservative window; re-claiming is safe because the BullMQ
  -- jobId is deterministic and the expansion is conflict-do-nothing.
  with candidates as (
    select j.id from public.notification_outbox j
    where j.recipient_id is null and j.audience is not null
      and j.channel = 'in_app'
      and (
        (j.state in ('pending', 'retry') and j.next_attempt_at <= now())
        or (j.state = 'processing' and j.lease_until < now() - interval '10 minutes')
      )
    order by j.next_attempt_at, j.id
    for update skip locked limit p_limit
  ), updated as (
    update public.notification_outbox j
      set state = 'processing',
          attempt_count = j.attempt_count + 1,
          lease_token = p_worker,
          lease_until = now() + interval '120 seconds',
          dispatched_at = coalesce(j.dispatched_at, now()),
          updated_at = now()
      from candidates c where j.id = c.id
      returning j.id, j.school_id, j.channel, j.template_key, j.audience,
                j.payload, j.bullmq_job_id, j.attempt_count
  )
  select coalesce(jsonb_agg(jsonb_build_object(
      'outboxId', u.id, 'schoolId', u.school_id, 'channel', u.channel,
      'templateKey', u.template_key, 'audience', u.audience,
      'payload', u.payload, 'bullmqJobId', u.bullmq_job_id,
      'attempt', u.attempt_count) order by u.id), '[]'::jsonb)
  into claimed
  from updated u;
  return claimed;
end;
$$;

-- The dispatcher records the deterministic BullMQ job id after a successful
-- enqueue and extends its lease. Crash before this call leaves the row
-- processing with the stale lease; the claim's stale branch recovers it.
create or replace function private.api061_record_dispatched(
  p_worker text,
  p_outbox_id bigint,
  p_job_id text
)
returns boolean
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
  where id = p_outbox_id and state = 'processing' and lease_token = p_worker
  for update;
  if row_state.id is null then return false; end if;
  update public.notification_outbox
    set bullmq_job_id = left(p_job_id, 120),
        dispatched_at = coalesce(dispatched_at, now()),
        lease_until = now() + interval '120 seconds',
        updated_at = now()
  where id = row_state.id;
  return true;
end;
$$;

-- Enqueue failed (e.g. Redis unreachable): hand the row back for a later
-- dispatch attempt with the shared exponential-backoff shape
-- (5s * 2^attempt, capped at 1h) so DB-level retries mirror BullMQ's.
create or replace function private.api061_release_dispatch(
  p_worker text,
  p_outbox_id bigint,
  p_error_code text
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare row_state public.notification_outbox%rowtype;
begin
  if p_worker is null or length(p_worker) not between 1 and 100
     or p_error_code is null or length(p_error_code) not between 1 and 80 then
    raise exception 'OPS061_INVALID_DISPATCH_RELEASE';
  end if;
  select * into row_state from public.notification_outbox
  where id = p_outbox_id and state = 'processing' and lease_token = p_worker
  for update;
  if row_state.id is null then return false; end if;
  update public.notification_outbox
    set state = 'retry',
        next_attempt_at = now()
          + make_interval(secs => least(3600, 5 * (2 ^ least(attempt_count, 9))::integer)),
        lease_token = null,
        lease_until = null,
        last_error_code = p_error_code,
        updated_at = now()
  where id = row_state.id;
  return true;
end;
$$;

-- Terminal transition without a delivery side effect: the BullMQ job
-- exhausted its attempts (or a channel proved unsupported). One writer for
-- dead_letter, mirroring api051_finish_scan; audited like the file DLQ.
create or replace function private.api061_fail_dispatch(
  p_outbox_id bigint,
  p_error_code text
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare row_state public.notification_outbox%rowtype;
begin
  if p_error_code is null or length(p_error_code) not between 1 and 80 then
    raise exception 'OPS061_INVALID_DISPATCH_FAIL';
  end if;
  select * into row_state from public.notification_outbox
  where id = p_outbox_id and state = 'processing' for update;
  if row_state.id is null then return false; end if;
  update public.notification_outbox
    set state = 'dead_letter',
        lease_token = null,
        lease_until = null,
        last_error_code = p_error_code,
        updated_at = now()
    where id = row_state.id;
  insert into public.audit_events(school_id, actor_id, action, entity_type, entity_id, after_value, request_id)
  values (row_state.school_id, null, 'ops061_outbox_dead_letter', 'notification_outbox', null,
    jsonb_build_object('outboxId', row_state.id, 'templateKey', row_state.template_key,
      'attempts', row_state.attempt_count, 'errorCode', p_error_code),
    'ops061-dlq-' || row_state.id || '-' || extract(epoch from now())::bigint);
  return true;
end;
$$;

-- Reclaim one stale row whose BullMQ job is provably gone. The caller
-- (dispatcher reconciliation) checks Redis first; this is the DB half.
create or replace function private.api061_reclaim_dispatch(
  p_outbox_id bigint
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare row_state public.notification_outbox%rowtype;
begin
  select * into row_state from public.notification_outbox
  where id = p_outbox_id and state = 'processing'
    and lease_until < now() - interval '10 minutes'
  for update;
  if row_state.id is null then return false; end if;
  update public.notification_outbox
    set state = 'retry',
        next_attempt_at = now(),
        lease_token = null,
        lease_until = null,
        last_error_code = 'DISPATCH_LEASE_EXPIRED',
        updated_at = now()
    where id = row_state.id;
  return true;
end;
$$;

-- The notifications processor's finish: expand the audience into in-app
-- deliveries and complete the row in ONE transaction, or dead-letter a
-- terminal audience. Called without a worker token on purpose: BullMQ
-- failover means any worker instance may finish, and the deliveries unique
-- constraint makes a repeat run a no-op, not a duplicate.
create or replace function private.api061_finish_notification(
  p_outbox_id bigint
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  row_state public.notification_outbox%rowtype;
  recipients uuid[];
  target_classroom uuid;
begin
  select * into row_state from public.notification_outbox where id = p_outbox_id for update;
  -- Already finished by a concurrent/duplicate run: idempotent no-op.
  if row_state.state = 'completed' then return 'completed'; end if;
  if row_state.state = 'dead_letter' then return 'terminal'; end if;
  if row_state.id is null or row_state.state <> 'processing' then
    return 'lost';
  end if;

  if row_state.channel <> 'in_app' then
    update public.notification_outbox
      set state = 'dead_letter', lease_token = null, lease_until = null,
          last_error_code = 'UNSUPPORTED_CHANNEL', updated_at = now()
      where id = row_state.id;
    insert into public.audit_events(school_id, actor_id, action, entity_type, entity_id, after_value, request_id)
    values (row_state.school_id, null, 'ops061_outbox_dead_letter', 'notification_outbox', null,
      jsonb_build_object('outboxId', row_state.id, 'templateKey', row_state.template_key,
        'errorCode', 'UNSUPPORTED_CHANNEL'),
      'ops061-dlq-' || row_state.id || '-' || extract(epoch from now())::bigint);
    return 'terminal';
  end if;

  if row_state.audience->>'classroomId' is not null then
    target_classroom := nullif(row_state.audience->>'classroomId', '')::uuid;
    if target_classroom is null then
      update public.notification_outbox
        set state = 'dead_letter', lease_token = null, lease_until = null,
            last_error_code = 'UNSUPPORTED_AUDIENCE', updated_at = now()
        where id = row_state.id;
      insert into public.audit_events(school_id, actor_id, action, entity_type, entity_id, after_value, request_id)
      values (row_state.school_id, null, 'ops061_outbox_dead_letter', 'notification_outbox', null,
        jsonb_build_object('outboxId', row_state.id, 'templateKey', row_state.template_key,
          'errorCode', 'UNSUPPORTED_AUDIENCE'),
        'ops061-dlq-' || row_state.id || '-' || extract(epoch from now())::bigint);
      return 'terminal';
    end if;
    select coalesce(array_agg(m.user_id), array[]::uuid[])
      into recipients
      from public.memberships m
      join public.classroom_staff cs on cs.school_id = m.school_id and cs.user_id = m.user_id
      join public.profiles p on p.id = m.user_id and p.status = 'active'
      where m.school_id = row_state.school_id and m.active and m.status = 'active'
        and cs.classroom_id = target_classroom and cs.status = 'active'
        and cs.role in ('lead_teacher', 'co_teacher', 'assistant');
  elsif row_state.audience->>'schoolId' is not null
        and nullif(row_state.audience->>'schoolId', '')::uuid = row_state.school_id then
    select coalesce(array_agg(m.user_id), array[]::uuid[])
      into recipients
      from public.memberships m
      join public.profiles p on p.id = m.user_id and p.status = 'active'
      where m.school_id = row_state.school_id and m.active and m.status = 'active'
        and m.role in ('school_admin', 'teacher');
  else
    update public.notification_outbox
      set state = 'dead_letter', lease_token = null, lease_until = null,
          last_error_code = 'UNSUPPORTED_AUDIENCE', updated_at = now()
      where id = row_state.id;
    insert into public.audit_events(school_id, actor_id, action, entity_type, entity_id, after_value, request_id)
    values (row_state.school_id, null, 'ops061_outbox_dead_letter', 'notification_outbox', null,
      jsonb_build_object('outboxId', row_state.id, 'templateKey', row_state.template_key,
        'errorCode', 'UNSUPPORTED_AUDIENCE'),
      'ops061-dlq-' || row_state.id || '-' || extract(epoch from now())::bigint);
    return 'terminal';
  end if;

  insert into public.notification_deliveries(
    school_id, outbox_id, recipient_id, channel, attempt, state, delivered_at
  )
  select row_state.school_id, row_state.id, m.user_id, row_state.channel, 1,
         'sent', now()
  from unnest(recipients) as m(user_id)
  on conflict (outbox_id, recipient_id, channel, attempt) do nothing;

  update public.notification_outbox
    set state = 'completed', lease_token = null, lease_until = null,
        last_error_code = null, updated_at = now()
    where id = row_state.id;
  return 'completed';
end;
$$;

-- Backlog/lag observability. Counts and age only; safe for logs.
create or replace function private.api061_outbox_backlog()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'pending', (select count(*) from public.notification_outbox
      where recipient_id is null and audience is not null and state = 'pending'),
    'retry', (select count(*) from public.notification_outbox
      where recipient_id is null and audience is not null and state = 'retry'),
    'processing', (select count(*) from public.notification_outbox
      where recipient_id is null and audience is not null and state = 'processing'),
    'deadLetter', (select count(*) from public.notification_outbox
      where recipient_id is null and audience is not null and state = 'dead_letter'),
    'oldestPendingSeconds', (select coalesce(extract(epoch from now()
      - min(next_attempt_at))::bigint, 0)
      from public.notification_outbox
      where recipient_id is null and audience is not null
        and state in ('pending', 'retry'))
  );
$$;

-- DLQ read for the operator tooling (see docs/security/ops061-operator-runbook.md).
create or replace function private.api061_list_dlq(
  p_limit integer default 100
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare rows jsonb;
begin
  if p_limit is null or p_limit not between 1 and 500 then
    raise exception 'OPS061_INVALID_DLQ_LIST';
  end if;
  select coalesce(jsonb_agg(jsonb_build_object(
      'outboxId', j.id, 'schoolId', j.school_id, 'channel', j.channel,
      'templateKey', j.template_key, 'attempts', j.attempt_count,
      'errorCode', j.last_error_code, 'bullmqJobId', j.bullmq_job_id,
      'createdAt', j.created_at, 'failedAt', j.updated_at) order by j.id), '[]'::jsonb)
  into rows
  from (
    select * from public.notification_outbox
    where recipient_id is null and audience is not null and state = 'dead_letter'
    order by id limit p_limit
  ) j;
  return rows;
end;
$$;

-- Authenticated redrive: back to retry, immediately dispatchable, audited.
create or replace function private.api061_redrive_dlq(
  p_outbox_id bigint
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare row_state public.notification_outbox%rowtype;
begin
  select * into row_state from public.notification_outbox
  where id = p_outbox_id and state = 'dead_letter' for update;
  if row_state.id is null then return false; end if;
  update public.notification_outbox
    set state = 'retry', next_attempt_at = now(), lease_token = null,
        lease_until = null, last_error_code = null, updated_at = now()
    where id = row_state.id;
  insert into public.audit_events(school_id, actor_id, action, entity_type, entity_id, after_value, request_id)
  values (row_state.school_id, null, 'ops061_dlq_redriven', 'notification_outbox', null,
    jsonb_build_object('outboxId', row_state.id, 'templateKey', row_state.template_key,
      'priorAttempts', row_state.attempt_count),
    'ops061-redrive-' || row_state.id || '-' || extract(epoch from now())::bigint);
  return true;
end;
$$;

alter function private.api061_claim_outbox_dispatch(text, integer) owner to postgres;
alter function private.api061_record_dispatched(text, bigint, text) owner to postgres;
alter function private.api061_release_dispatch(text, bigint, text) owner to postgres;
alter function private.api061_fail_dispatch(bigint, text) owner to postgres;
alter function private.api061_reclaim_dispatch(bigint) owner to postgres;
alter function private.api061_finish_notification(bigint) owner to postgres;
alter function private.api061_outbox_backlog() owner to postgres;
alter function private.api061_list_dlq(integer) owner to postgres;
alter function private.api061_redrive_dlq(bigint) owner to postgres;

revoke all on function private.api061_claim_outbox_dispatch(text, integer),
  private.api061_record_dispatched(text, bigint, text),
  private.api061_release_dispatch(text, bigint, text),
  private.api061_fail_dispatch(bigint, text),
  private.api061_reclaim_dispatch(bigint),
  private.api061_finish_notification(bigint),
  private.api061_outbox_backlog(),
  private.api061_list_dlq(integer),
  private.api061_redrive_dlq(bigint)
  from public, anon, authenticated, service_role, studafy_api_runtime;

-- Least privilege, exactly like the file workers: the worker runtime holds
-- EXECUTE on these functions and nothing else (no table grants exist for it).
grant execute on function private.api061_claim_outbox_dispatch(text, integer),
  private.api061_record_dispatched(text, bigint, text),
  private.api061_release_dispatch(text, bigint, text),
  private.api061_fail_dispatch(bigint, text),
  private.api061_reclaim_dispatch(bigint),
  private.api061_finish_notification(bigint),
  private.api061_outbox_backlog(),
  private.api061_list_dlq(integer),
  private.api061_redrive_dlq(bigint)
  to studafy_worker_runtime;
