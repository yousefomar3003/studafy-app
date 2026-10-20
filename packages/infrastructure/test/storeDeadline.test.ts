import { describe, expect, test } from "bun:test";
import { STORE_API_TIMEOUT_MS, withDeadline } from "../src";

describe("store API time limit", () => {
  test("a call that never answers fails with a timeout", async () => {
    const never = new Promise<string>(() => undefined);
    await expect(withDeadline(never, 10, "google subscription lookup"))
      .rejects.toThrow("google subscription lookup: timeout after 10 ms");
  });

  test("an answer in time, or a failure, passes through", async () => {
    expect(await withDeadline(Promise.resolve("ok"), 1_000, "x")).toBe("ok");
    await expect(
      withDeadline(Promise.reject(new Error("401")), 1_000, "x"),
    ).rejects.toThrow("401");
  });

  test("the default leaves room for a slow store but not forever", () => {
    expect(STORE_API_TIMEOUT_MS).toBeGreaterThanOrEqual(10_000);
    expect(STORE_API_TIMEOUT_MS).toBeLessThanOrEqual(30_000);
  });
});
