import { afterAll, describe, expect, test } from "bun:test";
import { Hono } from "hono";
import type { LogLevel, V1RouteContract } from "@studafy/contracts";
import { V1_ROUTE_CATALOGUE } from "@studafy/contracts";
import { closeRedis, createRedis } from "@studafy/infrastructure";
import { createJsonLogger } from "@studafy/observability";
import { LogCollector } from "@studafy/test-support";
import {
  createRateLimitDependencies,
  rateLimitAuto,
  rateLimitEdge,
} from "../../src/platform/rate-limit/middleware";
import {
  clientIpPrefix,
  flowFor,
  hmacSubject,
  RATE_LIMIT_FLOWS,
} from "../../src/platform/rate-limit/policies";

const redisUrl = process.env.REDIS_URL;
const redisTest = redisUrl ? test : test.skip;
const RUN = Math.random().toString(36).slice(2, 8);
const clients: { quit: () => Promise<unknown> }[] = [];

afterAll(async () => {
  await Promise.all(clients.map((client) => client.quit()));
});

const SECRET = "a-rate-limit-test-hmac-secret-32-bytes";

/** Fresh limiter dependencies per test; keys are deleted by callers first. */
function harnessDependencies() {
  const collector = new LogCollector();
  const logger = createJsonLogger(
    "api",
    "test",
    "debug" as LogLevel,
    collector.sink,
  );
  const deps = createRateLimitDependencies({
    enabled: true,
    secret: SECRET,
    redis: redisUrl ? createRedis(redisUrl) : null,
    logger,
    trustCloudflare: false,
  });
  if (deps.redis) clients.push({ quit: () => closeRedis(deps.redis!) });
  return { deps, collector };
}

const SAMPLE_SUBJECT_UUID = "7d444840-9dc0-4333-8b1a-555555555555";

describe("flow registry coverage (OPS-060)", () => {
  test("every catalogue route classifies into a registered flow", () => {
    for (const route of V1_ROUTE_CATALOGUE as readonly V1RouteContract[]) {
      const classification = flowFor(route.method, route.path);
      expect(RATE_LIMIT_FLOWS[classification.flow]).toBeDefined();
      expect(classification.weight).toBeGreaterThanOrEqual(1);
    }
  });

  test("classification is path-shaped: live paths agree with canonical paths", () => {
    for (const route of V1_ROUTE_CATALOGUE as readonly V1RouteContract[]) {
      const livePath = route.path.replaceAll(
        /\{[^}]+\}/g,
        SAMPLE_SUBJECT_UUID,
      );
      expect(flowFor(route.method, livePath)).toEqual(
        flowFor(route.method, route.path),
      );
    }
  });

  test("collections cost double single-resource reads, consistently", () => {
    for (const route of V1_ROUTE_CATALOGUE as readonly V1RouteContract[]) {
      if (route.method !== "get") continue;
      const classification = flowFor("get", route.path);
      // Admin-class reads cost 2 uniformly (low-volume, fail-closed); the
      // collection-vs-single distinction governs ordinary reads.
      if (classification.flow !== "authenticatedApi") continue;
      const expectedWeight = route.operationId.startsWith("list") ? 2 : 1;
      expect(classification.weight).toBe(expectedWeight);
    }
  });

  test("spot checks match the operator catalogue", () => {
    expect(flowFor("get", "/v1/me")).toEqual({
      flow: "authenticatedApi",
      weight: 1,
    });
    expect(flowFor("get", "/v1/schools/{schoolId}/terms")).toEqual({
      flow: "authenticatedApi",
      weight: 2,
    });
    expect(flowFor("get", "/v1/schools/{schoolId}")).toEqual({
      flow: "authenticatedApi",
      weight: 1,
    });
    expect(flowFor("post", "/v1/schools/{schoolId}/suspend")).toEqual({
      flow: "adminApi",
      weight: 2,
    });
    expect(flowFor("post", "/v1/students/locate")).toEqual({
      flow: "linking",
      weight: 2,
    });
    expect(flowFor("post", "/v1/guardian-links")).toEqual({
      flow: "linking",
      weight: 2,
    });
    expect(flowFor("post", "/v1/notifications/mark-read")).toEqual({
      flow: "rpc",
      weight: 1,
    });
    expect(flowFor("get", "/internal/moderation/queue")).toEqual({
      flow: "adminApi",
      weight: 2,
    });
    expect(flowFor("post", "/internal/support-access")).toEqual({
      flow: "adminApi",
      weight: 2,
    });
    expect(flowFor("post", "/v1/auth/sign-out")).toEqual({
      flow: "auth",
      weight: 2,
    });
    expect(flowFor("get", "/v1/auth/context")).toEqual({
      flow: "authenticatedApi",
      weight: 1,
    });
  });

  test("every registered flow declares a rationale and a sane policy", () => {
    for (const policy of Object.values(RATE_LIMIT_FLOWS)) {
      expect(policy.rationale.length).toBeGreaterThan(10);
      expect(policy.policy.limit).toBeGreaterThan(0);
      expect(policy.policy.windowSeconds).toBeGreaterThan(0);
    }
  });
});

