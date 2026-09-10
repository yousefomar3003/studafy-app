import type { Logger } from "@studafy/observability";
import {
  closeQueue,
  closeWorker,
  createQueue,
  createWorker,
  type Queue,
  type Worker,
} from "@studafy/infrastructure";
import type { Processor } from "bullmq";
import { createSmokeProcessor } from "../processors/smoke";

export interface WorkerRuntime {
  queue: Queue;
  worker: Worker;
  close: () => Promise<void>;
}

/** Builds the smoke queue runtime: queue + worker + a graceful close chain. */
export function buildSmokeRuntime(
  redisUrl: string,
  logger: Logger,
  options: { environment: string; concurrency?: number },
): WorkerRuntime {
  const prefix = `studafy-${options.environment}`;
  const processor: Processor = createSmokeProcessor(logger);
  const queue = createQueue("smoke", redisUrl, { prefix });
  const worker = createWorker("smoke", processor, redisUrl, {
    prefix,
    concurrency: options.concurrency ?? 1,
  });
  return {
    queue,
    worker,
    close: async () => {
      await closeWorker(worker);
      await closeQueue(queue);
    },
  };
}
