/**
 * API-042 S7 end-to-end proof against a real local Postgres. The exhaustive
 * state-machine coverage lives in supabase/tests/api042_account.sql; this
 * file proves the HTTP layer on top of it.
 */
import { afterAll, beforeAll, describe, expect, test } from "bun:test";
import { Hono } from "hono";
import type { LogLevel } from "@studafy/contracts";
import { createDatabase, type Sql } from "@studafy/database";
import { createJsonLogger } from "@studafy/observability";
import { AuthContextRepository } from "../../src/auth/context";
import type { Actor } from "../../src/auth/middleware";
import type { AuthorizationEnv } from "../../src/authorization/middleware";
import { createAuthorizationDependencies } from "../../src/authorization/middleware";
import { PostgresAuthorizationRepository } from "../../src/authorization/repository";
import { PostgresIdempotencyRepository } from "../../src/platform/idempotency";
import { PostgresAccountRepository } from "../../src/account/repository";
import { createAccountRoutes } from "../../src/account/routes";

const databaseUrl = process.env["DATABASE_URL"];
const suite = databaseUrl ? describe : describe.skip;

const USER_A = "5f480000-0000-4000-8000-0000000000a1";

let sql: Sql;
let contexts: AuthContextRepository;
let app: Hono<AuthorizationEnv>;

async function seed(): Promise<void> {
  await sql`
    insert into auth.users (
      id, email, encrypted_password, aud, role, email_confirmed_at,
      created_at, updated_at, instance_id, confirmation_token, recovery_token,
      email_change, email_change_token_new, email_change_token_current,
      phone_change_token, raw_app_meta_data, raw_user_meta_data
    ) values
      (${USER_A}::uuid, 'api042.acct.user@synthetic.studafy.test', 'synthetic-not-a-secret', 'authenticated', 'authenticated', now(), now(), now(), '00000000-0000-0000-0000-000000000000', '', '', '', '', '', '', '{}'::jsonb, '{"full_name":"API-042 Acct User"}'::jsonb)
    on conflict (id) do nothing
  `;
}

async function cleanup(): Promise<void> {
  await sql.begin(async (tx) => {
    await tx`alter table public.audit_events disable trigger db020_reject_mutation`;
    await tx`delete from public.data_export_requests where user_id = ${USER_A}::uuid`;
    await tx`delete from public.audit_events where actor_id = ${USER_A}::uuid`;
    await tx`delete from auth.users where id = ${USER_A}::uuid`;
    await tx`alter table public.audit_events enable trigger db020_reject_mutation`;
  });
}

interface RequestInput {
  method?: "GET" | "POST";
  subject: string;
  key?: string;
  body?: unknown;
}

async function request(path: string, input: RequestInput): Promise<Response> {
  const headers = new Headers();
  headers.set("x-test-subject", input.subject);
  if (input.body !== undefined) headers.set("content-type", "application/json");
  if ((input.method ?? "GET") === "POST") {
    headers.set("idempotency-key", input.key ?? crypto.randomUUID());
  }
  return await app.request(path, {
    method: input.method ?? "GET",
    headers,
    ...(input.body !== undefined ? { body: JSON.stringify(input.body) } : {}),
  });
}

suite("API-042 S7 account rights over the real /v1 stack", () => {
  beforeAll(async () => {
    sql = createDatabase(databaseUrl!);
    await cleanup();
    await seed();
    contexts = new AuthContextRepository(sql);
    const logger = createJsonLogger(
      "api",
      "api042-account-integration",
      "debug" as LogLevel,
      () => undefined,
    );
    const authorization = createAuthorizationDependencies(
      logger,
      new PostgresAuthorizationRepository(sql),
    );
    const idempotency = {
      logger,
      repository: new PostgresIdempotencyRepository(sql),
    };

    app = new Hono<AuthorizationEnv>();
    app.use("*", async (c, next) => {
      const subject = c.req.header("x-test-subject")!;
      const context = await contexts.load(subject);
      if (!context) return c.text("unauthenticated", 401);
      const actor: Actor = {
        token: {
          subject,
          sessionId: null,
          issuedAt: 1,
          expiresAt: 4_000_000_000,
          assuranceLevel: "aal1",
          authMethods: [],
          claims: {},
        },
        context,
        aal2: false,
        mfaRequiredByPolicy: false,
      };
      c.set("requestId", crypto.randomUUID());
      c.set("actor", actor);
      await next();
    });
    app.route(
      "/",
      createAccountRoutes(
        { repository: new PostgresAccountRepository(sql), cursorSigningKey: "api042-account-cursor-key-00" },
        authorization,
        idempotency,
      ),
    );
  });

  afterAll(async () => {
    if (!sql) return;
    await cleanup();
    await sql.end({ timeout: 5 });
  });

  test("a user with no school membership updates their own profile", async () => {
    const res = await request("/v1/account/profile", {
      method: "POST",
      subject: USER_A,
      body: { displayName: "New Name", locale: "ar" },
    });
    expect(res.status).toBe(200);
    const body = await res.json() as { displayName: string; locale: string };
    expect(body.displayName).toBe("New Name");
    expect(body.locale).toBe("ar");
  });

  test("a malformed request is rejected before reaching the database", async () => {
    const res = await request("/v1/account/profile", {
      method: "POST",
      subject: USER_A,
      body: { displayName: "" },
    });
    expect(res.status).toBe(400);
  });

  test("export request/status round-trips and a second request reuses the pending one", async () => {
    const before = await request("/v1/account/export-status", { subject: USER_A });
    expect((await before.json() as { request: unknown }).request).toBeNull();

    const first = await request("/v1/account/export-request", { method: "POST", subject: USER_A, body: {} });
    expect(first.status).toBe(201);
    const firstBody = await first.json() as { id: string; status: string };
    expect(firstBody.status).toBe("pending");

    const second = await request("/v1/account/export-request", { method: "POST", subject: USER_A, body: {} });
    const secondBody = await second.json() as { id: string };
    expect(secondBody.id).toBe(firstBody.id);

    const status = await request("/v1/account/export-status", { subject: USER_A });
    const statusBody = await status.json() as { request: { id: string } | null };
    expect(statusBody.request?.id).toBe(firstBody.id);
  });
});
