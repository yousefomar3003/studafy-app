import { afterAll, describe, expect, test } from "bun:test";
import {
  assertQueueRedisPosture,
  closeRedis,
  createRedis,
  isPersisted,
  type PostureClient,
  QueuePostureError,
  queuePostureProblems,
  type QueueRedisPosture,
  readQueueRedisPosture,
} from "../src";

const redisUrl = process.env.REDIS_URL;
const redisTest = redisUrl ? test : test.skip;

describe("queue redis posture (pure)", () => {
  const posture: QueueRedisPosture = {
    source: "config",
    maxmemoryPolicy: "noeviction",
    appendonly: "no",
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
      queuePostureProblems({ ...posture, save: "" }, "production"),
    ).toHaveLength(1);
    // CONFIG reports yes/no; INFO reports 1/0. Both mean AOF is on.
    for (const appendonly of ["yes", "1"]) {
      expect(
        queuePostureProblems(
          { ...posture, appendonly, save: "" },
          "production",
        ),
      ).toEqual([]);
    }
  });

  test("non-production environments are never rejected (warn only)", () => {
    for (const environment of ["development", "staging", "synthetic"]) {
      expect(
        queuePostureProblems(
          { ...posture, maxmemoryPolicy: "allkeys-lru", save: "" },
          environment,
        ),
      ).toEqual([]);
    }
  });

  test("from INFO, persistence needs AOF or a successful snapshot", () => {
    const info: QueueRedisPosture = {
      source: "info",
      maxmemoryPolicy: "noeviction",
      appendonly: "0",
      save: "",
    };
    expect(isPersisted({ ...info, appendonly: "1" })).toBe(true);
    expect(isPersisted({ ...info, rdbSaves: 3, rdbLastBgsaveStatus: "ok" }))
      .toBe(true);
    expect(isPersisted({ ...info, rdbSaves: 0, rdbLastBgsaveStatus: "ok" }))
      .toBe(false);
    expect(isPersisted({ ...info, rdbSaves: 2, rdbLastBgsaveStatus: "err" }))
      .toBe(false);
    expect(queuePostureProblems(info, "production")).toEqual([
      expect.stringContaining("aof_enabled:1"),
    ]);
  });
});

/** A Redis that answers (or refuses) CONFIG and INFO as told. */
function fakeRedis(options: {
  config?: Record<string, string> | Error;
  info?: Record<string, string> | Error;
}): PostureClient & { calls: string[] } {
  const calls: string[] = [];
  return {
    calls,
    call(command: string, ...args: string[]): Promise<unknown> {
      calls.push([command, ...args].join(" "));
      if (command === "CONFIG") {
        if (options.config instanceof Error) {
          return Promise.reject(options.config);
        }
        const key = args[1]!;
        const value = options.config?.[key];
        return Promise.resolve(value === undefined ? [] : [key, value]);
      }
      if (command === "INFO") {
        if (options.info instanceof Error) return Promise.reject(options.info);
        const section = args[0];
        const lines = Object.entries(options.info ?? {}).map(([k, v]) =>
          `${k}:${v}`
        );
        return Promise.resolve(`# ${section}\r\n${lines.join("\r\n")}\r\n`);
      }
      return Promise.reject(new Error(`unexpected ${command}`));
    },
  };
}

const refused = (message: string) =>
  Object.assign(new Error(message), { name: "ReplyError" });

