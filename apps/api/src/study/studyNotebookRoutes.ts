import { type Context, Hono } from "hono";
import { v1Route } from "@studafy/contracts";
import type { Sql } from "@studafy/database";
import { type NotebookContent, notebookText } from "@studafy/domain";
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
import { idempotency } from "../platform/idempotency";
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
import { outcomeProblem, type OutcomeTable } from "../platform/outcomes";
import type { StudyRepository } from "./repository";
import {
  AI_REFUSALS,
  AiMeter,
  holdFor,
  type ModelPrices,
  OUTPUT_TOKENS,
} from "./metering";
import { gatherMaterial, type MaterialRepository } from "./material";
import { STUDY_SET_MATERIAL_CHARS } from "./routes";

/**
 * A student's study notebooks (2026-10-07).
 *
 * A notebook is made from one lesson - all of it or chosen files and links -
 * and written by the AI in the background: the request that asks for it
 * answers at once with the notebook "creating", and the app polls until it
 * is ready or failed. Generation is metered like any AI call, keyed on the
 * notebook and its generation, so a retried request never pays twice.
 *
 * Everything else - the cover, the student's notes, deleting - is plain
 * reads and writes through `private.api055_study_notebooks`, which checks on
 * every call that the notebook is the caller's.
 */

/** The longest a notebook's AI reply may be. */
export const NOTEBOOK_OUTPUT_TOKENS = 3_500;

export interface StudyNotebookRepository {
  call(
    context: RequestDbContext,
    operation: string,
    input: Record<string, unknown>,
  ): Promise<Record<string, unknown>>;
}

export class PostgresStudyNotebookRepository
  implements StudyNotebookRepository {
  constructor(readonly sql: Sql) {}

  async call(
    context: RequestDbContext,
    operation: string,
    input: Record<string, unknown>,
  ): Promise<Record<string, unknown>> {
    return await withRequestContext(this.sql, context, async (tx) => {
      const rows = await tx<{ result: Record<string, unknown> }[]>`
        select private.api055_study_notebooks(${operation}, ${
        tx.json(input as never)
      }) as result
      `;
      return rows[0]?.result ?? { outcome: "invalid" };
    });
  }
}

export interface StudyNotebookDependencies {
  notebooks: StudyNotebookRepository;
  material: MaterialRepository;
  repository: StudyRepository;
  prices: ModelPrices;
  /** Null without an AI provider: making a notebook is "not available". */
  assistant: StudyAssistant | null;
  lessonToolsEnabled: boolean;
  /** Runs work after the response is sent; tests await it. */
  background?: (work: Promise<void>) => void;
}

const NOTEBOOK_OUTCOMES: OutcomeTable = {
  ...AI_REFUSALS,
  material_processing: ["MATERIAL_PROCESSING", 409],
};

function iso(value: unknown): string {
  return new Date(String(value)).toISOString();
}

/** The database's summary with timestamps as the contract writes them. */
function summaryOf(value: unknown): Record<string, unknown> {
  const summary = { ...(value as Record<string, unknown>) };
  summary["createdAt"] = iso(summary["createdAt"]);
  summary["updatedAt"] = iso(summary["updatedAt"]);
  return summary;
}

function notebookOf(value: unknown): Record<string, unknown> {
  const notebook = { ...(value as Record<string, unknown>) };
  notebook["summary"] = summaryOf(notebook["summary"]);
  notebook["generatedAt"] = notebook["generatedAt"]
    ? iso(notebook["generatedAt"])
    : null;
  notebook["sets"] = ((notebook["sets"] ?? []) as Record<string, unknown>[])
    .map((set) => ({ ...set, createdAt: iso(set["createdAt"]) }));
  return notebook;
}

function setOf(value: unknown): Record<string, unknown> {
  const set = value as Record<string, unknown>;
  return {
    id: set["id"],
    notebookId: set["notebookId"],
    kind: set["kind"],
    sectionKeys: set["sectionKeys"] ?? [],
    outdated: set["outdated"] === true,
    questions: set["kind"] === "quiz" ? set["items"] : null,
    cards: set["kind"] === "flashcards" ? set["items"] : null,
    createdAt: iso(set["createdAt"]),
  };
}

