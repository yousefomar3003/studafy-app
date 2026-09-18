import { NotificationsJobV1 } from "@studafy/contracts";
import type { Logger } from "@studafy/observability";
import { type Processor, UnrecoverableError } from "bullmq";
import { isFinalAttempt, normalizedErrorCode } from "../platform/jobGuards";
import type { OutboxDispatchPort } from "../outbox/outboxDispatch";

/**
 * OPS-061 notifications processor (§10 queue table: expand audience, create
 * in-app delivery). Runs at-least-once; idempotency is the database
 * invariant, not this function:
 *
 * - `completed` — the expansion transaction committed (one delivery per
 *   recipient, on-conflict-do-nothing), the outbox row is completed;
 * - `terminal` — the database already dead-lettered the row (unsupported
 *   channel/audience); return without throwing so BullMQ does not spin
 *   retries on a poison payload — the DLQ state lives in Postgres;
 * - `lost` — the claim disappeared (concurrent run, stale lease): retry.
 *
 * A repeat run of the same job inserts nothing (deliveries unique on
 * outbox/recipient/channel/attempt), so crash, failover and duplicate
 * delivery all converge to exactly one side effect.
 */
export function createNotificationProcessor(
  dispatch: OutboxDispatchPort,
  logger: Logger,
): Processor {
  return async (job) => {
    const parsed = NotificationsJobV1.safeParse(job.data);
    if (!parsed.success) {
      logger.warn("notification_job_invalid_payload", {
        queue: "notifications",
        job_id: job.id,
        attempts_made: job.attemptsMade,
      });
      throw new UnrecoverableError(
        "notification job payload does not match the v1 contract",
      );
    }
    const { outboxId } = parsed.data;
    try {
      const outcome = await dispatch.finishNotification(outboxId);
      if (outcome === "completed") {
        logger.info("notification_job_completed", {
          queue: "notifications",
          job_id: job.id,
          outbox_id: outboxId,
          attempt: job.attemptsMade + 1,
        });
        return { ok: true };
      }
      if (outcome === "terminal") {
        logger.warn("notification_job_terminal", {
          queue: "notifications",
          job_id: job.id,
          outbox_id: outboxId,
        });
        return { ok: true, deadLetter: true };
      }
      // "lost": the processing lease no longer matches. A BullMQ retry
      // re-runs the idempotent finish; after the final attempt the row is
      // dead-lettered below instead of being left processing forever.
      throw new Error("notification claim lost");
    } catch (error) {
      if (isFinalAttempt(job)) {
        await dispatch
          .failDispatch(outboxId, normalizedErrorCode(error))
          .catch(() => undefined);
        logger.error("notification_job_exhausted", {
          queue: "notifications",
          job_id: job.id,
          outbox_id: outboxId,
          error_code: normalizedErrorCode(error),
        });
        throw new UnrecoverableError(normalizedErrorCode(error));
      }
      logger.warn("notification_job_retry", {
        queue: "notifications",
        job_id: job.id,
        outbox_id: outboxId,
        attempt: job.attemptsMade + 1,
        error_code: normalizedErrorCode(error),
      });
      throw error;
    }
  };
}
