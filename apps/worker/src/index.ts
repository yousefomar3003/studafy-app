import { describeWorkerEnv, loadWorkerEnv } from "./bootstrap/config";
import {
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
  FileSecurityScanner,
  SupabasePrivateFileStorage,
} from "@studafy/infrastructure";
import { startFileCleanup } from "./processors/fileCleanup";
import { startFileScan } from "./processors/fileScan";
import { startFileRetentionSweep } from "./processors/retentionSweep";

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
    env.FILE051_RETENTION_ENABLED || env.OPS061_NOTIFICATIONS_ENABLED
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

installGracefulShutdown({
  logger,
  onClose: async () => {
    logShutdownStep(logger, "drain_workers", { queue: "smoke" });
    // Stop the producer before draining consumers: no new claims enqueue.
    if (outboxTimer) clearInterval(outboxTimer);
    await notifications?.close();
    await scan?.close();
    await retention?.close();
    await cleanup?.close();
    if (outboxSql && outboxSql !== fileWorkerSql) {
      await closeDatabase(outboxSql);
    }
    if (fileWorkerSql) await closeDatabase(fileWorkerSql);
    await runtime.close();
  },
});
