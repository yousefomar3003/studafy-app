import type { Sql } from "@studafy/database";
import { ChannelSendError, type EmailSender } from "@studafy/infrastructure";
import type { Logger } from "@studafy/observability";
import { channelCopy, serviceNoticeFooter } from "./notificationCopy";

export const INACTIVE_WARNING_TEMPLATE = "account.inactive_deletion_warning";

interface WarningEmailJob {
  userId: string;
  email: string | null;
  locale: string;
}

export interface WarningEmailCounts {
  sent: number;
  retry: number;
  failed: number;
  /** Warnings waiting for an email while no email provider is configured. */
  unconfigured: number;
}

/**
 * DL-057 / privacy policy §10: the inactive-account warning is a required
 * service notice, so it is emailed whatever the person's email preferences,
 * through the same sender as every other email (Resend). The database hands
 * out each warning once (`private.inactive_warning_email_claim`) and records
 * `emailed_at` when the provider accepts it, so a warning is never emailed
 * twice and deletion counts from when it reached the person.
 *
 * Without an email provider this logs how many warnings wait and changes
 * nothing: in-app and push warnings still go out, and nobody without a
 * school is deleted until their warning has been emailed. Logs carry counts
 * only, never an address or a person.
 */
export async function sendInactiveWarningEmails(
  sql: Sql,
  email: EmailSender | undefined,
  logger: Logger,
  batchSize = 20,
): Promise<WarningEmailCounts> {
  const counts: WarningEmailCounts = {
    sent: 0,
    retry: 0,
    failed: 0,
    unconfigured: 0,
  };
  if (!email) {
    const rows = await sql<{ pending: number }[]>`
      select private.inactive_warning_email_pending() as pending
    `;
    counts.unconfigured = Number(rows[0]?.pending ?? 0);
    if (counts.unconfigured > 0) {
      logger.warn("inactive_warning_email_unconfigured", {
        pending: counts.unconfigured,
      });
    }
    return counts;
  }

  const rows = await sql<{ jobs: WarningEmailJob[] }[]>`
    select private.inactive_warning_email_claim(${batchSize}) as jobs
  `;
  for (const job of rows[0]?.jobs ?? []) {
    const outcome = await sendOne(sql, email, job);
    counts[outcome] += 1;
  }
  if (counts.sent + counts.retry + counts.failed > 0) {
    logger.info("inactive_warning_emails", {
      sent: counts.sent,
      retry: counts.retry,
      failed: counts.failed,
    });
  }
  return counts;
}

async function sendOne(
  sql: Sql,
  email: EmailSender,
  job: WarningEmailJob,
): Promise<"sent" | "retry" | "failed"> {
  if (!job.email) {
    return await finish(sql, job, false, "NO_ADDRESS", true, null);
  }
  const copy = channelCopy(INACTIVE_WARNING_TEMPLATE, job.locale);
  try {
    const sent = await email.send({
      to: job.email,
      subject: copy.title,
      text: `${copy.body}\n\n${serviceNoticeFooter(job.locale)}`,
    });
    return await finish(sql, job, true, null, false, sent.providerMessageId);
  } catch (error) {
    const failure = error instanceof ChannelSendError
      ? error
      : new ChannelSendError("SENDER_ERROR", false);
    return await finish(
      sql,
      job,
      false,
      failure.code,
      failure.terminal,
      null,
    );
  }
}

async function finish(
  sql: Sql,
  job: WarningEmailJob,
  sent: boolean,
  errorCode: string | null,
  terminal: boolean,
  providerMessageId: string | null,
): Promise<"sent" | "retry" | "failed"> {
  const rows = await sql<{ outcome: string }[]>`
    select private.inactive_warning_email_finish(
      ${job.userId}::uuid, ${sent}, ${errorCode}, ${terminal}, ${providerMessageId}
    ) as outcome
  `;
  const outcome = rows[0]?.outcome;
  // `unchanged`: another worker already recorded it; count it as sent.
  if (outcome === "retry" || outcome === "failed") return outcome;
  return "sent";
}
