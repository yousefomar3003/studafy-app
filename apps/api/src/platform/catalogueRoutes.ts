import { type Context, Hono } from "hono";
import type {
  V1PageQuery as V1PageQueryType,
  V1RouteContract,
} from "@studafy/contracts";
import type {
  AuthorizationDependencies,
  AuthorizationEnv,
} from "../authorization/middleware";
import { requirePermission } from "../authorization/middleware";
import type { IdempotencyDependencies } from "./idempotency";
import { idempotency } from "./idempotency";
import { problem } from "./errors";
import {
  validatedBody,
  validatedParams,
  validatedQuery,
  validateRouteInput,
} from "./validation";
import { filterHash, signCursor, verifyCursor } from "./cursor";
import type { Permission } from "../authorization/catalogue";

/**
 * Generic dispatcher shared by every `/v1` domain module (API-041 academic,
 * API-042 school-admin/invitations/family/communications/meetings/
 * notifications/account). One catalogue entry in, one chained
 * validate -> authorize -> slice-flag -> (cursor list | idempotent command)
 * -> response-schema-checked handler out. Domain-specific behaviour lives in
 * the SQL dispatcher a repository forwards to, and in the `selector`/
 * `sliceFor` functions each caller supplies — this file has no domain
 * knowledge of its own.
 */

export interface CatalogueCommandResult {
  outcome:
    | "ok"
    | "not_found"
    | "forbidden"
    | "version_conflict"
    | "invalid_state"
    | "window_closed"
    | "invalid";
  response?: unknown;
}

export interface RequestDbContext {
  subject: string;
  /**
   * Null only for self-scoped permissions (e.g. platform-operator school
   * provisioning) that have no resolved tenant to check. Every
   * resource/tenant-scoped permission always resolves a school here.
   */
  schoolId: string | null;
  requestId: string;
}

export interface CatalogueRepository {
  query(
    context: RequestDbContext,
    operation: string,
    resourceId: string | null,
    input: unknown,
  ): Promise<unknown>;
  command(
    context: RequestDbContext,
    operation: string,
    resourceId: string | null,
    input: unknown,
    reservation: { id: string; generation: number },
  ): Promise<CatalogueCommandResult>;
}

export type CatalogueSelector = (
  c: Context<AuthorizationEnv>,
  route: V1RouteContract,
) => string | null;

export interface CatalogueRoutesOptions<Slice extends string> {
  routes: readonly V1RouteContract[];
  repository: CatalogueRepository;
  cursorSigningKey: string;
  selector: CatalogueSelector;
  sliceFor: (operationId: string) => Slice;
  enabledSlices?: Partial<Record<Slice, boolean>>;
}

export function honoPath(path: string): string {
  return path.replaceAll(/\{([^}]+)\}/g, ":$1");
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

export function createCatalogueRoutes<Slice extends string>(
  options: CatalogueRoutesOptions<Slice>,
  authorization: AuthorizationDependencies,
  idempotencyDependencies: IdempotencyDependencies,
): Hono<AuthorizationEnv> {
  const { routes: catalogue, repository, cursorSigningKey, selector, sliceFor, enabledSlices } =
    options;
  const routes = new Hono<AuthorizationEnv>();

  for (const route of catalogue) {
    const path = honoPath(route.path);
    const permission = route.permission as Permission;
    const available = async (
      c: Context<AuthorizationEnv>,
      next: () => Promise<void>,
    ) => {
      if (enabledSlices?.[sliceFor(route.operationId)] === false) {
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
            cursorSigningKey,
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
        const result = await repository.query(
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
          return switchOutcome(c as never, result["outcome"] as string);
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
                ? await signCursor(cursorSigningKey, {
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
        if (!reservation) return problem(c, "FORBIDDEN", 403);
        const result = await repository.command(
          {
            subject: actor.token.subject,
            schoolId: tenant?.schoolId ?? null,
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
          return switchOutcome(c as never, result.outcome);
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