describe("client network prefix normalization", () => {
  test("IPv4 keys on the address", () => {
    expect(clientIpPrefix("203.0.113.7")).toBe("203.0.113.7");
  });

  test("IPv4-mapped IPv6 collapses to its IPv4 form", () => {
    expect(clientIpPrefix("::ffff:203.0.113.7")).toBe("203.0.113.7");
  });

  test("IPv6 keys on a /64 aggregate, insensitive to case and zeros", () => {
    const a = clientIpPrefix("2001:0DB8:1234:5678:9abc:def0:1234:5678");
    const b = clientIpPrefix("2001:db8:1234:5678::1");
    expect(a).toBe("v6-2001-0db8-1234-5678");
    expect(a).toBe(b);
  });

  test("zone ids expand, compressed addresses expand, garbage is rejected", () => {
    expect(clientIpPrefix("fe80::1%en0")).toBe("v6-fe80-0000-0000-0000");
    expect(clientIpPrefix("::1")).toBe("v6-0000-0000-0000-0000");
    expect(clientIpPrefix("not-an-ip")).toBeNull();
    expect(clientIpPrefix(null)).toBeNull();
    expect(clientIpPrefix("")).toBeNull();
  });
});

describe("subject HMAC digests", () => {
  test("never contain the raw identifier and separate namespaces", () => {
    const account = hmacSubject(SECRET, "account", SAMPLE_SUBJECT_UUID);
    const tenant = hmacSubject(SECRET, "tenant", SAMPLE_SUBJECT_UUID);
    expect(account).not.toContain(SAMPLE_SUBJECT_UUID);
    expect(account).not.toBe(tenant);
    expect(account.startsWith("v1:")).toBe(true);
    expect(hmacSubject(SECRET, "account", SAMPLE_SUBJECT_UUID)).toBe(account);
    expect(
      hmacSubject(
        "another-hmac-secret-with-32-bytes!!",
        "account",
        SAMPLE_SUBJECT_UUID,
      ),
    )
      .not.toBe(account);
  });
});

function edgeRunner(deps: ReturnType<typeof createRateLimitDependencies>) {
  const app = new Hono();
  app.use("/v1/*", rateLimitEdge(deps) as never);
  app.get("/v1/ping", (c) => c.json({ ok: true }));
  app.get("/v1/other", (c) => c.json({ ok: true }));
  app.post("/v1/other", (c) => c.json({ ok: true }));
  return app;
}

/**
 * Installs a fake actor the way the auth middleware would, deriving the
 * subject from the bearer header so each test's budget key is unique (and
 * unique per run - Redis keys persist between runs).
 */
