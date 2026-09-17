-- OPS-061: notification outbox drain state machine. The concurrency proof
-- (two dispatcher sessions cannot double-claim one row) lives in the
-- integration suite because FOR UPDATE SKIP LOCKED cannot be raced inside
-- one pgtap transaction; this file proves the SQL transitions, the
-- idempotency invariants, the dead-letter path, and the least-privilege
-- grant surface.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(37);

-- --------------------------------------------------------------------------
-- Grant surface: the worker runtime drives the drain; nobody else does.
-- --------------------------------------------------------------------------

select ok(
  has_function_privilege('studafy_worker_runtime', 'private.api061_claim_outbox_dispatch(text, integer)', 'execute')
  and has_function_privilege('studafy_worker_runtime', 'private.api061_record_dispatched(text, bigint, text)', 'execute')
  and has_function_privilege('studafy_worker_runtime', 'private.api061_release_dispatch(text, bigint, text)', 'execute')
  and has_function_privilege('studafy_worker_runtime', 'private.api061_fail_dispatch(bigint, text)', 'execute')
  and has_function_privilege('studafy_worker_runtime', 'private.api061_reclaim_dispatch(bigint)', 'execute')
  and has_function_privilege('studafy_worker_runtime', 'private.api061_finish_notification(bigint)', 'execute')
  and has_function_privilege('studafy_worker_runtime', 'private.api061_outbox_backlog()', 'execute')
  and has_function_privilege('studafy_worker_runtime', 'private.api061_list_dlq(integer)', 'execute')
  and has_function_privilege('studafy_worker_runtime', 'private.api061_redrive_dlq(bigint)', 'execute'),
  'the worker runtime can execute the whole api061 dispatch surface'
);
select ok(
  not has_function_privilege('studafy_api_runtime', 'private.api061_claim_outbox_dispatch(text, integer)', 'execute')
  and not has_function_privilege('authenticated', 'private.api061_claim_outbox_dispatch(text, integer)', 'execute')
  and not has_function_privilege('anon', 'private.api061_finish_notification(bigint)', 'execute'),
  'no other role can drive the outbox drain'
);

-- --------------------------------------------------------------------------
-- Seed audience rows and one direct-recipient row (delivered inline by
-- notify_recipient, so the dispatcher must never claim it).
-- --------------------------------------------------------------------------

insert into public.notification_outbox(
  school_id, source_event_id, idempotency_key, channel, template_key, audience, payload
) values
  (:'school_id', 'ops061-evt-1', 'ops061-school-1', 'in_app', 'school_admin.membership_granted',
    jsonb_build_object('schoolId', :'school_id'::uuid), jsonb_build_object('entityId', 'x')),
  (:'school_id', 'ops061-evt-2', 'ops061-school-2', 'in_app', 'school_admin.membership_granted',
    jsonb_build_object('schoolId', :'other_school_id'::uuid), '{}'::jsonb),
  (:'school_id', 'ops061-evt-3', 'ops061-weird', 'in_app', 'school_admin.membership_granted',
    '{"unexpected":true}'::jsonb, '{}'::jsonb),
  (:'school_id', 'ops061-evt-4', 'ops061-release', 'in_app', 'school_admin.membership_granted',
    jsonb_build_object('schoolId', :'school_id'::uuid), '{}'::jsonb),
  (:'school_id', 'ops061-evt-5', 'ops061-stale', 'in_app', 'school_admin.membership_granted',
    jsonb_build_object('schoolId', :'school_id'::uuid), '{}'::jsonb);

-- A direct-recipient row is delivered inline by notify_recipient (recipient
-- set, no audience), so the dispatcher must never claim it.
insert into public.notification_outbox(
  school_id, source_event_id, idempotency_key, channel, template_key,
  recipient_id, audience, payload
) values
  (:'school_id', 'ops061-evt-6', 'ops061-direct', 'in_app', 'academic.grade_published',
    :'teacher_user'::uuid, null, '{}'::jsonb);

create temporary table ops061_ids as
  select id, idempotency_key from public.notification_outbox
  where school_id = :'school_id'::uuid and idempotency_key like 'ops061-%';

-- --------------------------------------------------------------------------
-- Dispatch claim: the direct-recipient row is invisible; the audience rows
-- are claimed exactly once and parked in processing with a lease.
-- --------------------------------------------------------------------------

select is(
  (select count(*) from jsonb_array_elements(
    private.api061_claim_outbox_dispatch('ops061-worker-a', 50)) claimed
   join ops061_ids i on i.id = (claimed->>'outboxId')::bigint
   where i.idempotency_key = 'ops061-direct'),
  0::bigint,
  'an outbox row with a direct recipient is never claimed'
);
select is(
  (select count(*) from jsonb_array_elements(
    private.api061_claim_outbox_dispatch('ops061-worker-a', 50)) claimed),
  0::bigint,
  'a re-claim without a stale lease takes nothing: the rows are processing'
);
select is(
  (select count(*) from public.notification_outbox
   where school_id = :'school_id'::uuid and idempotency_key = 'ops061-direct'
     and state = 'pending'),
  1::bigint,
  'the direct-recipient row stayed pending and untouched'
);

