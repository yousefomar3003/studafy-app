import { type Context, Hono } from "hono";
import {
  V1_ROUTE_CATALOGUE,
  type V1PageQuery as V1PageQueryType,
  type V1RouteContract,
} from "@studafy/contracts";
import type {
  AuthorizationDependencies,
  AuthorizationEnv,
} from "../authorization/middleware";
import { requirePermission } from "../authorization/middleware";
import type { IdempotencyDependencies } from "../platform/idempotency";
import { idempotency } from "../platform/idempotency";
import { problem } from "../platform/errors";
import {
  validatedBody,
  validatedParams,
  validatedQuery,
  validateRouteInput,
} from "../platform/validation";
import { filterHash, signCursor, verifyCursor } from "../platform/cursor";
import type { AcademicRepository } from "./repository";
import type { Permission } from "../authorization/catalogue";

export interface AcademicDependencies {
  repository: AcademicRepository;
  cursorSigningKey: string;
  enabledSlices?: Partial<Record<AcademicSlice, boolean>>;
}

export type AcademicSlice =
  | "classes"
  | "content"
  | "assignments"
  | "assessments"
  | "grades"
  | "attendance"
  | "wellbeing";

const ACADEMIC_ROUTES = V1_ROUTE_CATALOGUE.slice(12);

function honoPath(path: string): string {
  return path.replaceAll(/\{([^}]+)\}/g, ":$1");
}

function selector(
  c: Context<AuthorizationEnv>,
  route: V1RouteContract,
): string | null {
  const params = (c.get("validatedParams") ?? {}) as Record<string, string>;
  const query = (c.get("validatedQuery") ?? {}) as Record<string, string>;
  const body = (c.get("validatedBody") ?? {}) as Record<string, unknown>;
  return params["gradeResultId"] ?? params["assessmentId"] ??
    params["assignmentId"] ??
    params["resourceId"] ?? params["classroomId"] ?? params["schoolId"] ??
    query["classroomId"] ?? query["studentId"] ?? query["schoolId"] ??
    (typeof body["classroomId"] === "string" ? body["classroomId"] : null) ??
    (typeof body["schoolId"] === "string" ? body["schoolId"] : null) ??
    (route.permission === "school.read" ? params["schoolId"] ?? null : null);
}

function outcomeProblem(
  c: Context<AuthorizationEnv>,
  outcome: string,
): Response {
  return switchOutcome(c, outcome);
}

function switchOutcome(
  c: Context<AuthorizationEnv>,
  outcome: string,
): Response {
  switch (outcome) {
    case "not_found":
      return problem(c, "NOT_FOUND", 404);
    case "forbidden":
      return problem(c, "FORBIDDEN", 403);
    case "version_conflict":
      return problem(c, "VERSION_CONFLICT", 409);
    case "invalid_state":
      return problem(c, "INVALID_STATE", 409);
    case "window_closed":
      return problem(c, "WINDOW_CLOSED", 409);
    default:
      return problem(c, "INVALID_REQUEST", 400);
  }
}

function sliceFor(operation: string): AcademicSlice {
  if (/School|Term|Classroom/.test(operation)) return "classes";
  if (/Resource|LessonSession/.test(operation)) return "content";
  if (/Assignment|Submission/.test(operation)) return "assignments";
  if (/Assessment/.test(operation)) return "assessments";
  if (/Attendance/.test(operation)) return "attendance";
  if (/Wellbeing/.test(operation)) return "wellbeing";
  return "grades";
}

export function createAcademicRoutes(
  deps: AcademicDependencies,
  authorization: AuthorizationDependencies,
  idempotencyDependencies: IdempotencyDependencies,
): Hono<AuthorizationEnv> {
  const routes = new Hono<AuthorizationEnv>();

  for (const route of ACADEMIC_ROUTES) {
    const path = honoPath(route.path);
    const permission = route.permission as Permission;
    const available = async (
      c: Context<AuthorizationEnv>,
      next: () => Promise<void>,
    ) => {
      if (deps.enabledSlices?.[sliceFor(route.operationId)] === false) {
        c.res = problem(c, "SERVICE_UNAVAILABLE", 503);
        return;
      }
      await next();
    };
    const validate = validateRouteInput(route) as never;
    const authorize = requirePermission(
      authorization,
      permission,
      (c) => selector(c as never, route),
    );

    if (route.method === "get") {
      routes.get(path, validate, authorize, available as never, async (c) => {
        const actor = c.get("actor");
        const tenant = c.get("authorization").tenant;
        if (!tenant) return problem(c, "FORBIDDEN", 403);
        const query = (validatedQuery<V1PageQueryType>(c as never) ??
          {}) as V1PageQueryType;
        const filters = { ...query, cursor: undefined };
        const digest = await filterHash(filters);
        let position: string | null = null;
        if (query.cursor) {
          const decoded = await verifyCursor(
            deps.cursorSigningKey,
            query.cursor,
            {
              operation: route.operationId,
              schoolId: tenant.schoolId,
              filterHash: digest,
            },
          );
          if (!decoded) return problem(c, "CURSOR_INVALID", 400);
          position = decoded.position;
        }
        const result = await deps.repository.query(
          {
            subject: actor.token.subject,
            schoolId: tenant.schoolId,
            requestId: c.get("requestId"),
          },
          route.operationId,
          selector(c as never, route),
          { ...filters, position },
        ) as Record<string, unknown> | null;
        if (!result) return problem(c, "NOT_FOUND", 404);
        if (
          typeof result["outcome"] === "string" && result["outcome"] !== "ok"
        ) {
          return outcomeProblem(c as never, result["outcome"] as string);
        }
        const nextPosition = typeof result["nextPosition"] === "string"
          ? result["nextPosition"]
          : null;
        const { nextPosition: _nextPosition, outcome: _outcome, ...payload } =
          result;
        const response = {
          ...payload,
          ...(Object.hasOwn(payload, "items")
            ? {
              nextCursor: nextPosition
                ? await signCursor(deps.cursorSigningKey, {
                  version: 1,
                  filterVersion: 1,
                  operation: route.operationId,
                  schoolId: tenant.schoolId,
                  filterHash: digest,
                  position: nextPosition,
                })
                : null,
            }
            : {}),
        };
        const parsed = route.response.safeParse(response);
        if (!parsed.success) return problem(c, "INTERNAL_ERROR", 500);
        return c.json(parsed.data as never);
      });
      continue;
    }

    routes.post(
      path,
      validate,
      authorize,
      available as never,
      idempotency(idempotencyDependencies, route.operationId, "required"),
      async (c) => {
        const successStatus = "successStatus" in route
          ? route.successStatus ?? 200
          : 200;
        const actor = c.get("actor");
        const tenant = c.get("authorization").tenant;
        const reservation = c.get("idempotencyReservation");
        if (!tenant || !reservation) return problem(c, "FORBIDDEN", 403);
        const result = await deps.repository.command(
          {
            subject: actor.token.subject,
            schoolId: tenant.schoolId,
            requestId: c.get("requestId"),
          },
          route.operationId,
          selector(c as never, route),
          {
            body: validatedBody(c as never),
            params: validatedParams(c as never),
            responseStatus: successStatus,
          },
          reservation,
        );
        if (result.outcome !== "ok") {
          return outcomeProblem(c as never, result.outcome);
        }
        const parsed = route.response.safeParse(result.response);
        if (!parsed.success) return problem(c, "INTERNAL_ERROR", 500);
        c.set("idempotencyCompleted", true);
        return c.json(parsed.data as never, successStatus as never);
      },
    );
  }
  return routes;
}
