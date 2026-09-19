import { describe, expect, test } from "bun:test";
import { Hono } from "hono";
import type { LogLevel } from "@studafy/contracts";
import { createJsonLogger } from "@studafy/observability";
import { LogCollector } from "@studafy/test-support";
import type { Actor } from "../../src/auth/middleware";
import { VersionedTenantContextCache } from "../../src/authorization/cache";
import {
  type AuthorizationEnv,
  requirePermission,
} from "../../src/authorization/middleware";
import type {
  ResourceAuthorizationDecision,
  ResourceAuthorizationRepository,
} from "../../src/authorization/repository";
import type { Permission } from "../../src/authorization/catalogue";
import { baseContext } from "../auth/fake-repository";

const RESOURCE = "dddddddd-0000-4000-8000-000000000001";
const SCHOOL_A = "bbbbbbbb-0000-4000-8000-000000000001";
const SCHOOL_B = "bbbbbbbb-0000-4000-8000-000000000002";

class FakeAuthorizationRepository implements ResourceAuthorizationRepository {
  decision: ResourceAuthorizationDecision = {
    allowed: true,
    schoolId: SCHOOL_A,
    reason: "allowed",
  };
  calls: { subject: string; permission: Permission; resourceId: string }[] = [];
  fail = false;

  authorize(subject: string, permission: Permission, resourceId: string) {
    this.calls.push({ subject, permission, resourceId });
    if (this.fail) return Promise.reject(new Error("database unavailable"));
    return Promise.resolve(this.decision);
  }
}

function actor(): Actor {
  return {
    token: {
      subject: baseContext().userId,
      sessionId: "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee",
      issuedAt: 1,
      expiresAt: 4_000_000_000,
      assuranceLevel: "aal1",
      authMethods: [],
      // Hostile claims are retained to prove they are never an input.
      claims: { school_id: SCHOOL_B, role: "school_admin" },
    },
    context: baseContext(),
    aal2: false,
    mfaRequiredByPolicy: false,
  };
}

function harness(repository = new FakeAuthorizationRepository()) {
  const collector = new LogCollector();
  const logger = createJsonLogger(
    "api",
    "auth031-test",
    "debug" as LogLevel,
    collector.sink,
  );
  const app = new Hono<AuthorizationEnv>();
  app.use("*", async (c, next) => {
    c.set("requestId", crypto.randomUUID());
    c.set("actor", actor());
    await next();
  });
  app.post(
    "/v1/test/assignments/:id",
    requirePermission(
      {
        repository,
        cache: new VersionedTenantContextCache(),
        logger,
      },
      "assignment.read",
      (c) => c.req.param("id") ?? null,
    ),
    async (c) => {
      const body = await c.req.json().catch(() => ({})) as Record<
        string,
        unknown
      >;
      const grant = c.get("authorization");
      return c.json({
        tenant: grant.tenant?.schoolId,
        clientSchool: body["school_id"] ?? null,
      });
    },
  );
  return { app, repository, collector };
}

