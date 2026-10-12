import { afterAll, describe, expect, test } from "bun:test";
import { closeDatabase, createDatabase } from "@studafy/database";
import {
  FileSecurityScanner,
  type PrivateFileStorage,
} from "@studafy/infrastructure";
import { createJsonLogger } from "@studafy/observability";
import { integrationSuite, LogCollector } from "@studafy/test-support";
import { postgresScanQueue, startFileScan } from "../src/processors/fileScan";

// The scan worker's own path through Postgres (launch plan 7.1): its claim
// and backlog calls reach the real SQL functions, and its loop starts and
// stops cleanly. What a claim, a transform and a finish do is proven in
// supabase/tests/file051_scan_delivery.sql; the scanning decisions are
// fileScan.test.ts.

const databaseUrl = process.env["DATABASE_URL"];
const suite = integrationSuite(describe);

suite("file scan through Postgres", () => {
  const sql = createDatabase(databaseUrl ?? "postgresql://unused", { max: 2 });
  afterAll(() => closeDatabase(sql));

  test("a claim with nothing due returns no jobs and changes nothing", async () => {
    const queue = postgresScanQueue(sql);
    // Park every due scan job for this test, then put them back.
    const parked = await sql<{ id: number }[]>`
      update public.file_job_outbox set available_at = now() + interval '1 hour'
      where job_type = 'scan' and state in ('pending', 'retry') and available_at <= now()
      returning id`;
    try {
      expect(await queue.claim("file-scan-integration", 5)).toEqual([]);
    } finally {
      const ids = parked.map((row) => row.id);
      if (ids.length > 0) {
        await sql`update public.file_job_outbox set available_at = now() where id = any(${ids})`;
      }
    }
  });

  test("the backlog reads as counts", async () => {
    const backlog = await postgresScanQueue(sql).backlog();
    for (
      const key of [
        "quarantined",
        "oldestQuarantineSeconds",
        "scanDeadLetters",
        "deleteDeadLetters",
      ]
    ) {
      expect(typeof backlog[key]).toBe("number");
    }
  });

  test("the loop polls and closes without leaving work half done", async () => {
    const collector = new LogCollector();
    const runtime = startFileScan(
      sql,
      {
        openObject: () => Promise.reject(new Error("unused")),
      } as unknown as PrivateFileStorage,
      new FileSecurityScanner(),
      createJsonLogger("worker", "test", "debug", collector.sink),
      20,
    );
    await Bun.sleep(80);
    await runtime.close();
    expect(await runtime.runOnce()).toBe(0);
    expect(collector.events()).not.toContain("file_scan_poll_failed");
  });
});
