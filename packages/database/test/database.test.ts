import { describe, expect, test } from "bun:test";
import {
  checkDatabase,
  closeDatabase,
  createDatabase,
  databaseClientConfig,
  usesTransactionPooler,
} from "../src";

const databaseUrl = process.env.DATABASE_URL;
const databaseTest = databaseUrl ? test : test.skip;

describe("database connectivity smoke (read-only)", () => {
  databaseTest(
    "select 1 resolves and the pool closes cleanly",
    async () => {
      const sql = createDatabase(databaseUrl!);
      await checkDatabase(sql);
      await closeDatabase(sql);
    },
  );
});

describe("Supabase pooler modes", () => {
  test("only the transaction pooler turns prepared statements off", () => {
    const pooler = "postgresql://u:p@aws-1-eu-central-1.pooler.supabase.com";
    expect(usesTransactionPooler(`${pooler}:6543/postgres`)).toBe(true);
    expect(usesTransactionPooler(`${pooler}:5432/postgres`)).toBe(false);
    expect(usesTransactionPooler("postgresql://u:p@db.x.supabase.co/postgres"))
      .toBe(false);
    expect(usesTransactionPooler("not a url")).toBe(false);
  });

  test("the transaction pooler keeps pipelining, which sql.begin needs", async () => {
    // Creating a client opens no connection; only its options are read.
    const pooled = createDatabase(
      "postgresql://u:p@127.0.0.1:6543/postgres",
    );
    const session = createDatabase(
      "postgresql://u:p@127.0.0.1:5432/postgres",
    );
    // postgres.js parses max_pipeline but leaves it out of its types.
    const parsed = (sql: typeof pooled) =>
      sql.options as unknown as { prepare: boolean; max_pipeline: number };
    try {
      expect(parsed(pooled).prepare).toBe(false);
      // max_pipeline 0 makes every sql.begin fail (UNSAFE_TRANSACTION).
      expect(parsed(pooled).max_pipeline).toBe(100);
      // Session mode and direct connections keep postgres.js's defaults.
      expect(parsed(session).prepare).toBe(true);
      expect(parsed(session).max_pipeline).toBe(100);
    } finally {
      await closeDatabase(pooled);
      await closeDatabase(session);
    }
  });

  test("session mode moves a Supabase 6543 URL to 5432 and keeps postgres.js defaults", async () => {
    // Synthetic credentials. Creating a client opens no connection.
    const url =
      "postgresql://studafy_worker_runtime.synthetic:pw@aws-1-eu-central-1.pooler.supabase.com:6543/postgres";
    const config = databaseClientConfig(url, { poolerMode: "session" });
    expect(new URL(config.url).port).toBe("5432");
    expect(new URL(config.url).hostname).toBe(
      "aws-1-eu-central-1.pooler.supabase.com",
    );
    expect(usesTransactionPooler(config.url)).toBe(false);
    expect(config.target).toEqual({
      poolerMode: "session",
      port: 5432,
      rewritten: true,
      transactionPooler: false,
    });
    expect(config.options.prepare).toBeUndefined();
    // Still encrypted: the host is not this machine.
    expect(config.options.ssl).toBe("require");

    const sql = createDatabase(url, { poolerMode: "session" });
    const parsed = sql.options as unknown as {
      prepare: boolean;
      max_pipeline: number;
      port: number[];
      host: string[];
    };
    try {
      expect(parsed.port).toEqual([5432]);
      expect(parsed.host).toEqual(["aws-1-eu-central-1.pooler.supabase.com"]);
      expect(parsed.prepare).toBe(true);
      expect(parsed.max_pipeline).toBe(100);
    } finally {
      await closeDatabase(sql);
    }
  });

  test("transaction mode (the default) keeps 6543 and prepare: false", async () => {
    const url =
      "postgresql://role.synthetic:pw@aws-1-eu-central-1.pooler.supabase.com:6543/postgres";
    for (
      const config of [
        databaseClientConfig(url),
        databaseClientConfig(url, { poolerMode: "transaction" }),
      ]
    ) {
      expect(config.url).toBe(url);
      expect(config.options.prepare).toBe(false);
      expect(config.target.port).toBe(6543);
      expect(config.target.transactionPooler).toBe(true);
    }
  });

  test("session mode leaves direct and local URLs untouched", () => {
    for (
      const url of [
        "postgresql://postgres:pw@db.ref.supabase.co:5432/postgres",
        "postgresql://postgres:postgres@127.0.0.1:54322/postgres",
      ]
    ) {
      const config = databaseClientConfig(url, { poolerMode: "session" });
      expect(config.url).toBe(url);
      expect(config.target.rewritten).toBe(false);
      expect(config.options.prepare).toBeUndefined();
    }
  });

  test("session mode refuses a 6543 URL it cannot move", () => {
    expect(() =>
      databaseClientConfig(
        "postgresql://postgres:pw@db.ref.supabase.co:6543/postgres",
        { poolerMode: "session" },
      )
    ).toThrow(/session mode/);
  });
});
