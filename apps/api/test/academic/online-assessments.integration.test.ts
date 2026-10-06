/**
 * Online assessments over the real /v1 stack (ADR-0036): the builder,
 * attempts, marking, answer release and paper-grade attachments through the
 * Hono catalogue routes, AUTH-031 authorization, API-040 idempotency,
 * response-schema validation and the SQL handlers, against a real Postgres.
 *
 * The SQL rules themselves are proven by
 * supabase/tests/online_assessments.sql; this suite proves the HTTP
 * surface, and above all that an answer key never reaches a student or a
 * parent in a response before release.
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

const TEACHER = "5f470000-0000-4000-8000-0000000000a1";
const STUDENT_USER = "5f470000-0000-4000-8000-0000000000a2";
const ASSISTANT = "5f470000-0000-4000-8000-0000000000a3";
/** Linked by the child's ID: a verified link and no membership. */
const PARENT = "5f470000-0000-4000-8000-0000000000a4";
const OTHER_PARENT = "5f470000-0000-4000-8000-0000000000a5";
const SCHOOL = "5f470000-0000-4000-8000-0000000000b1";
const TERM = "5f470000-0000-4000-8000-0000000000c1";
const CLASS = "5f470000-0000-4000-8000-0000000000d1";
const STUDENT = "5f470000-0000-4000-8000-0000000000e1";
const OTHER_STUDENT = "5f470000-0000-4000-8000-0000000000e2";

