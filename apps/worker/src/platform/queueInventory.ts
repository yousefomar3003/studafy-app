/**
 * Queue inventory (OPS-061, instructions.md §10 "Queue inventory and
 * contracts"). One definition per §10 queue: the retry/timeout/concurrency
 * policy, the BullMQ key prefix, and the wiring status.
 *
 * Only `notifications` is implemented in this slice; the other queues carry
 * their §10 policy as declared contracts so a later slice wires processors
 * without re-deciding budgets. The payload contracts themselves live in
 * `@studafy/contracts` (`src/jobs`), and the drift test asserts the two
 * lists never diverge.
 */
import type { JobsOptions } from "bullmq";
import {
  backoffOptions,
  type BackoffPolicy,
  type QueueStats,
  type WorkerOptions,
} from "@studafy/infrastructure";

export type QueueStatus = "implemented" | "declared";

export interface QueueDefinition {
  /** BullMQ queue name; stable per §10. */
  name: string;
  status: QueueStatus;
  concurrency: number;
  lockDurationMs: number;
  stalledIntervalMs: number;
  maxStalledCount: number;
  /** Retry policy: attempts + exponential backoff with full jitter. */
  backoff: BackoffPolicy;
  /** Total per-job budget: the processor must enforce this itself. */
  timeoutMs: number;
  /** Removal retention for completed jobs (keep recent history for triage). */
  removeOnComplete: { count: number; age: number };
  /** §10 idempotency key contract, kept with the definition for review. */
  idempotencyKey: string;
}

/**
 * Queue keys use the BullMQ namespace `studafy-{env}:…` — never the
 * limiter/cache namespaces (`studafy:{env}:rl|cache`). Asserted by the
 * namespace test in apps/api/test/platform/cache.test.ts.
 */
export function queuePrefix(environment: string): string {
  return `studafy-${environment}`;
}

export function defaultJobOptionsFor(
  definition: QueueDefinition,
): JobsOptions {
  return {
    attempts: definition.backoff.attempts,
    backoff: backoffOptions(definition.backoff),
    // Keep failed jobs for operator triage; the DB dead_letter row is the
    // durable DLQ (ADR-0025), the failed set is the forensic detail.
    removeOnFail: false,
    removeOnComplete: definition.removeOnComplete,
  };
}

export function workerOptionsFor(
  definition: QueueDefinition,
): WorkerOptions {
  return {
    concurrency: definition.concurrency,
    lockDurationMs: definition.lockDurationMs,
    stalledIntervalMs: definition.stalledIntervalMs,
    maxStalledCount: definition.maxStalledCount,
  };
}

const notifications: QueueDefinition = {
  name: "notifications",
  status: "implemented",
  concurrency: 5,
  lockDurationMs: 30_000,
  stalledIntervalMs: 15_000,
  maxStalledCount: 2,
  // §10: 5 exponential retries with jitter.
  backoff: { baseMs: 5_000, capMs: 60 * 60_000, attempts: 5 },
  timeoutMs: 30_000,
  removeOnComplete: { count: 1000, age: 24 * 3600 },
  idempotencyKey: "source event + recipient + channel + template version",
};

const billingEvents: QueueDefinition = {
  name: "billing-events",
  status: "implemented",
  concurrency: 2,
  lockDurationMs: 60_000,
  stalledIntervalMs: 30_000,
  maxStalledCount: 1,
  // §10: 8 exponential retries with jitter; original-transaction unknowns
  // re-verify against the store and the reconciliation sweep backstops the
  // loss window, so a capped retry then a durable Postgres dead_letter is
  // the correct terminal state.
  backoff: { baseMs: 10_000, capMs: 60 * 60_000, attempts: 8 },
  timeoutMs: 60_000,
  removeOnComplete: { count: 5000, age: 7 * 24 * 3600 },
  idempotencyKey: "platform + environment + event/transaction ID",
};

