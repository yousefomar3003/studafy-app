import type { Sql } from "@studafy/database";
import type { Logger } from "@studafy/observability";
import {
  analyzeBytes,
  CSV_MEDIA_TYPE,
  DOC_MEDIA_TYPE,
  DOCX_MEDIA_TYPE,
  parsePdf,
  PPT_MEDIA_TYPE,
  PPTX_MEDIA_TYPE,
  XLS_MEDIA_TYPE,
  XLSX_MEDIA_TYPE,
} from "@studafy/domain";
import {
  ConverterUnavailableError,
  type ConvertFrom,
  type ConvertTo,
  detectMediaType,
  type DocumentConverter,
  type RenditionStorage,
  sha256Hex,
  StorageUnavailableError,
} from "@studafy/infrastructure";
import { errorFields } from "../platform/jobGuards";

/**
 * Derived files (DL-078): an in-app PDF preview of each Office file or CSV,
 * and the .docx/.xlsx/.pptx copy of an old .doc/.xls/.ppt for the material
 * index.
 *
 * Like the scan worker it accepts no location from anyone: the source
 * object, its digest and the rendition's key all come from the SECURITY
 * DEFINER claim. Only the exact bytes the scan cleared are sent to the
 * converter, and what comes back must pass the upload scan for its own type
 * before it is stored - the converter is trusted to convert, not to be
 * right. File names and contents are never logged: ids, kinds and codes.
 */

export interface RenditionJob {
  renditionId: string;
  kind: "pdf_preview" | "ooxml";
  attempt: number;
  sourceMediaType: string;
  mediaType: string;
  bucket: string;
  objectKey: string;
  source: {
    bucket: string;
    objectKey: string;
    storedSha256: string | null;
    storedSizeBytes: number | null;
    clean: boolean;
  } | null;
}

export type RenditionResult =
  | { outcome: "ready"; sha256: string; sizeBytes: number }
  | { outcome: "failed" | "retry" | "skipped"; code: string };

export interface RenditionDeletion {
  deletionId: number;
  bucket: string;
  objectKey: string;
}

/** The database half: SECURITY DEFINER functions only. */
export interface RenditionQueue {
  claim(workerId: string, limit: number): Promise<RenditionJob[]>;
  finish(
    workerId: string,
    renditionId: string,
    result: RenditionResult,
  ): Promise<"recorded" | "lost" | "gone">;
  requeueSkipped(): Promise<number>;
  claimDeletions(workerId: string, limit: number): Promise<RenditionDeletion[]>;
  finishDeletion(
    workerId: string,
    deletionId: number,
    succeeded: boolean,
    errorCode: string | null,
  ): Promise<boolean>;
  backlog(): Promise<Record<string, number>>;
}

export function postgresRenditionQueue(sql: Sql): RenditionQueue {
  return {
    async claim(workerId, limit) {
      const rows = await sql<{ jobs: RenditionJob[] }[]>`
        select private.file_rendition_claim(${workerId}, ${limit}) as jobs
      `;
      return rows[0]?.jobs ?? [];
    },
    async finish(workerId, renditionId, result) {
      const rows = await sql<{ answer: "recorded" | "lost" | "gone" }[]>`
        select private.file_rendition_finish(
          ${workerId}, ${renditionId}::uuid, ${sql.json(result as never)}
        ) as answer
      `;
      return rows[0]?.answer ?? "lost";
    },
    async requeueSkipped() {
      const rows = await sql<{ count: number }[]>`
        select private.file_rendition_requeue_skipped() as count
      `;
      return Number(rows[0]?.count ?? 0);
    },
    async claimDeletions(workerId, limit) {
      const rows = await sql<{ jobs: RenditionDeletion[] }[]>`
        select private.file_rendition_claim_deletions(${workerId}, ${limit})
          as jobs
      `;
      return rows[0]?.jobs ?? [];
    },
    async finishDeletion(workerId, deletionId, succeeded, errorCode) {
      const rows = await sql<{ done: boolean }[]>`
        select private.file_rendition_finish_deletion(
          ${workerId}, ${deletionId}, ${succeeded}, ${errorCode}
        ) as done
      `;
      return rows[0]?.done === true;
    },
    async backlog() {
      const rows = await sql<{ backlog: Record<string, number> }[]>`
        select private.file_rendition_backlog() as backlog
      `;
      return rows[0]?.backlog ?? {};
    },
  };
}

const FROM: Readonly<Record<string, ConvertFrom>> = {
  [DOC_MEDIA_TYPE]: "doc",
  [DOCX_MEDIA_TYPE]: "docx",
  [XLS_MEDIA_TYPE]: "xls",
  [XLSX_MEDIA_TYPE]: "xlsx",
  [CSV_MEDIA_TYPE]: "csv",
  [PPT_MEDIA_TYPE]: "ppt",
  [PPTX_MEDIA_TYPE]: "pptx",
};

