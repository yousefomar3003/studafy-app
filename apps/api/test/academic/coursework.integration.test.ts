/**
 * Paper gradebook, attendance corrections and deadlines over the real /v1
 * stack: the Hono catalogue routes, AUTH-031 authorization, API-040
 * idempotency and the SQL handlers, against a real local Postgres.
 *
 * The SQL rules themselves (policy windows, history rows, file access) are
 * proven by supabase/tests/{paper_gradebook,attendance_corrections,
 * submission_deadlines,coursework_files}.sql; this suite proves the HTTP
 * surface: status codes, problem codes, per-row errors, concealment and
 * replay.
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
import { PostgresAcademicRepository } from "../../src/academic/repository";
import {
  createAcademicRoutes,
  createCourseworkRoutes,
} from "../../src/academic/routes";

const databaseUrl = process.env["DATABASE_URL"];
const suite = integrationSuite(describe);

const TEACHER = "5f430000-0000-4000-8000-0000000000a1";
const STUDENT_USER = "5f430000-0000-4000-8000-0000000000a2";
const ASSISTANT = "5f430000-0000-4000-8000-0000000000a3";
/** Linked by the child's ID: a verified link and no membership. */
const PARENT = "5f430000-0000-4000-8000-0000000000a4";
const OTHER_TEACHER = "5f430000-0000-4000-8000-0000000000a5";
const SCHOOL = "5f430000-0000-4000-8000-0000000000b1";
const OTHER_SCHOOL = "5f430000-0000-4000-8000-0000000000b2";
const TERM = "5f430000-0000-4000-8000-0000000000c1";
const CLASS = "5f430000-0000-4000-8000-0000000000d1";
const STUDENT = "5f430000-0000-4000-8000-0000000000e1";
const OUTSIDER = "5f430000-0000-4000-8000-0000000000e2";
const OLD_SESSION = "5f430000-0000-4000-8000-0000000000f1";
const LATE_WORK = "5f430000-0000-4000-8000-0000000000f2";

const CURSOR_KEY = "coursework-integration-cursor-key-00000001";

let sql: Sql;
let app: Hono<AuthorizationEnv>;

