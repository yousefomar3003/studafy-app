import type { Sql } from "@studafy/database";
import type { Logger } from "@studafy/observability";
import type { FileScanner, PrivateFileStorage } from "@studafy/infrastructure";
import { sha256Hex } from "@studafy/infrastructure";

export interface ScanJob {
  jobId: number;
  uploadId: string;
  fileId: string;
  schoolId: string;
  purpose: string;
  bucket: string;
  objectKey: string;
  sizeBytes: number;
  sha256: string | null;
  /** Set when an earlier attempt already recorded (and maybe wrote) a transform. */
  storedSha256: string | null;
  transformPolicyVersion: string | null;
  declaredMediaType: string | null;
  detectedMediaType: string | null;
}

export interface ScanFinish {
  outcome: "clean" | "rejected" | "retry";
  errorCode?: string;
  scanPolicyVersion?: string;
  scanDurationMs?: number;
  transformPolicyVersion?: string;
  storedSha256?: string;
  storedSizeBytes?: number;
}

/** The database half of the scan loop — `SECURITY DEFINER` functions only. */
export interface ScanQueue {
  claim(workerId: string, limit: number): Promise<ScanJob[]>;
  recordTransform(
    workerId: string,
    jobId: number,
    storedSha256: string,
    storedSizeBytes: number,
    transformPolicyVersion: string,
  ): Promise<boolean>;
  finish(workerId: string, jobId: number, result: ScanFinish): Promise<boolean>;
  backlog(): Promise<Record<string, number>>;
}

export interface FileScanRuntime {
  close(): Promise<void>;
  runOnce(): Promise<number>;
}

export function postgresScanQueue(sql: Sql): ScanQueue {
  return {
    async claim(workerId, limit) {
      const rows = await sql<{ jobs: ScanJob[] }[]>`
        select private.api051_claim_scan(${workerId},${limit}) as jobs
      `;
      return rows[0]?.jobs ?? [];
    },
    async recordTransform(workerId, jobId, storedSha256, size, policy) {
      const rows = await sql<{ recorded: boolean }[]>`
        select private.api051_record_transform(
          ${workerId},${jobId},${storedSha256},${size},${policy}
        ) as recorded
      `;
      return rows[0]?.recorded === true;
    },
    async finish(workerId, jobId, result) {
      const rows = await sql<{ completed: boolean }[]>`
        select private.api051_finish_scan(
          ${workerId},${jobId},${sql.json(result as never)}
        ) as completed
      `;
      return rows[0]?.completed === true;
    },
    async backlog() {
      const rows = await sql<{ backlog: Record<string, number> }[]>`
        select private.api051_scan_backlog() as backlog
      `;
      return rows[0]?.backlog ?? {};
    },
  };
}

/**
 * FILE-051 scan worker. Accepts no object location from a caller: each
 * exact bucket/key comes from the `SECURITY DEFINER` claim, and the stored
 * bytes are re-verified against the immutable row before scanning.
 *
 * Ordering is what keeps this fail-closed:
 *  1. the stored bytes must hash to the uploaded digest — or to the
 *     transform digest an earlier attempt recorded before writing;
 *  2. a transform digest is recorded *before* the object is overwritten;
 *  3. the overwrite is read back and must match that digest exactly;
 *  4. only then is `clean` reported.
 * Every other path retries with the object still quarantined.
 */
