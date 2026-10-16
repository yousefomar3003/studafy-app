# OPS-061 operator runbook — BullMQ queues, outbox drain, DLQ

This runbook covers operating the queue platform delivered by ADR-0025
(DL-046). The OPS-060 runbook owns the Redis security posture and key
namespaces; this document owns the queue semantics: the outbox drain, the
dead-letter queue (DLQ), retries, poison jobs, crash/failover recovery, and
backlog alerting.

The code is the authority: `apps/worker/src/platform/queueInventory.ts`
holds the per-queue policy table, `docs/adr/ADR-0025` the architecture.

## 1. What runs where

| Component | Location | Role |
|---|---|---|
| Outbox dispatcher | `apps/worker/src/outbox/dispatcher.ts` | Polls `notification_outbox` (audience rows), claims with `FOR UPDATE SKIP LOCKED`, enqueues BullMQ jobs (`jobId = outbox-{id}`), records the id under a 120s lease |
| Notifications worker | `apps/worker/src/processors/notifications.ts` | Expands an audience row into in-app deliveries and completes the row in one transaction |
| Queue inventory | `apps/worker/src/platform/queueInventory.ts` | Per-queue policy (attempts/backoff/timeout/concurrency) and wiring status |
| Dispatch SQL | `private.api061_*` (migration `202609170005`) | Claim / record / release / fail / reclaim / finish / backlog / DLQ list / redrive |
| DLQ tooling | `bun run ops:outbox-redrive` (`scripts/redrive-outbox-dlq.ts`) | Operator list/redrive, audited in `audit_events` |

The drain is enabled with `OPS061_NOTIFICATIONS_ENABLED=true` (requires
`DATABASE_URL`; off by default so a queue outage can never silently become a
notification outage).

## 2. Queue inventory and budgets

| Queue | Status | Attempts / backoff | Concurrency | Idempotency key |
|---|---|---|---|---|
| `notifications` | **implemented** | 5, exponential full jitter, 5s base / 1h cap | 5 (env-tunable) | source event + recipient + channel + template version |
| `file-security` | declared | 3 | 1 | file object ID + scan policy version |
| `media-processing` | declared | 3 | 2 | file object ID + transform version |
| `billing-events` | declared | 8 | 2 | platform + environment + transaction ID |
| `meeting-operations` | declared | 4 | 2 | meeting command UUID |
| `exports` | declared | 3 | 2 | export request ID + snapshot version |
| `search-index` | declared | 5 | 5 | entity ID + version (latest wins) |
| `retention-maintenance` | declared | 5 | 1 | policy + resource + effective date |

Declared queues have contracts (`@studafy/contracts` → `src/jobs`) but no
processors; their budgets are review-ready, not enforced anywhere yet.

## 3. Redis posture (queues must never be evicted)

Queue keys live under `studafy-{env}:…` on an allocation that must be:

- `maxmemory-policy noeviction` — an evicted job hash is a silently dropped
  side effect;
- persisted — `appendonly yes` (preferred) or a non-empty RDB save policy,
  so a Redis restart cannot drop enqueued jobs.

The worker asserts this at boot. **Production refuses to start** on a
violating allocation (`QueuePostureError`, fail closed); development logs
`queue_redis_posture_warning`. The dev container pins the flags in
`docker-compose.dev.yml`; production topology (dedicated allocation, TLS,
ACL) is the Phase 8 / INFRA-080 gate.

**Where the probe reads from** (`packages/infrastructure/src/queuePosture.ts`):

1. `CONFIG GET maxmemory-policy`, `appendonly`, `save`, one key per call.
   Self-hosted Redis answers this.
2. If CONFIG is refused (an error, `NOPERM`, an unknown command) or does not
   report the keys, `INFO memory` (`maxmemory_policy`) and `INFO
   persistence`. Persistence then counts as proven by `aof_enabled:1`, or by
   `rdb_saves` above 0 with `rdb_last_bgsave_status:ok` (snapshots the
   provider has actually taken; managed Redis refuses `BGSAVE` from
   clients). A snapshot-only database is therefore not proven until its
   first snapshot after a restart, so **use AOF**.
3. If neither answers, or INFO has no `maxmemory_policy`, the posture is
   unknown and production refuses to start (`Queue Redis posture
   unreadable: ...`).

The boot log line `queue_redis_posture` says which one answered: `source`
is `config` or `info`, and with `info`, `config_refused` holds Redis's
reason. Check it after every Redis change, on the test copy too (it runs as
`development`, so it logs instead of refusing).

**Managed Redis settings that pass:**

| Provider | Setting | Value |
|---|---|---|
| Redis Cloud | Database → **Configuration** → **Durability** → **Data persistence** | **Append-only file (AOF) every 1 sec** (AOF every write also passes; snapshots pass only once one has run) |
| Redis Cloud | Database → **Configuration** → **Durability** → **Data eviction policy** | **noeviction** (shown as "no eviction"; the default is volatile-lru, which fails) |
| Upstash | Database → **Details** | Eviction **off** (it is off by default) |