async function seed(): Promise<void> {
  await sql`
    insert into auth.users (
      id, email, encrypted_password, aud, role, email_confirmed_at,
      created_at, updated_at, instance_id, confirmation_token, recovery_token,
      email_change, email_change_token_new, email_change_token_current,
      phone_change_token, raw_app_meta_data, raw_user_meta_data
    )
    select id, email, 'synthetic-not-a-secret', 'authenticated', 'authenticated',
      now(), now(), now(), '00000000-0000-0000-0000-000000000000', '', '', '',
      '', '', '', '{}'::jsonb, jsonb_build_object('full_name', name)
    from (values
      (${TEACHER}::uuid, 'cw.teacher@synthetic.studafy.test', 'CW Teacher'),
      (${STUDENT_USER}::uuid, 'cw.student@synthetic.studafy.test', 'CW Student'),
      (${ASSISTANT}::uuid, 'cw.assistant@synthetic.studafy.test', 'CW Assistant'),
      (${PARENT}::uuid, 'cw.parent@synthetic.studafy.test', 'CW Parent'),
      (${OTHER_TEACHER}::uuid, 'cw.other@synthetic.studafy.test', 'CW Other')
    ) as u(id, email, name)
    on conflict (id) do nothing
  `;
  await sql`
    insert into public.schools (id, name, timezone, status) values
      (${SCHOOL}::uuid, 'CW School', 'Asia/Riyadh', 'active'),
      (${OTHER_SCHOOL}::uuid, 'CW Other School', 'Asia/Riyadh', 'active')
  `;
  await sql`
    insert into public.memberships (school_id, user_id, role, active) values
      (${SCHOOL}::uuid, ${TEACHER}::uuid, 'teacher', true),
      (${SCHOOL}::uuid, ${STUDENT_USER}::uuid, 'student', true),
      (${SCHOOL}::uuid, ${ASSISTANT}::uuid, 'teacher', true),
      (${OTHER_SCHOOL}::uuid, ${OTHER_TEACHER}::uuid, 'teacher', true)
  `;
  await sql`
    insert into public.terms (id, school_id, name, starts_on, ends_on, active) values
      (${TERM}::uuid, ${SCHOOL}::uuid, 'CW Term', current_date - 60, current_date + 90, true)
  `;
  await sql`
    insert into public.classrooms (id, school_id, term_id, name, grade, section, teacher_id) values
      (${CLASS}::uuid, ${SCHOOL}::uuid, ${TERM}::uuid, 'CW Class', 'G8', 'A', ${TEACHER}::uuid)
  `;
  await sql`
    insert into public.classroom_staff (school_id, classroom_id, membership_id, user_id, role)
    select ${SCHOOL}::uuid, ${CLASS}::uuid, m.id, m.user_id,
      case when m.user_id = ${TEACHER}::uuid then 'lead_teacher' else 'assistant' end::public.classroom_staff_role
    from public.memberships m
    where m.school_id = ${SCHOOL}::uuid and m.user_id in (${TEACHER}::uuid, ${ASSISTANT}::uuid)
  `;
  await sql`
    insert into public.students (id, school_id, user_id, studafy_id, display_name, provisional, created_by) values
      (${STUDENT}::uuid, ${SCHOOL}::uuid, ${STUDENT_USER}::uuid, 'STU-CW-0001', 'CW Student', false, ${TEACHER}::uuid),
      (${OUTSIDER}::uuid, ${SCHOOL}::uuid, null, 'STU-CW-0002', 'CW Outsider', false, ${TEACHER}::uuid)
  `;
  await sql`
    insert into public.enrollments (classroom_id, student_id, active, starts_on) values
      (${CLASS}::uuid, ${STUDENT}::uuid, true, current_date - 60)
  `;
  await sql`
    insert into public.guardian_links (student_id, guardian_id, status, relationship, verified_by, verified_at) values
      (${STUDENT}::uuid, ${PARENT}::uuid, 'verified', 'parent', ${TEACHER}::uuid, now())
  `;
  // A lesson twelve days ago, past the default seven-day window.
  await sql`
    insert into public.lesson_sessions (id, classroom_id, starts_at, ends_at, status) values
      (${OLD_SESSION}::uuid, ${CLASS}::uuid, now() - interval '12 days',
        now() - interval '12 days' + interval '45 minutes', 'completed')
  `;
  await sql`
    insert into public.attendance_records (session_id, student_id, state, recorded_by) values
      (${OLD_SESSION}::uuid, ${STUDENT}::uuid, 'present', ${TEACHER}::uuid)
  `;
  await sql`
    insert into public.assignments (id, school_id, classroom_id, title, due_at, state, created_by, version, published_at)
    values (${LATE_WORK}::uuid, ${SCHOOL}::uuid, ${CLASS}::uuid, 'CW Essay',
      now() - interval '1 hour', 'published', ${TEACHER}::uuid, 1, now() - interval '2 days')
  `;
}

async function cleanup(): Promise<void> {
  await removeFixtures(sql, {
    schoolIds: [SCHOOL, OTHER_SCHOOL],
    userIds: [TEACHER, STUDENT_USER, ASSISTANT, PARENT, OTHER_TEACHER],
  });
}

async function call(
  path: string,
  subject: string,
  body?: unknown,
  key?: string,
): Promise<Response> {
  const headers = new Headers({ "x-test-subject": subject });
  if (body !== undefined) {
    headers.set("content-type", "application/json");
    headers.set("idempotency-key", key ?? `cw-${crypto.randomUUID()}`);
  }
  return await app.request(path, {
    method: body === undefined ? "GET" : "POST",
    headers,
    ...(body === undefined ? {} : { body: JSON.stringify(body) }),
  });
}

async function json(response: Response): Promise<Record<string, unknown>> {
  return await response.json() as Record<string, unknown>;
}

