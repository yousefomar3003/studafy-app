import type { Sql } from "@studafy/database";
import type { Logger } from "@studafy/observability";
import {
  hasReference,
  type MarkingReference,
  type MarkingStrictness,
  type MarkingVerdict,
  type StudyUsage,
} from "@studafy/domain";
import {
  costMicroUsd,
  holdFor,
  knownNamesOf,
  KnownNamesUnavailable,
  type ModelPrices,
  type PageReader,
  type PrivateFileStorage,
  readMaterial,
  redactingNames,
  sha256Hex,
  type StudyAssistant,
  StudyAssistantError,
} from "@studafy/infrastructure";
import { errorFields } from "../platform/jobGuards";

/**
 * Suggested marks (ADR-0046), made off their own queue.
 *
 * The API records what the teacher asked for - one row per written answer
 * or hand-in, each its own job - and this claims them with a lease. For each
 * it reads the student's work (typed text, and for a hand-in the clean files
 * the scan cleared, bytes checked against the stored digest), replaces every
 * name on the class roster, asks the model for a suggestion against the
 * reference the run recorded, and reports it. Every model call is held and
 * settled in the teacher's own marking ledger first, which refuses past the
 * plan or its monthly cap.
 *
 * A suggestion is a draft. Nothing here writes a mark.
 *
 * What a student wrote, the teacher's reference and the model's reply are
 * never logged: only the shape of what happened.
 */

export interface MarkingFile {
  fileId: string;
  bucket: string;
  objectKey: string;
  storedSha256: string | null;
  mediaType: string | null;
  rootClean: boolean;
}

export interface MarkingJob {
  id: string;
  attempt: number;
  teacherId: string;
  studentId: string;
  maximumScore: number;
  strictness: MarkingStrictness;
  referenceVersion: number;
  limits: {
    pagesPerHandIn?: number;
    handInChars?: number;
  };
  question: (MarkingReference & { questionId: string | null }) | null;
  answerText: string | null;
  files: MarkingFile[];
  names: unknown;
  planActive: boolean;
  teaches: boolean;
}

export type MarkingOutcome = "ready" | "retry" | "skipped" | "failed";

export interface MarkingQueue {
  claim(workerId: string, limit: number): Promise<MarkingJob[]>;
  usage(
    workerId: string,
    job: MarkingJob,
    operation: "reserve" | "settle" | "release",
    input: Record<string, unknown>,
  ): Promise<Record<string, unknown>>;
  finish(
    workerId: string,
    job: MarkingJob,
    outcome: MarkingOutcome,
    result: Record<string, unknown>,
  ): Promise<Record<string, unknown>>;
  backlog(): Promise<Record<string, number>>;
  purge(): Promise<Record<string, number>>;
}

export function postgresMarkingQueue(sql: Sql): MarkingQueue {
  return {
    async claim(workerId, limit) {
      const rows = await sql<{ jobs: MarkingJob[] }[]>`
        select private.marking_jobs_claim(${workerId}, ${limit}) as jobs
      `;
      return rows[0]?.jobs ?? [];
    },
    async usage(workerId, job, operation, input) {
      const rows = await sql<{ result: Record<string, unknown> }[]>`
        select private.marking_job_usage(${workerId}, ${job.id}::uuid,
          ${job.attempt}, ${operation}, ${sql.json(input as never)}) as result
      `;
      return rows[0]?.result ?? { outcome: "invalid" };
    },
    async finish(workerId, job, outcome, result) {
      const rows = await sql<{ result: Record<string, unknown> }[]>`
        select private.marking_job_finish(${workerId}, ${job.id}::uuid,
          ${job.attempt}, ${outcome}, ${sql.json(result as never)}) as result
      `;
      return rows[0]?.result ?? { outcome: "invalid" };
    },
    async backlog() {
      const rows = await sql<{ backlog: Record<string, number> }[]>`
        select private.marking_jobs_backlog() as backlog
      `;
      return rows[0]?.backlog ?? {};
    },
    async purge() {
      const rows = await sql<{ purged: Record<string, number> }[]>`
        select private.marking_purge_expired() as purged
      `;
      return rows[0]?.purged ?? {};
    },
  };
}

