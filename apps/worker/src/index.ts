import { describeWorkerEnv, loadWorkerEnv } from "./bootstrap/config";
import { usesPrivilegedDatabaseRole } from "@studafy/config";
import {
  buildBillingRuntime,
  buildNotificationRuntime,
  buildSmokeRuntime,
} from "./bootstrap/queues";
import {
  createJsonLogger,
  createLogSampler,
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
  createSentryReporter,
  createStudyAssistant,
  ExternalMalwareScannerClient,
  FcmPushSender,
  FileSecurityScanner,
  GoogleCalendarConferenceProvider,
  isPlaintextRemoteRedis,
  ResendEmailSender,
  SupabasePrivateFileStorage,
} from "@studafy/infrastructure";
import { startFileCleanup } from "./processors/fileCleanup";
import { startFileScan } from "./processors/fileScan";
import {
  postgresMaterialQueue,
  startMaterialIndex,
} from "./processors/materialIndex";
import { startFileRetentionSweep } from "./processors/retentionSweep";
import { startAccountDeletionExecutor } from "./processors/accountDeletion";
import { startDataExportExecutor } from "./processors/dataExport";
import { startMeetingProcessor } from "./processors/meetings";
import { startChannelDelivery } from "./processors/channelDelivery";
import { startHousekeeping } from "./processors/housekeeping";

const env = loadWorkerEnv();
// OPS-090: failed jobs and polls reach Sentry when a DSN is set, grouped
// by event; routine "job done" lines are sampled in production.
const errorReporter = env.SENTRY_DSN
  ? createSentryReporter({
    dsn: env.SENTRY_DSN,
    environment: env.ENVIRONMENT,
    release: workerVersion,
    service: "worker",
  })
  : undefined;
const logger = createJsonLogger(
  "worker",
  workerVersion,
  env.LOG_LEVEL,
  (line) => {
    console.log(line);
    errorReporter?.captureLogLine(line);
  },
  createLogSampler({
    successRate: env.LOG_SAMPLE_SUCCESS_RATE,
    routineRate: env.LOG_SAMPLE_ROUTINE_RATE,
    slowRequestMs: env.LOG_SLOW_REQUEST_MS,
  }),
);

// OPS-061 queue posture: the queue allocation must be non-evicting and
// persisted. Production refuses to start otherwise; development logs what
// it finds so the operator runbook can catch drift early.
if (usesPrivilegedDatabaseRole(env.DATABASE_URL)) {
  // Production refuses this; elsewhere it runs outside ADR-0014's
  // least-privilege boundary.
  logger.warn("database_privileged_role", { environment: env.ENVIRONMENT });
}
if (isPlaintextRemoteRedis(env.REDIS_URL)) {
  // Production refuses this (enforceWorkerFailClosed); elsewhere it is
  // allowed but loud: queue jobs and the password cross the network in clear.
  logger.warn("redis_plaintext_remote", { environment: env.ENVIRONMENT });
}
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

// One pool for every job that needs the database, opened on first use: the
// jobs run on one process against one database, and one pool is one thing to
// size and to close.
let sharedSql: Sql | undefined;
function database(): Sql {
  sharedSql ??= createDatabase(env.DATABASE_URL!, {
    max: env.DATABASE_POOL_MAX,
    ...(env.DATABASE_CA_CERT ? { caCert: env.DATABASE_CA_CERT } : {}),
  });
  return sharedSql;
}

const fileWorkerSql = env.FILE050_CLEANUP_ENABLED || env.FILE051_SCAN_ENABLED ||
    env.FILE051_RETENTION_ENABLED || env.AI_MATERIAL_INDEX_ENABLED ||
    env.OPS061_NOTIFICATIONS_ENABLED ||
    env.PAY071_BILLING_ENABLED
  ? database()
  : undefined;
const storage = fileWorkerSql && (env.STORAGE_URL ?? env.SUPABASE_URL) &&
    (env.STORAGE_SERVICE_ROLE_KEY ?? env.SUPABASE_SERVICE_ROLE_KEY)
  // The same storage the API issued upload capabilities for, or the scan
  // would look for bytes in a project that never received them.
  ? new SupabasePrivateFileStorage(
    (env.STORAGE_URL ?? env.SUPABASE_URL)!,
    (env.STORAGE_SERVICE_ROLE_KEY ?? env.SUPABASE_SERVICE_ROLE_KEY)!,
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

// ADR-0037: lesson files and links read for the study helper. The model
// reads scanned pages and pictures only behind the same switch as every
// other path that sends lesson material to the provider (ADR-0029).
const materialReader = env.AI_API_KEY && env.AI_BASE_URL &&
    env.AI_LESSON_TOOLS_ENABLED
  ? createStudyAssistant({
    apiKey: env.AI_API_KEY,
    baseUrl: env.AI_BASE_URL,
    model: env.AI_MODEL,
    maxLongOutputTokens: 1_800,
    timeoutMs: 60_000,
  })
  : null;
const materialIndex = fileWorkerSql && storage && env.AI_MATERIAL_INDEX_ENABLED
  ? startMaterialIndex({
    queue: postgresMaterialQueue(fileWorkerSql),
    storage,
    assistant: materialReader,
    limits: {
      ocrPagesPerFile: 60,
      textPagesPerFile: 500,
      charsPerDocument: 600_000,
      linkMaxBytes: 3_000_000,
    },
    prices: {
      inputUsdPerMTok: env.AI_PRICE_INPUT_USD_PER_MTOK,
      outputUsdPerMTok: env.AI_PRICE_OUTPUT_USD_PER_MTOK,
    },
    logger,
  }, env.AI_MATERIAL_POLL_INTERVAL_MS)
  : undefined;

// OPS-061: the transactional outbox drain. The dispatcher polls the
// notification outbox on an interval; the notifications worker processes the
// BullMQ jobs it produces.
const outboxSql: Sql | undefined = env.OPS061_NOTIFICATIONS_ENABLED
  ? database()
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
  ? database()
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
    ? database()
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
  ? database()
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
  ? database()
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

// Tables that grow with every request are kept to their live rows.
const housekeeping = env.DB_HOUSEKEEPING_ENABLED && env.DATABASE_URL
  ? startHousekeeping(database(), logger)
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
    await materialIndex?.close();
    await cleanup?.close();
    await accountDeletion?.close();
    await dataExport?.close();
    await meetings?.close();
    await channels?.close();
    await housekeeping?.close();
    if (sharedSql) await closeDatabase(sharedSql);
    await runtime.close();
    await errorReporter?.flush();
  },
});
