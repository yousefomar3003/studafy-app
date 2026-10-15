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
  type AiAccessRepository,
  nameRedactedAssistant,
  requireAiAccess,
} from "./aiAccess";
import {
  AI_REFUSALS,
  AiMeter,
  holdFor,
  type ModelPrices,
  OUTPUT_TOKENS,
} from "./metering";
import {
  gatherMaterial,
  type MaterialRepository,
  materialText,
} from "./material";

export type NotebookOperation =
  | "myNotebooks"
  | "lessonForNotes"
  | "references"
  | "whiteboardEntry"
  | "assistantAttachment";

/** The notebooks surface (api049): read-only, as the requesting user. */
export interface NotebookRepository {
  call(
    context: RequestDbContext,
    operation: NotebookOperation,
    resourceId: string | null,
    input?: Record<string, unknown>,
  ): Promise<Record<string, unknown>>;
  /** Keeps notes made from one version of a lesson for every student who
   * can read it; the database re-checks plan and access. */
  cacheLessonNotes?(
    context: RequestDbContext,
    resourceId: string,
    versionId: string,
    body: string,
    model: string,
  ): Promise<boolean>;
}

export class PostgresNotebookRepository implements NotebookRepository {
  constructor(readonly sql: Sql) {}

  async call(
    context: RequestDbContext,
    operation: NotebookOperation,
    resourceId: string | null,
    input: Record<string, unknown> = {},
  ): Promise<Record<string, unknown>> {
    return await withRequestContext(this.sql, context, async (tx) => {
      const rows = await tx<{ result: Record<string, unknown> }[]>`
        select private.api049_notebooks(
          ${operation}, ${resourceId}::uuid, ${tx.json(input as never)}
        ) as result
      `;
      return rows[0]?.result ?? { outcome: "invalid" };
    });
  }

  async cacheLessonNotes(
    context: RequestDbContext,
    resourceId: string,
    versionId: string,
    body: string,
    model: string,
  ): Promise<boolean> {
    return await withRequestContext(this.sql, context, async (tx) => {
      const rows = await tx<{ stored: boolean }[]>`
        select private.lesson_notes_cache_put(
          ${resourceId}::uuid, ${versionId}::uuid, ${body}, ${model}
        ) as stored
      `;
      return rows[0]?.stored ?? false;
    });
  }
}

export interface NotebookRoutesDependencies {
  notebooks: NotebookRepository;
  /** The notebook writes (api046), shared with the class notebook routes. */
  study: StudyRepository;
  prices: ModelPrices;
  assistant: StudyAssistant | null;
  lessonToolsEnabled: boolean;
  /** Lessons' files and links, read for the AI (ADR-0037). */
  material?: MaterialRepository;
  /** Who may use AI, and the names kept out of it (ADR-0043). */
  aiAccess: AiAccessRepository;
}

function toEntry(entry: Record<string, unknown>) {
  return {
    ...entry,
    createdAt: new Date(String(entry["createdAt"])).toISOString(),
  };
}

/**
 * Every notebook a student has, by class - deleted classes included - and
 * study notes made from a lesson (2026-09-29).
 */