Redis Cloud's free Essentials plan has no data persistence at all, so a
production worker cannot run on it; a paid Essentials plan offers AOF every
second. Redis Cloud allows `CONFIG GET` only for a short list of settings
that does not include these three, so its worker always uses the INFO path.
Its `INFO` comes from Redis Cloud's proxy, which returns a different set of
fields from open-source Redis, and with replication on, persistence runs on
the replica: if the primary's `INFO` reports `aof_enabled:0` although AOF is
on in the console, production refuses to start, and the fix is a support
question to Redis Cloud, not a weaker check. Confirm on the test copy
first: its boot line should show `source: info`, `maxmemory_policy:
noeviction` and `appendonly: 1`.

Outage drill (extends the OPS-060 drill):

1. Stop Redis. The dispatcher releases its claimed rows back to `retry`
   (`REDIS_UNAVAILABLE`) on the next poll; the notifications worker retries
   in-flight jobs with backoff.
2. Restart Redis. Jobs whose hashes survived (AOF/RDB) continue; rows whose
   job hash was lost are reclaimed after the stale-lease window and
   re-dispatched from the durable outbox. No row can be stranded: the
   database is the recovery source.
3. Verify `outbox_backlog` returns to baseline and no `dead_letter` was
   created by the outage itself.

## 4. Observability and alerts

| Signal | Source | Alert posture |
|---|---|---|
| Outbox backlog | `outbox_backlog` log line (60s): pending/retry/processing/dead_letter/oldestPendingSeconds | Page on oldest-pending beyond the business deadline (notifications ≈ 15 min) |
| Queue depth/age | `queueStats`/`oldestWaitingAgeMs` helpers, loggable per poll | Page on sustained depth growth + age |
| DLQ size | `deadLetter` count in `outbox_backlog`, `private.api061_list_dlq` | Ticket; any dead letter deserves a look |
| Job outcomes | `notification_job_completed` / `_retry` / `_terminal` / `_exhausted` log lines | `_exhausted` and `_terminal` are investigate-now signals |

All counts and codes only — no payloads, no identifiers.

## 5. DLQ operations

The DLQ is the `dead_letter` state on `notification_outbox`, written by
exactly one path per failure class (`api061_fail_dispatch`,
`api061_finish_notification`'s terminal branches) and always audited with a
normalized error code.

### Triage

```sh
# list dead letters (id, school, template, attempts, error code, timestamps)
DATABASE_URL=… bun run ops:outbox-redrive
```

Error codes and their meaning:

- `UNSUPPORTED_AUDIENCE` / `UNSUPPORTED_CHANNEL` — deterministic, permanent.
  Fix requires a code change (define the audience shape or the channel
  provider), never a re-drive alone. Redrive is safe (the finish re-runs the
  same terminal check) but pointless until the shape is supported.
- `JOB_UNRECOVERABLE` / `INVALID_JOB_PAYLOAD` — the BullMQ job did not match
  the v1 contract or a bug refused retry. Check the job payload contract
  version before re-driving.
- `DEPENDENCY_UNAVAILABLE` / `PROCESSING_FAILED` / `NOTIFICATION_PROCESSING_FAILED`
  — infrastructure-grade failures that exhausted their attempts. Re-drive is
  the standard action once the dependency is healthy.

### Re-drive (audited)

```sh
DATABASE_URL=… bun run ops:outbox-redrive -- --id 42   # one row
DATABASE_URL=… bun run ops:outbox-redrive -- --all     # all listed rows
```

`private.api061_redrive_dlq` returns the row to `retry`, clears the lease,
and writes an `ops061_dlq_redriven` audit row. The dispatcher re-enqueues
with the same deterministic `jobId`; a stale BullMQ job with that id is
removed first (`ensureEnqueued`), so the redrive always produces a fresh run
and the idempotent finish prevents double-application.

### Queue-level pause

BullMQ has no per-tenant partition pause yet (declared-queue track). To stop
a misbehaving domain entirely: scale the affected worker to zero (or flip its
feature switch off) — producers stop, the durable outbox holds the rows, and
nothing is lost. Rows in `processing` recover through the stale-lease path
on the next boot.

## 6. Crash / failover recovery drill

Proven by `apps/worker/test/outbox.integration.test.ts` (crash mid-job,
failover, duplicate delivery, poison, backlog drain):

1. The worker force-crashes mid-job (side effect committed, job not
   acknowledged): BullMQ's stalled-job recovery re-delivers to another
   worker; the repeat `finish` is an idempotent no-op — exactly one delivery
   set.
2. Failover (worker dies, second already running): same mechanics; also
   proven for two concurrent finishes of the same row.
3. Duplicate BullMQ delivery: the deterministic `jobId` collapses duplicate
   enqueues; the DB invariant dedupes duplicate *runs*.
4. Poison: deterministic failure dead-letters once, unrelated work continues.
5. Backlog: N rows drain to completed with `pending`/`retry` at zero.

To rehearse: run the e2e suite locally (`bun run test:outbox:e2e`) against
the dev stack; it asserts each of these directly.

## 7. Where NOT to intervene

- Do not manually `UPDATE public.notification_outbox` rows in flight: the
  immutable-column trigger guards identity columns, and state transitions
  belong to the `api061_*` functions.
- Do not delete BullMQ jobs to "fix" a stuck queue — the outbox row is the
  authority; deleting a live job while its row is `processing` is recovered
  only by the reclaim path. Use the DLQ tooling instead.
- Do not re-point `OPS061_*` flags mid-incident without reading §1: the
  drain off = producers stop and rows accumulate; the drain on = normal
  recovery path.
