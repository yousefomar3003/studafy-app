import { describe, expect, test } from "bun:test";
import { type LogLevel, V1_ROUTE_CATALOGUE } from "@studafy/contracts";
import { createJsonLogger } from "@studafy/observability";
import { LogCollector } from "@studafy/test-support";
import { Hono } from "hono";
import { createAuthRoutes } from "../../src/auth/routes";
import {
  createAcademicAppendedRoutes,
  createAcademicRoutes,
} from "../../src/academic/routes";
import {
  createSchoolAdminRoutes,
  createSchoolRosterRoutes,
} from "../../src/school-admin/routes";
import { createInvitationsRoutes } from "../../src/invitations/routes";
import {
  createFamilyReadRoutes,
  createFamilyRoutes,
  createStudentFamilyRoutes,
} from "../../src/family/routes";
import { createClassJoinRoutes } from "../../src/class-join/routes";
import {
  createCommunicationsRoutes,
  createContactsRoutes,
} from "../../src/communications/routes";
import { createMeetingsRoutes } from "../../src/meetings/routes";
import {
  createNotificationsRoutes,
  createPushDeviceRoutes,
} from "../../src/notifications/routes";
import {
  createAccountReadRoutes,
  createAccountRoutes,
} from "../../src/account/routes";
import { createSupportAccessRoutes } from "../../src/support-access/routes";
import { createSafetyRoutes } from "../../src/safety/routes";
import { createFileRoutes } from "../../src/files/routes";
import { createBillingRoutes } from "../../src/billing/routes";
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
    authDependencies,
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
  const classJoin = createClassJoinRoutes(
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
  const meetings = createMeetingsRoutes(
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
  const notifications = createNotificationsRoutes(
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
  const account = createAccountRoutes(
    {
      cursorSigningKey: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
      repository: {
        query: async () => null,
        command: async () => ({ outcome: "invalid" as const }),
      },
    },
    authorization,
    idempotency,
    authDependencies,
  );
  const supportAccess = createSupportAccessRoutes(
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
  const schoolRoster = createSchoolRosterRoutes(
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
  const safety = createSafetyRoutes(
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
  const files = createFileRoutes(
    {
      newIntentsEnabled: false,
      repository: {
        prepareIntent: async () => ({ outcome: "invalid" }),
        issueIntent: async () => ({ outcome: "invalid" }),
        query: async () => ({ outcome: "not_found" }),
        prepareCompletion: async () => ({ outcome: "not_found" }),
        complete: async () => ({ outcome: "invalid" }),
        publish: async () => ({ outcome: "invalid" }),
        createDownloadGrant: async () => ({ outcome: "invalid" }),
        consumeDownloadGrant: async () => ({ outcome: "grant_invalid" }),
      },
      storage: {
        createUploadCapability: async () => {
          throw new Error("disabled");
        },
        inspect: async () => ({ exists: false }),
        delete: async () => undefined,
        openObject: async () => {
          throw new Error("disabled");
        },
        replaceObject: async () => undefined,
      },
    },
    authorization,
    idempotency,
  );
  const billing = createBillingRoutes(
    {
      environment: "synthetic",
      apple: null,
      google: null,
      repository: {
        catalogue: async () => ({ products: [] }),
        selfPurchaseStatus: async () => [],
        setSelfPurchase: async () => false,
        submitVerification: async () => ({ outcome: "invalid" }),
        restore: async () => ({ outcome: "invalid" }),
        requestPurchaseApproval: async () => ({ outcome: "invalid" }),
        listPurchaseApprovals: async () => [],
        decidePurchaseApproval: async () => ({ outcome: "invalid" }),
        listEntitlements: async () => [],
        recordEvent: async () => ({ outcome: "duplicate" as const }),
      },
    },
    authorization,
    idempotency,
    authDependencies as never,
  );
  const combined = new Hono<AuthorizationEnv>();
  combined.route("/", academic);
  combined.route("/", schoolAdmin);
  combined.route("/", invitations);
  combined.route("/", family);
  combined.route("/", communications);
  combined.route("/", meetings);
  combined.route("/", notifications);
  combined.route("/", account);
  combined.route("/", supportAccess);
  combined.route("/", schoolRoster);
  combined.route("/", safety);
  combined.route("/", files);
  combined.route("/", billing);
  combined.route(
    "/",
    createContactsRoutes(
      {
        cursorSigningKey: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        repository: {
          query: async () => null,
          command: async () => ({ outcome: "invalid" as const }),
        },
      },
      authorization,
      idempotency,
    ),
  );
  combined.route(
    "/",
    createFamilyReadRoutes(
      {
        cursorSigningKey: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        repository: {
          query: async () => null,
          command: async () => ({ outcome: "invalid" as const }),
        },
      },
      authorization,
      idempotency,
    ),
  );
  combined.route(
    "/",
    createAccountReadRoutes(
      {
        cursorSigningKey: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        repository: {
          query: async () => null,
          command: async () => ({ outcome: "invalid" as const }),
        },
      },
      authorization,
      idempotency,
    ),
  );
  combined.route(
    "/",
    createPushDeviceRoutes(
      {
        cursorSigningKey: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        repository: {
          query: async () => null,
          command: async () => ({ outcome: "invalid" as const }),
        },
      },
      authorization,
      idempotency,
    ),
  );
  // Last: these routes are appended at the end of the contract catalogue,
  // and this suite asserts mount order equals catalogue order.
  combined.route("/", classJoin);
  combined.route(
    "/",
    createAcademicAppendedRoutes(
      {
        cursorSigningKey: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        repository: {
          query: async () => null,
          command: async () => ({ outcome: "invalid" as const }),
        },
      },
      authorization,
      idempotency,
    ),
  );
  combined.route(
    "/",
    createStudentFamilyRoutes(
      {
        cursorSigningKey: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        repository: {
          query: async () => null,
          command: async () => ({ outcome: "invalid" as const }),
        },
      },
      authorization,
      idempotency,
    ),
  );
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
    const meetingsMigration = await Bun.file(
      `${import.meta.dir}/../../../../supabase/migrations/202609160006_api042_meetings.sql`,
    ).text();
    const supportAccessMigration = await Bun.file(
      `${import.meta.dir}/../../../../supabase/migrations/202609160009_api042_support_access.sql`,
    ).text();
    const rosterMigration = await Bun.file(
      `${import.meta.dir}/../../../../supabase/migrations/202609160011_api042_terms_students.sql`,
    ).text();
    const safetySchemaMigration = await Bun.file(
      `${import.meta.dir}/../../../../supabase/migrations/202609170001_safe043_safety_schema.sql`,
    ).text();
    const safetySurfaceMigration = await Bun.file(
      `${import.meta.dir}/../../../../supabase/migrations/202609170002_safe043_surface.sql`,
    ).text();
    const fileMigration = await Bun.file(
      `${import.meta.dir}/../../../../supabase/migrations/202609170003_file050_upload_pipeline.sql`,
    ).text();
    const file051Migration = await Bun.file(
      `${import.meta.dir}/../../../../supabase/migrations/202609170004_file051_scan_delivery_publication.sql`,
    ).text();
    const classJoinMigration = await Bun.file(
      `${import.meta.dir}/../../../../supabase/migrations/202609200002_class_join_links.sql`,
    ).text();
    const contentPerSectionMigration = await Bun.file(
      `${import.meta.dir}/../../../../supabase/migrations/202609210002_content_per_section.sql`,
    ).text();
    const cataloguedResourceActions = PERMISSIONS.filter((permission) =>
      PERMISSION_CATALOGUE[permission].scope === "resource"
    ).sort();

    for (const permission of cataloguedResourceActions) {
      expect(
        `${authMigration}\n${academicMigration}\n${schoolAdminMigration}\n${invitationsMigration}\n${familyMigration}\n${communicationsMigration}\n${meetingsMigration}\n${supportAccessMigration}\n${rosterMigration}\n${safetySchemaMigration}\n${safetySurfaceMigration}\n${fileMigration}\n${file051Migration}\n${classJoinMigration}\n${contentPerSectionMigration}`,
      ).toContain(`'${permission}'`);
    }
  });

  test("every protected handler has exactly its declared permission middleware", () => {
    const routes = routeTable().routes;
    const protectedRoutes = [
      ...new Set(
        routes
          .filter((route) =>
            (route.path.startsWith("/v1/") ||
              route.path.startsWith("/internal/")) &&
            route.method !== "ALL"
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
            (route.path.startsWith("/v1/") ||
              route.path.startsWith("/internal/")) &&
            route.method !== "ALL"
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
