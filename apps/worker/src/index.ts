import { describeWorkerEnv, loadWorkerEnv } from "./bootstrap/config";
import { buildSmokeRuntime } from "./bootstrap/queues";
import {
  createJsonLogger,
  installGracefulShutdown,
  logShutdownStep,
  logStartup,
} from "@studafy/observability";
import { version as workerVersion } from "../package.json";
import { closeDatabase, createDatabase } from "@studafy/database";
import {
  ExternalMalwareScannerClient,
  FileSecurityScanner,
  SupabasePrivateFileStorage,
} from "@studafy/infrastructure";
import { startFileCleanup } from "./processors/fileCleanup";
import { startFileScan } from "./processors/fileScan";
import { startFileRetentionSweep } from "./processors/retentionSweep";

const env = loadWorkerEnv();
const logger = createJsonLogger("worker", workerVersion, env.LOG_LEVEL);

logStartup(logger, {
  environment: env.ENVIRONMENT,
  runtime: `bun ${Bun.version}`,
  configuration: describeWorkerEnv(env),
  extra: { queues: ["smoke"] },
});

const runtime = buildSmokeRuntime(env.REDIS_URL, logger, {
  environment: env.ENVIRONMENT,
});

await runtime.worker.waitUntilReady();
logger.info("worker_ready", { queue: "smoke" });

const fileWorkerSql = env.FILE050_CLEANUP_ENABLED || env.FILE051_SCAN_ENABLED ||
    env.FILE051_RETENTION_ENABLED
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

installGracefulShutdown({
  logger,
  onClose: async () => {
    logShutdownStep(logger, "drain_workers", { queue: "smoke" });
    await scan?.close();
    await retention?.close();
    await cleanup?.close();
    if (fileWorkerSql) await closeDatabase(fileWorkerSql);
    await runtime.close();
  },
});
