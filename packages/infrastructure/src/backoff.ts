/**
 * Retry backoff policy shared by the BullMQ layer and the database release
 * path (OPS-061, §10.652: exponential backoff with full jitter, capped by
 * business semantics).
 *
 * BullMQ's built-in `exponential` strategy already implements full jitter:
 * delay = uniform in [0, min(cap, base * 2^(attempt-1))]. The database
 * release function computes the same ceiling
 * (`least(cap, base * 2^attempt)` seconds). `maxDelayMs` is the mirror the
 * drift tests assert across both layers.
 */
import type { JobsOptions } from "bullmq";

export interface BackoffPolicy {
  /** Delay before the first retry, in milliseconds. */
  baseMs: number;
  /** Upper bound for any single delay, in milliseconds. */
  capMs: number;
  /** Total retry attempts before a job dead-letters. */
  attempts: number;
}

/** The largest delay an attempt may yield, mirroring the SQL release path. */
export function maxDelayMs(policy: BackoffPolicy, attempt: number): number {
  const safeAttempt = Math.max(1, attempt);
  const uncapped = policy.baseMs * 2 ** (safeAttempt - 1);
  return Math.min(policy.capMs, uncapped);
}

/**
 * BullMQ backoff options implementing the policy. `jitter: 1` is full
 * jitter (uniform [0, max]); the strategy is built-in, so no custom
 * `settings.backoffStrategy` registration is needed.
 */
export function backoffOptions(policy: BackoffPolicy): JobsOptions["backoff"] {
  return {
    type: "exponential",
    delay: policy.baseMs,
    jitter: 1,
  };
}
