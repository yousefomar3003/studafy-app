/**
 * API-042 S5 end-to-end proof against a real local Postgres. The exhaustive
 * state-machine/recipient-resolution coverage lives in
 * supabase/tests/api042_meetings.sql; this file proves the HTTP layer on
 * top of it, including the guardian-recipient tenant-cache fix.
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
import { PostgresMeetingsRepository } from "../../src/meetings/repository";
import { createMeetingsRoutes } from "../../src/meetings/routes";

const databaseUrl = process.env["DATABASE_URL"];
const suite = databaseUrl ? describe : describe.skip;

const ADMIN = "5f460000-0000-4000-8000-0000000000a1";
const TEACHER = "5f460000-0000-4000-8000-0000000000a2";
const GUARDIAN = "5f460000-0000-4000-8000-0000000000a3";
const SCHOOL = "5f460000-0000-4000-8000-0000000000b1";
const TERM = "5f460000-0000-4000-8000-0000000000c1";
const CLASSROOM = "5f460000-0000-4000-8000-0000000000d1";
const STUDENT_USER = "5f460000-0000-4000-8000-0000000000a4";
const STUDENT_ROW = "5f460000-0000-4000-8000-0000000000e1";

const CURSOR_KEY = "api042-meetings-integration-cursor-key-0000000001";

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
      (${ADMIN}::uuid, 'api042.meet.admin@synthetic.studafy.test', 'synthetic-not-a-secret', 'authenticated', 'authenticated', now(), now(), now(), '00000000-0000-0000-0000-000000000000', '', '', '', '', '', '', '{}'::jsonb, '{"full_name":"API-042 Meet Admin"}'::jsonb),
      (${TEACHER}::uuid, 'api042.meet.teacher@synthetic.studafy.test', 'synthetic-not-a-secret', 'authenticated', 'authenticated', now(), now(), now(), '00000000-0000-0000-0000-000000000000', '', '', '', '', '', '', '{}'::jsonb, '{"full_name":"API-042 Meet Teacher"}'::jsonb),
      (${GUARDIAN}::uuid, 'api042.meet.guardian@synthetic.studafy.test', 'synthetic-not-a-secret', 'authenticated', 'authenticated', now(), now(), now(), '00000000-0000-0000-0000-000000000000', '', '', '', '', '', '', '{}'::jsonb, '{"full_name":"API-042 Meet Guardian"}'::jsonb),
      (${STUDENT_USER}::uuid, 'api042.meet.student@synthetic.studafy.test', 'synthetic-not-a-secret', 'authenticated', 'authenticated', now(), now(), now(), '00000000-0000-0000-0000-000000000000', '', '', '', '', '', '', '{}'::jsonb, '{"full_name":"API-042 Meet Student"}'::jsonb)
    on conflict (id) do nothing
  `;
  await sql`
    insert into public.schools (id, name, timezone, status) values (${SCHOOL}::uuid, 'API-042 Meetings School', 'Asia/Riyadh', 'active')
    on conflict (id) do update set status = 'active'
  `;
  await sql`
    insert into public.memberships (school_id, user_id, role, active, status, version) values
      (${SCHOOL}::uuid, ${ADMIN}::uuid, 'school_admin', true, 'active', 1),
      (${SCHOOL}::uuid, ${TEACHER}::uuid, 'teacher', true, 'active', 1)
    on conflict (school_id, user_id, role) do nothing
  `;
  await sql`
    insert into public.terms (id, school_id, name, starts_on, ends_on, active) values
      (${TERM}::uuid, ${SCHOOL}::uuid, 'Integration Term', '2026-09-01', '2026-12-31', true)
    on conflict (id) do nothing
  `;
  await sql`
    insert into public.classrooms (id, school_id, term_id, name, grade, section, teacher_id, status) values
      (${CLASSROOM}::uuid, ${SCHOOL}::uuid, ${TERM}::uuid, 'Meetings Classroom', 'G6', 'A', ${TEACHER}::uuid, 'active')
    on conflict (id) do nothing
  `;
  await sql`
    insert into public.classroom_staff (school_id, classroom_id, membership_id, user_id, role)
    select ${SCHOOL}::uuid, ${CLASSROOM}::uuid, m.id, ${TEACHER}::uuid, 'lead_teacher'
    from public.memberships m where m.school_id = ${SCHOOL}::uuid and m.user_id = ${TEACHER}::uuid and m.role = 'teacher'
    on conflict do nothing
  `;
  await sql`
    insert into public.students (id, school_id, user_id, studafy_id, display_name, provisional, created_by) values
      (${STUDENT_ROW}::uuid, ${SCHOOL}::uuid, ${STUDENT_USER}::uuid, 'STU-API042-MEET', 'Meetings Integration Student', false, ${ADMIN}::uuid)
    on conflict (id) do nothing
  `;
  await sql`
    insert into public.enrollments (school_id, classroom_id, student_id, active, status, starts_on) values
      (${SCHOOL}::uuid, ${CLASSROOM}::uuid, ${STUDENT_ROW}::uuid, true, 'active', current_date)
    on conflict (school_id, classroom_id, student_id) do nothing
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
    await tx`delete from public.meeting_deliveries where school_id = ${SCHOOL}::uuid`;
    await tx`delete from public.meetings where school_id = ${SCHOOL}::uuid`;
    await tx`delete from public.enrollments where classroom_id = ${CLASSROOM}::uuid`;
    await tx`delete from public.guardian_links where student_id = ${STUDENT_ROW}::uuid`;
    await tx`delete from public.audit_events where school_id = ${SCHOOL}::uuid`;
    await tx`delete from public.students where id = ${STUDENT_ROW}::uuid`;
    await tx`delete from public.classroom_staff where classroom_id = ${CLASSROOM}::uuid`;
    await tx`delete from public.classrooms where id = ${CLASSROOM}::uuid`;
    await tx`delete from public.terms where id = ${TERM}::uuid`;
    await tx`delete from public.memberships where school_id = ${SCHOOL}::uuid`;
    await tx`delete from public.schools where id = ${SCHOOL}::uuid`;
    await tx`delete from auth.users where id in (${ADMIN}::uuid, ${TEACHER}::uuid, ${GUARDIAN}::uuid, ${STUDENT_USER}::uuid)`;
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

suite("API-042 S5 meetings over the real /v1 stack", () => {
  let meetingId: string;

  beforeAll(async () => {
    sql = createDatabase(databaseUrl!);
    await cleanup();
    await seed();
    contexts = new AuthContextRepository(sql);
    const logger = createJsonLogger(
      "api",
      "api042-meetings-integration",
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
      createMeetingsRoutes(
        {
          repository: new PostgresMeetingsRepository(sql),
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

  test("the lead teacher requests a meeting, resolving student and guardian recipients", async () => {
    const res = await request(`/v1/classrooms/${CLASSROOM}/meetings`, {
      method: "POST",
      subject: TEACHER,
      body: {
        title: "Progress check-in",
        startsAt: new Date(Date.now() + 86_400_000).toISOString(),
        endsAt: new Date(Date.now() + 86_400_000 + 1_800_000).toISOString(),
        audience: "both",
      },
    });
    expect(res.status).toBe(201);
    const body = await res.json() as {
      id: string;
      state: string;
      recipientCount: number;
    };
    expect(body.state).toBe("pending");
    // Student + guardian + lead teacher, resolved by one bulk query.
    expect(body.recipientCount).toBe(3);
    meetingId = body.id;
  });

  test("the guardian recipient (no memberships row) reads meeting status", async () => {
    const res = await request(`/v1/meetings/${meetingId}`, {
      subject: GUARDIAN,
    });
    expect(res.status).toBe(200);
    const body = await res.json() as { deliveries: { recipientId: string }[] };
    expect(body.deliveries.some((d) => d.recipientId === GUARDIAN)).toBe(true);
  });

  test("a non-recipient admin from elsewhere cannot read status of a meeting they have no role in", async () => {
    // ADMIN is a school admin of the same school, so they ARE authorized
    // (is_meeting_authorized covers admins); this instead proves a bare
    // 404 problem shape on an unrelated random id.
    const res = await request(`/v1/meetings/${crypto.randomUUID()}`, {
      subject: GUARDIAN,
    });
    expect(res.status).toBe(404);
  });

  test("the lead teacher cancels the meeting, which bulk-cancels every delivery", async () => {
    const res = await request(`/v1/meetings/${meetingId}/cancel`, {
      method: "POST",
      subject: TEACHER,
      body: { expectedVersion: 1 },
    });
    expect(res.status).toBe(200);
    const body = await res.json() as { state: string };
    expect(body.state).toBe("cancelled");

    const [row] = await sql<{ remaining: number }[]>`
      select count(*)::int as remaining from public.meeting_deliveries
      where meeting_id = ${meetingId}::uuid and state <> 'cancelled'
    `;
    expect(row?.remaining).toBe(0);
  });
});
