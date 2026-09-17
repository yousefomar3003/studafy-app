import { describe, expect, test } from "bun:test";
import { backoffOptions, type BackoffPolicy, maxDelayMs } from "../src/backoff";

const policy: BackoffPolicy = {
  baseMs: 5_000,
  capMs: 60 * 60_000,
  attempts: 5,
};

describe("backoff policy", () => {
  test("maxDelayMs doubles per attempt", () => {
    expect(maxDelayMs(policy, 1)).toBe(5_000);
    expect(maxDelayMs(policy, 2)).toBe(10_000);
    expect(maxDelayMs(policy, 3)).toBe(20_000);
    expect(maxDelayMs(policy, 4)).toBe(40_000);
    expect(maxDelayMs(policy, 5)).toBe(80_000);
  });

  test("maxDelayMs caps at the ceiling", () => {
    const capped: BackoffPolicy = {
      baseMs: 5_000,
      capMs: 12_000,
      attempts: 6,
    };
    expect(maxDelayMs(capped, 3)).toBe(12_000);
    expect(maxDelayMs(capped, 9)).toBe(12_000);
  });

  test("maxDelayMs clamps non-positive attempts to the base", () => {
    expect(maxDelayMs(policy, 0)).toBe(5_000);
    expect(maxDelayMs(policy, -3)).toBe(5_000);
  });

  test("backoffOptions encodes exponential full jitter", () => {
    expect(backoffOptions(policy)).toEqual({
      type: "exponential",
      delay: 5_000,
      jitter: 1,
    });
  });

  test("the delay ceiling mirrors the SQL release path", () => {
    // private.api061_release_dispatch: least(3600, 5 * 2^attempt) seconds.
    for (const attempt of [1, 2, 3, 4, 5]) {
      const sqlSeconds = Math.min(
        3600,
        5 * 2 ** Math.min(attempt, 9),
      );
      expect(sqlSeconds * 1000).toBe(maxDelayMs(policy, attempt + 1));
    }
  });
});
