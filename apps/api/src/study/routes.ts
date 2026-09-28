import { type Context, Hono } from "hono";
import { type ErrorCodeType, v1Route } from "@studafy/contracts";
import {
  STUDY_LESSON_MAX_CHARS,
  type StudyAssistant,
  StudyAssistantError,
  type StudyUsage,
} from "@studafy/infrastructure";
import type {
  AuthorizationDependencies,
  AuthorizationEnv,
} from "../authorization/middleware";
import { requirePermission } from "../authorization/middleware";
import type { IdempotencyDependencies } from "../platform/idempotency";
import { idempotency } from "../platform/idempotency";
import { problem } from "../platform/errors";
import { validatedParams, validateRouteInput } from "../platform/validation";
import type { RequestDbContext } from "../platform/catalogueRoutes";
import {
  type PrivateFileStorage,
  sha256Hex,
  StorageUnavailableError,
} from "../files/storage";
import type { StudyFeature, StudyRepository } from "./repository";

/** The model's prices, US dollars per million tokens. */
export interface ModelPrices {
  inputUsdPerMTok: number;
  outputUsdPerMTok: number;
}

export interface StudyRoutesDependencies {
  repository: StudyRepository;
  prices: ModelPrices;
  /** Null without an AI provider: the AI routes answer "not available". */
  assistant: StudyAssistant | null;
  /** Whiteboard notes and study sets - see ADR-0029. */
  lessonToolsEnabled: boolean;
  /** Where cleaned whiteboard photos are read from. */
  storage: PrivateFileStorage | null;
}

/**
 * Worst-case input tokens per call, used to size the hold taken against a
 * student's cap before the provider is called. Generous on purpose: the hold
 * must never be smaller than what the call can cost, or the cap could be
 * passed. The actual cost replaces it as soon as the provider answers.
 */
const INPUT_BOUND_TOKENS = {
  ask: 1_200,
  // A full-resolution phone photo is ~15k image tokens on Qwen3.5.
  whiteboard: 16_000,
} as const;
const ASK_OUTPUT_TOKENS = 500;
const LONG_OUTPUT_TOKENS = 1_400;

/** Millionths of a dollar for this many tokens. */
export function costMicroUsd(
  prices: ModelPrices,
  inputTokens: number,
  outputTokens: number,
): number {
  // USD per million tokens is exactly micro-USD per token.
  return Math.ceil(
    inputTokens * prices.inputUsdPerMTok +
      outputTokens * prices.outputUsdPerMTok,
  );
}

function holdFor(
  prices: ModelPrices,
  feature: StudyFeature,
  lessonChars = 0,
): number {
  switch (feature) {
    case "ask":
      return costMicroUsd(prices, INPUT_BOUND_TOKENS.ask, ASK_OUTPUT_TOKENS);
    case "whiteboard":
      return costMicroUsd(
        prices,
        INPUT_BOUND_TOKENS.whiteboard,
        LONG_OUTPUT_TOKENS,
      );
    default: {
      // Roughly three characters a token, plus the instructions.
      const input = Math.ceil(
        Math.min(lessonChars, STUDY_LESSON_MAX_CHARS) / 3,
      ) + 600;
      return costMicroUsd(prices, input, LONG_OUTPUT_TOKENS);
    }
  }
}

function requestContext(c: Context<AuthorizationEnv>): RequestDbContext {
  return {
    subject: c.get("actor").token.subject,
    schoolId: c.get("authorization").tenant?.schoolId ??
      c.get("authorization").decisionSchoolId ?? null,
    requestId: c.get("requestId"),
    aal2: c.get("actor").aal2,
  };
}

function body<T>(c: Context<AuthorizationEnv>): T {
  // Read from the context: validatedBody() is typed for PlatformEnv, which
  // Hono's invariant Context does not accept here. The schema has already
  // validated it by the time a handler runs.
  return c.get("validatedBody") as T;
}

function param(c: Context<AuthorizationEnv>, name: string): string {
  const value = validatedParams<Record<string, string>>(c as never)[name];
  if (!value) throw new Error(`validated route parameter missing: ${name}`);
  return value;
}