const declared: QueueDefinition[] = [
  {
    name: "file-security",
    status: "declared",
    concurrency: 1,
    lockDurationMs: 120_000,
    stalledIntervalMs: 30_000,
    maxStalledCount: 1,
    backoff: { baseMs: 5_000, capMs: 60 * 60_000, attempts: 3 },
    timeoutMs: 10 * 60_000,
    removeOnComplete: { count: 1000, age: 24 * 3600 },
    idempotencyKey: "file object ID + scan policy version",
  },
  {
    name: "media-processing",
    status: "declared",
    concurrency: 2,
    lockDurationMs: 120_000,
    stalledIntervalMs: 30_000,
    maxStalledCount: 1,
    backoff: { baseMs: 5_000, capMs: 60 * 60_000, attempts: 3 },
    timeoutMs: 5 * 60_000,
    removeOnComplete: { count: 1000, age: 24 * 3600 },
    idempotencyKey: "file object ID + transform version",
  },
  {
    name: "ai-grading",
    status: "declared",
    concurrency: 2,
    lockDurationMs: 120_000,
    stalledIntervalMs: 30_000,
    maxStalledCount: 1,
    backoff: { baseMs: 10_000, capMs: 10 * 60_000, attempts: 2 },
    timeoutMs: 2 * 60_000,
    removeOnComplete: { count: 1000, age: 24 * 3600 },
    idempotencyKey: "grade result + file object + rubric/model policy version",
  },
  {
    name: "meeting-operations",
    status: "declared",
    concurrency: 2,
    lockDurationMs: 60_000,
    stalledIntervalMs: 15_000,
    maxStalledCount: 2,
    backoff: { baseMs: 5_000, capMs: 10 * 60_000, attempts: 4 },
    timeoutMs: 60_000,
    removeOnComplete: { count: 1000, age: 24 * 3600 },
    idempotencyKey: "meeting command UUID",
  },
  {
    name: "exports",
    status: "declared",
    concurrency: 2,
    lockDurationMs: 300_000,
    stalledIntervalMs: 60_000,
    maxStalledCount: 1,
    backoff: { baseMs: 30_000, capMs: 60 * 60_000, attempts: 3 },
    timeoutMs: 30 * 60_000,
    removeOnComplete: { count: 2000, age: 24 * 3600 },
    idempotencyKey: "export request ID + requested snapshot/version",
  },
  {
    name: "search-index",
    status: "declared",
    concurrency: 5,
    lockDurationMs: 30_000,
    stalledIntervalMs: 15_000,
    maxStalledCount: 3,
    backoff: { baseMs: 2_000, capMs: 10 * 60_000, attempts: 5 },
    timeoutMs: 30_000,
    removeOnComplete: { count: 5000, age: 12 * 3600 },
    idempotencyKey: "entity ID + version (latest wins, superseded coalesce)",
  },
  {
    name: "retention-maintenance",
    status: "declared",
    concurrency: 1,
    lockDurationMs: 300_000,
    stalledIntervalMs: 60_000,
    maxStalledCount: 1,
    backoff: { baseMs: 60_000, capMs: 60 * 60_000, attempts: 5 },
    timeoutMs: 30 * 60_000,
    removeOnComplete: { count: 2000, age: 24 * 3600 },
    idempotencyKey: "policy + resource + effective date",
  },
];

export const QUEUE_INVENTORY: Record<string, QueueDefinition> = Object
  .fromEntries(
    [notifications, billingEvents, ...declared].map((definition) => [
      definition.name,
      definition,
    ]),
  );

/** Resolves one inventory definition, failing closed on an unknown name. */
export function queueDefinition(name: string): QueueDefinition {
  const definition = QUEUE_INVENTORY[name];
  if (!definition) {
    throw new Error(`Queue ${name} is not in the OPS-061 inventory.`);
  }
  return definition;
}

export const IMPLEMENTED_QUEUES = ["smoke", "notifications", "billing-events"] as const;

export type { QueueStats };
