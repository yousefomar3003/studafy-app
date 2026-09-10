import { loadWorkerEnv, describeWorkerEnv } from "./bootstrap/config";
import { buildSmokeRuntime } from "./bootstrap/queues";
import {
  createJsonLogger,
  installGracefulShutdown,
  logShutdownStep,
  logStartup,
} from "@studafy/observability";
import { version as workerVersion } from "../package.json";

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

installGracefulShutdown({
  logger,
  onClose: async () => {
    logShutdownStep(logger, "drain_workers", { queue: "smoke" });
    await runtime.close();
  },
});
