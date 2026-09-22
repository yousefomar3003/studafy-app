import type { Sql } from "@studafy/database";
import type { Logger } from "@studafy/observability";
import {
  type ConferenceProvider,
  ConferenceProviderError,
} from "@studafy/infrastructure";

interface MeetingJob {
  meetingId: string;
  action: "schedule" | "cancel";
  title: string;
  startsAt: string;
  endsAt: string;
  calendarEventId: string | null;
  attendees: string[];
}

export interface MeetingProcessorRuntime {
  close(): Promise<void>;
  /** Claims and processes due meetings once; returns jobs handled. */
  runOnce(): Promise<number>;
}

/**
 * DL-052 meeting processor. `private.meeting_claim` leases due work;
 * scheduling creates the provider event and link, then
 * `private.meeting_finish_schedule` marks the meeting scheduled and
 * notifies recipients. Provider failures go to `private.meeting_fail`,
 * which retries with backoff and fails the meeting on a refusal or the
 * fifth attempt. Logs never contain titles or attendee emails.
 */
export function startMeetingProcessor(
  sql: Sql,
  provider: ConferenceProvider,
  logger: Logger,
  intervalMs = 15_000,
): MeetingProcessorRuntime {
  let closed = false;
  let running: Promise<number> | null = null;

  const fail = async (job: MeetingJob, error: unknown) => {
    const failure = error instanceof ConferenceProviderError
      ? error
      : new ConferenceProviderError("PROCESSOR_ERROR", false);
    const rows = await sql<{ outcome: string }[]>`
      select private.meeting_fail(
        ${job.meetingId}::uuid, ${failure.code}, ${failure.terminal}
      ) as outcome
    `;
    logger.warn("meeting_job_failed", {
      meeting_id: job.meetingId,
      action: job.action,
      error_code: failure.code,
      outcome: rows[0]?.outcome ?? "lost",
    });
  };

  const processBatch = async (): Promise<number> => {
    if (closed) return 0;
    const rows = await sql<{ jobs: MeetingJob[] }[]>`
      select private.meeting_claim(5) as jobs
    `;
    const jobs = rows[0]?.jobs ?? [];
    for (const job of jobs) {
      try {
        if (job.action === "schedule") {
          const conference = await provider.schedule({
            meetingId: job.meetingId,
            title: job.title,
            startsAt: job.startsAt,
            endsAt: job.endsAt,
            attendees: job.attendees,
          });
          const done = await sql<{ outcome: string }[]>`
            select private.meeting_finish_schedule(
              ${job.meetingId}::uuid, ${conference.eventId},
              ${conference.joinUrl}
            ) as outcome
          `;
          logger.info("meeting_scheduled", {
            meeting_id: job.meetingId,
            outcome: done[0]?.outcome ?? "lost",
            attendee_count: job.attendees.length,
          });
        } else if (job.calendarEventId) {
          await provider.cancel(job.calendarEventId);
          await sql`select private.meeting_finish_cancel(${job.meetingId}::uuid)`;
          logger.info("meeting_event_withdrawn", { meeting_id: job.meetingId });
        }
      } catch (error) {
        await fail(job, error);
      }
    }
    return jobs.length;
  };

  // Startup polling and explicit drains must share the same in-flight batch.
  // Otherwise runOnce can resolve while the startup poll still owns leased jobs.
  const runOnce = (): Promise<number> => {
    if (closed) return Promise.resolve(0);
    running ??= processBatch().finally(() => running = null);
    return running;
  };
  const tick = () => {
    void runOnce().catch((error) => {
      logger.error("meeting_poll_failed", {
        error_name: error instanceof Error ? error.name : "unknown",
      });
    });
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
