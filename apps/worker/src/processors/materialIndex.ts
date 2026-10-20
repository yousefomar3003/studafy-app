import type { Sql } from "@studafy/database";
import type { Logger } from "@studafy/observability";
import {
  type MaterialLimits,
  type MaterialReadDeps,
  type MaterialResult,
  type PageReader,
  type PrivateFileStorage,
  readMaterial,
  sha256Hex,
  type StudyAssistant,
} from "@studafy/infrastructure";
import { errorFields } from "../platform/jobGuards";

/**
 * ADR-0037: lesson files and links read into passages in the background,
 * so a student's question can be answered from them.
 *
 * Like the scan worker it accepts no location from anyone: each file's
 * bucket, key and digest come from the claim, and the bytes are checked
 * against the digest the scan recorded before anything reads them. Model
 * reading is paid from the school's monthly page budget, recorded apart
 * from any student's allowance.
 */

export interface MaterialJob {
  docId: string;
  schoolId: string;
  attempt: number;
  kind: "file" | "link";
  file: {
    bucket: string;
    objectKey: string;
    storedSha256: string | null;
    mediaType: string | null;
    rootClean: boolean;
  } | null;
  url: string | null;
  /** private.ai_material_limits(): the one place the limits are set. */
  limits?: Partial<MaterialLimits>;
}

export interface MaterialQueue {
  claim(workerId: string, limit: number): Promise<MaterialJob[]>;
  ocrAllowance(workerId: string, docId: string, pages: number): Promise<number>;
  finish(
    workerId: string,
    docId: string,
    result: Record<string, unknown>,
  ): Promise<boolean>;
}

export function postgresMaterialQueue(sql: Sql): MaterialQueue {
  return {
    async claim(workerId, limit) {
      const rows = await sql<{ jobs: MaterialJob[] }[]>`
        select private.ai_material_claim(${workerId}, ${limit}) as jobs
      `;
      return rows[0]?.jobs ?? [];
    },
    async ocrAllowance(workerId, docId, pages) {
      const rows = await sql<{ pages: number }[]>`
        select private.ai_material_ocr_allowance(
          ${workerId}, ${docId}::uuid, ${pages}
        ) as pages
      `;
      return Number(rows[0]?.pages ?? 0);
    },
    async finish(workerId, docId, result) {
      const rows = await sql<{ done: boolean }[]>`
        select private.ai_material_finish(
          ${workerId}, ${docId}::uuid, ${sql.json(result as never)}
        ) as done
      `;
      return rows[0]?.done === true;
    },
  };
}

export interface MaterialIndexDeps {
  queue: MaterialQueue;
  storage: PrivateFileStorage;
  /** The model, or null: then only files with real text are read. */
  assistant: Pick<StudyAssistant, "transcribe"> | null;
  limits: MaterialLimits;
  prices: { inputUsdPerMTok: number; outputUsdPerMTok: number };
  logger: Logger;
  workerId?: string;
  /** For tests: a stand-in for the network. */
  fetchLink?: MaterialReadDeps["fetchLink"];
}

const cost = (
  prices: MaterialIndexDeps["prices"],
  input: number,
  output: number,
) =>
  Math.ceil(input * prices.inputUsdPerMTok + output * prices.outputUsdPerMTok);

export function createMaterialIndexProcessor(deps: MaterialIndexDeps) {
  const workerId = deps.workerId ?? `material-${crypto.randomUUID()}`;

  const reader = (kind: "page" | "image"): PageReader | null =>
    deps.assistant
      ? async (jpeg) => {
        const reply = await deps.assistant!.transcribe(
          jpeg,
          "image/jpeg",
          kind,
        );
        return {
          text: reply.answer,
          ...(reply.usage ? { usage: reply.usage } : {}),
        };
      }
      : null;

  async function process(job: MaterialJob): Promise<void> {
    let result: MaterialResult;
    try {
      const readDeps: MaterialReadDeps = {
        limits: { ...deps.limits, ...job.limits },
        ocrAllowance: (pages) =>
          deps.queue.ocrAllowance(workerId, job.docId, pages),
        readPage: reader("page"),
        readImage: reader("image"),
        ...(deps.fetchLink ? { fetchLink: deps.fetchLink } : {}),
      };
      if (job.kind === "file") {
        const file = job.file;
        if (!file || !file.rootClean || !file.mediaType) {
          await deps.queue.finish(workerId, job.docId, {
            outcome: "retry",
            reason: "not_scanned",
          });
          return;
        }
        const { bytes } = await deps.storage.openObject(
          file.bucket,
          file.objectKey,
        );
        // Only the exact bytes the scan cleared are ever read or sent.
        if (await sha256Hex(bytes) !== file.storedSha256) {
          await deps.queue.finish(workerId, job.docId, {
            outcome: "retry",
            reason: "stored_object_mismatch",
          });
          return;
        }
        result = await readMaterial(
          { kind: "file", mediaType: file.mediaType, bytes },
          readDeps,
        );
      } else {
        result = await readMaterial(
          { kind: "link", url: job.url ?? "" },
          readDeps,
        );
      }
    } catch (error) {
      // The model, the network or storage was unavailable: try again later.
      deps.logger.warn("material_read_retry", {
        doc_kind: job.kind,
        attempt: job.attempt,
        error_kind: (error as { kind?: string }).kind ?? "unknown",
      });
      await deps.queue.finish(workerId, job.docId, {
        outcome: "retry",
        reason: (error as { kind?: string }).kind === "unavailable"
          ? "model_unavailable"
          : "temporary",
      });
      return;
    }
    await deps.queue.finish(workerId, job.docId, {
      outcome: result.outcome,
      reason: result.reason,
      chunks: result.chunks,
      detail: result.detail,
      extractor: result.extractor,
      usage: result.usage.map((u) => ({
        kind: u.kind,
        pages: u.pages,
        inputTokens: u.inputTokens,
        outputTokens: u.outputTokens,
        costMicroUsd: cost(deps.prices, u.inputTokens, u.outputTokens),
        model: u.model,
      })),
    });
    // What was read is never logged: only its shape.
    deps.logger.info("material_read", {
      doc_kind: job.kind,
      outcome: result.outcome,
      reason: result.reason,
      chunks: result.chunks.length,
      extractor: result.extractor,
    });
  }

  return {
    workerId,
    /** Claims and reads one file or link; the number handled. */
    async runOnce(): Promise<number> {
      const jobs = await deps.queue.claim(workerId, 1);
      for (const job of jobs) await process(job);
      return jobs.length;
    },
  };
}

export function startMaterialIndex(
  deps: MaterialIndexDeps,
  intervalMs: number,
) {
  const processor = createMaterialIndexProcessor(deps);
  let closed = false;
  let running: Promise<number> | null = null;
  const tick = () => {
    if (running || closed) return;
    running = (async () => {
      // Drain what is waiting, a file at a time, then wait for the next tick.
      let handled = 0;
      while (!closed && handled < 20) {
        const n = await processor.runOnce();
        if (n === 0) break;
        handled += n;
      }
      return handled;
    })().catch((error) => {
      deps.logger.error("material_index_poll_failed", {
        ...errorFields(error),
      });
      return 0;
    }).finally(() => running = null);
  };
  const timer = setInterval(tick, intervalMs);
  return {
    runOnce: () => processor.runOnce(),
    async close() {
      closed = true;
      clearInterval(timer);
      await running;
    },
  };
}
