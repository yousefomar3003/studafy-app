/**
 * Job guards shared by OPS-061 processors: final-attempt detection (the
 * poison boundary — after this no BullMQ retry will run, so the durable
 * dead_letter must be recorded) and bounded error-code normalization
 * (§10.654: "normalized reason … redacted diagnostics"). Error messages are
 * never logged by callers; only the code is.
 */
import type { Job } from "bullmq";

export function isFinalAttempt(job: Job): boolean {
  const attempts = job.opts.attempts ?? 1;
  return job.attemptsMade + 1 >= attempts;
}

/**
 * Normalizes an arbitrary failure into a bounded operator-facing code.
 * Domain processors usually map outcomes themselves (the database is the
 * classifier); this is the fallback for failures before a domain outcome
 * exists.
 */
export function normalizedErrorCode(error: unknown): string {
  if (error instanceof Error) {
    if (error.name === "UnrecoverableError") return "JOB_UNRECOVERABLE";
    const message = error.message;
    if (/payload/i.test(message)) return "INVALID_JOB_PAYLOAD";
    if (/connection|unavailable|timeout/i.test(message)) {
      return "DEPENDENCY_UNAVAILABLE";
    }
    return "PROCESSING_FAILED";
  }
  return "PROCESSING_FAILED";
}

/**
 * Log fields for a failed poll or job: the error's class and, when it has
 * one, its code - a Postgres SQLSTATE (`42883`, `57014`), or a client code
 * from postgres.js or the runtime (`CONNECTION_CLOSED`, `ECONNRESET`). Only
 * a code that looks like one is kept, and never the message: a database
 * error's message and detail can quote the values of a row.
 */
export function errorFields(
  error: unknown,
): { error_name: string; error_code?: string } {
  const name = error instanceof Error ? error.name : "unknown";
  const code = typeof error === "object" && error !== null
    ? (error as { code?: unknown }).code
    : undefined;
  return typeof code === "string" && /^[A-Z0-9_]{2,40}$/.test(code)
    ? { error_name: name, error_code: code }
    : { error_name: name };
}

/** Deterministic BullMQ job id for one outbox row. */
export function outboxJobId(outboxId: number): string {
  return `outbox-${outboxId}`;
}

/** Parses the outbox id back out of a deterministic BullMQ job id. */
export function outboxIdFromJobId(jobId: string): number | null {
  const match = /^outbox-(\d+)$/.exec(jobId);
  return match ? Number(match[1]) : null;
}
