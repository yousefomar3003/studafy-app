import { Hono, type MiddlewareHandler } from "hono";
import {
  ErrorCode,
  type ReadinessReasonCode,
  type ServiceInfo,
} from "@studafy/contracts";
import type { Logger } from "@studafy/observability";
import type { AuthorizationEnv } from "../authorization/middleware";
import {
  protocolControls,
  requestContext,
  requestTelemetry,
  secureResponseHeaders,
  totalTimeout,
} from "../platform/middleware";
import { problem, RequestTimeoutError } from "../platform/errors";
import {
  DEFAULT_PLATFORM_LIMITS,
  type PlatformEnv,
  type PlatformLimits,
} from "../platform/types";

export type DependentCheck = () => Promise<void>;

export interface AppDependencies {
  info: ServiceInfo;
  logger: Logger;
  checks: {
    database?: DependentCheck;
    redis?: DependentCheck;
  };
  /**
   * AUTH-030 session lifecycle routes. Absent when the API has no verified
   * token source configured, in which case every /v1 path keeps answering
   * NOT_IMPLEMENTED rather than serving an unauthenticated surface.
   */
  auth?: Hono<AuthorizationEnv>;
  /**
   * OPS-060: pre-auth edge rate limiter mounted on /v1/* ahead of
   * authentication. Absent when limiting is disabled or no Redis is
   * configured in non-production (the limiter then only exists inside the
   * auth router as its bounded local fallback).
   */
  rateLimit?: { edge: MiddlewareHandler };
  /**
   * PAY-071 store webhooks. Mounted ahead of the /v1/* catch-all but
   * deliberately outside `auth` - Apple/Google notifications are the first
   * unauthenticated inbound routes this API serves, verified by JWS/OIDC
   * instead of a bearer token.
   */
  webhooks?: Hono<AppEnv>;
  challengePage?: Hono<AppEnv>;
  platform?: {
    allowedOrigins?: readonly string[];
    limits?: Partial<PlatformLimits>;
    now?: () => number;
  };
}

export interface AppEnv extends PlatformEnv {}

/** Maps an optional dependency to a readiness reason code. */
async function evaluate(
  name: ReadinessReasonCode,
  check: DependentCheck | undefined,
): Promise<ReadinessReasonCode | null> {
  if (!check) return name;
  try {
    await check();
    return null;
  } catch {
    return name;
  }
}

export function createApp(deps: AppDependencies): Hono<AppEnv> {
  const app = new Hono<AppEnv>();
  const limits = { ...DEFAULT_PLATFORM_LIMITS, ...deps.platform?.limits };
  const now = deps.platform?.now ?? Date.now;

  // Extend the existing request-id skeleton with the API-040 platform stack.
  // Ordering follows instructions.md section 7: correlation and protocol
  // controls run before authentication, validation, authorization and use cases.
  app.use("*", requestContext(now));
  app.use("*", secureResponseHeaders(deps.info.environment));
  app.use("*", requestTelemetry(deps.logger, now));
  app.use(
    "*",
    protocolControls({
      logger: deps.logger,
      environment: deps.info.environment,
      allowedOrigins: deps.platform?.allowedOrigins,
      limits,
    }),
  );
  app.use("*", totalTimeout(limits.requestTimeoutMs));

  // OPS-060 edge limiter: IP-scoped pre-auth backstop on the versioned
  // surface only - infrastructure probes stay unthrottled for oracles.
  if (deps.rateLimit) {
    app.use("/v1/*", deps.rateLimit.edge as unknown as MiddlewareHandler);
    app.use("/webhooks/*", deps.rateLimit.edge as unknown as MiddlewareHandler);
  }

  // Liveness: no dependency checks. The process is alive and serving.
  app.get("/healthz", (c) => c.json({ status: "ok" }));

  // Readiness: dependency checks with stable reason codes.
  app.get("/readyz", async (c) => {
    const [database, redis] = await Promise.all([
      evaluate("database_unreachable", deps.checks.database),
      evaluate("redis_unreachable", deps.checks.redis),
    ]);
    const reasons = [database, redis].filter(
      (reason): reason is ReadinessReasonCode => reason !== null,
    );
    if (reasons.length > 0) {
      return c.json({ ready: false, reasons }, 503);
    }
    return c.json({ ready: true, reasons: [] });
  });

  // Service identity. Contains no secrets or configuration values.
  app.get("/version", (c) =>
    c.json({
      service: deps.info.service,
      version: deps.info.version,
      environment: deps.info.environment,
    }));

  if (deps.challengePage) app.route("/", deps.challengePage);

  // AUTH-030 routes mount ahead of the catch-all so migrated paths are
  // served and everything else still fails closed below.
  if (deps.auth) {
    app.route("/", deps.auth as unknown as Hono<AppEnv>);
  }

  if (deps.webhooks) {
    app.route("/", deps.webhooks);
  }

  // The remaining versioned surface is intentionally empty until slices
  // migrate behind reviewed contracts (ARC-011+).
  app.all("/v1/*", (c) => problem(c, ErrorCode.NOT_IMPLEMENTED, 404));

  app.notFound((c) => problem(c, ErrorCode.NOT_FOUND, 404));

  app.onError((error, c) => {
    deps.logger.error("http_error", {
      request_id: c.get("requestId"),
      method: c.req.method,
      route: c.req.routePath || "unmatched",
      error_kind: error instanceof RequestTimeoutError
        ? "timeout"
        : "unexpected",
    });
    return error instanceof RequestTimeoutError
      ? problem(c, ErrorCode.REQUEST_TIMEOUT, 504)
      : problem(c, ErrorCode.INTERNAL_ERROR, 500);
  });

  return app;
}
