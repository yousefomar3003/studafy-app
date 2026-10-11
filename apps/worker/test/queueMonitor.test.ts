import { describe, expect, test } from "bun:test";
import { createJsonLogger } from "@studafy/observability";
import {
  type AlertSender,
  closeQueue,
  createQueue,
  createRedis,
} from "@studafy/infrastructure";
import { LogCollector } from "@studafy/test-support";
import {
  type AlertRedis,
  duration,
  evaluate,
  memoryAlertState,
  type MonitorSnapshot,
  redisAlertState,
  startQueueMonitor,
  type Thresholds,
} from "../src/monitoring/queueMonitor";
import { monitorSources } from "../src/monitoring/sources";
import { testAlertText } from "../src/monitoring/sendTestAlert";

const thresholds: Thresholds = {
  maxDepth: 100,
  maxAgeSeconds: 300,
  maxFailedPerWindow: 5,
  windowSeconds: 300,
  stallSeconds: 600,
};

const quiet = (at: number, overrides: Partial<MonitorSnapshot> = {}) => ({
  at,
  queues: [{
    name: "notifications",
    waiting: 0,
    failed: 0,
    oldestWaitingSeconds: 0,
    oldestActiveSeconds: 0,
    stalledEvents: 0,
  }],
  backlogs: [{
    name: "file scan",
    pending: 0,
    oldestSeconds: 0,
    deadLetters: 0,
  }],
  ...overrides,
});

const keys = (history: MonitorSnapshot[]) =>
  evaluate(history, thresholds).map((f) => f.key);

describe("queue monitor thresholds", () => {
  test("a quiet system raises nothing", () => {
    expect(keys([quiet(0), quiet(60_000)])).toEqual([]);
  });

  test("depth and age over their limits", () => {
    const busy = quiet(60_000);
    busy.queues[0] = {
      ...busy.queues[0]!,
      waiting: 101,
      oldestWaitingSeconds: 301,
    };
    busy.backlogs[0] = {
      ...busy.backlogs[0]!,
      pending: 150,
      oldestSeconds: 900,
    };
    expect(keys([busy])).toEqual([
      "notifications:depth",
      "notifications:age",
      "file scan:depth",
      "file scan:age",
    ]);
    expect(evaluate([busy], thresholds)[0]!.summary).toBe(
      "notifications queue: 101 jobs waiting (limit 100)",
    );
  });

  test("failures count as growth within the window, and trimming is not growth", () => {
    const before = quiet(0);
    before.queues[0]!.failed = 40;
    const after = quiet(240_000);
    after.queues[0]!.failed = 46;
    expect(keys([before, after])).toEqual(["notifications:failed"]);

    // The removal policy trimmed failed jobs: the count fell.
    const trimmed = quiet(240_000);
    trimmed.queues[0]!.failed = 10;
    expect(keys([before, trimmed])).toEqual([]);

    // Growth that happened before the window does not count.
    const old = quiet(0);
    const later = quiet(400_000);
    later.queues[0]!.failed = 6;
    const latest = quiet(460_000);
    latest.queues[0]!.failed = 6;
    expect(keys([old, later, latest])).toEqual([]);
  });

  test("dead letters in a backlog count the same way", () => {
    const before = quiet(0);
    const after = quiet(60_000);
    after.backlogs[0]!.deadLetters = 5;
    expect(keys([before, after])).toEqual(["file scan:failed"]);
  });

  test("a job running past the stall limit, or a stalled-job event, is a stuck worker", () => {
    const stuck = quiet(60_000);
    stuck.queues[0]!.oldestActiveSeconds = 601;
    expect(evaluate([stuck], thresholds)[0]!.summary).toContain(
      "its worker may be stuck",
    );

    const lost = quiet(60_000);
    lost.queues[0]!.stalledEvents = 2;
    expect(keys([quiet(0), lost])).toEqual(["notifications:stalled"]);
  });

  test("durations read as people say them", () => {
    expect(duration(45)).toBe("45s");
    expect(duration(600)).toBe("10 min");
    expect(duration(10_800)).toBe("3 h");
  });
});

class FakeSender implements AlertSender {
  readonly sent: string[] = [];
  fail = false;
  send(text: string) {
    if (this.fail) return Promise.reject(new Error("TELEGRAM_REFUSED_500"));
    this.sent.push(text);
    return Promise.resolve();
  }
}

function harness() {
  let clock = 1_000_000;
  let sample = quiet(0);
  const sender = new FakeSender();
  const collector = new LogCollector();
  const monitor = startQueueMonitor({
    sample: () =>
      Promise.resolve({ queues: sample.queues, backlogs: sample.backlogs }),
    thresholds,
    cooldownSeconds: 1800,
    state: memoryAlertState(() => clock),
    sender,
    logger: createJsonLogger("worker", "test", "debug", collector.sink),
    environment: "test",
    intervalMs: 3_600_000,
    now: () => clock,
  });
  return {
    monitor,
    sender,
    collector,
    advance: (seconds: number) => clock += seconds * 1000,
    set: (waiting: number) => {
      sample = quiet(0);
      sample.queues[0]!.waiting = waiting;
    },
  };
}

