import { describeWorkerEnv, loadWorkerEnv } from "./bootstrap/config";
import {
  buildBillingRuntime,
  buildNotificationRuntime,
  buildSmokeRuntime,
} from "./bootstrap/queues";
import {
  createJsonLogger,
  installGracefulShutdown,
  logShutdownStep,
  logStartup,
} from "@studafy/observability";
import { version as workerVersion } from "../package.json";
import { closeDatabase, createDatabase, type Sql } from "@studafy/database";
import {
  assertQueueRedisPosture,
  closeRedis,
  createRedis,
  ExternalMalwareScannerClient,
  FcmPushSender,
  FileSecurityScanner,
  GoogleCalendarConferenceProvider,
  ResendEmailSender,
  SupabasePrivateFileStorage,
} from "@studafy/infrastructure";
import { startFileCleanup } from "./processors/fileCleanup";
import { startFileScan } from "./processors/fileScan";
import { startFileRetentionSweep } from "./processors/retentionSweep";
import { startAccountDeletionExecutor } from "./processors/accountDeletion";
import { startDataExportExecutor } from "./processors/dataExport";
import { startMeetingProcessor } from "./processors/meetings";
import { startChannelDelivery } from "./processors/channelDelivery";

const env = loadWorkerEnv();
const logger = createJsonLogger("worker", workerVersion, env.LOG_LEVEL);

// OPS-061 queue posture: the queue allocation must be non-evicting and
// persisted. Production refuses to start otherwise; development logs what
// it finds so the operator runbook can catch drift early.
const postureRedis = createRedis(env.REDIS_URL, {
  connectTimeout: 3,
  maxRetriesPerRequest: 1,
});
try {
  const posture = await assertQueueRedisPosture(
    postureRedis,
    env.ENVIRONMENT,
  );
  logger.info("queue_redis_posture", {
    maxmemory_policy: posture.maxmemoryPolicy,
    appendonly: posture.appendonly,
    save_policy: posture.save,
  });
} catch (error) {
  if (env.ENVIRONMENT === "production") throw error;
  logger.warn("queue_redis_posture_warning", {
    message: error instanceof Error ? error.message : String(error),
  });
} finally {
  await closeRedis(postureRedis);
}

const activeQueues = env.OPS061_NOTIFICATIONS_ENABLED
  ? ["smoke", "notifications"]
  : ["smoke"];
if (env.PAY071_BILLING_ENABLED) activeQueues.push("billing-events");

logStartup(logger, {
  environment: env.ENVIRONMENT,
  runtime: `bun ${Bun.version}`,
  configuration: describeWorkerEnv(env),
  extra: { queues: activeQueues },
});

const runtime = buildSmokeRuntime(env.REDIS_URL, logger, {
  environment: env.ENVIRONMENT,
});

await runtime.worker.waitUntilReady();
logger.info("worker_ready", { queue: "smoke" });

const fileWorkerSql = env.FILE050_CLEANUP_ENABLED || env.FILE051_SCAN_ENABLED ||
    env.FILE051_RETENTION_ENABLED || env.OPS061_NOTIFICATIONS_ENABLED ||
    env.PAY071_BILLING_ENABLED
  ? createDatabase(env.DATABASE_URL!)
  : undefined;
const storage =
  fileWorkerSql && env.SUPABASE_URL && env.SUPABASE_SERVICE_ROLE_KEY
    ? new SupabasePrivateFileStorage(
      env.SUPABASE_URL,
      env.SUPABASE_SERVICE_ROLE_KEY,
    )
    : undefined;

// Production refuses to start with scanning enabled but no external scanner
// (worker schema fail-closed); local/disposable runs use the deterministic
// structural scanner, which has no egress and no credentials.
const scanner = env.MALWARE_SCANNER_URL && env.MALWARE_SCANNER_API_KEY
  ? new FileSecurityScanner(
    new ExternalMalwareScannerClient({
      url: env.MALWARE_SCANNER_URL,
      apiKey: env.MALWARE_SCANNER_API_KEY,
    }),
  )
  : new FileSecurityScanner();

const cleanup = fileWorkerSql && storage && env.FILE050_CLEANUP_ENABLED
  ? startFileCleanup(fileWorkerSql, storage, logger)
  : undefined;
const scan = fileWorkerSql && storage && env.FILE051_SCAN_ENABLED
  ? startFileScan(fileWorkerSql, storage, scanner, logger)
  : undefined;
const retention = fileWorkerSql && storage && env.FILE051_RETENTION_ENABLED
  ? startFileRetentionSweep(fileWorkerSql, storage, logger)
  : undefined;

// OPS-061: the transactional outbox drain. The dispatcher polls the
// notification outbox on an interval; the notifications worker processes the
// BullMQ jobs it produces.
const outboxSql: Sql | undefined = env.OPS061_NOTIFICATIONS_ENABLED
  ? (fileWorkerSql ?? createDatabase(env.DATABASE_URL!))
  : undefined;
const notifications = outboxSql
  ? buildNotificationRuntime(env.REDIS_URL, outboxSql, logger, {
    environment: env.ENVIRONMENT,
    concurrency: env.OPS061_OUTBOX_CONCURRENCY,
  })
  : undefined;
if (notifications) {
  await notifications.worker.waitUntilReady();
  logger.info("worker_ready", { queue: "notifications" });
}

const outboxTimer = notifications
  ? setInterval(() => {
    notifications.runDispatchOnce().catch((error) => {
      logger.error("outbox_dispatch_poll_failed", {
        error_name: error instanceof Error ? error.name : "unknown",
      });
    });
  }, env.OPS061_OUTBOX_POLL_INTERVAL_MS)
  : undefined;
