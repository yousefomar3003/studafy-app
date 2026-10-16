import type { Sql } from "@studafy/database";

/**
 * The database half of the notification outbox drain — SECURITY DEFINER
 * functions only. The worker role holds no table grants; every state
 * transition happens inside `private.api061_*` functions which re-validate
 * the transition they were called for.
 */
export interface ClaimedOutboxRow {
  outboxId: number;
  schoolId: string;
  channel: string;
  templateKey: string;
  audience: unknown;
  payload: unknown;
  bullmqJobId: string | null;
  attempt: number;
}

export type NotificationFinishOutcome = "completed" | "terminal" | "lost";

/**
 * Why recording a dispatched job id did or did not happen
 * (`private.api061_record_dispatched_v2`, and its billing twin):
 *
 * - `recorded`: the id is recorded and the lease extended;
 * - `already_finished`: the row already left `processing`, nearly always
 *   because the job ran and finished it before the dispatcher got here;
 * - `lease_lost`: the row is `processing` under another dispatcher's lease,
 *   or is gone.
 */
export type DispatchRecordOutcome =
  | "recorded"
  | "already_finished"
  | "lease_lost";

const RECORD_OUTCOMES: readonly string[] = [
  "recorded",
  "already_finished",
  "lease_lost",
];

/** An unknown or missing answer is treated as the one that warns. */
export function dispatchRecordOutcome(value: unknown): DispatchRecordOutcome {
  return typeof value === "string" && RECORD_OUTCOMES.includes(value)
    ? value as DispatchRecordOutcome
    : "lease_lost";
}

export interface OutboxDispatchPort {
  claim(workerId: string, limit: number): Promise<ClaimedOutboxRow[]>;
  recordDispatched(
    workerId: string,
    outboxId: number,
    jobId: string,
  ): Promise<DispatchRecordOutcome>;
  releaseDispatch(
    workerId: string,
    outboxId: number,
    errorCode: string,
  ): Promise<boolean>;
  failDispatch(outboxId: number, errorCode: string): Promise<boolean>;
  reclaimDispatch(outboxId: number): Promise<boolean>;
  finishNotification(outboxId: number): Promise<NotificationFinishOutcome>;
  backlog(): Promise<Record<string, number>>;
}

export function postgresOutboxDispatch(sql: Sql): OutboxDispatchPort {
  return {
    async claim(workerId, limit) {
      const rows = await sql<{ jobs: ClaimedOutboxRow[] }[]>`
        select private.api061_claim_outbox_dispatch(${workerId},${limit}) as jobs
      `;
      return rows[0]?.jobs ?? [];
    },
    async recordDispatched(workerId, outboxId, jobId) {
      const rows = await sql<{ outcome: string }[]>`
        select private.api061_record_dispatched_v2(
          ${workerId},${outboxId},${jobId}
        ) as outcome
      `;
      return dispatchRecordOutcome(rows[0]?.outcome);
    },
    async releaseDispatch(workerId, outboxId, errorCode) {
      const rows = await sql<{ released: boolean }[]>`
        select private.api061_release_dispatch(
          ${workerId},${outboxId},${errorCode}
        ) as released
      `;
      return rows[0]?.released === true;
    },
    async failDispatch(outboxId, errorCode) {
      const rows = await sql<{ failed: boolean }[]>`
        select private.api061_fail_dispatch(${outboxId},${errorCode}) as failed
      `;
      return rows[0]?.failed === true;
    },
    async reclaimDispatch(outboxId) {
      const rows = await sql<{ reclaimed: boolean }[]>`
        select private.api061_reclaim_dispatch(${outboxId}) as reclaimed
      `;
      return rows[0]?.reclaimed === true;
    },
    async finishNotification(outboxId) {
      const rows = await sql<{ outcome: NotificationFinishOutcome }[]>`
        select private.api061_finish_notification(${outboxId}) as outcome
      `;
      return rows[0]?.outcome ?? "lost";
    },
    async backlog() {
      const rows = await sql<{ backlog: Record<string, number> }[]>`
        select private.api061_outbox_backlog() as backlog
      `;
      return rows[0]?.backlog ?? {};
    },
  };
}