/** The refusals a paid call can meet before anything is spent. */
function refusal(
  c: Context<AuthorizationEnv>,
  outcome: string,
): Response {
  const mapped: Record<
    string,
    [ErrorCodeType, 400 | 403 | 404 | 409 | 422 | 429]
  > = {
    plan_required: ["PLAN_REQUIRED", 403],
    monthly_cap: ["AI_ALLOWANCE_USED", 429],
    daily_limit: ["AI_DAILY_LIMIT", 429],
    not_found: ["NOT_FOUND", 404],
    forbidden: ["FORBIDDEN", 403],
    invalid: ["INVALID_REQUEST", 400],
  };
  const entry = mapped[outcome] ?? ["INVALID_REQUEST", 400];
  return problem(c, entry[0], entry[1]);
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

  /**
   * Runs one metered provider call: hold the worst case, call, then settle
   * to what the provider reported - or release the hold if nothing came
   * back. Returns the outcome of the hold when it was refused.
   */
  async function metered<T extends { usage?: StudyUsage }>(
    context: RequestDbContext,
    feature: StudyFeature,
    hold: number,
    call: () => Promise<T>,
  ): Promise<{ ok: true; value: T } | { ok: false; outcome: string }> {
    const reserved = await deps.repository.usage(context, "reserve", {
      feature,
      estimateMicroUsd: hold,
    });
    if (reserved["outcome"] !== "ok") {
      return { ok: false, outcome: String(reserved["outcome"]) };
    }
    const usageId = reserved["usageId"];
    let value: T;
    try {
      value = await call();
    } catch (error) {
      await deps.repository.usage(context, "release", { usageId });
      throw error;
    }
    const usage = value.usage;
    await deps.repository.usage(context, "settle", {
      usageId,
      // No usage reported: charge the hold, which is the upper bound.
      costMicroUsd: usage
        ? costMicroUsd(deps.prices, usage.inputTokens, usage.outputTokens)
        : hold,
      inputTokens: usage?.inputTokens ?? null,
      outputTokens: usage?.outputTokens ?? null,
      model: usage?.model ?? null,
    });
    return { ok: true, value };
  }

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

  // -------------------------------------------------------------------------
  // The plan and this month's allowance.
  // -------------------------------------------------------------------------
  const planRoute = v1Route("getStudyPlan");
  routes.get(
    "/v1/me/study-plan",
    validateRouteInput(planRoute) as never,
    requirePermission(authorization, "study_plan.read"),
    async (c) => {
      const summary = await deps.repository.usage(
        requestContext(c),
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
    validateRouteInput(listRoute) as never,
    requirePermission(
      authorization,
      "notebook.read",
      (c) =>
        validatedParams<Record<string, string>>(c as never).classroomId ?? null,
    ),
    async (c) => {
      const result = await deps.repository.query(
        requestContext(c),
        "listNotebookEntries",
        param(c, "classroomId"),
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
      requestContext(c),
      operation,
      resourceId,
      entry,
      reservation,
    );
    if (result.outcome !== "ok") return refusal(c, result.outcome);
    const parsed = responseSchema.safeParse(result.response);
    if (!parsed.success) return problem(c, "INTERNAL_ERROR", 500);
    c.set("idempotencyCompleted", true);
    return c.json(parsed.data as never, status);
  }

  const createRoute = v1Route("createNotebookEntry");
  routes.post(
    "/v1/classrooms/:classroomId/notebook",
    validateRouteInput(createRoute) as never,
    requirePermission(
      authorization,
      "notebook.write",
      (c) =>
        validatedParams<Record<string, string>>(c as never).classroomId ?? null,
    ),
    idempotency(idempotencyDependencies, createRoute.operationId, "required"),
    async (c) => {
      const input = body<{ title: string; body: string }>(c);
      // Typed notes are always 'typed'; only the whiteboard route writes
      // 'whiteboard', after it has run the model.
      return await saveEntry(
        c,
        "createNotebookEntry",
        param(c, "classroomId"),
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
    validateRouteInput(whiteboardRoute) as never,
    requirePermission(
      authorization,
      "notebook.write",
      (c) =>
        validatedParams<Record<string, string>>(c as never).classroomId ?? null,
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
      const context = requestContext(c);
      const classroomId = param(c, "classroomId");
      const input = body<{ photoFileId: string; title?: string }>(c);

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
        notes = await metered(
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
    validateRouteInput(deleteRoute) as never,
    requirePermission(
      authorization,
      "notebook_entry.delete",
      (c) =>
        validatedParams<Record<string, string>>(c as never).entryId ?? null,
    ),
    idempotency(idempotencyDependencies, deleteRoute.operationId, "required"),
    async (c) =>
      await saveEntry(
        c,
        "deleteNotebookEntry",
        param(c, "entryId"),
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
    validateRouteInput(studyRoute) as never,
    requirePermission(
      authorization,
      "study_set.generate",
      (c) =>
        validatedParams<Record<string, string>>(c as never).resourceId ?? null,
    ),
    idempotency(idempotencyDependencies, studyRoute.operationId, "required"),
    async (c) => {
      const assistant = deps.assistant;
      if (!assistant || !deps.lessonToolsEnabled) {
        return problem(c, "AI_FEATURE_DISABLED", 409);
      }
      const context = requestContext(c);
      const resourceId = param(c, "resourceId");
      const { kind } = body<{ kind: "quiz" | "flashcards" }>(c);

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
        generated = await metered(
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
      c.set("idempotencyCompleted", true);
      return c.json(parsed.data, 201);
    },
  );

  return routes;
}

export { holdFor };
