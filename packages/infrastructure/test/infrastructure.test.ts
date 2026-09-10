import { afterAll, describe, expect, test } from "bun:test";
import {
  checkRedis,
  closeRedis,
  createQueue,
  closeQueue,
  createRedis,
  createWorker,
  drainQueue,
} from "../src";

const redisUrl = process.env.REDIS_URL;
const redisTest = redisUrl ? test : test.skip;
const clients: { quit: () => Promise<unknown> }[] = [];

afterAll(async () => {
  await Promise.all(clients.map((client) => client.quit()));
});

describe("redis connectivity", () => {
  redisTest(
    "ping answers PONG and quit closes cleanly",
    async () => {
      const redis = createRedis(redisUrl!);
      await checkRedis(redis);
      await closeRedis(redis);
    },
  );
});

describe("bullmq queue lifecycle", () => {
  redisTest(
    "enqueue, process, then drain and close",
    async () => {
      const processed: string[] = [];
      const worker = createWorker(
        "boundary-smoke",
        async (job) => {
          processed.push(String(job.data.value));
          return { ok: true };
        },
        redisUrl!,
      );
      const queue = createQueue("boundary-smoke", redisUrl!);
      clients.push({ quit: () => closeQueue(queue) });
      clients.push({ quit: () => Promise.resolve(worker.close()) });

      await queue.waitUntilReady();
      await worker.waitUntilReady();
      await queue.add("smoke-job", { value: "payload-1" });

      let attempts = 0;
      while (processed.length === 0 && attempts < 50) {
        await new Promise((resolve) => setTimeout(resolve, 100));
        attempts += 1;
      }
      expect(processed).toEqual(["payload-1"]);

      await drainQueue(queue);
    },
  );
});
