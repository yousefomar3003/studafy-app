import { describe, expect, test } from "bun:test";
import type { Sql } from "@studafy/database";
import { createJsonLogger } from "@studafy/observability";
import { LogCollector } from "@studafy/test-support";
import { createCountAlert } from "../src/monitoring/countAlert";
import { memoryAlertState } from "../src/monitoring/queueMonitor";
import {
  startRetentionSchedule,
  UNDELIVERABLE,
  undeliverableWarningsAlert,
} from "../src/processors/retentionSweep";

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
      : Promise.resolve([{ counts: result, pending: 0 }]);
  }) as unknown as Sql;
  return { sql, calls };
}

test("every purge runs each pass, and one failing does not stop the rest", async () => {
  const { sql, calls } = fakeSql({
    retention_purge_records: { audit_events: 12, consent_records: 0 },
    retention_purge_classes: new Error("lock timeout"),
    retention_inactive_accounts: { warned: 2, deletion_requested: 0 },
    retention_expire_helper_photos: { helper_photos: 0 },
    inactive_warning_email_pending: {},
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
    "retention_expire_helper_photos",
    // No email provider here: the warning emails only count what waits.
    "inactive_warning_email_pending",
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

test("the inactive-accounts step reports undeliverable warnings and the alert hears the count", async () => {
  const { sql } = fakeSql({
    retention_purge_records: { audit_events: 0 },
    retention_purge_classes: { classes_purged: 0 },
    retention_inactive_accounts: {
      warned: 0,
      deletion_requested: 0,
      inactive_warnings_undeliverable: 2,
    },
    retention_expire_helper_photos: { helper_photos: 0 },
    inactive_warning_email_pending: {},
  });
  const counts: number[] = [];
  const collector = new LogCollector();
  const logger = createJsonLogger("worker", "test", "debug", collector.sink);
  const runtime = startRetentionSchedule(sql, logger, 3_600_000, {
    undeliverableAlert: (count) => {
      counts.push(count);
      return Promise.resolve("new");
    },
  });
  await Bun.sleep(5);
  await runtime.close();

  expect(counts).toEqual([2]);
  expect(
    collector.parsed().find((line) => line.event === "retention_purged"),
  ).toMatchObject({ step: "inactive_accounts", [UNDELIVERABLE]: 2 });
});

test("a failed inactive-accounts step neither raises nor resolves the alert", async () => {
  const { sql } = fakeSql({
    retention_purge_records: { audit_events: 0 },
    retention_purge_classes: { classes_purged: 0 },
    retention_inactive_accounts: new Error("lock timeout"),
    retention_expire_helper_photos: { helper_photos: 0 },
    inactive_warning_email_pending: {},
  });
  const counts: number[] = [];
  const collector = new LogCollector();
  const logger = createJsonLogger("worker", "test", "debug", collector.sink);
  const runtime = startRetentionSchedule(sql, logger, 3_600_000, {
    undeliverableAlert: (count) => {
      counts.push(count);
      return Promise.resolve(null);
    },
  });
  await Bun.sleep(5);
  await runtime.close();
  expect(counts).toEqual([]);
});

describe("the undeliverable-warnings alert", () => {
  function harness(failSend = false) {
    let clock = 0;
    const sent: string[] = [];
    const collector = new LogCollector();
    const alert = undeliverableWarningsAlert({
      state: memoryAlertState(() => clock),
      sender: {
        send: (text) => {
          if (failSend) return Promise.reject(new Error("TELEGRAM_HTTP_502"));
          sent.push(text);
          return Promise.resolve();
        },
      },
      logger: createJsonLogger("worker", "test", "debug", collector.sink),
      environment: "production",
      now: () => clock,
    });
    return {
      alert,
      sent,
      collector,
      advance: (ms: number) => clock += ms,
    };
  }

  test("one alert per day while the count is above zero, then resolved", async () => {
    const h = harness();
    expect(await h.alert(0)).toBeNull();
    expect(await h.alert(3)).toBe("new");
    // The retention pass runs hourly: no repeat within the day.
    for (let hour = 1; hour < 24; hour += 1) {
      h.advance(3_600_000);
      expect(await h.alert(3)).toBeNull();
    }
    h.advance(3_600_000);
    expect(await h.alert(1)).toBe("reminder");
    expect(await h.alert(0)).toBe("resolved");
    expect(await h.alert(0)).toBeNull();

    expect(h.sent).toEqual([
      "ALERT Studafy production: 3 inactive-account warnings could not be emailed to people with no school. Those accounts are kept, not deleted, until someone acts: see docs/security/inactive-account-warnings-runbook.md",
      "STILL HAPPENING Studafy production: 1 inactive-account warning could not be emailed to people with no school. Those accounts are kept, not deleted, until someone acts: see docs/security/inactive-account-warnings-runbook.md",
      "RESOLVED Studafy production: no inactive-account warning is waiting on an undeliverable email",
    ]);
    expect(h.collector.parsed().filter((l) => l.event === "queue_alert_sent"))
      .toHaveLength(3);
  });

  test("a failed send is logged and never throws", async () => {
    const h = harness(true);
    expect(await h.alert(1)).toBe("new");
    expect(
      h.collector.parsed().find((l) => l.event === "queue_alert_send_failed"),
    ).toMatchObject({ key: UNDELIVERABLE, kind: "new" });
  });

  test("a shared state that fails falls back to the worker's own memory", async () => {
    const collector = new LogCollector();
    const sent: string[] = [];
    const alert = createCountAlert({
      key: "k",
      summary: (n) => `${n} waiting`,
      resolved: "clear",
      state: {
        open: () => Promise.reject(new Error("redis down")),
        close: () => Promise.reject(new Error("redis down")),
      },
      sender: {
        send: (text) => {
          sent.push(text);
          return Promise.resolve();
        },
      },
      logger: createJsonLogger("worker", "test", "debug", collector.sink),
      environment: "development",
    });
    expect(await alert(4)).toBe("new");
    expect(sent).toEqual(["ALERT Studafy development: 4 waiting"]);
    expect(collector.events()).toContain("queue_alert_state_unavailable");
  });
});

test("a pass that removes nothing logs nothing", async () => {
  const { sql } = fakeSql({
    retention_purge_records: { audit_events: 0 },
    retention_purge_classes: { classes_purged: 0 },
    retention_inactive_accounts: { warned: 0 },
    retention_expire_helper_photos: { helper_photos: 0 },
    inactive_warning_email_pending: {},
  });
  const collector = new LogCollector();
  const logger = createJsonLogger("worker", "test", "debug", collector.sink);
  const runtime = startRetentionSchedule(sql, logger, 3_600_000);
  // The startup pass; closing first would stop it between steps.
  await Bun.sleep(5);
  await runtime.close();
  expect(collector.events()).not.toContain("retention_purged");
});
