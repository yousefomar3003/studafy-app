# Phase 6, Part 6B (OPS-061) — BullMQ/outbox processing

Date: 2026-09-17 · ADR-0025 · DL-046 · Runbook:
`docs/security/ops061-operator-runbook.md`

## Scope executed

1. **Transactional outbox drain** — the worker-side dispatcher claims
   `notification_outbox` audience rows with `FOR UPDATE SKIP LOCKED`,
   enqueues deterministic BullMQ jobs (`jobId = outbox-{id}`), records the id
   under a lease, and reconciles rows whose job state disagrees with the
   row's. Enqueue failure releases rows to `retry` with the same capped
   exponential backoff BullMQ computes; stale leases are reclaimable after a
   conservative window. API-042's deferred audience rows now actually
   deliver.
2. **Reference processor (notifications).** Audience expansion → in-app
   deliveries + row completion in one transaction; the expansion is
   `ON CONFLICT DO NOTHING` so a repeat run cannot double-apply; suspended
   profiles are excluded; unsupported audiences/channels dead-letter
   deterministically and audited. Eight further §10 queues are registered
   with their policy and versioned Zod payload contracts (`declared`), no
   processors.
3. **DLQ + retries.** Terminal failures dead-letter in the database (one
   writer per class, audited); BullMQ `removeOnFail: false` keeps failed jobs
   for forensics; audited re-drive tooling (`bun run ops061:redrive`) plus a
   runbook. Backoff is exponential with full jitter (BullMQ `jitter: 1`),
   mirrored by the SQL release path and asserted by a drift test.
4. **Non-evicting, persisted queue Redis.** Dev compose pins
   `noeviction` + `appendonly yes` with a data volume; the worker asserts the
   posture at boot and **fails closed in production**; the posture logic is
   unit-tested and flips live against the pinned Redis in a test.
5. **Bun/Redis compatibility gate.** A dedicated suite proves the pinned
   Bun 1.4.2 + BullMQ 6.3.4 + ioredis 6.0.0 + Redis 7.4.4 stack: `duplicate()`
   blocking consumers, Lua/pipelines, typed connection failures, retry
   behaviour, exhausted attempts, delayed jobs, QueueEvents
   (including the `duplicated` jobId-collapse event the dispatcher relies
   on), stalled-job recovery after a hard crash, and graceful shutdown.
6. **Observability.** `outbox_backlog` (pending/retry/processing/dead-letter
   counts + oldest-pending age) and queue depth/age helpers; job outcome log
   lines with ids and codes only.

## Environment

- Local stack: Supabase (127.0.0.1:54322) + Redis 7.4.4 (pinned digest,
  recreated with the new `noeviction`/`appendonly` flags; verified
  `CONFIG GET` after recreation).
- Postgres-side suites and the e2e queue suite were run against the real
  local stack; Redis-only suites against the dev container.

## Verification transcript

| Suite | Result |
|---|---|
| `bunx supabase test db --local supabase/tests/ops061_outbox_seed.sql` | 37 pass / 0 fail (new: grants surface, claim/lease/reclaim, record/release bookkeeping, transactional expansion, idempotent re-finish, terminal audiences, DLQ list/redrive audited, backlog) |
| `bun run test:ops061:plans` | passed — `outbox_dispatch_claim` uses `db020_notification_outbox_ready` (redundant new index removed), `dlq_list` uses the new `ops061_outbox_dlq_idx`, resolver/backlog indexed; claim 0.03ms over a 2000+18000-row fixture |
| `bun run test:ops061:e2e` | 6 pass / 0 fail — happy path, duplicate delivery, failover, poison, backlog drain, **crash mid-job with force-close + stalled recovery** (41 assertions) |
| `bun test packages/infrastructure` | 52 pass / 0 fail (new: backoff mirror + jitter options, posture pure/redis guards, 9 BullMQ/Bun compat-gate tests) |
| `bun test packages/config` | 28 pass / 0 fail (8 new: drain flag default, DATABASE_URL coupling, bounded poll interval/concurrency, describeWorkerEnv) |
| `bun test apps/worker` | 29 pass / 0 fail (new: queue inventory vs §10 + contract drift, job guards, integration suite) |
| `bun test apps packages` (full, DB+Redis env) | 459 pass / 1 skip / 0 fail |
| `bun run typecheck` | 0 errors (9 packages) |
| `bun run lint` / `bun run format:check` | clean (186 / 209 files) |
| `bun run check:bounds` | passed — 9 members, 107 source files, 0 violations |
| `bun run generate:check` / `generate:db-types:check` | passed (migration type columns regenerated) |

## Acceptance evidence per instructions.md (OPS-061)

**Logical idempotency through crash and failover.** The e2e suite force-closes
a worker after the side effect commits but before BullMQ acknowledges:
recovery re-runs the finish and the delivery count stays 3 (one per active
staff member; the suspended profile is excluded). Two concurrent finishes
converge on one delivery set; two enqueues of the same jobId collapse to one
job (`duplicated` event, asserted live against BullMQ 6.3.4) and a repeated
processor run inserts nothing (`ON CONFLICT DO NOTHING` + completed-state
no-op), proven live and by pgTAP.

**Duplicate/out-of-order/stalled/poison.** Stalled recovery is exercised for
real (crashed lock reaped by the recovered worker's stalled check). Poison:
a deterministic failure (`UNSUPPORTED_AUDIENCE`) dead-letters exactly once
(one audit row), inserts nothing, and unrelated work continues; `isFinalAttempt`
unit tests pin the boundary.

**Outbox-only side effects.** The processor performs no external side
effect: every transition is a `SECURITY DEFINER` call; the claim is
`FOR UPDATE SKIP LOCKED` and records the queue job id; the API role has no
EXECUTE on any `api061_*` function (pgTAP grant assertions).

**Retries with backoff.** 5 exponential retries with full jitter for
notifications (§10); the SQL release path (`least(3600, 5·2^attempt)`s) is
asserted equal to the BullMQ ceiling by a drift test; terminal classes
never consume retries.

**Queues are observable, recoverable and non-evicting.** Backlog/age
logging; reconciliation covers dispatcher death (stale lease), Redis loss
(job-hash gone → re-dispatch from the durable row) and BullMQ job failure
(dead_letter reconcile); dev Redis runs `noeviction` + AOF, production
boot-blocks a violating allocation (tested live against the pinned Redis).

**No queue eviction.** The BullMQ namespace (`studafy-{env}`) stays
pairwise disjoint from limiter/cache (asserted in the existing namespace
test); the queue allocation is non-evicting and persisted in dev and
fail-closed enforced in production.

## Environment / honest limits (open gates, unchanged by this part)

- Eight §10 queues are `declared` only (contracts + budgets, no processors);
  the FILE-050/051 workers still drain `file_job_outbox` through their DB
  claim/finish functions and are deliberately **not** migrated onto BullMQ
  in this slice (ADR-0025 records the deferral).
- Email/push channels and Calendar/billing/export processors dead-letter as
  unsupported until their domain slices land.
- No repeatable-job scheduler exists (OPS-090's scope); scheduled sweeps
  remain the lazy/swept patterns documented in the Phase 4/5 contracts.
- TLS/ACL/failover of the exact managed Redis product remains a Phase 8
  infrastructure proof; the compat gate covers the local pinned stack only.
- Pre-existing DB-gated integration suites unaffected; the DB-020-gated
  failures noted in Phase 6A do not appear here because the local stack ran.
