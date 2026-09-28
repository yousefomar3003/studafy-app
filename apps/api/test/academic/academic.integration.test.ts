/**
 * API-041 end-to-end proof against a real local Postgres.
 *
 * The real Hono academic routes, the real AUTH-031 authorization middleware,
 * the real API-040 durable idempotency and the real SQL domain functions run
 * together over HTTP-style requests. This is the parity evidence for removing
 * the `approve-paper-grade` and `publish-grade-result` Edge Functions: the
 * review and publish transitions they performed are executed transactionally
 * through `/v1` with audit, outbox and idempotency coupling.
 *
 * The SQL-level semantics (forced rollback coupling, answer safety, least
 * privilege) are proven by supabase/tests/api041_academic.sql.
 */
import { afterAll, beforeAll, describe, expect, test } from "bun:test";
import { Hono } from "hono";
import { testAssurance } from "../support/assurance";
import type { LogLevel } from "@studafy/contracts";
import { createDatabase, type Sql } from "@studafy/database";
import { createJsonLogger } from "@studafy/observability";
import { AuthContextRepository } from "../../src/auth/context";
import { withRequestContext } from "../../src/platform/dbContext";
import type { Actor } from "../../src/auth/middleware";
import type { AuthorizationEnv } from "../../src/authorization/middleware";
import { createAuthorizationDependencies } from "../../src/authorization/middleware";
import { PostgresAuthorizationRepository } from "../../src/authorization/repository";
import { PostgresIdempotencyRepository } from "../../src/platform/idempotency";
import { PostgresAcademicRepository } from "../../src/academic/repository";
import {
  createAcademicRoutes,
  createSubmissionHistoryRoutes,
} from "../../src/academic/routes";
import { integrationSuite, removeFixtures } from "@studafy/test-support";

const databaseUrl = process.env["DATABASE_URL"];
const suite = integrationSuite(describe);

const TEACHER_A = "5f410000-0000-4000-8000-0000000000a1";
const STUDENT_USER = "5f410000-0000-4000-8000-0000000000a2";
const GUARDIAN = "5f410000-0000-4000-8000-0000000000a3";
const TEACHER_B = "5f410000-0000-4000-8000-0000000000a4";
const ADMIN = "5f410000-0000-4000-8000-0000000000a5";
const ASSISTANT = "5f410000-0000-4000-8000-0000000000a6";
/** A parent linked by the child's ID: a verified link and no membership. */
const LINKED_PARENT = "5f410000-0000-4000-8000-0000000000a7";
const SCHOOL_A = "5f410000-0000-4000-8000-0000000000b1";
const SCHOOL_B = "5f410000-0000-4000-8000-0000000000b2";
const TERM_A = "5f410000-0000-4000-8000-0000000000c1";
const CLASS_A = "5f410000-0000-4000-8000-0000000000d1";
const STUDENT_ROW = "5f410000-0000-4000-8000-0000000000e1";

const CURSOR_KEY = "api041-integration-cursor-key-0000000001";

/** Fixed deadlines so an idempotent retry hashes the identical body. */
const FIRST_DUE_AT = "2026-10-01T10:00:00.000Z";
const FIRST_CLOSES_AT = "2026-10-02T10:00:00.000Z";

function firstAssignmentBody() {
  return {
    classroomId: CLASS_A,
    title: "Atomic models essay",
    instructions: "Draw and label the parts.",
    dueAt: FIRST_DUE_AT,
    closesAt: FIRST_CLOSES_AT,
  };
}

/** Next Monday 05:00 UTC is Monday 08:00 in Asia/Riyadh (UTC+3, no DST). */
function nextMondayFiveUtc(): { startsAt: string; endsAt: string } {
  const now = new Date();
  const monday = new Date(
    Date.UTC(
      now.getUTCFullYear(),
      now.getUTCMonth(),
      now.getUTCDate(),
      5,
      0,
      0,
    ),
  );
  const add = monday.getUTCDay() === 1 ? 7 : (8 - monday.getUTCDay()) % 7;
  monday.setUTCDate(monday.getUTCDate() + add);
  const ends = new Date(monday.getTime() + 60 * 60 * 1000);
  return { startsAt: monday.toISOString(), endsAt: ends.toISOString() };
}

let sql: Sql;
let contexts: AuthContextRepository;
let app: Hono<AuthorizationEnv>;
let lessonStartsAt: string;
let lessonEndsAt: string;

async function seed(): Promise<void> {
  await sql`
    insert into auth.users (
      id, email, encrypted_password, aud, role, email_confirmed_at,
      created_at, updated_at, instance_id, confirmation_token, recovery_token,
      email_change, email_change_token_new, email_change_token_current,
      phone_change_token, raw_app_meta_data, raw_user_meta_data
    ) values
      (${TEACHER_A}::uuid, 'api041.a@synthetic.studafy.test', 'synthetic-not-a-secret', 'authenticated', 'authenticated', now(), now(), now(), '00000000-0000-0000-0000-000000000000', '', '', '', '', '', '', '{}'::jsonb, '{"full_name":"API-041 Teacher A"}'::jsonb),
      (${STUDENT_USER}::uuid, 'api041.s@synthetic.studafy.test', 'synthetic-not-a-secret', 'authenticated', 'authenticated', now(), now(), now(), '00000000-0000-0000-0000-000000000000', '', '', '', '', '', '', '{}'::jsonb, '{"full_name":"API-041 Student"}'::jsonb),
      (${GUARDIAN}::uuid, 'api041.g@synthetic.studafy.test', 'synthetic-not-a-secret', 'authenticated', 'authenticated', now(), now(), now(), '00000000-0000-0000-0000-000000000000', '', '', '', '', '', '', '{}'::jsonb, '{"full_name":"API-041 Guardian"}'::jsonb),
      (${TEACHER_B}::uuid, 'api041.b@synthetic.studafy.test', 'synthetic-not-a-secret', 'authenticated', 'authenticated', now(), now(), now(), '00000000-0000-0000-0000-000000000000', '', '', '', '', '', '', '{}'::jsonb, '{"full_name":"API-041 Teacher B"}'::jsonb),
      (${ADMIN}::uuid, 'api041.admin@synthetic.studafy.test', 'synthetic-not-a-secret', 'authenticated', 'authenticated', now(), now(), now(), '00000000-0000-0000-0000-000000000000', '', '', '', '', '', '', '{}'::jsonb, '{"full_name":"API-041 Admin"}'::jsonb),
      (${ASSISTANT}::uuid, 'api041.assistant@synthetic.studafy.test', 'synthetic-not-a-secret', 'authenticated', 'authenticated', now(), now(), now(), '00000000-0000-0000-0000-000000000000', '', '', '', '', '', '', '{}'::jsonb, '{"full_name":"API-041 Assistant"}'::jsonb),
      (${LINKED_PARENT}::uuid, 'api041.parent@synthetic.studafy.test', 'synthetic-not-a-secret', 'authenticated', 'authenticated', now(), now(), now(), '00000000-0000-0000-0000-000000000000', '', '', '', '', '', '', '{}'::jsonb, '{"full_name":"API-041 Linked Parent"}'::jsonb)
    on conflict (id) do nothing
  `;
  await sql`
    insert into public.schools (id, name, timezone, status) values
      (${SCHOOL_A}::uuid, 'API-041 School A', 'Asia/Riyadh', 'active'),
      (${SCHOOL_B}::uuid, 'API-041 School B', 'Asia/Riyadh', 'active')
    on conflict (id) do update set status = 'active'
  `;
  await sql`
    insert into public.memberships (school_id, user_id, role, active) values
      (${SCHOOL_A}::uuid, ${TEACHER_A}::uuid, 'teacher', true),
      (${SCHOOL_A}::uuid, ${STUDENT_USER}::uuid, 'student', true),
      (${SCHOOL_A}::uuid, ${GUARDIAN}::uuid, 'parent', true),
      (${SCHOOL_A}::uuid, ${ADMIN}::uuid, 'school_admin', true),
      (${SCHOOL_A}::uuid, ${ASSISTANT}::uuid, 'teacher', true),
      (${SCHOOL_B}::uuid, ${TEACHER_B}::uuid, 'teacher', true)
    on conflict (school_id, user_id, role) do update set active = true
  `;
  await sql`
    insert into public.terms (id, school_id, name, starts_on, ends_on, active) values
      (${TERM_A}::uuid, ${SCHOOL_A}::uuid, 'API-041 Term', current_date - 30, current_date + 90, true)
    on conflict (id) do update set active = true
  `;
  await sql`
    insert into public.classrooms (id, school_id, term_id, name, grade, section, teacher_id) values
      (${CLASS_A}::uuid, ${SCHOOL_A}::uuid, ${TERM_A}::uuid, 'API-041 Class', 'G6', 'A', ${TEACHER_A}::uuid)
    on conflict (id) do update set status = 'active'
  `;
  await sql`
    insert into public.classroom_staff (school_id, classroom_id, membership_id, user_id, role)
    select ${SCHOOL_A}::uuid, ${CLASS_A}::uuid, m.id, ${TEACHER_A}::uuid, 'lead_teacher'
    from public.memberships m
    where m.school_id = ${SCHOOL_A}::uuid and m.user_id = ${TEACHER_A}::uuid
    on conflict do nothing
  `;
  await sql`
    insert into public.classroom_staff (school_id, classroom_id, membership_id, user_id, role)
    select ${SCHOOL_A}::uuid, ${CLASS_A}::uuid, m.id, ${ASSISTANT}::uuid, 'assistant'
    from public.memberships m
    where m.school_id = ${SCHOOL_A}::uuid and m.user_id = ${ASSISTANT}::uuid
    on conflict do nothing
  `;
  await sql`
    insert into public.students (id, school_id, user_id, studafy_id, display_name, provisional, created_by) values
      (${STUDENT_ROW}::uuid, ${SCHOOL_A}::uuid, ${STUDENT_USER}::uuid, 'STU-API041-0001', 'API-041 Student', false, ${TEACHER_A}::uuid)
    on conflict (id) do nothing
  `;
  await sql`
    insert into public.guardian_links (student_id, guardian_id, status, relationship, verified_by, verified_at) values
      (${STUDENT_ROW}::uuid, ${GUARDIAN}::uuid, 'verified', 'parent', ${TEACHER_A}::uuid, now()),
      (${STUDENT_ROW}::uuid, ${LINKED_PARENT}::uuid, 'verified', 'parent', ${TEACHER_A}::uuid, now())
    on conflict (student_id, guardian_id) do nothing
  `;
  await sql`
    insert into public.enrollments (classroom_id, student_id, active) values
      (${CLASS_A}::uuid, ${STUDENT_ROW}::uuid, true)
    on conflict (classroom_id, student_id) do update set active = true
  `;
  const lesson = nextMondayFiveUtc();
  lessonStartsAt = lesson.startsAt;
  lessonEndsAt = lesson.endsAt;
  await sql`
    insert into public.class_schedules (school_id, classroom_id, weekday, starts_at, ends_at, effective_from)
    values (
      ${SCHOOL_A}::uuid, ${CLASS_A}::uuid,
      (extract(isodow from ${lessonStartsAt}::timestamptz at time zone 'Asia/Riyadh'))::smallint,
      (${lessonStartsAt}::timestamptz at time zone 'Asia/Riyadh')::time,
      (${lessonStartsAt}::timestamptz at time zone 'Asia/Riyadh')::time + interval '1 hour',
      current_date - 7
    )
    on conflict do nothing
  `;
}

