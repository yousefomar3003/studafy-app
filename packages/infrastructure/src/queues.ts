import { type JobsOptions, type Processor, Queue, Worker } from "bullmq";

export type { JobsOptions, Processor, Queue, Worker };

export interface QueueOptions {
  /** Prefix for all queue keys (enables per-environment namespaces). */
  prefix?: string;
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
  });
}

/** Creates a BullMQ worker that processes jobs from `name`. */
export function createWorker(
  name: string,
  processor: Processor,
  redisUrl: string,
  options: QueueOptions & { concurrency?: number } = {},
): Worker {
  return new Worker(name, processor, {
    connection: { url: redisUrl },
    prefix: options.prefix ?? "studafy",
    concurrency: options.concurrency ?? 1,
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

/** Graceful worker close: waits for the current job to finish. */
export async function closeWorker(worker: Worker): Promise<void> {
  await worker.close();
}
