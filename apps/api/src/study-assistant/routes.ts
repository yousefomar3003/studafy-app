import { type Context, Hono } from "hono";
import { v1Route } from "@studafy/contracts";
import type {
  PrivateFileStorage,
  StudyAssistant,
  StudyImage,
  StudyTurn,
} from "@studafy/infrastructure";
import { prepareImage, sha256Hex } from "@studafy/infrastructure";
import type { NotebookRepository } from "../study/notebookRoutes";
import { readInlineImage } from "../study/inlineImage";
import {
  type ChatMemoryBudgets,
  chatMemoryTokens,
  fitChatMemory,
  GROUNDED_RULES,
  type MaterialPassage,
  resolveCitations,
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
  allowanceOf,
  holdFor,
  type ModelPrices,
  OUTPUT_TOKENS,
} from "../study/metering";
import type { MaterialRepository } from "../study/material";
import {
  gatherScope,
  type MaterialRef,
  type ResolvedScope,
  resolveSelection,
  scopeJson,
  selectionProblem,
} from "../study/selection";
import { outcomeProblem } from "../platform/outcomes";
import { membershipDbContext } from "../platform/dbContext";
import {
  type AiAccessRepository,
  nameRedactedAssistant,
  requireAiAccess,
} from "../study/aiAccess";

export interface StudyAssistantDependencies {
  assistant: Pick<StudyAssistant, "ask">;
  /** Who may use AI, and the names kept out of it (ADR-0043). */
  aiAccess: AiAccessRepository;
  /** The AI ledger: the token allowance, and the dollar cap beneath it. */
  repository: StudyRepository;
  prices: ModelPrices;
  /** How much of a chat is remembered, by plan, inside the model's window. */
  chatMemory: ChatMemoryBudgets;
  /** Notes and photos (2026-09-29). Without these, or with the lesson-tools
   * switch off, a question carrying them is refused. */
  notebooks?: NotebookRepository;
  /** Lessons, their files and links (ADR-0037). */
  material?: MaterialRepository;
  storage?: PrivateFileStorage | null;
  lessonToolsEnabled?: boolean;
}

/**
 * How much class material goes with one question, by plan, in characters.
 * More material answers more fully and costs more tokens; these keep a
 * question on Free at about 3-4k tokens (ADR-0037).
 */
export const MATERIAL_CHARS = { free: 6_000, plus: 16_000, max: 24_000 };

