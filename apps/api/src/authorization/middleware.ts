import type { Context, MiddlewareHandler } from "hono";
import type { Logger } from "@studafy/observability";
import { problem } from "../platform/errors";
import type { AuthEnv } from "../auth/middleware";
import { type Permission, PERMISSION_CATALOGUE } from "./catalogue";
import { type TenantContext, VersionedTenantContextCache } from "./cache";
import type { ResourceAuthorizationRepository } from "./repository";

export interface AuthorizationGrant {
  permission: Permission;
  resourceId: string | null;
  tenant: TenantContext | null;
}

export interface AuthorizationEnv extends AuthEnv {
  Variables: AuthEnv["Variables"] & {
    authorization: AuthorizationGrant;
    requiredPermission: Permission;
  };
}

export interface AuthorizationDependencies {
  repository?: ResourceAuthorizationRepository;
  cache: VersionedTenantContextCache;
  logger: Logger;
}

export type ResourceIdResolver = (
  context: Context<AuthorizationEnv>,
) => string | null;

const DECLARED_PERMISSION = Symbol("studafy.requiredPermission");

export function declaredPermission(
  handler: unknown,
): Permission | null {
  if (typeof handler !== "function") return null;
  return (handler as { [DECLARED_PERMISSION]?: Permission })[
    DECLARED_PERMISSION
  ] ?? null;
}

/**
 * Declares and enforces one permission for a handler.
 *
 * Self-scoped permissions rely on AUTH-030's verified actor. Resource-scoped
 * permissions resolve only an opaque resource id from the request; the
 * database derives its school and relationship. No school header, body value,
 * or JWT claim is consulted here.
 */
export function requirePermission(
  deps: AuthorizationDependencies,
  permission: Permission,
  resolveResourceId?: ResourceIdResolver,
): MiddlewareHandler<AuthorizationEnv> {
  const definition = PERMISSION_CATALOGUE[permission];
  const middleware: MiddlewareHandler<AuthorizationEnv> = async (c, next) => {
    c.set("requiredPermission", permission);
    const actor = c.get("actor");

    if (definition.scope === "self") {
      c.set("authorization", {
        permission,
        resourceId: actor.context.userId,
        tenant: null,
      });
      await next();
      return;
    }

    const resourceId = resolveResourceId?.(c) ?? null;
    if (!resourceId || !deps.repository) {
      return deny(deps, c, permission, resourceId, "invalid_resource");
    }

    let decision;
    try {
      decision = await deps.repository.authorize(
        actor.token.subject,
        permission,
        resourceId,
      );
    } catch {
      deps.logger.error("authorization_decision_failed", {
        request_id: c.get("requestId"),
        action: permission,
      });
      return deny(deps, c, permission, resourceId, "decision_unavailable");
    }

    if (!decision.allowed) {
      return deny(deps, c, permission, resourceId, decision.reason);
    }

    const tenant = decision.schoolId
      ? deps.cache.resolve(actor.context, decision.schoolId)
      : null;
    if (definition.tenantRequired && !tenant) {
      // A decision can only be used when the freshly loaded membership
      // context independently names the same school. A stale relationship
      // result therefore cannot manufacture tenant context.
      return deny(deps, c, permission, resourceId, "membership_mismatch");
    }

    c.set("authorization", { permission, resourceId, tenant });
    await next();
  };
  Object.defineProperty(middleware, DECLARED_PERMISSION, {
    value: permission,
    enumerable: false,
  });
  return middleware;
}

function deny(
  deps: AuthorizationDependencies,
  c: Context<AuthorizationEnv>,
  permission: Permission,
  resourceId: string | null,
  reason: string,
): Response {
  deps.logger.warn("authorization_denied", {
    request_id: c.get("requestId"),
    action: permission,
    resource_type: PERMISSION_CATALOGUE[permission].resource,
    resource_present: resourceId !== null,
    reason,
  });
  // Object denials are deliberately indistinguishable from absence. This
  // prevents cross-school UUID substitution from becoming an existence oracle.
  if (PERMISSION_CATALOGUE[permission].concealDeniedResource) {
    return problem(c, "NOT_FOUND", 404);
  }
  return problem(c, "FORBIDDEN", 403);
}

/** Default cache for a route collection; injectable tests use a fresh one. */
export function createAuthorizationDependencies(
  logger: Logger,
  repository?: ResourceAuthorizationRepository,
): AuthorizationDependencies {
  return {
    logger,
    cache: new VersionedTenantContextCache(),
    ...(repository ? { repository } : {}),
  };
}
