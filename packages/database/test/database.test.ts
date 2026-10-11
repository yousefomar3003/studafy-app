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
});