/** Another worker holds the job now: stop, and leave it to that one. */
class LeaseLost extends Error {
  constructor() {
    super("marking_lease_lost");
  }
}

/** The ledger refused a model call: the job ends with this reason. */
class Refused extends Error {
  constructor(readonly outcome: "skipped" | "failed", readonly reason: string) {
    super(`marking_refused_${reason}`);
  }
}

export interface MarkingSuggestionsDeps {
  queue: MarkingQueue;
  storage: PrivateFileStorage;
  /** The model; the processor is started only with one. */
  assistant: Pick<StudyAssistant, "markAnswer" | "transcribe">;
  prices: ModelPrices;
  logger: Logger;
  /** Suggestions made at once. */
  concurrency: number;
  workerId?: string;
}

/** The defaults behind private.marking_limits(), if a claim lacks them. */
const PAGES_PER_HAND_IN = 20;
const HAND_IN_CHARS = 60_000;
const MARKING_OUTPUT_TOKENS = 900;
const PAGE_OUTPUT_TOKENS = 1_400;

const NO_SCORE: Omit<MarkingVerdict, "reviewReason"> = {
  suggestedScore: null,
  met: [],
  missed: [],
  rationale: null,
  feedback: null,
  conflict: null,
};

export function createMarkingSuggestionsProcessor(
  deps: MarkingSuggestionsDeps,
) {
  const workerId = deps.workerId ?? `marking-${crypto.randomUUID()}`;

  /**
   * One model call, held in the teacher's ledger first and settled with
   * what the provider reported - or the hold, if it reported nothing but may
   * have billed.
   */
  async function metered<T extends { usage?: StudyUsage }>(
    job: MarkingJob,
    inputChars: number,
    outputTokens: number,
    photos: number,
    call: () => Promise<T>,
  ): Promise<T> {
    const hold = holdFor(deps.prices, inputChars, outputTokens, photos);
    const reserved = await deps.queue.usage(workerId, job, "reserve", {
      estimateTokens: hold.tokens,
      estimateMicroUsd: hold.microUsd,
    });
    switch (reserved["outcome"]) {
      case "ok":
        break;
      case "lease_lost":
        throw new LeaseLost();
      case "plan_required":
        throw new Refused("skipped", "plan_inactive");
      case "allowance_exhausted":
      case "monthly_cap":
        throw new Refused("failed", "allowance_used");
      default:
        throw new Refused("failed", "ledger_refused");
    }
    const usageId = reserved["usageId"];
    const settle = (usage: StudyUsage | undefined) =>
      deps.queue.usage(workerId, job, "settle", {
        usageId,
        inputTokens: usage?.inputTokens ?? hold.tokens - outputTokens,
        outputTokens: usage?.outputTokens ?? outputTokens,
        costMicroUsd: usage
          ? costMicroUsd(deps.prices, usage.inputTokens, usage.outputTokens)
          : hold.microUsd,
        model: usage?.model ?? null,
      });
    try {
      const result = await call();
      await settle(result.usage);
      return result;
    } catch (error) {
      if (error instanceof StudyAssistantError && error.billed) {
        await settle(error.usage);
      } else {
        await deps.queue.usage(workerId, job, "release", { usageId });
      }
      throw error;
    }
  }

  /** The student's work as text: what they typed, then each file read. */
  async function workText(
    job: MarkingJob,
  ): Promise<{ text: string; unreadableFiles: number }> {
    const limit = job.limits.handInChars ?? HAND_IN_CHARS;
    const parts: string[] = [];
    if (job.answerText?.trim()) parts.push(job.answerText.trim());
    let pagesLeft = job.limits.pagesPerHandIn ?? PAGES_PER_HAND_IN;
    let unreadableFiles = 0;
    // Handwriting is copied exactly, mistakes and all: it is to be marked.
    const reader: PageReader = async (jpeg) => {
      const reply = await metered(
        job,
        0,
        PAGE_OUTPUT_TOKENS,
        1,
        () => deps.assistant.transcribe(jpeg, "image/jpeg", "work"),
      );
      return {
        text: reply.answer,
        ...(reply.usage ? { usage: reply.usage } : {}),
      };
    };
    for (const file of job.files) {
      const used = parts.join("\n\n").length;
      if (used >= limit) break;
      if (!file.rootClean || !file.mediaType) {
        unreadableFiles++;
        continue;
      }
      const { bytes } = await deps.storage.openObject(
        file.bucket,
        file.objectKey,
      );
      // Only the exact bytes the scan cleared are ever read or sent.
      if (await sha256Hex(bytes) !== file.storedSha256) {
        unreadableFiles++;
        continue;
      }
      const read = await readMaterial(
        { kind: "file", mediaType: file.mediaType, bytes },
        {
          limits: {
            ocrPagesPerFile: pagesLeft,
            textPagesPerFile: Math.max(pagesLeft, 1),
            charsPerDocument: limit - used,
            linkMaxBytes: 0,
          },
          ocrAllowance: (pages) => {
            const allowed = Math.max(0, Math.min(pages, pagesLeft));
            pagesLeft -= allowed;
            return Promise.resolve(allowed);
          },
          readPage: reader,
          readImage: reader,
        },
      );
      const text = read.chunks.map((chunk) => chunk.body).join("\n\n").trim();
      if (text) parts.push(text);
      else unreadableFiles++;
    }
    return { text: parts.join("\n\n").slice(0, limit), unreadableFiles };
  }

  async function suggest(
    job: MarkingJob,
  ): Promise<{ outcome: MarkingOutcome; result: Record<string, unknown> }> {
    // Re-checked at claim time: a teacher who left the class, or whose plan
    // lapsed, sends nothing more.
    if (!job.teaches) {
      return { outcome: "skipped", result: { reason: "not_teacher" } };
    }
    if (!job.planActive) {
      return { outcome: "skipped", result: { reason: "plan_inactive" } };
    }
    const reference = job.question;
    if (!reference || !hasReference(reference)) {
      return {
        outcome: "ready",
        result: { ...NO_SCORE, reviewReason: "no_reference" },
      };
    }
    // With no list of names there is no call (ADR-0043).
    const names = knownNamesOf({ outcome: "ok", names: job.names });
    const work = await workText(job);
    if (!work.text) {
      return {
        outcome: "ready",
        result: {
          ...NO_SCORE,
          reviewReason: work.unreadableFiles > 0 ? "unreadable" : "empty",
        },
      };
    }
    const assistant = redactingNames(
      { markAnswer: deps.assistant.markAnswer },
      names,
    );
    const marked = await metered(
      job,
      work.text.length + JSON.stringify(reference).length,
      MARKING_OUTPUT_TOKENS,
      0,
      () =>
        assistant.markAnswer!(
          { ...reference, maximumScore: job.maximumScore },
          work.text,
          job.strictness,
        ),
    );
    const verdict = marked.verdict;
    return {
      outcome: "ready",
      result: {
        ...verdict,
        // Part of the work could not be read: the teacher should look.
        reviewReason: verdict.reviewReason ??
          (work.unreadableFiles > 0 ? "unreadable" : null),
        model: marked.usage?.model ?? null,
      },
    };
  }

  async function process(job: MarkingJob): Promise<string> {
    const started = performance.now();
    let outcome: MarkingOutcome;
    let result: Record<string, unknown>;
    try {
      ({ outcome, result } = await suggest(job));
    } catch (error) {
      if (error instanceof LeaseLost) {
        deps.logger.warn("marking_lease_lost", { attempt: job.attempt });
        return "lease_lost";
      }
      if (error instanceof Refused) {
        outcome = error.outcome;
        result = { reason: error.reason };
      } else if (error instanceof KnownNamesUnavailable) {
        outcome = "failed";
        result = { reason: "names_unavailable" };
      } else if (error instanceof StudyAssistantError) {
        // The provider was busy or failed: tried again with backoff, until
        // the database's attempt limit fails it.
        outcome = "retry";
        result = { reason: `model_${error.kind}` };
      } else {
        // Storage or the database: the same.
        deps.logger.warn("marking_job_error", { ...errorFields(error) });
        outcome = "retry";
        result = { reason: "temporary" };
      }
    }
    const finished = await deps.queue.finish(workerId, job, outcome, result);
    const state = String(finished["outcome"]);
    deps.logger.info("marking_suggestion_job", {
      attempt: job.attempt,
      outcome,
      reason: typeof result["reason"] === "string" ? result["reason"] : null,
      review: typeof result["reviewReason"] === "string"
        ? result["reviewReason"]
        : null,
      scored: typeof result["suggestedScore"] === "number",
      files: job.files.length,
      state,
      duration_ms: Math.round(performance.now() - started),
    });
    return state;
  }

  return {
    workerId,
    process,
    /** Claims up to [limit] jobs and makes them together; the number. */
    async runOnce(limit = deps.concurrency): Promise<number> {
      const jobs = await deps.queue.claim(workerId, limit);
      await Promise.all(jobs.map((job) => process(job)));
      return jobs.length;
    },
  };
}

