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

export interface OutboxDispatchPort {
  claim(workerId: string, limit: number): Promise<ClaimedOutboxRow[]>;
  recordDispatched(
    workerId: string,
    outboxId: number,
    jobId: string,
  ): Promise<boolean>;
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
      const rows = await sql<{ recorded: boolean }[]>`
        select private.api061_record_dispatched(
          ${workerId},${outboxId},${jobId}
        ) as recorded
      `;
      return rows[0]?.recorded === true;
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
