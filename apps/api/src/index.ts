import { loadApiEnv, describeApiEnv } from "./bootstrap/config";
import { createApp, type DependentCheck } from "./bootstrap/app";
import {
  checkDatabase,
  closeDatabase,
  createDatabase,
} from "@studafy/database";
import {
  checkRedis,
  closeRedis,
  createRedis,
} from "@studafy/infrastructure";
import {
  createJsonLogger,
  installGracefulShutdown,
  logListening,
  logStartup,
} from "@studafy/observability";
import { version as apiVersion } from "../package.json";

const env = loadApiEnv();
const logger = createJsonLogger("api", apiVersion, env.LOG_LEVEL);

logStartup(logger, {
  environment: env.ENVIRONMENT,
  runtime: `bun ${Bun.version}`,
  configuration: describeApiEnv(env),
});

const sql = env.DATABASE_URL ? createDatabase(env.DATABASE_URL) : undefined;
const redis = env.REDIS_URL ? createRedis(env.REDIS_URL) : undefined;

const databaseCheck: DependentCheck | undefined = sql
  ? () => checkDatabase(sql)
  : undefined;
const redisCheck: DependentCheck | undefined = redis
  ? () => checkRedis(redis)
  : undefined;

const app = createApp({
  info: {
    service: "api",
    version: apiVersion,
    environment: env.ENVIRONMENT,
  },
  logger,
  checks: { database: databaseCheck, redis: redisCheck },
});

const server = Bun.serve({
  port: env.API_PORT,
  fetch: app.fetch,
});

logListening(logger, { port: server.port ?? env.API_PORT });

installGracefulShutdown({
  logger,
  onClose: async () => {
    server.stop(false);
    if (sql) await closeDatabase(sql);
    if (redis) await closeRedis(redis);
  },
});