/**
 * The study assistant's one route.
 *
 * Hand-written rather than catalogue-built because it orchestrates a
 * provider call between database steps. What it does have is the AI ledger:
 * the question is held at its worst-case tokens against the student's
 * allowance before the provider is called, so a spent allowance costs
 * nothing, and settled to what the provider reported.
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
    // Students in a class with a current AI consent only (ADR-0043).
    requireAiAccess(deps.aiAccess),
    async (c: Context<AuthorizationEnv>) => {
      const body = validatedBody<{
        question: string;
        history?: StudyTurn[];
        references?: MaterialRef[];
        skipUnavailable?: boolean;
        attachmentFileIds?: string[];
        images?: { mediaType: string; data: string }[];
        language?: "ar" | "en";
        requestId?: string;
      }>(c);
      // A question belongs to the student, not to a school.
      const context = { ...membershipDbContext(c), schoolId: null };

      const plan = await deps.repository.usage(context, "summary", {});
      const planName = String(plan["plan"] ?? "free") as
        | "free"
        | "plus"
        | "max";
      const references = body.references ?? [];
      const photoIds = body.attachmentFileIds ?? [];
      const inline = body.images ?? [];

      // Class material and photos reach the provider: only behind the
      // lesson-tools switch (ADR-0029), and photos only on Studafy Plus.
      if (references.length > 0 || photoIds.length > 0 || inline.length > 0) {
        if (!deps.lessonToolsEnabled || !deps.notebooks || !deps.material) {
          return problem(c, "AI_FEATURE_DISABLED", 409);
        }
      }
      if (photoIds.length > 0 || inline.length > 0) {
        if (planName !== "plus" && planName !== "max") {
          return problem(c, "PLAN_REQUIRED", 403);
        }
      }
      if (photoIds.length > 0 && !deps.storage) {
        return problem(c, "AI_FEATURE_DISABLED", 409);
      }

      const images: StudyImage[] = [];
      // Photos sent with the question by a student with no school to upload
      // into (ADR-0045): checked and drawn again, never stored.
      for (const image of inline) {
        const read = await readInlineImage(image);
        if (!read.ok) return problem(c, read.code, read.status);
        images.push({ bytes: read.bytes, mediaType: read.mediaType });
      }
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
        // At most 1,600 px on its longest side: a full phone photo costs far
        // more tokens, takes longer, and reads no better.
        try {
          images.push({
            bytes: await prepareImage(bytes),
            mediaType: "image/jpeg",
          });
        } catch {
          images.push({ bytes, mediaType: String(object["mediaType"]) });
        }
      }

      // The material: lessons and their files and links, chosen whole or
      // one by one, and the student's own notes. What they may read is
      // decided in SQL on this request.
      const budget = MATERIAL_CHARS[planName] ?? MATERIAL_CHARS.free;
      const history = body.history ?? [];
      const lastStudentTurn = [...history].reverse()
        .find((turn) => turn.role === "student")?.text;
      // Exactly what was chosen, checked on this request: a lesson they
      // cannot see, or a file not on its lesson, refuses the question; a
      // chosen file that cannot be read is named, never dropped silently.
      let resolved: ResolvedScope | null = null;
      if (references.length > 0 && deps.material) {
        const selection = await resolveSelection(
          deps.material,
          context,
          references,
          { skipUnavailable: body.skipUnavailable === true, allowNotes: true },
        );
        if (!selection.ok) return selectionProblem(c, selection);
        resolved = selection.scope;
      }
      const gathered = deps.material && resolved && resolved.lessons.length > 0
        ? await gatherScope(deps.material, context, resolved, {
          question: body.question,
          ...(lastStudentTurn ? { followUp: lastStudentTurn } : {}),
          budgetChars: budget,
        })
        : null;
      const passages: MaterialPassage[] = [...(gathered?.passages ?? [])];

      const notes = references.filter((r) => r.kind === "note");
      if (notes.length > 0 && deps.notebooks) {
        const found = await deps.notebooks.call(context, "references", null, {
          items: notes.map((n) => ({ kind: "note", id: n.id })),
        });
        const items = (found["items"] ?? []) as {
          title: string;
          text: string;
        }[];
        const share = Math.floor(budget / 3 / Math.max(1, items.length));
        for (const item of items) {
          passages.push({
            sourceKind: "note",
            name: String(item.title),
            text: String(item.text).slice(0, share),
          });
        }
      }

      // The chat is remembered up to the plan's budget, newest turns first,
      // whatever the app sent - it is the server's cost, and its window.
      const fitted = fitChatMemory(
        history,
        chatMemoryTokens(deps.chatMemory, planName),
      );
      const grounded = passages.length > 0 ||
        (gathered?.unreadable.length ?? 0) > 0;
      const inputChars = body.question.length +
        fitted.reduce((n, turn) => n + turn.text.length, 0) +
        passages.reduce((n, p) => n + p.text.length + p.name.length + 60, 0) +
        (grounded ? GROUNDED_RULES.length : 0) +
        (gathered?.unreadable ?? []).reduce(
          (n, u) => n + u.name.length + 60,
          0,
        );
      const hold = holdFor(
        deps.prices,
        inputChars,
        grounded || images.length > 0 ? OUTPUT_TOKENS.long : OUTPUT_TOKENS.ask,
        images.length,
      );

      let reply;
      try {
        // The names of the people the student can see are replaced in
        // everything sent, before the call (ADR-0043, DPIA D1).
        const assistant = await nameRedactedAssistant(
          deps.aiAccess,
          context,
          deps.assistant,
        );
        reply = await meter.run(
          context,
          "ask",
          hold,
          () =>
            assistant.ask(body.question, fitted, {
              passages,
              unreadable: gathered?.unreadable ?? [],
              images,
              learner: {
                grade: gathered?.grade ?? null,
                language: body.language ?? null,
              },
            }),
          body.requestId ? `ask:${body.requestId}` : undefined,
        );
      } catch (error) {
        // The question and the answer are both deliberately absent from this
        // log line: one is a child's words, the other is what a third party
        // said back, and neither belongs in an operational log.
        authorization.logger?.warn("study_assistant_failed", {
          error_kind: error instanceof StudyAssistantError
            ? error.kind
            : "unknown",
          provider_status: error instanceof StudyAssistantError
            ? error.status ?? null
            : null,
          with_photo: images.length > 0,
        });
        return problem(c, "SERVICE_UNAVAILABLE", 503);
      }
      if (!reply.ok) return outcomeProblem(c, reply.outcome, AI_REFUSALS);

      const { answer, citations } = resolveCitations(
        reply.value.answer,
        passages,
      );
      const allowance = reply.allowance ??
        allowanceOf(
          (await deps.repository.usage(context, "summary", {}))["allowance"],
        );
      const parsed = route.response.safeParse({
        answer: answer || reply.value.answer,
        citations,
        unreadable: (gathered?.unreadable ?? []).map((u) => ({
          name: u.name.slice(0, 300),
          reason: u.code.slice(0, 60),
        })),
        allowance,
        scope: resolved && resolved.lessons.length > 0
          ? scopeJson(resolved)
          : null,
      });
      return parsed.success
        ? c.json(parsed.data)
        : problem(c, "INTERNAL_ERROR", 500);
    },
  );

  return routes;
}
