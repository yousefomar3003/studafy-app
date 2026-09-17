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
import { SupabasePrivateFileStorage } from "@studafy/infrastructure";
import { startFileCleanup } from "./processors/fileCleanup";

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

const cleanupSql = env.FILE050_CLEANUP_ENABLED
  ? createDatabase(env.DATABASE_URL!)
  : undefined;
const cleanup = cleanupSql
  ? startFileCleanup(
    cleanupSql,
    new SupabasePrivateFileStorage(
      env.SUPABASE_URL!,
      env.SUPABASE_SERVICE_ROLE_KEY!,
    ),
    logger,
  )
  : undefined;

installGracefulShutdown({
  logger,
  onClose: async () => {
    logShutdownStep(logger, "drain_workers", { queue: "smoke" });
    await cleanup?.close();
    if (cleanupSql) await closeDatabase(cleanupSql);
    await runtime.close();
  },
});