const CURSOR_KEY = "online-assessments-cursor-key-000000001";
const KEY_FIELDS = [
  "correctOptionIds",
  "correctChoice",
  "acceptedAnswers",
  "preferredAnswer",
  "markingGuidance",
];

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
      (${TEACHER}::uuid, 'oa.teacher@synthetic.studafy.test', 'OA Teacher'),
      (${STUDENT_USER}::uuid, 'oa.student@synthetic.studafy.test', 'OA Student'),
      (${ASSISTANT}::uuid, 'oa.assistant@synthetic.studafy.test', 'OA Assistant'),
      (${PARENT}::uuid, 'oa.parent@synthetic.studafy.test', 'OA Parent'),
      (${OTHER_PARENT}::uuid, 'oa.parent2@synthetic.studafy.test', 'OA Other Parent')
    ) as u(id, email, name)
    on conflict (id) do nothing
  `;
  await sql`
    insert into public.schools (id, name, timezone, status) values
      (${SCHOOL}::uuid, 'OA School', 'Asia/Riyadh', 'active')
  `;
  await sql`
    insert into public.memberships (school_id, user_id, role, active) values
      (${SCHOOL}::uuid, ${TEACHER}::uuid, 'teacher', true),
      (${SCHOOL}::uuid, ${STUDENT_USER}::uuid, 'student', true),
      (${SCHOOL}::uuid, ${ASSISTANT}::uuid, 'teacher', true)
  `;
  await sql`
    insert into public.terms (id, school_id, name, starts_on, ends_on, active) values
      (${TERM}::uuid, ${SCHOOL}::uuid, 'OA Term', current_date - 60, current_date + 90, true)
  `;
  await sql`
    insert into public.classrooms (id, school_id, term_id, name, grade, section, teacher_id) values
      (${CLASS}::uuid, ${SCHOOL}::uuid, ${TERM}::uuid, 'OA Class', 'G8', 'A', ${TEACHER}::uuid)
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
      (${STUDENT}::uuid, ${SCHOOL}::uuid, ${STUDENT_USER}::uuid, 'STU-OA-1001', 'OA Student', false, ${TEACHER}::uuid),
      (${OTHER_STUDENT}::uuid, ${SCHOOL}::uuid, null, 'STU-OA-1002', 'OA Other Student', false, ${TEACHER}::uuid)
  `;
  await sql`
    insert into public.enrollments (classroom_id, student_id, active, starts_on) values
      (${CLASS}::uuid, ${STUDENT}::uuid, true, current_date - 60),
      (${CLASS}::uuid, ${OTHER_STUDENT}::uuid, true, current_date - 60)
  `;
  await sql`
    insert into public.guardian_links (student_id, guardian_id, status, relationship, verified_by, verified_at) values
      (${STUDENT}::uuid, ${PARENT}::uuid, 'verified', 'parent', ${TEACHER}::uuid, now()),
      (${OTHER_STUDENT}::uuid, ${OTHER_PARENT}::uuid, 'verified', 'parent', ${TEACHER}::uuid, now())
  `;
}

async function cleanup(): Promise<void> {
  await removeFixtures(sql, {
    schoolIds: [SCHOOL],
    userIds: [TEACHER, STUDENT_USER, ASSISTANT, PARENT, OTHER_PARENT],
  });
}

async function call(
  path: string,
  subject: string,
  body?: unknown,
): Promise<Response> {
  const headers = new Headers({ "x-test-subject": subject });
  if (body !== undefined) {
    headers.set("content-type", "application/json");
    headers.set("idempotency-key", `oa-${crypto.randomUUID()}`);
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

/** Whether any key, model answer or guidance appears anywhere in a body. */
function carriesAnswers(value: unknown): boolean {
  if (Array.isArray(value)) return value.some(carriesAnswers);
  if (value && typeof value === "object") {
    return Object.entries(value as Record<string, unknown>).some((
      [key, inner],
    ) => KEY_FIELDS.includes(key) || carriesAnswers(inner));
  }
  return false;
}

suite("online assessments over /v1", () => {
  let quizId: string;
  let version: number;
  let questions: { id: string; position: number; kind: string }[];
  let attemptId: string;

  beforeAll(async () => {
    sql = createDatabase(databaseUrl!);
    await cleanup();
    await seed();
    const contexts = new AuthContextRepository(sql);
    const logger = createJsonLogger(
      "api",
      "online-assessments-integration",
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

  test("a teacher builds a mixed quiz with a window and two attempts", async () => {
    const now = Date.now();
    const response = await call("/v1/assessments", TEACHER, {
      classroomId: CLASS,
      title: "OA quiz",
      category: "quiz",
      maximumScore: 6,
      scheduledAt: null,
      delivery: "online",
      opensAt: new Date(now - 3_600_000).toISOString(),
      closesAt: new Date(now + 3_600_000).toISOString(),
      maxAttempts: 2,
      attemptPolicy: "latest",
      answerRelease: "after_close",
      links: [{ title: "Revision", url: "https://revise.example.org/oa" }],
      questions: [
        {
          position: 1,
          kind: "single_choice",
          prompt: "2 + 2?",
          maximumScore: 2,
          preferredAnswer: null,
          options: [{ id: "a", text: "4" }, { id: "b", text: "5" }],
          correctOptionIds: ["a"],
        },
        {
          position: 2,
          kind: "true_false",
          prompt: "The sun is a star.",
          maximumScore: 1,
          preferredAnswer: null,
          correctChoice: true,
        },
        {
          position: 3,
          kind: "essay",
          prompt: "Why is the sky blue?",
          maximumScore: 3,
          preferredAnswer: "Rayleigh scattering.",
          markingGuidance: "Name the effect.",
        },
      ],
    });
    expect(response.status).toBe(201);
    const quiz = await json(response);
    expect(quiz["maxAttempts"]).toBe(2);
    expect((quiz["links"] as unknown[]).length).toBe(1);
    quizId = quiz["id"] as string;
    version = quiz["version"] as number;
  });

  test("an assistant cannot change the design; the teacher publishes", async () => {
    expect(
      (await call(`/v1/assessments/${quizId}/design`, ASSISTANT, {
        expectedVersion: version,
        maxAttempts: 5,
      })).status,
    ).toBe(404);
    const published = await call(`/v1/assessments/${quizId}/publish`, TEACHER, {
      expectedVersion: version,
    });
    expect(published.status).toBe(200);
  });

  test("the teacher sees the key; a student sees the questions without it", async () => {
    const authoring = await json(
      await call(`/v1/assessments/${quizId}/authoring-questions`, TEACHER),
    );
    expect(carriesAnswers(authoring)).toBe(true);
    const student = await call(
      `/v1/assessments/${quizId}/questions`,
      STUDENT_USER,
    );
    expect(student.status).toBe(200);
    const body = await json(student);
    expect(carriesAnswers(body)).toBe(false);
    questions = body["items"] as typeof questions;
    expect(questions.map((q) => q.kind)).toEqual([
      "single_choice",
      "true_false",
      "essay",
    ]);
  });

  test("a parent cannot sit it; the student submits and is told nothing of marks", async () => {
    const answers = [
      { questionId: questions[0]!.id, selectedOptionIds: ["a"] },
      { questionId: questions[1]!.id, choice: true },
      { questionId: questions[2]!.id, answerText: "Scattering." },
    ];
    expect(
      (await call(`/v1/assessments/${quizId}/submit`, PARENT, { answers }))
        .status,
    ).not.toBe(201);
    const response = await call(
      `/v1/assessments/${quizId}/submit`,
      STUDENT_USER,
      {
        answers,
      },
    );
    expect(response.status).toBe(201);
    const attempt = await json(response);
    expect(attempt["attemptNumber"]).toBe(1);
    expect(attempt["attemptsRemaining"]).toBe(1);
    expect(Object.keys(attempt)).not.toContain("awardedScore");
    attemptId = attempt["id"] as string;
  });

  test("while open, results carry the confirmation and nothing else", async () => {
    const response = await call(
      `/v1/assessment-results/${quizId}`,
      STUDENT_USER,
    );
    expect(response.status).toBe(200);
    const results = await json(response);
    expect(results["answersReleased"]).toBe(false);
    expect(results["grade"]).toBeNull();
    expect(carriesAnswers(results)).toBe(false);
    expect(
      Object.keys((results["attempts"] as Record<string, unknown>[])[0]!),
    ).not.toContain("answers");
  });

  test("the class's staff read and mark the attempt; the student cannot", async () => {
    expect(
      (await call(`/v1/assessment-attempts/${attemptId}`, STUDENT_USER)).status,
    ).toBe(404);
    const list = await json(
      await call(`/v1/assessments/${quizId}/attempts`, TEACHER),
    );
    expect(
      (list["items"] as Record<string, unknown>[])[0]!["needsMarking"],
    ).toBe(true);
    expect(
      (await call(`/v1/assessment-attempts/${attemptId}/mark`, ASSISTANT, {
        marks: [{ questionId: questions[2]!.id, score: 3 }],
      })).status,
    ).toBe(404);
    const marked = await call(
      `/v1/assessment-attempts/${attemptId}/mark`,
      TEACHER,
      {
        marks: [{
          questionId: questions[2]!.id,
          score: 3,
          feedback: "Spot on.",
        }],
        feedback: "Well done.",
      },
    );
    expect(marked.status).toBe(200);
    const detail = await json(marked);
    expect(detail["awardedScore"]).toBe(6);
    expect(detail["needsMarking"]).toBe(false);
  });

  test("closed for everyone: the student and the linked parent see the answers", async () => {
    await sql`update public.assessments set closes_at = now() - interval '1 second'
      where id = ${quizId}::uuid`;
    const results = await json(
      await call(`/v1/assessment-results/${quizId}`, STUDENT_USER),
    );
    expect(results["answersReleased"]).toBe(true);
    expect(carriesAnswers(results)).toBe(true);
    const parent = await call(
      `/v1/assessment-results/${quizId}?studentId=${STUDENT}`,
      PARENT,
    );
    expect(parent.status).toBe(200);
    expect((await json(parent))["canAttempt"]).toBe(false);
  });

  test("a parent of another child, or a student asking for another, gets nothing", async () => {
    expect(
      (await call(
        `/v1/assessment-results/${quizId}?studentId=${STUDENT}`,
        OTHER_PARENT,
      ))
        .status,
    ).toBe(404);
    expect(
      (await call(
        `/v1/assessment-results/${quizId}?studentId=${OTHER_STUDENT}`,
        STUDENT_USER,
      )).status,
    ).toBe(404);
  });

  test("paper grade attachments: shared and per student, private until published", async () => {
    const paper = await json(
      await call("/v1/assessments", TEACHER, {
        classroomId: CLASS,
        title: "OA paper",
        category: "test",
        maximumScore: 20,
        scheduledAt: null,
        delivery: "paper",
        questions: [],
      }),
    );
    const paperId = paper["id"] as string;
    const shared = await call(
      `/v1/assessments/${paperId}/grade-attachments`,
      TEACHER,
      {
        links: [{ title: "Mark scheme", url: "https://school.example.org/ms" }],
      },
    );
    expect(shared.status).toBe(200);
    expect(
      (await call(
        `/v1/assessments/${paperId}/grade-attachments`,
        TEACHER,
        {
          studentId: STUDENT,
          links: [{
            title: "Your feedback",
            url: "https://school.example.org/fb",
          }],
        },
      )).status,
    ).toBe(200);
    expect(
      (await call(
        `/v1/assessments/${paperId}/grade-attachments`,
        STUDENT_USER,
        {
          links: [{ title: "x", url: "https://evil.example.org/" }],
        },
      )).status,
    ).toBe(404);
    expect(
      (await call(`/v1/assessments/${paperId}/grade-attachments`, TEACHER, {
        links: [{ title: "x", url: "http://plain.example.org/" }],
      })).status,
    ).toBe(400);

    const sheet = await json(
      await call(`/v1/assessments/${paperId}/gradebook`, TEACHER),
    );
    expect(
      ((sheet["item"] as Record<string, unknown>)["sharedLinks"] as unknown[])
        .length,
    ).toBe(1);
    const gradebookVersion = (sheet["item"] as Record<string, number>)[
      "gradebookVersion"
    ];
    const row = (sheet["items"] as Record<string, Record<string, unknown>>[])
      .find((item) => (item["student"]!["id"] as string) === STUDENT)!;
    await call(`/v1/assessments/${paperId}/grades/drafts`, TEACHER, {
      expectedGradebookVersion: gradebookVersion,
      entries: [{
        studentId: STUDENT,
        expectedVersion: (row["grade"]?.["version"] as number | undefined) ?? 0,
        mark: "scored",
        score: 17,
      }],
    });
    const after = await json(
      await call(`/v1/assessments/${paperId}/gradebook`, TEACHER),
    );
    expect(
      (await call(`/v1/assessments/${paperId}/grades/publish`, TEACHER, {
        expectedGradebookVersion: (after["item"] as Record<string, number>)[
          "gradebookVersion"
        ],
      })).status,
    ).toBe(200);

    const grades = await json(
      await call(`/v1/grade-results?studentId=${STUDENT}`, PARENT),
    );
    const grade = (grades["items"] as Record<string, unknown>[]).find((g) =>
      g["assessmentId"] === paperId
    )!;
    expect((grade["links"] as unknown[]).length).toBe(1);
    expect((grade["sharedLinks"] as unknown[]).length).toBe(1);
  });
});
