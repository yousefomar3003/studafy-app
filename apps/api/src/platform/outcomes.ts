import type { Context, Env } from "hono";
import type { Logger } from "@studafy/observability";
import type { ErrorCodeType } from "@studafy/contracts";
import { problem } from "./errors";

/** The HTTP statuses a refusal from the database may map to. */
export type RefusalStatus = Parameters<typeof problem>[2];

/** One module's database outcomes and the problem each becomes. */
export type OutcomeTable = Readonly<
  Record<string, readonly [ErrorCodeType, RefusalStatus]>
>;

/**
 * Outcomes every SQL dispatcher shares. A module's own table is merged over
 * these, so it only lists what is particular to it.
 */
export const COMMON_OUTCOMES: OutcomeTable = {
  not_found: ["NOT_FOUND", 404],
  forbidden: ["FORBIDDEN", 403],
  // A request the database understood and rejected on its own rules.
  invalid: ["INVALID_REQUEST", 400],
  invalid_state: ["INVALID_STATE", 409],
  version_conflict: ["VERSION_CONFLICT", 409],
  window_closed: ["WINDOW_CLOSED", 409],
  // A bulk command refused row by row; nothing in it was written.
  grade_entries_invalid: ["GRADE_ENTRIES_INVALID", 422],
  reason_required: ["REASON_REQUIRED", 400],
  attendance_locked: ["ATTENDANCE_LOCKED", 409],
  graded_locked: ["SUBMISSION_LOCKED", 409],
  file_not_clean: ["FILE_NOT_CLEAN", 409],
  // A file or link refused for attaching; the rows name each one.
  attachment_refused: ["ATTACHMENT_REFUSED", 422],
};

/**
 * A request path as the SQL names a refused attachment: body field names
 * and list indexes only (`attachmentFileIds.2`, `questions.1.links.0`).
 */
const REQUEST_PATH = /^[A-Za-z]{1,40}(\.([0-9]{1,3}|[A-Za-z]{1,40})){0,4}$/;

/**
 * The rows a command refused, as problem `errors`: the row's id (a bulk
 * command) or the request path of a refused attachment as the path, and a
 * fixed reason code. Ids and paths the caller sent and codes from a fixed
 * SQL vocabulary only - never account data - so the list is safe to return
 * and to log.
 */
export function rowErrors(rows: unknown): { path: string; code: string }[] {
  if (!Array.isArray(rows)) return [];
  const errors: { path: string; code: string }[] = [];
  for (const row of rows) {
    if (typeof row !== "object" || row === null) continue;
    const record = row as Record<string, unknown>;
    const reason = record["reason"];
    const path = record["path"];
    if (typeof path === "string") {
      if (
        typeof reason === "string" && REQUEST_PATH.test(path) &&
        /^[a-z_]{1,64}$/.test(reason)
      ) {
        errors.push({ path, code: reason });
        if (errors.length === 16) break;
      }
      continue;
    }
    const id = record["gradeResultId"] ?? record["studentId"];
    if (typeof id !== "string" || typeof reason !== "string") continue;
    if (!/^[0-9a-f-]{36}$/i.test(id) || !/^[a-z_]{1,64}$/.test(reason)) {
      continue;
    }
    const kind = record["gradeResultId"] ? "gradeResults" : "students";
    errors.push({ path: `${kind}/${id}`, code: reason });
    if (errors.length === 16) break;
  }
  return errors;
}

/**
 * Turns a database refusal into a problem response.
 *
 * An outcome missing from the table is a gap on the server, not a malformed
 * request, so it is logged and answered as a 500 - never guessed at as a
 * client error. The outcome is a fixed vocabulary from SQL, never account
 * data, so it is safe to log.
 */
export function outcomeProblem<E extends Env>(
  c: Context<E>,
  outcome: string,
  table: OutcomeTable,
  logger?: Logger,
  rows?: unknown,
): Response {
  const entry = table[outcome] ?? COMMON_OUTCOMES[outcome];
  if (entry) {
    const errors = rowErrors(rows);
    return problem(c, entry[0], entry[1], errors.length ? { errors } : {});
  }
  const vars = c.var as { requestId?: unknown; operationId?: unknown };
  logger?.warn("outcome_unmapped", {
    request_id: vars.requestId,
    operation_id: vars.operationId,
    outcome,
  });
  return problem(c, "INTERNAL_ERROR", 500);
}
