import { type Context, Hono } from "hono";
import { v1Route } from "@studafy/contracts";
import type { StudyAssistant } from "@studafy/infrastructure";
import { StudyAssistantError } from "@studafy/infrastructure";
import type { AuthorizationDependencies } from "../authorization/middleware";
import type { AuthorizationEnv } from "../authorization/middleware";
import { requirePermission } from "../authorization/middleware";
import { validateRouteInput } from "../platform/validation";
import { problem } from "../platform/errors";

export interface StudyAssistantQuota {
  /**
   * Counts one question against today's allowance.
   *
   * Returns how many remain, or null when the allowance is spent. A daily cap
   * per account is the spend ceiling as much as the fairness rule: the
   * provider bills per call, and an unbounded endpoint is an unbounded bill.
   */
  consume(subject: string): Promise<number | null>;
}

export interface StudyAssistantDependencies {
  assistant: StudyAssistant;
  quota: StudyAssistantQuota;
}

/**
 * The study assistant's one route.
 *
 * Hand-written rather than built from the catalogue helper because it is not
 * a database command: there is no idempotency record, no tenant and no SQL
 * dispatcher behind it. What it does have is a quota, checked before the
 * provider is called so a spent allowance costs nothing.
 */
export function createStudyAssistantRoutes(
  deps: StudyAssistantDependencies,
  authorization: AuthorizationDependencies,
): Hono<AuthorizationEnv> {
  const routes = new Hono<AuthorizationEnv>();
  const route = v1Route("askStudyAssistant");

  routes.post(
    "/v1/study-assistant/ask",
    validateRouteInput(route) as never,
    requirePermission(authorization, "study_assistant.ask"),
    async (c: Context<AuthorizationEnv>) => {
      const actor = c.get("actor");
      // Read straight from the context rather than through validatedBody(),
      // whose Context<PlatformEnv> parameter is invariant in Hono and so does
      // not accept this route's authorization-aware environment. The schema
      // has already validated it by the time this runs.
      const body = c.get("validatedBody") as { question: string };

      const remaining = await deps.quota.consume(actor.token.subject);
      if (remaining === null) return problem(c, "RATE_LIMITED", 429);

      try {
        const reply = await deps.assistant.ask(body.question);
        return c.json({ answer: reply.answer, remainingToday: remaining });
      } catch (error) {
        // The question and the answer are both deliberately absent from this
        // log line: one is a child's words, the other is what a third party
        // said back, and neither belongs in an operational log.
        authorization.logger?.warn("study_assistant_failed", {
          error_kind: error instanceof StudyAssistantError
            ? error.kind
            : "unknown",
        });
        return problem(c, "SERVICE_UNAVAILABLE", 503);
      }
    },
  );

  return routes;
}
