/**
 * API-042 S4 end-to-end proof against a real local Postgres. The exhaustive
 * state-machine coverage lives in supabase/tests/api042_communications.sql;
 * this file proves the HTTP layer (route paths, permission middleware,
 * idempotency, response-schema validation) on top of it.
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
import { PostgresCommunicationsRepository } from "../../src/communications/repository";
import { createCommunicationsRoutes } from "../../src/communications/routes";

const databaseUrl = process.env["DATABASE_URL"];
const suite = databaseUrl ? describe : describe.skip;

const ADMIN = "5f450000-0000-4000-8000-0000000000a1";
const TEACHER = "5f450000-0000-4000-8000-0000000000a2";
const GUARDIAN = "5f450000-0000-4000-8000-0000000000a3";
const SCHOOL = "5f450000-0000-4000-8000-0000000000b1";
const STUDENT_USER = "5f450000-0000-4000-8000-0000000000a4";
const STUDENT_ROW = "5f450000-0000-4000-8000-0000000000c1";

const CURSOR_KEY = "api042-comms-integration-cursor-key-01";

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
      (${ADMIN}::uuid, 'api042.comms.admin@synthetic.studafy.test', 'synthetic-not-a-secret', 'authenticated', 'authenticated', now(), now(), now(), '00000000-0000-0000-0000-000000000000', '', '', '', '', '', '', '{}'::jsonb, '{"full_name":"API-042 Comms Admin"}'::jsonb),
      (${TEACHER}::uuid, 'api042.comms.teacher@synthetic.studafy.test', 'synthetic-not-a-secret', 'authenticated', 'authenticated', now(), now(), now(), '00000000-0000-0000-0000-000000000000', '', '', '', '', '', '', '{}'::jsonb, '{"full_name":"API-042 Comms Teacher"}'::jsonb),
      (${GUARDIAN}::uuid, 'api042.comms.guardian@synthetic.studafy.test', 'synthetic-not-a-secret', 'authenticated', 'authenticated', now(), now(), now(), '00000000-0000-0000-0000-000000000000', '', '', '', '', '', '', '{}'::jsonb, '{"full_name":"API-042 Comms Guardian"}'::jsonb),
      (${STUDENT_USER}::uuid, 'api042.comms.student@synthetic.studafy.test', 'synthetic-not-a-secret', 'authenticated', 'authenticated', now(), now(), now(), '00000000-0000-0000-0000-000000000000', '', '', '', '', '', '', '{}'::jsonb, '{"full_name":"API-042 Comms Student"}'::jsonb)
    on conflict (id) do nothing
  `;
  await sql`
    insert into public.schools (id, name, timezone, status) values (${SCHOOL}::uuid, 'API-042 Comms School', 'Asia/Riyadh', 'active')
    on conflict (id) do update set status = 'active'
  `;
  await sql`
    insert into public.memberships (school_id, user_id, role, active, status, version) values
      (${SCHOOL}::uuid, ${ADMIN}::uuid, 'school_admin', true, 'active', 1),
      (${SCHOOL}::uuid, ${TEACHER}::uuid, 'teacher', true, 'active', 1)
    on conflict (school_id, user_id, role) do nothing
  `;
  await sql`
    insert into public.students (id, school_id, user_id, studafy_id, display_name, provisional, created_by) values
      (${STUDENT_ROW}::uuid, ${SCHOOL}::uuid, ${STUDENT_USER}::uuid, 'STU-API042-COMMS', 'Comms Integration Student', false, ${ADMIN}::uuid)
    on conflict (id) do nothing
  `;
  await sql`
    insert into public.guardian_links (school_id, student_id, guardian_id, status, relationship, verified_by, verified_at) values
      (${SCHOOL}::uuid, ${STUDENT_ROW}::uuid, ${GUARDIAN}::uuid, 'verified', 'parent', ${ADMIN}::uuid, now())
    on conflict (student_id, guardian_id) do nothing
  `;
}

async function cleanup(): Promise<void> {
  await sql.begin(async (tx) => {
    await tx`alter table public.audit_events disable trigger db020_reject_mutation`;
    await tx`alter table public.messages disable trigger db020_reject_mutation`;
    await tx`delete from public.messages where school_id = ${SCHOOL}::uuid`;
    await tx`delete from public.conversation_participants where school_id = ${SCHOOL}::uuid`;
    await tx`delete from public.conversations where school_id = ${SCHOOL}::uuid`;
    await tx`delete from public.announcements where school_id = ${SCHOOL}::uuid`;
    await tx`delete from public.guardian_links where student_id = ${STUDENT_ROW}::uuid`;
    await tx`delete from public.audit_events where school_id = ${SCHOOL}::uuid`;
    await tx`delete from public.students where id = ${STUDENT_ROW}::uuid`;
    await tx`delete from public.memberships where school_id = ${SCHOOL}::uuid`;
    await tx`delete from public.schools where id = ${SCHOOL}::uuid`;
    await tx`delete from auth.users where id in (${ADMIN}::uuid, ${TEACHER}::uuid, ${GUARDIAN}::uuid, ${STUDENT_USER}::uuid)`;
    await tx`alter table public.messages enable trigger db020_reject_mutation`;
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

suite("API-042 S4 communications over the real /v1 stack", () => {
  let conversationId: string;

  beforeAll(async () => {
    sql = createDatabase(databaseUrl!);
    await cleanup();
    await seed();
    contexts = new AuthContextRepository(sql);
    const logger = createJsonLogger(
      "api",
      "api042-comms-integration",
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
      createCommunicationsRoutes(
        { repository: new PostgresCommunicationsRepository(sql), cursorSigningKey: CURSOR_KEY },
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

  test("a teacher creates a conversation with a verified guardian", async () => {
    const res = await request("/v1/conversations", {
      method: "POST",
      subject: TEACHER,
      body: { schoolId: SCHOOL, subject: "About homework", participantIds: [GUARDIAN] },
    });
    expect(res.status).toBe(201);
    const body = await res.json() as { id: string; state: string };
    expect(body.state).toBe("active");
    conversationId = body.id;
  });

  test("the guardian (no memberships row) sends a message in the conversation", async () => {
    const res = await request(`/v1/conversations/${conversationId}/messages`, {
      method: "POST",
      subject: GUARDIAN,
      body: { clientMessageId: crypto.randomUUID(), body: "Thank you for the update." },
    });
    expect(res.status).toBe(201);
    const body = await res.json() as { body: string; senderId: string };
    expect(body.body).toBe("Thank you for the update.");
    expect(body.senderId).toBe(GUARDIAN);
  });

  test("a non-participant cannot list messages", async () => {
    const res = await request(`/v1/conversations/${conversationId}/messages`, {
      subject: ADMIN,
    });
    expect(res.status).toBe(404);
  });

  test("a teacher cannot create a school-wide announcement", async () => {
    const res = await request("/v1/announcements", {
      method: "POST",
      subject: TEACHER,
      body: { schoolId: SCHOOL, title: "Rogue notice", body: "x" },
    });
    expect([403, 404]).toContain(res.status);
  });

  test("a school admin creates a school-wide announcement, visible to members", async () => {
    const create = await request("/v1/announcements", {
      method: "POST",
      subject: ADMIN,
      body: { schoolId: SCHOOL, title: "Term dates", body: "See the calendar." },
    });
    expect(create.status).toBe(201);

    const list = await request(`/v1/announcements?schoolId=${SCHOOL}`, { subject: TEACHER });
    expect(list.status).toBe(200);
    const body = await list.json() as { items: { title: string }[] };
    expect(body.items.some((a) => a.title === "Term dates")).toBe(true);
  });
});
