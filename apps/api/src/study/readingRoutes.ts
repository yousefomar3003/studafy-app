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
import {
  routeParam,
  validatedParams,
  validateRouteInput,
} from "../platform/validation";
import { resolvedSchoolDbContext } from "../platform/dbContext";
import { outcomeProblem } from "../platform/outcomes";
import { AI_REFUSALS } from "./metering";
import type { MaterialRepository } from "./material";

/**
 * How far a lesson's files and links have been read for the study helper,
 * and reading one again (ADR-0037). Its own group so it is mounted where the
 * catalogue lists it.
 */
export function createLessonReadingRoutes(
  deps: { material: MaterialRepository },
  authorization: AuthorizationDependencies,
  idempotencyDependencies: IdempotencyDependencies,
): Hono<AuthorizationEnv> {
  const routes = new Hono<AuthorizationEnv>();
  const refusal = (c: Context<AuthorizationEnv>, outcome: string) =>
    outcomeProblem(c, outcome, AI_REFUSALS);

  // -------------------------------------------------------------------------
  // How far a lesson's files and links have been read (ADR-0037). A teacher
  // sees any lesson they teach; a student or parent a lesson they can see.
  // -------------------------------------------------------------------------
  const materialRoute = v1Route("listLessonReading");
  routes.get(
    "/v1/resources/:resourceId/reading",
    validateRouteInput(materialRoute),
    requirePermission(
      authorization,
      "lesson_reading.read",
      (c) => validatedParams<Record<string, string>>(c).resourceId ?? null,
    ),
    async (c) => {
      const context = resolvedSchoolDbContext(c);
      const resourceId = routeParam(c, "resourceId");
      let found = await deps.material.call(context, "status", { resourceId });
      if (found["outcome"] !== "ok") {
        const lessons = await deps.material.call(context, "lessons", {
          resourceIds: [resourceId],
        });
        const lesson =
          ((lessons["lessons"] ?? []) as Record<string, unknown>[])[0];
        if (!lesson) return refusal(c, "not_found");
        found = { outcome: "ok", resourceId, sources: lesson["sources"] };
      }
      const parsed = materialRoute.response.safeParse({
        resourceId,
        sources: found["sources"] ?? [],
      });
      return parsed.success
        ? c.json(parsed.data)
        : problem(c, "INTERNAL_ERROR", 500);
    },
  );

  const retryRoute = v1Route("retryLessonReading");
  routes.post(
    "/v1/resources/:resourceId/reading/:sourceId/retry",
    validateRouteInput(retryRoute),
    requirePermission(
      authorization,
      "lesson_reading.retry",
      (c) => validatedParams<Record<string, string>>(c).resourceId ?? null,
    ),
    idempotency(idempotencyDependencies, retryRoute.operationId, "required"),
    async (c) => {
      const context = resolvedSchoolDbContext(c);
      const resourceId = routeParam(c, "resourceId");
      const found = await deps.material.call(context, "retry", {
        resourceId,
        sourceId: routeParam(c, "sourceId"),
      });
      if (found["outcome"] !== "ok") {
        return refusal(c, String(found["outcome"]));
      }
      const parsed = retryRoute.response.safeParse({
        resourceId,
        sources: found["sources"] ?? [],
      });
      return parsed.success
        ? committedJson(c, parsed.data, 200)
        : problem(c, "INTERNAL_ERROR", 500);
    },
  );

  return routes;
}
