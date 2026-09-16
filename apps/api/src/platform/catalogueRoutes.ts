import { type Context, Hono, type MiddlewareHandler } from "hono";
import type {
  V1PageQuery as V1PageQueryType,
  V1RouteContract,
} from "@studafy/contracts";
import type {
  AuthorizationDependencies,
  AuthorizationEnv,
} from "../authorization/middleware";
import { requirePermission } from "../authorization/middleware";
import type { AuthDependencies } from "../auth/middleware";
import { requireAal2, requireRecentAuth } from "../auth/middleware";
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
  /**
   * Whether this session actually presented a second factor (AAL2), not
   * just whether MFA is enrolled. Most modules ignore this; support-access
   * requires it unconditionally, matching instructions.md section 7's
   * "MFA, ticket/reason, ... full audit" requirement.
   */
  aal2: boolean;
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

/**
 * instructions.md section 7's route table calls out MFA/recent-auth for
 * specific admin mutations by name (school closure, data export) - the same
 * short-lived re-confirmation AUTH-030's account-linking/deletion routes
 * already require, just reachable from the generic catalogue dispatcher
 * instead of a hand-written route. `aal2: true` stacks requireAal2() in
 * front for operations destructive enough to also need a standing second
 * factor, not just a fresh challenge (school closure; support-access uses
 * its own stricter per-request check instead, see support-access/repository.ts).
 */
export interface ReauthRequirement {
  purpose: string;
  aal2?: boolean;
}

export interface CatalogueRoutesOptions<Slice extends string> {
  routes: readonly V1RouteContract[];
  repository: CatalogueRepository;
  cursorSigningKey: string;
  selector: CatalogueSelector;
  sliceFor: (operationId: string) => Slice;
  enabledSlices?: Partial<Record<Slice, boolean>>;
  reauth?: {
    dependencies: AuthDependencies;
    requirements: Partial<Record<string, ReauthRequirement>>;
  };
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
        const query = (validatedQuery<V1PageQueryType>(c as never) ??
          {}) as V1PageQueryType;
        const filters = { ...query, cursor: undefined };
        const digest = await filterHash(filters);
        let position: string | null = null;
        if (query.cursor) {
          // A signed cursor is always school-bound; a null tenant can never
          // hold one. This is the only case a null tenant fails a GET here
          // - single-resource reads (no items/cursor in their response,
          // e.g. getMeetingStatus) intentionally allow it, for the same
          // reason message.list/send and meeting.status are not
          // tenantRequired: an invited guardian recipient often has no
          // memberships row, and the resource-level check inside the SQL
          // function is the real guard either way.
          if (!tenant) return problem(c, "CURSOR_INVALID", 400);
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
            schoolId: tenant?.schoolId ?? null,
            requestId: c.get("requestId"),
            aal2: actor.aal2,
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
              // A null tenant (a participant/recipient with no memberships
              // row - see the comment above) never gets a continuation
              // cursor, since a cursor is always school-signed; the page
              // itself is unaffected, only paging past it is unavailable.
              nextCursor: (nextPosition && tenant)
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

    const reauthRequirement = options.reauth?.requirements[route.operationId];
    const reauthMiddlewares: MiddlewareHandler<AuthorizationEnv>[] = [];
    if (reauthRequirement) {
      if (reauthRequirement.aal2) {
        reauthMiddlewares.push(requireAal2() as never);
      }
      reauthMiddlewares.push(
        requireRecentAuth(
          options.reauth!.dependencies,
          reauthRequirement.purpose,
        ) as never,
      );
    }

    routes.post(
      path,
      validate,
      authorize,
      available as never,
      idempotency(idempotencyDependencies, route.operationId, "required"),
      ...reauthMiddlewares,
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
            aal2: actor.aal2,
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