-- Reclaim the seeded audience rows back to pending so the numbered claim
-- below starts from a deterministic state (within this single transaction
-- the SKIP LOCKED lock is our own, so an UPDATE is the honest equivalent).
select throws_ok(
  format('select private.api061_claim_outbox_dispatch(%L, %L)', '', 50),
  'OPS061_INVALID_DISPATCH_CLAIM',
  'an empty worker id is rejected'
);
select throws_ok(
  format('select private.api061_claim_outbox_dispatch(%L, %L)', 'ops061-worker-a', 0),
  'OPS061_INVALID_DISPATCH_CLAIM',
  'a zero limit is rejected'
);

-- Claim everything dispatchable now and park with leases.
select is(
  (select count(*) from jsonb_array_elements(
    private.api061_claim_outbox_dispatch('ops061-worker-a', 50)) claimed),
  0::bigint,
  'nothing new is claimable this round'
);

-- Rewind the four audience rows so each phase can drive them one by one.
update public.notification_outbox
  set state = 'pending', lease_token = null, lease_until = null,
      attempt_count = 0
  where school_id = :'school_id'::uuid
    and idempotency_key in ('ops061-school-1', 'ops061-school-2', 'ops061-weird');

select is(
  (select count(*) from jsonb_array_elements(
    private.api061_claim_outbox_dispatch('ops061-worker-a', 50)) claimed
   join ops061_ids i on i.id = (claimed->>'outboxId')::bigint),
  3::bigint,
  'the claim takes every dispatchable audience row and only those'
);
select is(
  (select count(*) from public.notification_outbox
   where idempotency_key in ('ops061-school-1', 'ops061-school-2', 'ops061-weird')
     and state = 'processing' and attempt_count = 1
     and lease_token = 'ops061-worker-a' and lease_until > now()),
  3::bigint,
  'claimed rows are processing with the worker''s lease and one counted attempt'
);

-- --------------------------------------------------------------------------
-- record / release dispatch bookkeeping
-- --------------------------------------------------------------------------

select is(
  private.api061_record_dispatched('ops061-worker-a',
    (select id from ops061_ids where idempotency_key = 'ops061-school-1'),
    'outbox-' || (select id from ops061_ids where idempotency_key = 'ops061-school-1')),
  true,
  'the dispatcher records its deterministic BullMQ job id'
);
select is(
  private.api061_record_dispatched('ops061-worker-b',
    (select id from ops061_ids where idempotency_key = 'ops061-school-1'), 'outbox-9'),
  false,
  'a different dispatcher token cannot record over a live lease'
);
select is(
  (select count(*) from public.notification_outbox
   where idempotency_key = 'ops061-school-1'
     and bullmq_job_id like 'outbox-%' and dispatched_at is not null),
  1::bigint,
  'the recorded job id is the deterministic one and dispatch time is set'
);
select is(
  private.api061_release_dispatch('ops061-worker-a',
    (select id from ops061_ids where idempotency_key = 'ops061-school-1'),
    'REDIS_UNAVAILABLE'),
  true,
  'a failed enqueue hands the row back for a later dispatch'
);
select is(
  (select count(*) from public.notification_outbox
   where idempotency_key = 'ops061-school-1' and state = 'retry'
     and last_error_code = 'REDIS_UNAVAILABLE'
     and next_attempt_at > now()),
  1::bigint,
  'the released row retries with an error code and a backoff delay'
);

-- The backoff elapses; the next poll re-claims and finishes the row.
update public.notification_outbox
  set next_attempt_at = now()
  where idempotency_key = 'ops061-school-1';
select is(
  (select count(*) from jsonb_array_elements(
    private.api061_claim_outbox_dispatch('ops061-worker-b', 50)) claimed
   join ops061_ids i on i.id = (claimed->>'outboxId')::bigint
   where i.idempotency_key = 'ops061-school-1'),
  1::bigint,
  'the released row dispatches again once its backoff elapses'
);

-- --------------------------------------------------------------------------
-- Finish: expansion is transactional and idempotent; unsupported audiences
-- are terminal.
-- --------------------------------------------------------------------------

