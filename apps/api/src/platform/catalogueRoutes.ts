import { type Context, Hono, type MiddlewareHandler } from "hono";
import {
  V1_ROUTE_CATALOGUE,
  type V1CatalogueRoute,
  type V1OperationId,
  type V1PageQuery as V1PageQueryType,
} from "@studafy/contracts";
import type {
  AuthorizationDependencies,
  AuthorizationEnv,
} from "../authorization/middleware";
import { requirePermission } from "../authorization/middleware";
import type { AuthDependencies } from "../auth/middleware";
import { requireAal2, requireRecentAuth } from "../auth/middleware";
import type { IdempotencyDependencies } from "./idempotency";
import { committedJson, idempotency } from "./idempotency";
import { problem } from "./errors";
import {
  validatedBody,
  validatedParams,
  validatedQuery,
  validateRouteInput,
} from "./validation";
import { filterHash, signCursor, verifyCursor } from "./cursor";
import type { CatalogueRepository } from "./dispatchRepository";
import { membershipDbContext } from "./dbContext";
import type { Permission } from "../authorization/catalogue";
import { outcomeProblem, type OutcomeTable } from "./outcomes";

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

export type CatalogueSelector = (
  c: Context<AuthorizationEnv>,
  route: V1CatalogueRoute,
) => string | null;

/**
 * docs/planning/instructions.md section 7's route table calls out MFA/recent-auth for
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
  routes: readonly V1CatalogueRoute[];
  repository: CatalogueRepository;
  cursorSigningKey: string;
  selector: CatalogueSelector;
  sliceFor: (operationId: string) => Slice;
  enabledSlices?: Partial<Record<Slice, boolean>>;
  reauth?: {
    dependencies: AuthDependencies;
    requirements: Partial<Record<string, ReauthRequirement>>;
  };
  /**
   * Operations whose success changes the CALLER's own session context.
   *
   * That context - memberships included - is cached per account behind a
   * generation counter, so a command that gives an account its first
   * membership leaves the very next /v1/me telling the client it still
   * belongs nowhere. Naming the operation here bumps the generation the
   * moment it succeeds. Only commands that change the caller's own
   * memberships belong here; changing somebody else's is not this account's
   * context.
   */
  actorContextChangedBy?: {
    operations: ReadonlySet<string>;
    invalidate: (subject: string) => Promise<void>;
  };
}

export function honoPath(path: string): string {
  return path.replaceAll(/\{([^}]+)\}/g, ":$1");
}

/** Refusals particular to catalogue modules; the rest are common. */
const CATALOGUE_OUTCOMES: OutcomeTable = {
  messaging_disabled: ["MESSAGING_DISABLED", 403],
  contact_not_allowed: ["CONTACT_NOT_ALLOWED", 403],
};

export function createCatalogueRoutes<Slice extends string>(
  options: CatalogueRoutesOptions<Slice>,
  authorization: AuthorizationDependencies,
  idempotencyDependencies: IdempotencyDependencies,
): Hono<AuthorizationEnv> {
  const {
    routes: catalogue,
    repository,
    cursorSigningKey,
    selector,
    sliceFor,
    enabledSlices,
  } = options;
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
    const validate = validateRouteInput<AuthorizationEnv>(route);
    const authorize = requirePermission(
      authorization,
      permission,
      (c) => selector(c, route),
    );

    if (route.method === "get") {
      routes.get(path, validate, authorize, available as never, async (c) => {
        const actor = c.get("actor");
        const tenant = c.get("authorization").tenant;
        // A caller with no memberships row (a verified guardian, an invited
        // meeting recipient) has no tenant. Their cursor is bound to their
        // own account instead, so it cannot be replayed by anyone else; the
        // SQL function re-authorizes the resource on every page regardless.
        const cursorBinding = tenant?.schoolId ??
          `actor:${actor.token.subject}`;
        const query = (validatedQuery<V1PageQueryType>(c) ??
          {}) as V1PageQueryType;
        const filters = { ...query, cursor: undefined };
        const digest = await filterHash(filters);
        let position: string | null = null;
        if (query.cursor) {
          // The cursor is bound to the school, or to the caller's own
          // account when there is no tenant (see cursorBinding above).
          const decoded = await verifyCursor(
            cursorSigningKey,
            query.cursor,
            {
              operation: route.operationId,
              schoolId: cursorBinding,
              filterHash: digest,
            },
          );
          if (!decoded) return problem(c, "CURSOR_INVALID", 400);
          position = decoded.position;
        }
        const result = await repository.query(
          membershipDbContext(c),
          route.operationId,
          selector(c, route),
          { ...filters, position },
        ) as Record<string, unknown> | null;
        if (!result) return problem(c, "NOT_FOUND", 404);
        if (
          typeof result["outcome"] === "string" && result["outcome"] !== "ok"
        ) {
          return outcomeProblem(
            c,
            result["outcome"] as string,
            CATALOGUE_OUTCOMES,
            authorization.logger,
          );
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
                  schoolId: cursorBinding,
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
        const reservation = c.get("idempotencyReservation");
        if (!reservation) return problem(c, "FORBIDDEN", 403);
        const result = await repository.command(
          membershipDbContext(c),
          route.operationId,
          selector(c, route),
          {
            body: validatedBody(c),
            params: validatedParams(c),
            responseStatus: successStatus,
          },
          reservation,
        );
        if (result.outcome !== "ok") {
          return outcomeProblem(
            c,
            result.outcome,
            CATALOGUE_OUTCOMES,
            authorization.logger,
            result.rows,
          );
        }
        const parsed = route.response.safeParse(result.response);
        if (!parsed.success) return problem(c, "INTERNAL_ERROR", 500);
        const contextChange = options.actorContextChangedBy;
        if (contextChange?.operations.has(route.operationId)) {
          try {
            await contextChange.invalidate(c.get("actor").token.subject);
          } catch (error) {
            // The write already committed. A stale cache corrects itself
            // within the entry's TTL, so this must never fail the command.
            authorization.logger?.warn("actor_context_invalidate_failed", {
              operation: route.operationId,
              error_kind: error instanceof Error ? error.name : "unknown",
            });
          }
        }
        return committedJson(c, parsed.data as never, successStatus as never);
      },
    );
  }
  return routes;
}

/**
 * A module's routes, by name, in catalogue order.
 *
 * Modules used to take a positional slice of the catalogue
 * (`V1_ROUTE_CATALOGUE.slice(52, 64)`), so adding a route anywhere but the end
 * silently moved routes between modules. Naming them makes a module's surface
 * explicit and fails at startup if a name is wrong.
 */
export function catalogueRoutesNamed(
  operationIds: readonly V1OperationId[],
): readonly V1CatalogueRoute[] {
  const wanted = new Set<string>(operationIds);
  const routes = V1_ROUTE_CATALOGUE.filter((route) =>
    wanted.delete(route.operationId)
  );
  if (wanted.size > 0) {
    throw new Error(`unknown catalogue operations: ${[...wanted].join(", ")}`);
  }
  return routes;
}