function actorMiddleware(_bootstrap: string) {
  return async (
    c: {
      set: (key: string, value: unknown) => void;
      req: { header: (name: string) => string | undefined };
    },
    next: () => Promise<void>,
  ) => {
    const subject = c.req.header("authorization")?.replace("Bearer ", "") ??
      "anon";
    c.set("actor", { token: { subject } });
    await next();
  };
}

function authRunner(deps: ReturnType<typeof createRateLimitDependencies>) {
  const app = new Hono();
  app.use("*", actorMiddleware("bootstrap") as never);
  app.use("*", rateLimitAuto(deps) as never);
  app.all("/v1/*", (c) => c.json({ ok: true }));
  return app;
}

describe("edge limiter enforcement", () => {
  redisTest(
    "blocks an address past the publicDefault budget with 429 and Retry-After",
    async () => {
      const { deps } = harnessDependencies();
      const ip = `203.0.${RUN.length}.${7}`;
      const key = `rl:publicDefault:ip:203.0.${RUN.length}.7`;
      if (deps.redis) await deps.redis.del(key);
      const app = edgeRunner(deps);
      const limit = RATE_LIMIT_FLOWS.publicDefault.policy.limit;
      let limited = 0;
      for (let i = 0; i < limit + 3; i++) {
        const response = await app.request("/v1/ping", {
          headers: { "cf-connecting-ip": ip },
        });
        if (response.status === 429) {
          limited++;
          expect(response.headers.get("Retry-After")).toBeTruthy();
        } else {
          expect(response.status).toBe(200);
        }
      }
      expect(limited).toBe(3);
    },
  );

  redisTest("the prefix budget spans paths and methods", async () => {
    const { deps } = harnessDependencies();
    const ip = `198.51.100.${RUN.length}`;
    if (deps.redis) await deps.redis.del(`rl:publicDefault:ip:${ip}`);
    const app = edgeRunner(deps);
    const limit = RATE_LIMIT_FLOWS.publicDefault.policy.limit;
    for (let i = 0; i < limit - 1; i++) {
      await app.request("/v1/ping", { headers: { "cf-connecting-ip": ip } });
    }
    const lastAllowed = await app.request("/v1/other", {
      headers: { "cf-connecting-ip": ip },
    });
    expect(lastAllowed.status).toBe(200);
    const blocked = await app.request("/v1/other", {
      method: "post",
      headers: { "cf-connecting-ip": ip },
    });
    expect(blocked.status).toBe(429);
  });

  redisTest("unresolved addresses share one bounded bucket", async () => {
    const { deps } = harnessDependencies();
    if (deps.redis) await deps.redis.del("rl:publicDefault:ip:unresolved");
    const app = edgeRunner(deps);
    const limit = RATE_LIMIT_FLOWS.publicDefault.policy.limit;
    let allowed = 0;
    for (let i = 0; i < limit + 1; i++) {
      const response = await app.request("/v1/ping", {});
      if (response.status === 200) allowed++;
    }
    expect(allowed).toBe(limit);
  });
});

