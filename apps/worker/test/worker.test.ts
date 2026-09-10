import { describe, expect, test } from "bun:test";
import { buildSmokeRuntime } from "../src/bootstrap/queues";
import { createJsonLogger } from "@studafy/observability";
import { LogCollector } from "@studafy/test-support";

const redisUrl = process.env.REDIS_URL;
const workerTest = redisUrl ? test : test.skip;

describe("worker smoke queue lifecycle", () => {
  workerTest(
    "enqueued smoke jobs are processed and logged, then close cleanly",
    async () => {
      const collector = new LogCollector();
      const logger = createJsonLogger("worker", "test", "debug", collector.sink);
      const runtime = buildSmokeRuntime(redisUrl!, logger, {
        environment: "development",
        concurrency: 1,
      });

      await runtime.worker.waitUntilReady();
      await runtime.queue.add("smoke-job", { value: "payload" });

      let attempts = 0;
      while (
        !collector.events().includes("job_processed") &&
        attempts < 50
      ) {
        await new Promise((resolve) => setTimeout(resolve, 100));
        attempts += 1;
      }

      expect(collector.events()).toContain("job_processed");
      const processed = collector.parsed().find(
        (entry) => entry.event === "job_processed",
      );
      expect(processed?.queue).toBe("smoke");

      await runtime.close();
    },
  );
});
