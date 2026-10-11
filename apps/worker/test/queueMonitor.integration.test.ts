import { afterAll, describe, expect, test } from "bun:test";
import { closeDatabase, createDatabase } from "@studafy/database";
import { monitorSources } from "../src/monitoring/sources";

// The Postgres backlogs the queue monitor reads (launch plan 4.7), through
// the same functions the per-minute backlog log lines use.
const databaseUrl = process.env["DATABASE_URL"];
const suite = databaseUrl ? describe : describe.skip;

suite("queue monitor: Postgres backlogs", () => {
  const sql = createDatabase(databaseUrl ?? "postgresql://unused", { max: 1 });
  afterAll(() => closeDatabase(sql));

  test("the outbox and file-scan backlogs read as numbers", async () => {
    const sample = await monitorSources({
      queues: [],
      outboxSql: sql,
      fileScanSql: sql,
    })();
    expect(sample.backlogs.map((b) => b.name)).toEqual([
      "notification outbox",
      "file scan",
    ]);
    for (const backlog of sample.backlogs) {
      expect(backlog.pending).toBeGreaterThanOrEqual(0);
      expect(backlog.oldestSeconds).toBeGreaterThanOrEqual(0);
      expect(backlog.deadLetters).toBeGreaterThanOrEqual(0);
    }
  });
});
