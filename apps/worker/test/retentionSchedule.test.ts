import { expect, test } from "bun:test";
import type { Sql } from "@studafy/database";
import { createJsonLogger } from "@studafy/observability";
import { LogCollector } from "@studafy/test-support";
import { startRetentionSchedule } from "../src/processors/retentionSweep";

function fakeSql(results: Record<string, Record<string, number> | Error>) {
  const calls: string[] = [];
  const sql = ((strings: TemplateStringsArray) => {
    const text = strings.join("?");
    const step = Object.keys(results).find((name) => text.includes(name));
    if (!step) return Promise.reject(new Error(`unexpected query: ${text}`));
    calls.push(step);
    const result = results[step]!;
    return result instanceof Error
      ? Promise.reject(result)
      : Promise.resolve([{ counts: result }]);
  }) as unknown as Sql;
  return { sql, calls };
}

test("every purge runs each pass, and one failing does not stop the rest", async () => {
  const { sql, calls } = fakeSql({
    retention_purge_records: { audit_events: 12, consent_records: 0 },
    retention_purge_classes: new Error("lock timeout"),
    retention_inactive_accounts: { warned: 2, deletion_requested: 0 },
  });
  const collector = new LogCollector();
  const logger = createJsonLogger("worker", "test", "debug", collector.sink);
  const runtime = startRetentionSchedule(sql, logger, 3_600_000);
  // The startup pass; closing first would stop it between steps.
  await Bun.sleep(5);
  await runtime.close();

  expect(calls).toEqual([
    "retention_purge_records",
    "retention_purge_classes",
    "retention_inactive_accounts",
  ]);
  const logged = collector.parsed();
  expect(
    logged.filter((line) => line.event === "retention_purged")
      .map((line) => line.step),
  ).toEqual(["records", "inactive_accounts"]);
  expect(logged.find((line) => line.event === "retention_step_failed"))
    .toMatchObject({ step: "classes", error_name: "Error" });
  // Counts only: never the error text, an id or a person.
  expect(collector.lines.join("\n")).not.toContain("lock timeout");
});

test("a pass that removes nothing logs nothing", async () => {
  const { sql } = fakeSql({
    retention_purge_records: { audit_events: 0 },
    retention_purge_classes: { classes_purged: 0 },
    retention_inactive_accounts: { warned: 0 },
  });
  const collector = new LogCollector();
  const logger = createJsonLogger("worker", "test", "debug", collector.sink);
  const runtime = startRetentionSchedule(sql, logger, 3_600_000);
  // The startup pass; closing first would stop it between steps.
  await Bun.sleep(5);
  await runtime.close();
  expect(collector.events()).not.toContain("retention_purged");
});
