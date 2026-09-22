/**
 * A teacher creates a class through the real /v1 stack.
 *
 * This exists because relaxing the guard inside private.api041_command was
 * not enough and looked like it was: private.authz_authorize decides first,
 * its classroom.create branch asked is_school_admin, and a denial on a
 * concealed resource is reported as 404. Calling the dispatcher directly
 * skips that decision entirely, so the only test that can prove a teacher
 * may create a class is one that goes through the authorization middleware.
 */
import { afterAll, beforeAll, describe, expect, test } from "bun:test";
import { Hono } from "hono";
import { testAssurance } from "../support/assurance";
import type { LogLevel } from "@studafy/contracts";
import { createDatabase, type Sql } from "@studafy/database";
import { createJsonLogger } from "@studafy/observability";
import { AuthContextRepository } from "../../src/auth/context";
import type { Actor } from "../../src/auth/middleware";
import type { AuthorizationEnv } from "../../src/authorization/middleware";
import { createAuthorizationDependencies } from "../../src/authorization/middleware";
import { PostgresAuthorizationRepository } from "../../src/authorization/repository";
import { PostgresIdempotencyRepository } from "../../src/platform/idempotency";
import { PostgresAcademicRepository } from "../../src/academic/repository";
import { createAcademicRoutes } from "../../src/academic/routes";

const databaseUrl = process.env["DATABASE_URL"];
const suite = databaseUrl ? describe : describe.skip;

const TEACHER = "5f410000-0000-4000-8000-0000000000a1";
const PARENT = "5f410000-0000-4000-8000-0000000000a2";
const SCHOOL = "5f410000-0000-4000-8000-0000000000b1";
const TERM = "5f410000-0000-4000-8000-0000000000c1";

let sql: Sql;
let contexts: AuthContextRepository;
let app: Hono<AuthorizationEnv>;

function authUser(id: string, email: string) {
  return sql`
    insert into auth.users (
      id, email, encrypted_password, aud, role, email_confirmed_at,
      created_at, updated_at, instance_id, confirmation_token, recovery_token,
      email_change, email_change_token_new, email_change_token_current,
      phone_change_token, raw_app_meta_data, raw_user_meta_data
    ) values (
      ${id}::uuid, ${email}, 'synthetic-not-a-secret', 'authenticated',
      'authenticated', now(), now(), now(),
      '00000000-0000-0000-0000-000000000000', '', '', '', '', '', '',
      '{}'::jsonb, '{}'::jsonb
    ) on conflict (id) do nothing
  `;
}

async function seed(): Promise<void> {
  await authUser(TEACHER, "api041.teacher.create@synthetic.studafy.test");
  await authUser(PARENT, "api041.parent.create@synthetic.studafy.test");
  await sql`
    insert into public.schools (id, name, timezone, status)
    values (${SCHOOL}::uuid, 'Teacher Creates Class School', 'Asia/Riyadh', 'active')
    on conflict (id) do update set status = 'active'
  `;
  // A teacher and nothing else: no school_admin exists in this product.
  await sql`
    insert into public.memberships (school_id, user_id, role, active, status, version) values
      (${SCHOOL}::uuid, ${TEACHER}::uuid, 'teacher', true, 'active', 1),
      (${SCHOOL}::uuid, ${PARENT}::uuid, 'parent', true, 'active', 1)
    on conflict (school_id, user_id, role) do nothing
  `;
  await sql`
    insert into public.terms (id, school_id, name, starts_on, ends_on, active, status)
    values (${TERM}::uuid, ${SCHOOL}::uuid, 'Term', current_date - 5, current_date + 90, true, 'active')
    on conflict (id) do nothing
  `;
}

async function cleanup(): Promise<void> {
  await sql.begin(async (tx) => {
    await tx`alter table public.membership_events disable trigger db020_reject_mutation`;
    await tx`alter table public.audit_events disable trigger db020_reject_mutation`;
    await tx`delete from public.class_schedules where school_id = ${SCHOOL}::uuid`;
    await tx`delete from public.classroom_staff where school_id = ${SCHOOL}::uuid`;
    await tx`delete from public.classrooms where school_id = ${SCHOOL}::uuid`;
    await tx`delete from public.terms where school_id = ${SCHOOL}::uuid`;
    await tx`delete from public.membership_events where school_id = ${SCHOOL}::uuid`;
    await tx`delete from public.audit_events where school_id = ${SCHOOL}::uuid`;
    await tx`delete from public.idempotency_records where school_id = ${SCHOOL}::uuid`;
    await tx`delete from public.memberships where school_id = ${SCHOOL}::uuid`;
    await tx`delete from public.schools where id = ${SCHOOL}::uuid`;
    await tx`delete from auth.users where id in (${TEACHER}::uuid, ${PARENT}::uuid)`;
    await tx`alter table public.membership_events enable trigger db020_reject_mutation`;
    await tx`alter table public.audit_events enable trigger db020_reject_mutation`;
  });
}

function createClass(subject: string, name: string) {
  const headers = new Headers();
  headers.set("x-test-subject", subject);
  headers.set("content-type", "application/json");
  headers.set("idempotency-key", crypto.randomUUID());
  return app.request("/v1/classrooms", {
    method: "POST",
    headers,
    body: JSON.stringify({
      schoolId: SCHOOL,
      name,
      grade: "7",
      section: "A",
      room: null,
      schedule: [],
    }),
  });
}

suite("a teacher creates a class over the real /v1 stack", () => {
  beforeAll(async () => {
    sql = createDatabase(databaseUrl!);
    await cleanup();
    await seed();
    contexts = new AuthContextRepository(sql);
    const logger = createJsonLogger(
      "api",
      "api041-teacher-create",
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
          assuranceLevel: testAssurance(c),
          authMethods: [],
          claims: {},
        },
        context,
        aal2: testAssurance(c) === "aal2",
        mfaRequiredByPolicy: false,
      };
      c.set("requestId", crypto.randomUUID());
      c.set("actor", actor);
      await next();
    });
    app.route(
      "/",
      createAcademicRoutes(
        {
          repository: new PostgresAcademicRepository(sql),
          cursorSigningKey: "api041-teacher-create-cursor-key-0000000001",
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

  test("a teacher with no admin role creates a class", async () => {
    const res = await createClass(TEACHER, "Grade 7 Science");
    expect(res.status).toBe(201);
    const body = await res.json() as { name: string; id: string };
    expect(body.name).toBe("Grade 7 Science");
  });

  test("the creator is recorded as lead teacher of their own class", async () => {
    const rows = await sql<{ role: string; membership_role: string }[]>`
      select cs.role::text as role, m.role::text as membership_role
      from public.classroom_staff cs
      join public.memberships m on m.id = cs.membership_id
      where cs.school_id = ${SCHOOL}::uuid and cs.user_id = ${TEACHER}::uuid
    `;
    expect(rows).toHaveLength(1);
    expect(rows[0]!.role).toBe("lead_teacher");
    // Not merely "some membership of this user": the teaching one.
    expect(rows[0]!.membership_role).toBe("teacher");
  });

  test("a parent of the same school still cannot create a class", async () => {
    const res = await createClass(PARENT, "Parent Attempt");
    expect([403, 404]).toContain(res.status);
  });
});