describe("one incident, one alert", () => {
  test("alert once, stay quiet in the cooldown, remind after it, resolve once", async () => {
    const h = harness();
    h.set(500);
    await h.monitor.runOnce();
    expect(h.sender.sent).toEqual([
      "ALERT Studafy test: notifications queue: 500 jobs waiting (limit 100)",
    ]);

    h.advance(60);
    await h.monitor.runOnce();
    h.advance(60);
    await h.monitor.runOnce();
    expect(h.sender.sent).toHaveLength(1);

    h.advance(1800);
    await h.monitor.runOnce();
    expect(h.sender.sent[1]).toStartWith("STILL HAPPENING Studafy test:");

    h.set(3);
    h.advance(60);
    await h.monitor.runOnce();
    h.advance(60);
    await h.monitor.runOnce();
    expect(h.sender.sent.slice(2)).toEqual([
      "RESOLVED Studafy test: notifications depth is back within its limit",
    ]);
    await h.monitor.close();
  });

  test("a failed send is logged and does not stop the monitor", async () => {
    const h = harness();
    h.sender.fail = true;
    h.set(500);
    await h.monitor.runOnce();
    expect(h.collector.events()).toContain("queue_alert_send_failed");
    expect(h.collector.events()).toContain("queue_monitor_tick");
    await h.monitor.close();
  });
});

/** Just enough of Redis's SET NX EX and DEL. */
class FakeRedis implements AlertRedis {
  readonly values = new Map<string, number>();
  now = 0;
  set(key: string, _value: string, ...args: unknown[]): Promise<"OK" | null> {
    const expires = this.values.get(key);
    if (expires !== undefined && expires > this.now) {
      return Promise.resolve(null);
    }
    const ttl = args[0] === "EX" ? Number(args[1]) * 1000 : Infinity;
    this.values.set(key, this.now + ttl);
    return Promise.resolve("OK");
  }
  del(...keys: string[]): Promise<number> {
    let removed = 0;
    for (const key of keys) {
      if ((this.values.get(key) ?? -1) > this.now) removed++;
      this.values.delete(key);
    }
    return Promise.resolve(removed);
  }
}

describe("shared alert state", () => {
  test("two worker machines report an incident once between them", async () => {
    const redis = new FakeRedis();
    const a = redisAlertState(redis, "studafy-test");
    const b = redisAlertState(redis, "studafy-test");
    expect(await a.open("notifications:depth", 1800)).toBe("new");
    expect(await b.open("notifications:depth", 1800)).toBeNull();
    redis.now += 1_801_000;
    expect(await b.open("notifications:depth", 1800)).toBe("reminder");
    expect(await a.close("notifications:depth")).toBe(true);
    expect(await b.close("notifications:depth")).toBe(false);
    expect([...redis.values.keys()]).toEqual([]);
  });

  test("when Redis fails the monitor still alerts, from its own memory", async () => {
    const sender = new FakeSender();
    const collector = new LogCollector();
    const monitor = startQueueMonitor({
      sample: () =>
        Promise.resolve({
          queues: [],
          backlogs: [{
            name: "file scan",
            pending: 900,
            oldestSeconds: 0,
            deadLetters: 0,
          }],
        }),
      thresholds,
      cooldownSeconds: 1800,
      state: {
        open: () => Promise.reject(new Error("redis down")),
        close: () => Promise.reject(new Error("redis down")),
      },
      sender,
      logger: createJsonLogger("worker", "test", "debug", collector.sink),
      environment: "test",
      intervalMs: 3_600_000,
    });
    await monitor.runOnce();
    expect(sender.sent).toEqual([
      "ALERT Studafy test: file scan: 900 waiting (limit 100)",
    ]);
    expect(collector.events()).toContain("queue_alert_state_unavailable");
    await monitor.close();
  });
});

describe("the test alert", () => {
  test("says it is a test and that nothing is wrong", () => {
    expect(testAlertText("production", new Date("2026-10-12T09:00:00Z"))).toBe(
      "TEST Studafy production: queue alerts reach this chat (2026-10-12T09:00:00.000Z). Nothing is wrong.",
    );
  });
});

const redisUrl = process.env.REDIS_URL;
const redisTest = redisUrl ? test : test.skip;

describe("sampling a real BullMQ queue", () => {
  redisTest("counts waiting jobs and the age of the oldest", async () => {
    const prefix = `test-${crypto.randomUUID()}`;
    const queue = createQueue("notifications", redisUrl!, { prefix });
    const redis = createRedis(redisUrl!);
    try {
      await queue.add("a", {}, { timestamp: Date.now() - 400_000 } as never);
      await queue.add("b", {});
      const sample = await monitorSources({
        queues: [{ name: "notifications", queue }],
      })();
      expect(sample.queues[0]!.waiting).toBe(2);
      expect(sample.queues[0]!.oldestWaitingSeconds).toBeGreaterThan(390);
      expect(sample.backlogs).toEqual([]);
    } finally {
      await queue.obliterate({ force: true });
      await closeQueue(queue);
      redis.disconnect();
    }
  });
});
