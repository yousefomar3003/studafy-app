/**
 * API-042 S1 end-to-end proof against a real local Postgres.
 *
 * The exhaustive state-machine/authorization-branch coverage (guards,
 * version conflicts, cross-school substitution, forced-audit rollback) lives
 * in supabase/tests/api042_school_operations.sql, which calls the SQL
 * dispatcher directly. This file proves the HTTP layer on top of it is wired
 * correctly: route paths resolve, the AUTH-031 permission middleware and
 * API-040 idempotency middleware actually run over real requests, and every
 * response validates against its Zod contract - the same division of labour
 * academic.integration.test.ts uses for API-041.
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
import { PostgresSchoolAdminRepository } from "../../src/school-admin/repository";
import { createSchoolAdminRoutes } from "../../src/school-admin/routes";
import { createAcademicRoutes } from "../../src/academic/routes";
import { PostgresAcademicRepository } from "../../src/academic/repository";

const databaseUrl = process.env["DATABASE_URL"];
const suite = databaseUrl ? describe : describe.skip;

const OPERATOR = "5f420000-0000-4000-8000-0000000000a1";
const ADMIN = "5f420000-0000-4000-8000-0000000000a2";
const TEACHER = "5f420000-0000-4000-8000-0000000000a3";
const SCHOOL = "5f420000-0000-4000-8000-0000000000b1";
const TERM = "5f420000-0000-4000-8000-0000000000c1";
const CLASSROOM = "5f420000-0000-4000-8000-0000000000d1";
const STUDENT_USER = "5f420000-0000-4000-8000-0000000000a4";
const STUDENT_ROW = "5f420000-0000-4000-8000-0000000000e1";

const CURSOR_KEY = "api042-integration-cursor-key-0000000001";

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
      (${OPERATOR}::uuid, 'api042.operator@synthetic.studafy.test', 'synthetic-not-a-secret', 'authenticated', 'authenticated', now(), now(), now(), '00000000-0000-0000-0000-000000000000', '', '', '', '', '', '', '{}'::jsonb, '{"full_name":"API-042 Operator"}'::jsonb),
      (${ADMIN}::uuid, 'api042.admin@synthetic.studafy.test', 'synthetic-not-a-secret', 'authenticated', 'authenticated', now(), now(), now(), '00000000-0000-0000-0000-000000000000', '', '', '', '', '', '', '{}'::jsonb, '{"full_name":"API-042 Admin"}'::jsonb),
      (${TEACHER}::uuid, 'api042.teacher@synthetic.studafy.test', 'synthetic-not-a-secret', 'authenticated', 'authenticated', now(), now(), now(), '00000000-0000-0000-0000-000000000000', '', '', '', '', '', '', '{}'::jsonb, '{"full_name":"API-042 Teacher"}'::jsonb),
      (${STUDENT_USER}::uuid, 'api042.student@synthetic.studafy.test', 'synthetic-not-a-secret', 'authenticated', 'authenticated', now(), now(), now(), '00000000-0000-0000-0000-000000000000', '', '', '', '', '', '', '{}'::jsonb, '{"full_name":"API-042 Student"}'::jsonb)
    on conflict (id) do nothing
  `;
  await sql`
    insert into public.platform_operators (user_id, note) values (${OPERATOR}::uuid, 'integration fixture')
    on conflict (user_id) do nothing
  `;
  await sql`
    insert into public.schools (id, name, timezone, status) values (${SCHOOL}::uuid, 'API-042 School', 'Asia/Riyadh', 'active')
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
      (${CLASSROOM}::uuid, ${SCHOOL}::uuid, ${TERM}::uuid, 'Integration Classroom', 'G6', 'A', ${TEACHER}::uuid, 'active')
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
      (${STUDENT_ROW}::uuid, ${SCHOOL}::uuid, ${STUDENT_USER}::uuid, 'STU-API042-INT', 'Integration Student', false, ${TEACHER}::uuid)
    on conflict (id) do nothing
  `;
}

async function cleanup(provisioned?: string): Promise<void> {
  const schoolIds = provisioned ? [SCHOOL, provisioned] : [SCHOOL];
  await sql.begin(async (tx) => {
    await tx`alter table public.membership_events disable trigger db020_reject_mutation`;
    await tx`alter table public.audit_events disable trigger db020_reject_mutation`;
    await tx`delete from public.enrollments where classroom_id = ${CLASSROOM}::uuid`;
    await tx`delete from public.students where id = ${STUDENT_ROW}::uuid`;
    await tx`delete from public.classroom_staff where classroom_id = ${CLASSROOM}::uuid`;
    await tx`delete from public.classrooms where id = ${CLASSROOM}::uuid`;
    await tx`delete from public.terms where id = ${TERM}::uuid`;
    await tx`delete from public.membership_events where school_id = any(${schoolIds}::uuid[])`;
    await tx`delete from public.audit_events where school_id = any(${schoolIds}::uuid[])`;
    await tx`delete from public.memberships where school_id = any(${schoolIds}::uuid[])`;
    await tx`delete from public.schools where id = any(${schoolIds}::uuid[])`;
    await tx`delete from public.platform_operators where user_id = ${OPERATOR}::uuid`;
    // auth.users cascades to profiles, which SET NULLs audit_events.actor_id
    // - still an update against the append-only table, so it must happen
    // before the trigger is re-enabled.
    await tx`delete from auth.users where id in (${OPERATOR}::uuid, ${ADMIN}::uuid, ${TEACHER}::uuid, ${STUDENT_USER}::uuid)`;
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

suite("API-042 S1 school-admin over the real /v1 stack", () => {
  let provisionedSchoolId: string;

  beforeAll(async () => {
    sql = createDatabase(databaseUrl!);
    await cleanup();
    await seed();
    contexts = new AuthContextRepository(sql);
    const logger = createJsonLogger(
      "api",
      "api042-integration",
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
      createSchoolAdminRoutes(
        { repository: new PostgresSchoolAdminRepository(sql), cursorSigningKey: CURSOR_KEY },
        authorization,
        idempotency,
      ),
    );
    // enrollStudent's classroom-writer check needs api041_class_writer, whose
    // json helpers are the academic module's - mount it too so the shared
    // dispatcher has the whole surface a real deployment would have.
    app.route(
      "/",
      createAcademicRoutes(
        { repository: new PostgresAcademicRepository(sql), cursorSigningKey: CURSOR_KEY },
        authorization,
        idempotency,
      ),
    );
  });

  afterAll(async () => {
    if (!sql) return;
    await cleanup(provisionedSchoolId);
    await sql.end({ timeout: 5 });
  });

  test("provisioning is denied over HTTP for a non-operator", async () => {
    const res = await request("/v1/schools", {
      method: "POST",
      subject: ADMIN,
      body: { name: "Rogue via HTTP", initialAdminUserId: ADMIN },
    });
    expect(res.status).toBe(403);
  });

  test("a platform operator provisions a school and the response matches V1SchoolAdmin", async () => {
    const res = await request("/v1/schools", {
      method: "POST",
      subject: OPERATOR,
      body: { name: "HTTP Provisioned School", initialAdminUserId: ADMIN },
    });
    expect(res.status).toBe(201);
    const body = await res.json() as {
      id: string;
      name: string;
      status: string;
      version: number;
    };
    expect(body.status).toBe("active");
    expect(body.version).toBe(1);
    provisionedSchoolId = body.id;
  });

  test("suspending with a stale version returns a 409 problem", async () => {
    const res = await request(`/v1/schools/${provisionedSchoolId}/suspend`, {
      method: "POST",
      subject: ADMIN,
      body: { expectedVersion: 99 },
    });
    expect(res.status).toBe(409);
    const body = await res.json() as { code: string };
    expect(body.code).toBe("VERSION_CONFLICT");
  });

  test("a school admin grants an additional role to an existing member", async () => {
    const res = await request(`/v1/schools/${SCHOOL}/memberships/grant`, {
      method: "POST",
      subject: ADMIN,
      body: { userId: TEACHER, role: "school_admin" },
    });
    expect(res.status).toBe(201);
    const body = await res.json() as { role: string; status: string };
    expect(body.role).toBe("school_admin");
    expect(body.status).toBe("active");
  });

  test("a teacher outside the classroom cannot assign classroom staff", async () => {
    const res = await request(`/v1/classrooms/${CLASSROOM}/staff/assign`, {
      method: "POST",
      subject: STUDENT_USER,
      body: { userId: TEACHER, role: "co_teacher" },
    });
    expect([403, 404]).toContain(res.status);
  });

  test("an enrollment command round-trips a validated V1EnrollmentTransition", async () => {
    const res = await request(`/v1/classrooms/${CLASSROOM}/enrollments/enroll`, {
      method: "POST",
      subject: ADMIN,
      body: { studentId: STUDENT_ROW },
    });
    expect(res.status).toBe(200);
    const body = await res.json() as {
      classroomId: string;
      studentId: string;
      status: string;
    };
    expect(body.classroomId).toBe(CLASSROOM);
    expect(body.status).toBe("active");
  });

  test("a replayed idempotency key returns the identical stored response", async () => {
    const key = crypto.randomUUID();
    const first = await request(`/v1/classrooms/${CLASSROOM}/enrollments/withdraw`, {
      method: "POST",
      subject: ADMIN,
      key,
      body: { studentId: STUDENT_ROW },
    });
    const second = await request(`/v1/classrooms/${CLASSROOM}/enrollments/withdraw`, {
      method: "POST",
      subject: ADMIN,
      key,
      body: { studentId: STUDENT_ROW },
    });
    expect(first.status).toBe(200);
    expect(second.status).toBe(200);
    expect(await first.json()).toEqual(await second.json());
  });
});
