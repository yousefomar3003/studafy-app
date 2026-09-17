import type { MiddlewareHandler } from "hono";
import type { EnvironmentType } from "@studafy/config";
import type { Logger } from "@studafy/observability";
import { problem } from "./errors";
import {
  DEFAULT_PLATFORM_LIMITS,
  type PlatformEnv,
  type PlatformLimits,
} from "./types";

const METHODS = new Set(["GET", "HEAD", "POST", "OPTIONS"]);
const SINGLETON_HEADERS = [
  "authorization",
  "content-length",
  "content-type",
  "idempotency-key",
  "x-studafy-device",
  "x-studafy-reauth",
] as const;

export interface PlatformMiddlewareOptions {
  logger: Logger;
  environment: EnvironmentType;
  allowedOrigins?: readonly string[];
  limits?: Partial<PlatformLimits>;
  now?: () => number;
}

export function requestContext(
  now: () => number = Date.now,
): MiddlewareHandler<PlatformEnv> {
  return async (c, next) => {
    c.set("requestId", crypto.randomUUID());
    c.set("requestStartedAt", now());
    c.set("abortSignal", new AbortController().signal);
    try {
      await next();
    } finally {
      c.header("X-Request-ID", c.get("requestId"));
    }
  };
}

export function secureResponseHeaders(
  environment: EnvironmentType,
): MiddlewareHandler<PlatformEnv> {
  return async (c, next) => {
    try {
      await next();
    } finally {
      c.header("Cache-Control", "no-store");
      // FILE-051 delivery responses carry a stricter, sandboxed policy of
      // their own; every other response gets the platform default.
      if (
        !c.res.headers.get("Content-Security-Policy")?.startsWith("sandbox")
      ) {
        c.header(
          "Content-Security-Policy",
          "default-src 'none'; frame-ancestors 'none'; base-uri 'none'",
        );
      }
      c.header(
        "Permissions-Policy",
        "camera=(), microphone=(), geolocation=(), payment=()",
      );
      c.header("Referrer-Policy", "no-referrer");
      c.header("X-Content-Type-Options", "nosniff");
      c.header("X-Frame-Options", "DENY");
      if (environment === "production") {
        c.header(
          "Strict-Transport-Security",
          "max-age=31536000; includeSubDomains",
        );
      }
    }
  };
}

function invalidSingleton(value: string | undefined): boolean {
  return value !== undefined &&
    (value.includes(",") || /[\r\n\0]/.test(value) || value.length > 16_384);
}

async function boundedBody(
  c: Parameters<MiddlewareHandler<PlatformEnv>>[0],
  maxBytes: number,
): Promise<Response | null> {
  const request = c.req.raw;
  if (!request.body) return null;
  if (c.req.method === "GET" || c.req.method === "HEAD") {
    return problem(c, "INVALID_REQUEST", 400);
  }
  const encoding = request.headers.get("content-encoding");
  if (encoding && encoding.toLowerCase() !== "identity") {
    return problem(c, "UNSUPPORTED_MEDIA_TYPE", 415);
  }
  const type = request.headers.get("content-type")?.split(";", 1)[0]?.trim()
    .toLowerCase();
  if (type !== "application/json") {
    return problem(c, "UNSUPPORTED_MEDIA_TYPE", 415);
  }

  const reader = request.body.getReader();
  const chunks: Uint8Array[] = [];
  let size = 0;
  for (;;) {
    const { done, value } = await reader.read();
    if (done) break;
    size += value.byteLength;
    if (size > maxBytes) {
      await reader.cancel();
      return problem(c, "PAYLOAD_TOO_LARGE", 413);
    }
    chunks.push(value);
  }
  const bytes = new Uint8Array(size);
  let offset = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.byteLength;
  }
  try {
    new TextDecoder("utf-8", { fatal: true }).decode(bytes);
  } catch {
    return problem(c, "INVALID_REQUEST", 400);
  }
  c.req.raw = new Request(
    request,
    { body: bytes, duplex: "half" } as RequestInit,
  );
  return null;
}