describe("authenticated flow enforcement", () => {
  redisTest(
    "blocks the auth flow once its weighted budget is spent",
    async () => {
      const { deps } = harnessDependencies();
      const app = authRunner(deps);
      const subject = `${RUN}-auth-subject`;
      const limit = RATE_LIMIT_FLOWS.auth.policy.limit;
      const responses: Response[] = [];
      for (let i = 0; i < Math.ceil(limit / 2) + 2; i++) {
        responses.push(
          await app.request("/v1/auth/sign-out", {
            method: "post",
            headers: { authorization: `Bearer ${subject}` },
          }),
        );
      }
      const allowed = responses.filter((response) => response.status === 200);
      const rejected = responses.filter((response) => response.status === 429);
      expect(allowed.length).toBe(Math.floor(limit / 2));
      expect(rejected.length).toBe(2);
      expect(rejected[0]?.headers.get("Retry-After")).toBeTruthy();
      for (const response of rejected) {
        expect(((await response.json()) as { code: string }).code).toBe(
          "RATE_LIMITED",
        );
      }
    },
  );

  redisTest(
    "the linking flow is bounded separately from ordinary reads",
    async () => {
      const { deps } = harnessDependencies();
      const app = authRunner(deps);
      const subject = `${RUN}-linker`;
      const limit = RATE_LIMIT_FLOWS.linking.policy.limit;
      const responses: Response[] = [];
      for (let i = 0; i < Math.ceil(limit / 2) + 1; i++) {
        responses.push(
          await app.request("/v1/students/locate", {
            method: "post",
            headers: { authorization: `Bearer ${subject}` },
          }),
        );
      }
      expect(responses.filter((response) => response.status === 200).length)
        .toBe(Math.floor(limit / 2));
      expect(
        responses[responses.length - 1]?.status,
      ).toBe(429);
      // A different subject keeps its own budget.
      const other = await app.request("/v1/students/locate", {
        method: "post",
        headers: { authorization: `Bearer ${RUN}-other` },
      });
      expect(other.status).toBe(200);
    },
  );
});

describe("false-positive rate (OPS-060 gate)", () => {
  redisTest(
    "a legitimate student never sees a 429 under the documented budget",
    async () => {
      const { deps } = harnessDependencies();
      const app = authRunner(deps);
      const subject = `${RUN}-student`;
      // 100 single reads + 10 collection pages + 2 commands in one 5-minute
      // window: 124 weighted units, inside the 150-token burst capacity.
      const responses: Response[] = [];
      for (let i = 0; i < 100; i++) {
        responses.push(
          await app.request("/v1/notifications/unread-count", {
            headers: { authorization: `Bearer ${subject}` },
          }),
        );
      }
      for (let i = 0; i < 10; i++) {
        responses.push(
          await app.request("/v1/notifications", {
            headers: { authorization: `Bearer ${subject}` },
          }),
        );
      }
      for (let i = 0; i < 2; i++) {
        responses.push(
          await app.request("/v1/account/profile", {
            method: "post",
            headers: { authorization: `Bearer ${subject}` },
          }),
        );
      }
      const rejected = responses.filter((response) => response.status === 429);
      expect(rejected).toEqual([]);
      expect(responses.every((response) => response.status === 200)).toBe(true);
    },
  );
});

describe("redis-down failure modes", () => {
  test("fail-closed flows answer 503 SERVICE_UNAVAILABLE, never 429", async () => {
    const { deps: healthy } = harnessDependencies();
    const app = authRunner({ ...healthy, redis: unreachableRedis() });
    const response = await app.request("/v1/students/locate", {
      method: "post",
      headers: { authorization: "Bearer down-subject" },
    });
    expect(response.status).toBe(503);
    expect(((await response.json()) as { code: string }).code).toBe(
      "SERVICE_UNAVAILABLE",
    );
  });

  test("fail-open flows degrade to the bounded local cap", async () => {
    const { deps: healthy } = harnessDependencies();
    const app = authRunner({ ...healthy, redis: unreachableRedis() });
    const subject = `down-${RUN}`;
    // authenticatedApi reads cost 2; the local cap serves the policy limit
    // (300 weighted units = 150 requests), then refuses with 429.
    let rejected = 0;
    for (let i = 0; i < 200; i++) {
      const response = await app.request("/v1/notifications", {
        headers: { authorization: `Bearer ${subject}` },
      });
      if (response.status === 429) rejected++;
    }
    expect(rejected).toBe(50);
  });
});

/** A Redis stand-in whose every operation rejects, as an outage would. */
function unreachableRedis() {
  const failure = () =>
    Promise.reject(new Error("ECONNREFUSED 127.0.0.1:6379"));
  return {
    get: failure,
    set: failure,
    incr: failure,
    del: failure,
    eval: failure,
    ping: failure,
  } as unknown as NonNullable<
    ReturnType<typeof createRateLimitDependencies>["redis"]
  >;
}
