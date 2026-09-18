import type { Sql } from "@studafy/database";
import type { Logger } from "@studafy/observability";
import type { PrivateFileStorage } from "@studafy/infrastructure";

interface RetentionJob {
  jobId: number;
  schoolId: string;
  rootFileId: string;
  memberFileIds: string[];
  bucket: string;
  objectKey: string;
}

export interface FileRetentionRuntime {
  close(): Promise<void>;
  runOnce(): Promise<number>;
}

/**
 * FILE-051 retention sweep worker. Deletion is group-atomic: the claim
 * hands over one physical object (the dedupe root) only after the database
 * verified every same-school member is past its horizon, unheld and
 * unreferenced; the rows move to `deleted` only after storage confirms the
 * physical deletion. Retention durations themselves stay unset until the
 * human retention decision (§29) — this loop proves the mechanism.
 */
export function startFileRetentionSweep(
  sql: Sql,
  storage: PrivateFileStorage,
  logger: Logger,
  intervalMs = 60_000,
): FileRetentionRuntime {
  const workerId = `file051-retention-${crypto.randomUUID()}`;
  let closed = false;
  let running: Promise<number> | null = null;

  const runOnce = async (): Promise<number> => {
    if (closed) return 0;
    const rows = await sql<{ jobs: RetentionJob[] }[]>`
      select private.api051_claim_retention(${workerId},5) as jobs
    `;
    const jobs = rows[0]?.jobs ?? [];
    for (const job of jobs) {
      try {
        await storage.delete(job.bucket, job.objectKey);
        await finish(job.jobId, true, null);
        logger.info("retention_group_deleted", {
          job_id: job.jobId,
          root_file_id: job.rootFileId,
          member_count: job.memberFileIds.length,
        });
      } catch {
        await finish(job.jobId, false, "STORAGE_UNAVAILABLE");
        logger.warn("retention_retry", { job_id: job.jobId });
      }
    }
    return jobs.length;
  };

  const finish = async (
    jobId: number,
    succeeded: boolean,
    errorCode: string | null,
  ): Promise<void> => {
    const rows = await sql<{ completed: boolean }[]>`
      select private.api051_finish_retention(
        ${workerId},${jobId},${succeeded},${errorCode}
      ) as completed
    `;
    if (rows[0]?.completed !== true) throw new Error("retention claim lost");
  };

  const timer = setInterval(() => {
    if (running) return;
    running = runOnce().catch((error) => {
      logger.error("retention_poll_failed", {
        error_name: error instanceof Error ? error.name : "unknown",
      });
      return 0;
    }).finally(() => running = null);
  }, intervalMs);

  return {
    runOnce,
    async close() {
      closed = true;
      clearInterval(timer);
      await running;
    },
  };
}
