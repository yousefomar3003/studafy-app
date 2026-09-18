import { describe, expect, test } from "bun:test";
import { Job } from "bullmq";
import {
  isFinalAttempt,
  normalizedErrorCode,
  outboxIdFromJobId,
  outboxJobId,
} from "../src/platform/jobGuards";

function fakeJob(attemptsMade: number, attempts: number): Job {
  return {
    attemptsMade,
    opts: { attempts },
  } as unknown as Job;
}

describe("job guards", () => {
  test("isFinalAttempt is true on the last allowed attempt", () => {
    expect(isFinalAttempt(fakeJob(0, 5))).toBe(false);
    expect(isFinalAttempt(fakeJob(3, 5))).toBe(false);
    expect(isFinalAttempt(fakeJob(4, 5))).toBe(true);
    expect(isFinalAttempt(fakeJob(5, 5))).toBe(true);
    expect(isFinalAttempt(fakeJob(0, 1))).toBe(true);
  });

  test("normalizedErrorCode stays bounded and stable", () => {
    expect(normalizedErrorCode(new Error("job payload mismatch"))).toBe(
      "INVALID_JOB_PAYLOAD",
    );
    expect(normalizedErrorCode(new Error("connection refused"))).toBe(
      "DEPENDENCY_UNAVAILABLE",
    );
    expect(normalizedErrorCode(new Error("what happened"))).toBe(
      "PROCESSING_FAILED",
    );
    expect(normalizedErrorCode("boom")).toBe("PROCESSING_FAILED");
  });

  test("deterministic outbox job ids round-trip", () => {
    expect(outboxJobId(42)).toBe("outbox-42");
    expect(outboxIdFromJobId("outbox-42")).toBe(42);
    expect(outboxIdFromJobId("outbox-x")).toBeNull();
    expect(outboxIdFromJobId("smoke-job")).toBeNull();
  });
});