// First dispatch runs immediately: a restart must not wait a poll interval
// to pick up where a previous dispatcher left off.
if (notifications) {
  notifications.runDispatchOnce().catch(() => undefined);
}

// PAY-071: the store-event drain. The dispatcher polls due `store_events`
// rows and enqueues deterministic `billing-events` jobs; the processor
// re-verifies against Apple/Google and converges the ledger. The
// reconciliation sweep is the loss backstop (re-verify open transactions +
// the Google 3-day acknowledgement window).
const billingSql: Sql | undefined = env.PAY071_BILLING_ENABLED
  ? (fileWorkerSql ?? createDatabase(env.DATABASE_URL!))
  : undefined;
const billing = billingSql
  ? buildBillingRuntime(env.REDIS_URL, billingSql, logger, env)
  : undefined;
if (billing) {
  await billing.worker.waitUntilReady();
  logger.info("worker_ready", { queue: "billing-events" });
}

const billingDispatchTimer = billing
  ? setInterval(() => {
    billing.runDispatchOnce().catch((error) => {
      logger.error("billing_dispatch_poll_failed", {
        error_name: error instanceof Error ? error.name : "unknown",
      });
    });
  }, env.PAY071_OUTBOX_POLL_INTERVAL_MS)
  : undefined;
if (billing) {
  billing.runDispatchOnce().catch(() => undefined);
}
if (billing && env.PAY071_RECONCILIATION_ENABLED) {
  billing.runReconciliationOnce().catch(() => undefined);
}

// DL-051 account rights: execute deletions whose grace period ended and
// build requested data exports. The request rows are the durable queue.
const accountRightsSql: Sql | undefined =
  env.ACCOUNT_DELETION_EXECUTOR_ENABLED || env.DATA_EXPORT_EXECUTOR_ENABLED
    ? (fileWorkerSql ?? createDatabase(env.DATABASE_URL!))
    : undefined;
const accountDeletion =
  accountRightsSql && env.ACCOUNT_DELETION_EXECUTOR_ENABLED
    ? startAccountDeletionExecutor(
      accountRightsSql,
      logger,
      env.ACCOUNT_RIGHTS_POLL_INTERVAL_MS,
    )
    : undefined;
const dataExport = accountRightsSql && env.DATA_EXPORT_EXECUTOR_ENABLED
  ? startDataExportExecutor(
    accountRightsSql,
    logger,
    env.ACCOUNT_RIGHTS_POLL_INTERVAL_MS,
  )
  : undefined;

// DL-052: schedule requested meetings with the conferencing provider.
const meetingsSql: Sql | undefined = env.MEETINGS_PROCESSOR_ENABLED
  ? (fileWorkerSql ?? createDatabase(env.DATABASE_URL!))
  : undefined;
const meetings = meetingsSql
  ? startMeetingProcessor(
    meetingsSql,
    new GoogleCalendarConferenceProvider({
      serviceAccountJson: env.GOOGLE_CALENDAR_SERVICE_ACCOUNT_JSON!,
      organizerEmail: env.GOOGLE_CALENDAR_ORGANIZER_EMAIL!,
    }),
    logger,
  )
  : undefined;

// DL-053: email and push delivery for channels with a configured provider.
const channelsSql: Sql | undefined = env.NOTIFICATION_CHANNELS_ENABLED
  ? (fileWorkerSql ?? createDatabase(env.DATABASE_URL!))
  : undefined;
const channels = channelsSql
  ? startChannelDelivery(
    channelsSql,
    {
      email: env.RESEND_API_KEY && env.EMAIL_FROM_ADDRESS
        ? new ResendEmailSender({
          apiKey: env.RESEND_API_KEY,
          from: env.EMAIL_FROM_ADDRESS,
        })
        : undefined,
      push: env.FCM_PROJECT_ID && env.FCM_SERVICE_ACCOUNT_JSON
        ? new FcmPushSender({
          projectId: env.FCM_PROJECT_ID,
          serviceAccountJson: env.FCM_SERVICE_ACCOUNT_JSON,
        })
        : undefined,
    },
    logger,
  )
  : undefined;

installGracefulShutdown({
  logger,
  onClose: async () => {
    logShutdownStep(logger, "drain_workers", { queue: "smoke" });
    // Stop the producer before draining consumers: no new claims enqueue.
    if (outboxTimer) clearInterval(outboxTimer);
    if (billingDispatchTimer) clearInterval(billingDispatchTimer);
    await notifications?.close();
    await billing?.close();
    await scan?.close();
    await retention?.close();
    await cleanup?.close();
    await accountDeletion?.close();
    await dataExport?.close();
    await meetings?.close();
    await channels?.close();
    if (channelsSql && channelsSql !== fileWorkerSql) {
      await closeDatabase(channelsSql);
    }
    if (meetingsSql && meetingsSql !== fileWorkerSql) {
      await closeDatabase(meetingsSql);
    }
    if (accountRightsSql && accountRightsSql !== fileWorkerSql) {
      await closeDatabase(accountRightsSql);
    }
    if (billingSql && billingSql !== fileWorkerSql) {
      await closeDatabase(billingSql);
    }
    if (outboxSql && outboxSql !== fileWorkerSql) {
      await closeDatabase(outboxSql);
    }
    if (fileWorkerSql) await closeDatabase(fileWorkerSql);
    await runtime.close();
  },
});
