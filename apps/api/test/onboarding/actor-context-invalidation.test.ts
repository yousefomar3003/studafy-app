/**
 * The session context - memberships included - is cached per account behind a
 * generation counter with a 30 second TTL. A command whose whole purpose is to
 * give the caller their first membership therefore leaves the very next
 * /v1/me answering from an entry written while that account still belonged
 * nowhere, and the client concludes the sign-up failed.
 *
 * This was observed: createTeacherWorkspace returned 201, the row was in the
 * database, and the app still showed its "you have no class yet" screen.
 * These tests pin the bump that fixes it, and pin that it neither runs on a
 * refused command nor turns a cache outage into a failed sign-up.
 */
import { describe, expect, test } from "bun:test";
import { Hono } from "hono";
import type { LogLevel } from "@studafy/contracts";
import { createJsonLogger } from "@studafy/observability";
import type { Actor } from "../../src/auth/middleware";
import type { AuthorizationEnv } from "../../src/authorization/middleware";
import { VersionedTenantContextCache } from "../../src/authorization/cache";
import { createOnboardingRoutes } from "../../src/onboarding/routes";
import type { CatalogueCommandResult } from "../../src/platform/catalogueRoutes";
import { FakeIdempotencyRepository } from "../platform/fake-idempotency";

const SUBJECT = "4a110000-0000-4000-8000-0000000000a1";
const CURSOR_KEY = "onboarding-invalidation-cursor-key-0000001";

function buildApp(options: {
  outcome: CatalogueCommandResult;
  invalidate: (subject: string) => Promise<void>;
}) {
  const logger = createJsonLogger(
    "api",
    "onboarding-test",
    "error" as LogLevel,
    () => {},
  );
  const app = new Hono<AuthorizationEnv>();
  app.use("*", async (c, next) => {
    const actor: Actor = {
      token: {
        subject: SUBJECT,
        sessionId: null,
        issuedAt: 1,
        expiresAt: 4_000_000_000,
        assuranceLevel: "aal1",
        authMethods: [],
        claims: {},
      },
      context: {
        userId: SUBJECT,
        displayName: "New Teacher",
        locale: "en",
        profileStatus: "active",
        profileDeletedAt: null,
        revokedBefore: null,
        deletionState: null,
        // The shape this whole problem is about: signed in, belonging nowhere.
        memberships: [],
        membershipVersion: "0",
        mfaEnrolled: false,
      },
      aal2: false,
      mfaRequiredByPolicy: false,
    };
    c.set("requestId", crypto.randomUUID());
    c.set("actor", actor);
    await next();
  });
  app.route(
    "/",
    createOnboardingRoutes(
      {
        repository: {
          query: async () => null,
          command: async () => options.outcome,
        },
        cursorSigningKey: CURSOR_KEY,
        enabledSlices: { onboarding: true },
        invalidateActorContext: options.invalidate,
      },
      {
        logger,
        cache: new VersionedTenantContextCache(),
        repository: {
          authorize: async () => ({
            allowed: true,
            schoolId: null,
            reason: "allowed" as const,
          }),
        },
      },
      { logger, repository: new FakeIdempotencyRepository() },
    ),
  );
  return app;
}

function signUp(app: Hono<AuthorizationEnv>) {
  return app.request("/v1/onboarding/teacher-workspace", {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "idempotency-key": crypto.randomUUID(),
    },
    body: JSON.stringify({}),
  });
}

const created: CatalogueCommandResult = {
  outcome: "ok",
  response: {
    id: "4a110000-0000-4000-8000-0000000000b1",
    name: "New Teacher",
    timezone: "Asia/Amman",
    locale: "en",
    role: "teacher",
  },
};

describe("onboarding invalidates the caller's cached context", () => {
  test("a created workspace bumps the caller's generation", async () => {
    const invalidated: string[] = [];
    const app = buildApp({
      outcome: created,
      invalidate: async (subject) => {
        invalidated.push(subject);
      },
    });

    const res = await signUp(app);

    expect(res.status).toBe(201);
    // Without this the next /v1/me reports no memberships for up to the
    // cache TTL, and the client shows onboarding again to a teacher who
    // already has a workspace.
    expect(invalidated).toEqual([SUBJECT]);
  });

  test("a refused command leaves the cache alone", async () => {
    const invalidated: string[] = [];
    const app = buildApp({
      outcome: { outcome: "invalid_state" },
      invalidate: async (subject) => {
        invalidated.push(subject);
      },
    });

    const res = await signUp(app);

    expect(res.status).toBe(409);
    expect(invalidated).toEqual([]);
  });

  test(
    "a cache outage does not fail a sign-up that already committed",
    async () => {
      const app = buildApp({
        outcome: created,
        invalidate: async () => {
          throw new Error("redis unavailable");
        },
      });

      // The row is written either way; refusing here would tell the teacher
      // their sign-up failed while their workspace exists. Staleness is
      // bounded by the TTL instead.
      const res = await signUp(app);

      expect(res.status).toBe(201);
    },
  );
});
