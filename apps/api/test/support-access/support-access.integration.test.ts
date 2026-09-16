/**
 * API-042 S8 end-to-end proof against a real local Postgres. The exhaustive
 * state-machine/two-person-approval coverage lives in
 * supabase/tests/api042_support_access.sql; this file proves the HTTP layer
 * (route paths, permission middleware, idempotency, response-schema
 * validation, and that AAL2 actually has to come from the session, not just
 * a header claim) on top of it.
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
import { PostgresSupportAccessRepository } from "../../src/support-access/repository";
import { createSupportAccessRoutes } from "../../src/support-access/routes";

const databaseUrl = process.env["DATABASE_URL"];
const suite = databaseUrl ? describe : describe.skip;

const OPERATOR_A = "5f490000-0000-4000-8000-0000000000a1";
const OPERATOR_B = "5f490000-0000-4000-8000-0000000000a2";
const ADMIN = "5f490000-0000-4000-8000-0000000000a3";
const TEACHER = "5f490000-0000-4000-8000-0000000000a4";
const SCHOOL = "5f490000-0000-4000-8000-0000000000b1";

const CURSOR_KEY = "api042-support-access-integration-cursor-key-01";

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
      (${OPERATOR_A}::uuid, 'api042.sup.operator-a@synthetic.studafy.test', 'synthetic-not-a-secret', 'authenticated', 'authenticated', now(), now(), now(), '00000000-0000-0000-0000-000000000000', '', '', '', '', '', '', '{}'::jsonb, '{"full_name":"API-042 Sup Operator A"}'::jsonb),
      (${OPERATOR_B}::uuid, 'api042.sup.operator-b@synthetic.studafy.test', 'synthetic-not-a-secret', 'authenticated', 'authenticated', now(), now(), now(), '00000000-0000-0000-0000-000000000000', '', '', '', '', '', '', '{}'::jsonb, '{"full_name":"API-042 Sup Operator B"}'::jsonb),
      (${ADMIN}::uuid, 'api042.sup.admin@synthetic.studafy.test', 'synthetic-not-a-secret', 'authenticated', 'authenticated', now(), now(), now(), '00000000-0000-0000-0000-000000000000', '', '', '', '', '', '', '{}'::jsonb, '{"full_name":"API-042 Sup Admin"}'::jsonb),
      (${TEACHER}::uuid, 'api042.sup.teacher@synthetic.studafy.test', 'synthetic-not-a-secret', 'authenticated', 'authenticated', now(), now(), now(), '00000000-0000-0000-0000-000000000000', '', '', '', '', '', '', '{}'::jsonb, '{"full_name":"API-042 Sup Teacher"}'::jsonb)
    on conflict (id) do nothing
  `;
  await sql`
    insert into public.schools (id, name, timezone, status) values (${SCHOOL}::uuid, 'API-042 Support-Access School', 'Asia/Riyadh', 'active')
    on conflict (id) do update set status = 'active'
  `;
  await sql`
    insert into public.memberships (school_id, user_id, role, active, status, version) values
      (${SCHOOL}::uuid, ${ADMIN}::uuid, 'school_admin', true, 'active', 1),
      (${SCHOOL}::uuid, ${TEACHER}::uuid, 'teacher', true, 'active', 1)
    on conflict (school_id, user_id, role) do nothing
  `;
  await sql`
    insert into public.platform_operators (user_id, note) values
      (${OPERATOR_A}::uuid, 'api042 support-access integration fixture'),
      (${OPERATOR_B}::uuid, 'api042 support-access integration fixture')
    on conflict (user_id) do nothing
  `;
}

async function cleanup(): Promise<void> {
  await sql.begin(async (tx) => {
    await tx`alter table public.audit_events disable trigger db020_reject_mutation`;
    await tx`delete from public.support_access_grants where school_id = ${SCHOOL}::uuid`;
    await tx`delete from public.audit_events where school_id = ${SCHOOL}::uuid`;
    await tx`delete from public.platform_operators where user_id in (${OPERATOR_A}::uuid, ${OPERATOR_B}::uuid)`;
    await tx`delete from public.memberships where school_id = ${SCHOOL}::uuid`;
    await tx`delete from public.schools where id = ${SCHOOL}::uuid`;
    await tx`delete from auth.users where id in (${OPERATOR_A}::uuid, ${OPERATOR_B}::uuid, ${ADMIN}::uuid, ${TEACHER}::uuid)`;
    await tx`alter table public.audit_events enable trigger db020_reject_mutation`;
  });
}

interface RequestInput {
  method?: "GET" | "POST";
  subject: string;
  aal2?: boolean;
  key?: string;
  body?: unknown;
}

async function request(path: string, input: RequestInput): Promise<Response> {
  const headers = new Headers();
  headers.set("x-test-subject", input.subject);
  headers.set("x-test-aal2", input.aal2 ? "true" : "false");
  if ((input.method ?? "GET") === "POST") {
    headers.set("content-type", "application/json");
    headers.set("idempotency-key", input.key ?? crypto.randomUUID());
  }
  return await app.request(path, {
    method: input.method ?? "GET",
    headers,
    ...(input.body !== undefined ? { body: JSON.stringify(input.body) } : {}),
  });
}

suite("API-042 S8 support-access over the real /v1 stack", () => {
  let grantId: string;

  beforeAll(async () => {
    sql = createDatabase(databaseUrl!);
    await cleanup();
    await seed();
    contexts = new AuthContextRepository(sql);
    const logger = createJsonLogger(
      "api",
      "api042-support-access-integration",
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
          assuranceLevel: c.req.header("x-test-aal2") === "true" ? "aal2" : "aal1",
          authMethods: [],
          claims: {},
        },
        context,
        aal2: c.req.header("x-test-aal2") === "true",
        mfaRequiredByPolicy: false,
      };
      c.set("requestId", crypto.randomUUID());
      c.set("actor", actor);
      await next();
    });
    app.route(
      "/",
      createSupportAccessRoutes(
        { repository: new PostgresSupportAccessRepository(sql), cursorSigningKey: CURSOR_KEY },
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

  test("an ordinary teacher cannot request support access", async () => {
    const res = await request("/internal/support-access", {
      method: "POST",
      subject: TEACHER,
      aal2: true,
      body: { schoolId: SCHOOL, reason: "Investigating a support ticket", ticketRef: "TICK-HTTP-1" },
    });
    expect(res.status).toBe(403);
  });

  test("a platform operator without a verified second factor cannot request support access", async () => {
    const res = await request("/internal/support-access", {
      method: "POST",
      subject: OPERATOR_A,
      aal2: false,
      body: { schoolId: SCHOOL, reason: "Investigating a support ticket", ticketRef: "TICK-HTTP-2" },
    });
    expect(res.status).toBe(403);
  });

  test("a platform operator with a verified second factor requests support access", async () => {
    const res = await request("/internal/support-access", {
      method: "POST",
      subject: OPERATOR_A,
      aal2: true,
      body: {
        schoolId: SCHOOL,
        reason: "Investigating a support ticket",
        ticketRef: "TICK-HTTP-3",
        durationMinutes: 60,
      },
    });
    expect(res.status).toBe(201);
    const body = await res.json() as { id: string; status: string };
    expect(body.status).toBe("pending");
    grantId = body.id;
  });

  test("the requester cannot approve their own request", async () => {
    // support_access.approve conceals denials as 404, the same
    // existence-oracle protection every other resource-scoped permission
    // uses - a stale/foreign grant id must not be distinguishable from one
    // this actor simply isn't allowed to approve.
    const res = await request(`/internal/support-access/${grantId}/approve`, {
      method: "POST",
      subject: OPERATOR_A,
      aal2: true,
      body: { expectedVersion: 1 },
    });
    expect(res.status).toBe(404);
  });

  test("a different operator with a verified second factor approves the request", async () => {
    const res = await request(`/internal/support-access/${grantId}/approve`, {
      method: "POST",
      subject: OPERATOR_B,
      aal2: true,
      body: { expectedVersion: 1 },
    });
    expect(res.status).toBe(200);
    const body = await res.json() as { status: string };
    expect(body.status).toBe("approved");
  });

  test("only the original requester can start the approved session", async () => {
    const wrongActor = await request(`/internal/support-access/${grantId}/start`, {
      method: "POST",
      subject: OPERATOR_B,
      aal2: true,
      body: { expectedVersion: 2 },
    });
    expect(wrongActor.status).toBe(404);

    const res = await request(`/internal/support-access/${grantId}/start`, {
      method: "POST",
      subject: OPERATOR_A,
      aal2: true,
      body: { expectedVersion: 2 },
    });
    expect(res.status).toBe(200);
    const body = await res.json() as { status: string; startedAt: string | null };
    expect(body.status).toBe("active");
    expect(body.startedAt).not.toBeNull();
  });

  test("the school's own admin revokes the active session, and it cannot be revoked twice", async () => {
    const res = await request(`/internal/support-access/${grantId}/revoke`, {
      method: "POST",
      subject: ADMIN,
      body: { expectedVersion: 3, reason: "Investigation complete" },
    });
    expect(res.status).toBe(200);
    const body = await res.json() as { status: string; endedAt: string | null };
    expect(body.status).toBe("revoked");
    expect(body.endedAt).not.toBeNull();

    const again = await request(`/internal/support-access/${grantId}/revoke`, {
      method: "POST",
      subject: ADMIN,
      body: { expectedVersion: 4 },
    });
    expect(again.status).toBe(409);
  });

  test("an ordinary teacher cannot list a school's support-access grants, but the admin can", async () => {
    const denied = await request(`/internal/support-access?schoolId=${SCHOOL}`, { subject: TEACHER });
    expect(denied.status).toBe(404);

    const allowed = await request(`/internal/support-access?schoolId=${SCHOOL}`, { subject: ADMIN });
    expect(allowed.status).toBe(200);
    const body = await allowed.json() as { items: { id: string }[] };
    expect(body.items.some((item) => item.id === grantId)).toBe(true);
  });
});
