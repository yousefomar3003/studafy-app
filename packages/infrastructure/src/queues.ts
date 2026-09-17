import { type JobsOptions, type Processor, Queue, Worker } from "bullmq";

export type { JobsOptions, Processor, Queue, Worker };

export interface QueueOptions {
  /** Prefix for all queue keys (enables per-environment namespaces). */
  prefix?: string;
  /**
   * Defaults applied to every job added through this queue: attempts,
   * backoff, removal policies. The queue inventory (apps/worker) is the
   * authority for per-queue values; callers pass the resolved options.
   */
  defaultJobOptions?: JobsOptions;
}

export interface WorkerOptions {
  prefix?: string;
  concurrency?: number;
  /** How long a job's processing lock holds before it may be re-dispatched. */
  lockDurationMs?: number;
  /** How often stalled active jobs are checked for recovery. */
  stalledIntervalMs?: number;
  /** How many times a job may be recovered from a stall before failing. */
  maxStalledCount?: number;
}

/** Creates a BullMQ queue used to enqueue jobs. */
export function createQueue(
  name: string,
  redisUrl: string,
  options: QueueOptions = {},
): Queue {
  return new Queue(name, {
    connection: { url: redisUrl },
    prefix: options.prefix ?? "studafy",
    defaultJobOptions: options.defaultJobOptions,
  });
}

/** Creates a BullMQ worker that processes jobs from `name`. */
export function createWorker(
  name: string,
  processor: Processor,
  redisUrl: string,
  options: WorkerOptions = {},
): Worker {
  return new Worker(name, processor, {
    connection: { url: redisUrl },
    prefix: options.prefix ?? "studafy",
    concurrency: options.concurrency ?? 1,
    lockDuration: options.lockDurationMs ?? 30_000,
    stalledInterval: options.stalledIntervalMs ?? 30_000,
    maxStalledCount: options.maxStalledCount ?? 1,
  });
}

/** Drains the queue (removes all jobs — test/synthetic use only). */
export async function drainQueue(queue: Queue): Promise<void> {
  await queue.drain();
}

/** Graceful queue close: stops accepting new jobs. */
export async function closeQueue(queue: Queue): Promise<void> {
  await queue.close();
}

/**
 * Graceful worker close: stops accepting new jobs and waits for in-flight
 * jobs to finish (§10.658). The caller closes the Queue and Redis client
 * after this, so a bounded shutdown budget can wrap the whole chain.
 */
export async function closeWorker(worker: Worker): Promise<void> {
  await worker.close();
}

export interface QueueStats {
  waiting: number;
  active: number;
  delayed: number;
  failed: number;
  completed: number;
}

/**
 * Depth observability for the worker's periodic metrics log. Counts only —
 * never job payloads (§10 payload minimization).
 */
export async function queueStats(queue: Queue): Promise<QueueStats> {
  const counts = await queue.getJobCounts(
    "waiting",
    "active",
    "delayed",
    "failed",
    "completed",
  );
  return {
    waiting: counts.waiting ?? 0,
    active: counts.active ?? 0,
    delayed: counts.delayed ?? 0,
    failed: counts.failed ?? 0,
    completed: counts.completed ?? 0,
  };
}

/** The oldest job waiting, in ms, or 0 when the queue is empty. */
export async function oldestWaitingAgeMs(queue: Queue): Promise<number> {
  const jobs = await queue.getWaiting(0, 0);
  const oldest = jobs[0];
  if (!oldest?.timestamp) return 0;
  return Math.max(0, Date.now() - oldest.timestamp);
}
