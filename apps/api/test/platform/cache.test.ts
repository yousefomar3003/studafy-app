import { afterAll, describe, expect, test } from "bun:test";
import { closeRedis, createRedis } from "@studafy/infrastructure";
import { RedisAuthContextCache } from "../../src/platform/cache/authContextCache";
import {
  AUTH_CACHE_MAX_TTL_SECONDS,
  CACHE_CATALOGUE,
  redisKeyPrefixes,
} from "../../src/platform/cache/cacheCatalogue";

const redisUrl = process.env.REDIS_URL;
const redisTest = redisUrl ? test : test.skip;
const RUN = Math.random().toString(36).slice(2, 8);
const clients: { quit: () => Promise<unknown> }[] = [];

afterAll(async () => {
  await Promise.all(clients.map((client) => client.quit()));
});

function cacheHarness(budgetSeconds: number) {
  const redis = createRedis(redisUrl!);
  clients.push({ quit: () => closeRedis(redis) });
  return {
    redis,
    cache: new RedisAuthContextCache(redis, "a-test-hmac-secret-32-bytes!!!", {
      environment: "test",
      budgetSeconds,
    }),
  };
}

describe("cache catalogue invariants (OPS-060)", () => {
  test("authorization-adjacent TTLs clamp to the committed staleness bound", () => {
    for (const budget of [0, 5, 300]) {
      expect(CACHE_CATALOGUE.authContext.ttlSeconds(budget))
        .toBeLessThanOrEqual(AUTH_CACHE_MAX_TTL_SECONDS);
      expect(CACHE_CATALOGUE.entitlementRead.ttlSeconds(budget))
        .toBeLessThanOrEqual(AUTH_CACHE_MAX_TTL_SECONDS);
    }
    // Budget 0 still caches (version-keyed), budget 5 clamps to 5.
    expect(CACHE_CATALOGUE.authContext.ttlSeconds(0)).toBe(30);
    expect(CACHE_CATALOGUE.authContext.ttlSeconds(5)).toBe(5);
    expect(CACHE_CATALOGUE.authContext.ttlSeconds(300)).toBe(30);
  });

  test("every entry documents an invalidation event and a failure mode", () => {
    for (const entry of Object.values(CACHE_CATALOGUE)) {
      expect(entry.id).toBeTruthy();
      expect(entry.description.length).toBeGreaterThan(10);
      expect(entry.invalidation.length).toBeGreaterThan(10);
      expect(["fallback_to_loader", "fail_closed_to_db"]).toContain(
        entry.failure,
      );
      // Sensitive entries must never serve stale data.
      if (entry.failure === "fail_closed_to_db") {
        expect(entry.staleSeconds).toBeUndefined();
      }
      expect(entry.ttlSeconds(0)).toBeGreaterThan(0);
      expect(entry.status === "active" || entry.status === "declared").toBe(
        true,
      );
    }
    expect(CACHE_CATALOGUE.authContext.status).toBe("active");
  });

  test("key namespaces never collide with the limiter or BullMQ", () => {
    for (const environment of ["development", "production", "test"]) {
      const prefixes = redisKeyPrefixes(environment);
      const values = Object.values(prefixes);
      expect(new Set(values).size).toBe(values.length);
      for (const a of values) {
        for (const b of values) {
          if (a === b) continue;
          expect(a.startsWith(b)).toBe(false);
        }
      }
    }
  });
});

describe("redis auth-context cache", () => {
  redisTest(
    "serves the loader once, then the cache, until invalidation",
    async () => {
      const { cache } = cacheHarness(0);
      const subject = `${RUN}-11111111-2222-4333-8444-555555555555`;
      let loads = 0;
      const context = {
        userId: subject,
        displayName: "Test User",
        locale: "en" as const,
        profileStatus: "active",
        profileDeletedAt: null,
        revokedBefore: null,
        deletionState: null,
        memberships: [],
        membershipVersion: "mv-1",
        mfaEnrolled: false,
      };
      const loader = () => {
        loads += 1;
        return Promise.resolve(context);
      };
      const first = await cache.load(subject, loader);
      expect(first).toEqual(context);
      expect(loads).toBe(1);
      const second = await cache.load(subject, loader);
      expect(second).toEqual(context);
      expect(loads).toBe(1);
      await cache.invalidate(subject);
      const third = await cache.load(subject, loader);
      expect(third).toEqual(context);
      expect(loads).toBe(2);
    },
  );

  redisTest("keys never contain the raw subject", async () => {
    const { cache, redis } = cacheHarness(0);
    const subject = `raw-${RUN}-9d444840-9dc0-4333-8b1a-000000000099`;
    await cache.load(subject, () =>
      Promise.resolve({
        userId: subject,
        displayName: "Probe",
        locale: "en",
        profileStatus: "active",
        profileDeletedAt: null,
        revokedBefore: null,
        deletionState: null,
        memberships: [],
        membershipVersion: "mv-1",
        mfaEnrolled: false,
      }));
    const keys = await redis.keys("studafy:{test}:cache:*");
    expect(keys.length).toBeGreaterThan(0);
    for (const key of keys) {
      expect(key).not.toContain(subject);
    }
  });

  redisTest("the TTL clamps to a positive revocation budget", async () => {
    const { cache, redis } = cacheHarness(5);
    const subject = `${RUN}-ttl-probe`;
    const { hmacSubject } = await import(
      "../../src/platform/rate-limit/policies"
    );
    const digest = hmacSubject(
      "a-test-hmac-secret-32-bytes!!!",
      "authctx",
      subject,
    );
    const key = `studafy:{test}:cache:authctx:${digest}:0`;
    await redis.del(key);
    // The negative (null) context is cached under the clamped TTL.
    await cache.load(subject, () => Promise.resolve(null));
    const pttl = await redis.pttl(key);
    expect(pttl).toBeGreaterThan(0);
    expect(pttl).toBeLessThanOrEqual(5100);
  });

  redisTest("a Redis failure falls back to the loader", async () => {
    // The cache must never mask a loader result: with an unreachable Redis
    // the whole load path degrades to the DB (here: the loader itself).
    const failure = () => Promise.reject(new Error("ECONNREFUSED"));
    const stub = {
      get: failure,
      set: failure,
      incr: failure,
      del: failure,
      eval: failure,
    } as unknown as ConstructorParameters<typeof RedisAuthContextCache>[0];
    const cache = new RedisAuthContextCache(
      stub,
      "a-test-hmac-secret-32-bytes!!!",
      { environment: "test", budgetSeconds: 0 },
    );
    let loads = 0;
    const loader = () => {
      loads += 1;
      return Promise.resolve(null);
    };
    const result = await cache.load(`down-${RUN}`, loader);
    expect(result).toBeNull();
    expect(loads).toBe(1);
  });
});
