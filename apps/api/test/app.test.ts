import { describe, expect, test } from "bun:test";
import { createApp, type AppDependencies } from "../src/bootstrap/app";
import { ErrorCode } from "@studafy/contracts";
import type { LogLevel } from "@studafy/contracts";
import { createJsonLogger } from "@studafy/observability";
import { LogCollector } from "@studafy/test-support";

function buildDependencies(
  overrides: Partial<AppDependencies["checks"]> = {},
): { deps: AppDependencies; collector: LogCollector } {
  const collector = new LogCollector();
  const logger = createJsonLogger(
    "api",
    "0.1.0-test",
    "debug" as LogLevel,
    collector.sink,
  );
  const deps: AppDependencies = {
    info: { service: "api", version: "0.1.0-test", environment: "development" },
    logger,
    checks: {
      database: async () => undefined,
      redis: async () => undefined,
      ...overrides,
    },
  };
  return { deps, collector };
}

describe("liveness and identity", () => {
  test("GET /healthz answers 200 without touching dependencies", async () => {
    const { deps } = buildDependencies({
      database: undefined,
      redis: async () => {
        throw new Error("unreachable");
      },
    });
    const response = await createApp(deps).request("/healthz");
    expect(response.status).toBe(200);
    expect(await response.json()).toEqual({ status: "ok" });
  });

  test("GET /version exposes only service identity", async () => {
    const { deps } = buildDependencies();
    const response = await createApp(deps).request("/version");
    expect(response.status).toBe(200);
    expect(await response.json()).toEqual({
      service: "api",
      version: "0.1.0-test",
      environment: "development",
    });
  });
});

describe("readiness reason codes", () => {
  test("all dependencies healthy reports ready", async () => {
    const { deps } = buildDependencies();
    const response = await createApp(deps).request("/readyz");
    expect(response.status).toBe(200);
    expect(await response.json()).toEqual({ ready: true, reasons: [] });
  });

  test("a failing database check yields exactly database_unreachable", async () => {
    const { deps } = buildDependencies({
      database: async () => {
        throw new Error("connection refused");
      },
    });
    const response = await createApp(deps).request("/readyz");
    expect(response.status).toBe(503);
    expect(await response.json()).toEqual({
      ready: false,
      reasons: ["database_unreachable"],
    });
  });

  test("an unconfigured dependency is reported as a readiness reason", async () => {
    const { deps } = buildDependencies({ redis: undefined });
    const response = await createApp(deps).request("/readyz");
    expect(response.status).toBe(503);
    expect(await response.json()).toEqual({
      ready: false,
      reasons: ["redis_unreachable"],
    });
  });

  test("multiple failures are reported together", async () => {
    const { deps } = buildDependencies({
      database: async () => {
        throw new Error("down");
      },
      redis: async () => {
        throw new Error("down");
      },
    });
    const response = await createApp(deps).request("/readyz");
    expect(response.status).toBe(503);
    const body = (await response.json()) as { reasons: string[] };
    expect(body.reasons.sort()).toEqual([
      "database_unreachable",
      "redis_unreachable",
    ]);
  });
});

describe("empty /v1 router and unmatched routes", () => {
  test("any /v1 path and method returns the NOT_IMPLEMENTED contract", async () => {
    const { deps } = buildDependencies();
    const app = createApp(deps);
    for (const [method, path] of [
      ["GET", "/v1/me"],
      ["POST", "/v1/classrooms"],
      ["DELETE", "/v1/nested/resource"],
    ] as const) {
      const response = await app.request(path, { method });
      expect(response.status).toBe(404);
      const body = (await response.json()) as {
        error: { code: string; request_id: string };
      };
      expect(body.error.code).toBe(ErrorCode.NOT_IMPLEMENTED);
      expect(body.error.request_id).toBeString();
    }
  });

  test("routes outside /v1 answer NOT_FOUND", async () => {
    const { deps } = buildDependencies();
    const response = await createApp(deps).request("/nope");
    expect(response.status).toBe(404);
    const body = (await response.json()) as { error: { code: string } };
    expect(body.error.code).toBe(ErrorCode.NOT_FOUND);
  });
});

describe("error handling and request correlation", () => {
  test("thrown route errors return a sanitized body and log the detail", async () => {
    const { deps, collector } = buildDependencies();
    const app = createApp(deps);
    app.get("/boom", () => {
      throw new Error("sensitive internal detail");
    });

    const response = await app.request("/boom");
    expect(response.status).toBe(500);
    const body = (await response.json()) as {
      error: { code: string; message: string; request_id: string };
    };
    expect(body.error.code).toBe(ErrorCode.INTERNAL_ERROR);
    expect(body.error.message).not.toContain("sensitive");
    expect(body.error.request_id).toBeString();

    const logged = collector.parsed().find((entry) => entry.event === "http_error");
    expect(logged?.error_message).toBe("sensitive internal detail");
  });

  test("every response carries a server-generated X-Request-ID", async () => {
    const { deps } = buildDependencies();
    const app = createApp(deps);
    const response = await app.request("/healthz");
    const requestId = response.headers.get("X-Request-ID");
    expect(requestId).toMatch(
      /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/,
    );

    const errorResponse = await app.request("/v1/x");
    const body = (await errorResponse.json()) as { error: { request_id: string } };
    expect(body.error.request_id).toBe(
      errorResponse.headers.get("X-Request-ID") ?? "",
    );
  });
});
