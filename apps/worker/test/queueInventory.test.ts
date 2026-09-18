import { describe, expect, test } from "bun:test";
import { JobQueueName } from "@studafy/contracts";
import {
  defaultJobOptionsFor,
  IMPLEMENTED_QUEUES,
  QUEUE_INVENTORY,
  queueDefinition,
  queuePrefix,
  workerOptionsFor,
} from "../src/platform/queueInventory";

describe("queue inventory", () => {
  test("covers every §10 queue name exactly", () => {
    expect(Object.keys(QUEUE_INVENTORY).sort()).toEqual(
      [...JobQueueName.options].sort(),
    );
  });

  test("notifications and billing-events are implemented; the rest declared", () => {
    expect(QUEUE_INVENTORY["notifications"]?.status).toBe("implemented");
    expect(QUEUE_INVENTORY["billing-events"]?.status).toBe("implemented");
    const declared = Object.values(QUEUE_INVENTORY).filter(
      (definition) => definition.status === "declared",
    );
    expect(declared).toHaveLength(6);
  });

  test("implemented queue set matches what the worker boots", () => {
    expect(IMPLEMENTED_QUEUES).toContain("smoke");
    expect(IMPLEMENTED_QUEUES).toContain("notifications");
    expect(IMPLEMENTED_QUEUES).toContain("billing-events");
  });

  test("every definition carries a bounded retry policy", () => {
    for (const definition of Object.values(QUEUE_INVENTORY)) {
      expect(definition.backoff.attempts).toBeGreaterThanOrEqual(1);
      expect(definition.backoff.baseMs).toBeGreaterThan(0);
      expect(definition.backoff.capMs).toBeGreaterThanOrEqual(
        definition.backoff.baseMs,
      );
      expect(definition.timeoutMs).toBeGreaterThan(0);
      expect(definition.concurrency).toBeGreaterThanOrEqual(1);
      expect(definition.idempotencyKey.length).toBeGreaterThan(0);
    }
  });

  test("notifications uses five jittered exponential retries (§10)", () => {
    const definition = queueDefinition("notifications");
    expect(definition.backoff.attempts).toBe(5);
    expect(defaultJobOptionsFor(definition)).toMatchObject({
      attempts: 5,
      backoff: { type: "exponential", delay: 5_000, jitter: 1 },
      removeOnFail: false,
    });
  });

  test("worker options carry stall-recovery settings", () => {
    const options = workerOptionsFor(queueDefinition("notifications"));
    expect(options.lockDurationMs).toBeGreaterThan(0);
    expect(options.stalledIntervalMs).toBeGreaterThan(0);
    expect(options.maxStalledCount).toBeGreaterThanOrEqual(1);
  });

  test("queueDefinition fails closed on an unknown queue", () => {
    expect(() => queueDefinition("unknown-queue")).toThrow(/inventory/);
  });

  test("prefix is the BullMQ namespace, disjoint from limiter/cache", () => {
    expect(queuePrefix("development")).toBe("studafy-development");
    expect(queuePrefix("production")).toBe("studafy-production");
    expect(queuePrefix("production").startsWith("studafy:{env}")).toBe(false);
  });
});
