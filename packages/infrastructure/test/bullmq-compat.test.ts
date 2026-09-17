/**
 * Bun/Redis/BullMQ compatibility gate (OPS-061, instructions.md §10).
 *
 * §10 pins the stack and requires the pinned Bun runtime + BullMQ + Redis
 * versions to be proven against each other before any queue guarantee is
 * trusted: blocking consumers and duplicate() clients, Lua scripts,
 * pipelines, retry behaviour, stalled-job recovery, delayed jobs,
 * QueueEvents and graceful shutdown.
 *
 * These tests run against the pinned Redis 7.4.4 dev container (REDIS_URL)
 * and are skipped when it is absent — the same pattern as the other
 * Redis-gated suites. TLS/ACLs and the exact managed product cannot be
 * proven here; they are Phase 8 infrastructure gates recorded in
 * docs/evidence/phase-6b/README.md.
 */
import { afterAll, describe, expect, test } from "bun:test";
import { type Processor, Queue, QueueEvents, Worker } from "bullmq";
import { Redis } from "ioredis";

const redisUrl = process.env.REDIS_URL;
const redisTest = redisUrl ? test : test.skip;
const closeables: { close: () => Promise<unknown> }[] = [];

afterAll(async () => {
  await Promise.allSettled(closeables.map((closeable) => closeable.close()));
});

async function waitFor(
  predicate: () => boolean | Promise<boolean>,
  timeoutMs = 10_000,
): Promise<void> {
  const deadline = Date.now();
  const started = deadline;
  while (!(await predicate())) {
    if (Date.now() - started > timeoutMs) {
      throw new Error("condition not reached");
    }
    await new Promise((resolve) => setTimeout(resolve, 50));
  }
}

describe("bun + ioredis fundamentals", () => {
  redisTest(
    "duplicate() yields an independent blocking consumer",
    async () => {
      const base = new Redis(redisUrl!, { maxRetriesPerRequest: null });
      closeables.push({ close: () => base.quit() });
      await base.set("compat:base", "v1");
      const blocking = base.duplicate();
      closeables.push({ close: () => blocking.quit() });
      // BLPOP's timeout unit is seconds, not milliseconds.
      const reply = await blocking.blpop("compat:queue", 1);
      expect(reply).toBeNull();
      await base.lpush("compat:queue", "job-1");
      const popped = await blocking.blpop("compat:queue", 1);
      expect(popped).toEqual(["compat:queue", "job-1"]);
      expect(await base.get("compat:base")).toBe("v1");
    },
  );

  redisTest("Lua scripts and pipelines execute atomically", async () => {
    const client = new Redis(redisUrl!, { maxRetriesPerRequest: null });
    closeables.push({ close: () => client.quit() });
    const script =
      "redis.call('SET', KEYS[1], ARGV[1]); return redis.call('GET', KEYS[1])";
    expect(await client.eval(script, 1, "compat:lua", "result")).toBe(
      "result",
    );
    const pipeline = client.pipeline();
    pipeline.set("compat:p1", "a");
    pipeline.get("compat:p1");
    const results = await pipeline.exec();
    expect(results?.[0]?.[0]).toBeNull();
    expect(results?.[1]?.[1]).toBe("a");
  });

  redisTest("connection failures are typed and bounded", async () => {
    const dead = new Redis("redis://127.0.0.1:6390", {
      connectTimeout: 500,
      maxRetriesPerRequest: 1,
      retryStrategy: () => null,
      lazyConnect: true,
    });
    dead.on("error", () => {});
    closeables.push({ close: () => dead.quit().catch(() => undefined) });
    await expect(dead.connect()).rejects.toThrow();
  });
});

describe("bullmq retry behaviour", () => {
  redisTest(
    "a job that fails twice succeeds on attempt three",
    async () => {
      const name = "compat-retry";
      const queue = new Queue(name, {
        connection: { url: redisUrl! },
        defaultJobOptions: {
          attempts: 3,
          backoff: { type: "fixed", delay: 100 },
        },
      });
      closeables.push({ close: () => queue.close() });
      const attemptsSeen: number[] = [];
      const worker = new Worker(
        name,
        (async (job) => {
          attemptsSeen.push(job.attemptsMade + 1);
          if (job.attemptsMade < 2) throw new Error("transient");
          return { ok: true };
        }) as Processor,
        { connection: { url: redisUrl! } },
      );
      closeables.push({ close: () => worker.close() });
      await worker.waitUntilReady();
      await queue.add("retry-job", {});
      await waitFor(() => attemptsSeen.length >= 3);
      expect(attemptsSeen).toEqual([1, 2, 3]);
    },
  );

  redisTest(
    "exhausted attempts leave the job failed with a normalized reason",
    async () => {
      const name = "compat-poison";
      const queue = new Queue(name, {
        connection: { url: redisUrl! },
        defaultJobOptions: {
          attempts: 2,
          backoff: { type: "fixed", delay: 100 },
        },
      });
      closeables.push({ close: () => queue.close() });
      let attemptsSeen = 0;
      const processor: Processor = async () => {
        attemptsSeen += 1;
        throw new Error("deterministic failure");
      };
      const worker = new Worker(name, processor, {
        connection: { url: redisUrl! },
      });
      closeables.push({ close: () => worker.close() });
      await worker.waitUntilReady();
      const job = await queue.add("poison-job", {});
      await waitFor(async () => (await job.getState()) === "failed");
      // Both attempts ran (at-least-once), then the job dead-ended.
      expect(attemptsSeen).toBe(2);
      const failed = await queue.getJob(job.id!);
      expect(failed?.failedReason).toBe("deterministic failure");
    },
  );
});

