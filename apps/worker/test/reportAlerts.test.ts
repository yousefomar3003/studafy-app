import { expect, test } from "bun:test";
import type { Sql } from "@studafy/database";
import { type AlertSender, AlertSendError } from "@studafy/infrastructure";
import { createJsonLogger } from "@studafy/observability";
import { LogCollector } from "@studafy/test-support";
import {
  type ReportAlertRow,
  reportAlertText,
  startReportAlerts,
} from "../src/processors/reportAlerts";

const row = (id: string, attempts = 1): ReportAlertRow => ({
  report_id: id,
  kind: "message",
  priority: "critical",
  school_hash: "0123456789abcdef",
  reported_at: new Date("2026-10-15T09:30:00Z"),
  attempts,
});

/** Answers the three SQL calls the processor makes, and records them. */
function fakeSql(claims: ReportAlertRow[][]) {
  const finished: { id: string; sent: boolean; error: string | null }[] = [];
  const sql = ((strings: TemplateStringsArray, ...values: unknown[]) => {
    const text = strings.join("?");
    if (text.includes("report_alerts_claim")) {
      return Promise.resolve(claims.shift() ?? []);
    }
    if (text.includes("report_alerts_finish")) {
      finished.push({
        id: String(values[0]),
        sent: text.includes("true"),
        error: text.includes("true") ? null : String(values[1]),
      });
      return Promise.resolve([{ report_alerts_finish: true }]);
    }
    if (text.includes("report_alerts_backlog")) {
      return Promise.resolve([{ backlog: { unsent: 1, oldestSeconds: 42 } }]);
    }
    return Promise.reject(new Error(`unexpected SQL: ${text}`));
  }) as unknown as Sql;
  return { sql, finished };
}

function sender(fail: (text: string) => boolean = () => false) {
  const sent: string[] = [];
  const value: AlertSender = {
    send(text: string) {
      if (fail(text)) {
        return Promise.reject(new AlertSendError("TELEGRAM_REFUSED_502"));
      }
      sent.push(text);
      return Promise.resolve();
    },
  };
  return { value, sent };
}

test("the message carries id, kind, priority and the school hash only", () => {
  const text = reportAlertText(row("r-1"), "production");
  expect(text).toContain("SAFETY REPORT Studafy production");
  expect(text).toContain("Report: r-1");
  expect(text).toContain("Kind: message, priority: critical");
  expect(text).toContain("School: #0123456789abcdef");
  expect(text).toContain("Filed: 2026-10-15 09:30 UTC");
  expect(text).not.toContain("attempt");
  expect(text).toContain("Review in the app: Account, Safety reports");
  expect(reportAlertText(row("r-1", 3), "production")).toContain(
    "(delivery attempt 3)",
  );
});

test("each claimed report is sent once and marked sent", async () => {
  const { sql, finished } = fakeSql([[], [row("r-1"), row("r-2")]]);
  const telegram = sender();
  const collector = new LogCollector();
  const runtime = startReportAlerts({
    sql,
    sender: telegram.value,
    logger: createJsonLogger("worker", "test", "debug", collector.sink),
    environment: "production",
    intervalMs: 60_000,
  });
  await Bun.sleep(0);
  expect(await runtime.runOnce()).toBe(2);
  await runtime.close();
  expect(telegram.sent).toHaveLength(2);
  expect(finished).toEqual([
    { id: "r-1", sent: true, error: null },
    { id: "r-2", sent: true, error: null },
  ]);
});

test("a failed send is recorded with its code and the backlog is logged", async () => {
  const { sql, finished } = fakeSql([[], [row("r-1"), row("r-2")]]);
  const telegram = sender((text) => text.includes("r-2"));
  const lines: string[] = [];
  const runtime = startReportAlerts({
    sql,
    sender: telegram.value,
    logger: createJsonLogger("worker", "test", "debug", (line) => {
      lines.push(line);
    }),
    environment: "production",
    intervalMs: 60_000,
  });
  await Bun.sleep(0);
  expect(await runtime.runOnce()).toBe(1);
  await runtime.close();
  expect(finished).toEqual([
    { id: "r-1", sent: true, error: null },
    { id: "r-2", sent: false, error: "TELEGRAM_REFUSED_502" },
  ]);
  const log = lines.join("\n");
  expect(log).toContain("report_alert_send_failed");
  expect(log).toContain("TELEGRAM_REFUSED_502");
  expect(log).toContain("report_alert_backlog");
});
