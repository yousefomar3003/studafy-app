import { describe, expect, test } from "bun:test";
import { type LogLevel, V1_ROUTE_CATALOGUE } from "@studafy/contracts";
import { createJsonLogger } from "@studafy/observability";
import { LogCollector } from "@studafy/test-support";
import { Hono } from "hono";
import { createAuthRoutes } from "../../src/auth/routes";
import { createAcademicRoutes } from "../../src/academic/routes";
import { createSchoolAdminRoutes } from "../../src/school-admin/routes";
import { createInvitationsRoutes } from "../../src/invitations/routes";
import { createFamilyRoutes } from "../../src/family/routes";
import { createCommunicationsRoutes } from "../../src/communications/routes";
import { JwksKeySource } from "../../src/auth/jwks";
import type { AuthorizationEnv } from "../../src/authorization/middleware";
import {
  AUTH_HANDLER_PERMISSIONS,
  isPermission,
  PERMISSION_CATALOGUE,
  PERMISSIONS,
} from "../../src/authorization/catalogue";
import { declaredPermission } from "../../src/authorization/middleware";
import { FakeAuthRepository } from "../auth/fake-repository";
import { FakeIdempotencyRepository } from "../platform/fake-idempotency";
import { VersionedTenantContextCache } from "../../src/authorization/cache";

function routeTable() {
  const logger = createJsonLogger(
    "api",
    "auth031-test",
    "debug" as LogLevel,
    new LogCollector().sink,
  );
  const repository = new FakeAuthRepository();
  const authDependencies = {
    keys: new JwksKeySource("https://unused.test/jwks"),
    repository: repository.asRepository(),
    logger,
    issuer: "https://unused.test/auth/v1",
    audience: "authenticated",
    clockSkewSeconds: 0,
    revocationBudgetSeconds: 0,
    reauthTtlSeconds: 300,
    deletionGraceDays: 14,
  };
  const authorization = {
    logger,
    cache: new VersionedTenantContextCache(),
    repository: {
      authorize: async () => ({
        allowed: true,
        schoolId: "bbbbbbbb-0000-4000-8000-000000000001",
        reason: "allowed" as const,
      }),
    },
  };
  const idempotency = { logger, repository: new FakeIdempotencyRepository() };
  const academic = createAcademicRoutes(
    {
      cursorSigningKey: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
      repository: {
        query: async () => null,
        command: async () => ({ outcome: "invalid" as const }),
      },
    },
    authorization,
    idempotency,
  );
  const schoolAdmin = createSchoolAdminRoutes(
    {
      cursorSigningKey: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
      repository: {
        query: async () => null,
        command: async () => ({ outcome: "invalid" as const }),
      },
    },
    authorization,
    idempotency,
  );
  const invitations = createInvitationsRoutes(
    {
      cursorSigningKey: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
      repository: {
        query: async () => null,
        command: async () => ({ outcome: "invalid" as const }),
      },
    },
    authorization,
    idempotency,
  );
  const family = createFamilyRoutes(
    {
      cursorSigningKey: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
      repository: {
        query: async () => null,
        command: async () => ({ outcome: "invalid" as const }),
      },
    },
    authorization,
    idempotency,
  );
  const communications = createCommunicationsRoutes(
    {
      cursorSigningKey: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
      repository: {
        query: async () => null,
        command: async () => ({ outcome: "invalid" as const }),
      },
    },
    authorization,
    idempotency,
  );
  const combined = new Hono<AuthorizationEnv>();
  combined.route("/", academic);
  combined.route("/", schoolAdmin);
  combined.route("/", invitations);
  combined.route("/", family);
  combined.route("/", communications);
  const routes = createAuthRoutes(
    authDependencies,
    authorization,
    idempotency,
    combined,
  );
  return routes;
}

