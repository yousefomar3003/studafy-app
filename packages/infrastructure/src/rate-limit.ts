import type { Redis } from "./redis";

/**
 * OPS-060 rate-limit primitives. Every decision is made atomically inside a
 * single Lua script so concurrent instances of the API behind one Redis share
 * one budget: two simultaneous requests can never both see "one slot left"
 * and both take it. Time is supplied by the caller (tests pass a fixed clock)
 * and stored inside Redis state, never read with TIME.
 */

export interface FixedWindowPolicy {
  kind: "fixedWindow";
  /** Maximum events per window. */
  limit: number;
  windowSeconds: number;
  /** Weight consumed per event (default 1). */
  cost?: number;
}

/**
 * Exact sliding-window counter over a sorted set. O(history) memory, so it is
 * reserved for low-volume sensitive flows (login attempts, linking, admin)
 * where a fixed-window cliff or a smoothed bucket would be the wrong answer.
 */
export interface SlidingWindowPolicy {
  kind: "slidingWindow";
  limit: number;
  windowSeconds: number;
  cost?: number;
}

/**
 * Token bucket with continuous refill: `limit` events per `windowSeconds`
 * sustained, up to `burst` tokens in the bucket at once (default: limit).
 * Used for ordinary authenticated traffic, which is bursty by nature.
 */
export interface TokenBucketPolicy {
  kind: "tokenBucket";
  limit: number;
  windowSeconds: number;
  burst?: number;
  cost?: number;
}

export type RateLimitPolicy =
  | FixedWindowPolicy
  | SlidingWindowPolicy
  | TokenBucketPolicy;

export interface RateLimitDecision {
  allowed: boolean;
  /** Events still available before this key is blocked. */
  remaining: number;
  /** Milliseconds until the policy would accept one event; null when allowed. */
  retryAfterMs: number | null;
}

export interface ConsumeOptions {
  /**
   * Unique member id for sliding-window accounting (a request id). Colliding
   * members collapse into one event, so callers must pass a unique value.
   */
  member?: string;
  /** Overrides the policy's per-event cost for this call (e.g. weights). */
  cost?: number;
  /** Injectable clock in epoch milliseconds (defaults to Date.now()). */
  nowMs?: number;
}

export class RateLimitConfigError extends Error {
  readonly code = "RATE_LIMIT_CONFIG_INVALID";
  constructor(message: string) {
    super(message);
    this.name = "RateLimitConfigError";
  }
}

function validatePolicy(policy: RateLimitPolicy): {
  limit: number;
  windowSeconds: number;
  cost: number;
} {
  const { limit, windowSeconds } = policy;
  const cost = policy.cost ?? 1;
  if (!Number.isInteger(limit) || limit < 1) {
    throw new RateLimitConfigError("limit must be a positive integer");
  }
  if (!Number.isInteger(windowSeconds) || windowSeconds < 1) {
    throw new RateLimitConfigError("windowSeconds must be a positive integer");
  }
  if (!Number.isInteger(cost) || cost < 1) {
    throw new RateLimitConfigError("cost must be a positive integer");
  }
  return { limit, windowSeconds, cost };
}

/**
 * Fixed-window counter. The cheapest primitive: one INCR. The documented
 * trade-off (a burst of 2x limit across a window boundary) is acceptable for
 * the high-cardinality public edge limiter where it is used.
 */
const FIXED_WINDOW_SCRIPT = `
local count = redis.call("INCRBY", KEYS[1], ARGV[3])
local limit = tonumber(ARGV[1])
local windowMs = tonumber(ARGV[2])
if count == tonumber(ARGV[3]) then
  redis.call("PEXPIRE", KEYS[1], windowMs)
end
if count > limit then
  local pttl = redis.call("PTTL", KEYS[1])
  local retryAfterMs = pttl > 0 and pttl or windowMs
  return {0, 0, retryAfterMs}
end
return {1, limit - count, 0}
`;

/**
 * Exact sliding window over a sorted set. Weights are represented by adding
 * one member per cost unit so ZCARD is the authoritative counter. Entries
 * older than the window are trimmed before counting.
 */
const SLIDING_WINDOW_SCRIPT = `
local now = tonumber(ARGV[1])
local windowMs = tonumber(ARGV[2])
local member = ARGV[3]
local cost = tonumber(ARGV[4])
local limit = tonumber(ARGV[5])
redis.call("ZREMRANGEBYSCORE", KEYS[1], "-inf", now - windowMs)
local count = redis.call("ZCARD", KEYS[1])
if count + cost <= limit then
  for i = 1, cost do
    if i == 1 then
      redis.call("ZADD", KEYS[1], now, member)
    else
      redis.call("ZADD", KEYS[1], now, member .. "#" .. i)
    end
  end
  redis.call("PEXPIRE", KEYS[1], windowMs)
  return {1, limit - count - cost, 0}
end
local oldest = redis.call("ZRANGE", KEYS[1], 0, 0, "WITHSCORES")
local resetMs = 0
if #oldest >= 2 then
  resetMs = math.max(1, math.ceil(tonumber(oldest[2]) + windowMs - now))
end
return {0, math.max(0, limit - count), resetMs}
`;

