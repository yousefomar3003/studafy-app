import { createTurnstilePage } from "./turnstile/page";
import { createApp } from "./bootstrap/app";
import { createAuthRoutes } from "./auth/routes";
import { rateLimitAuto, rateLimitEdge } from "./platform/rate-limit/middleware";
import { closeRedis } from "@studafy/infrastructure";
import { closeDatabase } from "@studafy/database";
import { installGracefulShutdown, logListening } from "@studafy/observability";
import { version as apiVersion } from "../package.json";
import { buildPlatform } from "./composition/platform";
import { buildRoutes } from "./composition/routes";

// The API process: build the platform, then the modules on it, then serve.
const platform = buildPlatform();
const {
  env,
  cloudwatch,
  logger,
  sql,
  redis,
  databaseCheck,
  redisCheck,
  rateLimitDependencies,
  authorization,
  idempotencyDependencies,
  authDependencies,
} = platform;
const { combinedRoutes, turnstile, billingWebhooks } = buildRoutes(platform);

const auth = authDependencies
  ? createAuthRoutes(
    authDependencies,
    authorization,
    idempotencyDependencies,
    combinedRoutes,
    env.RATE_LIMIT_ENABLED ? rateLimitAuto(rateLimitDependencies) : undefined,
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
    identity: {
      // Same key and trust posture the rate limiter already uses, so one
      // client hashes identically in both places.
      ...(env.RATE_LIMIT_HMAC_SIGNING_KEY
        ? { hmacKey: env.RATE_LIMIT_HMAC_SIGNING_KEY }
        : {}),
      trustCloudflare: env.ENVIRONMENT === "production",
    },
  },
  ...(env.RATE_LIMIT_ENABLED
    ? { rateLimit: { edge: rateLimitEdge(rateLimitDependencies) } }
    : {}),
  ...(auth ? { auth } : {}),
  ...(turnstile ? { challengePage: createTurnstilePage(turnstile) } : {}),
  ...(billingWebhooks ? { webhooks: billingWebhooks } : {}),
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
    // Last, so shutdown logging from the steps above is included in the final
    // batch rather than lost with the process.
    if (cloudwatch) {
      cloudwatch.close();
      await cloudwatch.flush();
    }
  },
});
