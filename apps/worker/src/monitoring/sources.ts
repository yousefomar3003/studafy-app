import type { Sql } from "@studafy/database";
import {
  oldestActiveAgeMs,
  oldestWaitingAgeMs,
  type Queue,
  queueStats,
  type Worker,
} from "@studafy/infrastructure";
import type {
  BacklogSample,
  MonitorSnapshot,
  QueueSample,
} from "./queueMonitor";

export interface MonitoredQueue {
  name: string;
  queue: Queue;
  /** The local worker, whose stalled-job events are counted. */
  worker?: Worker;
}

/**
 * Samples what the queue monitor watches (launch plan 4.7): the BullMQ
 * queues this worker runs, and the Postgres backlogs read by the same
 * functions the per-minute backlog log lines use.
 */
export function monitorSources(options: {
  queues: MonitoredQueue[];
  outboxSql?: Sql;
  fileScanSql?: Sql;
}): () => Promise<Omit<MonitorSnapshot, "at">> {
  const stalled = new Map<string, number>();
  for (const { name, worker } of options.queues) {
    stalled.set(name, 0);
    worker?.on(
      "stalled",
      () => stalled.set(name, (stalled.get(name) ?? 0) + 1),
    );
  }

  return async () => {
    const queues: QueueSample[] = [];
    for (const { name, queue } of options.queues) {
      const [stats, waitingMs, activeMs] = await Promise.all([
        queueStats(queue),
        oldestWaitingAgeMs(queue),
        oldestActiveAgeMs(queue),
      ]);
      queues.push({
        name,
        waiting: stats.waiting,
        failed: stats.failed,
        oldestWaitingSeconds: waitingMs / 1000,
        oldestActiveSeconds: activeMs / 1000,
        stalledEvents: stalled.get(name) ?? 0,
      });
      stalled.set(name, 0);
    }

    const backlogs: BacklogSample[] = [];
    if (options.outboxSql) {
      const rows = await options.outboxSql<
        { backlog: Record<string, number> }[]
      >`select private.api061_outbox_backlog() as backlog`;
      const b = rows[0]?.backlog ?? {};
      backlogs.push({
        name: "notification outbox",
        pending: (b.pending ?? 0) + (b.retry ?? 0),
        oldestSeconds: b.oldestPendingSeconds ?? 0,
        deadLetters: b.deadLetter ?? 0,
      });
    }
    if (options.fileScanSql) {
      const rows = await options.fileScanSql<
        { backlog: Record<string, number> }[]
      >`select private.api051_scan_backlog() as backlog`;
      const b = rows[0]?.backlog ?? {};
      backlogs.push({
        name: "file scan",
        pending: b.quarantined ?? 0,
        oldestSeconds: b.oldestQuarantineSeconds ?? 0,
        deadLetters: (b.scanDeadLetters ?? 0) + (b.deleteDeadLetters ?? 0),
      });
    }
    return { queues, backlogs };
  };
}
