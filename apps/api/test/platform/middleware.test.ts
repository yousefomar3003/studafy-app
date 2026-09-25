import { describe, expect, test } from "bun:test";
import { z } from "zod";
import type { LogLevel, V1RouteContract } from "@studafy/contracts";
import { createJsonLogger } from "@studafy/observability";
import { LogCollector } from "@studafy/test-support";
import { type AppDependencies, createApp } from "../../src/bootstrap/app";
import {
  validatedBody,
  validateRouteInput,
} from "../../src/platform/validation";

const input = z.strictObject({
  name: z.string().min(1),
  count: z.number().finite().optional(),
});
const output = z.strictObject({ name: z.string() });
const route = {
  method: "post",
  path: "/platform-test",
  operationId: "platformTest",
  summary: "Platform test",
  permission: "test",
  idempotency: "none",
  request: input,
  requestSchema: "PlatformTestRequest",
  response: output,
  responseSchema: "PlatformTestResponse",
} satisfies V1RouteContract;

function harness(options: {
  allowedOrigins?: string[];
  maxBodyBytes?: number;
  maxJsonDepth?: number;
  maxJsonKeys?: number;
  requestTimeoutMs?: number;
  hmacKey?: string;
} = {}) {
  const collector = new LogCollector();
  const logger = createJsonLogger(
    "api",
    "test",
    "debug" as LogLevel,
    collector.sink,
  );
  const deps: AppDependencies = {
    info: { service: "api", version: "test", environment: "development" },
    logger,
    checks: {},
    platform: {
      allowedOrigins: options.allowedOrigins,
      limits: options,
      ...(options.hmacKey
        ? { identity: { hmacKey: options.hmacKey, trustCloudflare: false } }
        : {}),
    },
  };
  const app = createApp(deps);
  app.post(
    route.path,
    validateRouteInput(route) as never,
    (c) => c.json({ name: validatedBody<{ name: string }>(c).name }),
  );
  app.get("/slow", async (c) => {
    await new Promise((resolve) => setTimeout(resolve, 30));
    return c.json({ tooLate: true });
  });
  return { app, collector };
}

async function code(response: Response): Promise<string> {
  return ((await response.json()) as { code: string }).code;
}

describe("API-040 request protocol controls", () => {
  test("rejects malformed JSON, malformed UTF-8, and non-finite values", async () => {
    const { app } = harness();
    const cases: Array<string | Uint8Array> = [
      "{",
      new Uint8Array([0xc3, 0x28]),
      '{"name":"ok","count":1e999}',
    ];
    for (const body of cases) {
      const response = await app.request("/platform-test", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body,
      });
      expect(response.status).toBe(400);
      expect(await code(response)).toBe("INVALID_REQUEST");
      expect(response.headers.get("content-type")).toContain(
        "application/problem+json",
      );
    }
  });

  test("requires JSON and rejects compressed bodies", async () => {
    const { app } = harness();
    const wrongType = await app.request("/platform-test", {
      method: "POST",
      headers: { "content-type": "text/plain" },
      body: "{}",
    });
    expect(wrongType.status).toBe(415);
    expect(await code(wrongType)).toBe("UNSUPPORTED_MEDIA_TYPE");

    const compressed = await app.request("/platform-test", {
      method: "POST",
      headers: {
        "content-type": "application/json",
        "content-encoding": "gzip",
      },
      body: "not-really-compressed",
    });
    expect(compressed.status).toBe(415);
  });

  test("measures streamed bytes instead of trusting Content-Length", async () => {
    const { app } = harness({ maxBodyBytes: 32 });
    const response = await app.request(
      new Request("http://local/platform-test", {
        method: "POST",
        headers: { "content-type": "application/json", "content-length": "2" },
        body: JSON.stringify({ name: "x".repeat(64) }),
        duplex: "half",
      } as RequestInit),
    );
    expect(response.status).toBe(413);
    expect(await code(response)).toBe("PAYLOAD_TOO_LARGE");
  });

  test("bounds JSON depth and total object keys", async () => {
    const depthApp = harness({ maxJsonDepth: 2 }).app;
    const deep = await depthApp.request("/platform-test", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: '{"name":"ok","a":{"b":{"c":1}}}',
    });
    expect(deep.status).toBe(400);

    const keysApp = harness({ maxJsonKeys: 2 }).app;
    const manyKeys = await keysApp.request("/platform-test", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: '{"name":"ok","a":1,"b":2}',
    });
    expect(manyKeys.status).toBe(400);
  });

  test("strict schemas reject mass-assignment fields without echoing them", async () => {
    const { app } = harness();
    const response = await app.request("/platform-test", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({
        name: "ok",
        schoolId: "attacker",
        role: "admin",
        url: "http://127.0.0.1",
      }),
    });
    expect(response.status).toBe(400);
    const text = await response.text();
    expect(text).not.toContain("schoolId");
    expect(text).not.toContain("attacker");
    expect(text).not.toContain("127.0.0.1");
  });

  test("rejects unsupported methods and ambiguous singleton headers", async () => {
    const { app } = harness();
    const method = await app.request("/platform-test", { method: "PUT" });
    expect(method.status).toBe(405);
    expect(await code(method)).toBe("METHOD_NOT_ALLOWED");

    const header = await app.request("/platform-test", {
      method: "POST",
      headers: {
        "content-type": "application/json",
        authorization: "Bearer first, Bearer injected",
      },
      body: '{"name":"ok"}',
    });
    expect(header.status).toBe(400);
    expect(await code(header)).toBe("INVALID_HEADER");
  });
});

