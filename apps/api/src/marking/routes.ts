import { type Context, Hono } from "hono";
import { v1Route } from "@studafy/contracts";
import type { Sql } from "@studafy/database";
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
import { outcomeProblem, type OutcomeTable } from "../platform/outcomes";

type QueryOperation = "plan" | "references" | "suggestions" | "preference";
type CommandOperation =
  | "setReferences"
  | "requestSuggestions"
  | "dismissSuggestion"
  | "setPreference";

/**
 * AI-suggested marks against the teacher's reference (api059, ADR-0046).
 * Every call runs as the requesting user; the SQL re-checks that they teach
 * the assessment's class, and that a preference is a student's own. Nothing
 * here writes a mark: the teacher's own save through the marking routes
 * stays the only writer.
 */
export interface MarkingRepository {
  query(
    context: RequestDbContext,
    operation: QueryOperation,
    resourceId: string | null,
  ): Promise<Record<string, unknown>>;
  command(
    context: RequestDbContext,
    operation: CommandOperation,
    resourceId: string | null,
    body: Record<string, unknown>,
    reservation: { id: string; generation: number },
  ): Promise<CatalogueCommandResult>;
}

export class PostgresMarkingRepository implements MarkingRepository {
  constructor(readonly sql: Sql) {}

  async query(
    context: RequestDbContext,
    operation: QueryOperation,
    resourceId: string | null,
  ): Promise<Record<string, unknown>> {
    return await withRequestContext(this.sql, context, async (tx) => {
      const rows = await tx<{ result: Record<string, unknown> }[]>`
        select private.api059_query(
          ${operation}, ${resourceId}::uuid, '{}'::jsonb
        ) as result
      `;
      return rows[0]?.result ?? { outcome: "invalid" };
    });
  }

  async command(
    context: RequestDbContext,
    operation: CommandOperation,
    resourceId: string | null,
    body: Record<string, unknown>,
    reservation: { id: string; generation: number },
  ): Promise<CatalogueCommandResult> {
    return await withRequestContext(this.sql, context, async (tx) => {
      const rows = await tx<{ result: CatalogueCommandResult }[]>`
        select private.api059_command(
          ${operation}, ${resourceId}::uuid, ${tx.json({ body } as never)},
          ${reservation.id}::uuid, ${reservation.generation}
        ) as result
      `;
      return rows[0]?.result ?? { outcome: "invalid" };
    });
  }
}

export interface MarkingRoutesDependencies {
  marking: MarkingRepository;
  /**
   * Suggestions can be made at all: MARKING_SUGGESTIONS_ENABLED and an AI
   * provider. Off, references can still be written and read, and asking for
   * suggestions answers "not available".
   */
  available: boolean;
}

const MARKING_REFUSALS: OutcomeTable = {
  plan_required: ["PLAN_REQUIRED", 403],
};

/** Marking reads and writes no tenant of the request's choosing: the SQL
 * finds the assessment's school and checks the caller teaches there. */
function selfContext(c: Context<AuthorizationEnv>): RequestDbContext {
  return { ...membershipDbContext(c), schoolId: null };
}

