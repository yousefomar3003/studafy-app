import { expect, test } from "bun:test";
import type { Sql } from "@studafy/database";
import { createJsonLogger } from "@studafy/observability";
import { LogCollector } from "@studafy/test-support";
import { startHousekeeping } from "../src/processors/housekeeping";

function fakeSql(batches: number[]) {
  const calls: number[] = [];
  const sql = ((_: TemplateStringsArray, limit: number) => {
    calls.push(limit);
    return Promise.resolve([{ removed: batches.shift() ?? 0 }]);
  }) as unknown as Sql;
  return { sql, calls };
}

test("a backlog drains in bounded batches until one comes back short", async () => {
  const { sql, calls } = fakeSql([0, 5_000, 5_000, 1_200]);
  const collector = new LogCollector();
  const logger = createJsonLogger("worker", "test", "debug", collector.sink);
  // The first (startup) pass finds nothing; the second is measured.
  const runtime = startHousekeeping(sql, logger, 60_000, 5_000);
  await Bun.sleep(0);
  expect(await runtime.runOnce()).toBe(11_200);
  expect(calls).toEqual([5_000, 5_000, 5_000, 5_000]);
  await runtime.close();
  // Counts only: never a key, an actor or a response.
  expect(JSON.stringify(collector.lines ?? collector)).not.toContain(
    "idempotency_key",
  );
});
