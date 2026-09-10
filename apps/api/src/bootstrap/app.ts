import { Hono } from "hono";
import {
  ErrorCode,
  type ReadinessReasonCode,
  type ServiceInfo,
} from "@studafy/contracts";
import type { Logger } from "@studafy/observability";

export type DependentCheck = () => Promise<void>;

export interface AppDependencies {
  info: ServiceInfo;
  logger: Logger;
  checks: {
    database?: DependentCheck;
    redis?: DependentCheck;
  };
}

export interface AppEnv {
  Variables: { requestId: string };
}

function errorBody(
  code: string,
  message: string,
  requestId: string,
): { error: { code: string; message: string; request_id: string } } {
  return { error: { code, message, request_id: requestId } };
}

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

  // Every request gets a server-generated request id; inbound ids are not
  // trusted, so clients cannot spoof correlation identifiers.
  app.use("*", async (c, next) => {
    const requestId = globalThis.crypto.randomUUID();
    c.set("requestId", requestId);
    await next();
    c.header("X-Request-ID", requestId);
  });

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

  // The versioned public API surface is intentionally empty until slices
  // migrate behind reviewed contracts (ARC-011+).
  app.all("/v1/*", (c) =>
    c.json(
      errorBody(
        ErrorCode.NOT_IMPLEMENTED,
        "No /v1 resources are implemented yet.",
        c.get("requestId"),
      ),
      404,
    ));

  app.notFound((c) =>
    c.json(
      errorBody(
        ErrorCode.NOT_FOUND,
        "No such resource.",
        c.get("requestId"),
      ),
      404,
    )
  );

  app.onError((error, c) => {
    deps.logger.error("http_error", {
      request_id: c.get("requestId"),
      method: c.req.method,
      path: c.req.path,
      error_message: error instanceof Error ? error.message : String(error),
    });
    return c.json(
      errorBody(
        ErrorCode.INTERNAL_ERROR,
        "An unexpected error occurred.",
        c.get("requestId"),
      ),
      500,
    );
  });

  return app;
}
