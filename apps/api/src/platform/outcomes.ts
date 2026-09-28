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
};

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
): Response {
  const entry = table[outcome] ?? COMMON_OUTCOMES[outcome];
  if (entry) return problem(c, entry[0], entry[1]);
  const vars = c.var as { requestId?: unknown; operationId?: unknown };
  logger?.warn("outcome_unmapped", {
    request_id: vars.requestId,
    operation_id: vars.operationId,
    outcome,
  });
  return problem(c, "INTERNAL_ERROR", 500);
}
