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
  RealAppleTransactionVerifier,
  RealGooglePurchaseVerifier,
} from "@studafy/infrastructure";
import type { WorkerEnv } from "@studafy/config";
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
import { postgresBillingDispatch } from "../billing/billingDispatch";
import { createBillingDispatcher } from "../billing/dispatcher";
import { createBillingEventProcessor, type BillingVerifierDependencies } from "../billing/processor";
import { startBillingReconciliation } from "../billing/reconciliation";

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

export interface BillingRuntime {
  queue: Queue;
  worker: Worker;
  /** Runs one dispatcher poll: claim → enqueue → record. */
  runDispatchOnce: () => Promise<number>;
  /** Runs one reconciliation sweep poll (when enabled). */
  runReconciliationOnce: () => Promise<number>;
  close: () => Promise<void>;
}

/** PAY-071 store verifiers from the worker environment; null when unconfigured. */
export function billingVerifiersFromEnv(env: WorkerEnv): BillingVerifierDependencies {
  const apple = env.APPLE_BUNDLE_ID && env.APPLE_ENVIRONMENT &&
      env.APPLE_ISSUER_ID && env.APPLE_KEY_ID && env.APPLE_PRIVATE_KEY &&
      env.APPLE_ROOT_CERTIFICATES_BASE64
    ? {
      verifier: new RealAppleTransactionVerifier({
        rootCertificates: env.APPLE_ROOT_CERTIFICATES_BASE64.split(",")
          .map((value) => Buffer.from(value.trim(), "base64")),
        bundleId: env.APPLE_BUNDLE_ID,
        environment: env.APPLE_ENVIRONMENT,
        appAppleId: env.APPLE_APP_APPLE_ID,
        api: {
          signingKey: env.APPLE_PRIVATE_KEY,
          keyId: env.APPLE_KEY_ID,
          issuerId: env.APPLE_ISSUER_ID,
        },
      }),
      bundleId: env.APPLE_BUNDLE_ID,
      platformEnvironment: env.APPLE_ENVIRONMENT,
    }
    : null;
  const google = env.GOOGLE_PACKAGE_NAME && env.GOOGLE_SERVICE_ACCOUNT_JSON &&
      env.GOOGLE_PUBSUB_AUDIENCE && env.GOOGLE_PUBSUB_SERVICE_ACCOUNT_EMAIL
    ? {
      verifier: new RealGooglePurchaseVerifier({
        serviceAccountJson: env.GOOGLE_SERVICE_ACCOUNT_JSON,
        pubsubAudience: env.GOOGLE_PUBSUB_AUDIENCE,
        pubsubServiceAccountEmail: env.GOOGLE_PUBSUB_SERVICE_ACCOUNT_EMAIL,
      }),
      packageName: env.GOOGLE_PACKAGE_NAME,
    }
    : null;
  return {
    environment: env.PAY071_ENVIRONMENT ?? "development",
    apple,
    google,
  };
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

/**
 * Builds the PAY-071 billing runtime: the `billing-events` BullMQ queue +
 * worker (re-verification against the official store APIs) with the
 * store-event dispatcher draining `store_events` rows into it, plus the
 * reconciliation sweep when enabled. Runs under the same non-evicting
 * `studafy-{env}` prefix as every other queue.
 */
export function buildBillingRuntime(
  redisUrl: string,
  sql: Sql,
  logger: Logger,
  env: WorkerEnv,
  options: {
    concurrency?: number;
    pollIntervalMs?: number;
    reconciliationIntervalMs?: number;
  } = {},
): BillingRuntime {
  const definition = queueDefinition("billing-events");
  const prefix = queuePrefix(env.ENVIRONMENT);
  const queueOptions: QueueOptions = {
    prefix,
    defaultJobOptions: defaultJobOptionsFor(definition),
  };
  const dispatch = postgresBillingDispatch(sql);
  const verifiers = billingVerifiersFromEnv(env);
  const processor: Processor = createBillingEventProcessor(
    dispatch,
    verifiers,
    logger,
  );
  const queue = createQueue(definition.name, redisUrl, queueOptions);
  const worker = createWorker(
    definition.name,
    processor,
    redisUrl,
    {
      prefix,
      ...workerOptionsFor(definition),
      concurrency: options.concurrency ?? env.PAY071_OUTBOX_CONCURRENCY,
    },
  );
  const dispatcher = createBillingDispatcher(dispatch, queue, logger, {
    limit: env.PAY071_OUTBOX_CONCURRENCY,
  });
  const reconciliation = env.PAY071_RECONCILIATION_ENABLED
    ? startBillingReconciliation(
      dispatch,
      verifiers,
      logger,
      options.reconciliationIntervalMs ?? 60_000,
    )
    : undefined;
  return {
    queue,
    worker,
    runDispatchOnce: () => dispatcher.runOnce(),
    runReconciliationOnce: async () => {
      if (!reconciliation) return 0;
      return reconciliation.runOnce();
    },
    close: async () => {
      await closeWorker(worker);
      await reconciliation?.close();
      await closeQueue(queue);
    },
  };
}