suite("paper gradebook, corrections and deadlines over /v1", () => {
  let itemId: string;
  let gradebookVersion: number;
  let gradeId: string;

  beforeAll(async () => {
    sql = createDatabase(databaseUrl!);
    await cleanup();
    await seed();
    const contexts = new AuthContextRepository(sql);
    const logger = createJsonLogger(
      "api",
      "coursework-integration",
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
    const deps = {
      repository: new PostgresAcademicRepository(sql),
      cursorSigningKey: CURSOR_KEY,
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
    app.route("/", createAcademicRoutes(deps, authorization, idempotency));
    app.route("/", createCourseworkRoutes(deps, authorization, idempotency));
  });

  afterAll(async () => {
    if (!sql) return;
    await cleanup();
    await sql.end({ timeout: 5 });
  });

  test("a teacher sets up a paper exam with a weight", async () => {
    const response = await call("/v1/assessments", TEACHER, {
      classroomId: CLASS,
      title: "Term 1 exam (paper)",
      category: "paper_exam",
      maximumScore: 50,
      scheduledAt: null,
      delivery: "paper",
      questions: [],
      weight: 40,
    });
    expect(response.status).toBe(201);
    const item = await json(response);
    expect(item["weight"]).toBe(40);
    itemId = item["id"] as string;
  });

  test("the class's staff read the gradebook; a student is told it does not exist", async () => {
    const teacher = await call(
      `/v1/assessments/${itemId}/gradebook`,
      TEACHER,
    );
    expect(teacher.status).toBe(200);
    const sheet = await json(teacher);
    expect((sheet["items"] as unknown[]).length).toBe(1);
    gradebookVersion = (sheet["item"] as Record<string, number>)[
      "gradebookVersion"
    ]!;
    expect(
      (await call(`/v1/assessments/${itemId}/gradebook`, ASSISTANT)).status,
    ).toBe(200);
    expect(
      (await call(`/v1/assessments/${itemId}/gradebook`, STUDENT_USER)).status,
    ).toBe(404);
    expect(
      (await call(`/v1/assessments/${itemId}/gradebook`, OTHER_TEACHER))
        .status,
    ).toBe(404);
  });

  test("a sheet with a student outside the class is refused whole, naming the row", async () => {
    const response = await call(
      `/v1/assessments/${itemId}/grades/drafts`,
      TEACHER,
      {
        entries: [
          { studentId: STUDENT, expectedVersion: 0, mark: "scored", score: 41 },
          { studentId: OUTSIDER, expectedVersion: 0, mark: "absent" },
        ],
      },
    );
    expect(response.status).toBe(422);
    const problem = await json(response);
    expect(problem["code"]).toBe("GRADE_ENTRIES_INVALID");
    expect(problem["errors"]).toEqual([
      { path: `students/${OUTSIDER}`, code: "not_enrolled" },
    ]);
  });

  test("an assistant cannot enter marks", async () => {
    const response = await call(
      `/v1/assessments/${itemId}/grades/drafts`,
      ASSISTANT,
      {
        entries: [{
          studentId: STUDENT,
          expectedVersion: 0,
          mark: "scored",
          score: 50,
        }],
      },
    );
    expect(response.status).toBe(404);
  });

  test("draft marks save once, replay safely, and stay private", async () => {
    const key = `cw-drafts-${crypto.randomUUID()}`;
    const body = {
      expectedGradebookVersion: gradebookVersion,
      entries: [{
        studentId: STUDENT,
        expectedVersion: 0,
        mark: "scored",
        score: 41,
        feedback: "Strong on part B",
      }],
    };
    const first = await call(
      `/v1/assessments/${itemId}/grades/drafts`,
      TEACHER,
      body,
      key,
    );
    expect(first.status).toBe(200);
    const saved = await json(first);
    gradebookVersion = saved["gradebookVersion"] as number;
    const replay = await call(
      `/v1/assessments/${itemId}/grades/drafts`,
      TEACHER,
      body,
      key,
    );
    expect(replay.status).toBe(200);
    expect(replay.headers.get("idempotency-replayed")).toBe("true");

    const mine = await json(
      await call(`/v1/grade-results?studentId=${STUDENT}`, STUDENT_USER),
    );
    expect(
      (mine["items"] as { assessmentId: string }[]).some((g) =>
        g.assessmentId === itemId
      ),
    ).toBe(false);
    const child = await json(
      await call(`/v1/grade-results?studentId=${STUDENT}`, PARENT),
    );
    expect(
      (child["items"] as { assessmentId: string }[]).some((g) =>
        g.assessmentId === itemId
      ),
    ).toBe(false);
  });

  test("publishing a stale sheet conflicts; publishing the current one releases it", async () => {
    const stale = await call(
      `/v1/assessments/${itemId}/grades/publish`,
      TEACHER,
      { expectedGradebookVersion: gradebookVersion - 1 },
    );
    expect(stale.status).toBe(409);
    expect((await json(stale))["code"]).toBe("VERSION_CONFLICT");

    const published = await call(
      `/v1/assessments/${itemId}/grades/publish`,
      TEACHER,
      { expectedGradebookVersion: gradebookVersion },
    );
    expect(published.status).toBe(200);
    expect((await json(published))["published"]).toBe(1);

    const child = await json(
      await call(`/v1/grade-results?studentId=${STUDENT}`, PARENT),
    );
    const grade = (child["items"] as Record<string, unknown>[]).find((g) =>
      g["assessmentId"] === itemId
    )!;
    expect(grade["delivery"]).toBe("paper");
    expect(grade["mark"]).toBe("scored");
    expect(grade["score"]).toBe(41);
    gradeId = grade["id"] as string;
  });

  test("a correction needs a reason, and its history shows the old mark", async () => {
    const version = (await sql<{ version: number }[]>`
      select version::int from public.grade_results where id = ${gradeId}::uuid
    `)[0]!.version;
    const missing = await call(
      `/v1/assessments/${itemId}/grades/correct`,
      TEACHER,
      {
        reason: "",
        entries: [{
          gradeResultId: gradeId,
          expectedVersion: version,
          mark: "scored",
          score: 44,
        }],
      },
    );
    expect(missing.status).toBe(400);

    const corrected = await call(
      `/v1/assessments/${itemId}/grades/correct`,
      TEACHER,
      {
        reason: "Missed a page when adding up",
        entries: [{
          gradeResultId: gradeId,
          expectedVersion: version,
          mark: "scored",
          score: 44,
          feedback: "Strong on part B",
        }],
      },
    );
    expect(corrected.status).toBe(200);
    expect((await json(corrected))["notified"]).toBe(1);

    const history = await json(
      await call(`/v1/grade-results/${gradeId}/history`, TEACHER),
    );
    const latest = (history["items"] as Record<string, unknown>[])[0]!;
    expect(latest["change"]).toBe("corrected");
    expect(latest["previousScore"]).toBe(41);
    expect(latest["nextScore"]).toBe(44);
    expect(latest["reason"]).toBe("Missed a page when adding up");
    expect(
      (await call(`/v1/grade-results/${gradeId}/history`, STUDENT_USER))
        .status,
    ).toBe(404);
  });

  test("a locked register needs the lead teacher, an override and a reason", async () => {
    const version = (await sql<{ version: number }[]>`
      select version::int from public.lesson_sessions where id = ${OLD_SESSION}::uuid
    `)[0]!.version;
    const entries = [{ studentId: STUDENT, state: "absent", reason: null }];
    const path = `/v1/lesson-sessions/${OLD_SESSION}/attendance/correct`;

    expect(
      (await call(path, ASSISTANT, {
        expectedVersion: version,
        reason: "x",
        entries,
      })).status,
    ).toBe(404);
    const locked = await call(path, TEACHER, {
      expectedVersion: version,
      reason: "Misread",
      entries,
    });
    expect(locked.status).toBe(409);
    expect((await json(locked))["code"]).toBe("ATTENDANCE_LOCKED");
    const reasonless = await call(path, TEACHER, {
      expectedVersion: version,
      override: true,
      entries,
    });
    expect(reasonless.status).toBe(400);
    expect((await json(reasonless))["code"]).toBe("REASON_REQUIRED");
    const done = await call(path, TEACHER, {
      expectedVersion: version,
      override: true,
      reason: "Register was misread",
      entries,
    });
    expect(done.status).toBe(200);

    const history = await json(
      await call(
        `/v1/lesson-sessions/${OLD_SESSION}/attendance/history`,
        TEACHER,
      ),
    );
    const change = (history["items"] as Record<string, unknown>[])[0]!;
    expect(change["previousState"]).toBe("present");
    expect(change["nextState"]).toBe("absent");
    expect(change["override"]).toBe(true);
  });

  test("closed work opens again for one student only through an extension", async () => {
    const closed = await call(
      `/v1/assignments/${LATE_WORK}/submit`,
      STUDENT_USER,
      { answerText: "Sorry this is late" },
    );
    expect(closed.status).toBe(409);
    expect((await json(closed))["code"]).toBe("WINDOW_CLOSED");

    expect(
      (await call(`/v1/assignments/${LATE_WORK}/extensions`, PARENT, {
        studentId: STUDENT,
        extendedUntilLocal: "2099-01-01T12:00",
        reason: "Please",
      })).status,
    ).toBe(404);
    const granted = await call(
      `/v1/assignments/${LATE_WORK}/extensions`,
      TEACHER,
      {
        studentId: STUDENT,
        extendedUntilLocal: "2099-01-01T12:00",
        reason: "Was in hospital",
      },
    );
    expect(granted.status).toBe(201);
    expect((await json(granted))["extendedUntilLocal"]).toBe(
      "2099-01-01T12:00",
    );

    const submitted = await call(
      `/v1/assignments/${LATE_WORK}/submit`,
      STUDENT_USER,
      { answerText: "Here it is" },
    );
    expect(submitted.status).toBe(201);
    expect((await json(submitted))["late"]).toBe(true);

    const view = await json(
      await call(`/v1/assignments/${LATE_WORK}`, STUDENT_USER),
    );
    expect(view["submissionState"]).toBe("open");
    expect(view["timeZone"]).toBe("Asia/Riyadh");
  });
});
