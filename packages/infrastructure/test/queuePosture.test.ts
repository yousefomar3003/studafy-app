import { afterAll, describe, expect, test } from "bun:test";
import {
  assertQueueRedisPosture,
  closeRedis,
  createRedis,
  QueuePostureError,
  queuePostureProblems,
  type QueueRedisPosture,
  readQueueRedisPosture,
} from "../src";

const redisUrl = process.env.REDIS_URL;
const redisTest = redisUrl ? test : test.skip;

describe("queue redis posture (pure)", () => {
  const posture: QueueRedisPosture = {
    maxmemoryPolicy: "noeviction",
    appendonly: "0",
    save: "3600 1 300 100",
  };

  test("production accepts noeviction with persistence", () => {
    expect(queuePostureProblems(posture, "production")).toEqual([]);
  });

  test("production rejects evicting policies", () => {
    expect(
      queuePostureProblems(
        { ...posture, maxmemoryPolicy: "allkeys-lfu" },
        "production",
      ),
    ).toHaveLength(1);
  });

  test("production rejects both missing AOF and RDB persistence", () => {
    expect(
      queuePostureProblems(
        { maxmemoryPolicy: "noeviction", appendonly: "0", save: "" },
        "production",
      ),
    ).toHaveLength(1);
    expect(
      queuePostureProblems(
        { maxmemoryPolicy: "noeviction", appendonly: "1", save: "" },
        "production",
      ),
    ).toEqual([]);
  });

  test("non-production environments are never rejected (warn only)", () => {
    for (const environment of ["development", "staging", "synthetic"]) {
      expect(
        queuePostureProblems(
          { maxmemoryPolicy: "allkeys-lru", appendonly: "0", save: "" },
          environment,
        ),
      ).toEqual([]);
    }
  });
});

describe("queue redis posture (redis)", () => {
  let client: ReturnType<typeof createRedis> | undefined;

  afterAll(async () => {
    if (client) await closeRedis(client);
  });

  redisTest(
    "reads the live policy and fails closed when it evicts",
    async () => {
      client = createRedis(redisUrl!, { maxRetriesPerRequest: 5 });
      const original = await readQueueRedisPosture(client);
      expect(original.maxmemoryPolicy.length).toBeGreaterThan(0);

      // Production-environment checks: the guard throws on an evicting
      // policy and passes under noeviction. The live server is flipped with
      // CONFIG SET so this works against the default CI/dev instance.
      await client.config("SET", "maxmemory-policy", "allkeys-lru");
      try {
        await expect(
          assertQueueRedisPosture(client, "production"),
        ).rejects.toBeInstanceOf(QueuePostureError);
      } finally {
        await client.config("SET", "maxmemory-policy", "noeviction");
      }
      const restored = await readQueueRedisPosture(client);
      expect(restored.maxmemoryPolicy).toBe("noeviction");
      await expect(
        assertQueueRedisPosture(client, "production"),
      ).resolves.toMatchObject({ maxmemoryPolicy: "noeviction" });
    },
  );
});
