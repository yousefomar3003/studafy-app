import type { Sql } from "@studafy/database";
import { type AlertSender, AlertSendError } from "@studafy/infrastructure";
import type { Logger } from "@studafy/observability";
import { errorFields } from "../platform/jobGuards";

/**
 * DPIA D7: tells the reviewers' Telegram chat that a safety report was
 * filed (docs/security/safe043-operator-runbook.md, "Reviewing a report").
 *
 * Every new report gets a row in private.report_alerts (a trigger, so no
 * path can file a report silently). This polls them, sends one message per
 * report, and records the outcome. A failed send is retried with a backoff
 * for as long as it takes; the backlog is logged on every pass that finds
 * one, so a chat that stopped working shows in the logs.
 *
 * The message carries the report id, its kind and priority, and a hash of
 * the school id. Never the report's text, a name or an account id: the chat
 * is a third party, and the reviewer reads the report through the audited
 * review script under a moderation grant.
 */
export interface ReportAlertRow {
  report_id: string;
  kind: string;
  priority: string;
  school_hash: string;
  reported_at: Date | string;
  attempts: number;
}

export interface ReportAlertsRuntime {
  close(): Promise<void>;
  /** One pass; returns how many alerts were sent. */
  runOnce(): Promise<number>;
}

const iso = (value: Date | string): string =>
  (value instanceof Date ? value : new Date(value)).toISOString().slice(0, 16)
    .replace("T", " ") + " UTC";

/** The whole message. Only fields the claim function returns appear in it. */
export function reportAlertText(
  row: ReportAlertRow,
  environment: string,
): string {
  return [
    `SAFETY REPORT Studafy ${environment}: a new report needs review.`,
    `Report: ${row.report_id}`,
    `Kind: ${row.kind}, priority: ${row.priority}`,
    `School: #${row.school_hash}`,
    `Filed: ${iso(row.reported_at)}`,
    ...(row.attempts > 1 ? [`(delivery attempt ${row.attempts})`] : []),
    // The app is the normal path (DL-063); the script is the fallback.
    "Review in the app: Account, Safety reports (safe043 runbook).",
  ].join("\n");
}

export function startReportAlerts(options: {
  sql: Sql;
  sender: AlertSender;
  logger: Logger;
  environment: string;
  intervalMs?: number;
  batchSize?: number;
  leaseSeconds?: number;
}): ReportAlertsRuntime {
  const {
    sql,
    sender,
    logger,
    environment,
    intervalMs = 30_000,
    batchSize = 20,
    leaseSeconds = 120,
  } = options;
  let closed = false;
  let running: Promise<number> | null = null;

  const runOnce = async (): Promise<number> => {
    const rows = await sql<ReportAlertRow[]>`
      select report_id, kind, priority, school_hash, reported_at, attempts
      from private.report_alerts_claim(${batchSize}, ${leaseSeconds})
    `;
    let sent = 0;
    for (const row of rows) {
      if (closed) break;
      try {
        await sender.send(reportAlertText(row, environment));
        await sql`
          select private.report_alerts_finish(${row.report_id}::uuid, true, null)
        `;
        sent += 1;
        logger.info("report_alert_sent", {
          report_id: row.report_id,
          priority: row.priority,
          attempts: row.attempts,
        });
      } catch (error) {
        const code = error instanceof AlertSendError
          ? error.code
          : "SEND_FAILED";
        await sql`
          select private.report_alerts_finish(${row.report_id}::uuid, false, ${code})
        `.catch(() => undefined);
        logger.error("report_alert_send_failed", {
          report_id: row.report_id,
          attempts: row.attempts,
          error_code: code,
        });
      }
    }
    if (rows.length > 0 && sent < rows.length) {
      const [backlog] = await sql<{ backlog: Record<string, number> }[]>`
        select private.report_alerts_backlog() as backlog
      `;
      logger.warn("report_alert_backlog", {
        unsent: backlog?.backlog.unsent ?? null,
        oldest_seconds: backlog?.backlog.oldestSeconds ?? null,
      });
    }
    return sent;
  };

  const tick = () => {
    if (running || closed) return;
    running = runOnce().catch((error) => {
      logger.error("report_alert_poll_failed", {
        ...errorFields(error),
      });
      return 0;
    }).finally(() => running = null);
  };
  const timer = setInterval(tick, intervalMs);
  tick();

  return {
    runOnce,
    async close() {
      closed = true;
      clearInterval(timer);
      await running;
    },
  };
}
