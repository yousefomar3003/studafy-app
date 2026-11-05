/**
 * Studafy School Portal over real SQL (docs/planning/school-portal.md):
 * routes, permission middleware, idempotency and api062 together. A website
 * administrator with no school membership creates a school, asks a teacher
 * by Studafy ID, the teacher accepts in the app, the school reads the class,
 * and an unlink hides it again. The SQL's own rules are in
 * supabase/tests/school_portal.sql.
 */
import { afterAll, beforeAll, describe, expect, test } from "bun:test";
import { Hono } from "hono";
import type { LogLevel } from "@studafy/contracts";
import { createDatabase, type Sql } from "@studafy/database";
import { createJsonLogger } from "@studafy/observability";
import { integrationSuite, removeFixtures } from "@studafy/test-support";
import { AuthContextRepository } from "../../src/auth/context";
import type { Actor } from "../../src/auth/middleware";
import type { AuthorizationEnv } from "../../src/authorization/middleware";
import { createAuthorizationDependencies } from "../../src/authorization/middleware";
import { PostgresAuthorizationRepository } from "../../src/authorization/repository";
import { PostgresIdempotencyRepository } from "../../src/platform/idempotency";
import {
  createSchoolPortalRoutes,
  PostgresSchoolPortalRepository,
} from "../../src/school-portal/routes";
import { testAssurance } from "../support/assurance";

const databaseUrl = process.env["DATABASE_URL"];
const suite = integrationSuite(describe);

const P = "5c900000-0000-4000-8000-0000000000";
const SCHOOL = `${P}01`;
const TERM = `${P}02`;
const CLASSROOM = `${P}03`;
const TEACHER = `${P}11`;
const STUDENT = `${P}12`;
const ADMIN = `${P}13`;
const STUDENT_ROW = `${P}21`;

let sql: Sql;
let app: Hono<AuthorizationEnv>;

async function user(id: string, name: string, email: string): Promise<void> {
  await sql`
    insert into auth.users (
      id, email, encrypted_password, aud, role, email_confirmed_at,
      created_at, updated_at, instance_id, confirmation_token, recovery_token,
      email_change, email_change_token_new, email_change_token_current,
      phone_change_token, raw_app_meta_data, raw_user_meta_data
    ) values (
      ${id}::uuid, ${email}, 'synthetic-not-a-secret', 'authenticated',
      'authenticated', now(), now(), now(),
      '00000000-0000-0000-0000-000000000000', '', '', '', '', '', '',
      '{}'::jsonb, ${JSON.stringify({ full_name: name })}::jsonb
    ) on conflict (id) do nothing`;
  await sql`update public.profiles set display_name = ${name} where id = ${id}::uuid`;
}

async function cleanup(): Promise<void> {
  await removeFixtures(sql, {
    schoolIds: [SCHOOL],
    userIds: [TEACHER, STUDENT, ADMIN],
  });
}

async function seed(): Promise<void> {
  await user(TEACHER, "Rania Haddad", "portal.teacher@synthetic.studafy.test");
  await user(STUDENT, "Omar Khatib", "portal.student@synthetic.studafy.test");
  await user(ADMIN, "Head of Cedar", "portal.head@synthetic.studafy.test");
  // A website-only adult: no membership anywhere.
  await sql`update public.profiles set account_kind = 'adult' where id = ${ADMIN}::uuid`;
  await sql`insert into public.schools (id, name, timezone, status)
    values (${SCHOOL}::uuid, 'Teacher Workspace', 'Asia/Amman', 'active')`;
  await sql`
    insert into public.memberships (school_id, user_id, role, active, status, version) values
      (${SCHOOL}::uuid, ${TEACHER}::uuid, 'teacher', true, 'active', 1),
      (${SCHOOL}::uuid, ${STUDENT}::uuid, 'student', true, 'active', 1)`;
  await sql`insert into public.terms (id, school_id, name, starts_on, ends_on, active, status)
    values (${TERM}::uuid, ${SCHOOL}::uuid, 'Term', current_date - 10, current_date + 90, true, 'active')`;
  await sql`insert into public.classrooms (id, school_id, term_id, name, grade, section, teacher_id, status, version)
    values (${CLASSROOM}::uuid, ${SCHOOL}::uuid, ${TERM}::uuid, 'Grade 7 Science', '7', 'A', ${TEACHER}::uuid, 'active', 1)`;
  await sql`
    insert into public.classroom_staff (school_id, classroom_id, membership_id, user_id, role)
    select ${SCHOOL}::uuid, ${CLASSROOM}::uuid, m.id, m.user_id, 'lead_teacher'
    from public.memberships m where m.school_id = ${SCHOOL}::uuid and m.user_id = ${TEACHER}::uuid`;
  await sql`
    insert into public.students (id, school_id, user_id, studafy_id, display_name, provisional, created_by)
    values (${STUDENT_ROW}::uuid, ${SCHOOL}::uuid, ${STUDENT}::uuid, 'STU-PORTAL-1', 'Omar Khatib', false, ${TEACHER}::uuid)`;
  await sql`
    insert into public.enrollments (classroom_id, student_id, school_id, status, active)
    values (${CLASSROOM}::uuid, ${STUDENT_ROW}::uuid, ${SCHOOL}::uuid, 'active', true)`;
}