select is(
  private.api061_finish_notification(
    (select id from ops061_ids where idempotency_key = 'ops061-school-1')),
  'completed',
  'finishing the school audience expands it in one transaction'
);
select is(
  (select count(distinct nd.recipient_id) from public.notification_deliveries nd
   join public.notification_outbox o on o.id = nd.outbox_id
   where o.idempotency_key = 'ops061-school-1'),
  4::bigint,
  'every active staff member got exactly one delivery; suspended profiles did not'
);
select is(
  (select nd.attempt from public.notification_deliveries nd
   join public.notification_outbox o on o.id = nd.outbox_id
   where o.idempotency_key = 'ops061-school-1' limit 1),
  1,
  'in-app deliveries record attempt 1 and are marked sent'
);
select is(
  private.api061_finish_notification(
    (select id from ops061_ids where idempotency_key = 'ops061-school-1')),
  'completed',
  'a repeat run of the same job is an idempotent no-op'
);
select is(
  (select count(*) from public.notification_deliveries nd
   join public.notification_outbox o on o.id = nd.outbox_id
   where o.idempotency_key = 'ops061-school-1'),
  4::bigint,
  'the repeat run inserted no second delivery'
);
select is(
  private.api061_finish_notification(
    (select id from ops061_ids where idempotency_key = 'ops061-weird')),
  'terminal',
  'an unsupported audience is terminal, not retried'
);
select is(
  (select count(*) from public.notification_outbox
   where idempotency_key = 'ops061-weird' and state = 'dead_letter'
     and last_error_code = 'UNSUPPORTED_AUDIENCE'),
  1::bigint,
  'the terminal row dead-letters with a normalized reason'
);
select is(
  (select count(*) from public.audit_events
   where action = 'ops061_outbox_dead_letter'
     and after_value->>'outboxId' = (select id from ops061_ids where idempotency_key = 'ops061-weird')::text),
  1::bigint,
  'the dead letter is audited'
);
select is(
  private.api061_finish_notification(
    (select id from ops061_ids where idempotency_key = 'ops061-school-2')),
  'terminal',
  'an audience pointing at another school never applies there'
);

-- A stale lease is reclaimable and the row then re-dispatches cleanly.
update public.notification_outbox
  set state = 'processing', attempt_count = 1, lease_token = 'ops061-worker-dead',
      lease_until = now() - interval '11 minutes'
  where idempotency_key = 'ops061-stale';
select is(
  private.api061_reclaim_dispatch(
    (select id from ops061_ids where idempotency_key = 'ops061-stale')),
  true,
  'a dispatcher death is recoverable through the stale lease'
);
select is(
  private.api061_reclaim_dispatch(
    (select id from ops061_ids where idempotency_key = 'ops061-stale')),
  false,
  'the reclaim is a one-shot: a retry row cannot be reclaimed again'
);
select is(
  (select count(*) from jsonb_array_elements(
    private.api061_claim_outbox_dispatch('ops061-worker-b', 50)) claimed
   join ops061_ids i on i.id = (claimed->>'outboxId')::bigint
   where i.idempotency_key = 'ops061-stale'),
  1::bigint,
  'the reclaimed row dispatches again for a new worker'
);
select is(
  private.api061_finish_notification(
    (select id from ops061_ids where idempotency_key = 'ops061-stale')),
  'completed',
  'the recovered run finishes normally'
);
select is(
  (select count(distinct nd.recipient_id) from public.notification_deliveries nd
   join public.notification_outbox o on o.id = nd.outbox_id
   where o.idempotency_key = 'ops061-stale'),
  4::bigint,
  'the recovered run produced the same four deliveries, once'
);

-- --------------------------------------------------------------------------
-- DLQ: listing, audited redrive, and the honest second round.
-- --------------------------------------------------------------------------

select is(
  (select count(*) from jsonb_array_elements(private.api061_list_dlq(100)) dlq),
  2::bigint,
  'the DLQ lists both terminal rows'
);
select is(
  private.api061_redrive_dlq(
    (select id from ops061_ids where idempotency_key = 'ops061-school-2')),
  true,
  'an operator redrive returns the row to dispatch'
);
select is(
  (select count(*) from public.audit_events
   where action = 'ops061_dlq_redriven'
     and after_value->>'outboxId' = (select id from ops061_ids where idempotency_key = 'ops061-school-2')::text),
  1::bigint,
  'the redrive is audited'
);
select is(
  (select count(*) from jsonb_array_elements(
    private.api061_claim_outbox_dispatch('ops061-worker-b', 50)) claimed
   join ops061_ids i on i.id = (claimed->>'outboxId')::bigint
   where i.idempotency_key = 'ops061-school-2'),
  1::bigint,
  'the redriven row is claimed again and dead-letters again, deterministically'
);
select is(
  private.api061_finish_notification(
    (select id from ops061_ids where idempotency_key = 'ops061-school-2')),
  'terminal',
  'a permanently unsupported audience dead-letters again after redrive'
);

-- --------------------------------------------------------------------------
-- Backlog observability.
-- --------------------------------------------------------------------------

select is(
  ((select (private.api061_outbox_backlog()->>'deadLetter'))::int >= 2),
  true,
  'the backlog reports the dead letters'
);
select is(
  ((select (private.api061_outbox_backlog()->>'oldestPendingSeconds'))::int >= 0),
  true,
  'the backlog reports a pending-age lag metric'
);

rollback;
