import type { Sql } from "@studafy/database";
import type { Logger } from "@studafy/observability";

export interface DataExportRuntime {
  close(): Promise<void>;
  /** Builds pending exports and sweeps expired ones; returns builds. */
  runOnce(): Promise<number>;
}

/**
 * DL-051 data export executor. `private.data_export_build` locks each
 * request with SKIP LOCKED, so concurrent workers never build one export
 * twice, and it is a no-op for anything no longer pending. Each pass also
 * deletes the payloads of expired exports. Logs carry ids and outcomes,
 * never the document.
 */
export function startDataExportExecutor(
  sql: Sql,
  logger: Logger,
  intervalMs = 60_000,
): DataExportRuntime {
  let closed = false;
  let running: Promise<number> | null = null;

  const runOnce = async (): Promise<number> => {
    if (closed) return 0;
    const rows = await sql<{ ids: string[] }[]>`
      select private.data_export_claim(5) as ids
    `;
    let built = 0;
    for (const id of rows[0]?.ids ?? []) {
      try {
        const result = await sql<{ outcome: string }[]>`
          select private.data_export_build(${id}::uuid) as outcome
        `;
        const outcome = result[0]?.outcome ?? "lost";
        if (outcome === "ready") built++;
        logger.info("data_export_built", { request_id: id, outcome });
      } catch (error) {
        logger.error("data_export_failed", {
          request_id: id,
          error_name: error instanceof Error ? error.name : "unknown",
        });
      }
    }
    const swept = await sql<{ n: number }[]>`
      select private.data_export_expire() as n
    `;
    if ((swept[0]?.n ?? 0) > 0) {
      logger.info("data_export_expired", { count: swept[0]!.n });
    }
    return built;
  };

  const tick = () => {
    if (running) return;
    running = runOnce().catch((error) => {
      logger.error("data_export_poll_failed", {
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