export function createStudyNotebookRoutes(
  deps: StudyNotebookDependencies,
  authorization: AuthorizationDependencies,
  idempotencyDependencies: IdempotencyDependencies,
): Hono<AuthorizationEnv> {
  const routes = new Hono<AuthorizationEnv>();
  const log = authorization.logger;
  const meter = new AiMeter(deps.repository, deps.prices);
  const background = deps.background ??
    ((work: Promise<void>) => void work.catch(() => {}));
  const refusal = (c: Context<AuthorizationEnv>, outcome: string) =>
    outcomeProblem(c, outcome, NOTEBOOK_OUTCOMES);
  const ready = () => deps.assistant !== null && deps.lessonToolsEnabled;

  /**
   * Writes the notebook's AI part: the chosen material, the model, then the
   * saved notebook - or the reason it failed, which the app shows with a
   * retry. Never throws.
   */
  async function generate(
    context: RequestDbContext,
    started: Record<string, unknown>,
  ): Promise<void> {
    const id = String(started["notebookId"]);
    const generation = Number(started["generation"]);
    const fail = async (reason: string) => {
      await deps.notebooks.call(context, "fail", { id, generation, reason })
        .catch(() => {});
    };
    try {
      const assistant = deps.assistant;
      if (!assistant) return await fail("provider_unavailable");
      const gathered = await gatherMaterial(deps.material, context, {
        lessonIds: [String(started["resourceId"])],
        sourceIds: (started["sourceIds"] ?? []) as string[],
        question: "",
        budgetChars: STUDY_SET_MATERIAL_CHARS,
        mode: "coverage",
      });
      if (gathered.pending) return await fail("material_processing");
      const readable = gathered.passages.filter((p) => p.text.trim());
      if (readable.reduce((n, p) => n + p.text.length, 0) < 40) {
        return await fail("no_readable_material");
      }
      const metered = await meter.run(
        context,
        "notes",
        holdFor(deps.prices, gathered.chars, NOTEBOOK_OUTPUT_TOKENS),
        () =>
          assistant.notebook(String(started["lessonTitle"] ?? ""), readable, {
            unreadable: gathered.unreadable,
            learner: gathered.grade ? { grade: gathered.grade } : {},
          }),
        `notebook:${id}:${generation}`,
      );
      if (!metered.ok) return await fail(metered.outcome);
      await deps.notebooks.call(context, "finish", {
        id,
        generation,
        content: metered.value.content,
        unreadable: gathered.unreadable.slice(0, 100).map((u) => ({
          name: u.name.slice(0, 300),
          reason: u.code.slice(0, 60),
        })),
        model: metered.value.usage?.model ?? "unknown",
      });
    } catch (error) {
      // Neither the material nor the reply is logged: one is a school's,
      // the other a third party's words about it.
      log?.warn("study_notebook_failed", {
        error_kind: error instanceof StudyAssistantError
          ? error.kind
          : "unknown",
        provider_status: error instanceof StudyAssistantError
          ? error.status ?? null
          : null,
      });
      await fail(
        error instanceof StudyAssistantError && error.kind === "empty"
          ? "unusable_reply"
          : "provider_unavailable",
      );
    }
  }

  // -------------------------------------------------------------------------
  // A class's notebooks, and making one.
  // -------------------------------------------------------------------------
  const listRoute = v1Route("listStudyNotebooks");
  routes.get(
    "/v1/classrooms/:classroomId/study-notebooks",
    validateRouteInput(listRoute),
    requirePermission(
      authorization,
      "notebook.read",
      (c) => validatedParams<Record<string, string>>(c).classroomId ?? null,
    ),
    async (c) => {
      const found = await deps.notebooks.call(
        resolvedSchoolDbContext(c),
        "list",
        { classroomId: routeParam(c, "classroomId") },
      );
      if (found["outcome"] !== "ok") {
        return refusal(c, String(found["outcome"]));
      }
      const parsed = listRoute.response.safeParse({
        items: ((found["items"] ?? []) as unknown[]).map(summaryOf),
      });
      return parsed.success
        ? c.json(parsed.data)
        : problem(c, "INTERNAL_ERROR", 500);
    },
  );

  const createRoute = v1Route("createStudyNotebook");
  routes.post(
    "/v1/classrooms/:classroomId/study-notebooks",
    validateRouteInput(createRoute),
    requirePermission(
      authorization,
      "notebook.write",
      (c) => validatedParams<Record<string, string>>(c).classroomId ?? null,
    ),
    idempotency(idempotencyDependencies, createRoute.operationId, "required"),
    async (c) => {
      if (!ready()) return problem(c, "AI_FEATURE_DISABLED", 409);
      const context = resolvedSchoolDbContext(c);
      const input = validatedBody<{
        resourceId: string;
        sourceIds: string[];
        title?: string;
      }>(c);
      const started = await deps.notebooks.call(context, "create", {
        classroomId: routeParam(c, "classroomId"),
        resourceId: input.resourceId,
        sourceIds: input.sourceIds,
        ...(input.title ? { title: input.title } : {}),
      });
      if (started["outcome"] !== "ok") {
        return refusal(c, String(started["outcome"]));
      }
      background(generate(context, started));
      const parsed = createRoute.response.safeParse(
        summaryOf(started["summary"]),
      );
      return parsed.success
        ? c.json(parsed.data, 201)
        : problem(c, "INTERNAL_ERROR", 500);
    },
  );

  // -------------------------------------------------------------------------
  // One notebook.
  // -------------------------------------------------------------------------
  const notebookId = (c: Context<AuthorizationEnv>) =>
    routeParam(c, "notebookId");

  const getRoute = v1Route("getStudyNotebook");
  routes.get(
    "/v1/study-notebooks/:notebookId",
    validateRouteInput(getRoute),
    requirePermission(authorization, "study_notebook.read"),
    async (c) => {
      const found = await deps.notebooks.call(
        resolvedSchoolDbContext(c),
        "get",
        { id: notebookId(c) },
      );
      if (found["outcome"] !== "ok") {
        return refusal(c, String(found["outcome"]));
      }
      const parsed = getRoute.response.safeParse(notebookOf(found["notebook"]));
      if (!parsed.success) {
        log?.error("study_notebook_shape", {
          issues: parsed.error.issues.slice(0, 3).map((i) => i.path.join(".")),
        });
      }
      return parsed.success
        ? c.json(parsed.data)
        : problem(c, "INTERNAL_ERROR", 500);
    },
  );

  const regenerateRoute = v1Route("regenerateStudyNotebook");
  routes.post(
    "/v1/study-notebooks/:notebookId/regenerate",
    validateRouteInput(regenerateRoute),
    requirePermission(authorization, "study_notebook.write"),
    idempotency(
      idempotencyDependencies,
      regenerateRoute.operationId,
      "required",
    ),
    async (c) => {
      if (!ready()) return problem(c, "AI_FEATURE_DISABLED", 409);
      const context = resolvedSchoolDbContext(c);
      const input = validatedBody<{ sourceIds?: string[] }>(c);
      const started = await deps.notebooks.call(context, "regenerate", {
        id: notebookId(c),
        ...(input.sourceIds ? { sourceIds: input.sourceIds } : {}),
      });
      if (started["outcome"] !== "ok") {
        return refusal(c, String(started["outcome"]));
      }
      background(generate(context, started));
      const parsed = regenerateRoute.response.safeParse(
        summaryOf(started["summary"]),
      );
      return parsed.success
        ? c.json(parsed.data, 200)
        : problem(c, "INTERNAL_ERROR", 500);
    },
  );

  const settingsRoute = v1Route("updateStudyNotebookSettings");
  routes.post(
    "/v1/study-notebooks/:notebookId/settings",
    validateRouteInput(settingsRoute),
    requirePermission(authorization, "study_notebook.write"),
    idempotency(idempotencyDependencies, settingsRoute.operationId, "required"),
    async (c) => {
      const found = await deps.notebooks.call(
        resolvedSchoolDbContext(c),
        "settings",
        { ...validatedBody<Record<string, unknown>>(c), id: notebookId(c) },
      );
      if (found["outcome"] !== "ok") {
        return refusal(c, String(found["outcome"]));
      }
      const parsed = settingsRoute.response.safeParse(
        summaryOf(found["summary"]),
      );
      return parsed.success
        ? c.json(parsed.data, 200)
        : problem(c, "INTERNAL_ERROR", 500);
    },
  );

  const personalRoute = v1Route("saveStudyNotebookPersonal");
  routes.post(
    "/v1/study-notebooks/:notebookId/personal",
    validateRouteInput(personalRoute),
    requirePermission(authorization, "study_notebook.write"),
    idempotency(idempotencyDependencies, personalRoute.operationId, "required"),
    async (c) => {
      const found = await deps.notebooks.call(
        resolvedSchoolDbContext(c),
        "personal",
        { ...validatedBody<Record<string, unknown>>(c), id: notebookId(c) },
      );
      if (found["outcome"] !== "ok") {
        return refusal(c, String(found["outcome"]));
      }
      const parsed = personalRoute.response.safeParse(
        notebookOf(found["notebook"]),
      );
      return parsed.success
        ? c.json(parsed.data, 200)
        : problem(c, "INTERNAL_ERROR", 500);
    },
  );

  const deleteRoute = v1Route("deleteStudyNotebook");
  routes.post(
    "/v1/study-notebooks/:notebookId/delete",
    validateRouteInput(deleteRoute),
    requirePermission(authorization, "study_notebook.write"),
    idempotency(idempotencyDependencies, deleteRoute.operationId, "required"),
    async (c) => {
      const found = await deps.notebooks.call(
        resolvedSchoolDbContext(c),
        "delete",
        { id: notebookId(c) },
      );
      if (found["outcome"] !== "ok") {
        return refusal(c, String(found["outcome"]));
      }
      return c.json({ deleted: true }, 200);
    },
  );

  // -------------------------------------------------------------------------
  // A quiz or flashcards from the notebook, or from chosen sections of it:
  // made once per notebook version, then reopened for free.
  // -------------------------------------------------------------------------
  const setRoute = v1Route("makeNotebookStudySet");
  routes.post(
    "/v1/study-notebooks/:notebookId/study-set",
    validateRouteInput(setRoute),
    requirePermission(authorization, "study_notebook.write"),
    idempotency(idempotencyDependencies, setRoute.operationId, "required"),
    async (c) => {
      const assistant = deps.assistant;
      if (!assistant || !deps.lessonToolsEnabled) {
        return problem(c, "AI_FEATURE_DISABLED", 409);
      }
      const context = resolvedSchoolDbContext(c);
      const id = notebookId(c);
      const input = validatedBody<
        { kind: "quiz" | "flashcards"; sectionKeys: string[] }
      >(c);
      const found = await deps.notebooks.call(context, "set", {
        id,
        kind: input.kind,
        sectionKeys: input.sectionKeys,
      });
      if (found["outcome"] !== "ok") {
        return refusal(c, String(found["outcome"]));
      }
      if (found["existing"]) {
        const parsed = setRoute.response.safeParse(setOf(found["existing"]));
        return parsed.success
          ? c.json(parsed.data, 201)
          : problem(c, "INTERNAL_ERROR", 500);
      }

      const keys = (found["sectionKeys"] ?? []) as string[];
      const text = notebookText(found["content"] as NotebookContent, keys);
      if (text.length < 40) return problem(c, "LESSON_HAS_NO_TEXT", 422);
      const version = Number(found["contentVersion"]);

      let generated;
      try {
        generated = await meter.run(
          context,
          input.kind,
          holdFor(deps.prices, text.length, OUTPUT_TOKENS.long),
          () =>
            assistant.studySet(input.kind, String(found["title"] ?? ""), text),
          // The same notebook version and sections: one charge, however
          // often the request is retried.
          `nbset:${id}:${input.kind}:${version}:${keys.join(",")}`.slice(
            0,
            140,
          ),
        );
      } catch (error) {
        log?.warn("study_ai_failed", {
          feature: input.kind,
          error_kind: error instanceof StudyAssistantError
            ? error.kind
            : "unknown",
          provider_status: error instanceof StudyAssistantError
            ? error.status ?? null
            : null,
        });
        return problem(c, "SERVICE_UNAVAILABLE", 503);
      }
      if (!generated.ok) return refusal(c, generated.outcome);
      const set = generated.value;
      const saved = await deps.notebooks.call(context, "saveSet", {
        id,
        kind: input.kind,
        sectionKeys: keys,
        contentVersion: version,
        items: set.kind === "quiz" ? set.questions : set.cards,
        model: set.usage?.model ?? "unknown",
      });
      if (saved["outcome"] !== "ok") {
        return refusal(c, String(saved["outcome"]));
      }
      const parsed = setRoute.response.safeParse(setOf(saved["set"]));
      return parsed.success
        ? c.json(parsed.data, 201)
        : problem(c, "INTERNAL_ERROR", 500);
    },
  );

  return routes;
}