describe("API-040 response controls", () => {
  test("does not reflect an unapproved Origin and emits exact-origin CORS", async () => {
    const { app } = harness({ allowedOrigins: ["https://app.studafy.test"] });
    const denied = await app.request("/healthz", {
      headers: { origin: "https://evil.test" },
    });
    expect(denied.status).toBe(403);
    expect(denied.headers.get("access-control-allow-origin")).toBeNull();

    const allowed = await app.request("/healthz", {
      headers: { origin: "https://app.studafy.test" },
    });
    expect(allowed.status).toBe(200);
    expect(allowed.headers.get("access-control-allow-origin")).toBe(
      "https://app.studafy.test",
    );
  });

  test("ignores spoofed request IDs and emits hardened no-store responses", async () => {
    const { app } = harness();
    const response = await app.request("/healthz", {
      headers: { "x-request-id": "client-controlled" },
    });
    expect(response.headers.get("x-request-id")).not.toBe("client-controlled");
    expect(response.headers.get("cache-control")).toBe("no-store");
    expect(response.headers.get("content-security-policy")).toContain(
      "default-src 'none'",
    );
    expect(response.headers.get("permissions-policy")).toContain("camera=()");
    expect(response.headers.get("referrer-policy")).toBe("no-referrer");
    expect(response.headers.get("x-content-type-options")).toBe("nosniff");
    expect(response.headers.get("x-frame-options")).toBe("DENY");
  });

  test("returns a sanitized 504 and propagates an abort signal", async () => {
    const { app, collector } = harness({ requestTimeoutMs: 5 });
    const response = await app.request("/slow");
    expect(response.status).toBe(504);
    expect(await code(response)).toBe("REQUEST_TIMEOUT");
    expect(response.headers.get("cache-control")).toBe("no-store");
    const completed = collector.parsed().find((entry) =>
      entry.event === "http_request_completed"
    );
    expect(completed?.status).toBe(504);
    expect(completed?.outcome).toBe("error");
  });

  test("logs one allowlisted completion event and no request body", async () => {
    const { app, collector } = harness();
    await app.request("/platform-test", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: '{"name":"secret-body-value"}',
    });
    const completed = collector.parsed().filter((entry) =>
      entry.event === "http_request_completed"
    );
    expect(completed).toHaveLength(1);
    expect(completed[0]?.route).toBe("/platform-test");
    expect(Object.keys(completed[0]!).sort()).toEqual([
      "duration_ms",
      "event",
      "ip_hash",
      "level",
      "method",
      "outcome",
      "request_id",
      "route",
      "service",
      "status",
      "timestamp",
      "ua_family",
      "user_id",
      "version",
    ]);
    expect(JSON.stringify(completed)).not.toContain("secret-body-value");
  });

  test("hashes the client address and never logs it raw", async () => {
    const { app, collector } = harness({ hmacKey: "k".repeat(32) });
    await app.request("/platform-test", {
      headers: { "x-forwarded-for": "203.0.113.7, 70.41.3.18" },
    });
    const completed = collector.parsed().find((entry) =>
      entry.event === "http_request_completed"
    );
    expect(completed?.ip_hash).toBeTruthy();
    expect(JSON.stringify(completed)).not.toContain("203.0.113.7");
  });

  test("omits the address hash when no signing key is configured", async () => {
    const { app, collector } = harness();
    await app.request("/platform-test", {
      headers: { "x-forwarded-for": "203.0.113.7" },
    });
    const completed = collector.parsed().find((entry) =>
      entry.event === "http_request_completed"
    );
    // An unkeyed digest of an address is reversible, so null is the only
    // safe answer here.
    expect(completed?.ip_hash).toBeNull();
    expect(JSON.stringify(completed)).not.toContain("203.0.113.7");
  });

  test("records the user agent family, never the full header", async () => {
    const { app, collector } = harness();
    await app.request("/platform-test", {
      headers: { "user-agent": "Dart/3.5 (dart:io) Flutter/3.24 iPhone17,1" },
    });
    const completed = collector.parsed().find((entry) =>
      entry.event === "http_request_completed"
    );
    expect(completed?.ua_family).toBe("flutter");
    expect(JSON.stringify(completed)).not.toContain("iPhone17,1");
  });

  test("user_id is null for an unauthenticated request", async () => {
    const { app, collector } = harness();
    await app.request("/platform-test");
    const completed = collector.parsed().find((entry) =>
      entry.event === "http_request_completed"
    );
    expect(completed?.user_id).toBeNull();
  });
});