describe("resource permission and tenant middleware", () => {
  test("derives tenant from the database decision, not headers, body, or JWT", async () => {
    const h = harness();
    const response = await h.app.request(`/v1/test/assignments/${RESOURCE}`, {
      method: "POST",
      headers: {
        "content-type": "application/json",
        "x-school-id": SCHOOL_B,
        "x-tenant-id": SCHOOL_B,
      },
      body: JSON.stringify({ school_id: SCHOOL_B, role: "school_admin" }),
    });

    expect(response.status).toBe(200);
    expect(await response.json()).toEqual({
      tenant: SCHOOL_A,
      clientSchool: SCHOOL_B,
    });
    expect(h.repository.calls).toEqual([{
      subject: baseContext().userId,
      permission: "assignment.read",
      resourceId: RESOURCE,
    }]);
  });

  test("conceals wrong-role and cross-tenant resource denials", async () => {
    const repository = new FakeAuthorizationRepository();
    repository.decision = {
      allowed: false,
      schoolId: SCHOOL_B,
      reason: "denied",
    };
    const h = harness(repository);
    const response = await h.app.request(`/v1/test/assignments/${RESOURCE}`, {
      method: "POST",
      body: "{}",
    });
    expect(response.status).toBe(404);
    const body = await response.json() as { code: string };
    expect(body.code).toBe("NOT_FOUND");
  });

  test("requires the fresh membership context to agree with resource school", async () => {
    const repository = new FakeAuthorizationRepository();
    repository.decision = {
      allowed: true,
      schoolId: SCHOOL_B,
      reason: "allowed",
    };
    const response = await harness(repository).app.request(
      `/v1/test/assignments/${RESOURCE}`,
      { method: "POST", body: "{}" },
    );
    expect(response.status).toBe(404);
  });

  test("does not cache resource decisions and observes a revoke race", async () => {
    const repository = new FakeAuthorizationRepository();
    const h = harness(repository);
    expect(
      (await h.app.request(`/v1/test/assignments/${RESOURCE}`, {
        method: "POST",
        body: "{}",
      })).status,
    ).toBe(200);

    repository.decision = {
      allowed: false,
      schoolId: SCHOOL_A,
      reason: "denied",
    };
    expect(
      (await h.app.request(`/v1/test/assignments/${RESOURCE}`, {
        method: "POST",
        body: "{}",
      })).status,
    ).toBe(404);
    expect(repository.calls).toHaveLength(2);
  });

  test("fails closed when the authorization store is unavailable", async () => {
    const repository = new FakeAuthorizationRepository();
    repository.fail = true;
    const h = harness(repository);
    const response = await h.app.request(`/v1/test/assignments/${RESOURCE}`, {
      method: "POST",
      body: "{}",
    });
    expect(response.status).toBe(404);
    expect(
      h.collector.parsed().some((entry) =>
        entry.event === "authorization_decision_failed"
      ),
    ).toBe(true);
  });
});

describe("privileged MFA boundary", () => {
  for (
    const permission of [
      "school.provision",
      "school.close",
      "membership.grant",
      "billing.school_settings.write",
      "moderation.queue.read",
    ] as Permission[]
  ) {
    test(`${permission} rejects AAL1 administrators even with a false cached policy flag`, async () => {
      const a = actor();
      a.context.memberships[0]!.role = "school_admin";
      a.mfaRequiredByPolicy = false;
      const logger = createJsonLogger(
        "api",
        "mfa-test",
        "error",
        () => undefined,
      );
      const app = new Hono<AuthorizationEnv>();
      app.use("*", async (c, next) => {
        c.set("actor", a);
        c.set("requestId", crypto.randomUUID());
        await next();
      });
      app.get(
        "/",
        requirePermission(
          {
            logger,
            cache: new VersionedTenantContextCache(),
            repository: new FakeAuthorizationRepository(),
          },
          permission,
          () => RESOURCE,
        ),
        (c) => c.json({ ok: true }),
      );
      const response = await app.request("/");
      expect(response.status).toBe(403);
      expect(((await response.json()) as { code: string }).code).toBe(
        "MFA_REQUIRED",
      );
      a.aal2 = true;
      expect((await app.request("/")).status).toBe(200);
    });
  }
  test("a platform operator with no school membership still needs AAL2", async () => {
    const a = actor();
    a.context.memberships = [];
    const logger = createJsonLogger(
      "api",
      "mfa-test",
      "error",
      () => undefined,
    );
    const app = new Hono<AuthorizationEnv>();
    app.use("*", async (c, next) => {
      c.set("actor", a);
      c.set("requestId", crypto.randomUUID());
      await next();
    });
    app.get(
      "/",
      requirePermission(
        { logger, cache: new VersionedTenantContextCache() },
        "school.provision",
      ),
      (c) => c.json({ ok: true }),
    );
    expect((await app.request("/")).status).toBe(403);
  });
});
