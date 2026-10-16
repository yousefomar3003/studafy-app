import { type Context, Hono } from "hono";
import { v1Route } from "@studafy/contracts";
import type { Sql } from "@studafy/database";
import {
  type StudyAssistant,
  StudyAssistantError,
} from "@studafy/infrastructure";
import type {
  AuthorizationDependencies,
  AuthorizationEnv,
} from "../authorization/middleware";
import { requirePermission } from "../authorization/middleware";
import type { IdempotencyDependencies } from "../platform/idempotency";
import { committedJson, idempotency } from "../platform/idempotency";
import { problem } from "../platform/errors";
import {
  routeParam,
  validatedBody,
  validatedParams,
  validateRouteInput,
} from "../platform/validation";
import {
  type RequestDbContext,
  resolvedSchoolDbContext,
  withRequestContext,
} from "../platform/dbContext";
import { outcomeProblem } from "../platform/outcomes";
import type { StudyRepository } from "./repository";
import {
  AI_REFUSALS,
  AiMeter,
  holdFor,
  type ModelPrices,
  OUTPUT_TOKENS,
} from "./metering";
import { type MaterialRepository, materialText } from "./material";
import {
  gatherScope,
  type MaterialRef,
  type ResolvedScope,
  resolveSelection,
  scopeFingerprint,
  scopeJson,
  selectionProblem,
} from "./selection";
import { STUDY_SET_MATERIAL_CHARS } from "./routes";
import {
  type AiAccessRepository,
  nameRedactedAssistant,
  requireAiAccess,
} from "./aiAccess";

/**
 * Quizzes, flashcards and study notes from exactly the material a student
 * chose (2026-10-07, ADR-0039).
 *
 * The selection is resolved on each request (see `selection.ts`). A result
 * is kept against a fingerprint of the selection - the lesson versions,
 * whether each one's text is in, and the files read - so choosing the same
 * material again opens it for free, for anyone who can see every lesson in
 * it. Nothing is made from more, or less, than was chosen.
 */

export interface MaterialOutputRepository {
  call(
    context: RequestDbContext,
    operation: "get" | "put",
    input: Record<string, unknown>,
  ): Promise<Record<string, unknown>>;
}

export class PostgresMaterialOutputRepository
  implements MaterialOutputRepository {
  constructor(readonly sql: Sql) {}

  async call(
    context: RequestDbContext,
    operation: "get" | "put",
    input: Record<string, unknown>,
  ): Promise<Record<string, unknown>> {
    return await withRequestContext(this.sql, context, async (tx) => {
      const rows = await tx<{ result: Record<string, unknown> }[]>`
        select private.api056_material_outputs(${operation}, ${
        tx.json(input as never)
      }) as result
      `;
      return rows[0]?.result ?? { outcome: "invalid" };
    });
  }
}

export interface SelectionRoutesDependencies {
  material: MaterialRepository;
  outputs: MaterialOutputRepository;
  repository: StudyRepository;
  prices: ModelPrices;
  assistant: StudyAssistant | null;
  lessonToolsEnabled: boolean;
  /** Who may use AI, and the names kept out of it (ADR-0043). */
  aiAccess: AiAccessRepository;
}

/** The title of something made from [scope]: its lesson, or its lessons. */
export function scopeTitle(scope: ResolvedScope): string {
  return scope.lessons.map((l) => l.title).join(" · ").slice(0, 200) ||
    "Notes";
}

/**
 * The line under notes saying what they were made from, in the app's
 * language: each lesson, with "lesson text" or its files, and anything
 * left out.
 */
export function madeFromLine(
  scope: ResolvedScope,
  language: "ar" | "en",
): string {
  const words = language === "ar"
    ? {
      from: "مصنوع من",
      text: "نص الدرس",
      all: "الدرس كاملًا",
      left: "لم يُستخدم",
      sep: "؛ ",
      list: "، ",
    }
    : {
      from: "Made from",
      text: "lesson text",
      all: "whole lesson",
      left: "Left out",
      sep: "; ",
      list: ", ",
    };
  const lessons = scope.lessons.map((l) => {
    const parts = l.wholeLesson ? [words.all] : [
      ...(l.includeText ? [words.text] : []),
      ...l.kept.map((s) => s.name),
    ];
    return `${l.title} (${parts.join(words.list)})`;
  });
  const lines = [`**${words.from}:** ${lessons.join(words.sep)}`];
  if (scope.skipped.length > 0) {
    lines.push(
      `**${words.left}:** ${scope.skipped.map((s) => s.name).join(words.list)}`,
    );
  }
  return `\n\n---\n${lines.join("\n\n")}`;
}

