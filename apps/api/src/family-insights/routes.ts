import { type Context, Hono } from "hono";
import type { V1FamilyInsightsResponse } from "@studafy/contracts";
import { v1Route } from "@studafy/contracts";
import type {
  AuthorizationDependencies,
  AuthorizationEnv,
} from "../authorization/middleware";
import { requirePermission } from "../authorization/middleware";
import { validateRouteInput } from "../platform/validation";
import { problem } from "../platform/errors";
import { buildInsights, type InsightFacts } from "./analysis";
import type { FamilyInsightsRepository } from "./repository";

export interface FamilyInsightsDependencies {
  repository: FamilyInsightsRepository;
  now?: () => Date;
}

/**
 * Family+ : one request for everything the tab shows.
 *
 * Hand-written rather than built from the catalogue helper because the
 * response is derived, not a row set: SQL returns the child's permitted
 * facts and the analysis module turns them into signals. The paywall and the
 * guardian check both live in SQL, so a refusal here is indistinguishable
 * from having no such child.
 */
export function createFamilyInsightsRoutes(
  deps: FamilyInsightsDependencies,
  authorization: AuthorizationDependencies,
): Hono<AuthorizationEnv> {
  const routes = new Hono<AuthorizationEnv>();
  const route = v1Route("getFamilyInsights");
  const now = deps.now ?? (() => new Date());

  routes.get(
    "/v1/family/insights",
    validateRouteInput(route) as never,
    requirePermission(authorization, "family_insights.read"),
    async (c: Context<AuthorizationEnv>) => {
      const query = c.get("validatedQuery") as {
        studentId: string;
        period: "last30" | "term" | "year";
      };
      const actor = c.get("actor");

      const raw = await deps.repository.read(
        { subject: actor.token.subject, requestId: c.get("requestId") },
        query.studentId,
        query.period,
      );
      // No entitlement, no verified link, or no such child all arrive here
      // the same way. Saying which would tell an unpaid caller whether a
      // given student id exists.
      if (raw === null) return problem(c, "NOT_FOUND", 404);

      const facts: InsightFacts = {
        grades: raw.grades.map((g) => ({
          subject: g.subject,
          percent: (g.score * 100) / g.maximumScore,
          at: new Date(g.at),
        })),
        attendance: raw.attendance.map((a) => ({
          state: a.state,
          at: new Date(a.at),
        })),
        homework: raw.homework.map((h) => ({
          assignmentId: h.assignmentId,
          title: h.title,
          dueAt: new Date(h.dueAt),
          submittedAt: h.submittedAt === null ? null : new Date(h.submittedAt),
        })),
      };

      const at = now();
      const body: V1FamilyInsightsResponse = buildInsights(
        {
          studentId: raw.studentId,
          studentName: raw.studentName,
          period: raw.period,
          from: raw.from,
          to: raw.to,
          upcoming: facts.homework
            .filter((h) => h.submittedAt === null && h.dueAt > at)
            .sort((a, b) => a.dueAt.getTime() - b.dueAt.getTime())
            .slice(0, 20)
            .map((h) => ({
              assignmentId: h.assignmentId,
              title: h.title,
              dueAt: h.dueAt.toISOString(),
              submitted: false,
            })),
          wellbeing: raw.wellbeing.slice(0, 20),
        },
        facts,
        at,
      );

      const parsed = route.response.safeParse(body);
      if (!parsed.success) return problem(c, "INTERNAL_ERROR", 500);
      return c.json(parsed.data as never);
    },
  );

  return routes;
}
