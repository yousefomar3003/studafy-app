import { describe, expect, test } from "bun:test";
import type { Job } from "bullmq";
import { createJsonLogger } from "@studafy/observability";
import { LogCollector } from "@studafy/test-support";
import type {
  NotificationFinishOutcome,
  OutboxDispatchPort,
} from "../src/outbox/outboxDispatch";
import { createNotificationProcessor } from "../src/processors/notifications";

// The notification processor's outcomes, one by one (launch plan 7.1). The
// end-to-end path through Postgres and Redis is outbox.integration.test.ts.

const payload = {
  outboxId: 41,
  schoolId: "7c000000-0000-4000-8000-000000000001",
  templateKey: "academic.assignment_published",
  channel: "in_app",
  audience: { kind: "classroom" },
  payload: {},
};

function job(data: unknown, attemptsMade = 0, attempts = 5): Job {
  return { id: "outbox-41", data, attemptsMade, opts: { attempts } } as Job;
}

function harness(finish: () => Promise<NotificationFinishOutcome>) {
  const failed: { outboxId: number; code: string }[] = [];
  const dispatch = {
    finishNotification: finish,
    failDispatch: (outboxId: number, code: string) => {
      failed.push({ outboxId, code });
      return Promise.resolve(true);
    },
  } as unknown as OutboxDispatchPort;
  const collector = new LogCollector();
  const logger = createJsonLogger("worker", "test", "debug", collector.sink);
  return {
    run: createNotificationProcessor(dispatch, logger),
    failed,
    events: () => collector.events(),
  };
}

describe("notification processor", () => {
  test("a payload that does not match the contract is never retried", async () => {
    const h = harness(() => Promise.resolve("completed"));
    const error = await h.run(job({ outboxId: "x" }), "token").catch((e) => e);
    expect((error as Error).name).toBe("UnrecoverableError");
    expect(h.events()).toContain("notification_job_invalid_payload");
  });

  test("completed: the deliveries were created", async () => {
    const h = harness(() => Promise.resolve("completed"));
    expect(await h.run(job(payload), "token")).toEqual({ ok: true });
    expect(h.events()).toContain("notification_job_completed");
  });

  test("terminal: the database dead-lettered the row, so BullMQ must not retry", async () => {
    const h = harness(() => Promise.resolve("terminal"));
    expect(await h.run(job(payload), "token")).toEqual({
      ok: true,
      deadLetter: true,
    });
    expect(h.failed).toEqual([]);
  });

  test("lost: retried while attempts remain, without dead-lettering", async () => {
    const h = harness(() => Promise.resolve("lost"));
    const error = await h.run(job(payload, 1), "token").catch((e) => e);
    expect((error as Error).message).toBe("notification claim lost");
    expect(h.events()).toContain("notification_job_retry");
    expect(h.failed).toEqual([]);
  });

  test("on the final attempt the row is dead-lettered with a bounded code", async () => {
    const h = harness(() => Promise.resolve("lost"));
    const error = await h.run(job(payload, 4, 5), "token").catch((e) => e);
    expect((error as Error).name).toBe("UnrecoverableError");
    expect(h.failed).toEqual([{ outboxId: 41, code: "PROCESSING_FAILED" }]);
    expect(h.events()).toContain("notification_job_exhausted");
  });

  test("a database outage is classified, never logged raw", async () => {
    const h = harness(() =>
      Promise.reject(new Error("connection refused to 10.0.0.5:5432"))
    );
    const error = await h.run(job(payload, 4, 5), "token").catch((e) => e);
    expect((error as Error).message).toBe("DEPENDENCY_UNAVAILABLE");
    expect(h.failed[0]?.code).toBe("DEPENDENCY_UNAVAILABLE");
  });
});