export function createSelectionRoutes(
  deps: SelectionRoutesDependencies,
  authorization: AuthorizationDependencies,
  idempotencyDependencies: IdempotencyDependencies,
): Hono<AuthorizationEnv> {
  const routes = new Hono<AuthorizationEnv>();
  const log = authorization.logger;
  const meter = new AiMeter(deps.repository, deps.prices);
  const refusal = (c: Context<AuthorizationEnv>, outcome: string) =>
    outcomeProblem(c, outcome, AI_REFUSALS, log);

  function providerFailure(
    c: Context<AuthorizationEnv>,
    feature: string,
    error: unknown,
  ): Response {
    // Neither the material nor the reply is logged.
    log?.warn("study_ai_failed", {
      feature,
      error_kind: error instanceof StudyAssistantError ? error.kind : "unknown",
      provider_status: error instanceof StudyAssistantError
        ? error.status ?? null
        : null,
    });
    return problem(c, "SERVICE_UNAVAILABLE", 503);
  }

  // -------------------------------------------------------------------------
  // A quiz or flashcards from the chosen material (Studafy Max).
  // -------------------------------------------------------------------------
  const setRoute = v1Route("generateSelectionStudySet");
  routes.post(
    "/v1/study-sets",
    validateRouteInput(setRoute),
    requirePermission(authorization, "material_set.generate"),
    requireAiAccess(deps.aiAccess),
    idempotency(idempotencyDependencies, setRoute.operationId, "required"),
    async (c) => {
      const assistant = deps.assistant;
      if (!assistant || !deps.lessonToolsEnabled) {
        return problem(c, "AI_FEATURE_DISABLED", 409);
      }
      const context = resolvedSchoolDbContext(c);
      const input = validatedBody<{
        kind: "quiz" | "flashcards";
        references: MaterialRef[];
        skipUnavailable?: boolean;
      }>(c);
      const selection = await resolveSelection(
        deps.material,
        context,
        input.references,
        { skipUnavailable: input.skipUnavailable === true },
      );
      if (!selection.ok) return selectionProblem(c, selection);
      const scope = selection.scope;
      const fingerprint = await scopeFingerprint(scope);
      const resourceIds = scope.lessons.map((l) => l.resourceId);

      const answer = (output: Record<string, unknown>) => {
        const parsed = setRoute.response.safeParse({
          id: output["id"],
          kind: input.kind,
          questions: input.kind === "quiz" ? output["items"] : null,
          cards: input.kind === "flashcards" ? output["items"] : null,
          scope: scopeJson(scope),
          createdAt: new Date(String(output["createdAt"])).toISOString(),
        });
        return parsed.success
          ? c.json(parsed.data, 201)
          : problem(c, "INTERNAL_ERROR", 500);
      };

      // Made before from exactly this material: free.
      const kept = await deps.outputs.call(context, "get", {
        kind: input.kind,
        fingerprint,
        resourceIds,
      });
      if (kept["outcome"] !== "ok") return refusal(c, String(kept["outcome"]));
      if (kept["output"]) {
        return answer(kept["output"] as Record<string, unknown>);
      }

      const gathered = await gatherScope(deps.material, context, scope, {
        question: "",
        budgetChars: STUDY_SET_MATERIAL_CHARS,
        mode: "coverage",
      });
      const text = materialText(gathered.passages);
      if (text.trim().length < 40) {
        return problem(c, "LESSON_HAS_NO_TEXT", 422);
      }
      let generated;
      try {
        // Names out of the material before it is sent (ADR-0043).
        const redacted = await nameRedactedAssistant(
          deps.aiAccess,
          context,
          assistant,
        );
        generated = await meter.run(
          context,
          input.kind,
          holdFor(deps.prices, text.length, OUTPUT_TOKENS.long),
          () => redacted.studySet(input.kind, scopeTitle(scope), text),
          `set:${input.kind}:${fingerprint.slice(0, 64)}`,
        );
      } catch (error) {
        return providerFailure(c, input.kind, error);
      }
      if (!generated.ok) return refusal(c, generated.outcome);
      const set = generated.value;
      const saved = await deps.outputs.call(context, "put", {
        kind: input.kind,
        fingerprint,
        resourceIds,
        items: set.kind === "quiz" ? set.questions : set.cards,
        scope: scopeJson(scope),
        model: set.usage?.model ?? "unknown",
      });
      if (saved["outcome"] !== "ok") {
        return refusal(c, String(saved["outcome"]));
      }
      return answer(saved["output"] as Record<string, unknown>);
    },
  );

  // -------------------------------------------------------------------------
  // Study notes from the chosen material, filed in this class's notebook
  // (Studafy Plus).
  // -------------------------------------------------------------------------
  const summaryRoute = v1Route("summariseMaterial");
  routes.post(
    "/v1/classrooms/:classroomId/notebook/summary",
    validateRouteInput(summaryRoute),
    requirePermission(
      authorization,
      "notebook.write",
      (c) => validatedParams<Record<string, string>>(c).classroomId ?? null,
    ),
    requireAiAccess(deps.aiAccess),
    idempotency(idempotencyDependencies, summaryRoute.operationId, "required"),
    async (c) => {
      const assistant = deps.assistant;
      if (!assistant || !deps.lessonToolsEnabled) {
        return problem(c, "AI_FEATURE_DISABLED", 409);
      }
      const context = resolvedSchoolDbContext(c);
      const classroomId = routeParam(c, "classroomId");
      const input = validatedBody<{
        references: MaterialRef[];
        skipUnavailable?: boolean;
        language?: "ar" | "en";
      }>(c);
      const selection = await resolveSelection(
        deps.material,
        context,
        input.references,
        { skipUnavailable: input.skipUnavailable === true },
      );
      if (!selection.ok) return selectionProblem(c, selection);
      const scope = selection.scope;
      // Notes are filed in this class's notebook: from its lessons only.
      if (scope.lessons.some((l) => l.classroomId !== classroomId)) {
        return problem(c, "INVALID_REQUEST", 400);
      }
      const fingerprint = await scopeFingerprint(scope);
      const resourceIds = scope.lessons.map((l) => l.resourceId);

      const kept = await deps.outputs.call(context, "get", {
        kind: "summary",
        fingerprint,
        resourceIds,
      });
      if (kept["outcome"] !== "ok") return refusal(c, String(kept["outcome"]));
      let body = (kept["output"] as Record<string, unknown> | null)?.["body"];
      if (typeof body !== "string") {
        const gathered = await gatherScope(deps.material, context, scope, {
          question: "",
          budgetChars: STUDY_SET_MATERIAL_CHARS,
          mode: "coverage",
        });
        const text = materialText(gathered.passages);
        if (text.trim().length < 40) {
          return problem(c, "LESSON_HAS_NO_TEXT", 422);
        }
        let notes;
        try {
          const redacted = await nameRedactedAssistant(
            deps.aiAccess,
            context,
            assistant,
          );
          notes = await meter.run(
            context,
            "notes",
            holdFor(deps.prices, text.length, OUTPUT_TOKENS.long),
            () => redacted.lessonNotes(scopeTitle(scope), text),
            `summary:${fingerprint.slice(0, 64)}`,
          );
        } catch (error) {
          return providerFailure(c, "summary", error);
        }
        if (!notes.ok) return refusal(c, notes.outcome);
        body = notes.value.answer.slice(0, 18_000);
        await deps.outputs.call(context, "put", {
          kind: "summary",
          fingerprint,
          resourceIds,
          body,
          scope: scopeJson(scope),
          model: notes.value.usage?.model ?? "unknown",
        }).catch(() => null);
      }

      const reservation = c.get("idempotencyReservation");
      if (!reservation) return problem(c, "FORBIDDEN", 403);
      const saved = await deps.repository.command(
        context,
        "createNotebookEntry",
        classroomId,
        {
          title: scopeTitle(scope),
          body: (body + madeFromLine(scope, input.language ?? "en")).slice(
            0,
            20_000,
          ),
          source: "lesson",
        },
        reservation,
      );
      if (saved.outcome !== "ok") return refusal(c, saved.outcome);
      const entry = saved.response as Record<string, unknown>;
      const parsed = summaryRoute.response.safeParse({
        ...entry,
        createdAt: new Date(String(entry["createdAt"])).toISOString(),
      });
      return parsed.success
        ? committedJson(c, parsed.data, 201)
        : problem(c, "INTERNAL_ERROR", 500);
    },
  );

  return routes;
}
