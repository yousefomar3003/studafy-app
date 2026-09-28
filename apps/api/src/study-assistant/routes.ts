import { type Context, Hono } from "hono";
import { v1Route } from "@studafy/contracts";
import type { StudyAssistant } from "@studafy/infrastructure";
import { StudyAssistantError } from "@studafy/infrastructure";
import type { AuthorizationDependencies } from "../authorization/middleware";
import type { AuthorizationEnv } from "../authorization/middleware";
import { requirePermission } from "../authorization/middleware";
import { validatedBody, validateRouteInput } from "../platform/validation";
import { problem } from "../platform/errors";
import type { StudyRepository } from "../study/repository";
import {
  AI_REFUSALS,
  AiMeter,
  holdFor,
  type ModelPrices,
} from "../study/metering";
import { outcomeProblem } from "../platform/outcomes";
import { membershipDbContext } from "../platform/dbContext";

export interface StudyAssistantDependencies {
  assistant: Pick<StudyAssistant, "ask">;
  /** The AI cost ledger: daily question count and, on paid plans, the cap. */
  repository: StudyRepository;
  prices: ModelPrices;
}

/**
 * The study assistant's one route.
 *
 * Hand-written rather than built from the catalogue helper because it is not
 * a database command: there is no idempotency record, no tenant and no SQL
 * dispatcher behind it. What it does have is the AI cost ledger: the
 * question is counted against today's allowance (10 on the free plan) and,
 * on Studafy Plus / Max, held against the monthly cap before the provider is
 * called, so a spent allowance costs nothing.
 */
export function createStudyAssistantRoutes(
  deps: StudyAssistantDependencies,
  authorization: AuthorizationDependencies,
): Hono<AuthorizationEnv> {
  const routes = new Hono<AuthorizationEnv>();
  const route = v1Route("askStudyAssistant");
  const meter = new AiMeter(deps.repository, deps.prices);

  routes.post(
    "/v1/study-assistant/ask",
    validateRouteInput(route) as never,
    requirePermission(authorization, "study_assistant.ask"),
    async (c: Context<AuthorizationEnv>) => {
      const body = validatedBody<{ question: string }>(c);

      // A question belongs to the student, not to a school.
      const context = { ...membershipDbContext(c), schoolId: null };
      let reply;
      try {
        reply = await meter.run(
          context,
          "ask",
          holdFor(deps.prices, "ask"),
          () => deps.assistant.ask(body.question),
        );
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
      if (!reply.ok) return outcomeProblem(c, reply.outcome, AI_REFUSALS);

      const summary = await deps.repository.usage(context, "summary", {});
      const remaining = Math.max(
        0,
        Number(summary["askPerDay"] ?? 0) - Number(summary["askToday"] ?? 0),
      );
      return c.json({ answer: reply.value.answer, remainingToday: remaining });
    },
  );

  return routes;
}
