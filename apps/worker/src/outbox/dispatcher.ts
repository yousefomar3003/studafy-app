import type { Logger } from "@studafy/observability";
import type { Queue } from "@studafy/infrastructure";
import {
  normalizedErrorCode,
  outboxIdFromJobId,
  outboxJobId,
} from "../platform/jobGuards";
import type { ClaimedOutboxRow, OutboxDispatchPort } from "./outboxDispatch";

export interface OutboxDispatcherOptions {
  limit?: number;
  backlogLogIntervalMs?: number;
}

export interface OutboxDispatcherRuntime {
  runOnce(): Promise<number>;
  close(): Promise<void>;
}

/**
 * Dispatches one BullMQ job payload from one outbox row. Jobs use a
 * deterministic id (`outbox-{id}`) so a repeat enqueue after a lost record
 * collapses onto the existing job (BullMQ returns the existing job for a
 * known id) instead of double-applying.
 */
async function ensureEnqueued(
  queue: Queue,
  row: ClaimedOutboxRow,
  jobId: string,
  payload: Record<string, unknown>,
): Promise<string> {
  const existing = await queue.getJob(jobId);
  if (existing) {
    // A completed/failed job must never silently consume a re-drive: remove
    // the terminal BullMQ job so the deterministic id is free again.
    if ((await existing.isCompleted()) || (await existing.isFailed())) {
      await existing.remove();
    } else {
      return jobId;
    }
  }
  const added = await queue.add(row.templateKey, payload, { jobId });
  return added.id ?? jobId;
}

/**
 * The transactional-outbox drain (§10.651). Claims rows with
 * FOR UPDATE SKIP LOCKED, enqueues them onto the BullMQ queue with a
 * deterministic job id, records the id, and retries safely:
 *
 * - claim → crash → stale lease reclaim on the next poll (attempt already
 *   counted, expansion idempotent);
 * - claim → enqueue fails → released to retry with capped backoff;
 * - row with a recorded id → reconciled against the live BullMQ state
 *   before anything is re-enqueued (completed → finish reconcile,
 *   failed → dead_letter, queued → skip).
 */
export function createOutboxDispatcher(
  dispatch: OutboxDispatchPort,
  notificationsQueue: Queue,
  logger: Logger,
  options: OutboxDispatcherOptions = {},
): OutboxDispatcherRuntime {
  const workerId = `ops061-dispatch-${crypto.randomUUID()}`;
  const limit = options.limit ?? 50;
  const backlogLogIntervalMs = options.backlogLogIntervalMs ?? 60_000;
  let lastBacklogAt = 0;

  const reportBacklog = async (): Promise<void> => {
    if (Date.now() - lastBacklogAt < backlogLogIntervalMs) return;
    lastBacklogAt = Date.now();
    try {
      const backlog = await dispatch.backlog();
      logger.info("outbox_backlog", {
        pending: backlog.pending ?? 0,
        retry: backlog.retry ?? 0,
        processing: backlog.processing ?? 0,
        dead_letter: backlog.deadLetter ?? 0,
        oldest_pending_seconds: backlog.oldestPendingSeconds ?? 0,
      });
    } catch {
      // Backlog telemetry must never break dispatch.
    }
  };

  const dispatchRow = async (row: ClaimedOutboxRow): Promise<void> => {
    if (row.channel !== "in_app") {
      await dispatch.failDispatch(row.outboxId, "UNSUPPORTED_CHANNEL");
      logger.warn("outbox_row_unsupported_channel", {
        outbox_id: row.outboxId,
        channel: row.channel,
      });
      return;
    }
    if (row.bullmqJobId) {
      await reconcileRecordedRow(dispatch, notificationsQueue, row, logger);
      return;
    }
    const payload = {
      outboxId: row.outboxId,
      schoolId: row.schoolId,
      templateKey: row.templateKey,
      channel: row.channel,
      audience: row.audience ?? null,
      payload: row.payload ?? {},
    };
    const jobId = outboxJobId(row.outboxId);
    try {
      const enqueuedId = await ensureEnqueued(
        notificationsQueue,
        row,
        jobId,
        payload,
      );
      const recorded = await dispatch.recordDispatched(
        workerId,
        row.outboxId,
        enqueuedId,
      );
      if (!recorded) {
        // The lease was lost mid-dispatch: the idempotent expansion makes
        // a possible duplicate enqueue harmless; the next claim reconciles.
        logger.warn("outbox_dispatch_record_lost", {
          outbox_id: row.outboxId,
        });
      }
    } catch {
      await dispatch.releaseDispatch(
        workerId,
        row.outboxId,
        "REDIS_UNAVAILABLE",
      );
      logger.warn("outbox_dispatch_released", { outbox_id: row.outboxId });
    }
  };

  return {
    async runOnce() {
      await reportBacklog();
      const rows = await dispatch.claim(workerId, limit);
      for (const row of rows) {
        try {
          await dispatchRow(row);
        } catch (error) {
          logger.warn("outbox_dispatch_failed", {
            outbox_id: row.outboxId,
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

/**
 * A row already carries a BullMQ job id but was re-claimed (stale lease).
 * Decide from the live job state whether anything must happen.
 */
async function reconcileRecordedRow(
  dispatch: OutboxDispatchPort,
  queue: Queue,
  row: ClaimedOutboxRow,
  logger: Logger,
): Promise<void> {
  const jobId = row.bullmqJobId!;
  const job = await queue.getJob(jobId);
  if (!job) {
    // The BullMQ job is gone (Redis loss or removal): re-enqueue from the
    // durable row. Clearing the recorded id is implicit — recordDispatched
    // rewrites it after the fresh enqueue below.
    const payload = {
      outboxId: row.outboxId,
      schoolId: row.schoolId,
      templateKey: row.templateKey,
      channel: row.channel,
      audience: row.audience ?? null,
      payload: row.payload ?? {},
    };
    try {
      await ensureEnqueued(queue, row, jobId, payload);
    } catch (error) {
      logger.warn("outbox_reconcile_reenqueue_failed", {
        outbox_id: row.outboxId,
        error_code: normalizedErrorCode(error),
      });
    }
    return;
  }
  if (await job.isFailed()) {
    const outboxId = outboxIdFromJobId(jobId) ?? row.outboxId;
    await dispatch.failDispatch(
      outboxId,
      normalizedErrorCode(
        job.failedReason ? new Error(job.failedReason) : undefined,
      ),
    );
    logger.warn("outbox_job_dead_letter", { outbox_id: row.outboxId });
    return;
  }
  if (await job.isCompleted()) {
    // The processor committed but the row was never finished (or a redrive
    // raced): finish is idempotent.
    const outcome = await dispatch.finishNotification(row.outboxId);
    logger.info("outbox_reconcile_finished", {
      outbox_id: row.outboxId,
      outcome,
    });
    return;
  }
  // Waiting/delayed/active: nothing to do; the lease was refreshed by the
  // claim and the job will drive the row to completion or dead_letter.
}
