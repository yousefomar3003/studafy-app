/**
 * PAY-071 billing-events drain, mirroring OPS-061's outbox dispatcher. Webhook
 * routes only durably record an event and ack the provider fast; this
 * dispatcher claims due `store_events` rows (FOR UPDATE SKIP LOCKED), enqueues
 * a BillingEventsJobV1 job onto the `billing-events` BullMQ queue with a
 * deterministic id (`billing-event-{eventId}`), and records the job id so a
 * crash between claim and enqueue self-heals on the next poll:
 *
 * - claim → crash → stale lease reclaimed on the next poll (attempt already
 *   counted, expansion idempotent);
 * - claim → enqueue fails → released to retry with capped backoff;
 * - row with a recorded id → reconciled against the live BullMQ state before
 *   anything is re-enqueued (completed → idempotent finish re-run,
 *   failed → dead_letter, queued/active → skip).
 *
 * The provider's raw payload never rides in a job body: the processor
 * re-fetches it through `private.billing_event_payload`, scoped to a
 * `processing` event.
 */
import type { Logger } from "@studafy/observability";
import type { Queue } from "@studafy/infrastructure";
import { normalizedErrorCode } from "../platform/jobGuards";
import {
  billingEventIdFromJobId,
  billingEventJobId,
  type BillingDispatchPort,
  type ClaimedBillingEvent,
} from "./billingDispatch";

export interface BillingDispatcherOptions {
  limit?: number;
}

export interface BillingDispatcherRuntime {
  runOnce(): Promise<number>;
  close(): Promise<void>;
}

export function createBillingDispatcher(
  dispatch: BillingDispatchPort,
  billingQueue: Queue,
  logger: Logger,
  options: BillingDispatcherOptions = {},
): BillingDispatcherRuntime {
  const workerId = `pay071-dispatch-${crypto.randomUUID()}`;
  const limit = options.limit ?? 50;

  /**
   * Enqueues one job payload from one store event. Jobs use a deterministic
   * id so a repeat enqueue after a lost record collapses onto the existing
   * job instead of double-applying.
   */
  async function ensureEnqueued(
    row: ClaimedBillingEvent,
    jobId: string,
  ): Promise<string> {
    const existing = await billingQueue.getJob(jobId);
    if (existing) {
      // A completed/failed job must never silently consume a re-drive:
      // remove the terminal BullMQ job so the deterministic id is free.
      if ((await existing.isCompleted()) || (await existing.isFailed())) {
        await existing.remove();
      } else {
        return jobId;
      }
    }
    const added = await billingQueue.add("billing-event", {
      platform: row.platform,
      environment: row.environment,
      // Opaque identifier only: the processor re-fetches the durable row by
      // the event id parsed out of the deterministic job id (§10).
      transactionId: String(row.eventId),
    }, { jobId });
    return added.id ?? jobId;
  }

  async function dispatchRow(row: ClaimedBillingEvent): Promise<void> {
    if (row.bullmqJobId) {
      await reconcileRecordedRow(row);
      return;
    }
    const jobId = billingEventJobId(row.eventId);
    try {
      const enqueuedId = await ensureEnqueued(row, jobId);
      const recorded = await dispatch.recordDispatched(
        workerId,
        row.eventId,
        enqueuedId,
      );
      if (!recorded) {
        // The lease was lost mid-dispatch: the idempotent expansion makes a
        // possible duplicate enqueue harmless; the next claim reconciles.
        logger.warn("billing_dispatch_record_lost", {
          event_id: row.eventId,
        });
      }
    } catch {
      await dispatch
        .releaseDispatch(workerId, row.eventId, "REDIS_UNAVAILABLE")
        .catch(() => undefined);
      logger.warn("billing_dispatch_released", { event_id: row.eventId });
    }
  }

  /** A row already carries a job id but was re-claimed (stale lease). */
  async function reconcileRecordedRow(row: ClaimedBillingEvent): Promise<void> {
    const jobId = row.bullmqJobId!;
    const job = await billingQueue.getJob(jobId);
    if (!job) {
      // The BullMQ job is gone (Redis loss or removal): re-enqueue from the
      // durable row; recordDispatched rewrites the id after the enqueue.
      try {
        await ensureEnqueued(row, jobId);
      } catch (error) {
        logger.warn("billing_reconcile_reenqueue_failed", {
          event_id: row.eventId,
          error_code: normalizedErrorCode(error),
        });
      }
      return;
    }
    if (await job.isFailed()) {
      const eventId = billingEventIdFromJobId(jobId) ?? row.eventId;
      await dispatch.failDispatch(
        eventId,
        normalizedErrorCode(
          job.failedReason ? new Error(job.failedReason) : undefined,
        ),
      );
      logger.warn("billing_job_dead_letter", { event_id: row.eventId });
      return;
    }
    if (await job.isCompleted()) {
      // The processor committed the ledger but the row was never finished
      // (or a redrive raced): billing_finish_event is idempotent and
      // re-running it converges the row to completed.
      try {
        await ensureEnqueued(row, jobId);
      } catch (error) {
        logger.warn("billing_reconcile_finish_failed", {
          event_id: row.eventId,
          error_code: normalizedErrorCode(error),
        });
      }
      return;
    }
    // Waiting/delayed/active: nothing to do; the claim refreshed the lease
    // and the job will drive the row to completion or dead_letter.
  }

  return {
    async runOnce() {
      const rows = await dispatch.claim(workerId, limit);
      for (const row of rows) {
        try {
          await dispatchRow(row);
        } catch (error) {
          logger.warn("billing_dispatch_failed", {
            event_id: row.eventId,
            error_code: normalizedErrorCode(error),
          });
        }
      }
      return rows.length;
    },
    close: async () => {
      // No held resources: each runOnce completes or releases its lease.
    },
  };
}