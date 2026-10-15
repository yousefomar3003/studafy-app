import { type Context, Hono } from "hono";
import { v1Route } from "@studafy/contracts";
import type {
  AuthorizationDependencies,
  AuthorizationEnv,
} from "../authorization/middleware";
import { requirePermission } from "../authorization/middleware";
import type { IdempotencyDependencies } from "../platform/idempotency";
import { committedJson, idempotency } from "../platform/idempotency";
import { problem } from "../platform/errors";
import { outcomeProblem, type OutcomeTable } from "../platform/outcomes";
import {
  routeParam,
  validatedBody,
  validateRouteInput,
} from "../platform/validation";
import {
  actorDbContext,
  AI_ACCESS_REFUSALS,
  type AiAccessRepository,
  type AiConsentOperation,
} from "./aiAccess";

export interface AiConsentRoutesDependencies {
  repository: AiAccessRepository;
}

const REFUSALS: OutcomeTable = {
  ...AI_ACCESS_REFUSALS,
  // The notice the app showed is not the current one: it fetches the state
  // again and shows the current notice.
  stale_version: ["INVALID_STATE", 409],
};

/**
 * The AI consent (ADR-0043; DPIA D2): a student agrees to the AI notice
 * before their first AI use, or withdraws; a parent does both for a child
 * account they manage. Everything is decided in
 * `private.api057_ai_consent`, which re-derives the caller.
 */
export function createAiConsentRoutes(
  deps: AiConsentRoutesDependencies,
  authorization: AuthorizationDependencies,
  idempotencyDependencies: IdempotencyDependencies,
): Hono<AuthorizationEnv> {
  const routes = new Hono<AuthorizationEnv>();
  const log = authorization.logger;

  function state(
    c: Context<AuthorizationEnv>,
    result: Record<string, unknown>,
    schema: { safeParse: (v: unknown) => { success: boolean; data?: unknown } },
    committed: boolean,
  ): Response {
    if (result["outcome"] !== "ok") {
      return outcomeProblem(c, String(result["outcome"]), REFUSALS, log);
    }
    const consent = result["consent"] as Record<string, unknown> | null;
    const parsed = schema.safeParse({
      access: result["access"],
      version: result["version"] ?? null,
      consent: consent
        ? {
          version: consent["version"],
          locale: consent["locale"],
          givenAt: new Date(String(consent["givenAt"])).toISOString(),
          givenAs: consent["givenAs"],
        }
        : null,
    });
    if (!parsed.success) return problem(c, "INTERNAL_ERROR", 500);
    return committed
      ? committedJson(c, parsed.data as never, 200)
      : c.json(parsed.data as never);
  }

  async function update(
    c: Context<AuthorizationEnv>,
    give: AiConsentOperation,
    withdraw: AiConsentOperation,
    extra: Record<string, unknown>,
    schema: { safeParse: (v: unknown) => { success: boolean; data?: unknown } },
  ): Promise<Response> {
    const body = validatedBody<{
      given: boolean;
      version?: string;
      locale?: "en" | "ar";
    }>(c);
    if (body.given && (!body.version || !body.locale)) {
      return problem(c, "INVALID_REQUEST", 400);
    }
    const result = await deps.repository.call(
      actorDbContext(c),
      body.given ? give : withdraw,
      body.given
        ? { ...extra, version: body.version, locale: body.locale }
        : extra,
    );
    return state(c, result, schema, true);
  }

  const getRoute = v1Route("getStudyToolsConsent");
  routes.get(
    "/v1/me/study-tools-consent",
    validateRouteInput(getRoute),
    requirePermission(authorization, "study_tools_consent.read"),
    async (c) =>
      state(
        c,
        await deps.repository.call(actorDbContext(c), "status", {}),
        getRoute.response,
        false,
      ),
  );

  const updateRoute = v1Route("updateStudyToolsConsent");
  routes.post(
    "/v1/me/study-tools-consent",
    validateRouteInput(updateRoute),
    requirePermission(authorization, "study_tools_consent.write"),
    idempotency(idempotencyDependencies, updateRoute.operationId, "required"),
    async (c) => await update(c, "give", "withdraw", {}, updateRoute.response),
  );

  const childGetRoute = v1Route("getManagedChildStudyToolsConsent");
  routes.get(
    "/v1/me/managed-children/:childId/study-tools-consent",
    validateRouteInput(childGetRoute),
    requirePermission(authorization, "managed_child.study_tools_consent"),
    async (c) =>
      state(
        c,
        await deps.repository.call(actorDbContext(c), "child_status", {
          childId: routeParam(c, "childId"),
        }),
        childGetRoute.response,
        false,
      ),
  );

  const childUpdateRoute = v1Route("updateManagedChildStudyToolsConsent");
  routes.post(
    "/v1/me/managed-children/:childId/study-tools-consent",
    validateRouteInput(childUpdateRoute),
    requirePermission(authorization, "managed_child.study_tools_consent"),
    idempotency(
      idempotencyDependencies,
      childUpdateRoute.operationId,
      "required",
    ),
    async (c) =>
      await update(
        c,
        "child_give",
        "child_withdraw",
        { childId: routeParam(c, "childId") },
        childUpdateRoute.response,
      ),
  );

  return routes;
}
