import { describe, expect, test } from "bun:test";
import { createJsonLogger } from "@studafy/observability";
import { LogCollector } from "@studafy/test-support";
import { startGuardedPoll } from "../src/platform/poller";
import { errorFields } from "../src/platform/jobGuards";

function deferred() {
  let resolve!: () => void;
  const promise = new Promise<void>((r) => resolve = r);
  return { promise, resolve };
}

function harness() {
  const collector = new LogCollector();
  return {
    collector,
    logger: createJsonLogger("worker", "test", "debug", collector.sink),
  };
}

describe("guarded poll (worker stall, 2026-10-20)", () => {
  test("a tick never starts a run while the previous one is in flight", async () => {
    const { logger } = harness();
    const gate = deferred();
    let runs = 0;
    const poll = startGuardedPoll({
      name: "outbox_dispatch",
      intervalMs: 3_600_000,
      run: async () => {
        runs++;
        await gate.promise;
      },
      logger,
    });
    const first = poll.run();
    const second = poll.run();
    const third = poll.run();
    expect(runs).toBe(0); // the run starts on the next microtask
    await Promise.resolve();
    expect(runs).toBe(1);
    gate.resolve();
    await Promise.all([first, second, third]);
    expect(runs).toBe(1);

    // Once it settled, the next tick runs again.
    await poll.run();
    expect(runs).toBe(2);
    await poll.close();
  });

  test("a failed run is logged with its code, never its message", async () => {
    const { collector, logger } = harness();
    const poll = startGuardedPoll({
      name: "channel_delivery",
      intervalMs: 3_600_000,
      run: () =>
        Promise.reject(
          Object.assign(new Error("value 'someone@example.com' broke"), {
            name: "PostgresError",
            code: "23505",
          }),
        ),
      logger,
    });
    await poll.run();
    await poll.close();
    const [line] = collector.parsed();
    expect(line).toMatchObject({
      level: "error",
      event: "channel_delivery_poll_failed",
      error_name: "PostgresError",
      error_code: "23505",
    });
    expect(collector.lines.join("\n")).not.toContain("example.com");
  });

  test("a run stuck past the stall limit is reported, once per period", async () => {
    const { collector, logger } = harness();
    let clock = 0;
    const gate = deferred();
    const poll = startGuardedPoll({
      name: "billing_dispatch",
      intervalMs: 3_600_000,
      stallAfterMs: 60_000,
      now: () => clock,
      run: () => gate.promise,
      logger,
    });
    void poll.run();
    clock = 30_000;
    void poll.run(); // in flight, not yet stalled: quiet
    clock = 61_000;
    void poll.run(); // stalled: reported
    clock = 90_000;
    void poll.run(); // reported less than a period ago: quiet
    clock = 125_000;
    void poll.run(); // reported again
    expect(collector.parsed()).toEqual([
      expect.objectContaining({
        event: "poll_stalled",
        poll: "billing_dispatch",
        in_flight_seconds: 61,
      }),
      expect.objectContaining({
        event: "poll_stalled",
        poll: "billing_dispatch",
        in_flight_seconds: 125,
      }),
    ]);
    gate.resolve();
    await poll.close();
  });

  test("runAtStart runs at once; close waits for it and stops the interval", async () => {
    const { logger } = harness();
    const gate = deferred();
    let runs = 0;
    let finished = false;
    const poll = startGuardedPoll({
      name: "outbox_dispatch",
      intervalMs: 5,
      run: async () => {
        runs++;
        await gate.promise;
        finished = true;
      },
      logger,
      runAtStart: true,
    });
    await Promise.resolve();
    expect(runs).toBe(1);
    const closing = poll.close();
    gate.resolve();
    await closing;
    expect(finished).toBe(true);
    await new Promise((resolve) => setTimeout(resolve, 20));
    expect(runs).toBe(1);
    await poll.run(); // closed: nothing runs
    expect(runs).toBe(1);
  });
});

describe("error log fields", () => {
  test("a Postgres error keeps its SQLSTATE, not its message", () => {
    const error = Object.assign(new Error("Key (email)=(a@b.c) exists"), {
      name: "PostgresError",
      code: "23505",
    });
    expect(errorFields(error)).toEqual({
      error_name: "PostgresError",
      error_code: "23505",
    });
  });

  test("client codes are kept; anything that is not a code is dropped", () => {
    expect(
      errorFields(Object.assign(new Error("x"), { code: "CONNECTION_CLOSED" })),
    ).toEqual({ error_name: "Error", error_code: "CONNECTION_CLOSED" });
    expect(errorFields(Object.assign(new Error("x"), { code: "a@b.c" })))
      .toEqual({ error_name: "Error" });
    expect(errorFields(Object.assign(new Error("x"), { code: 500 })))
      .toEqual({ error_name: "Error" });
    expect(errorFields(new Error("x"))).toEqual({ error_name: "Error" });
    expect(errorFields("boom")).toEqual({ error_name: "unknown" });
    expect(errorFields(null)).toEqual({ error_name: "unknown" });
  });
});
