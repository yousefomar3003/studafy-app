import { describe, expect, test } from "bun:test";
import {
  checkDatabase,
  closeDatabase,
  createDatabase,
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

  test("the transaction pooler gets one statement per connection at a time", async () => {
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
      expect(parsed(pooled).max_pipeline).toBe(0);
      // Session mode and direct connections keep postgres.js's defaults.
      expect(parsed(session).prepare).toBe(true);
      expect(parsed(session).max_pipeline).toBe(100);
    } finally {
      await closeDatabase(pooled);
      await closeDatabase(session);
    }
  });
});