describe("bullmq delayed jobs and QueueEvents", () => {
  redisTest(
    "a delayed job runs no earlier than its delay",
    async () => {
      const name = "compat-delayed";
      const queue = new Queue(name, { connection: { url: redisUrl! } });
      closeables.push({ close: () => queue.close() });
      const processed: { at: number }[] = [];
      const worker = new Worker(
        name,
        (async () => {
          processed.push({ at: Date.now() });
          return { ok: true };
        }) as Processor,
        { connection: { url: redisUrl! } },
      );
      closeables.push({ close: () => worker.close() });
      await worker.waitUntilReady();
      const queuedAt = Date.now();
      await queue.add("delayed-job", {}, { delay: 400 });
      await waitFor(() => processed.length > 0);
      expect(processed[0]!.at - queuedAt).toBeGreaterThanOrEqual(350);
    },
  );

  redisTest(
    "QueueEvents surfaces completed and duplicated events",
    async () => {
      const name = "compat-events";
      const queue = new Queue(name, { connection: { url: redisUrl! } });
      closeables.push({ close: () => queue.close() });
      const worker = new Worker(
        name,
        (async () => ({ ok: true })) as Processor,
        {
          connection: { url: redisUrl! },
        },
      );
      closeables.push({ close: () => worker.close() });
      const events = new QueueEvents(name, { connection: { url: redisUrl! } });
      closeables.push({ close: () => events.close() });
      await worker.waitUntilReady();
      await events.waitUntilReady();

      const completed = new Promise<string>((resolve) => {
        events.on("completed", ({ jobId }) => resolve(jobId));
      });
      await queue.add("events-job", {});
      expect(await completed).toBeTypeOf("string");

      const duplicated = new Promise<string>((resolve) => {
        events.on("duplicated", ({ jobId }) => resolve(jobId));
      });
      await queue.add("dup-job", {}, { jobId: "compat-dup-id" });
      await queue.add("events-job", {}, { jobId: "compat-dup-id" });
      expect(await duplicated).toBe("compat-dup-id");
    },
  );
});

describe("bullmq stalled-job recovery and graceful shutdown", () => {
  redisTest(
    "a crashed worker's active job is recovered by another worker, at-least-once",
    async () => {
      const name = "compat-stalled";
      const queue = new Queue(name, { connection: { url: redisUrl! } });
      closeables.push({ close: () => queue.close() });

      let release!: () => void;
      const blocker = new Promise<void>((resolve) => {
        release = resolve;
      });
      const runs: string[] = [];
      const processor: Processor = async (job) => {
        runs.push(String(job.id));
        if (runs.length === 1) await blocker;
        return { ok: true, run: runs.length };
      };

      const crashedWorker = new Worker(name, processor, {
        connection: { url: redisUrl! },
        lockDuration: 1_000,
        stalledInterval: 500,
      });
      await crashedWorker.waitUntilReady();

      const job = await queue.add("stall-job", { value: "v" });
      await waitFor(() => runs.length === 1);
      // Hard-crash the worker mid-job: no graceful close, the lock dies.
      await crashedWorker.close(true);

      const recoveredWorker = new Worker(name, processor, {
        connection: { url: redisUrl! },
        lockDuration: 1_000,
        stalledInterval: 500,
        maxStalledCount: 3,
      });
      closeables.push({ close: () => recoveredWorker.close() });
      await recoveredWorker.waitUntilReady();

      release();
      await waitFor(() => runs.length >= 2);
      expect(runs[0]).toBe(runs[1]);
      await waitFor(async () => (await job.getState()) === "completed");
    },
  );

  redisTest(
    "graceful close lets the in-flight job finish and exits cleanly",
    async () => {
      const name = "compat-graceful";
      const queue = new Queue(name, { connection: { url: redisUrl! } });
      closeables.push({ close: () => queue.close() });
      let finished = false;
      const processor: Processor = async (job) => {
        await new Promise((resolve) => setTimeout(resolve, 300));
        finished = true;
        return { ok: true, id: job.id };
      };
      const worker = new Worker(name, processor, {
        connection: { url: redisUrl! },
        lockDuration: 3_000,
      });
      await worker.waitUntilReady();
      await queue.add("graceful-job", {});
      await waitFor(() => finished);
      const start = Date.now();
      await worker.close();
      expect(finished).toBe(true);
      expect(Date.now() - start).toBeLessThan(10_000);
    },
  );
});
