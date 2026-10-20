import { describeApiEnv, loadApiEnv } from "../bootstrap/config";
import { type DependentCheck } from "../bootstrap/app";
import {
  authIssuer,
  authJwksUrl,
  usesPrivilegedDatabaseRole,
} from "@studafy/config";
import { AuthContextRepository } from "../auth/context";
import { JwksKeySource } from "../auth/jwks";
import { PostgresAuthorizationRepository } from "../authorization/repository";
import { createAuthorizationDependencies } from "../authorization/middleware";
import { PostgresIdempotencyRepository } from "../platform/idempotency";
import { createRedactingLogger } from "../platform/logging";
import { RedisAuthContextCache } from "../platform/cache/authContextCache";
import { createRateLimitDependencies } from "../platform/rate-limit/middleware";
import {
  checkRedis,
  createRedis,
  createSentryReporter,
  isPlaintextRemoteRedis,
  releaseId,
  SupabaseManagedAccountIssuer,
  SupabasePrivateFileStorage,
} from "@studafy/infrastructure";
import { checkDatabase, createDatabase } from "@studafy/database";
import {
  createJsonLogger,
  createLogSampler,
  logStartup,
} from "@studafy/observability";
import { version as apiVersion } from "../../package.json";

/**
 * Everything the API's modules are built on: configuration, logging, the
 * database and Redis clients, and the authentication, authorization,
 * idempotency and rate-limit dependencies. Built once at startup.
 */
