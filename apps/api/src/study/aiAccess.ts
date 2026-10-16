import type { Context, MiddlewareHandler } from "hono";
import type { KnownName } from "@studafy/domain";
import {
  knownNamesOf,
  redactingNames,
  type StudyAssistant,
} from "@studafy/infrastructure";
import type { Sql } from "@studafy/database";
import type { AuthorizationEnv } from "../authorization/middleware";
import { problem } from "../platform/errors";
import type { OutcomeTable } from "../platform/outcomes";
import {
  type RequestDbContext,
  withRequestContext,
} from "../platform/dbContext";

/**
 * Who may use the AI study tools, and the names kept out of what they send
 * (ADR-0043; DPIA D1-D4).
 *
 * The database decides (`private.ai_access`): a student account with at
 * least one active class enrollment, managed child accounts included, that
 * holds a current AI consent. Every AI route asks it before doing any work,
 * and the AI ledger asks it again before holding a single token, so no
 * route can reach the provider without it.
 */

export type AiAccess =
  | "ok"
  | "not_student"
  | "no_class"
  | "consent_required"
  | "guardian_consent_required";

export type AiConsentOperation =
  | "status"
  | "names"
  | "give"
  | "withdraw"
  | "child_status"
  | "child_give"
  | "child_withdraw";

/** The SQL behind AI access and consent (`private.api057_ai_consent`). */
export interface AiAccessRepository {
  call(
    context: RequestDbContext,
    operation: AiConsentOperation,
    input: Record<string, unknown>,
  ): Promise<Record<string, unknown>>;
}

export class PostgresAiAccessRepository implements AiAccessRepository {
  constructor(readonly sql: Sql) {}

  async call(
    context: RequestDbContext,
    operation: AiConsentOperation,
    input: Record<string, unknown>,
  ): Promise<Record<string, unknown>> {
    return await withRequestContext(this.sql, context, async (tx) => {
      const rows = await tx<{ result: Record<string, unknown> }[]>`
        select private.api057_ai_consent(${operation}, ${
        tx.json(input as never)
      }) as result
      `;
      return rows[0]?.result ?? { outcome: "invalid" };
    });
  }
}

/** Why an account may not use the AI study tools, as a problem. */
export const AI_ACCESS_REFUSALS: OutcomeTable = {
  not_student: ["AI_STUDENTS_ONLY", 403],
  no_class: ["AI_STUDENTS_ONLY", 403],
  consent_required: ["AI_CONSENT_REQUIRED", 403],
  guardian_consent_required: ["AI_GUARDIAN_CONSENT_REQUIRED", 403],
};

/** The actor's own context: AI access belongs to a person, not a school. */
export function actorDbContext(c: Context<AuthorizationEnv>): RequestDbContext {
  return {
    subject: c.get("actor").token.subject,
    schoolId: null,
    requestId: c.get("requestId"),
    aal2: c.get("actor").aal2,
  };
}

/**
 * Refuses an AI route to anyone `private.ai_access` does not say "ok" for,
 * before the route reads material, holds tokens or calls the provider.
 * Mounted after the route's permission, so the permission still decides
 * what the actor may see; this decides whether they may use AI on it.
 */
export function requireAiAccess(
  repository: AiAccessRepository,
): MiddlewareHandler<AuthorizationEnv> {
  return async (c, next) => {
    let result: Record<string, unknown>;
    try {
      result = await repository.call(actorDbContext(c), "status", {});
    } catch {
      return problem(c, "SERVICE_UNAVAILABLE", 503);
    }
    if (result["outcome"] !== "ok") return problem(c, "FORBIDDEN", 403);
    const access = String(result["access"]);
    if (access === "ok") {
      await next();
      return;
    }
    const refusal = AI_ACCESS_REFUSALS[access];
    return refusal
      ? problem(c, refusal[0], refusal[1])
      : problem(c, "FORBIDDEN", 403);
  };
}

/** The names the student can see, as the database lists them. Throws when
 * they cannot be read: better no call than one that might carry a name. */
export async function knownNames(
  repository: AiAccessRepository,
  context: RequestDbContext,
): Promise<KnownName[]> {
  return knownNamesOf(await repository.call(context, "names", {}));
}

/**
 * [assistant] with the student's known names replaced in everything it
 * sends (DPIA D1). Every route builds this for the request before it calls
 * the provider; a failure to read the names fails the request.
 */
export async function nameRedactedAssistant<
  A extends Partial<StudyAssistant>,
>(
  repository: AiAccessRepository,
  context: RequestDbContext,
  assistant: A,
): Promise<A> {
  return redactingNames(assistant, await knownNames(repository, context));
}