describe("permission catalogue", () => {
  test("has unique stable names and complete definitions", () => {
    expect(new Set(PERMISSIONS).size).toBe(PERMISSIONS.length);
    for (const permission of PERMISSIONS) {
      expect(isPermission(permission)).toBe(true);
      expect(PERMISSION_CATALOGUE[permission].resource.length).toBeGreaterThan(
        0,
      );
      expect(PERMISSION_CATALOGUE[permission].description.endsWith(".")).toBe(
        true,
      );
    }
    expect(isPermission("attacker.become_admin")).toBe(false);
  });

  test("the private database evaluator covers every resource action exactly", async () => {
    const authMigration = await Bun.file(
      `${import.meta.dir}/../../../../supabase/migrations/202609140001_auth031_authorization.sql`,
    ).text();
    const academicMigration = await Bun.file(
      `${import.meta.dir}/../../../../supabase/migrations/202609150002_api041_authoritative_surface.sql`,
    ).text();
    const schoolAdminMigration = await Bun.file(
      `${import.meta.dir}/../../../../supabase/migrations/202609160002_api042_school_operations.sql`,
    ).text();
    const invitationsMigration = await Bun.file(
      `${import.meta.dir}/../../../../supabase/migrations/202609160003_api042_invitations.sql`,
    ).text();
    const familyMigration = await Bun.file(
      `${import.meta.dir}/../../../../supabase/migrations/202609160004_api042_family.sql`,
    ).text();
    const communicationsMigration = await Bun.file(
      `${import.meta.dir}/../../../../supabase/migrations/202609160005_api042_communications.sql`,
    ).text();
    const cataloguedResourceActions = PERMISSIONS.filter((permission) =>
      PERMISSION_CATALOGUE[permission].scope === "resource"
    ).sort();

    for (const permission of cataloguedResourceActions) {
      expect(
        `${authMigration}\n${academicMigration}\n${schoolAdminMigration}\n${invitationsMigration}\n${familyMigration}\n${communicationsMigration}`,
      ).toContain(`'${permission}'`);
    }
  });

  test("every protected handler has exactly its declared permission middleware", () => {
    const routes = routeTable().routes;
    const protectedRoutes = [
      ...new Set(
        routes
          .filter((route) =>
            route.path.startsWith("/v1/") && route.method !== "ALL"
          )
          .map((route) => `${route.method} ${route.path}`),
      ),
    ];
    expect(protectedRoutes).toEqual(
      AUTH_HANDLER_PERMISSIONS.map((declaration) =>
        `${declaration.method} ${declaration.path}`
      ),
    );

    const actual = routes
      .map((route) => ({
        method: route.method,
        path: route.path,
        permission: declaredPermission(route.handler),
      }))
      .filter((route) => route.permission !== null);

    expect(actual).toEqual([...AUTH_HANDLER_PERMISSIONS]);

    for (const declaration of AUTH_HANDLER_PERMISSIONS) {
      const handlers = routes.filter((route) =>
        route.method === declaration.method && route.path === declaration.path
      );
      expect(
        handlers.filter((route) =>
          declaredPermission(route.handler) === declaration.permission
        ),
      ).toHaveLength(1);
    }
  });

  test("the route contract catalogue exactly covers every mounted v1 handler", () => {
    const mounted = [
      ...new Set(
        routeTable().routes
          .filter((route) =>
            route.path.startsWith("/v1/") && route.method !== "ALL"
          )
          .map((route) => `${route.method} ${route.path}`),
      ),
    ];
    const contracted = V1_ROUTE_CATALOGUE.map((route) =>
      `${route.method.toUpperCase()} ${
        route.path.replaceAll(/\{([^}]+)\}/g, ":$1")
      }`
    );
    expect(mounted).toEqual(contracted);
    expect(JSON.stringify(V1_ROUTE_CATALOGUE.map((route) => ({
      method: route.method.toUpperCase(),
      path: route.path.replaceAll(/\{([^}]+)\}/g, ":$1"),
      permission: route.permission,
    })))).toBe(JSON.stringify(AUTH_HANDLER_PERMISSIONS));
    expect(
      V1_ROUTE_CATALOGUE.some((route) =>
        route.operationId === "createClassroom"
      ),
    ).toBe(true);
  });

  test("command idempotency modes are explicit and reauth verification is never replayed", () => {
    for (const route of V1_ROUTE_CATALOGUE) {
      expect(["none", "required", "forbidden"]).toContain(route.idempotency);
      if (route.method === "get") expect(route.idempotency).toBe("none");
    }
    expect(
      V1_ROUTE_CATALOGUE.find((route) => route.operationId === "verifyReauth")
        ?.idempotency,
    )
      .toBe("forbidden");
    expect(
      V1_ROUTE_CATALOGUE.filter((route) =>
        route.method === "post" && route.operationId !== "verifyReauth"
      )
        .every((route) => route.idempotency === "required"),
    ).toBe(true);
  });

  test("every declared protected handler enforces its self permission", async () => {
    const app = routeTable();
    for (const declaration of AUTH_HANDLER_PERMISSIONS) {
      const response = await app.request(declaration.path, {
        method: declaration.method,
        headers: { "content-type": "application/json" },
        body: declaration.method === "POST" ? "{}" : undefined,
      });
      expect(response.status, `${declaration.method} ${declaration.path}`).toBe(
        401,
      );
    }
  });
});
