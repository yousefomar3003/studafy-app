/**
 * API-042 S2 end-to-end proof against a real local Postgres.
 *
 * The exhaustive state-machine coverage (duplicate live invite, wrong/
 * expired/reused token, existing-member refusal, cross-school revoke,
 * lazy re-expiry) lives in supabase/tests/api042_invitations.sql, which
 * calls the SQL dispatcher directly with pre-computed hash fixtures. This
 * file is the one place that proves the real token generation/hashing
 * round-trip (apps/api/src/invitations/repository.ts) actually works: a
 * raw token minted by issueInvitation's response is hashed the same way by
 * acceptInvitation and matches.
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
import { PostgresInvitationsRepository } from "../../src/invitations/repository";
import { createInvitationsRoutes } from "../../src/invitations/routes";

const databaseUrl = process.env["DATABASE_URL"];
const suite = databaseUrl ? describe : describe.skip;

const ADMIN = "5f430000-0000-4000-8000-0000000000a1";
const TEACHER = "5f430000-0000-4000-8000-0000000000a2";
const INVITEE = "5f430000-0000-4000-8000-0000000000a3";
const SCHOOL = "5f430000-0000-4000-8000-0000000000b1";

const CURSOR_KEY = "api042-inv-integration-cursor-key-0000000001";

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
      (${ADMIN}::uuid, 'api042.inv.admin@synthetic.studafy.test', 'synthetic-not-a-secret', 'authenticated', 'authenticated', now(), now(), now(), '00000000-0000-0000-0000-000000000000', '', '', '', '', '', '', '{}'::jsonb, '{"full_name":"API-042 Inv Admin"}'::jsonb),
      (${TEACHER}::uuid, 'api042.inv.teacher@synthetic.studafy.test', 'synthetic-not-a-secret', 'authenticated', 'authenticated', now(), now(), now(), '00000000-0000-0000-0000-000000000000', '', '', '', '', '', '', '{}'::jsonb, '{"full_name":"API-042 Inv Teacher"}'::jsonb),
      (${INVITEE}::uuid, 'api042.inv.invitee@synthetic.studafy.test', 'synthetic-not-a-secret', 'authenticated', 'authenticated', now(), now(), now(), '00000000-0000-0000-0000-000000000000', '', '', '', '', '', '', '{}'::jsonb, '{"full_name":"API-042 Inv Invitee"}'::jsonb)
    on conflict (id) do nothing
  `;
  await sql`
    insert into public.schools (id, name, timezone, status) values (${SCHOOL}::uuid, 'API-042 Invitations School', 'Asia/Riyadh', 'active')
    on conflict (id) do update set status = 'active'
  `;
  await sql`
    insert into public.memberships (school_id, user_id, role, active, status, version) values
      (${SCHOOL}::uuid, ${ADMIN}::uuid, 'school_admin', true, 'active', 1),
      (${SCHOOL}::uuid, ${TEACHER}::uuid, 'teacher', true, 'active', 1)
    on conflict (school_id, user_id, role) do nothing
  `;
}

async function cleanup(): Promise<void> {
  await sql.begin(async (tx) => {
    await tx`alter table public.membership_events disable trigger db020_reject_mutation`;
    await tx`alter table public.audit_events disable trigger db020_reject_mutation`;
    await tx`delete from public.invitations where school_id = ${SCHOOL}::uuid`;
    await tx`delete from public.membership_events where school_id = ${SCHOOL}::uuid`;
    await tx`delete from public.audit_events where school_id = ${SCHOOL}::uuid`;
    await tx`delete from public.memberships where school_id = ${SCHOOL}::uuid`;
    await tx`delete from public.schools where id = ${SCHOOL}::uuid`;
    await tx`delete from auth.users where id in (${ADMIN}::uuid, ${TEACHER}::uuid, ${INVITEE}::uuid)`;
    await tx`alter table public.membership_events enable trigger db020_reject_mutation`;
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

suite("API-042 S2 invitations over the real /v1 stack", () => {
  let issuedToken: string;

  beforeAll(async () => {
    sql = createDatabase(databaseUrl!);
    await cleanup();
    await seed();
    contexts = new AuthContextRepository(sql);
    const logger = createJsonLogger(
      "api",
      "api042-inv-integration",
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
      createInvitationsRoutes(
        {
          repository: new PostgresInvitationsRepository(sql),
          cursorSigningKey: CURSOR_KEY,
        },
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

  test("a non-admin cannot issue an invitation", async () => {
    const res = await request(`/v1/schools/${SCHOOL}/invitations`, {
      method: "POST",
      subject: TEACHER,
      body: {
        email: "api042.inv.invitee@synthetic.studafy.test",
        role: "teacher",
      },
    });
    expect([403, 404]).toContain(res.status);
  });

  test("a school admin issues an invitation and receives a one-time token", async () => {
    const res = await request(`/v1/schools/${SCHOOL}/invitations`, {
      method: "POST",
      subject: ADMIN,
      body: {
        email: "api042.inv.invitee@synthetic.studafy.test",
        role: "teacher",
      },
    });
    expect(res.status).toBe(201);
    const body = await res.json() as {
      status: string;
      email: string;
      token: string;
    };
    expect(body.status).toBe("pending");
    expect(body.email).toBe("api042.inv.invitee@synthetic.studafy.test");
    expect(body.token.length).toBeGreaterThanOrEqual(32);
    issuedToken = body.token;
  });

  test("the admin can list the issued invitation", async () => {
    const res = await request(`/v1/schools/${SCHOOL}/invitations`, {
      subject: ADMIN,
    });
    expect(res.status).toBe(200);
    const body = await res.json() as { items: { email: string }[] };
    expect(
      body.items.some((i) =>
        i.email === "api042.inv.invitee@synthetic.studafy.test"
      ),
    )
      .toBe(true);
  });

  test("a garbled token is refused, not matched to the real invitation", async () => {
    const res = await request("/v1/invitations/accept", {
      method: "POST",
      subject: INVITEE,
      body: { token: `${issuedToken}-tampered` },
    });
    expect(res.status).toBe(404);
  });

  test("the invitee accepts with the real token and receives an active membership", async () => {
    const res = await request("/v1/invitations/accept", {
      method: "POST",
      subject: INVITEE,
      body: { token: issuedToken },
    });
    expect(res.status).toBe(200);
    const body = await res.json() as { role: string; status: string };
    expect(body.role).toBe("teacher");
    expect(body.status).toBe("active");
  });

  test("the same token cannot be accepted a second time", async () => {
    const res = await request("/v1/invitations/accept", {
      method: "POST",
      subject: INVITEE,
      body: { token: issuedToken },
    });
    expect(res.status).toBe(409);
  });
});