export function createFileScanProcessor(
  queue: ScanQueue,
  storage: PrivateFileStorage,
  scanner: FileScanner,
  logger: Logger,
): { runOnce(): Promise<number> } {
  const workerId = `file051-${crypto.randomUUID()}`;
  let lastBacklogAt = 0;

  // Quarantine age and dead letters, at most once a minute: the signals the
  // malicious-file runbook alerts on. Counts only, no identifiers.
  const reportBacklog = async (): Promise<void> => {
    if (Date.now() - lastBacklogAt < 60_000) return;
    lastBacklogAt = Date.now();
    const backlog = await queue.backlog();
    logger.info("file_scan_backlog", {
      quarantined: backlog.quarantined ?? 0,
      oldest_quarantine_seconds: backlog.oldestQuarantineSeconds ?? 0,
      scan_dead_letters: backlog.scanDeadLetters ?? 0,
      delete_dead_letters: backlog.deleteDeadLetters ?? 0,
      dedupe_bytes_pending: backlog.dedupeBytesPending ?? 0,
    });
  };

  const finish = async (jobId: number, result: ScanFinish): Promise<void> => {
    if (!(await queue.finish(workerId, jobId, result))) {
      throw new Error("scan claim lost");
    }
  };

  const retry = async (
    job: ScanJob,
    errorCode: string,
    event: string,
  ): Promise<void> => {
    await finish(job.jobId, { outcome: "retry", errorCode });
    logger.warn(event, { job_id: job.jobId, file_id: job.fileId });
  };

  const scanOne = async (job: ScanJob): Promise<void> => {
    const { bytes } = await storage.openObject(job.bucket, job.objectKey);
    const digest = await sha256Hex(bytes);
    const isOriginal = job.sha256 !== null && digest === job.sha256;
    const isOwnEarlierWrite = job.storedSha256 !== null &&
      digest === job.storedSha256;
    if (!isOriginal && !isOwnEarlierWrite) {
      // The immutable row and the stored object disagree; never scan to
      // clean on top of bytes nobody can account for.
      await retry(job, "stored_object_mismatch", "file_scan_object_mismatch");
      return;
    }
    const result = await scanner.scan({
      bytes,
      mediaType: job.detectedMediaType ?? "",
      purpose: job.purpose,
    });

    if (result.verdict === "infrastructure") {
      await retry(job, "SCAN_INFRASTRUCTURE", "file_scan_retry");
      return;
    }
    if (result.verdict !== "clean") {
      await finish(job.jobId, {
        outcome: "rejected",
        errorCode: result.errorCode ?? "malformed_file",
        scanPolicyVersion: result.scanPolicyVersion,
        scanDurationMs: result.durationMs,
      });
      logger.warn("file_scan_rejected", {
        job_id: job.jobId,
        file_id: job.fileId,
        verdict: result.verdict,
        failure_code: result.errorCode ?? "unknown",
        scan_policy_version: result.scanPolicyVersion,
      });
      return;
    }
    if (result.storedSha256 === null || result.storedSizeBytes === null) {
      await retry(job, "SCAN_INFRASTRUCTURE", "file_scan_retry");
      return;
    }

    if (result.storedBytes !== null && result.storedSha256 !== digest) {
      const recorded = await queue.recordTransform(
        workerId,
        job.jobId,
        result.storedSha256,
        result.storedSizeBytes,
        result.transformPolicyVersion ?? "unknown",
      );
      if (!recorded) throw new Error("scan claim lost");
      await storage.replaceObject(
        job.bucket,
        job.objectKey,
        result.storedBytes,
        job.detectedMediaType ?? "application/octet-stream",
      );
      const observed = await storage.inspect(
        job.bucket,
        job.objectKey,
        result.storedSizeBytes,
      );
      // A read-back without a digest proves nothing about the stored bytes,
      // so it is a mismatch — never a reason to fall back to a local hash.
      if (
        !observed.exists || observed.sha256 === undefined ||
        observed.sha256 !== result.storedSha256 ||
        observed.sizeBytes !== result.storedSizeBytes
      ) {
        await retry(
          job,
          "stored_object_mismatch",
          "file_scan_readback_mismatch",
        );
        return;
      }
    }

    await finish(job.jobId, {
      outcome: "clean",
      scanPolicyVersion: result.scanPolicyVersion,
      scanDurationMs: result.durationMs,
      transformPolicyVersion: result.transformPolicyVersion ?? undefined,
      storedSha256: result.storedSha256,
      storedSizeBytes: result.storedSizeBytes,
    });
    logger.info("file_scan_completed", {
      job_id: job.jobId,
      file_id: job.fileId,
      verdict: result.verdict,
      duration_ms: result.durationMs,
      transform_applied: result.storedBytes !== null,
      transform_policy_version: result.transformPolicyVersion,
      scan_policy_version: result.scanPolicyVersion,
    });
  };

  return {
    async runOnce() {
      await reportBacklog();
      const jobs = await queue.claim(workerId, 10);
      for (const job of jobs) {
        try {
          await scanOne(job);
        } catch {
          // Storage or scanner failure: retry, never clean. A lost claim
          // makes this finish a no-op, which the next claim recovers.
          await queue.finish(workerId, job.jobId, {
            outcome: "retry",
            errorCode: "SCAN_INFRASTRUCTURE",
          });
          logger.warn("file_scan_retry", {
            job_id: job.jobId,
            file_id: job.fileId,
          });
        }
      }
      return jobs.length;
    },
  };
}

export function startFileScan(
  sql: Sql,
  storage: PrivateFileStorage,
  scanner: FileScanner,
  logger: Logger,
  intervalMs = 5_000,
): FileScanRuntime {
  const processor = createFileScanProcessor(
    postgresScanQueue(sql),
    storage,
    scanner,
    logger,
  );
  let closed = false;
  let running: Promise<number> | null = null;

  const runOnce = async (): Promise<number> =>
    closed ? 0 : await processor.runOnce();

  const timer = setInterval(() => {
    if (running) return;
    running = runOnce().catch((error) => {
      logger.error("file_scan_poll_failed", {
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
