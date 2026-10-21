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
  validateRouteInput,
} from "../platform/validation";
import {
  membershipDbContext,
  type RequestDbContext,
  withRequestContext,
} from "../platform/dbContext";
import type { CatalogueCommandResult } from "../platform/dispatchRepository";
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
import { readInlineImage } from "./inlineImage";
import { STUDY_SET_MATERIAL_CHARS } from "@studafy/infrastructure";

/**
 * A student's personal notebook (api058): notes that belong to no class,
 * and editing any of their own notes (ADR-0045). Every call runs as the
 * requesting user; the SQL re-checks that the note is theirs.
 */
export interface PersonalNotebookRepository {
  query(
    context: RequestDbContext,
    operation: "listPersonal" | "notesForPractice",
    input: Record<string, unknown>,
  ): Promise<Record<string, unknown>>;
  command(
    context: RequestDbContext,
    operation: "createPersonal" | "updateEntry" | "deleteEntry",
    resourceId: string | null,
    body: Record<string, unknown>,
    reservation: { id: string; generation: number },
  ): Promise<CatalogueCommandResult>;
}

export class PostgresPersonalNotebookRepository
  implements PersonalNotebookRepository {
  constructor(readonly sql: Sql) {}

  async query(
    context: RequestDbContext,
    operation: "listPersonal" | "notesForPractice",
    input: Record<string, unknown>,
  ): Promise<Record<string, unknown>> {
    return await withRequestContext(this.sql, context, async (tx) => {
      const rows = await tx<{ result: Record<string, unknown> }[]>`
        select private.api058_query(${operation}, ${
        tx.json(input as never)
      }) as result
      `;
      return rows[0]?.result ?? { outcome: "invalid" };
    });
  }

  async command(
    context: RequestDbContext,
    operation: "createPersonal" | "updateEntry" | "deleteEntry",
    resourceId: string | null,
    body: Record<string, unknown>,
    reservation: { id: string; generation: number },
  ): Promise<CatalogueCommandResult> {
    return await withRequestContext(this.sql, context, async (tx) => {
      const rows = await tx<{ result: CatalogueCommandResult }[]>`
        select private.api058_command(
          ${operation}, ${resourceId}::uuid, ${tx.json({ body } as never)},
          ${reservation.id}::uuid, ${reservation.generation}
        ) as result
      `;
      return rows[0]?.result ?? { outcome: "invalid" };
    });
  }
}

export interface PersonalNotebookRoutesDependencies {
  notebook: PersonalNotebookRepository;
  /** The AI ledger: the token allowance, and the plan behind it. */
  repository: StudyRepository;
  prices: ModelPrices;
  /** Null without an AI provider: the AI routes answer "not available". */
  assistant: StudyAssistant | null;
  /** Photo notes and practice - see ADR-0029. */
  lessonToolsEnabled: boolean;
  /** Who may use AI, and the names kept out of it (ADR-0043). */
  aiAccess: AiAccessRepository;
}

/** A personal note belongs to the student, never to a school. */
function selfContext(c: Context<AuthorizationEnv>): RequestDbContext {
  return { ...membershipDbContext(c), schoolId: null };
}

