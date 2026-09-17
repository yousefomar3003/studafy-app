import type { Redis } from "./redis";

/**
 * OPS-060 Redis cache adapter. The API layer decides *what* is cacheable and
 * how long it may live (the cache catalogue); this module only provides the
 * safe mechanics: versioned keys supplied by the caller, single-flight
 * loading, bounded staleness, TTL jitter, and typed failure propagation.
 * It never stores an authorization decision - callers must only point it at
 * catalogue entries whose invalidation story is proven.
 */

export interface CacheEvent {
  kind:
    | "hit"
    | "miss"
    | "stale_hit"
    | "single_flight_wait"
    | "single_flight_loader"
    | "single_flight_timeout";
  key: string;
}

export interface RedisCacheOptions {
  /**
   * Key namespace, e.g. "studafy:{env}:cache". Must stay distinct from the
   * limiter namespace and the BullMQ prefix (studafy-{env}:...) so a cache
   * can never evict a job payload.
   */
  prefix: string;
  /** Injectable clock (defaults to Date.now()). */
  nowMs?: () => number;
  /** Observability hook; never receives values, only key shapes. */
  onEvent?: (event: CacheEvent) => void;
}

export interface CacheEnvelope<T> {
  /** Written envelope version. */
  v: 1;
  /** Epoch ms when the entry was written. */
  writtenAt: number;
  /** TTL the writer asked for, kept so readers can compute staleness. */
  ttlMs: number;
  data: T;
}

export interface GetOrLoadOptions<T> {
  /** Exact TTL for the cached value in milliseconds (must be > 0). */
  ttlMs: number;
  /** Loader that produces the value on a miss. */
  load: () => Promise<T>;
  /**
   * Bound stale-while-revalidate: when set, an expired entry may be served
   * for this many extra milliseconds while a single-flight revalidation
   * runs. Sensitive entries must leave it unset.
   */
  staleMs?: number;
  /** Lock lifetime for single-flight loading (default 5000). */
  lockMs?: number;
  /** How long a late joiner waits for the winner before loading itself. */
  waitMs?: number;
}

export type CacheResultStatus = "hit" | "loaded" | "stale_hit";

export interface CacheResult<T> {
  value: T;
  status: CacheResultStatus;
}

const LOCK_SCRIPT = `
if redis.call("GET", KEYS[1]) == ARGV[1] then
  return redis.call("DEL", KEYS[1])
end
return 0
`;

function defaultNowMs(): number {
  return Date.now();
}

export class CacheConfigError extends Error {
  readonly code = "CACHE_CONFIG_INVALID";
  constructor(message: string) {
    super(message);
    this.name = "CacheConfigError";
  }
}

export class RedisCache {
  readonly #redis: Redis;
  readonly #prefix: string;
  readonly #nowMs: () => number;
  readonly #onEvent?: (event: CacheEvent) => void;

  constructor(redis: Redis, options: RedisCacheOptions) {
    if (!options.prefix || !options.prefix.includes(":")) {
      // The prefix must look like "studafy:{env}:cache" so built keys are
      // always "prefix:rest" and can never drift into another module's
      // namespace (limiter, BullMQ).
      throw new CacheConfigError(
        "cache prefix must contain a namespace separator",
      );
    }
    this.#redis = redis;
    this.#prefix = options.prefix;
    this.#nowMs = options.nowMs ?? defaultNowMs;
    this.#onEvent = options.onEvent;
  }

  /** Builds the full Redis key from caller-owned parts (digests, ids). */
  key(...parts: string[]): string {
    return [this.#prefix, ...parts].join(":");
  }

  async get<T>(key: string): Promise<CacheEnvelope<T> | null> {
    const raw = await this.#redis.get(key);
    if (raw == null) return null;
    try {
      const parsed = JSON.parse(raw) as CacheEnvelope<T>;
      if (parsed?.v !== 1 || typeof parsed.writtenAt !== "number") {
        await this.#redis.del(key);
        return null;
      }
      return parsed;
    } catch {
      // A corrupt or foreign payload is treated as a miss, never propagated.
      await this.#redis.del(key);
      return null;
    }
  }

  async set<T>(
    key: string,
    data: T,
    ttlMs: number,
    options: { jitterRatio?: number } = {},
  ): Promise<void> {
    if (!Number.isFinite(ttlMs) || ttlMs <= 0) {
      throw new CacheConfigError("ttlMs must be a positive number");
    }
    const jitterRatio = options.jitterRatio ?? 0.1;
    const jitter = Math.round(ttlMs * jitterRatio * Math.random());
    const envelope: CacheEnvelope<T> = {
      v: 1,
      writtenAt: this.#nowMs(),
      ttlMs,
      data,
    };
    await this.#redis.set(
      key,
      JSON.stringify(envelope),
      "PX",
      Math.max(1, ttlMs + jitter),
    );
  }

