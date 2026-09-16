/**
 * Builds the same request pipeline apps/api/src/index.ts assembles for
 * production, minus the modules a given operational script does not need,
 * for use outside a running server process (e.g. scripts/seed-reviewer-
 * tenant.ts). Lives here rather than in the script itself so the script -
 * outside any package's node_modules - never has to resolve `hono` or any
 * other apps/api-only dependency directly.
 */
import { Hono, type MiddlewareHandler } from "hono";
import type { Sql } from "@studafy/database";
import { createJsonLogger } from "@studafy/observability";
import { requestContext } from "../platform/middleware";
import { AuthContextRepository } from "../auth/context";
import { JwksKeySource } from "../auth/jwks";
import { createAuthRoutes } from "../auth/routes";
import type { AuthDependencies } from "../auth/middleware";
import type { AuthorizationEnv } from "../authorization/middleware";
import { createAuthorizationDependencies } from "../authorization/middleware";
import { PostgresAuthorizationRepository } from "../authorization/repository";
import { PostgresIdempotencyRepository } from "../platform/idempotency";
import { createAcademicRoutes } from "../academic/routes";
import { PostgresAcademicRepository } from "../academic/repository";
import { createSchoolAdminRoutes, createSchoolRosterRoutes } from "../school-admin/routes";
import { PostgresSchoolAdminRepository } from "../school-admin/repository";
import { createInvitationsRoutes } from "../invitations/routes";
import { PostgresInvitationsRepository } from "../invitations/repository";
import { createFamilyRoutes } from "../family/routes";
import { PostgresFamilyRepository } from "../family/repository";

export function buildReviewerSeedApp(
  sql: Sql,
  supabaseApiUrl: string,
): Hono<AuthorizationEnv> {
  const logger = createJsonLogger("api", "seed-reviewer-tenant", "warn", () => undefined);
  const authDependencies: AuthDependencies = {
    keys: new JwksKeySource(`${supabaseApiUrl}/auth/v1/.well-known/jwks.json`),
    repository: new AuthContextRepository(sql),
    logger,
    issuer: `${supabaseApiUrl}/auth/v1`,
    audience: "authenticated",
    clockSkewSeconds: 30,
    revocationBudgetSeconds: 0,
    reauthTtlSeconds: 300,
    deletionGraceDays: 14,
  };
  const authorization = createAuthorizationDependencies(
    logger,
    new PostgresAuthorizationRepository(sql),
  );
  const idempotency = { logger, repository: new PostgresIdempotencyRepository(sql) };
  const cursorSigningKey = "seed-reviewer-tenant-unused-cursor-key-0000";

  const combined = new Hono<AuthorizationEnv>();
  combined.route(
    "/",
    createAcademicRoutes(
      { repository: new PostgresAcademicRepository(sql), cursorSigningKey },
      authorization,
      idempotency,
    ),
  );
  combined.route(
    "/",
    createSchoolAdminRoutes(
      { repository: new PostgresSchoolAdminRepository(sql), cursorSigningKey },
      authorization,
      idempotency,
      authDependencies,
    ),
  );
  combined.route(
    "/",
    createInvitationsRoutes(
      { repository: new PostgresInvitationsRepository(sql), cursorSigningKey },
      authorization,
      idempotency,
    ),
  );
  combined.route(
    "/",
    createFamilyRoutes(
      { repository: new PostgresFamilyRepository(sql), cursorSigningKey },
      authorization,
      idempotency,
    ),
  );
  combined.route(
    "/",
    createSchoolRosterRoutes(
      { repository: new PostgresSchoolAdminRepository(sql), cursorSigningKey },
      authorization,
      idempotency,
    ),
  );
  // createApp() (apps/api/src/bootstrap/app.ts) normally mounts this ahead
  // of everything else; outside a real server this script never runs, so
  // it has to be applied by hand or requestId (and therefore every
  // audit_events row) would be undefined.
  const app = new Hono<AuthorizationEnv>();
  app.use("*", requestContext() as unknown as MiddlewareHandler<AuthorizationEnv>);
  app.route("/", createAuthRoutes(authDependencies, authorization, idempotency, combined));
  return app;
}
