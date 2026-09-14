import { describe, expect, test } from "bun:test";
import { type LogLevel, V1_ROUTE_CATALOGUE } from "@studafy/contracts";
import { createJsonLogger } from "@studafy/observability";
import { LogCollector } from "@studafy/test-support";
import { createAuthRoutes } from "../../src/auth/routes";
import { JwksKeySource } from "../../src/auth/jwks";
import {
  AUTH_HANDLER_PERMISSIONS,
  isPermission,
  PERMISSION_CATALOGUE,
  PERMISSIONS,
} from "../../src/authorization/catalogue";
import { declaredPermission } from "../../src/authorization/middleware";
import { FakeAuthRepository } from "../auth/fake-repository";

function routeTable() {
  const logger = createJsonLogger(
    "api",
    "auth031-test",
    "debug" as LogLevel,
    new LogCollector().sink,
  );
  const repository = new FakeAuthRepository();
  const routes = createAuthRoutes({
    keys: new JwksKeySource("https://unused.test/jwks"),
    repository: repository.asRepository(),
    logger,
    issuer: "https://unused.test/auth/v1",
    audience: "authenticated",
    clockSkewSeconds: 0,
    revocationBudgetSeconds: 0,
    reauthTtlSeconds: 300,
    deletionGraceDays: 14,
  });
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
    const migration = await Bun.file(
      `${import.meta.dir}/../../../../supabase/migrations/202609140001_auth031_authorization.sql`,
    ).text();
    const databaseActions = [
      ...migration.matchAll(/when '([a-z_]+\.[a-z_]+)' then/g),
    ].map((match) => match[1]!).sort();
    const cataloguedResourceActions = PERMISSIONS.filter((permission) =>
      PERMISSION_CATALOGUE[permission].scope === "resource"
    ).sort();

    expect(databaseActions).toEqual(cataloguedResourceActions);
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
      `${route.method.toUpperCase()} ${route.path}`
    );
    expect(mounted).toEqual(contracted);
    expect(JSON.stringify(V1_ROUTE_CATALOGUE.map((route) => ({
      method: route.method.toUpperCase(),
      path: route.path,
      permission: route.permission,
    })))).toBe(JSON.stringify(AUTH_HANDLER_PERMISSIONS));
    expect(
      V1_ROUTE_CATALOGUE.some((route) =>
        String(route.path) === "/v1/classrooms"
      ),
    ).toBe(false);
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
