/**
 * Reviewer access (2026-10-15): a password session against the real
 * Supabase Auth and the real API auth stack.
 *
 * The store reviewers sign in with an email and a password Studafy set up.
 * Nothing in the API may treat that session differently from an OAuth one:
 * the same JWKS verification, the same account resolution, and the same
 * recent-sign-in rule before a grant for deletion or export (launch plan
 * 2.10). A password account must be able to satisfy that rule by signing in
 * again, and a refresh must not.
 *
 * It also pins the sign-up rule (migration 202610150050) where it matters,
 * at Supabase Auth's own endpoints: public email sign-up is refused, and
 * even the service role needs an address registered first.
 *
 * Needs the local stack's Supabase Auth as well as its database. Its URL and
 * service key are read from variables of their own, never SUPABASE_URL, so a
 * developer .env pointing at a hosted project can never be written to; the
 * defaults are the local CLI stack's.
 */
import { afterAll, beforeAll, describe, expect, test } from "bun:test";
import { Hono, type MiddlewareHandler } from "hono";
import { createDatabase, type Sql } from "@studafy/database";
import { createJsonLogger } from "@studafy/observability";
import { integrationSuite, removeFixtures } from "@studafy/test-support";
import { AuthContextRepository } from "../../src/auth/context";
import { JwksKeySource } from "../../src/auth/jwks";
import type { AuthDependencies } from "../../src/auth/middleware";
import { createAuthRoutes } from "../../src/auth/routes";
import type { AuthorizationEnv } from "../../src/authorization/middleware";
import { createAuthorizationDependencies } from "../../src/authorization/middleware";
import { PostgresAuthorizationRepository } from "../../src/authorization/repository";
import { PostgresIdempotencyRepository } from "../../src/platform/idempotency";
import { requestContext } from "../../src/platform/middleware";

const databaseUrl = process.env["DATABASE_URL"];

/**
 * The Auth server must belong to the same stack as DATABASE_URL. The default
 * (54321) is only that stack's when the database is the default one (54322),
 * as in CI. Pointed at any other database, the suite needs
 * AUTH_INTEGRATION_SUPABASE_URL, or it would reach a different stack's Auth
 * (on 2026-10-15 it reached the owner's working one).
 */
const AUTH_URL = process.env["AUTH_INTEGRATION_SUPABASE_URL"] ??
  (databaseUrl && new URL(databaseUrl).port === "54322"
    ? "http://127.0.0.1:54321"
    : "");
const suite = AUTH_URL ? integrationSuite(describe) : describe.skip;
/** The Supabase CLI's well-known local service key: not a secret. */
const SERVICE_KEY = process.env["AUTH_INTEGRATION_SERVICE_ROLE_KEY"] ??
  "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImV4cCI6MTk4MzgxMjk5Nn0.EGIM96RAZx35lJzdJsyH-qQwv8Hdp7fsn3W0YpN81IU";

const EMAIL = "password-session@review.studafy.test";
const PASSWORD = `Synthetic-${crypto.randomUUID()}`;
/** How recent a sign-in must be in this suite, so it can wait one out. */
const RECENT_SECONDS = 2;

let sql: Sql;
let app: Hono<AuthorizationEnv>;
let userId = "";

const admin = {
  apikey: SERVICE_KEY,
  authorization: `Bearer ${SERVICE_KEY}`,
  "content-type": "application/json",
};

async function auth(
  path: string,
  init: { method?: string; body?: unknown; headers?: Record<string, string> },
): Promise<Response> {
  return await fetch(`${AUTH_URL}${path}`, {
    method: init.method ?? "POST",
    headers: init.headers ?? admin,
    ...(init.body === undefined ? {} : { body: JSON.stringify(init.body) }),
  });
}

async function signIn(password = PASSWORD): Promise<Response> {
  return await auth("/auth/v1/token?grant_type=password", {
    body: { email: EMAIL, password },
  });
}

async function session(): Promise<{
  access_token: string;
  refresh_token: string;
}> {
  const response = await signIn();
  expect(response.status).toBe(200);
  return await response.json() as {
    access_token: string;
    refresh_token: string;
  };
}

function claims(token: string): Record<string, unknown> {
  return JSON.parse(
    Buffer.from(token.split(".")[1]!, "base64url").toString("utf8"),
  ) as Record<string, unknown>;
}

async function reauth(token: string, purpose: string): Promise<Response> {
  return await app.request("/v1/auth/reauth/verify", {
    method: "POST",
    headers: {
      authorization: `Bearer ${token}`,
      "content-type": "application/json",
    },
    body: JSON.stringify({ purpose }),
  });
}

async function removeUser(): Promise<void> {
  const ids = (await sql<{ id: string }[]>`
    select id::text from auth.users where email = ${EMAIL}
  `).map((row) => row.id);
  if (ids.length === 0) return;
  // Supabase Auth's own rows first: removeFixtures suspends the cascades.
  for (const table of ["sessions", "identities", "mfa_factors"]) {
    await sql.unsafe(
      `delete from auth.${table} where user_id = any($1::uuid[])`,
      [ids],
    );
  }
  await removeFixtures(sql, { userIds: ids });
}