export function createMarkingRoutes(
  deps: MarkingRoutesDependencies,
  authorization: AuthorizationDependencies,
  idempotencyDependencies: IdempotencyDependencies,
): Hono<AuthorizationEnv> {
  const routes = new Hono<AuthorizationEnv>();
  const log = authorization.logger;
  const refusal = (c: Context<AuthorizationEnv>, outcome: string) =>
    outcomeProblem(c, outcome, MARKING_REFUSALS, log);

  async function read(
    c: Context<AuthorizationEnv>,
    operation: QueryOperation,
    resourceId: string | null,
    schema: { safeParse: (v: unknown) => { success: boolean; data?: unknown } },
    extra: Record<string, unknown> = {},
  ): Promise<Response> {
    const result = await deps.marking.query(
      selfContext(c),
      operation,
      resourceId,
    );
    if (result["outcome"] !== "ok") {
      return refusal(c, String(result["outcome"] ?? "not_found"));
    }
    const { outcome: _outcome, ...rest } = result;
    const parsed = schema.safeParse({ ...rest, ...extra });
    return parsed.success
      ? c.json(parsed.data as never)
      : problem(c, "INTERNAL_ERROR", 500);
  }

  async function write(
    c: Context<AuthorizationEnv>,
    operation: CommandOperation,
    resourceId: string | null,
    body: Record<string, unknown>,
    schema: { safeParse: (v: unknown) => { success: boolean; data?: unknown } },
    status: 200 | 201,
  ): Promise<Response> {
    const reservation = c.get("idempotencyReservation");
    if (!reservation) return problem(c, "FORBIDDEN", 403);
    const result = await deps.marking.command(
      selfContext(c),
      operation,
      resourceId,
      body,
      reservation,
    );
    if (result.outcome !== "ok") return refusal(c, result.outcome);
    const parsed = schema.safeParse(result.response);
    if (!parsed.success) return problem(c, "INTERNAL_ERROR", 500);
    return committedJson(c, parsed.data as never, status);
  }

  // -------------------------------------------------------------------------
  // The teacher's plan, and whether suggestions can be made at all.
  // -------------------------------------------------------------------------
  const planRoute = v1Route("getMyMarkingPlan");
  routes.get(
    "/v1/me/marking-plan",
    validateRouteInput(planRoute),
    requirePermission(authorization, "marking_plan.read"),
    async (c) =>
      await read(c, "plan", null, planRoute.response, {
        available: deps.available,
      }),
  );

  // -------------------------------------------------------------------------
  // References: what the teacher says a good answer is, and how strictly to
  // read it. Editable at any time; a change re-marks nothing by itself.
  // -------------------------------------------------------------------------
  const referencesRoute = v1Route("getMarkingReferences");
  routes.get(
    "/v1/assessments/:assessmentId/marking-references",
    validateRouteInput(referencesRoute),
    requirePermission(authorization, "marking_reference.read"),
    async (c) =>
      await read(
        c,
        "references",
        routeParam(c, "assessmentId"),
        referencesRoute.response,
      ),
  );

  const updateReferencesRoute = v1Route("updateMarkingReferences");
  routes.post(
    "/v1/assessments/:assessmentId/marking-references",
    validateRouteInput(updateReferencesRoute),
    requirePermission(authorization, "marking_reference.write"),
    idempotency(
      idempotencyDependencies,
      updateReferencesRoute.operationId,
      "required",
    ),
    async (c) =>
      await write(
        c,
        "setReferences",
        routeParam(c, "assessmentId"),
        validatedBody<Record<string, unknown>>(c),
        updateReferencesRoute.response,
        200,
      ),
  );

  // -------------------------------------------------------------------------
  // Suggestions: drafts for the teacher. Asking queues them for the worker;
  // nobody but the class's teachers ever reads them.
  // -------------------------------------------------------------------------
  const suggestionsRoute = v1Route("listMarkingSuggestions");
  routes.get(
    "/v1/assessments/:assessmentId/marking-suggestions",
    validateRouteInput(suggestionsRoute),
    requirePermission(authorization, "marking_suggestion.read"),
    async (c) =>
      await read(
        c,
        "suggestions",
        routeParam(c, "assessmentId"),
        suggestionsRoute.response,
      ),
  );

  const requestRoute = v1Route("requestMarkingSuggestions");
  routes.post(
    "/v1/assessments/:assessmentId/marking-suggestions",
    validateRouteInput(requestRoute),
    requirePermission(authorization, "marking_suggestion.request"),
    idempotency(idempotencyDependencies, requestRoute.operationId, "required"),
    async (c) => {
      if (!deps.available) return problem(c, "AI_FEATURE_DISABLED", 409);
      return await write(
        c,
        "requestSuggestions",
        routeParam(c, "assessmentId"),
        validatedBody<Record<string, unknown>>(c),
        requestRoute.response,
        201,
      );
    },
  );

  const dismissRoute = v1Route("dismissMarkingSuggestion");
  routes.post(
    "/v1/marking-suggestions/:suggestionId/dismiss",
    validateRouteInput(dismissRoute),
    requirePermission(authorization, "marking_suggestion.dismiss"),
    idempotency(idempotencyDependencies, dismissRoute.operationId, "required"),
    async (c) =>
      await write(
        c,
        "dismissSuggestion",
        routeParam(c, "suggestionId"),
        {},
        dismissRoute.response,
        200,
      ),
  );

  // -------------------------------------------------------------------------
  // A student's choice: their work is never sent to the AI.
  // -------------------------------------------------------------------------
  const preferenceRoute = v1Route("getMyMarkingPreference");
  routes.get(
    "/v1/me/marking-preference",
    validateRouteInput(preferenceRoute),
    requirePermission(authorization, "marking_preference.read"),
    async (c) => await read(c, "preference", null, preferenceRoute.response),
  );

  const updatePreferenceRoute = v1Route("updateMyMarkingPreference");
  routes.post(
    "/v1/me/marking-preference",
    validateRouteInput(updatePreferenceRoute),
    requirePermission(authorization, "marking_preference.write"),
    idempotency(
      idempotencyDependencies,
      updatePreferenceRoute.operationId,
      "required",
    ),
    async (c) =>
      await write(
        c,
        "setPreference",
        null,
        { optedOut: validatedBody<{ optedOut: boolean }>(c).optedOut },
        updatePreferenceRoute.response,
        200,
      ),
  );

  return routes;
}
