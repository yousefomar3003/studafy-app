import { describe, expect, test } from "bun:test";
import { isScoreInRange } from "../src";

describe("isScoreInRange", () => {
  test("accepts scores inside the range", () => {
    expect(isScoreInRange(0, 10)).toBe(true);
    expect(isScoreInRange(7.5, 10)).toBe(true);
    expect(isScoreInRange(10, 10)).toBe(true);
  });

  test("rejects negative, over-maximum, and non-finite values", () => {
    expect(isScoreInRange(-0.1, 10)).toBe(false);
    expect(isScoreInRange(10.1, 10)).toBe(false);
    expect(isScoreInRange(Number.NaN, 10)).toBe(false);
    expect(isScoreInRange(Number.POSITIVE_INFINITY, 10)).toBe(false);
  });

  test("rejects non-positive or non-finite maximums", () => {
    expect(isScoreInRange(1, 0)).toBe(false);
    expect(isScoreInRange(1, -5)).toBe(false);
    expect(isScoreInRange(1, Number.NaN)).toBe(false);
  });
});