/**
 * Token bucket with continuous refill, state in a small hash. The bucket
 * starts full, so a fresh key tolerates a full burst immediately and then
 * recovers at the sustained rate.
 */
const TOKEN_BUCKET_SCRIPT = `
local key = KEYS[1]
local now = tonumber(ARGV[1])
local capacity = tonumber(ARGV[2])
local refillPerMs = tonumber(ARGV[3])
local cost = tonumber(ARGV[4])
local ttlMs = tonumber(ARGV[5])
local state = redis.call("HMGET", key, "tokens", "ts")
local tokens = tonumber(state[1])
local ts = tonumber(state[2])
if tokens == nil or ts == nil then
  tokens = capacity
  ts = now
end
local elapsed = now - ts
if elapsed > 0 then
  tokens = math.min(capacity, tokens + elapsed * refillPerMs)
end
if tokens >= cost then
  tokens = tokens - cost
  redis.call("HSET", key, "tokens", tokens, "ts", now)
  redis.call("PEXPIRE", key, ttlMs)
  return {1, math.floor(tokens), 0}
end
local retryAfterMs = math.ceil((cost - tokens) / refillPerMs)
redis.call("HSET", key, "tokens", tokens, "ts", now)
redis.call("PEXPIRE", key, ttlMs)
return {0, math.floor(tokens), retryAfterMs}
`;

/**
 * Consumes `cost` units from the policy for `key`, atomically. Throws on
 * Redis failure (callers map that to their documented failure mode) and on
 * malformed policies.
 */
export async function consumeRateLimit(
  redis: Redis,
  key: string,
  policy: RateLimitPolicy,
  options: ConsumeOptions = {},
): Promise<RateLimitDecision> {
  const configured = validatePolicy(policy);
  const cost = options.cost ?? configured.cost;
  const { limit, windowSeconds } = configured;
  const nowMs = options.nowMs ?? Date.now();
  const windowMs = windowSeconds * 1000;
  if (policy.kind === "fixedWindow") {
    const reply = (await redis.eval(
      FIXED_WINDOW_SCRIPT,
      1,
      key,
      String(limit),
      String(windowMs),
      String(cost),
    )) as [number, number, number];
    return {
      allowed: reply[0] === 1,
      remaining: reply[1],
      retryAfterMs: reply[0] === 1 ? null : reply[2],
    };
  }
  if (policy.kind === "slidingWindow") {
    const member = options.member ??
      `${nowMs}-${Math.random().toString(36).slice(2)}`;
    const reply = (await redis.eval(
      SLIDING_WINDOW_SCRIPT,
      1,
      key,
      String(nowMs),
      String(windowMs),
      member,
      String(cost),
      String(limit),
    )) as [number, number, number];
    return {
      allowed: reply[0] === 1,
      remaining: reply[1],
      retryAfterMs: reply[0] === 1 ? null : reply[2],
    };
  }
  const capacity = policy.burst ?? limit;
  // Capacity may be smaller than the window's limit (a burst allowance
  // tighter than one window's worth of events), but it must be able to hold
  // at least one event's cost or nothing could ever pass.
  if (!Number.isInteger(capacity) || capacity < cost) {
    throw new RateLimitConfigError(
      "burst must be a positive integer >= cost",
    );
  }
  // A bucket must always make progress: refillPerMs = limit / windowMs > 0
  // for any validated policy. Internal guard against degenerate rounding.
  const refillPerMs = limit / windowMs;
  if (refillPerMs <= 0) {
    throw new RateLimitConfigError("refill rate must be positive");
  }
  // State older than two windows is simply dropped; a fresh bucket starts
  // full, which is the standard (and acceptable) reward for a long idle.
  const ttlMs = windowMs * 2;
  const reply = (await redis.eval(
    TOKEN_BUCKET_SCRIPT,
    1,
    key,
    String(nowMs),
    String(capacity),
    String(refillPerMs),
    String(cost),
    String(ttlMs),
  )) as [number, number, number];
  return {
    allowed: reply[0] === 1,
    remaining: reply[1],
    retryAfterMs: reply[0] === 1 ? null : reply[2],
  };
}

/**
 * Drops limiter state for a key. Used by tests and by the documented
 * operator action of clearing a wrongly accumulated counter.
 */
export async function resetRateLimit(
  redis: Redis,
  ...keys: string[]
): Promise<void> {
  if (keys.length === 0) return;
  await redis.del(...keys);
}
