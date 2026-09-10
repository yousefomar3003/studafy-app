import type { Logger } from "@studafy/observability";
import type { Processor } from "bullmq";

/**
 * Domain-free lifecycle proof job. Phase 4+ replaces this with real job
 * processors; until then the queue exists only to prove BullMQ semantics
 * (enqueue, process, drain, graceful close) against the pinned versions.
 */
export function createSmokeProcessor(logger: Logger): Processor {
  return async (job) => {
    logger.info("job_processed", {
      queue: "smoke",
      job_id: job.id,
      attempt: job.attemptsMade + 1,
    });
    return { ok: true, job_id: job.id ?? null };
  };
}