  async delete(...keys: string[]): Promise<void> {
    if (keys.length === 0) return;
    await this.#redis.del(...keys);
  }

  /**
   * Returns a cached value or loads it. Concurrent misses for the same key
   * are collapsed into one loader invocation through a SET NX lock; if the
   * lock does not resolve within waitMs, the loser loads anyway (bounded,
   * never hangs). Redis failures propagate to the caller, which applies the
   * catalogue's failure mode (fall back to the loader for safe entries).
   */
  async getOrLoad<T>(
    key: string,
    options: GetOrLoadOptions<T>,
  ): Promise<CacheResult<T>> {
    const { ttlMs, load } = options;
    if (!Number.isFinite(ttlMs) || ttlMs <= 0) {
      throw new CacheConfigError("ttlMs must be a positive number");
    }

    const existing = await this.get<T>(key);
    if (existing && this.#fresh(existing)) {
      this.#onEvent?.({ kind: "hit", key });
      return { value: existing.data, status: "hit" };
    }

    // Bounded stale-while-revalidate: an expired entry inside the stale
    // bound is served immediately while one background loader refreshes it
    // under the single-flight lock. Sensitive entries must leave staleMs
    // unset, which routes every expired read through the strict path below.
    const staleUsable = options.staleMs != null && options.staleMs > 0 &&
      existing != null &&
      this.#nowMs() - existing.writtenAt <= existing.ttlMs + options.staleMs;
    if (staleUsable) {
      this.#onEvent?.({ kind: "stale_hit", key });
      void this.#revalidate(key, options).catch(() => undefined);
      return { value: existing!.data, status: "stale_hit" };
    }

    const lockKey = `${key}:lock`;
    const lockToken = `${this.#nowMs()}-${Math.random().toString(36).slice(2)}`;
    const lockMs = options.lockMs ?? 5000;
    const waitMs = options.waitMs ?? 2000;

    const acquired = await this.#redis.set(
      lockKey,
      lockToken,
      "PX",
      lockMs,
      "NX",
    );
    if (acquired) {
      try {
        const value = await load();
        await this.set(key, value, ttlMs, { jitterRatio: 0 });
        this.#onEvent?.({ kind: "miss", key });
        return { value, status: "loaded" };
      } finally {
        await this.#redis.eval(LOCK_SCRIPT, 1, lockKey, lockToken);
      }
    }

    // Someone else holds the lock: poll for the winner's write, then fall
    // back to loading locally so a wedged lock cannot wedge requests.
    const deadline = this.#nowMs() + waitMs;
    while (this.#nowMs() < deadline) {
      await new Promise((resolve) => setTimeout(resolve, 25));
      const polled = await this.get<T>(key);
      if (polled && this.#fresh(polled)) {
        this.#onEvent?.({ kind: "single_flight_wait", key });
        return { value: polled.data, status: "hit" };
      }
    }
    const value = await load();
    await this.set(key, value, ttlMs);
    this.#onEvent?.({ kind: "miss", key });
    return { value, status: "loaded" };
  }

  /** Background revalidation for stale-while-revalidate; never throws. */
  async #revalidate<T>(
    key: string,
    options: GetOrLoadOptions<T>,
  ): Promise<void> {
    const lockKey = `${key}:lock`;
    const lockToken = `${this.#nowMs()}-${Math.random().toString(36).slice(2)}`;
    const lockMs = options.lockMs ?? 5000;
    const acquired = await this.#redis.set(
      lockKey,
      lockToken,
      "PX",
      lockMs,
      "NX",
    );
    if (!acquired) return;
    try {
      const value = await options.load();
      await this.set(key, value, options.ttlMs, { jitterRatio: 0 });
      this.#onEvent?.({ kind: "single_flight_loader", key });
    } finally {
      await this.#redis.eval(LOCK_SCRIPT, 1, lockKey, lockToken);
    }
  }

  #fresh(envelope: CacheEnvelope<unknown>): boolean {
    return this.#nowMs() - envelope.writtenAt < envelope.ttlMs;
  }
}