const OOXML_TO: Readonly<Record<string, ConvertTo>> = {
  [DOCX_MEDIA_TYPE]: "docx",
  [XLSX_MEDIA_TYPE]: "xlsx",
  [PPTX_MEDIA_TYPE]: "pptx",
};

const PDF = "application/pdf";

/**
 * Null when converted bytes pass the upload rules for their own type, or
 * the rule they broke: a short code, never anything read from the file, so
 * a refused preview can be diagnosed from the log (2026-11-03: the first
 * live previews were refused without saying why).
 */
async function outputRefusal(
  bytes: Uint8Array,
  mediaType: string,
): Promise<string | null> {
  if (detectMediaType(bytes) !== mediaType) return "type_mismatch";
  if (mediaType === PDF) {
    // LibreOffice opens every PDF at page one with an /OpenAction
    // destination; nothing else an upload may not have is let through.
    const parsed = await parsePdf(bytes, { allowOpenActionDestination: true });
    if (parsed.ok) return null;
    if (parsed.pattern) {
      return `pdf_${parsed.reason}_${parsed.pattern}_${parsed.location}`;
    }
    return parsed.detail
      ? `pdf_${parsed.reason}_${parsed.detail}`
      : `pdf_${parsed.reason}`;
  }
  const analysis = await analyzeBytes(bytes, mediaType);
  return analysis.verdict === "clean" ? null : `analysis_${analysis.verdict}`;
}

export interface RenditionDeps {
  queue: RenditionQueue;
  storage: RenditionStorage;
  /** The converter, or null: then every rendition is marked skipped. */
  converter: DocumentConverter | null;
  logger: Logger;
  /** Conversions in hand at once. The converter itself does one at a time. */
  concurrency: number;
  workerId?: string;
}

export function createRenditionProcessor(deps: RenditionDeps) {
  const workerId = deps.workerId ?? `renditions-${crypto.randomUUID()}`;

  const finish = async (job: RenditionJob, result: RenditionResult) => {
    const answer = await deps.queue.finish(workerId, job.renditionId, result);
    deps.logger.info("rendition_finished", {
      rendition_id: job.renditionId,
      kind: job.kind,
      outcome: result.outcome,
      ...("code" in result ? { code: result.code } : {}),
      attempt: job.attempt,
      answer,
    });
    return answer;
  };

  async function process(job: RenditionJob): Promise<void> {
    if (!deps.converter) {
      await finish(job, {
        outcome: "skipped",
        code: "converter_not_configured",
      });
      return;
    }
    const from = FROM[job.sourceMediaType];
    const to = job.kind === "pdf_preview" ? "pdf" : OOXML_TO[job.mediaType];
    const source = job.source;
    if (!from || !to || (job.kind === "pdf_preview" && job.mediaType !== PDF)) {
      await finish(job, { outcome: "failed", code: "unsupported_type" });
      return;
    }
    if (!source?.clean || !source.storedSha256) {
      await finish(job, { outcome: "failed", code: "source_unavailable" });
      return;
    }
    try {
      const { bytes } = await deps.storage.openObject(
        source.bucket,
        source.objectKey,
      );
      // Only the exact bytes the scan cleared are ever converted.
      if (await sha256Hex(bytes) !== source.storedSha256) {
        await finish(job, { outcome: "retry", code: "stored_object_mismatch" });
        return;
      }
      const converted = await deps.converter.convert(bytes, from, to);
      if (!converted.ok) {
        await finish(job, { outcome: "failed", code: converted.code });
        return;
      }
      const refusal = await outputRefusal(converted.bytes, job.mediaType);
      if (refusal) {
        deps.logger.warn("rendition_output_refused", {
          rendition_id: job.renditionId,
          kind: job.kind,
          rule: refusal,
        });
        await finish(job, { outcome: "failed", code: "unsafe_output" });
        return;
      }
      await deps.storage.writeRendition(
        job.bucket,
        job.objectKey,
        converted.bytes,
        job.mediaType,
      );
      const answer = await finish(job, {
        outcome: "ready",
        sha256: await sha256Hex(converted.bytes),
        sizeBytes: converted.bytes.byteLength,
      });
      // The file went while this was converting: its row and the queued
      // deletion may both be gone, so remove what was just written.
      if (answer === "gone") {
        await deps.storage.delete(job.bucket, job.objectKey).catch(() => {
          deps.logger.warn("rendition_orphan_delete_failed", {
            rendition_id: job.renditionId,
          });
        });
      }
    } catch (error) {
      const code = error instanceof ConverterUnavailableError
        ? "converter_unavailable"
        : error instanceof StorageUnavailableError
        ? "storage_unavailable"
        : "temporary";
      deps.logger.warn("rendition_retry", {
        rendition_id: job.renditionId,
        kind: job.kind,
        attempt: job.attempt,
        code,
        ...(code === "temporary" ? errorFields(error) : {}),
      });
      await deps.queue.finish(workerId, job.renditionId, {
        outcome: "retry",
        code,
      });
    }
  }

  /** Deletes the objects of renditions that are gone; the number handled. */
  async function sweepDeletions(limit = 50): Promise<number> {
    const jobs = await deps.queue.claimDeletions(workerId, limit);
    for (const job of jobs) {
      let ok = true;
      try {
        await deps.storage.delete(job.bucket, job.objectKey);
      } catch {
        ok = false;
      }
      await deps.queue.finishDeletion(
        workerId,
        job.deletionId,
        ok,
        ok ? null : "STORAGE_UNAVAILABLE",
      );
      if (!ok) {
        deps.logger.warn("rendition_delete_retry", {
          deletion_id: job.deletionId,
        });
      }
    }
    return jobs.length;
  }

  return {
    workerId,
    process,
    sweepDeletions,
    /** Claims up to [limit] renditions and makes them; the number. */
    async runOnce(limit = deps.concurrency): Promise<number> {
      const jobs = await deps.queue.claim(workerId, limit);
      await Promise.all(jobs.map((job) => process(job)));
      return jobs.length;
    },
  };
}

