import type { Sql } from "@studafy/database";
import type { Logger } from "@studafy/observability";
import {
  type ModelPrices,
  type NotebookStart,
  type NotebookWriteResult,
  type StudyAssistant,
  type StudyCallContext,
  writeNotebook,
} from "@studafy/infrastructure";

/**
 * Study notebooks, written off the notebook queue (2026-10-16, ADR-0038).
 *
 * The API records a notebook and its job in one transaction and answers
 * "creating"; this claims the job with a lease, writes the notebook with the
 * writer the API used to run in its own process, and reports what came of
 * it. The database decides the rest: saved, failed with the reason the
 * student sees, tried again with backoff, or a dead letter.
 *
 * Every call for a job names the claim - this worker, the job and the
 * attempt - and acts as the notebook's owner only for that notebook's lesson
 * and that generation's AI charge. A worker that lost its lease can no
 * longer act on the job: its calls answer `lease_lost`.
 */

export interface NotebookClaim {
  jobId: string;
  attempt: number;
}

export interface NotebookJob extends NotebookClaim {
  ownerId: string;
  schoolId: string;
  start: NotebookStart;
}

export interface NotebookQueue {
  claim(workerId: string, limit: number): Promise<NotebookJob[]>;
  material(
    workerId: string,
    claim: NotebookClaim,
    operation: string,
    input: Record<string, unknown>,
  ): Promise<Record<string, unknown>>;
  usage(
    workerId: string,
    claim: NotebookClaim,
    operation: string,
    input: Record<string, unknown>,
  ): Promise<Record<string, unknown>>;
  finish(
    workerId: string,
    claim: NotebookClaim,
    result: NotebookWriteResult,
  ): Promise<Record<string, unknown>>;
  backlog(): Promise<Record<string, number>>;
}

export function postgresNotebookQueue(sql: Sql): NotebookQueue {
  return {
    async claim(workerId, limit) {
      const rows = await sql<{ jobs: NotebookJob[] }[]>`
        select private.notebook_jobs_claim(${workerId}, ${limit}) as jobs
      `;
      return rows[0]?.jobs ?? [];
    },
    async material(workerId, claim, operation, input) {
      const rows = await sql<{ result: Record<string, unknown> }[]>`
        select private.notebook_job_material(${workerId}, ${claim.jobId}::uuid,
          ${claim.attempt}, ${operation}, ${sql.json(input as never)}) as result
      `;
      return rows[0]?.result ?? { outcome: "invalid" };
    },
    async usage(workerId, claim, operation, input) {
      const rows = await sql<{ result: Record<string, unknown> }[]>`
        select private.notebook_job_usage(${workerId}, ${claim.jobId}::uuid,
          ${claim.attempt}, ${operation}, ${sql.json(input as never)}) as result
      `;
      return rows[0]?.result ?? { outcome: "invalid" };
    },
    async finish(workerId, claim, result) {
      const rows = await sql<{ result: Record<string, unknown> }[]>`
        select private.notebook_job_finish(${workerId}, ${claim.jobId}::uuid,
          ${claim.attempt}, ${sql.json(result as never)}) as result
      `;
      return rows[0]?.result ?? { outcome: "invalid" };
    },
    async backlog() {
      const rows = await sql<{ backlog: Record<string, number> }[]>`
        select private.notebook_jobs_backlog() as backlog
      `;
      return rows[0]?.backlog ?? {};
    },
  };
}

/** Another worker holds the job now: stop, and leave it to that one. */
export class NotebookLeaseLost extends Error {
  constructor() {
    super("notebook_lease_lost");
    this.name = "NotebookLeaseLost";
  }
}

export interface NotebookGenerationDeps {
  queue: NotebookQueue;
  /** The model; the processor is started only with one. */
  assistant: Pick<StudyAssistant, "notebook">;
  prices: ModelPrices;
  logger: Logger;
  /** Notebooks written at once. */
  concurrency: number;
  workerId?: string;
}

