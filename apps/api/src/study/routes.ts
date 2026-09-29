import { type Context, Hono } from "hono";
import { v1Route } from "@studafy/contracts";
import {
  type PrivateFileStorage,
  sha256Hex,
  StorageUnavailableError,
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
import type { StudyRepository } from "./repository";
import type { NotebookRepository } from "./notebookRoutes";
import { resolvedSchoolDbContext } from "../platform/dbContext";
import { outcomeProblem } from "../platform/outcomes";
import { AI_REFUSALS, AiMeter, holdFor, type ModelPrices } from "./metering";
import {
  CHARS_PER_TOKEN,
  type ChatMemoryBudgets,
  chatMemoryTokens,
} from "@studafy/domain";

export interface StudyRoutesDependencies {
  repository: StudyRepository;
  prices: ModelPrices;
  /** Null without an AI provider: the AI routes answer "not available". */
  assistant: StudyAssistant | null;
  /** Whiteboard notes and study sets - see ADR-0029. */
  lessonToolsEnabled: boolean;
  /** Where cleaned whiteboard photos are read from. */
  storage: PrivateFileStorage | null;
  /** How much of a chat the helper remembers, by plan. */
  chatMemory?: ChatMemoryBudgets;
  /** Finds a note already made from a whiteboard photo. */
  notebooks?: NotebookRepository;
}

function refusal(c: Context<AuthorizationEnv>, outcome: string): Response {
  return outcomeProblem(c, outcome, AI_REFUSALS);
}

/**
 * Studafy Plus / Max and the student's Notebook.
 *
 * Hand-written rather than catalogue-built: the AI routes orchestrate a
 * provider call between database steps, which the generic handler cannot.
 * Each still carries the catalogue's route validation, its declared
 * permission and, for writes, a required idempotency key - so a retried
 * request replays the stored answer and is never charged twice.
 */
export function createStudyRoutes(
  deps: StudyRoutesDependencies,
  authorization: AuthorizationDependencies,
  idempotencyDependencies: IdempotencyDependencies,
): Hono<AuthorizationEnv> {
  const routes = new Hono<AuthorizationEnv>();
  const log = authorization.logger;

  const meter = new AiMeter(deps.repository, deps.prices);

  function providerFailure(
    c: Context<AuthorizationEnv>,
    feature: string,
    error: unknown,
  ): Response {
    // The request and the reply are both absent from this log line: one is a
    // child's work, the other is what a third party said back.
    log?.warn("study_ai_failed", {
      feature,
      error_kind: error instanceof StudyAssistantError ? error.kind : "unknown",
    });
    if (error instanceof StudyAssistantError && error.kind === "unreadable") {
      return problem(c, "PHOTO_UNREADABLE", 422);
    }
    return problem(c, "SERVICE_UNAVAILABLE", 503);
  }

  // The same conditions the AI routes below check before calling the
  // provider, so the app is never told a feature is here when it is not.
  function available(): string[] {
    if (!deps.assistant) return [];
    if (!deps.lessonToolsEnabled) return ["ask"];
    return deps.storage
      ? ["ask", "whiteboard", "quiz", "flashcards"]
      : ["ask", "quiz", "flashcards"];
  }

  // -------------------------------------------------------------------------
  // The plan and this month's allowance.
  // -------------------------------------------------------------------------
  const planRoute = v1Route("getStudyPlan");
  routes.get(
    "/v1/me/study-plan",
    validateRouteInput(planRoute),
    requirePermission(authorization, "study_plan.read"),
    async (c) => {
      const summary = await deps.repository.usage(
        resolvedSchoolDbContext(c),
        "summary",
        {},
      );
      if (summary["outcome"] !== "ok") {
        return refusal(c, String(summary["outcome"]));
      }
      const cap = Number(summary["capMicroUsd"]);
      const committed = Number(summary["committedMicroUsd"]);
      const response = {
        plan: summary["plan"],
        features: summary["features"],
        available: available(),
        ...(deps.chatMemory
          ? {
            chatMemoryChars:
              chatMemoryTokens(deps.chatMemory, String(summary["plan"])) *
              CHARS_PER_TOKEN,
          }
          : {}),
        allowanceUsed: cap > 0 ? Math.min(1, committed / cap) : 0,
        resetsAt: new Date(String(summary["resetsAt"])).toISOString(),
        askToday: summary["askToday"],
        askPerDay: summary["askPerDay"],
      };
      const parsed = planRoute.response.safeParse(response);
      return parsed.success
        ? c.json(parsed.data)
        : problem(c, "INTERNAL_ERROR", 500);
    },
  );

  // -------------------------------------------------------------------------
  // The notebook: read, write, delete.
  // -------------------------------------------------------------------------
  const listRoute = v1Route("listNotebookEntries");
  routes.get(
    "/v1/classrooms/:classroomId/notebook",
    validateRouteInput(listRoute),
    requirePermission(
      authorization,
      "notebook.read",
      (c) => validatedParams<Record<string, string>>(c).classroomId ?? null,
    ),
    async (c) => {
      const result = await deps.repository.query(
        resolvedSchoolDbContext(c),
        "listNotebookEntries",
        routeParam(c, "classroomId"),
        {},
      );
      if (!result || typeof result["outcome"] === "string") {
        return refusal(c, String(result?.["outcome"] ?? "not_found"));
      }
      const parsed = listRoute.response.safeParse({
        items: result["items"],
        nextCursor: null,
      });
      return parsed.success
        ? c.json(parsed.data)
        : problem(c, "INTERNAL_ERROR", 500);
    },
  );

  async function saveEntry(
    c: Context<AuthorizationEnv>,
    operation: string,
    resourceId: string,
    entry: Record<string, unknown>,
    responseSchema: {
      safeParse: (v: unknown) => { success: boolean; data?: unknown };
    },
    status: 200 | 201,
  ): Promise<Response> {
    const reservation = c.get("idempotencyReservation");
    if (!reservation) return problem(c, "FORBIDDEN", 403);
    const result = await deps.repository.command(
      resolvedSchoolDbContext(c),
      operation,
      resourceId,
      entry,
      reservation,
    );
    if (result.outcome !== "ok") return refusal(c, result.outcome);
    const parsed = responseSchema.safeParse(result.response);
    if (!parsed.success) return problem(c, "INTERNAL_ERROR", 500);
    return committedJson(c, parsed.data as never, status);
  }

  const createRoute = v1Route("createNotebookEntry");
  routes.post(
    "/v1/classrooms/:classroomId/notebook",
    validateRouteInput(createRoute),
    requirePermission(
      authorization,
      "notebook.write",
      (c) => validatedParams<Record<string, string>>(c).classroomId ?? null,
    ),
    idempotency(idempotencyDependencies, createRoute.operationId, "required"),
    async (c) => {
      const input = validatedBody<{ title: string; body: string }>(c);
      // Typed notes are always 'typed'; only the whiteboard route writes
      // 'whiteboard', after it has run the model.
      return await saveEntry(
        c,
        "createNotebookEntry",
        routeParam(c, "classroomId"),
        { title: input.title, body: input.body, source: "typed" },
        createRoute.response,
        201,
      );
    },
  );

  // -------------------------------------------------------------------------
  // Studafy Plus: whiteboard photo -> notebook notes.
  // -------------------------------------------------------------------------
  const whiteboardRoute = v1Route("createWhiteboardNote");
  routes.post(
    "/v1/classrooms/:classroomId/notebook/whiteboard",
    validateRouteInput(whiteboardRoute),
    requirePermission(
      authorization,
      "notebook.write",
      (c) => validatedParams<Record<string, string>>(c).classroomId ?? null,
    ),
    idempotency(
      idempotencyDependencies,
      whiteboardRoute.operationId,
      "required",
    ),
    async (c) => {
      const assistant = deps.assistant;
      if (!assistant || !deps.lessonToolsEnabled || !deps.storage) {
        return problem(c, "AI_FEATURE_DISABLED", 409);
      }
      const context = resolvedSchoolDbContext(c);
      const classroomId = routeParam(c, "classroomId");
      const input = validatedBody<{ photoFileId: string; title?: string }>(c);

      // The same photo again: the note made from it is still the note. The
      // provider is not asked again and nothing is charged.
      const made = await deps.notebooks?.call(
        context,
        "whiteboardEntry",
        input.photoFileId,
      );
      if (made?.["entry"]) {
        const parsed = whiteboardRoute.response.safeParse(made["entry"]);
        if (parsed.success) return c.json(parsed.data, 201);
      }

      const photo = await deps.repository.query(
        context,
        "getNotebookPhoto",
        input.photoFileId,
        { classroomId },
      );
      if (!photo || photo["outcome"] !== "ok") return refusal(c, "not_found");
      const object = photo["object"] as Record<string, unknown>;
      if (!object?.["rootClean"]) return problem(c, "PHOTO_NOT_READY", 409);

      let bytes: Uint8Array;
      try {
        bytes = (await deps.storage.openObject(
          String(object["bucket"]),
          String(object["objectKey"]),
        )).bytes;
      } catch (error) {
        if (!(error instanceof StorageUnavailableError)) throw error;
        return problem(c, "SERVICE_UNAVAILABLE", 503);
      }
      // Only the exact bytes the scan cleared are ever sent anywhere.
      if (await sha256Hex(bytes) !== object["storedSha256"]) {
        return problem(c, "SERVICE_UNAVAILABLE", 503);
      }

      let notes;
      try {
        notes = await meter.run(
          context,
          "whiteboard",
          holdFor(deps.prices, "whiteboard"),
          () => assistant.whiteboardNotes(bytes, String(object["mediaType"])),
        );
      } catch (error) {
        return providerFailure(c, "whiteboard", error);
      }
      if (!notes.ok) return refusal(c, notes.outcome);

      const text = notes.value.answer;
      // The model's own first heading is the natural title; a student's
      // choice wins, and "Lesson notes" is the last resort.
      const heading = text.match(/^#{1,3}\s+(.+)$/m)?.[1]?.trim();
      return await saveEntry(
        c,
        "createNotebookEntry",
        classroomId,
        {
          title: (input.title ?? heading ?? "Lesson notes").slice(0, 200),
          body: text.slice(0, 20000),
          source: "whiteboard",
          photoFileId: input.photoFileId,
        },
        whiteboardRoute.response,
        201,
      );
    },
  );

  const deleteRoute = v1Route("deleteNotebookEntry");
  routes.post(
    "/v1/notebook-entries/:entryId/delete",
    validateRouteInput(deleteRoute),
    requirePermission(
      authorization,
      "notebook_entry.delete",
      (c) => validatedParams<Record<string, string>>(c).entryId ?? null,
    ),
    idempotency(idempotencyDependencies, deleteRoute.operationId, "required"),
    async (c) =>
      await saveEntry(
        c,
        "deleteNotebookEntry",
        routeParam(c, "entryId"),
        {},
        deleteRoute.response,
        200,
      ),
  );

  // -------------------------------------------------------------------------
  // Studafy Max: a quiz or flashcards from a lesson.
  // -------------------------------------------------------------------------
  const studyRoute = v1Route("generateStudySet");
  routes.post(
    "/v1/resources/:resourceId/study-set",
    validateRouteInput(studyRoute),
    requirePermission(
      authorization,
      "study_set.generate",
      (c) => validatedParams<Record<string, string>>(c).resourceId ?? null,
    ),
    idempotency(idempotencyDependencies, studyRoute.operationId, "required"),
    async (c) => {
      const assistant = deps.assistant;
      if (!assistant || !deps.lessonToolsEnabled) {
        return problem(c, "AI_FEATURE_DISABLED", 409);
      }
      const context = resolvedSchoolDbContext(c);
      const resourceId = routeParam(c, "resourceId");
      const { kind } = validatedBody<{ kind: "quiz" | "flashcards" }>(c);

      const found = await deps.repository.query(
        context,
        "getStudyLesson",
        resourceId,
        { kind },
      );
      if (!found || found["outcome"] !== "ok") {
        return refusal(c, String(found?.["outcome"] ?? "not_found"));
      }

      const toResponse = (set: Record<string, unknown>) => {
        const items = set["items"];
        return {
          id: set["id"],
          resourceId: set["resourceId"],
          kind: set["kind"],
          questions: set["kind"] === "quiz" ? items : null,
          cards: set["kind"] === "flashcards" ? items : null,
          createdAt: new Date(String(set["createdAt"])).toISOString(),
        };
      };

      // Already made for this version of the lesson: free to everyone after
      // the first.
      const existing = found["existing"] as Record<string, unknown> | null;
      if (existing) {
        const parsed = studyRoute.response.safeParse(toResponse(existing));
        if (!parsed.success) return problem(c, "INTERNAL_ERROR", 500);
        return c.json(parsed.data, 201);
      }

      const lesson = found["lesson"] as Record<string, unknown>;
      const text = String(lesson["body"] ?? "").trim();
      if (text.length < 40) return problem(c, "LESSON_HAS_NO_TEXT", 422);

      let generated;
      try {
        generated = await meter.run(
          context,
          kind,
          holdFor(deps.prices, kind, text.length),
          () => assistant.studySet(kind, String(lesson["title"] ?? ""), text),
        );
      } catch (error) {
        return providerFailure(c, kind, error);
      }
      if (!generated.ok) return refusal(c, generated.outcome);

      const set = generated.value;
      const reservation = c.get("idempotencyReservation");
      if (!reservation) return problem(c, "FORBIDDEN", 403);
      const saved = await deps.repository.command(
        context,
        "saveStudySet",
        resourceId,
        {
          versionId: lesson["versionId"],
          kind,
          items: set.kind === "quiz" ? set.questions : set.cards,
          model: set.usage?.model ?? "unknown",
        },
        reservation,
      );
      if (saved.outcome !== "ok") return refusal(c, saved.outcome);
      const parsed = studyRoute.response.safeParse(
        toResponse(saved.response as Record<string, unknown>),
      );
      if (!parsed.success) return problem(c, "INTERNAL_ERROR", 500);
      return committedJson(c, parsed.data, 201);
    },
  );

  return routes;
}