/** The model's own first heading is the natural title. */
function headingOf(text: string): string | undefined {
  return text.match(/^#{1,3}\s+(.+)$/m)?.[1]?.replace(/[*_`]/g, "").trim();
}

export function createPersonalNotebookRoutes(
  deps: PersonalNotebookRoutesDependencies,
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
    // Neither the notes nor the reply is logged: one is a child's work, the
    // other is what a third party said back.
    log?.warn("study_ai_failed", {
      feature,
      error_kind: error instanceof StudyAssistantError ? error.kind : "unknown",
      provider_status: error instanceof StudyAssistantError
        ? error.status ?? null
        : null,
    });
    if (error instanceof StudyAssistantError && error.kind === "unreadable") {
      return problem(c, "PHOTO_UNREADABLE", 422);
    }
    return problem(c, "SERVICE_UNAVAILABLE", 503);
  }

  async function write(
    c: Context<AuthorizationEnv>,
    operation: "createPersonal" | "updateEntry" | "deleteEntry",
    resourceId: string | null,
    body: Record<string, unknown>,
    responseSchema: {
      safeParse: (v: unknown) => { success: boolean; data?: unknown };
    },
    status: 200 | 201,
  ): Promise<Response> {
    const reservation = c.get("idempotencyReservation");
    if (!reservation) return problem(c, "FORBIDDEN", 403);
    const result = await deps.notebook.command(
      selfContext(c),
      operation,
      resourceId,
      body,
      reservation,
    );
    if (result.outcome !== "ok") return refusal(c, result.outcome);
    const parsed = responseSchema.safeParse(result.response);
    if (!parsed.success) return problem(c, "INTERNAL_ERROR", 500);
    return committedJson(c, parsed.data as never, status);
  }

  // -------------------------------------------------------------------------
  // The personal notebook: read and write. Typed notes are free (DL-055).
  // -------------------------------------------------------------------------
  const listRoute = v1Route("listMyNotebookEntries");
  routes.get(
    "/v1/me/notebook",
    validateRouteInput(listRoute),
    requirePermission(authorization, "my_notebook.read"),
    async (c) => {
      const result = await deps.notebook.query(
        selfContext(c),
        "listPersonal",
        {},
      );
      if (result["outcome"] !== "ok") {
        return refusal(c, String(result["outcome"] ?? "not_found"));
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

  const createRoute = v1Route("createMyNotebookEntry");
  routes.post(
    "/v1/me/notebook",
    validateRouteInput(createRoute),
    requirePermission(authorization, "my_notebook.write"),
    idempotency(idempotencyDependencies, createRoute.operationId, "required"),
    async (c) => {
      const input = validatedBody<{ title: string; body: string }>(c);
      // Typed notes are always 'typed'; only the photo route writes
      // 'whiteboard', after it has run the model.
      return await write(
        c,
        "createPersonal",
        null,
        { title: input.title, body: input.body, source: "typed" },
        createRoute.response,
        201,
      );
    },
  );

  // -------------------------------------------------------------------------
  // Studafy Plus: a photo or screenshot -> a note in the personal notebook.
  // The image is read once and never stored (ADR-0045).
  // -------------------------------------------------------------------------
  const photoRoute = v1Route("createMyPhotoNote");
  routes.post(
    "/v1/me/notebook/photo-notes",
    validateRouteInput(photoRoute),
    requirePermission(authorization, "my_notebook.write"),
    requireAiAccess(deps.aiAccess),
    idempotency(idempotencyDependencies, photoRoute.operationId, "required"),
    async (c) => {
      const assistant = deps.assistant;
      if (!assistant || !deps.lessonToolsEnabled) {
        return problem(c, "AI_FEATURE_DISABLED", 409);
      }
      const context = selfContext(c);
      const input = validatedBody<{
        image: { mediaType: string; data: string };
        title?: string;
      }>(c);
      const image = await readInlineImage(input.image);
      if (!image.ok) return problem(c, image.code, image.status);

      let notes;
      try {
        notes = await meter.run(
          context,
          "whiteboard",
          holdFor(deps.prices, 0, OUTPUT_TOKENS.long, 1),
          async () =>
            await assistant.whiteboardNotes(image.bytes, image.mediaType),
        );
      } catch (error) {
        return providerFailure(c, "whiteboard", error);
      }
      if (!notes.ok) return refusal(c, notes.outcome);

      const text = notes.value.answer;
      return await write(
        c,
        "createPersonal",
        null,
        {
          title: (input.title ?? headingOf(text) ?? "Notes").slice(0, 200),
          body: text.slice(0, 20000),
          source: "whiteboard",
        },
        photoRoute.response,
        201,
      );
    },
  );

  const editRoute = v1Route("updateMyNotebookEntry");
  routes.post(
    "/v1/me/notebook-entries/:entryId/edit",
    validateRouteInput(editRoute),
    requirePermission(authorization, "my_notebook.write"),
    idempotency(idempotencyDependencies, editRoute.operationId, "required"),
    async (c) => {
      const input = validatedBody<{ title?: string; body?: string }>(c);
      return await write(
        c,
        "updateEntry",
        routeParam(c, "entryId"),
        {
          ...(input.title !== undefined ? { title: input.title } : {}),
          ...(input.body !== undefined ? { body: input.body } : {}),
        },
        editRoute.response,
        200,
      );
    },
  );

  const deleteRoute = v1Route("deleteMyNotebookEntry");
  routes.post(
    "/v1/me/notebook-entries/:entryId/delete",
    validateRouteInput(deleteRoute),
    requirePermission(authorization, "my_notebook.write"),
    idempotency(idempotencyDependencies, deleteRoute.operationId, "required"),
    async (c) =>
      await write(
        c,
        "deleteEntry",
        routeParam(c, "entryId"),
        {},
        deleteRoute.response,
        200,
      ),
  );

  // -------------------------------------------------------------------------
  // Studafy Max: a quiz or flashcards from the student's own notes. Theirs
  // alone, so it is answered and not kept.
  // -------------------------------------------------------------------------
  const practiceRoute = v1Route("practiseMyNotes");
  routes.post(
    "/v1/me/notebook/practice",
    validateRouteInput(practiceRoute),
    requirePermission(authorization, "my_notebook.practise"),
    requireAiAccess(deps.aiAccess),
    idempotency(
      idempotencyDependencies,
      practiceRoute.operationId,
      "required",
    ),
    async (c) => {
      const assistant = deps.assistant;
      if (!assistant || !deps.lessonToolsEnabled) {
        return problem(c, "AI_FEATURE_DISABLED", 409);
      }
      const context = selfContext(c);
      const input = validatedBody<{
        kind: "quiz" | "flashcards";
        entryIds: string[];
      }>(c);
      const found = await deps.notebook.query(context, "notesForPractice", {
        entryIds: input.entryIds,
      });
      if (found["outcome"] !== "ok") {
        return refusal(c, String(found["outcome"]));
      }
      const notes = (found["items"] ?? []) as { title: string; text: string }[];
      const share = Math.floor(
        STUDY_SET_MATERIAL_CHARS / Math.max(1, notes.length),
      );
      const text = notes
        .map((note) => `## ${note.title}\n\n${note.text.slice(0, share)}`)
        .join("\n\n");
      if (text.replace(/\s+/g, " ").trim().length < 40) {
        return problem(c, "LESSON_HAS_NO_TEXT", 422);
      }
      const title = notes.length === 1 ? notes[0]!.title : "My notes";

      let generated;
      try {
        // Names out of the notes before they are sent (ADR-0043).
        const redacted = await nameRedactedAssistant(
          deps.aiAccess,
          context,
          assistant,
        );
        generated = await meter.run(
          context,
          input.kind,
          holdFor(deps.prices, text.length, OUTPUT_TOKENS.long),
          () => redacted.studySet(input.kind, title, text),
        );
      } catch (error) {
        return providerFailure(c, input.kind, error);
      }
      if (!generated.ok) return refusal(c, generated.outcome);
      const set = generated.value;
      const parsed = practiceRoute.response.safeParse({
        kind: input.kind,
        questions: set.kind === "quiz" ? set.questions : null,
        cards: set.kind === "flashcards" ? set.cards : null,
        createdAt: new Date().toISOString(),
      });
      return parsed.success
        ? c.json(parsed.data, 201)
        : problem(c, "INTERNAL_ERROR", 500);
    },
  );

  return routes;
}
