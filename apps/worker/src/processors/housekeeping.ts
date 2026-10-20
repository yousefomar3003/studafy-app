import type { Sql } from "@studafy/database";
import type { Logger } from "@studafy/observability";
import { errorFields } from "../platform/jobGuards";

export interface HousekeepingRuntime {
  close(): Promise<void>;
  /** One pass; returns the rows removed. */
  runOnce(): Promise<number>;
}

/**
 * Removes rows that already count as gone, so tables that grow with every
 * request stay the size of their live data (docs/operations/capacity.md).
 * Today that is expired idempotency records. Each pass removes a bounded
 * batch, repeating while batches come back full, so a backlog drains
 * without one long transaction.
 */
export function startHousekeeping(
  sql: Sql,
  logger: Logger,
  intervalMs = 5 * 60_000,
  batchSize = 5_000,
): HousekeepingRuntime {
  let closed = false;
  let running: Promise<number> | null = null;

  const runOnce = async (): Promise<number> => {
    let total = 0;
    for (let batch = 0; batch < 20 && !closed; batch++) {
      const rows = await sql<{ removed: number }[]>`
        select private.prune_expired_idempotency(${batchSize}) as removed
      `;
      const removed = rows[0]?.removed ?? 0;
      total += removed;
      if (removed < batchSize) break;
    }
    if (total > 0) {
      logger.info("housekeeping_pruned", {
        table: "idempotency_records",
        rows: total,
      });
    }
    return total;
  };

  const tick = () => {
    if (running || closed) return;
    running = runOnce().catch((error) => {
      logger.error("housekeeping_failed", {
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