export function createNotebookGenerationProcessor(
  deps: NotebookGenerationDeps,
) {
  const workerId = deps.workerId ?? `notebooks-${crypto.randomUUID()}`;
  const held = (result: Record<string, unknown>) => {
    if (result["outcome"] === "lease_lost") throw new NotebookLeaseLost();
    return result;
  };

  async function process(job: NotebookJob): Promise<string> {
    const started = performance.now();
    const claim = { jobId: job.jobId, attempt: job.attempt };
    // The owner, as the database checks them: every call below runs as the
    // notebook's owner, set by the database from the claim, not from this.
    const context: StudyCallContext = {
      subject: job.ownerId,
      schoolId: job.schoolId,
      requestId: crypto.randomUUID(),
      aal2: false,
    };
    const result = await writeNotebook(
      {
        material: {
          call: async (_context, operation, input) =>
            held(await deps.queue.material(workerId, claim, operation, input)),
        },
        usage: {
          usage: async (_context, operation, input) =>
            held(await deps.queue.usage(workerId, claim, operation, input)),
        },
        prices: deps.prices,
        assistant: deps.assistant,
        logger: deps.logger,
      },
      context,
      job.start,
    );
    const finished = await deps.queue.finish(workerId, claim, result);
    const state = String(finished["state"] ?? finished["outcome"]);
    // Only the shape: never the material or the reply.
    const fields = {
      attempt: job.attempt,
      outcome: result.outcome,
      reason: result.outcome === "ready" ? null : result.reason,
      state,
      duration_ms: Math.round(performance.now() - started),
    };
    if (state === "dead") {
      deps.logger.error("study_notebook_dead_letter", fields);
    } else if (state === "lease_lost") {
      deps.logger.warn("study_notebook_lease_lost", fields);
    } else {
      deps.logger.info("study_notebook_job", fields);
    }
    return state;
  }

  return {
    workerId,
    process,
    /** Claims up to [limit] jobs and writes them together; the number. */
    async runOnce(limit = deps.concurrency): Promise<number> {
      const jobs = await deps.queue.claim(workerId, limit);
      await Promise.all(jobs.map((job) => process(job)));
      return jobs.length;
    },
  };
}

/**
 * Polls the queue every [intervalMs], keeping up to `concurrency` notebooks
 * being written. On close it stops claiming and waits a little for the ones
 * in hand; any still unfinished are taken up again when their lease lapses.
 */
export function startNotebookGeneration(
  deps: NotebookGenerationDeps,
  intervalMs: number,
  options: { backlogLogIntervalMs?: number; closeWaitMs?: number } = {},
) {
  const processor = createNotebookGenerationProcessor(deps);
  const inFlight = new Set<Promise<unknown>>();
  let closed = false;
  let claiming = false;
  let lastBacklogAt = 0;
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
            deps.logger.error("study_notebook_job_failed", {
              error_name: error instanceof Error ? error.name : "unknown",
            });
          }).finally(() => inFlight.delete(work));
          inFlight.add(work);
        }
      }
      if (Date.now() - lastBacklogAt >= backlogEvery) {
        lastBacklogAt = Date.now();
        const backlog = await deps.queue.backlog();
        deps.logger.info("notebook_backlog", {
          pending: backlog["pending"] ?? 0,
          processing: backlog["processing"] ?? 0,
          dead_letter: backlog["deadLetters"] ?? 0,
          oldest_pending_seconds: backlog["oldestPendingSeconds"] ?? 0,
          in_flight: inFlight.size,
        });
      }
    } catch (error) {
      deps.logger.error("study_notebook_poll_failed", {
        error_name: error instanceof Error ? error.name : "unknown",
      });
    } finally {
      claiming = false;
    }
  };

  const timer = setInterval(() => void tick(), intervalMs);
  void tick();
  deps.logger.info("worker_ready", {
    queue: "study-notebooks",
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
