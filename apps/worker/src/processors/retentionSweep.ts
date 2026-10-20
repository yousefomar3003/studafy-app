import type { Sql } from "@studafy/database";
import type { Logger } from "@studafy/observability";
import type { EmailSender, PrivateFileStorage } from "@studafy/infrastructure";
import { sendInactiveWarningEmails } from "./inactiveWarningEmail";
import {
  type CountAlert,
  type CountAlertOptions,
  createCountAlert,
} from "../monitoring/countAlert";
import { errorFields } from "../platform/jobGuards";

/**
 * Warnings to someone with no school whose email failed for good
 * (`private.inactive_warning_email_undeliverable`): the account is kept
 * rather than deleted without a warning, and the operator is told.
 */
export const UNDELIVERABLE = "inactive_warnings_undeliverable";

/** The daily alert for {@link UNDELIVERABLE}. Counts only. */
export function undeliverableWarningsAlert(
  options: Omit<CountAlertOptions, "key" | "summary" | "resolved">,
): CountAlert {
  return createCountAlert({
    ...options,
    key: UNDELIVERABLE,
    summary: (count) =>
      `${count} inactive-account ${
        count === 1 ? "warning" : "warnings"
      } could not be emailed to people with no school. Those accounts are kept, not deleted, until someone acts: see docs/security/inactive-account-warnings-runbook.md`,
    resolved:
      "no inactive-account warning is waiting on an undeliverable email",
  });
}

interface RetentionJob {
  jobId: number;
  schoolId: string;
  rootFileId: string;
  memberFileIds: string[];
  bucket: string;
  objectKey: string;
}

export interface FileRetentionRuntime {
  close(): Promise<void>;
  runOnce(): Promise<number>;
}

/**
 * FILE-051 retention sweep worker. Deletion is group-atomic: the claim
 * hands over one physical object (the dedupe root) only after the database
 * verified every same-school member is past its horizon, unheld and
 * unreferenced; the rows move to `deleted` only after storage confirms the
 * physical deletion. A file's horizon is set by whatever ends its purpose:
 * account deletion, or the retention schedule below (DL-057, DL-060).
 */
export function startFileRetentionSweep(
  sql: Sql,
  storage: PrivateFileStorage,
  logger: Logger,
  intervalMs = 60_000,
): FileRetentionRuntime {
  const workerId = `file051-retention-${crypto.randomUUID()}`;
  let closed = false;
  let running: Promise<number> | null = null;

  const runOnce = async (): Promise<number> => {
    if (closed) return 0;
    const rows = await sql<{ jobs: RetentionJob[] }[]>`
      select private.api051_claim_retention(${workerId},5) as jobs
    `;
    const jobs = rows[0]?.jobs ?? [];
    for (const job of jobs) {
      try {
        await storage.delete(job.bucket, job.objectKey);
        await finish(job.jobId, true, null);
        logger.info("retention_group_deleted", {
          job_id: job.jobId,
          root_file_id: job.rootFileId,
          member_count: job.memberFileIds.length,
        });
      } catch {
        await finish(job.jobId, false, "STORAGE_UNAVAILABLE");
        logger.warn("retention_retry", { job_id: job.jobId });
      }
    }
    return jobs.length;
  };

  const finish = async (
    jobId: number,
    succeeded: boolean,
    errorCode: string | null,
  ): Promise<void> => {
    const rows = await sql<{ completed: boolean }[]>`
      select private.api051_finish_retention(
        ${workerId},${jobId},${succeeded},${errorCode}
      ) as completed
    `;
    if (rows[0]?.completed !== true) throw new Error("retention claim lost");
  };

  const timer = setInterval(() => {
    if (running) return;
    running = runOnce().catch((error) => {
      logger.error("retention_poll_failed", {
        ...errorFields(error),
      });
      return 0;
    }).finally(() => running = null);
  }, intervalMs);

  return {
    runOnce,
    async close() {
      closed = true;
      clearInterval(timer);
      await running;
    },
  };
}

