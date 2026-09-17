import type { Sql } from "@studafy/database";
import type { Logger } from "@studafy/observability";
import type { PrivateFileStorage } from "@studafy/infrastructure";

interface CleanupJob {
  jobId: number;
  uploadId: string;
  fileId: string | null;
  bucket: string;
  objectKey: string;
}

export interface FileCleanupRuntime {
  close(): Promise<void>;
  runOnce(): Promise<number>;
}

/**
 * Narrow FILE-050 outbox poller. It accepts no object location from Redis or
 * a caller: each exact bucket/key comes from the SECURITY DEFINER claim.
 */
export function startFileCleanup(
  sql: Sql,
  storage: PrivateFileStorage,
  logger: Logger,
  intervalMs = 5_000,
): FileCleanupRuntime {
  const workerId = `file050-${crypto.randomUUID()}`;
  let closed = false;
  let running: Promise<number> | null = null;

  const runOnce = async (): Promise<number> => {
    if (closed) return 0;
    const rows = await sql<{ jobs: CleanupJob[] }[]>`
      select private.api050_claim_cleanup(${workerId},20) as jobs
    `;
    const jobs = rows[0]?.jobs ?? [];
    for (const job of jobs) {
      try {
        await storage.delete(job.bucket, job.objectKey);
        await finish(sql, workerId, job.jobId, true, null);
        logger.info("file_cleanup_completed", {
          job_id: job.jobId,
          upload_id: job.uploadId,
          file_present: job.fileId !== null,
        });
      } catch {
        await finish(sql, workerId, job.jobId, false, "STORAGE_UNAVAILABLE");
        logger.warn("file_cleanup_retry", { job_id: job.jobId });
      }
    }
    return jobs.length;
  };

  const timer = setInterval(() => {
    if (running) return;
    running = runOnce().catch((error) => {
      logger.error("file_cleanup_poll_failed", {
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

async function finish(
  sql: Sql,
  workerId: string,
  jobId: number,
  succeeded: boolean,
  errorCode: string | null,
): Promise<void> {
  const rows = await sql<{ completed: boolean }[]>`
    select private.api050_finish_cleanup(
      ${workerId},${jobId},${succeeded},${errorCode}
    ) as completed
  `;
  if (rows[0]?.completed !== true) throw new Error("cleanup claim lost");
}