function jsonShapeWithinLimits(
  value: unknown,
  maxDepth: number,
  maxKeys: number,
): boolean {
  const queue: Array<{ value: unknown; depth: number }> = [{ value, depth: 0 }];
  let keys = 0;
  while (queue.length) {
    const item = queue.pop()!;
    if (item.depth > maxDepth) return false;
    if (!item.value || typeof item.value !== "object") continue;
    if (Array.isArray(item.value)) {
      for (const child of item.value) {
        queue.push({ value: child, depth: item.depth + 1 });
      }
      continue;
    }
    const entries = Object.entries(item.value);
    keys += entries.length;
    if (keys > maxKeys) return false;
    for (const [, child] of entries) {
      queue.push({ value: child, depth: item.depth + 1 });
    }
  }
  return true;
}

export function protocolControls(
  options: PlatformMiddlewareOptions,
): MiddlewareHandler<PlatformEnv> {
  const limits = { ...DEFAULT_PLATFORM_LIMITS, ...options.limits };
  const allowed = new Set(options.allowedOrigins ?? []);
  return async (c, next) => {
    if (!METHODS.has(c.req.method)) {
      return problem(c, "METHOD_NOT_ALLOWED", 405);
    }
    for (const name of SINGLETON_HEADERS) {
      if (invalidSingleton(c.req.header(name))) {
        return problem(c, "INVALID_HEADER", 400);
      }
    }

    const origin = c.req.header("origin");
    if (origin && !allowed.has(origin)) return problem(c, "FORBIDDEN", 403);
    if (origin) {
      c.header("Access-Control-Allow-Origin", origin);
      c.header("Vary", "Origin", { append: true });
      c.header(
        "Access-Control-Expose-Headers",
        "X-Request-ID, Idempotency-Replayed",
      );
    }
    if (c.req.method === "OPTIONS") {
      c.header("Access-Control-Allow-Methods", "GET, HEAD, POST, OPTIONS");
      c.header(
        "Access-Control-Allow-Headers",
        "Authorization, Content-Type, Idempotency-Key, X-Studafy-Device, X-Studafy-Reauth",
      );
      c.header("Access-Control-Max-Age", "600");
      return c.body(null, 204);
    }

    const limited = await boundedBody(c, limits.maxBodyBytes);
    if (limited) return limited;
    if (c.req.raw.body) {
      try {
        const value = JSON.parse(await c.req.raw.clone().text());
        if (
          !jsonShapeWithinLimits(value, limits.maxJsonDepth, limits.maxJsonKeys)
        ) {
          return problem(c, "INVALID_REQUEST", 400);
        }
      } catch {
        return problem(c, "INVALID_REQUEST", 400);
      }
    }
    await next();
  };
}

export function totalTimeout(
  durationMs: number,
): MiddlewareHandler<PlatformEnv> {
  return async (c, next) => {
    const controller = new AbortController();
    c.set("abortSignal", controller.signal);
    let timer: ReturnType<typeof setTimeout> | undefined;
    const deadline = new Promise<Response>((resolve) => {
      timer = setTimeout(() => {
        controller.abort();
        resolve(problem(c, "REQUEST_TIMEOUT", 504));
      }, durationMs);
    });
    try {
      const result = await Promise.race([
        next().then(() => null),
        deadline,
      ]);
      if (result) c.res = result;
    } finally {
      if (timer) clearTimeout(timer);
    }
  };
}

export function requestTelemetry(
  logger: Logger,
  now: () => number = Date.now,
): MiddlewareHandler<PlatformEnv> {
  return async (c, next) => {
    let threw = false;
    try {
      await next();
    } catch (error) {
      threw = true;
      throw error;
    } finally {
      const status = threw ? 500 : c.res.status;
      logger.info("http_request_completed", {
        request_id: c.get("requestId"),
        method: c.req.method,
        route: c.req.routePath || "unmatched",
        status,
        duration_ms: Math.max(0, now() - c.get("requestStartedAt")),
        outcome: status >= 500 ? "error" : status >= 400 ? "denied" : "ok",
      });
    }
  };
}
