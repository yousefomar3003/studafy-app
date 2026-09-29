import { type Context, Hono } from "hono";
import { v1Route } from "@studafy/contracts";
import type {
  PrivateFileStorage,
  StudyAssistant,
  StudyImage,
  StudyReference,
  StudyTurn,
} from "@studafy/infrastructure";
import { sha256Hex } from "@studafy/infrastructure";
import type { NotebookRepository } from "../study/notebookRoutes";
import {
  CHARS_PER_TOKEN,
  type ChatMemoryBudgets,
  chatMemoryTokens,
  fitChatMemory,
} from "@studafy/domain";
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
  /** How much of a chat is remembered, by plan, inside the model's window. */
  chatMemory: ChatMemoryBudgets;
  /** Class material and photos (2026-09-29). Without these, or with the
   * lesson-tools switch off, a question carrying them is refused. */
  notebooks?: NotebookRepository;
  storage?: PrivateFileStorage | null;
  lessonToolsEnabled?: boolean;
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
    validateRouteInput(route),
    requirePermission(authorization, "study_assistant.ask"),
    async (c: Context<AuthorizationEnv>) => {
      const body = validatedBody<{
        question: string;
        history?: StudyTurn[];
        references?: { kind: "lesson" | "note"; id: string }[];
        attachmentFileIds?: string[];
      }>(c);
      // A question belongs to the student, not to a school.
      const context = { ...membershipDbContext(c), schoolId: null };

      // The chat is remembered up to the plan's budget, newest turns first,
      // whatever the app sent - it is the server's cost, and its window.
      const plan = await deps.repository.usage(context, "summary", {});
      const planName = String(plan["plan"] ?? "free");
      const budget = chatMemoryTokens(deps.chatMemory, planName);
      const asked = body.references ?? [];
      const photoIds = body.attachmentFileIds ?? [];

      // Class material and photos reach the provider: only behind the
      // lesson-tools switch (ADR-0029), and photos only on Studafy Plus.
      if (asked.length > 0 || photoIds.length > 0) {
        if (!deps.lessonToolsEnabled || !deps.notebooks) {
          return problem(c, "AI_FEATURE_DISABLED", 409);
        }
      }
      if (photoIds.length > 0) {
        if (planName !== "plus" && planName !== "max") {
          return problem(c, "PLAN_REQUIRED", 403);
        }
        if (!deps.storage) return problem(c, "AI_FEATURE_DISABLED", 409);
      }

      const images: StudyImage[] = [];
      for (const fileId of photoIds) {
        const found = await deps.notebooks!.call(
          context,
          "assistantAttachment",
          fileId,
        );
        if (found["outcome"] !== "ok") return problem(c, "NOT_FOUND", 404);
        const object = found["object"] as Record<string, unknown> | null;
        if (!object?.["rootClean"]) return problem(c, "PHOTO_NOT_READY", 409);
        let bytes: Uint8Array;
        try {
          bytes = (await deps.storage!.openObject(
            String(object["bucket"]),
            String(object["objectKey"]),
          )).bytes;
        } catch {
          return problem(c, "SERVICE_UNAVAILABLE", 503);
        }
        // Only the exact bytes the scan cleared are ever sent anywhere.
        if (await sha256Hex(bytes) !== object["storedSha256"]) {
          return problem(c, "SERVICE_UNAVAILABLE", 503);
        }
        images.push({ bytes, mediaType: String(object["mediaType"]) });
      }

      // The material the student may read, fitted to the plan's memory
      // first; the chat gets what is left.
      let references: StudyReference[] = [];
      if (asked.length > 0) {
        const found = await deps.notebooks!.call(context, "references", null, {
          items: asked,
        });
        const items = (found["items"] ?? []) as {
          title: string;
          text: string;
        }[];
        const share = items.length === 0
          ? 0
          : Math.floor(budget * CHARS_PER_TOKEN / items.length);
        references = items.map((item) => ({
          title: String(item.title),
          text: String(item.text).slice(0, share),
        }));
      }
      const referenceChars = references.reduce(
        (n, reference) => n + reference.text.length,
        0,
      );
      const history = fitChatMemory(
        body.history ?? [],
        Math.max(0, budget - Math.ceil(referenceChars / CHARS_PER_TOKEN)),
      );
      const historyChars = history.reduce((n, turn) => n + turn.text.length, 0);
      const hold = holdFor(deps.prices, "ask", historyChars + referenceChars) +
        images.length * holdFor(deps.prices, "whiteboard");
      let reply;
      try {
        reply = await meter.run(
          context,
          "ask",
          hold,
          () =>
            deps.assistant.ask(body.question, history, { references, images }),
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
