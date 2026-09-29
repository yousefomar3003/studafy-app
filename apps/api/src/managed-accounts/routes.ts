import { type Context, Hono } from "hono";
import { v1Route } from "@studafy/contracts";
import {
  ManagedAccountError,
  type ManagedAccountIssuer,
} from "@studafy/infrastructure";
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
import type { RequestDbContext } from "../platform/dbContext";
import type { ManagedAccountRepository } from "./repository";

export interface ManagedAccountRoutesDependencies {
  repository: ManagedAccountRepository;
  issuer: ManagedAccountIssuer;
}

const REFUSALS: OutcomeTable = {
  limit_reached: ["MANAGED_CHILD_LIMIT", 409],
};

/**
 * Managed child accounts (2026-09-28): a parent creates a student account
 * for a child who has no email or phone, and switches into it.
 *
 * Hand-written because creating one spans Supabase Auth and the database:
 * the account is made first, then registered, and removed again if the
 * registration is refused, so no orphan identity is left behind.
 */
export function createManagedAccountRoutes(
  deps: ManagedAccountRoutesDependencies,
  authorization: AuthorizationDependencies,
  idempotencyDependencies: IdempotencyDependencies,
): Hono<AuthorizationEnv> {
  const routes = new Hono<AuthorizationEnv>();
  const log = authorization.logger;

  // Not a school's: whose children these are is the caller's own business.
  const context = (c: Context<AuthorizationEnv>): RequestDbContext => ({
    subject: c.get("actor").token.subject,
    schoolId: null,
    requestId: c.get("requestId"),
    aal2: c.get("actor").aal2,
  });

  const listRoute = v1Route("listManagedChildren");
  routes.get(
    "/v1/me/managed-children",
    validateRouteInput(listRoute),
    requirePermission(authorization, "managed_child.list"),
    async (c) => {
      const result = await deps.repository.call(context(c), "list", {});
      if (result["outcome"] !== "ok") {
        return outcomeProblem(c, String(result["outcome"]), REFUSALS, log);
      }
      const parsed = listRoute.response.safeParse({ items: result["items"] });
      return parsed.success
        ? c.json(parsed.data)
        : problem(c, "INTERNAL_ERROR", 500);
    },
  );

  const createRoute = v1Route("createManagedChild");
  routes.post(
    "/v1/me/managed-children",
    validateRouteInput(createRoute),
    requirePermission(authorization, "managed_child.create"),
    idempotency(idempotencyDependencies, createRoute.operationId, "required"),
    async (c) => {
      const body = validatedBody<{
        displayName: string;
        policyVersion: string;
        locale: "en" | "ar";
      }>(c);
      const caller = c.get("actor").token.subject;

      // Refused before an identity exists, so a refusal costs nothing.
      const allowed = await deps.repository.call(context(c), "can_create", {});
      if (allowed["outcome"] !== "ok") {
        return outcomeProblem(c, String(allowed["outcome"]), REFUSALS, log);
      }

      let child;
      try {
        child = await deps.issuer.createChild(body.displayName, caller);
      } catch (error) {
        log?.warn("managed_child_create_failed", {
          stage: "identity",
          error_kind: error instanceof ManagedAccountError
            ? error.kind
            : "unknown",
        });
        return problem(c, "SERVICE_UNAVAILABLE", 503);
      }

      let registered: Record<string, unknown>;
      try {
        await deps.repository.mirrorIdentity?.({
          id: child.id,
          email: child.email,
          displayName: body.displayName,
          guardianId: caller,
        });
        registered = await deps.repository.call(context(c), "register", {
          childId: child.id,
          policyVersion: body.policyVersion,
          locale: body.locale,
        });
      } catch {
        registered = { outcome: "unavailable" };
      }
      if (registered["outcome"] !== "ok") {
        // Nobody can reach an account that was never registered, but it is
        // still an identity with a name in it: remove it.
        await deps.issuer.deleteChild(child.id).catch(() => {
          log?.error("managed_child_orphaned", { child_id: child.id });
        });
        if (registered["outcome"] === "unavailable") {
          return problem(c, "SERVICE_UNAVAILABLE", 503);
        }
        return outcomeProblem(c, String(registered["outcome"]), REFUSALS, log);
      }

      const parsed = createRoute.response.safeParse({
        childId: registered["childId"],
        displayName: registered["displayName"],
        createdAt: new Date(String(registered["createdAt"])).toISOString(),
      });
      return parsed.success
        ? committedJson(c, parsed.data, 201)
        : problem(c, "INTERNAL_ERROR", 500);
    },
  );

  const sessionRoute = v1Route("createManagedChildSession");
  routes.post(
    "/v1/me/managed-children/:childId/session",
    validateRouteInput(sessionRoute),
    requirePermission(authorization, "managed_child.session"),
    // A one-time credential: never stored, so never replayed.
    idempotency(idempotencyDependencies, sessionRoute.operationId, "forbidden"),
    async (c) => {
      const childId = routeParam(c, "childId");
      const decision = await deps.repository.call(
        context(c),
        "authorize_session",
        { childId },
      );
      if (decision["outcome"] !== "ok") {
        return outcomeProblem(c, String(decision["outcome"]), REFUSALS, log);
      }
      let tokenHash: string;
      try {
        tokenHash = await deps.issuer.signInToken(childId);
      } catch (error) {
        const kind = error instanceof ManagedAccountError
          ? error.kind
          : "unknown";
        log?.warn("managed_child_session_failed", { error_kind: kind });
        return kind === "not_managed"
          ? problem(c, "NOT_FOUND", 404)
          : problem(c, "SERVICE_UNAVAILABLE", 503);
      }
      c.header("cache-control", "no-store");
      return c.json({ tokenHash });
    },
  );

  return routes;
}
