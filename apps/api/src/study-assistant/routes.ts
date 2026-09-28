import { type Context, Hono } from "hono";
import { v1Route } from "@studafy/contracts";
import type { StudyAssistant } from "@studafy/infrastructure";
import { StudyAssistantError } from "@studafy/infrastructure";
import type { AuthorizationDependencies } from "../authorization/middleware";
import type { AuthorizationEnv } from "../authorization/middleware";
import { requirePermission } from "../authorization/middleware";
import { validateRouteInput } from "../platform/validation";
import { problem } from "../platform/errors";
import type { StudyRepository } from "../study/repository";
import { costMicroUsd, holdFor, type ModelPrices } from "../study/routes";

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

      const context = {
        subject: actor.token.subject,
        schoolId: null,
        requestId: c.get("requestId"),
        aal2: actor.aal2,
      };
      const hold = holdFor(deps.prices, "ask");
      const reserved = await deps.repository.usage(context, "reserve", {
        feature: "ask",
        estimateMicroUsd: hold,
      });
      if (reserved["outcome"] === "daily_limit") {
        return problem(c, "AI_DAILY_LIMIT", 429);
      }
      if (reserved["outcome"] === "monthly_cap") {
        return problem(c, "AI_ALLOWANCE_USED", 429);
      }
      if (reserved["outcome"] !== "ok") return problem(c, "FORBIDDEN", 403);
      const usageId = reserved["usageId"];

      try {
        const reply = await deps.assistant.ask(body.question);
        const usage = reply.usage;
        await deps.repository.usage(context, "settle", {
          usageId,
          costMicroUsd: usage
            ? costMicroUsd(deps.prices, usage.inputTokens, usage.outputTokens)
            : hold,
          inputTokens: usage?.inputTokens ?? null,
          outputTokens: usage?.outputTokens ?? null,
          model: usage?.model ?? null,
        });
        const summary = await deps.repository.usage(context, "summary", {});
        const remaining = Math.max(
          0,
          Number(summary["askPerDay"] ?? 0) - Number(summary["askToday"] ?? 0),
        );
        return c.json({ answer: reply.answer, remainingToday: remaining });
      } catch (error) {
        await deps.repository.usage(context, "release", { usageId });
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
