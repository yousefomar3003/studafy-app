import { describe, expect, test } from "bun:test";
import type { Queue } from "@studafy/infrastructure";
import { createJsonLogger } from "@studafy/observability";
import { LogCollector } from "@studafy/test-support";
import { createOutboxDispatcher } from "../src/outbox/dispatcher";
import {
  type ClaimedOutboxRow,
  type DispatchRecordOutcome,
  dispatchRecordOutcome,
  type OutboxDispatchPort,
} from "../src/outbox/outboxDispatch";

// What the dispatcher logs when it cannot record a job id. The SQL answers
// are covered in supabase/tests/outbox_record_dispatched.sql; the queue and
// database together in outbox.integration.test.ts.

const row: ClaimedOutboxRow = {
  outboxId: 41,
  schoolId: "7c000000-0000-4000-8000-000000000001",
  channel: "in_app",
  templateKey: "academic.assignment_published",
  audience: { classroomId: "7c000000-0000-4000-8000-000000000002" },
  payload: {},
  bullmqJobId: null,
  attempt: 1,
};

function emptyQueue(): Queue {
  return {
    getJob: () => Promise.resolve(null),
    add: (_name: string, _data: unknown, opts: { jobId?: string } = {}) =>
      Promise.resolve({ id: opts.jobId }),
  } as unknown as Queue;
}

async function dispatchOnce(outcome: DispatchRecordOutcome) {
  const recorded: Array<[number, string]> = [];
  const released: number[] = [];
  const dispatch = {
    claim: () => Promise.resolve([row]),
    recordDispatched: (_worker: string, outboxId: number, jobId: string) => {
      recorded.push([outboxId, jobId]);
      return Promise.resolve(outcome);
    },
    releaseDispatch: (_worker: string, outboxId: number) => {
      released.push(outboxId);
      return Promise.resolve(true);
    },
    backlog: () => Promise.resolve({}),
  } as unknown as OutboxDispatchPort;
  const collector = new LogCollector();
  const logger = createJsonLogger("worker", "test", "debug", collector.sink);
  const dispatcher = createOutboxDispatcher(dispatch, emptyQueue(), logger);
  expect(await dispatcher.runOnce()).toBe(1);
  return {
    recorded,
    released,
    lines: collector.parsed()
      .filter((line) => String(line.event).startsWith("outbox_dispatch_"))
      .map((line) => [line.level, line.event, line.outbox_id]),
  };
}

describe("outbox dispatcher: recording the job id", () => {
  test("recorded: nothing to say", async () => {
    const result = await dispatchOnce("recorded");
    expect(result.recorded).toEqual([[41, "outbox-41"]]);
    expect(result.lines).toEqual([]);
    expect(result.released).toEqual([]);
  });

  test("already finished by the processor: an info line, not a warning", async () => {
    const result = await dispatchOnce("already_finished");
    expect(result.lines).toEqual([
      ["info", "outbox_dispatch_already_finished", 41],
    ]);
    expect(result.released).toEqual([]);
  });

  test("another dispatcher's lease, or no row: the warning stays", async () => {
    const result = await dispatchOnce("lease_lost");
    expect(result.lines).toEqual([
      ["warn", "outbox_dispatch_record_lost", 41],
    ]);
    expect(result.released).toEqual([]);
  });
});

describe("dispatchRecordOutcome", () => {
  test("passes the three answers through", () => {
    expect(dispatchRecordOutcome("recorded")).toBe("recorded");
    expect(dispatchRecordOutcome("already_finished")).toBe("already_finished");
    expect(dispatchRecordOutcome("lease_lost")).toBe("lease_lost");
  });

  test("anything else is treated as the case that warns", () => {
    expect(dispatchRecordOutcome(undefined)).toBe("lease_lost");
    expect(dispatchRecordOutcome(true)).toBe("lease_lost");
    expect(dispatchRecordOutcome("completed")).toBe("lease_lost");
  });
});