suite("password sessions (reviewer access)", () => {
  beforeAll(async () => {
    if (!/^http:\/\/(127\.0\.0\.1|localhost):\d+$/.test(AUTH_URL)) {
      throw new Error("This suite only talks to a local Supabase Auth.");
    }
    sql = createDatabase(databaseUrl!);
    await removeUser();
    const health = await fetch(`${AUTH_URL}/auth/v1/health`, {
      headers: { apikey: SERVICE_KEY },
    }).catch(() => null);
    if (!health?.ok) {
      throw new Error(`Supabase Auth is not reachable at ${AUTH_URL}.`);
    }

    // Provisioned the way scripts/provision-reviewer-school.ts does it.
    const registered = await auth(
      "/rest/v1/rpc/allow_provisioned_email_account",
      { body: { requested_email: EMAIL } },
    );
    expect(registered.status).toBe(204);
    const created = await auth("/auth/v1/admin/users", {
      body: {
        email: EMAIL,
        password: PASSWORD,
        email_confirm: true,
        app_metadata: { studafy_reviewer: true },
        user_metadata: { full_name: "Password Session" },
      },
    });
    expect(created.status).toBe(200);
    userId = (await created.json() as { id: string }).id;

    const logger = createJsonLogger("api", "test", "error", () => undefined);
    const authDependencies: AuthDependencies = {
      keys: new JwksKeySource(`${AUTH_URL}/auth/v1/.well-known/jwks.json`),
      repository: new AuthContextRepository(sql),
      logger,
      issuer: `${AUTH_URL}/auth/v1`,
      audience: "authenticated",
      clockSkewSeconds: 30,
      revocationBudgetSeconds: 0,
      reauthTtlSeconds: 300,
      recentSignInSeconds: RECENT_SECONDS,
      deletionGraceDays: 14,
    };
    app = new Hono<AuthorizationEnv>();
    app.use(
      "*",
      requestContext() as unknown as MiddlewareHandler<AuthorizationEnv>,
    );
    app.route(
      "/",
      createAuthRoutes(
        authDependencies,
        createAuthorizationDependencies(
          logger,
          new PostgresAuthorizationRepository(sql),
        ),
        { logger, repository: new PostgresIdempotencyRepository(sql) },
      ),
    );
  }, 60_000);

  afterAll(async () => {
    await removeUser();
    await sql.end({ timeout: 5 });
  });

  test("email sign-up is refused at Supabase Auth itself", async () => {
    const address = `signup-${crypto.randomUUID()}@review.studafy.test`;
    const signup = await auth("/auth/v1/signup", {
      headers: { apikey: SERVICE_KEY, "content-type": "application/json" },
      body: { email: address, password: PASSWORD },
    });
    expect(signup.ok).toBe(false);
    const created = await auth("/auth/v1/admin/users", {
      body: { email: address, password: PASSWORD, email_confirm: true },
    });
    expect(created.ok).toBe(false);
    const rows = await sql`select 1 from auth.users where email = ${address}`;
    expect(rows.length).toBe(0);
  }, 60_000);

  test("a wrong password is refused as invalid credentials", async () => {
    const response = await signIn("not-the-password");
    expect(response.status).toBe(400);
    const body = await response.json() as { error_code?: string };
    expect(body.error_code).toBe("invalid_credentials");
  }, 30_000);

  test("the API accepts a password session like any other", async () => {
    const { access_token } = await session();
    expect(claims(access_token)["sub"]).toBe(userId);
    const context = await app.request("/v1/auth/context", {
      headers: { authorization: `Bearer ${access_token}` },
    });
    expect(context.status).toBe(200);
  }, 30_000);

  test(
    "a fresh password sign-in earns a grant for deletion and export",
    async () => {
      const { access_token } = await session();
      const methods = claims(access_token)["amr"] as { method: string }[];
      expect(methods.map((entry) => entry.method)).toContain("password");
      for (const purpose of ["account_deletion", "account_data_export"]) {
        const response = await reauth(access_token, purpose);
        expect(response.status).toBe(200);
        const body = await response.json() as { grant?: string };
        expect(body.grant?.length).toBeGreaterThan(20);
      }
    },
    30_000,
  );

  test(
    "an old sign-in is refused, a refresh does not renew it, and signing in again does",
    async () => {
      const first = await session();
      await Bun.sleep((RECENT_SECONDS + 2) * 1000);

      const stale = await reauth(first.access_token, "account_deletion");
      expect(stale.status).toBe(403);
      expect((await stale.json() as { code: string }).code).toBe(
        "RECENT_SIGN_IN_REQUIRED",
      );

      const refreshed = await auth("/auth/v1/token?grant_type=refresh_token", {
        body: { refresh_token: first.refresh_token },
      });
      expect(refreshed.status).toBe(200);
      const { access_token: refreshedToken } = await refreshed.json() as {
        access_token: string;
      };
      const stillStale = await reauth(refreshedToken, "account_deletion");
      expect(stillStale.status).toBe(403);

      // What the app does for a password account: ask for it, sign in again.
      const again = await session();
      const fresh = await reauth(again.access_token, "account_deletion");
      expect(fresh.status).toBe(200);
    },
    60_000,
  );
});
