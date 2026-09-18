import { afterAll, describe, expect, test } from "bun:test";
import {
  CacheConfigError,
  closeRedis,
  consumeRateLimit,
  createRedis,
  type RateLimitPolicy,
  RedisCache,
  RedisUnavailableError,
  resetRateLimit,
  withRedisFailure,
} from "../src";

const redisUrl = process.env.REDIS_URL;
const redisTest = redisUrl ? test : test.skip;
// Keys persist across test runs; every key carries a per-run prefix so a
// previous run's state can never leak into this one's assertions.
const RUN = Math.random().toString(36).slice(2);
const clients: { quit: () => Promise<unknown> }[] = [];
let redis: ReturnType<typeof createRedis> | null = null;

function client() {
  if (!redis) {
    redis = createRedis(redisUrl!);
    clients.push({ quit: () => closeRedis(redis!) });
  }
  return redis!;
}

const FIXED_CLOCK = 1_700_000_000_000;

function window(
  limit: number,
  windowSeconds = 60,
): Extract<RateLimitPolicy, { kind: "slidingWindow" }> {
  return { kind: "slidingWindow", limit, windowSeconds };
}

afterAll(async () => {
  await Promise.all(clients.map((client) => client.quit()));
});

describe("rate-limit engine", () => {
  redisTest(
    "fixed window counts and blocks, then reports a reset",
    async () => {
      const r = client();
      const key = `test:ops060:${RUN}:fixed`;
      await resetRateLimit(r, key);
      const policy: RateLimitPolicy = {
        kind: "fixedWindow",
        limit: 2,
        windowSeconds: 60,
      };
      const first = await consumeRateLimit(r, key, policy, {
        nowMs: FIXED_CLOCK,
      });
      expect(first.allowed).toBe(true);
      expect(first.remaining).toBe(1);
      const second = await consumeRateLimit(r, key, policy, {
        nowMs: FIXED_CLOCK + 1,
      });
      expect(second.allowed).toBe(true);
      expect(second.remaining).toBe(0);
      const third = await consumeRateLimit(r, key, policy, {
        nowMs: FIXED_CLOCK + 2,
      });
      expect(third.allowed).toBe(false);
      expect(third.retryAfterMs).toBeGreaterThan(0);
      expect(third.retryAfterMs).toBeLessThanOrEqual(60_000);
    },
  );

  redisTest(
    "fixed window resets once the real window has elapsed",
    async () => {
      const r = client();
      const key = `test:ops060:${RUN}:fixed-reset`;
      await resetRateLimit(r, key);
      const policy: RateLimitPolicy = {
        kind: "fixedWindow",
        limit: 1,
        windowSeconds: 1,
      };
      expect(
        (await consumeRateLimit(r, key, policy)).allowed,
      ).toBe(true);
      expect(
        (await consumeRateLimit(r, key, policy)).allowed,
      ).toBe(false);
      await new Promise((resolve) => setTimeout(resolve, 1100));
      expect(
        (await consumeRateLimit(r, key, policy)).allowed,
      ).toBe(true);
    },
  );

  redisTest(
    "sliding window is exact, not cliffted at the boundary",
    async () => {
      const r = client();
      const key = `test:ops060:${RUN}:sliding`;
      await resetRateLimit(r, key);
      const policy = window(3);
      // Two events at t=0, one at t=59s; the set holds all three.
      await consumeRateLimit(r, key, policy, {
        nowMs: FIXED_CLOCK,
        member: "a",
      });
      await consumeRateLimit(r, key, policy, {
        nowMs: FIXED_CLOCK,
        member: "b",
      });
      const third = await consumeRateLimit(r, key, policy, {
        nowMs: FIXED_CLOCK + 59_000,
        member: "c",
      });
      expect(third.allowed).toBe(true);
      // At t=61s the two t=0 entries have aged out exactly: one slot is
      // still held by the t=59s event, so the count is 1 not 3.
      const fourth = await consumeRateLimit(r, key, policy, {
        nowMs: FIXED_CLOCK + 61_000,
        member: "d",
      });
      expect(fourth.allowed).toBe(true);
      expect(fourth.remaining).toBe(1);
    },
  );

  redisTest("sliding window supports weighted cost", async () => {
    const r = client();
    const key = `test:ops060:${RUN}:sliding-cost`;
    await resetRateLimit(r, key);
    const policy: RateLimitPolicy = {
      kind: "slidingWindow",
      limit: 3,
      windowSeconds: 60,
      cost: 2,
    };
    const first = await consumeRateLimit(r, key, policy, {
      nowMs: FIXED_CLOCK,
    });
    expect(first.allowed).toBe(true);
    expect(first.remaining).toBe(1);
    const second = await consumeRateLimit(r, key, policy, {
      nowMs: FIXED_CLOCK + 1,
    });
    expect(second.allowed).toBe(false);
    expect(second.retryAfterMs).toBeGreaterThan(0);
  });

  redisTest("token bucket absorbs a burst then refills", async () => {
    const r = client();
    const key = `test:ops060:${RUN}:bucket`;
    await resetRateLimit(r, key);
    const policy: RateLimitPolicy = {
      kind: "tokenBucket",
      limit: 10,
      windowSeconds: 10,
      burst: 5,
    };
    // Full burst of 5 is accepted immediately.
    for (let i = 0; i < 5; i++) {
      const decision = await consumeRateLimit(r, key, policy, {
        nowMs: FIXED_CLOCK + i,
      });
      expect(decision.allowed).toBe(true);
    }
    const sixth = await consumeRateLimit(r, key, policy, {
      nowMs: FIXED_CLOCK + 5,
    });
    expect(sixth.allowed).toBe(false);
    // One token refills every second; after 2s there is room again.
    const later = await consumeRateLimit(r, key, policy, {
      nowMs: FIXED_CLOCK + 2100,
    });
    expect(later.allowed).toBe(true);
  });

  redisTest(
    "concurrent consumers share one budget without overshoot",
    async () => {
      const r = client();
      const key = `test:ops060:${RUN}:concurrency`;
      await resetRateLimit(r, key);
      const policy: RateLimitPolicy = {
        kind: "slidingWindow",
        limit: 20,
        windowSeconds: 60,
      };
      const results = await Promise.all(
        Array.from({ length: 50 }, (_, i) =>
          consumeRateLimit(r, key, policy, {
            nowMs: FIXED_CLOCK,
            member: `req-${i}`,
          })),
      );
      const allowedCount = results.filter((d) => d.allowed).length;
      expect(allowedCount).toBe(20);
      expect(
        results.filter((d) => !d.allowed).every((d) =>
          d.retryAfterMs != null && d.retryAfterMs > 0
        ),
      ).toBe(true);
    },
  );

  redisTest(
    "malformed policies are rejected before touching Redis",
    async () => {
      const r = client();
      const bad = { kind: "slidingWindow", limit: 0, windowSeconds: 60 };
      expect(() =>
        // @ts-expect-error malformed policy on purpose
        consumeRateLimit(r, `test:ops060:${RUN}:bad`, bad)
      ).toThrow();
      const badBucket = {
        kind: "tokenBucket",
        limit: 10,
        windowSeconds: 10,
        burst: 0,
      };
      expect(() =>
        // @ts-expect-error malformed policy on purpose
        consumeRateLimit(r, `test:ops060:${RUN}:bad`, badBucket)
      ).toThrow();
    },
  );

  redisTest("resetRateLimit clears accumulated state", async () => {
    const r = client();
    const key = `test:ops060:${RUN}:reset-clears`;
    const policy: RateLimitPolicy = {
      kind: "slidingWindow",
      limit: 1,
      windowSeconds: 60,
    };
    await consumeRateLimit(r, key, policy, { nowMs: FIXED_CLOCK });
    const blocked = await consumeRateLimit(r, key, policy, {
      nowMs: FIXED_CLOCK + 1,
    });
    expect(blocked.allowed).toBe(false);
    await resetRateLimit(r, key);
    const cleared = await consumeRateLimit(r, key, policy, {
      nowMs: FIXED_CLOCK + 2,
    });
    expect(cleared.allowed).toBe(true);
  });
});

