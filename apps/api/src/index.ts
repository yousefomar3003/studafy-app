import { describeApiEnv, loadApiEnv } from "./bootstrap/config";
import { createApp, type DependentCheck } from "./bootstrap/app";
import { authIssuer, authJwksUrl } from "@studafy/config";
import { AuthContextRepository } from "./auth/context";
import { JwksKeySource } from "./auth/jwks";
import { createAuthRoutes } from "./auth/routes";
import { PostgresAuthorizationRepository } from "./authorization/repository";
import { createAuthorizationDependencies } from "./authorization/middleware";
import { PostgresIdempotencyRepository } from "./platform/idempotency";
import { createRedactingLogger } from "./platform/logging";
import { createAcademicRoutes } from "./academic/routes";
import { PostgresAcademicRepository } from "./academic/repository";
import {
  checkDatabase,
  closeDatabase,
  createDatabase,
} from "@studafy/database";
import { checkRedis, closeRedis, createRedis } from "@studafy/infrastructure";
import {
  createJsonLogger,
  installGracefulShutdown,
  logListening,
  logStartup,
} from "@studafy/observability";
import { version as apiVersion } from "../package.json";

const env = loadApiEnv();
const logger = createRedactingLogger(
  createJsonLogger("api", apiVersion, env.LOG_LEVEL),
);

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

// AUTH-030 needs both a verified token source and a database. Without either
// the auth routes are not mounted at all, so /v1 keeps answering
// NOT_IMPLEMENTED instead of exposing handlers that cannot authenticate.
const authorization = createAuthorizationDependencies(
  logger,
  sql ? new PostgresAuthorizationRepository(sql) : undefined,
);
const idempotencyDependencies = {
  logger,
  ...(sql ? { repository: new PostgresIdempotencyRepository(sql) } : {}),
};
const academic = sql && env.API_CURSOR_SIGNING_KEY
  ? createAcademicRoutes(
    {
      repository: new PostgresAcademicRepository(sql),
      cursorSigningKey: env.API_CURSOR_SIGNING_KEY,
      enabledSlices: {
        classes: env.API041_CLASSES_ENABLED,
        content: env.API041_CONTENT_ENABLED,
        assignments: env.API041_ASSIGNMENTS_ENABLED,
        assessments: env.API041_ASSESSMENTS_ENABLED,
        grades: env.API041_GRADES_ENABLED,
        attendance: env.API041_ATTENDANCE_ENABLED,
        wellbeing: env.API041_WELLBEING_ENABLED,
      },
    },
    authorization,
    idempotencyDependencies,
  )
  : undefined;

const auth = sql && env.SUPABASE_URL
  ? createAuthRoutes(
    {
      keys: new JwksKeySource(authJwksUrl(env.SUPABASE_URL)),
      repository: new AuthContextRepository(sql),
      logger,
      issuer: authIssuer(env.SUPABASE_URL),
      audience: env.AUTH_JWT_AUDIENCE,
      clockSkewSeconds: env.AUTH_CLOCK_SKEW_SECONDS,
      revocationBudgetSeconds: env.AUTH_REVOCATION_BUDGET_SECONDS,
      reauthTtlSeconds: env.AUTH_REAUTH_TTL_SECONDS,
      deletionGraceDays: env.AUTH_DELETION_GRACE_DAYS,
    },
    authorization,
    idempotencyDependencies,
    academic,
  )
  : undefined;

if (!auth) {
  logger.warn("auth_routes_disabled", {
    reason: !env.SUPABASE_URL ? "supabase_url_missing" : "database_missing",
  });
}

const app = createApp({
  info: {
    service: "api",
    version: apiVersion,
    environment: env.ENVIRONMENT,
  },
  logger,
  checks: { database: databaseCheck, redis: redisCheck },
  platform: {
    allowedOrigins: env.API_ALLOWED_ORIGINS,
    limits: {
      maxBodyBytes: env.API_MAX_BODY_BYTES,
      requestTimeoutMs: env.API_REQUEST_TIMEOUT_MS,
    },
  },
  ...(auth ? { auth } : {}),
});

const server = Bun.serve({
  port: env.API_PORT,
  maxRequestBodySize: env.API_MAX_BODY_BYTES,
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
