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
import { validatedBody, validateRouteInput } from "../platform/validation";
import {
  type RequestDbContext,
  withRequestContext,
} from "../platform/dbContext";
import type { CatalogueCommandResult } from "../platform/dispatchRepository";
import { outcomeProblem } from "../platform/outcomes";

/**
 * Reporting an AI answer (DL-076; Google Play's AI-Generated Content
 * policy, Apple review). Separate from the safety reports, which belong to
 * a school: a student with no class can report too. The SQL files the
 * report as the caller (`private.ai_output_report_file`), completes the
 * idempotency reservation in the same transaction, and a trigger queues a
 * content-free alert for the reviewers.
 */
export interface OutputReportRepository {
  file(
    context: RequestDbContext,
    body: Record<string, unknown>,
    reservation: { id: string; generation: number },
  ): Promise<CatalogueCommandResult>;
}

export class PostgresOutputReportRepository implements OutputReportRepository {
  constructor(readonly sql: Sql) {}

  async file(
    context: RequestDbContext,
    body: Record<string, unknown>,
    reservation: { id: string; generation: number },
  ): Promise<CatalogueCommandResult> {
    return await withRequestContext(this.sql, context, async (tx) => {
      const rows = await tx<{ result: CatalogueCommandResult }[]>`
        select private.ai_output_report_file(
          ${tx.json(body as never)},
          ${reservation.id}::uuid, ${reservation.generation}
        ) as result
      `;
      return rows[0]?.result ?? { outcome: "invalid" };
    });
  }
}

export interface OutputReportRoutesDependencies {
  reports: OutputReportRepository;
}

/** A report belongs to the person, not a school. */
function selfContext(c: Context<AuthorizationEnv>): RequestDbContext {
  return {
    subject: c.get("actor").token.subject,
    schoolId: null,
    requestId: c.get("requestId"),
    aal2: c.get("actor").aal2,
  };
}

export function createOutputReportRoutes(
  deps: OutputReportRoutesDependencies,
  authorization: AuthorizationDependencies,
  idempotencyDependencies: IdempotencyDependencies,
): Hono<AuthorizationEnv> {
  const routes = new Hono<AuthorizationEnv>();
  const log = authorization.logger;

  const reportRoute = v1Route("reportAiOutput");
  routes.post(
    "/v1/me/output-reports",
    validateRouteInput(reportRoute),
    requirePermission(authorization, "output_report.create"),
    idempotency(idempotencyDependencies, reportRoute.operationId, "required"),
    async (c) => {
      const reservation = c.get("idempotencyReservation");
      if (!reservation) return problem(c, "FORBIDDEN", 403);
      const body = validatedBody<{
        feature: string;
        reason: string;
        details?: string;
        excerpt: string;
      }>(c);
      const result = await deps.reports.file(
        selfContext(c),
        {
          feature: body.feature,
          reason: body.reason,
          details: body.details ?? null,
          excerpt: body.excerpt,
        },
        reservation,
      );
      if (result.outcome !== "ok") {
        return outcomeProblem(c, result.outcome, {}, log);
      }
      const parsed = reportRoute.response.safeParse(result.response);
      if (!parsed.success) return problem(c, "INTERNAL_ERROR", 500);
      // Ids only: never the output or the person's words.
      log.info("output_report_filed", {
        request_id: c.get("requestId"),
        feature: body.feature,
        reason: body.reason,
      });
      return committedJson(c, parsed.data as never, 201);
    },
  );

  return routes;
}
