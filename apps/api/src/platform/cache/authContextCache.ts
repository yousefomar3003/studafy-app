/**
 * OPS-060 Redis-backed session-context cache.
 *
 * Wraps AuthContextRepository.load with a version-keyed Redis entry. The key
 * embeds the account generation, which every auth-state mutation bumps, so a
 * sign-out or device revocation changes the key instantly - the cache is
 * provably revocation-safe even at a zero revocation budget (ADR-0022).
 * Keys carry HMAC(subject), never the raw identifier. A Redis failure falls
 * back to the DB loader (fail closed to fresh state); the loader itself is
 * never short-circuited by a cache error.
 */
import {
  type Redis,
  RedisCache,
  RedisUnavailableError,
  withRedisFailure,
} from "@studafy/infrastructure";
import type { SessionContext } from "../../auth/context";
import { hmacSubject } from "../rate-limit/policies";
import { authContextTtlMs } from "./cacheCatalogue";

/**
 * Consumer-defined port (auth/context.ts) implemented over Redis. Kept in
 * one class so the auth layer never sees Redis details.
 */
export class RedisAuthContextCache {
  readonly #redis: Redis;
  readonly #cache: RedisCache;
  readonly #secret: string;
  readonly #ttlMs: number;

  constructor(
    redis: Redis,
    secret: string,
    options: { environment: string; budgetSeconds: number },
  ) {
    this.#redis = redis;
    this.#cache = new RedisCache(redis, {
      prefix: `studafy:{${options.environment}}:cache`,
    });
    this.#secret = secret;
    this.#ttlMs = authContextTtlMs(options.budgetSeconds);
  }

  #digest(subject: string): string {
    return hmacSubject(this.#secret, "authctx", subject);
  }

  /** Current generation for an account; bumped on every auth mutation. */
  async #generation(digest: string): Promise<string> {
    const raw = await withRedisFailure(() =>
      this.#redis.get(this.#cache.key("authctx-gen", digest))
    );
    return raw ?? "0";
  }

  async load(
    subject: string,
    loader: () => Promise<SessionContext | null>,
  ): Promise<SessionContext | null> {
    const digest = this.#digest(subject);
    try {
      const generation = await this.#generation(digest);
      const key = this.#cache.key("authctx", digest, generation);
      const result = await this.#cache.getOrLoad<SessionContext | null>(key, {
        ttlMs: this.#ttlMs,
        // Jitter is deliberately zero: the TTL is a committed staleness
        // bound, not a stampede-tuning knob, for this entry.
        load: loader,
      });
      return result.value;
    } catch (error) {
      // Redis down means the DB answers fresh (the catalogue's documented
      // failure mode); loader failures still propagate.
      if (error instanceof RedisUnavailableError) return await loader();
      throw error;
    }
  }

  /**
   * Bumps the account generation so the next load keys a fresh entry. Best
   * effort: a failed bump is bounded by the TTL, and the error surfaces as
   * REDIS_UNAVAILABLE for callers that treat it as a signal.
   */
  async invalidate(subject: string): Promise<void> {
    const digest = this.#digest(subject);
    try {
      await this.#redis.incr(this.#cache.key("authctx-gen", digest));
    } catch (error) {
      throw RedisUnavailableError.from(error);
    }
  }
}