describe("withRedisFailure", () => {
  test("wraps thrown errors in a typed RedisUnavailableError", async () => {
    const cause = new Error("ECONNREFUSED");
    await expect(withRedisFailure(() => Promise.reject(cause))).rejects.toThrow(
      RedisUnavailableError,
    );
    await expect(
      withRedisFailure(() => Promise.reject(cause)),
    ).rejects.toMatchObject({ code: "REDIS_UNAVAILABLE", original: cause });
  });

  test("passes successful values through untouched", async () => {
    expect(await withRedisFailure(() => Promise.resolve(42))).toBe(42);
  });
});

describe("redis cache adapter", () => {
  redisTest("set/get round-trips an envelope, delete clears", async () => {
    const r = client();
    const cache = new RedisCache(r, { prefix: `test:ops060:${RUN}:cache` });
    const key = cache.key("envelope");
    await cache.set(key, { a: 1 }, 5000, { jitterRatio: 0 });
    const envelope = await cache.get<{ a: number }>(key);
    expect(envelope?.v).toBe(1);
    expect(envelope?.data).toEqual({ a: 1 });
    expect(envelope?.ttlMs).toBe(5000);
    await cache.delete(key);
    expect(await cache.get(key)).toBeNull();
  });

  redisTest("corrupt payloads are treated as misses", async () => {
    const r = client();
    const cache = new RedisCache(r, { prefix: `test:ops060:${RUN}:cache` });
    const key = cache.key("corrupt");
    await r.set(key, "not json");
    expect(await cache.get(key)).toBeNull();
    expect(await r.exists(key)).toBe(0);
  });

  redisTest("getOrLoad hits, loads, and expires", async () => {
    const r = client();
    let clock = FIXED_CLOCK;
    const cache = new RedisCache(r, {
      prefix: `test:ops060:${RUN}:cache`,
      nowMs: () => clock,
    });
    const key = cache.key("hitmiss");
    let loads = 0;
    const load = () => Promise.resolve(++loads);
    const first = await cache.getOrLoad(key, { ttlMs: 1000, load });
    expect(first).toEqual({ value: 1, status: "loaded" });
    const second = await cache.getOrLoad(key, { ttlMs: 1000, load });
    expect(second).toEqual({ value: 1, status: "hit" });
    expect(loads).toBe(1);
    clock += 5000; // past the envelope TTL: must reload
    const third = await cache.getOrLoad(key, { ttlMs: 1000, load });
    expect(third).toEqual({ value: 2, status: "loaded" });
  });

  redisTest(
    "single-flight collapses concurrent misses into one load",
    async () => {
      const r = client();
      const cache = new RedisCache(r, { prefix: `test:ops060:${RUN}:cache` });
      const key = cache.key("stampede");
      let loads = 0;
      const result = await Promise.all(
        Array.from({ length: 8 }, () =>
          cache.getOrLoad(key, {
            ttlMs: 5000,
            lockMs: 10_000,
            load: async () => {
              loads += 1;
              // Long enough that every loser has already attempted the
              // lock before the winner releases it.
              await new Promise((resolve) => setTimeout(resolve, 300));
              return { n: loads };
            },
          })),
      );
      expect(loads).toBe(1);
      for (const entry of result) {
        expect(entry.value).toEqual({ n: 1 });
        expect(["hit", "loaded"]).toContain(entry.status);
      }
    },
  );

  redisTest("stale-while-revalidate serves bounded staleness", async () => {
    const r = client();
    let clock = FIXED_CLOCK;
    const cache = new RedisCache(r, {
      prefix: `test:ops060:${RUN}:cache`,
      nowMs: () => clock,
    });
    const key = cache.key("swr");
    let loads = 0;
    const load = () => Promise.resolve(++loads);
    const first = await cache.getOrLoad(key, { ttlMs: 1000, load });
    expect(first.status).toBe("loaded");
    clock += 1500; // expired but well inside a 10s stale bound
    const second = await cache.getOrLoad(key, {
      ttlMs: 1000,
      staleMs: 10_000,
      load,
    });
    expect(second.status).toBe("stale_hit");
    expect(second.value).toBe(1);
    // The background revalidation fires exactly once; give it a beat.
    await new Promise((resolve) => setTimeout(resolve, 150));
    expect(loads).toBe(2);
    // At the same (still-advanced) clock the revalidated value is fresh.
    const third = await cache.getOrLoad(key, {
      ttlMs: 1000,
      staleMs: 10_000,
      load,
    });
    expect(third.status).toBe("hit");
    expect(third.value).toBe(2);
  });

  redisTest("stale data is never served past the stale bound", async () => {
    const r = client();
    let clock = FIXED_CLOCK;
    const cache = new RedisCache(r, {
      prefix: `test:ops060:${RUN}:cache`,
      nowMs: () => clock,
    });
    const key = cache.key("swr-bound");
    let loads = 0;
    const load = () => Promise.resolve(++loads);
    await cache.getOrLoad(key, { ttlMs: 1000, load });
    clock += 30_000; // far beyond any stale bound
    const result = await cache.getOrLoad(key, {
      ttlMs: 1000,
      staleMs: 10_000,
      load,
    });
    expect(result.status).toBe("loaded");
    expect(result.value).toBe(2);
  });

  redisTest("invalid TTL is rejected before any Redis call", async () => {
    const r = client();
    const cache = new RedisCache(r, { prefix: `test:ops060:${RUN}:cache` });
    expect(() =>
      cache.getOrLoad("k", { ttlMs: 0, load: () => Promise.resolve(1) })
    ).toThrow(CacheConfigError);
  });

  redisTest("prefix without a namespace separator is rejected", () => {
    expect(() => new RedisCache(client(), { prefix: "studafy" })).toThrow(
      CacheConfigError,
    );
  });
});
