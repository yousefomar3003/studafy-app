import { describe, test } from "bun:test";
import { checkDatabase, closeDatabase, createDatabase } from "../src";

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