/**
 * Removes the fixture. History tables are append-only in production
 * (db020_reject_mutation and the api041_immutable_* triggers), so their rows
 * are removed with the guards disabled inside one transaction. The disabling
 * ALTER TABLE statements are themselves transactional: a failure rolls back
 * to fully guarded tables, and the re-enable runs before commit.
 */
async function cleanup(): Promise<void> {
  await removeFixtures(sql, {
    schoolIds: [SCHOOL_A, SCHOOL_B],
    userIds: [
      TEACHER_A,
      STUDENT_USER,
      GUARDIAN,
      TEACHER_B,
      ADMIN,
      ASSISTANT,
      LINKED_PARENT,
    ],
  });
}

interface RequestInput {
  method?: "GET" | "POST";
  subject: string;
  key?: string;
  body?: unknown;
  requestId?: string;
}

async function request(path: string, input: RequestInput): Promise<Response> {
  const headers = new Headers();
  headers.set("x-test-subject", input.subject);
  if (input.requestId) headers.set("x-test-request-id", input.requestId);
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

async function scalar(query: ReturnType<typeof sql>): Promise<unknown> {
  const rows = await query as unknown as { result?: unknown }[];
  return rows[0]?.result ?? null;
}

suite("API-041 academic slices over the real /v1 stack", () => {
  let assignmentId: string;
  let assessmentId: string;
  let gradeResultId: string;
  let sessionId: string;

  beforeAll(async () => {
    sql = createDatabase(databaseUrl!);
    await cleanup();
    await seed();
    contexts = new AuthContextRepository(sql);
    const logger = createJsonLogger(
      "api",
      "api041-integration",
      "debug" as LogLevel,
      () => undefined,
    );

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
      c.set(
        "requestId",
        c.req.header("x-test-request-id") ?? crypto.randomUUID(),
      );
      c.set("actor", actor);
      await next();
    });
    app.route(
      "/",
      createAcademicRoutes(
        {
          repository: new PostgresAcademicRepository(sql),
          cursorSigningKey: CURSOR_KEY,
        },
        createAuthorizationDependencies(
          logger,
          new PostgresAuthorizationRepository(sql),
        ),
        { logger, repository: new PostgresIdempotencyRepository(sql) },
      ),
    );
    app.route(
      "/",
      createSubmissionHistoryRoutes(
        {
          repository: new PostgresAcademicRepository(sql),
          cursorSigningKey: CURSOR_KEY,
        },
        createAuthorizationDependencies(
          logger,
          new PostgresAuthorizationRepository(sql),
        ),
        { logger, repository: new PostgresIdempotencyRepository(sql) },
      ),
    );
  });

  afterAll(async () => {
    if (!sql) return;
    await cleanup();
    await sql.end({ timeout: 5 });
  });

  test("actor, tenant, and request settings are transaction-local on one pooled connection", async () => {
    const isolated = createDatabase(databaseUrl!, { max: 1 });
    try {
      const inside = await withRequestContext(
        isolated,
        { subject: TEACHER_A, schoolId: SCHOOL_A, requestId: "api041-local-1" },
        async (tx) => {
          const rows = await tx<{
            actor: string;
            school: string;
            request: string;
          }[]>`select current_setting('request.jwt.claim.sub',true) actor,
            current_setting('studafy.school_id',true) school,
            current_setting('studafy.request_id',true) request`;
          return rows[0]!;
        },
      );
      expect(inside).toEqual({
        actor: TEACHER_A,
        school: SCHOOL_A,
        request: "api041-local-1",
      });
      const outside = await isolated<{
        actor: string | null;
        school: string | null;
        request: string | null;
      }[]>`select nullif(current_setting('request.jwt.claim.sub',true),'') actor,
        nullif(current_setting('studafy.school_id',true),'') school,
        nullif(current_setting('studafy.request_id',true),'') request`;
      expect(outside[0]).toEqual({ actor: null, school: null, request: null });
    } finally {
      await isolated.end({ timeout: 5 });
    }
  });

  test("admin creates, updates, and replaces a classroom schedule", async () => {
    const create = await request("/v1/classrooms", {
      method: "POST",
      subject: ADMIN,
      key: "api041-it-classroom-create-1",
      body: {
        schoolId: SCHOOL_A,
        name: "API-041 New Class",
        grade: "G7",
        section: "B",
        room: "Lab 4",
        schedule: [{
          weekday: 2,
          startsAt: "08:00",
          endsAt: "09:00",
          effectiveFrom: "2026-09-01",
          effectiveUntil: null,
        }],
      },
    });
    expect(create.status).toBe(201);
    const created = await create.json() as { id: string; version: number };
    expect(created.version).toBe(1);

    const update = await request(`/v1/classrooms/${created.id}/update`, {
      method: "POST",
      subject: ADMIN,
      key: "api041-it-classroom-update-1",
      body: {
        expectedVersion: 1,
        name: "API-041 Updated Class",
        grade: "G7",
        section: "B",
        room: "Lab 5",
      },
    });
    expect(update.status).toBe(200);
    expect(((await update.json()) as { version: number }).version).toBe(2);

    const schedule = await request(
      `/v1/classrooms/${created.id}/schedule/replace`,
      {
        method: "POST",
        subject: ADMIN,
        key: "api041-it-classroom-schedule-1",
        body: {
          expectedVersion: 2,
          schedule: [{
            weekday: 3,
            startsAt: "10:00",
            endsAt: "11:00",
            effectiveFrom: "2026-09-01",
            effectiveUntil: null,
          }],
        },
      },
    );
    expect(schedule.status).toBe(200);
    const scheduled = await schedule.json() as {
      classroom: { version: number };
      schedule: unknown[];
    };
    expect(scheduled.classroom.version).toBe(3);
    expect(scheduled.schedule).toHaveLength(1);
  });

  test("teacher versions, publishes, and withdraws text content", async () => {
    const create = await request("/v1/resources", {
      method: "POST",
      subject: TEACHER_A,
      key: "api041-it-resource-create-1",
      body: {
        schoolId: SCHOOL_A,
        classroomId: CLASS_A,
        title: "Cell lesson",
        resourceType: "lesson_note",
        body: "First immutable version.",
        audience: "both",
      },
    });
    expect(create.status).toBe(201);
    const created = await create.json() as { id: string; version: number };

    const revise = await request(`/v1/resources/${created.id}/revise`, {
      method: "POST",
      subject: TEACHER_A,
      key: "api041-it-resource-revise-1",
      body: {
        expectedVersion: created.version,
        title: "Cell lesson revised",
        body: "Second immutable version.",
      },
    });
    expect(revise.status).toBe(200);
    const revised = await revise.json() as { version: number };

    const publish = await request(`/v1/resources/${created.id}/publish`, {
      method: "POST",
      subject: TEACHER_A,
      key: "api041-it-resource-publish-1",
      body: { expectedVersion: revised.version },
    });
    expect(publish.status).toBe(200);
    const published = await publish.json() as { version: number };

    const learnerFeed = await request(
      `/v1/resources?schoolId=${SCHOOL_A}&classroomId=${CLASS_A}`,
      { subject: STUDENT_USER },
    );
    expect(learnerFeed.status).toBe(200);
    expect(JSON.stringify(await learnerFeed.json())).toContain(
      "Cell lesson revised",
    );

    const withdraw = await request(`/v1/resources/${created.id}/withdraw`, {
      method: "POST",
      subject: TEACHER_A,
      key: "api041-it-resource-withdraw-1",
      body: { expectedVersion: published.version },
    });
    expect(withdraw.status).toBe(200);
    expect(((await withdraw.json()) as { state: string }).state).toBe(
      "withdrawn",
    );
    expect(
      await scalar(
        sql`select count(*)::int as result from public.resource_versions where resource_id=${created.id}::uuid`,
      ),
    ).toBe(2);
  });

  test("teacher creates and publishes an assignment transactionally", async () => {
    const create = await request("/v1/assignments", {
      method: "POST",
      subject: TEACHER_A,
      key: "api041-it-assignment-create-1",
      body: firstAssignmentBody(),
    });
    expect(create.status).toBe(201);
    const created = await create.json() as {
      id: string;
      state: string;
      version: number;
    };
    assignmentId = created.id;
    expect(created.state).toBe("draft");

    const publish = await request(`/v1/assignments/${assignmentId}/publish`, {
      method: "POST",
      subject: TEACHER_A,
      key: "aaaaaaaaaaaaaaaaaaaaaa01",
      requestId: "api041-it-publish-assignment",
      body: { expectedVersion: 1 },
    });
    expect(publish.status).toBe(200);
    const published = await publish.json() as {
      state: string;
      version: number;
    };
    expect(published.state).toBe("published");
    expect(published.version).toBe(2);

    // One transaction: the mutation, its audit row, its outbox row and the
    // idempotency completion all committed together.
    expect(
      await scalar(
        sql`select count(*)::int as result from public.assignments where id = ${assignmentId}::uuid`,
      ),
    ).toBe(1);
    expect(
      await scalar(
        sql`select count(*)::int as result from public.audit_events where request_id = 'api041-it-publish-assignment' and action = 'assignment_published'`,
      ),
    ).toBe(1);
    expect(
      await scalar(
        sql`select count(*)::int as result from public.notification_outbox where source_event_id = ${assignmentId}::uuid::text and template_key = 'academic.assignment_published'`,
      ),
    ).toBe(1);
    expect(
      await scalar(
        sql`select count(*)::int as result from public.notifications where entity_id = ${assignmentId}::uuid`,
      ),
    ).toBe(0);
    expect(
      await scalar(
        sql`select status::text as result from public.idempotency_records where idempotency_key = 'aaaaaaaaaaaaaaaaaaaaaa01' and scope = 'v1.publishAssignment'`,
      ),
    ).toBe("completed");
  });

  test("concurrent identical publication keys produce one mutation, audit, and outbox row", async () => {
    const create = await request("/v1/assignments", {
      method: "POST",
      subject: TEACHER_A,
      key: "api041-it-concurrent-create",
      body: {
        classroomId: CLASS_A,
        title: "Concurrent publication fixture",
        instructions: null,
        dueAt: "2026-10-03T10:00:00.000Z",
        closesAt: null,
      },
    });
    const id = (await create.json() as { id: string }).id;
    const publish = () =>
      request(`/v1/assignments/${id}/publish`, {
        method: "POST",
        subject: TEACHER_A,
        key: "api041-it-concurrent-publish",
        requestId: "api041-it-concurrent-publication",
        body: { expectedVersion: 1 },
      });
    const responses = await Promise.all([publish(), publish()]);
    expect(responses.some((response) => response.status === 200)).toBe(true);
    expect(responses.every((response) => [200, 409].includes(response.status)))
      .toBe(true);
    expect(
      await scalar(
        sql`select version::int as result from public.assignments where id=${id}::uuid`,
      ),
    ).toBe(2);
    expect(
      await scalar(
        sql`select count(*)::int as result from public.audit_events where request_id='api041-it-concurrent-publication' and action='assignment_published'`,
      ),
    ).toBe(1);
    expect(
      await scalar(
        sql`select count(*)::int as result from public.notification_outbox where source_event_id=${id}::uuid::text and template_key='academic.assignment_published'`,
      ),
    ).toBe(1);
  });

  test("cursor paging walks every published assignment", async () => {
    const second = await request("/v1/assignments", {
      method: "POST",
      subject: TEACHER_A,
      key: "api041-it-assignment-create-2",
      body: {
        classroomId: CLASS_A,
        title: "Second assignment",
        instructions: null,
        dueAt: new Date(Date.now() + 9 * 86_400_000).toISOString(),
        closesAt: null,
      },
    });
    expect(second.status).toBe(201);

    const seen: string[] = [];
    let cursor: string | null = null;
    do {
      const path =
        `/v1/assignments?schoolId=${SCHOOL_A}&classroomId=${CLASS_A}&pageSize=1${
          cursor ? `&cursor=${encodeURIComponent(cursor)}` : ""
        }`;
      const page = await request(path, { subject: TEACHER_A });
      expect(page.status).toBe(200);
      const body = await page.json() as {
        items: { id: string }[];
        nextCursor: string | null;
      };
      expect(body.items.length).toBeLessThanOrEqual(1);
      seen.push(...body.items.map((item) => item.id));
      cursor = body.nextCursor;
    } while (cursor);
    expect(seen).toHaveLength(3);
    expect(new Set(seen).size).toBe(3);
  });

  test("a lost response replays once without duplicating the assignment", async () => {
    const replay = await request("/v1/assignments", {
      method: "POST",
      subject: TEACHER_A,
      key: "api041-it-assignment-create-1",
      body: firstAssignmentBody(),
    });
    expect(replay.status).toBe(201);
    expect(replay.headers.get("idempotency-replayed")).toBe("true");
    expect(
      await scalar(
        sql`select count(*)::int as result from public.assignments where title = 'Atomic models essay'`,
      ),
    ).toBe(1);
  });

  test("a reused key with a changed body conflicts", async () => {
    const mismatch = await request("/v1/assignments", {
      method: "POST",
      subject: TEACHER_A,
      key: "api041-it-assignment-create-1",
      body: {
        classroomId: CLASS_A,
        title: "A different essay",
        instructions: null,
        dueAt: new Date(Date.now() + 7 * 86_400_000).toISOString(),
        closesAt: null,
      },
    });
    expect(mismatch.status).toBe(409);
    expect(((await mismatch.json()) as { code: string }).code).toBe(
      "IDEMPOTENCY_KEY_REUSED",
    );
  });

  test("stale optimistic versions are rejected without mutation", async () => {
    const stale = await request(`/v1/assignments/${assignmentId}/withdraw`, {
      method: "POST",
      subject: TEACHER_A,
      key: "aaaaaaaaaaaaaaaaaaaaaa02",
      body: { expectedVersion: 1 },
    });
    expect(stale.status).toBe(409);
    expect(((await stale.json()) as { code: string }).code).toBe(
      "VERSION_CONFLICT",
    );
    expect(
      await scalar(
        sql`select state::text as result from public.assignments where id = ${assignmentId}::uuid`,
      ),
    ).toBe("published");
  });

  test("the enrolled student submits inside the open window", async () => {
    const detail = await request(`/v1/assignments/${assignmentId}`, {
      subject: STUDENT_USER,
    });
    expect(detail.status).toBe(200);
    expect(((await detail.json()) as { id: string }).id).toBe(assignmentId);

    const submit = await request(`/v1/assignments/${assignmentId}/submit`, {
      method: "POST",
      subject: STUDENT_USER,
      key: "api041-it-submission-000001",
      body: { answerText: "My labelled diagram and explanation." },
    });
    expect(submit.status).toBe(201);
    const body = await submit.json() as { status: string; answerText: string };
    expect(body.status).toBe("submitted");
    expect(body.answerText).toBe("My labelled diagram and explanation.");
    expect(
      await scalar(
        sql`select count(*)::int as result from public.submission_attempts where school_id = ${SCHOOL_A}::uuid`,
      ),
    ).toBe(1);
  });

  test("the teacher lists the submission through the roster", async () => {
    const page = await request(
      `/v1/assignments/${assignmentId}/submissions?pageSize=10`,
      { subject: TEACHER_A },
    );
    expect(page.status).toBe(200);
    const body = await page.json() as {
      items: { studentId: string; status: string }[];
    };
    expect(body.items).toHaveLength(1);
    expect(body.items[0]?.studentId).toBe(STUDENT_ROW);
    expect(body.items[0]?.status).toBe("submitted");
  });

  test("online assessment questions submit as one immutable attempt", async () => {
    const create = await request("/v1/assessments", {
      method: "POST",
      subject: TEACHER_A,
      key: "api041-it-online-assessment-1",
      body: {
        classroomId: CLASS_A,
        title: "Online cells quiz",
        category: "quiz",
        maximumScore: 4,
        scheduledAt: null,
        delivery: "online",
        questions: [
          {
            position: 1,
            prompt: "Cell wall?",
            preferredAnswer: "Plants",
            maximumScore: 2,
          },
          {
            position: 2,
            prompt: "Nucleus?",
            preferredAnswer: "DNA",
            maximumScore: 2,
          },
        ],
      },
    });
    expect(create.status).toBe(201);
    const onlineId = (await create.json() as { id: string }).id;

    const publish = await request(`/v1/assessments/${onlineId}/publish`, {
      method: "POST",
      subject: TEACHER_A,
      key: "api041-it-online-publish-1",
      body: { expectedVersion: 1 },
    });
    expect(publish.status).toBe(200);

    const questions = await request(`/v1/assessments/${onlineId}/questions`, {
      subject: STUDENT_USER,
    });
    const items = (await questions.json() as { items: { id: string }[] }).items;
    expect(items).toHaveLength(2);

    const submit = await request(`/v1/assessments/${onlineId}/submit`, {
      method: "POST",
      subject: STUDENT_USER,
      key: "api041-it-online-submit-1",
      body: {
        answers: items.map((question, index) => ({
          questionId: question.id,
          answerText: index === 0 ? "Plant cells" : "It contains DNA",
        })),
      },
    });
    expect(submit.status).toBe(201);

    const attempts = await request(`/v1/assessments/${onlineId}/attempts`, {
      subject: TEACHER_A,
    });
    expect(((await attempts.json()) as { items: unknown[] }).items)
      .toHaveLength(1);
    expect(
      await scalar(
        sql`select count(*)::int as result from public.assessment_answers aa join public.assessment_attempts at on at.id=aa.attempt_id where at.assessment_id=${onlineId}::uuid`,
      ),
    ).toBe(2);
  });

  test("paper grading review and publish replace the removed Edge Functions", async () => {
    const create = await request("/v1/assessments", {
      method: "POST",
      subject: TEACHER_A,
      key: "api041-it-assessment-create-1",
      body: {
        classroomId: CLASS_A,
        title: "Paper quiz",
        category: "quiz",
        maximumScore: 10,
        scheduledAt: null,
        delivery: "paper",
        questions: [
          {
            position: 1,
            prompt: "Name the parts",
            preferredAnswer: null,
            maximumScore: 4,
          },
          {
            position: 2,
            prompt: "Explain the model",
            preferredAnswer: null,
            maximumScore: 6,
          },
        ],
      },
    });
    expect(create.status).toBe(201);
    assessmentId = (await create.json() as { id: string }).id;

    const publish = await request(`/v1/assessments/${assessmentId}/publish`, {
      method: "POST",
      subject: TEACHER_A,
      key: "aaaaaaaaaaaaaaaaaaaaaa03",
      body: { expectedVersion: 1 },
    });
    expect(publish.status).toBe(200);
    expect(((await publish.json()) as { state: string }).state).toBe(
      "published",
    );

    const learnerQuestions = await request(
      `/v1/assessments/${assessmentId}/questions`,
      { subject: STUDENT_USER },
    );
    expect(learnerQuestions.status).toBe(200);
    const learnerBody = await learnerQuestions.json() as { items: unknown[] };
    expect(learnerBody.items).toHaveLength(2);
    expect(JSON.stringify(learnerBody)).not.toContain("preferredAnswer");

    const authoringQuestions = await request(
      `/v1/assessments/${assessmentId}/authoring-questions`,
      { subject: TEACHER_A },
    );
    expect(authoringQuestions.status).toBe(200);
    expect(
      (await authoringQuestions.json() as {
        items: { preferredAnswer: string | null }[];
      })
        .items,
    ).toHaveLength(2);
    expect(
      await scalar(
        sql`select count(*)::int as result from public.grade_results where assessment_id = ${assessmentId}::uuid and student_id = ${STUDENT_ROW}::uuid and state = 'draft'`,
      ),
    ).toBe(1);

    const grades = await request(`/v1/grade-results?classroomId=${CLASS_A}`, {
      subject: TEACHER_A,
    });
    const gradePage = await grades.json() as {
      items: { id: string; assessmentId: string; state: string }[];
    };
    gradeResultId = gradePage.items
      .find((item) =>
        item.state === "draft" && item.assessmentId === assessmentId
      )?.id ?? "";
    expect(gradeResultId).toBeTruthy();

    const review = await request(`/v1/grade-results/${gradeResultId}/review`, {
      method: "POST",
      subject: TEACHER_A,
      key: "api041-it-grade-review-0001",
      body: { expectedVersion: 1, score: 8, feedback: "Strong diagram." },
    });
    expect(review.status).toBe(200);
    const reviewed = await review.json() as {
      state: string;
      score: number;
      version: number;
    };
    expect(reviewed.state).toBe("reviewed");
    expect(reviewed.score).toBe(8);

    // An unpublished grade is invisible to the student and guardian.
    const before = await request(`/v1/grade-results?studentId=${STUDENT_ROW}`, {
      subject: STUDENT_USER,
    });
    expect(((await before.json()) as { items: unknown[] }).items).toHaveLength(
      0,
    );

    const publishGrade = await request(
      `/v1/grade-results/${gradeResultId}/publish`,
      {
        method: "POST",
        subject: TEACHER_A,
        key: "aaaaaaaaaaaaaaaaaaaaaa04",
        requestId: "api041-it-publish-grade",
        body: { expectedVersion: 2 },
      },
    );
    expect(publishGrade.status).toBe(200);
    expect(((await publishGrade.json()) as { state: string }).state).toBe(
      "published",
    );

    expect(
      await scalar(
        sql`select count(*)::int as result from public.grade_result_events where grade_result_id = ${gradeResultId}::uuid and event_type in ('reviewed','published')`,
      ),
    ).toBe(2);
    expect(
      await scalar(
        sql`select count(*)::int as result from public.notification_outbox where source_event_id = ${gradeResultId}::uuid::text and template_key = 'academic.grade_published'`,
      ),
    ).toBe(1);
    expect(
      await scalar(
        sql`select count(*)::int as result from public.notifications where entity_id = ${gradeResultId}::uuid`,
      ),
    ).toBe(0);

    const after = await request(`/v1/grade-results?studentId=${STUDENT_ROW}`, {
      subject: STUDENT_USER,
    });
    const studentGrades = (await after.json()) as {
      items: { id: string; score: number }[];
    };
    expect(studentGrades.items).toHaveLength(1);
    expect(studentGrades.items[0]?.id).toBe(gradeResultId);
    expect(studentGrades.items[0]?.score).toBe(8);

    const guardianView = await request(
      `/v1/grade-results?studentId=${STUDENT_ROW}`,
      {
        subject: GUARDIAN,
      },
    );
    expect(((await guardianView.json()) as { items: unknown[] }).items)
      .toHaveLength(1);
  });

  test("published grades require a reason to correct and may be withdrawn", async () => {
    const missingReason = await request(
      `/v1/grade-results/${gradeResultId}/correct`,
      {
        method: "POST",
        subject: TEACHER_A,
        key: "aaaaaaaaaaaaaaaaaaaaaa05",
        body: { expectedVersion: 3, score: 9, feedback: "Rechecked." },
      },
    );
    expect(missingReason.status).toBe(400);

    const correct = await request(
      `/v1/grade-results/${gradeResultId}/correct`,
      {
        method: "POST",
        subject: TEACHER_A,
        key: "aaaaaaaaaaaaaaaaaaaaaa06",
        body: {
          expectedVersion: 3,
          score: 9,
          feedback: "Rechecked against the paper.",
          reason: "Question two was totaled incorrectly.",
        },
      },
    );
    expect(correct.status).toBe(200);
    const corrected = await correct.json() as {
      state: string;
      score: number;
      version: number;
    };
    expect(corrected.state).toBe("published");
    expect(corrected.score).toBe(9);
    expect(
      await scalar(
        sql`select reason as result from public.grade_result_events where grade_result_id=${gradeResultId}::uuid and event_type='corrected'`,
      ),
    ).toBe("Question two was totaled incorrectly.");

    const withdraw = await request(
      `/v1/grade-results/${gradeResultId}/withdraw`,
      {
        method: "POST",
        subject: TEACHER_A,
        key: "aaaaaaaaaaaaaaaaaaaaaa07",
        body: { expectedVersion: corrected.version },
      },
    );
    expect(withdraw.status).toBe(200);
    expect(((await withdraw.json()) as { state: string }).state).toBe(
      "withdrawn",
    );

    const studentTimeline = await request(
      `/v1/grade-results?studentId=${STUDENT_ROW}`,
      { subject: STUDENT_USER },
    );
    expect(((await studentTimeline.json()) as { items: unknown[] }).items)
      .toHaveLength(0);
  });

  test("attendance records transactionally against the class schedule", async () => {
    const record = await request("/v1/attendance/record", {
      method: "POST",
      subject: TEACHER_A,
      key: "api041-it-attendance-000001",
      requestId: "api041-it-attendance",
      body: {
        classroomId: CLASS_A,
        startsAt: lessonStartsAt,
        endsAt: lessonEndsAt,
        expectedVersion: 0,
        entries: [
          { studentId: STUDENT_ROW, state: "present", reason: null },
        ],
      },
    });
    expect(record.status).toBe(200);
    const body = await record.json() as {
      sessionId: string;
      version: number;
      recorded: number;
    };
    sessionId = body.sessionId;
    expect(body.version).toBe(1);
    expect(body.recorded).toBe(1);
    expect(
      await scalar(
        sql`select count(*)::int as result from public.audit_events where request_id = 'api041-it-attendance' and action = 'attendance_recorded'`,
      ),
    ).toBe(1);

    const list = await request(`/v1/attendance?classroomId=${CLASS_A}`, {
      subject: TEACHER_A,
    });
    const items =
      ((await list.json()) as { items: { sessionId: string; state: string }[] })
        .items;
    expect(
      items.some((item) =>
        item.sessionId === sessionId && item.state === "present"
      ),
    ).toBe(
      true,
    );
  });

  test("the register loads through the real API", async () => {
    // It answered 500 for every class: each row carried a stray id field the
    // response schema refuses. Only a request through the real route shows it.
    const date = lessonStartsAt.slice(0, 10);
    const res = await request(
      `/v1/classrooms/${CLASS_A}/attendance-roster?date=${date}&startsAt=${
        encodeURIComponent(lessonStartsAt)
      }`,
      { subject: TEACHER_A },
    );
    expect(res.status).toBe(200);
    const body = await res.json() as {
      items: { student: { id: string }; record: { state: string } | null }[];
      session: { id: string; version: number } | null;
    };
    const row = body.items.find((i) => i.student.id === STUDENT_ROW);
    expect(row?.record?.state).toBe("present");
    expect(body.session?.version).toBe(1);
  });

  test("a register already taken can be changed", async () => {
    const change = await request("/v1/attendance/record", {
      method: "POST",
      subject: TEACHER_A,
      key: "api041-it-attendance-000002",
      body: {
        classroomId: CLASS_A,
        startsAt: lessonStartsAt,
        endsAt: lessonEndsAt,
        expectedVersion: 1,
        entries: [
          { studentId: STUDENT_ROW, state: "late", reason: "bus" },
        ],
      },
    });
    expect(change.status).toBe(200);
    const date = lessonStartsAt.slice(0, 10);
    const res = await request(
      `/v1/classrooms/${CLASS_A}/attendance-roster?date=${date}&startsAt=${
        encodeURIComponent(lessonStartsAt)
      }`,
      { subject: TEACHER_A },
    );
    const body = await res.json() as {
      items: { student: { id: string }; record: { state: string } | null }[];
    };
    expect(
      body.items.find((i) => i.student.id === STUDENT_ROW)?.record?.state,
    ).toBe("late");
  });

  test("wellbeing events record without outbox side effects unless shared", async () => {
    const create = await request("/v1/wellbeing", {
      method: "POST",
      subject: TEACHER_A,
      key: "api041-it-wellbeing-000001",
      body: {
        studentId: STUDENT_ROW,
        classroomId: CLASS_A,
        kind: "note",
        title: "Settling in well",
        context: "Participates confidently in group work.",
        followUp: null,
        visibility: "class_staff",
        severity: "low",
      },
    });
    expect(create.status).toBe(201);
    const created = await create.json() as { id: string; visibility: string };
    expect(created.visibility).toBe("class_staff");
    expect(
      await scalar(
        sql`select count(*)::int as result from public.notification_outbox where source_event_id = ${created.id}::uuid::text`,
      ),
    ).toBe(0);

    const list = await request(`/v1/wellbeing?studentId=${STUDENT_ROW}`, {
      subject: TEACHER_A,
    });
    const items = ((await list.json()) as { items: { title: string }[] }).items;
    expect(items.some((item) => item.title === "Settling in well")).toBe(true);
  });

  test("assistants read but cannot execute academic commands", async () => {
    const read = await request(
      `/v1/assignments?schoolId=${SCHOOL_A}&classroomId=${CLASS_A}`,
      { subject: ASSISTANT },
    );
    expect(read.status).toBe(200);

    const write = await request("/v1/assignments", {
      method: "POST",
      subject: ASSISTANT,
      key: "api041-it-assistant-denied",
      body: {
        classroomId: CLASS_A,
        title: "Assistant must not create",
        instructions: null,
        dueAt: "2026-10-05T10:00:00.000Z",
        closesAt: null,
      },
    });
    expect(write.status).toBe(404);
    expect(
      await scalar(
        sql`select count(*)::int as result from public.assignments where title='Assistant must not create'`,
      ),
    ).toBe(0);
  });

  test("membership revocation denies the next command without stale authority", async () => {
    await sql`update public.memberships set active=false,status='revoked' where school_id=${SCHOOL_A}::uuid and user_id=${TEACHER_A}::uuid and role='teacher'`;
    const denied = await request(`/v1/assignments/${assignmentId}/withdraw`, {
      method: "POST",
      subject: TEACHER_A,
      key: "aaaaaaaaaaaaaaaaaaaaaa08",
      body: { expectedVersion: 2 },
    });
    expect(denied.status).toBe(404);
    expect(
      await scalar(
        sql`select state::text as result from public.assignments where id=${assignmentId}::uuid`,
      ),
    ).toBe("published");
    await sql`update public.memberships set active=true,status='active' where school_id=${SCHOOL_A}::uuid and user_id=${TEACHER_A}::uuid and role='teacher'`;
  });

  test("cross-tenant substitution is concealed and never audited", async () => {
    const read = await request(`/v1/classrooms/${CLASS_A}`, {
      subject: TEACHER_B,
    });
    expect(read.status).toBe(404);

    const command = await request(`/v1/assignments/${assignmentId}/withdraw`, {
      method: "POST",
      subject: TEACHER_B,
      key: "api041-it-cross-tenant-001",
      body: { expectedVersion: 2 },
    });
    expect(command.status).toBe(404);
    expect(
      await scalar(
        sql`select count(*)::int as result from public.audit_events where actor_id = ${TEACHER_B}::uuid`,
      ),
    ).toBe(0);
    expect(
      await scalar(
        sql`select state::text as result from public.assignments where id = ${assignmentId}::uuid`,
      ),
    ).toBe("published");
  });

  // -------------------------------------------------------------------------
  // Submission attachments.
  //
  // The binding is what grants other people access to an uploaded object, so
  // these tests are about what private.file_attach_bind refuses, not only what
  // it accepts.
  // -------------------------------------------------------------------------
  /** A completed, clean upload owned by `owner`, as the pipeline would leave it. */
  async function seedFile(
    id: string,
    owner: string,
    purpose: string,
    school = SCHOOL_A,
  ): Promise<string> {
    const membership = await scalar(
      sql`select id as result from public.memberships
          where school_id = ${school}::uuid and user_id = ${owner}::uuid limit 1`,
    ) as string;
    await sql`
      insert into public.file_objects(
        id, school_id, bucket, object_key, uploader_id, owner_id,
        owner_membership_id, purpose, display_name, size_bytes, sha256,
        declared_media_type, scan_state, policy_version, scanned_at,
        scan_policy_version)
      values (
        ${id}::uuid, ${school}::uuid, 'private-school-files',
        ${"quarantine/v1/" + id + "/" + id.replace(/-/g, "") + "aaaaaa"},
        ${owner}::uuid, ${owner}::uuid, ${membership}::uuid,
        ${purpose}::public.file_purpose, 'diagram.pdf', 2048,
        ${"a".repeat(64)}, 'application/pdf', 'clean', 'file-attach-v1',
        now(), 'file051-test')`;
    return id;
  }

  const OWN_FILE = "5f410000-0000-4000-8000-0000000000f1";
  const SECOND_FILE = "5f410000-0000-4000-8000-0000000000f2";
  const TEACHER_FILE = "5f410000-0000-4000-8000-0000000000f3";
  const WRONG_PURPOSE_FILE = "5f410000-0000-4000-8000-0000000000f4";

  test("a student hands work in with their own attachment", async () => {
    await seedFile(OWN_FILE, STUDENT_USER, "assignment_submission");
    const submit = await request(`/v1/assignments/${assignmentId}/submit`, {
      method: "POST",
      subject: STUDENT_USER,
      key: "api041-it-attach-1",
      body: {
        answerText: "Diagram attached.",
        attachmentFileIds: [OWN_FILE],
      },
    });
    expect(submit.status).toBe(201);
    const body = await submit.json() as {
      attachments: { id: string; scanState: string }[];
    };
    expect(body.attachments.map((a) => a.id)).toEqual([OWN_FILE]);
    // The binding is the record that grants access; it must exist.
    expect(
      await scalar(
        sql`select count(*)::int as result from public.file_bindings
            where file_object_id = ${OWN_FILE}::uuid
              and submission_attempt_id is not null`,
      ),
    ).toBe(1);
  });

  test("the teacher sees the attachment on the roster read", async () => {
    const page = await request(
      `/v1/assignments/${assignmentId}/submissions?pageSize=10`,
      { subject: TEACHER_A },
    );
    expect(page.status).toBe(200);
    const body = await page.json() as {
      items: { attachments: { id: string }[] }[];
    };
    expect(body.items[0]?.attachments.map((a) => a.id)).toEqual([OWN_FILE]);
  });

  test("the marking teacher may download it; an unrelated teacher may not", async () => {
    // Asked of the database directly: the rule is a SECURITY DEFINER function
    // reading auth.uid(), so it has to be evaluated as each actor. Both
    // set_config and the call must share one connection, hence the
    // single-statement form.
    const allowedFor = async (subject: string) =>
      await scalar(
        sql`select (
              select (private.file051_authorize_download(${OWN_FILE}::uuid))->>'allowed'
              from (select set_config('request.jwt.claim.sub', ${subject}, true)) as _
            ) as result`,
      );
    expect(await allowedFor(TEACHER_A)).toBe("true");
    expect(await allowedFor(TEACHER_B)).toBe("false");
    // The student who handed it in keeps access through own_submission.
    expect(await allowedFor(STUDENT_USER)).toBe("true");
  });

  test("a student cannot attach a file they do not own", async () => {
    await seedFile(TEACHER_FILE, TEACHER_A, "assignment_submission");
    const submit = await request(`/v1/assignments/${assignmentId}/submit`, {
      method: "POST",
      subject: STUDENT_USER,
      key: "api041-it-attach-2",
      body: {
        answerText: "Not mine.",
        attachmentFileIds: [TEACHER_FILE],
      },
    });
    expect(submit.status).toBe(403);
    expect(
      await scalar(
        sql`select count(*)::int as result from public.file_bindings
            where file_object_id = ${TEACHER_FILE}::uuid
              and submission_attempt_id is not null`,
      ),
    ).toBe(0);
  });

  test("an already attached file cannot be attached again", async () => {
    const submit = await request(`/v1/assignments/${assignmentId}/submit`, {
      method: "POST",
      subject: STUDENT_USER,
      key: "api041-it-attach-3",
      body: {
        answerText: "Reusing the same upload.",
        attachmentFileIds: [OWN_FILE],
      },
    });
    expect(submit.status).toBe(400);
  });

  test("a file of the wrong purpose is refused", async () => {
    await seedFile(WRONG_PURPOSE_FILE, STUDENT_USER, "message_attachment");
    const submit = await request(`/v1/assignments/${assignmentId}/submit`, {
      method: "POST",
      subject: STUDENT_USER,
      key: "api041-it-attach-4",
      body: {
        answerText: "Wrong purpose.",
        attachmentFileIds: [WRONG_PURPOSE_FILE],
      },
    });
    expect(submit.status).toBe(400);
  });

  test("a duplicated id in one request is refused", async () => {
    await seedFile(SECOND_FILE, STUDENT_USER, "assignment_submission");
    const submit = await request(`/v1/assignments/${assignmentId}/submit`, {
      method: "POST",
      subject: STUDENT_USER,
      key: "api041-it-attach-5",
      body: {
        answerText: "Same file twice.",
        attachmentFileIds: [SECOND_FILE, SECOND_FILE],
      },
    });
    expect(submit.status).toBe(400);
  });

  // -------------------------------------------------------------------------
  // A guardian hands work in for a child with no device of their own.
  //
  // students.user_id is nullable and `provisional` defaults true, so this is
  // the ordinary shape for a young child, not an edge case. Nothing here
  // impersonates the child: the guardian is the actor and is recorded as such.
  // -------------------------------------------------------------------------
  test("a linked guardian hands work in for their child", async () => {
    const submit = await request(`/v1/assignments/${assignmentId}/submit`, {
      method: "POST",
      subject: GUARDIAN,
      key: "api041-it-guardian-1",
      body: {
        answerText: "Photographed her working and typed it up.",
        studentId: STUDENT_ROW,
      },
    });
    expect(submit.status).toBe(201);
    const body = await submit.json() as {
      studentId: string;
      submittedByGuardianId: string | null;
    };
    // Filed against the child, credited to the guardian who acted.
    expect(body.studentId).toBe(STUDENT_ROW);
    expect(body.submittedByGuardianId).toBe(GUARDIAN);
  });

  test("the teacher sees that a guardian handed it in", async () => {
    const page = await request(
      `/v1/assignments/${assignmentId}/submissions?pageSize=10`,
      { subject: TEACHER_A },
    );
    expect(page.status).toBe(200);
    const body = await page.json() as {
      items: { submittedByGuardianId: string | null }[];
    };
    expect(body.items[0]?.submittedByGuardianId).toBe(GUARDIAN);
  });

  test("a guardian audit row is distinct from a student hand-in", async () => {
    expect(
      await scalar(
        sql`select count(*)::int as result from public.audit_events
            where action = 'assignment_submitted_by_guardian'
              and actor_id = ${GUARDIAN}::uuid`,
      ),
    ).toBe(1);
  });

  test("an unrelated adult cannot hand work in for a child", async () => {
    // TEACHER_B is in the school but holds no guardian link to this child.
    // 404 rather than 403 is deliberate: assignment.submit conceals a denied
    // resource, so a refusal must not confirm the assignment exists.
    const submit = await request(`/v1/assignments/${assignmentId}/submit`, {
      method: "POST",
      subject: TEACHER_B,
      key: "api041-it-guardian-2",
      body: { answerText: "Not my child.", studentId: STUDENT_ROW },
    });
    expect(submit.status).toBe(404);
  });

  test("a revoked link ends the guardian's ability to hand work in", async () => {
    await sql`
      update public.guardian_links set status = 'revoked'
      where student_id = ${STUDENT_ROW}::uuid
        and guardian_id = ${GUARDIAN}::uuid`;
    const submit = await request(`/v1/assignments/${assignmentId}/submit`, {
      method: "POST",
      subject: GUARDIAN,
      key: "api041-it-guardian-3",
      body: { answerText: "After revocation.", studentId: STUDENT_ROW },
    });
    expect(submit.status).toBe(404);
    await sql`
      update public.guardian_links set status = 'verified'
      where student_id = ${STUDENT_ROW}::uuid
        and guardian_id = ${GUARDIAN}::uuid`;
  });

  test("an expired link ends it too", async () => {
    // verified_at moves with it: the schema requires an expiry after the
    // verification, so a link cannot be backdated by expiry alone.
    await sql`
      update public.guardian_links
      set verified_at = now() - interval '30 days',
          expires_at = now() - interval '1 day'
      where student_id = ${STUDENT_ROW}::uuid
        and guardian_id = ${GUARDIAN}::uuid`;
    const submit = await request(`/v1/assignments/${assignmentId}/submit`, {
      method: "POST",
      subject: GUARDIAN,
      key: "api041-it-guardian-4",
      body: { answerText: "After expiry.", studentId: STUDENT_ROW },
    });
    expect(submit.status).toBe(404);
    await sql`
      update public.guardian_links set expires_at = null, verified_at = now()
      where student_id = ${STUDENT_ROW}::uuid
        and guardian_id = ${GUARDIAN}::uuid`;
  });

  test("a guardian may upload for their child", async () => {
    // The blocker before this change: an upload intent required the actor to
    // hold a memberships row, and a guardian may hold none. Run in one
    // transaction so set_config and the call share a connection.
    const allowed = await sql.begin(async (tx) => {
      await tx`select set_config('request.jwt.claim.sub', ${GUARDIAN}, true)`;
      const rows = await tx`
        select (private.file050_authorize_target(jsonb_build_object(
          'schoolId', ${SCHOOL_A}::text,
          'purpose', 'assignment_submission',
          'assignmentId', ${assignmentId}::text,
          'studentId', ${STUDENT_ROW}::text)))->>'allowed' as result`;
      return (rows as unknown as Record<string, unknown>[])[0]?.["result"];
    });
    expect(allowed).toBe("true");
  });

  // -------------------------------------------------------------------------
  // Material a teacher attaches to the work they set.
  //
  // Uploaded while the assignment is still being written, so the upload is
  // scoped to the class; bound when the work is created; opened by whoever
  // may see the work.
  // -------------------------------------------------------------------------
  const OTHER_CLASS = "5f410000-0000-4000-8000-0000000000d9";

  /** A clean material upload started for [classroom], as the pipeline leaves it. */
  async function seedMaterial(id: string, classroom: string): Promise<string> {
    await seedFile(id, TEACHER_A, "assignment_material");
    const session = crypto.randomUUID();
    await sql`
      insert into public.upload_sessions(
        id, school_id, uploader_id, owner_id, purpose, expected_size_bytes,
        allowed_media_types, nonce_hash, expires_at, classroom_id)
      values (
        ${session}::uuid, ${SCHOOL_A}::uuid, ${TEACHER_A}::uuid,
        ${TEACHER_A}::uuid, 'assignment_material', 2048,
        array['application/pdf'], ${crypto.randomUUID()},
        now() + interval '1 hour', ${classroom}::uuid)`;
    await sql`
      insert into public.file_bindings(school_id, file_object_id, upload_session_id)
      values (${SCHOOL_A}::uuid, ${id}::uuid, ${session}::uuid)`;
    return id;
  }

  async function mayStartMaterial(subject: string, classroom: string) {
    return await sql.begin(async (tx) => {
      await tx`select set_config('request.jwt.claim.sub', ${subject}, true)`;
      const rows = await tx`
        select (private.file050_authorize_target(jsonb_build_object(
          'schoolId', ${SCHOOL_A}::text,
          'purpose', 'assignment_material',
          'classroomId', ${classroom}::text)))->>'allowed' as result`;
      return (rows as unknown as Record<string, unknown>[])[0]?.["result"];
    });
  }

  async function mayOpen(subject: string, file: string) {
    return await scalar(
      sql`select (
            select (private.file051_authorize_download(${file}::uuid))->>'allowed'
            from (select set_config('request.jwt.claim.sub', ${subject}, true)) as _
          ) as result`,
    );
  }

  const MATERIAL = "5f410000-0000-4000-8000-0000000000f7";
  const FOREIGN_MATERIAL = "5f410000-0000-4000-8000-0000000000f8";
  const EXAM_MATERIAL = "5f410000-0000-4000-8000-0000000000f9";
  let materialAssignment = "";

  test("only the class's teacher may start a material upload for it", async () => {
    expect(await mayStartMaterial(TEACHER_A, CLASS_A)).toBe("true");
    expect(await mayStartMaterial(TEACHER_B, CLASS_A)).toBe("false");
    expect(await mayStartMaterial(STUDENT_USER, CLASS_A)).toBe("false");
  });

  test("a teacher sets work with a worksheet attached", async () => {
    await seedMaterial(MATERIAL, CLASS_A);
    const body = {
      classroomId: CLASS_A,
      title: "Worksheet homework",
      instructions: "Use the attached sheet.",
      dueAt: FIRST_DUE_AT,
      closesAt: FIRST_CLOSES_AT,
      attachmentFileIds: [MATERIAL],
    };
    const create = await request("/v1/assignments", {
      method: "POST",
      subject: TEACHER_A,
      key: "api041-it-material-1",
      body,
    });
    expect(create.status).toBe(201);
    const created = await create.json() as {
      id: string;
      attachments: { id: string }[];
    };
    materialAssignment = created.id;
    expect(created.attachments.map((a) => a.id)).toEqual([MATERIAL]);

    // A replay describes the same work, files included.
    const replay = await request("/v1/assignments", {
      method: "POST",
      subject: TEACHER_A,
      key: "api041-it-material-1",
      body,
    });
    expect(replay.status).toBe(201);
    expect(
      (await replay.json() as { attachments: { id: string }[] }).attachments
        .map((a) => a.id),
    ).toEqual([MATERIAL]);
  });

  test("students open material only once the work is published", async () => {
    expect(await mayOpen(TEACHER_A, MATERIAL)).toBe("true");
    expect(await mayOpen(STUDENT_USER, MATERIAL)).toBe("false");

    const publish = await request(
      `/v1/assignments/${materialAssignment}/publish`,
      {
        method: "POST",
        subject: TEACHER_A,
        key: "api041-it-material-publish", // gitleaks:allow (synthetic idempotency key)
        body: { expectedVersion: 1 },
      },
    );
    expect(publish.status).toBe(200);

    expect(await mayOpen(STUDENT_USER, MATERIAL)).toBe("true");
    // A verified guardian sees what their child sees.
    expect(await mayOpen(GUARDIAN, MATERIAL)).toBe("true");
    // Another school's teacher sees nothing.
    expect(await mayOpen(TEACHER_B, MATERIAL)).toBe("false");
  });

  test("the student's read of the work lists its material", async () => {
    const read = await request(`/v1/assignments/${materialAssignment}`, {
      subject: STUDENT_USER,
    });
    expect(read.status).toBe(200);
    const body = await read.json() as { attachments: { id: string }[] };
    expect(body.attachments.map((a) => a.id)).toEqual([MATERIAL]);
  });

  test("material uploaded for another class is refused, and the work with it", async () => {
    await sql`
      insert into public.classrooms (id, school_id, term_id, name, grade, section, teacher_id, status, version)
      values (${OTHER_CLASS}::uuid, ${SCHOOL_A}::uuid, ${TERM_A}::uuid,
              'Other class', '8', 'B', ${TEACHER_A}::uuid, 'active', 1)
      on conflict (id) do nothing`;
    await seedMaterial(FOREIGN_MATERIAL, OTHER_CLASS);
    const create = await request("/v1/assignments", {
      method: "POST",
      subject: TEACHER_A,
      key: "api041-it-material-2", // gitleaks:allow (synthetic idempotency key)
      body: {
        classroomId: CLASS_A,
        title: "Smuggled sheet",
        instructions: null,
        dueAt: FIRST_DUE_AT,
        closesAt: FIRST_CLOSES_AT,
        attachmentFileIds: [FOREIGN_MATERIAL],
      },
    });
    expect(create.status).not.toBe(201);
    // Rolled back together: no work was created without its file.
    expect(
      await scalar(
        sql`select count(*)::int as result from public.assignments
            where title = 'Smuggled sheet'`,
      ),
    ).toBe(0);
    expect(
      await scalar(
        sql`select count(*)::int as result from public.file_bindings
            where file_object_id = ${FOREIGN_MATERIAL}::uuid
              and assignment_id is not null`,
      ),
    ).toBe(0);
  });

  test("graded work carries material too", async () => {
    await seedMaterial(EXAM_MATERIAL, CLASS_A);
    const create = await request("/v1/assessments", {
      method: "POST",
      subject: TEACHER_A,
      key: "api041-it-material-3", // gitleaks:allow (synthetic idempotency key)
      body: {
        classroomId: CLASS_A,
        title: "Graded worksheet",
        category: "assignment",
        maximumScore: 10,
        scheduledAt: null,
        delivery: "paper",
        questions: [],
        attachmentFileIds: [EXAM_MATERIAL],
      },
    });
    expect(create.status).toBe(201);
    const body = await create.json() as { attachments: { id: string }[] };
    expect(body.attachments.map((a) => a.id)).toEqual([EXAM_MATERIAL]);
  });

  // -------------------------------------------------------------------------
  // Submission history. By now the student has handed the first assignment
  // in more than once - on their own, with an attachment, and through their
  // guardian - so every attempt should be readable, newest first.
  // -------------------------------------------------------------------------
  interface HistoryItem {
    id: string;
    current: boolean;
    submittedAt: string;
    submittedByGuardianId: string | null;
    attachments: { id: string }[];
  }

  async function history(subject: string, studentId?: string) {
    const query = studentId ? `?studentId=${studentId}` : "";
    const res = await request(
      `/v1/assignments/${assignmentId}/history${query}`,
      { subject },
    );
    return {
      status: res.status,
      items: res.status === 200
        ? (await res.json() as { items: HistoryItem[] }).items
        : [],
    };
  }

  test("a student reads every attempt at their own work, newest first", async () => {
    const own = await history(STUDENT_USER);
    expect(own.status).toBe(200);
    const attempts = await scalar(
      sql`select count(*)::int as result from public.submission_attempts sa
          join public.submissions s on s.id = sa.submission_id
          where s.assignment_id = ${assignmentId}::uuid
            and s.student_id = ${STUDENT_ROW}::uuid`,
    );
    expect(own.items.length).toBe(attempts as number);
    expect(own.items.length).toBeGreaterThan(1);
    // Only the newest is the one being marked.
    expect(own.items.map((i) => i.current)).toEqual(
      own.items.map((_, index) => index === 0),
    );
    const times = own.items.map((i) => Date.parse(i.submittedAt));
    expect([...times].sort((a, b) => b - a)).toEqual(times);
    // Earlier attempts keep what they were handed in with.
    expect(own.items.some((i) => i.attachments.some((a) => a.id === OWN_FILE)))
      .toBe(true);
    // And say who handed each in.
    expect(own.items.some((i) => i.submittedByGuardianId === GUARDIAN))
      .toBe(true);
  });

  test("a guardian and the class teacher read the same history", async () => {
    const own = await history(STUDENT_USER);
    const guardian = await history(GUARDIAN, STUDENT_ROW);
    const teacher = await history(TEACHER_A, STUDENT_ROW);
    expect(guardian.status).toBe(200);
    expect(teacher.status).toBe(200);
    expect(guardian.items.map((i) => i.id)).toEqual(own.items.map((i) => i.id));
    expect(teacher.items.map((i) => i.id)).toEqual(own.items.map((i) => i.id));
  });

  test("history is concealed from anyone else", async () => {
    // Another school's teacher.
    expect((await history(TEACHER_B, STUDENT_ROW)).status).toBe(404);
    // A teacher must say which student; they have no work of their own.
    expect((await history(TEACHER_A)).status).toBe(404);
    // A student naming someone who is not them.
    expect((await history(STUDENT_USER, crypto.randomUUID())).status).toBe(404);
    // A guardian naming a child they are not linked to.
    expect((await history(GUARDIAN, crypto.randomUUID())).status).toBe(404);
  });

  test("a guardian may open the files on their child's work", async () => {
    expect(await mayOpen(GUARDIAN, OWN_FILE)).toBe("true");
    expect(await mayOpen(TEACHER_B, OWN_FILE)).toBe("false");
  });

  // -------------------------------------------------------------------------
  // A parent who linked by the child's ID holds no membership. Every feed
  // their Learning tab shows, and handing work in, must work on the link.
  // -------------------------------------------------------------------------
  test("the linked parent really has no membership", async () => {
    expect(
      await scalar(
        sql`select count(*)::int as result from public.memberships
            where user_id = ${LINKED_PARENT}::uuid`,
      ),
    ).toBe(0);
  });

  test("a parent with no membership reads the child's published work", async () => {
    const res = await request(
      `/v1/assignments?schoolId=${SCHOOL_A}&studentId=${STUDENT_ROW}`,
      { subject: LINKED_PARENT },
    );
    expect(res.status).toBe(200);
    const items = (await res.json() as {
      items: { id: string; state: string; submissionId: string | null }[];
    }).items;
    expect(items.length).toBeGreaterThan(0);
    expect(items.every((i) => i.state === "published")).toBe(true);
    // The child's own hand-in, not the parent's (who has none).
    expect(items.find((i) => i.id === assignmentId)?.submissionId)
      .not.toBeNull();
  });

  test("a parent with no membership reads every Learning feed", async () => {
    for (
      const path of [
        "/v1/assessments",
        "/v1/grade-results",
        "/v1/attendance",
        "/v1/resources",
      ]
    ) {
      const res = await request(
        `${path}?schoolId=${SCHOOL_A}&studentId=${STUDENT_ROW}`,
        { subject: LINKED_PARENT },
      );
      expect({ path, status: res.status }).toEqual({ path, status: 200 });
    }
    const grades = (await (await request(
      `/v1/grade-results?schoolId=${SCHOOL_A}&studentId=${STUDENT_ROW}`,
      { subject: LINKED_PARENT },
    )).json() as { items: { studentId: string; state: string }[] }).items;
    // Only the child's, and only what the teacher released.
    expect(grades.every((g) => g.studentId === STUDENT_ROW)).toBe(true);
    expect(grades.every((g) => g.state === "published")).toBe(true);
  });

  test("a parent cannot read a child they are not linked to", async () => {
    const res = await request(
      `/v1/grade-results?schoolId=${SCHOOL_A}&studentId=${crypto.randomUUID()}`,
      { subject: LINKED_PARENT },
    );
    expect(res.status).toBe(404);
    // Nor a whole school's feed without naming their child.
    const school = await request(`/v1/assignments?schoolId=${SCHOOL_A}`, {
      subject: LINKED_PARENT,
    });
    expect(school.status).toBe(404);
  });

  test("a parent with no membership hands work in for the child", async () => {
    const submit = await request(`/v1/assignments/${assignmentId}/submit`, {
      method: "POST",
      subject: LINKED_PARENT,
      key: "api041-it-linked-parent-1",
      body: {
        answerText: "Filed from a parent's phone.",
        studentId: STUDENT_ROW,
      },
    });
    expect(submit.status).toBe(201);
    const body = await submit.json() as { submittedByGuardianId: string };
    expect(body.submittedByGuardianId).toBe(LINKED_PARENT);
  });

  // -------------------------------------------------------------------------
  // Graded assignments: the work is an assignment the class hands in, and
  // its mark is an assessment linked to it.
  // -------------------------------------------------------------------------
  let gradedAssignment = "";

  test("graded work is an assignment with a linked mark", async () => {
    const create = await request("/v1/assignments", {
      method: "POST",
      subject: TEACHER_A,
      key: "api041-it-graded-1",
      body: {
        classroomId: CLASS_A,
        title: "Graded lab report",
        instructions: null,
        dueAt: FIRST_DUE_AT,
        closesAt: FIRST_CLOSES_AT,
      },
    });
    expect(create.status).toBe(201);
    gradedAssignment = (await create.json() as { id: string }).id;

    const mark = await request("/v1/assessments", {
      method: "POST",
      subject: TEACHER_A,
      key: "api041-it-graded-2", // gitleaks:allow (synthetic idempotency key)
      body: {
        classroomId: CLASS_A,
        title: "Graded lab report",
        category: "assignment",
        maximumScore: 25,
        scheduledAt: FIRST_DUE_AT,
        delivery: "paper",
        questions: [],
        assignmentId: gradedAssignment,
      },
    });
    expect(mark.status).toBe(201);
    expect((await mark.json() as { assignmentId: string }).assignmentId)
      .toBe(gradedAssignment);

    const read = await request(`/v1/assignments/${gradedAssignment}`, {
      subject: TEACHER_A,
    });
    expect((await read.json() as { maximumScore: number }).maximumScore)
      .toBe(25);
  });

  test("a piece of work has one mark, in its own class", async () => {
    const again = await request("/v1/assessments", {
      method: "POST",
      subject: TEACHER_A,
      key: "api041-it-graded-3", // gitleaks:allow (synthetic idempotency key)
      body: {
        classroomId: CLASS_A,
        title: "Second mark",
        category: "assignment",
        maximumScore: 10,
        scheduledAt: null,
        delivery: "paper",
        questions: [],
        assignmentId: gradedAssignment,
      },
    });
    expect(again.status).not.toBe(201);

    const elsewhere = await request("/v1/assessments", {
      method: "POST",
      subject: TEACHER_A,
      key: "api041-it-graded-4",
      body: {
        classroomId: OTHER_CLASS,
        title: "Wrong class",
        category: "assignment",
        maximumScore: 10,
        scheduledAt: null,
        delivery: "paper",
        questions: [],
        assignmentId: gradedAssignment,
      },
    });
    expect(elsewhere.status).not.toBe(201);
  });
});