describe("queue redis posture (fake client)", () => {
  test("CONFIG answers: reads from CONFIG and never asks INFO", async () => {
    const client = fakeRedis({
      config: {
        "maxmemory-policy": "noeviction",
        appendonly: "yes",
        save: "",
      },
      info: refused("ERR should not be called"),
    });
    const posture = await assertQueueRedisPosture(client, "production");
    expect(posture).toEqual({
      source: "config",
      maxmemoryPolicy: "noeviction",
      appendonly: "yes",
      save: "",
    });
    expect(client.calls.every((call) => call.startsWith("CONFIG"))).toBe(true);
  });

  test("CONFIG refused, INFO answers: falls back and says so", async () => {
    // Redis Cloud's answer for a setting outside its CONFIG GET list.
    const client = fakeRedis({
      config: refused("ERR unsupported CONFIG parameter: maxmemory-policy"),
      info: {
        maxmemory_policy: "noeviction",
        aof_enabled: "1",
        rdb_saves: "0",
        rdb_last_bgsave_status: "ok",
      },
    });
    const posture = await assertQueueRedisPosture(client, "production");
    expect(posture.source).toBe("info");
    expect(posture.maxmemoryPolicy).toBe("noeviction");
    expect(posture.appendonly).toBe("1");
    expect(posture.configRefused).toContain("unsupported CONFIG parameter");
    expect(client.calls).toContain("INFO memory");
    expect(client.calls).toContain("INFO persistence");
  });

  test("CONFIG silent (empty reply), INFO answers: falls back", async () => {
    const client = fakeRedis({
      config: {},
      info: {
        maxmemory_policy: "noeviction",
        aof_enabled: "0",
        rdb_saves: "4",
        rdb_last_bgsave_status: "ok",
      },
    });
    const posture = await assertQueueRedisPosture(client, "production");
    expect(posture.source).toBe("info");
    expect(posture.rdbSaves).toBe(4);
  });

  test("INFO fallback still fails closed on an evicting policy", async () => {
    const client = fakeRedis({
      config: refused("NOPERM this user has no permissions to run 'config'"),
      info: { maxmemory_policy: "volatile-lru", aof_enabled: "1" },
    });
    const error = await assertQueueRedisPosture(client, "production").catch(
      (caught: unknown) => caught,
    );
    expect(error).toBeInstanceOf(QueuePostureError);
    expect((error as QueuePostureError).problems[0]).toContain(
      "volatile-lru, from info",
    );
  });

  test("INFO fallback fails closed without persistence evidence", async () => {
    const client = fakeRedis({
      config: refused("ERR unknown command 'CONFIG'"),
      info: { maxmemory_policy: "noeviction", aof_enabled: "0" },
    });
    await expect(assertQueueRedisPosture(client, "production")).rejects
      .toBeInstanceOf(QueuePostureError);
    // Outside production the same posture is only reported.
    await expect(assertQueueRedisPosture(client, "development")).resolves
      .toMatchObject({ source: "info", appendonly: "0" });
  });

  test("both refused: fails closed in every environment", async () => {
    const client = fakeRedis({
      config: refused("ERR unknown command 'CONFIG'"),
      info: refused("NOPERM this user has no permissions to run 'info'"),
    });
    for (const environment of ["production", "development"]) {
      const error = await assertQueueRedisPosture(client, environment).catch(
        (caught: unknown) => caught,
      );
      expect(error).toBeInstanceOf(QueuePostureError);
      expect((error as QueuePostureError).problems).toEqual([
        "CONFIG GET refused (ERR unknown command 'CONFIG')",
        "INFO refused (NOPERM this user has no permissions to run 'info')",
      ]);
    }
  });

  test("INFO without maxmemory_policy counts as not answering", async () => {
    const client = fakeRedis({
      config: refused("ERR unknown command 'CONFIG'"),
      info: { aof_enabled: "1" },
    });
    await expect(readQueueRedisPosture(client)).rejects.toBeInstanceOf(
      QueuePostureError,
    );
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
      expect(original.source).toBe("config");
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

  redisTest("a real server's INFO parses to the same policy", async () => {
    client ??= createRedis(redisUrl!, { maxRetriesPerRequest: 5 });
    const refusing: PostureClient = {
      call: (command: string, ...args: string[]) =>
        command === "CONFIG"
          ? Promise.reject(new Error("ERR unknown command 'CONFIG'"))
          : client!.call(command, ...args),
    };
    const viaInfo = await readQueueRedisPosture(refusing);
    const viaConfig = await readQueueRedisPosture(client);
    expect(viaInfo.source).toBe("info");
    expect(viaInfo.maxmemoryPolicy).toBe(viaConfig.maxmemoryPolicy);
    expect(["0", "1"]).toContain(viaInfo.appendonly);
    expect(typeof viaInfo.rdbSaves).toBe("number");
  });
});