async function request(
  path: string,
  subject: string,
  body?: unknown,
): Promise<Response> {
  const headers = new Headers({ "x-test-subject": subject });
  if (body !== undefined) {
    headers.set("content-type", "application/json");
    headers.set("idempotency-key", crypto.randomUUID());
  }
  return await app.request(path, {
    method: body === undefined ? "GET" : "POST",
    headers,
    ...(body !== undefined ? { body: JSON.stringify(body) } : {}),
  });
}

function build(enabled: boolean): Hono<AuthorizationEnv> {
  const contexts = new AuthContextRepository(sql);
  const logger = createJsonLogger(
    "api",
    "school-portal-it",
    "debug" as LogLevel,
    () => undefined,
  );
  const authorization = createAuthorizationDependencies(
    logger,
    new PostgresAuthorizationRepository(sql),
  );
  const routes = new Hono<AuthorizationEnv>();
  routes.use("*", async (c, next) => {
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
      aal2: false,
      mfaRequiredByPolicy: false,
    };
    c.set("requestId", crypto.randomUUID());
    c.set("actor", actor);
    await next();
  });
  routes.route(
    "/",
    createSchoolPortalRoutes(
      { repository: new PostgresSchoolPortalRepository(sql), enabled },
      authorization,
      { logger, repository: new PostgresIdempotencyRepository(sql) },
    ),
  );
  return routes;
}

suite("School Portal over real SQL", () => {
  beforeAll(async () => {
    sql = createDatabase(databaseUrl!);
    await cleanup();
    await seed();
    app = build(true);
  });

  afterAll(async () => {
    if (!sql) return;
    await cleanup();
    await sql.end({ timeout: 5 });
  });

  test("a school links a teacher by Studafy ID and reads the class until unlinked", async () => {
    const created = await request("/v1/school-portal/orgs", ADMIN, {
      name: "Cedar Grove School",
      country: "Jordan",
      city: "Amman",
      kind: "private",
      jobTitle: "Principal",
      adult: true,
    });
    expect(created.status).toBe(201);
    const org = (await created.json() as { id: string }).id;

    const [teacher] = await sql<{ public_id: string }[]>`
      select public_id from public.profiles where id = ${TEACHER}::uuid`;
    const [student] = await sql<{ public_id: string }[]>`
      select public_id from public.profiles where id = ${STUDENT}::uuid`;

    const notATeacher = await request(
      `/v1/school-portal/orgs/${org}/link-requests`,
      ADMIN,
      { studafyId: student!.public_id },
    );
    expect(notATeacher.status).toBe(404);
    expect((await notATeacher.json() as { code: string }).code).toBe(
      "TEACHER_NOT_FOUND",
    );

    const asked = await request(
      `/v1/school-portal/orgs/${org}/link-requests`,
      ADMIN,
      { studafyId: teacher!.public_id },
    );
    expect(asked.status).toBe(201);
    const link = (await asked.json() as { linkId: string }).linkId;

    // Before the teacher accepts, the class is not the school's to read.
    const early = await request(
      `/v1/school-portal/orgs/${org}/classes/${CLASSROOM}/roster`,
      ADMIN,
    );
    expect(early.status).toBe(404);

    const mine = await request("/v1/me/school-links", TEACHER);
    expect(mine.status).toBe(200);
    const links = (await mine.json() as {
      links: { id: string; org: { name: string } }[];
    }).links;
    expect(links.map((l) => [l.id, l.org.name])).toEqual([[
      link,
      "Cedar Grove School",
    ]]);

    const accepted = await request(
      `/v1/me/school-links/${link}/decision`,
      TEACHER,
      { decision: "accept" },
    );
    expect(accepted.status).toBe(200);

    const classes = await request(
      `/v1/school-portal/orgs/${org}/classes`,
      ADMIN,
    );
    expect(
      (await classes.json() as { classes: { name: string }[] }).classes.map((
        c,
      ) => c.name),
    ).toEqual(["Grade 7 Science"]);
    const roster = await request(
      `/v1/school-portal/orgs/${org}/classes/${CLASSROOM}/roster`,
      ADMIN,
    );
    expect(roster.status).toBe(200);
    expect(
      (await roster.json() as { students: { email: string }[] }).students[0]
        ?.email,
    ).toBe("portal.student@synthetic.studafy.test");

    const unlinked = await request(
      `/v1/me/school-links/${link}/unlink`,
      TEACHER,
      {},
    );
    expect(unlinked.status).toBe(200);
    const after = await request(
      `/v1/school-portal/orgs/${org}/classes/${CLASSROOM}/roster`,
      ADMIN,
    );
    expect(after.status).toBe(404);
  });

  test("with the switch off nothing answers, whoever asks", async () => {
    const off = build(false);
    for (const subject of [ADMIN, TEACHER]) {
      const response = await off.request("/v1/me/school-links", {
        headers: { "x-test-subject": subject },
      });
      expect(response.status).toBe(404);
    }
  });
});