/**
 * Polls every [intervalMs], keeping up to `concurrency` conversions in hand,
 * and sweeps rendition objects due for deletion. With a converter, renditions
 * skipped while there was none are queued again at start. On close it stops
 * claiming and waits a little for those in hand; any unfinished are taken up
 * again when their lease lapses.
 */
export function startRenditions(
  deps: RenditionDeps,
  intervalMs: number,
  options: { backlogLogIntervalMs?: number; closeWaitMs?: number } = {},
) {
  const processor = createRenditionProcessor(deps);
  const inFlight = new Set<Promise<unknown>>();
  let closed = false;
  let ticking = false;
  let lastBacklogAt = 0;
  let requeued = deps.converter === null;
  const backlogEvery = options.backlogLogIntervalMs ?? 60_000;

  const tick = async () => {
    if (closed || ticking) return;
    ticking = true;
    try {
      if (!requeued) {
        const count = await deps.queue.requeueSkipped();
        requeued = true;
        if (count > 0) deps.logger.info("renditions_requeued", { count });
      }
      const free = deps.concurrency - inFlight.size;
      if (free > 0) {
        const jobs = await deps.queue.claim(processor.workerId, free);
        for (const job of jobs) {
          const work = processor.process(job).catch((error) => {
            // The database was unreachable when reporting: the lease lapses
            // and the rendition is tried again.
            deps.logger.error("rendition_failed", { ...errorFields(error) });
          }).finally(() => inFlight.delete(work));
          inFlight.add(work);
        }
      }
      await processor.sweepDeletions();
      if (Date.now() - lastBacklogAt >= backlogEvery) {
        lastBacklogAt = Date.now();
        const backlog = await deps.queue.backlog();
        deps.logger.info("rendition_backlog", {
          queued: backlog["queued"] ?? 0,
          processing: backlog["processing"] ?? 0,
          failed: backlog["failed"] ?? 0,
          skipped: backlog["skipped"] ?? 0,
          deletions_pending: backlog["deletionsPending"] ?? 0,
          deletions_dead: backlog["deletionsDead"] ?? 0,
          in_flight: inFlight.size,
        });
      }
    } catch (error) {
      deps.logger.error("rendition_poll_failed", { ...errorFields(error) });
    } finally {
      ticking = false;
    }
  };

  const timer = setInterval(() => void tick(), intervalMs);
  void tick();
  deps.logger.info("worker_ready", {
    queue: "renditions",
    concurrency: deps.concurrency,
    converter: deps.converter !== null,
  });

  return {
    workerId: processor.workerId,
    runOnce: () => processor.runOnce(),
    inFlight: () => inFlight.size,
    async close() {
      closed = true;
      clearInterval(timer);
      let wait: ReturnType<typeof setTimeout> | undefined;
      await Promise.race([
        Promise.allSettled([...inFlight]),
        new Promise((resolve) => {
          wait = setTimeout(resolve, options.closeWaitMs ?? 20_000);
        }),
      ]);
      clearTimeout(wait);
    },
  };
}