/**
 * Polls the queue every [intervalMs], keeping up to `concurrency`
 * suggestions in hand, and purges what is past its retention once an hour.
 * On close it stops claiming and waits a little for those in hand; any
 * still unfinished are taken up again when their lease lapses.
 */
export function startMarkingSuggestions(
  deps: MarkingSuggestionsDeps,
  intervalMs: number,
  options: { backlogLogIntervalMs?: number; closeWaitMs?: number } = {},
) {
  const processor = createMarkingSuggestionsProcessor(deps);
  const inFlight = new Set<Promise<unknown>>();
  let closed = false;
  let claiming = false;
  let lastBacklogAt = 0;
  let lastPurgeAt = 0;
  const backlogEvery = options.backlogLogIntervalMs ?? 60_000;

  const tick = async () => {
    if (closed || claiming) return;
    claiming = true;
    try {
      const free = deps.concurrency - inFlight.size;
      if (free > 0) {
        const jobs = await deps.queue.claim(processor.workerId, free);
        for (const job of jobs) {
          const work = processor.process(job).catch((error) => {
            // The database was unreachable when reporting: the lease lapses
            // and the job is tried again.
            deps.logger.error("marking_job_failed", { ...errorFields(error) });
          }).finally(() => inFlight.delete(work));
          inFlight.add(work);
        }
      }
      if (Date.now() - lastBacklogAt >= backlogEvery) {
        lastBacklogAt = Date.now();
        const backlog = await deps.queue.backlog();
        deps.logger.info("marking_backlog", {
          pending: backlog["pending"] ?? 0,
          oldest_pending_seconds: backlog["oldestSeconds"] ?? 0,
          in_flight: inFlight.size,
        });
      }
      if (Date.now() - lastPurgeAt >= 3_600_000) {
        lastPurgeAt = Date.now();
        deps.logger.info("marking_purged", await deps.queue.purge());
      }
    } catch (error) {
      deps.logger.error("marking_poll_failed", { ...errorFields(error) });
    } finally {
      claiming = false;
    }
  };

  const timer = setInterval(() => void tick(), intervalMs);
  void tick();
  deps.logger.info("worker_ready", {
    queue: "marking-suggestions",
    concurrency: deps.concurrency,
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
