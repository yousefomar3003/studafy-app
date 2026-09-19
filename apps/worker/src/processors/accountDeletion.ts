import type { Sql } from "@studafy/database";
import type { Logger } from "@studafy/observability";

export interface AccountDeletionRuntime {
  close(): Promise<void>;
  /** Claims and executes due requests once; returns how many completed. */
  runOnce(): Promise<number>;
}

/**
 * DL-051 account deletion executor. The request rows are the durable queue:
 * `private.account_deletion_claim` moves due, unheld requests to
 * `executing`, and `private.account_deletion_execute` de-identifies the
 * account in one transaction. A crash between the two leaves the request in
 * `executing`, which the claim re-selects after fifteen minutes. Logs carry
 * request ids and outcomes only, never a name or email.
 */
export function startAccountDeletionExecutor(
  sql: Sql,
  logger: Logger,
  intervalMs = 60_000,
): AccountDeletionRuntime {
  let closed = false;
  let running: Promise<number> | null = null;

  const runOnce = async (): Promise<number> => {
    if (closed) return 0;
    const rows = await sql<{ ids: string[] }[]>`
      select private.account_deletion_claim(5) as ids
    `;
    let completed = 0;
    for (const id of rows[0]?.ids ?? []) {
      try {
        const result = await sql<{ outcome: string }[]>`
          select private.account_deletion_execute(${id}::uuid) as outcome
        `;
        const outcome = result[0]?.outcome ?? "lost";
        if (outcome === "completed") completed++;
        logger.info("account_deletion_executed", {
          request_id: id,
          outcome,
        });
      } catch (error) {
        // The transaction rolled back; the claim retries after its lease.
        logger.error("account_deletion_failed", {
          request_id: id,
          error_name: error instanceof Error ? error.name : "unknown",
        });
      }
    }
    return completed;
  };

  const tick = () => {
    if (running) return;
    running = runOnce().catch((error) => {
      logger.error("account_deletion_poll_failed", {
        error_name: error instanceof Error ? error.name : "unknown",
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
