import type { Logger } from "@studafy/observability";
import type { Sql } from "@studafy/database";
import {
  closeQueue,
  closeWorker,
  createQueue,
  createWorker,
  type Queue,
  type QueueOptions,
  type Worker,
} from "@studafy/infrastructure";
import type { Processor } from "bullmq";
import {
  defaultJobOptionsFor,
  queueDefinition,
  queuePrefix,
  workerOptionsFor,
} from "../platform/queueInventory";
import { createNotificationProcessor } from "../processors/notifications";
import { postgresOutboxDispatch } from "../outbox/outboxDispatch";
import { createOutboxDispatcher } from "../outbox/dispatcher";
import { createSmokeProcessor } from "../processors/smoke";

export interface WorkerRuntime {
  queue: Queue;
  worker: Worker;
  close: () => Promise<void>;
}

export interface NotificationRuntime {
  queue: Queue;
  worker: Worker;
  /** Runs one dispatcher poll: claim → enqueue → record. */
  runDispatchOnce: () => Promise<number>;
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

/**
 * Builds the OPS-061 notifications runtime: the BullMQ queue + worker for
 * the `notifications` queue and the outbox dispatcher that drains
 * `notification_outbox` rows into it. All BullMQ keys live under the
 * non-evicting `studafy-{env}` prefix.
 */
export function buildNotificationRuntime(
  redisUrl: string,
  sql: Sql,
  logger: Logger,
  options: {
    environment: string;
    concurrency?: number;
    pollIntervalMs?: number;
  },
): NotificationRuntime {
  const definition = queueDefinition("notifications");
  const prefix = queuePrefix(options.environment);
  const queueOptions: QueueOptions = {
    prefix,
    defaultJobOptions: defaultJobOptionsFor(definition),
  };
  const dispatch = postgresOutboxDispatch(sql);
  const processor: Processor = createNotificationProcessor(dispatch, logger);
  const queue = createQueue(definition.name, redisUrl, queueOptions);
  const worker = createWorker(
    definition.name,
    processor,
    redisUrl,
    {
      prefix,
      ...workerOptionsFor(definition),
      concurrency: options.concurrency ?? definition.concurrency,
    },
  );
  const dispatcher = createOutboxDispatcher(dispatch, queue, logger);
  return {
    queue,
    worker,
    runDispatchOnce: () => dispatcher.runOnce(),
    close: async () => {
      // Stop the producer side first (no new claims), then drain the
      // worker's in-flight job, then close the queue client (§10.658).
      await closeWorker(worker);
      await closeQueue(queue);
    },
  };
}