export interface RetentionScheduleRuntime {
  close(): Promise<void>;
  /** One pass of every purge; returns the counts each one reported. */
  runOnce(): Promise<Record<string, Record<string, number>>>;
}

const RETENTION_STEPS = [
  // Security logs (2 years), consent and deletion records (the account's
  // life plus 6 years), billing (6 years after the tax year), legacy AI.
  {
    name: "records",
    query: (sql: Sql) =>
      sql<{ counts: Record<string, number> }[]>`
    select private.retention_purge_records(5000) as counts`,
  },
  // Classes closed 12 months ago (or the school's period), then the
  // conversations nobody shares a class for any more.
  {
    name: "classes",
    query: (sql: Sql) =>
      sql<{ counts: Record<string, number> }[]>`
    select private.retention_purge_classes(5) as counts`,
  },
  // Warn at 23 months without activity; request deletion at 24. Also
  // counts the warnings to people with no school whose email failed for
  // good: those accounts are kept, and the operator is alerted (below).
  {
    name: "inactive_accounts",
    query: (sql: Sql) =>
      sql<{ counts: Record<string, number> }[]>`
    select private.retention_inactive_accounts(100)
      || jsonb_build_object('inactive_warnings_undeliverable',
        private.inactive_warning_email_undeliverable()) as counts`,
  },
  // Study helper photos, 30 days after upload (DL-060). The model has read
  // them and the chat keeps its own copy on the device.
  {
    name: "helper_photos",
    query: (sql: Sql) =>
      sql<{ counts: Record<string, number> }[]>`
    select private.retention_expire_helper_photos(5000) as counts`,
  },
] as const;

/**
 * DL-057 retention schedule (privacy policy §10). Each step is one bounded
 * transaction in the database; a step that fails is logged and the others
 * still run. Files the purges leave unreferenced become due for the FILE-051
 * sweep above, which deletes their bytes. After the purges, the
 * inactive-account warnings are emailed (`email`, the worker's Resend
 * sender; without one, the waiting count is logged). Logs carry counts only.
 *
 * `undeliverableAlert` (the queue alerts' Telegram chat, when they are on)
 * is told the `inactive_warnings_undeliverable` count after each pass, and
 * alerts once a day while it is above zero
 * (docs/security/inactive-account-warnings-runbook.md).
 */
export function startRetentionSchedule(
  sql: Sql,
  logger: Logger,
  intervalMs = 60 * 60_000,
  options: { email?: EmailSender; undeliverableAlert?: CountAlert } = {},
): RetentionScheduleRuntime {
  let closed = false;
  let running: Promise<unknown> | null = null;

  const runOnce = async () => {
    const report: Record<string, Record<string, number>> = {};
    for (const step of RETENTION_STEPS) {
      if (closed) break;
      try {
        const rows = await step.query(sql);
        const counts = rows[0]?.counts ?? {};
        report[step.name] = counts;
        if (Object.values(counts).some((n) => n > 0)) {
          logger.info("retention_purged", { step: step.name, ...counts });
        }
      } catch (error) {
        logger.error("retention_step_failed", {
          step: step.name,
          ...errorFields(error),
        });
      }
    }
    if (!closed) {
      try {
        report.inactive_warning_emails = {
          ...await sendInactiveWarningEmails(sql, options.email, logger),
        };
      } catch (error) {
        logger.error("retention_step_failed", {
          step: "inactive_warning_emails",
          ...errorFields(error),
        });
      }
    }
    // Only a count the step actually returned: a failed step neither
    // raises nor resolves the alert.
    const undeliverable = report.inactive_accounts?.[UNDELIVERABLE];
    if (!closed && options.undeliverableAlert && undeliverable !== undefined) {
      try {
        await options.undeliverableAlert(Number(undeliverable));
      } catch (error) {
        logger.error("retention_alert_failed", {
          key: UNDELIVERABLE,
          ...errorFields(error),
        });
      }
    }
    return report;
  };

  const tick = () => {
    if (running || closed) return;
    running = runOnce().finally(() => running = null);
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
