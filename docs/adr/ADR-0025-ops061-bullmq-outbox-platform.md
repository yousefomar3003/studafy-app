# ADR-0025: OPS-061 BullMQ outbox processing platform

- Status: Accepted for local/disposable use
- Date: 2026-09-17
- Decision log: DL-046

## Context

Phase 6 Part 6B (OPS-061) required a reliable asynchronous execution layer:
BullMQ queues, the transactional outbox drain, a DLQ with operator tooling,
retries with backoff, and workers under `apps/worker`. Until this change,
BullMQ existed only as a pinned-version smoke proof; the transactional outbox
was real but one-sided — API-042's audience rows were never expanded into
deliveries (documented honestly in `api042_notifications.sql`), and the
FILE-050/051 pipeline drains `file_job_outbox` through SECURITY DEFINER
claim/finish functions without a queue at all.

Scope was agreed with the product owner before implementation:

1. **One real processor, eight declared contracts.** The notifications queue
   is implemented end-to-end as the reference processor (audience expansion →
   deliveries); the remaining §10 queues (`file-security`, `media-processing`,
   `ai-grading`, `billing-events`, `meeting-operations`, `exports`,
   `search-index`, `retention-maintenance`) are registered with their §10
   policy and versioned Zod payload contracts but no processors. Wiring them
   is the "processors by domain" parallel track §20 names.
2. **DLQ as database state, not a queue.** Terminal failures mark the outbox
   row `dead_letter` (the FILE-051 precedent); BullMQ's `failed` set with
   `removeOnFail: false` is forensic detail. Re-drive is an audited SQL
   transition plus an operator script, not a DLQ queue consumer.
3. **The file pipeline stays where it is.** The file workers already satisfy
   outbox-only + idempotency + crash recovery through their DB claim/finish
   functions. Migrating them onto BullMQ is a later, separate reviewed change
   and is recorded as an open gate — not silently skipped.

## Decision

**The outbox is the only path from a transaction to a side effect, and the
database invariant — not the queue — is the idempotency authority.**

- **Dispatch.** The worker-side dispatcher claims `notification_outbox`
  audience rows with `FOR UPDATE SKIP LOCKED` (`private.api061_claim_outbox_dispatch`),
  enqueues each onto the BullMQ `notifications` queue with the deterministic
  id `outbox-{id}`, and records the id (`api061_record_dispatched`) under a
  120s lease. A crash between claim and record is recovered by the claim's
  stale-lease branch; a crash between record and processing is recovered by
  BullMQ's stalled-job recovery; enqueue failure releases the row to `retry`
  with the same capped exponential backoff BullMQ computes.
- **Idempotency.** BullMQ 6 returns the existing job for a known `jobId`
  (verified against the pinned 6.3.4 Lua: `handleDuplicatedJob`), so a
  duplicate enqueue collapses onto the live job. But the guarantee that
  matters is the database one: `private.api061_finish_notification` expands
  the audience and inserts deliveries `ON CONFLICT DO NOTHING` inside the
  same transaction that completes the row. A job that runs twice — crash,
  failover, redrive — cannot double-apply. Concurrent finishes serialize on
  the row lock and converge on one delivery set.
- **Poison handling.** Terminal outcomes (unsupported channel/audience,
  exhausted attempts) dead-letter in the database exactly once and are
  audited; the processor returns without throwing so BullMQ does not spin
  retries on a permanently broken payload. Per-queue isolation (one worker
  per queue) keeps unrelated work running.
- **Backoff.** BullMQ's built-in `exponential` strategy with `jitter: 1`
  (full jitter) and the SQL release path compute the same ceiling
  (`maxDelayMs` mirror asserted by a drift test): 5s base, 1h cap, 5 attempts
  for notifications.
- **Queue Redis posture.** Queue keys are never evicted: the dev stack pins
  `--maxmemory-policy noeviction --appendonly yes`, production boots fail
  closed unless the queue Redis reports `noeviction` plus persistence (AOF
  or RDB) — enforced at worker startup via `assertQueueRedisPosture`. In
  production this must be a dedicated non-evicting allocation (OPS-060
  runbook §2); CONFIG GET requires a Redis ACL that permits it for the
  worker connection (Phase 8 IaC note).
- **Least privilege.** The worker role holds EXECUTE on the nine
  `private.api061_*` functions and no table grants, exactly like the file
  workers; the finish function intentionally takes no worker token because
  BullMQ failover means any instance may finish, and the deliveries unique
  constraint makes the repeat run a no-op.

## Consequences

- In-app notification fan-out (the deferred API-042 S1–S5 audience rows)
  now actually delivers; other channels (`email`, `push`) dead-letter as
  `UNSUPPORTED_CHANNEL` until their provider slice lands.
- The reconciliation loop (claim → check BullMQ → finish/fail/re-enqueue)
  is the recovery path for a wiped Redis: durable outbox rows re-dispatch.
- Known limits recorded for later slices: eight declared queues, the file
  pipeline still draining through DB functions, no repeatable-job scheduler
  (OPS-090), no managed-Redis failover/TLS proof (Phase 8), and per-tenant
  partition pausing (runbook documents the queue-level pause instead).