export function buildPlatform() {
  const env = loadApiEnv();

  // OPS-090: unexpected errors to Sentry when a DSN is set, with nothing
  // personal in them.
  const release = releaseId(apiVersion);
  const errorReporter = env.SENTRY_DSN
    ? createSentryReporter({
      dsn: env.SENTRY_DSN,
      environment: env.ENVIRONMENT,
      release,
      service: "api",
    })
    : undefined;

  const logger = createRedactingLogger(
    createJsonLogger(
      "api",
      apiVersion,
      env.LOG_LEVEL,
      (line) => {
        console.log(line);
        // Error-level lines only; the reporter ignores the rest.
        errorReporter?.captureLogLine(line);
      },
      createLogSampler({
        successRate: env.LOG_SAMPLE_SUCCESS_RATE,
        routineRate: env.LOG_SAMPLE_ROUTINE_RATE,
        slowRequestMs: env.LOG_SLOW_REQUEST_MS,
      }),
      // The test copy and production ship to one Axiom dataset; every line
      // says which it came from, and which deploy (launch plan 4.7).
    ).child({ environment: env.ENVIRONMENT, release }),
  );

  logStartup(logger, {
    environment: env.ENVIRONMENT,
    runtime: `bun ${Bun.version}`,
    configuration: describeApiEnv(env),
  });

  const sql = env.DATABASE_URL
    ? createDatabase(env.DATABASE_URL, {
      max: env.DATABASE_POOL_MAX,
      // Session mode moves a 6543 pooler URL to 5432 (packages/config,
      // databasePooler.ts); the startup log's database_connection shows it.
      poolerMode: env.DATABASE_POOLER_MODE,
      ...(env.DATABASE_CA_CERT ? { caCert: env.DATABASE_CA_CERT } : {}),
    })
    : undefined;
  if (usesPrivilegedDatabaseRole(env.DATABASE_URL)) {
    // Production refuses this; elsewhere it runs, but outside ADR-0014's
    // least-privilege boundary (RLS bypassed, every table writable).
    logger.warn("database_privileged_role", { environment: env.ENVIRONMENT });
  }
  const redis = env.REDIS_URL ? createRedis(env.REDIS_URL) : undefined;
  if (env.REDIS_URL && isPlaintextRemoteRedis(env.REDIS_URL)) {
    // Production refuses this outright; elsewhere it is allowed but loud:
    // the Redis password and every key cross the network in clear.
    logger.warn("redis_plaintext_remote", { environment: env.ENVIRONMENT });
  }

  const databaseCheck: DependentCheck | undefined = sql
    ? () => checkDatabase(sql)
    : undefined;
  const redisCheck: DependentCheck | undefined = redis
    ? () => checkRedis(redis)
    : undefined;

  // OPS-060. Rate limiting and the revocation-safe session-context cache share
  // one Redis client; production is required to configure the HMAC secret
  // (enforceApiFailClosed), development mints an ephemeral one for the boot so
  // no identifier is ever stored raw in a Redis key either way.
  const ephemeralSecret = env.RATE_LIMIT_HMAC_SIGNING_KEY == null &&
    env.RATE_LIMIT_ENABLED;
  if (ephemeralSecret) {
    logger.warn("rate_limit_hmac_ephemeral", {
      environment: env.ENVIRONMENT,
    });
  }
  const rateLimitSecret = env.RATE_LIMIT_HMAC_SIGNING_KEY ??
    `${crypto.randomUUID()}${crypto.randomUUID()}`;
  const rateLimitDependencies = createRateLimitDependencies({
    enabled: env.RATE_LIMIT_ENABLED,
    secret: rateLimitSecret,
    redis: redis ?? null,
    logger,
    clientIpSource: env.CLIENT_IP_SOURCE,
  });

  // The session-context cache: version-keyed (membershipVersion, revocation
  // watermark, profile state ride along in the generation), TTL clamped to
  // min(30s, AUTH_REVOCATION_BUDGET_SECONDS), failing back to the DB loader
  // whenever Redis cannot serve.
  const authContextCache = env.RATE_LIMIT_ENABLED && redis
    ? new RedisAuthContextCache(redis, rateLimitSecret, {
      environment: env.ENVIRONMENT,
      budgetSeconds: env.AUTH_REVOCATION_BUDGET_SECONDS,
    })
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

  // Built ahead of the route modules below so school-admin (closeSchool,
  // suspendSchool) and account (requestDataExport) can require the same
  // recent-auth/AAL2 grants AUTH-030's own routes require, instead of each
  // carrying a separate, easy-to-diverge copy of these settings.
  const authDependencies = sql && env.SUPABASE_URL
    ? {
      keys: new JwksKeySource(authJwksUrl(env.SUPABASE_URL)),
      repository: new AuthContextRepository(sql, authContextCache),
      logger,
      issuer: authIssuer(env.SUPABASE_URL),
      audience: env.AUTH_JWT_AUDIENCE,
      clockSkewSeconds: env.AUTH_CLOCK_SKEW_SECONDS,
      revocationBudgetSeconds: env.AUTH_REVOCATION_BUDGET_SECONDS,
      reauthTtlSeconds: env.AUTH_REAUTH_TTL_SECONDS,
      recentSignInSeconds: env.AUTH_RECENT_SIGN_IN_SECONDS,
      deletionGraceDays: env.AUTH_DELETION_GRACE_DAYS,
      // Development alone signs in against the hosted project while keeping
      // DATABASE_URL on local Postgres, so it alone needs profiles created on
      // first sight. Staging and production read the issuer's own database,
      // where the signup trigger has already done it.
      provisionUnknownSubjects: env.ENVIRONMENT === "development",
    }
    : undefined;
  // Commands that hand an account its first membership live in other
  // dispatchers, so they need this to clear the session context cached while
  // that account still belonged nowhere. Undefined without an auth repository,
  // in which case nothing is cached either.
  const invalidateActorContext = authDependencies
    ? (subject: string) =>
      authDependencies.repository.invalidateContext(subject)
    : undefined;

  // FILE-050 uses the service role only inside the isolated storage adapter.
  // Database authorization and mutation still run as studafy_api_runtime via
  // the narrow private.api050_* surface. With no key the routes do not mount.
  // STORAGE_URL and its key only in the development split; everywhere else
  // they are unset and the files live in the SUPABASE_URL project.
  const storageUrl = env.STORAGE_URL ?? env.SUPABASE_URL;
  const storageKey = env.STORAGE_SERVICE_ROLE_KEY ??
    env.SUPABASE_SERVICE_ROLE_KEY;
  // One client for every module that reads private files (uploads and
  // whiteboard photos); null when no storage credential is configured.
  const privateStorage = storageUrl && storageKey
    ? new SupabasePrivateFileStorage(storageUrl, storageKey)
    : null;

  // Managed child accounts use Supabase Auth's admin API in the project that
  // issues identities - SUPABASE_URL, never the storage split above.
  const managedAccountIssuer = env.SUPABASE_URL && env.SUPABASE_SERVICE_ROLE_KEY
    ? new SupabaseManagedAccountIssuer(
      env.SUPABASE_URL,
      env.SUPABASE_SERVICE_ROLE_KEY,
    )
    : null;

  return {
    env,
    errorReporter,
    logger,
    sql,
    redis,
    databaseCheck,
    redisCheck,
    rateLimitDependencies,
    authContextCache,
    authorization,
    idempotencyDependencies,
    authDependencies,
    invalidateActorContext,
    privateStorage,
    managedAccountIssuer,
  };
}

export type Platform = ReturnType<typeof buildPlatform>;
