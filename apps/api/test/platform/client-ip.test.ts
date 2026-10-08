import { describe, expect, test } from "bun:test";
import { Hono } from "hono";
import {
  isCloudflareAddress,
  resolveClientAddress,
} from "../../src/platform/clientIp";
import { requireCloudflareOrigin } from "../../src/platform/middleware";
import {
  createRateLimitDependencies,
  rateLimitEdge,
} from "../../src/platform/rate-limit/middleware";
import { RATE_LIMIT_FLOWS } from "../../src/platform/rate-limit/policies";
import type { LogLevel } from "@studafy/contracts";
import { createJsonLogger } from "@studafy/observability";

const headers = (values: Record<string, string>) => (name: string) =>
  values[name.toLowerCase()];

const CLOUDFLARE_EDGE = "162.158.1.20";
const CLOUDFLARE_EDGE_V6 = "2606:4700:10::ac43:1";

describe("client address (security audit 2026-10-08)", () => {
  test("Cloudflare ranges match, and only them", () => {
    expect(isCloudflareAddress(CLOUDFLARE_EDGE)).toBe(true);
    expect(isCloudflareAddress(CLOUDFLARE_EDGE_V6)).toBe(true);
    expect(isCloudflareAddress("::ffff:104.16.0.1")).toBe(true);
    expect(isCloudflareAddress("104.32.0.1")).toBe(false);
    expect(isCloudflareAddress("203.0.113.7")).toBe(false);
    expect(isCloudflareAddress("2606:4701::1")).toBe(false);
    expect(isCloudflareAddress("not-an-ip")).toBe(false);
    expect(isCloudflareAddress(undefined)).toBe(false);
  });

  test("cloudflare: a direct origin request cannot name its own address", () => {
    // The caller reached *.fly.dev directly and wrote CF-Connecting-IP.
    expect(
      resolveClientAddress(
        "cloudflare",
        headers({
          "fly-client-ip": "198.51.100.4",
          "cf-connecting-ip": "203.0.113.99",
          "x-forwarded-for": "192.0.2.1",
        }),
      ),
    ).toBe("198.51.100.4");
    // No peer header at all: nothing trustworthy, never the claimed value.
    expect(
      resolveClientAddress(
        "cloudflare",
        headers({ "cf-connecting-ip": "203.0.113.99" }),
      ),
    ).toBeNull();
  });

  test("cloudflare: the visitor's address when the peer is Cloudflare", () => {
    expect(
      resolveClientAddress(
        "cloudflare",
        headers({
          "fly-client-ip": CLOUDFLARE_EDGE,
          "cf-connecting-ip": "203.0.113.99",
        }),
      ),
    ).toBe("203.0.113.99");
  });

  test("fly: only the proxy's own header counts", () => {
    expect(
      resolveClientAddress(
        "fly",
        headers({
          "fly-client-ip": "198.51.100.4",
          "x-forwarded-for": "192.0.2.1, 198.51.100.4",
          "cf-connecting-ip": "203.0.113.99",
        }),
      ),
    ).toBe("198.51.100.4");
  });

  test("forwarded (local only) keeps reading X-Forwarded-For", () => {
    expect(
      resolveClientAddress(
        "forwarded",
        headers({ "x-forwarded-for": "192.0.2.1, 10.0.0.1" }),
      ),
    ).toBe("192.0.2.1");
  });
});

describe("edge limit cannot be dodged by rotating headers", () => {
  test("one direct caller rotating CF-Connecting-IP shares one budget", async () => {
    const deps = createRateLimitDependencies({
      enabled: true,
      secret: "a-rate-limit-test-hmac-secret-32-bytes",
      // Local fallback limiter: the same keying as Redis, no server needed.
      redis: null,
      logger: createJsonLogger("api", "test", "error" as LogLevel, () => {}),
      clientIpSource: "cloudflare",
    });
    const app = new Hono();
    app.use("/v1/*", rateLimitEdge(deps));
    app.get("/v1/ping", (c) => c.text("ok"));

    const limit = RATE_LIMIT_FLOWS.publicDefault.policy.limit;
    let limited = 0;
    for (let i = 0; i < limit + 5; i++) {
      const response = await app.request("/v1/ping", {
        headers: {
          "fly-client-ip": "198.51.100.77",
          "cf-connecting-ip": `203.0.113.${i % 250}`,
          "x-forwarded-for": `192.0.2.${i % 250}`,
        },
      });
      if (response.status === 429) limited++;
    }
    expect(limited).toBe(5);
  });
});

describe("ORIGIN_REQUIRE_CLOUDFLARE", () => {
  const app = new Hono();
  app.use("*", requireCloudflareOrigin());
  app.get("/healthz", (c) => c.text("ok"));
  app.get("/v1/me", (c) => c.text("ok"));

  test("refuses traffic that did not come through Cloudflare", async () => {
    const direct = await app.request("/v1/me", {
      headers: {
        "fly-client-ip": "198.51.100.4",
        "cf-connecting-ip": "1.2.3.4",
      },
    });
    expect(direct.status).toBe(403);
    expect((await app.request("/v1/me")).status).toBe(403);
  });

  test("lets Cloudflare and Fly's health check through", async () => {
    const proxied = await app.request("/v1/me", {
      headers: { "fly-client-ip": CLOUDFLARE_EDGE },
    });
    expect(proxied.status).toBe(200);
    expect((await app.request("/healthz")).status).toBe(200);
  });
});