export function createNotebookRoutes(
  deps: NotebookRoutesDependencies,
  authorization: AuthorizationDependencies,
  idempotencyDependencies: IdempotencyDependencies,
): Hono<AuthorizationEnv> {
  const routes = new Hono<AuthorizationEnv>();
  const meter = new AiMeter(deps.study, deps.prices);
  const log = authorization.logger;

  // The student's own notes, whoever else is in the class, and whether or
  // not the class still exists.
  const context = (c: Context<AuthorizationEnv>): RequestDbContext => ({
    subject: c.get("actor").token.subject,
    schoolId: null,
    requestId: c.get("requestId"),
    aal2: c.get("actor").aal2,
  });

  const listRoute = v1Route("listMyNotebooks");
  routes.get(
    "/v1/me/notebooks",
    validateRouteInput(listRoute),
    requirePermission(authorization, "notebook.list_own"),
    async (c) => {
      const result = await deps.notebooks.call(context(c), "myNotebooks", null);
      if (result["outcome"] !== "ok") {
        return outcomeProblem(c, String(result["outcome"]), AI_REFUSALS, log);
      }
      const classes = (result["classes"] as Record<string, unknown>[]).map(
        (group) => ({
          ...group,
          entries: (group["entries"] as Record<string, unknown>[]).map(toEntry),
        }),
      );
      const parsed = listRoute.response.safeParse({ classes });
      return parsed.success
        ? c.json(parsed.data)
        : problem(c, "INTERNAL_ERROR", 500);
    },
  );

  const notesRoute = v1Route("createLessonNotes");
  routes.post(
    "/v1/resources/:resourceId/lesson-notes",
    validateRouteInput(notesRoute),
    requirePermission(
      authorization,
      "study_set.generate",
      (c) => validatedParams<Record<string, string>>(c).resourceId ?? null,
    ),
    requireAiAccess(deps.aiAccess),
    idempotency(idempotencyDependencies, notesRoute.operationId, "required"),
    async (c) => {
      const assistant = deps.assistant;
      // Sends a lesson's text to the provider: behind the same switch as
      // quizzes and whiteboard notes (ADR-0029).
      if (!assistant || !deps.lessonToolsEnabled) {
        return problem(c, "AI_FEATURE_DISABLED", 409);
      }
      const db = resolvedSchoolDbContext(c);
      const found = await deps.notebooks.call(
        db,
        "lessonForNotes",
        routeParam(c, "resourceId"),
      );
      if (found["outcome"] !== "ok") {
        return outcomeProblem(c, String(found["outcome"]), AI_REFUSALS, log);
      }
      const lesson = found["lesson"] as Record<string, unknown>;
      const resourceId = routeParam(c, "resourceId");
      // From every file and link on the lesson, not only its text, and only
      // once they have all been read (ADR-0037).
      let text = String(lesson["body"] ?? "").trim();
      if (deps.material) {
        const pending = await deps.material.call(db, "pending", { resourceId });
        if (pending["pending"] === true) {
          return problem(c, "MATERIAL_PROCESSING", 409);
        }
        const gathered = await gatherMaterial(deps.material, db, {
          lessonIds: [resourceId],
          sourceIds: [],
          question: "",
          budgetChars: 40_000,
          mode: "coverage",
        });
        if (gathered.passages.length > 0) {
          text = materialText(gathered.passages);
        }
      }
      if (text.length < 40) return problem(c, "LESSON_HAS_NO_TEXT", 422);
      const title = String(lesson["title"] ?? "");

      // Notes already made from this version of the lesson are reused:
      // free, and the provider is not asked again.
      let body = typeof found["cachedNotes"] === "string"
        ? found["cachedNotes"]
        : "";
      if (!body) {
        let notes;
        try {
          // Names out of the lesson before it is sent (ADR-0043).
          const redacted = await nameRedactedAssistant(
            deps.aiAccess,
            db,
            assistant,
          );
          // Plus's AI note-making, metered like the whiteboard.
          notes = await meter.run(
            db,
            "notes",
            holdFor(deps.prices, text.length, OUTPUT_TOKENS.long),
            () => redacted.lessonNotes(title, text),
          );
        } catch (error) {
          log?.warn("study_ai_failed", {
            feature: "lesson_notes",
            error_kind: error instanceof StudyAssistantError
              ? error.kind
              : "unknown",
          });
          return problem(c, "SERVICE_UNAVAILABLE", 503);
        }
        if (!notes.ok) {
          return outcomeProblem(c, notes.outcome, AI_REFUSALS, log);
        }
        body = notes.value.answer.slice(0, 20000);
        await deps.notebooks.cacheLessonNotes?.(
          db,
          routeParam(c, "resourceId"),
          String(lesson["versionId"]),
          body,
          notes.value.usage?.model ?? "unknown",
        ).catch(() => false);
      }

      const reservation = c.get("idempotencyReservation");
      if (!reservation) return problem(c, "FORBIDDEN", 403);
      const saved = await deps.study.command(
        db,
        "createNotebookEntry",
        String(lesson["classroomId"]),
        {
          title: (title || "Lesson notes").slice(0, 200),
          body,
          source: "lesson",
        },
        reservation,
      );
      if (saved.outcome !== "ok") {
        return outcomeProblem(c, saved.outcome, AI_REFUSALS, log);
      }
      const parsed = notesRoute.response.safeParse(
        toEntry(saved.response as Record<string, unknown>),
      );
      return parsed.success
        ? committedJson(c, parsed.data, 201)
        : problem(c, "INTERNAL_ERROR", 500);
    },
  );

  return routes;
}
