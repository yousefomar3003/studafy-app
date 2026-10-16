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

  test("the teacher opens the attempt and sees every answer, question by question", async () => {
    const opened = await call(`/v1/assessment-attempts/${attemptId}`, TEACHER);
    expect(opened.status).toBe(200);
    const detail = await json(opened);
    expect(detail["studentName"]).toBe("OA Student");
    expect(detail["gradeState"]).toBe("draft");
    const answers = detail["answers"] as Record<string, unknown>[];
    expect(
      answers.map((a) => (a["question"] as Record<string, unknown>)["prompt"]),
    )
      .toEqual(["2 + 2?", "The sun is a star.", "Why is the sky blue?"]);
    // The objective answers are marked by the key; the essay waits.
    expect(answers[0]!["selectedOptionIds"]).toEqual(["a"]);
    expect(answers[0]!["autoScore"]).toBe(2);
    expect(answers[1]!["choice"]).toBe(true);
    expect(answers[2]!["answerText"]).toBe("Scattering.");
    expect(answers[2]!["awardedScore"]).toBeNull();
    expect(
      (answers[2]!["question"] as Record<string, unknown>)["maximumScore"],
    ).toBe(3);

    const list = await json(
      await call(`/v1/assessments/${quizId}/attempts`, TEACHER),
    );
    const row = (list["items"] as Record<string, unknown>[])[0]!;
    expect(row["gradeState"]).toBe("draft");
    expect(row["pendingAnswers"]).toBe(1);
    expect(row["manualAnswers"]).toBe(1);
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
    expect(detail["gradeState"]).toBe("reviewed");
  });

  test("marks are a private draft until published, feedback and all", async () => {
    const [grade] = await sql<
      { score: string; feedback: string; state: string }[]
    >`
      select score::text, feedback, state::text from public.grade_results
      where assessment_id = ${quizId}::uuid and student_id = ${STUDENT}::uuid`;
    expect(grade).toEqual({
      score: "6.00",
      feedback: "Well done.",
      state: "reviewed",
    });
    const results = await json(
      await call(`/v1/assessment-results/${quizId}`, STUDENT_USER),
    );
    expect(results["grade"]).toBeNull();
    const parent = await json(
      await call(
        `/v1/assessment-results/${quizId}?studentId=${STUDENT}`,
        PARENT,
      ),
    );
    expect(parent["grade"]).toBeNull();
  });

  test("a bad mark in a batch writes none of the marks", async () => {
    const response = await call(
      `/v1/assessment-attempts/${attemptId}/mark`,
      TEACHER,
      {
        marks: [
          { questionId: questions[2]!.id, score: 1 },
          { questionId: questions[0]!.id, score: 99 },
        ],
      },
    );
    expect(response.status).toBe(400);
    const detail = await json(
      await call(`/v1/assessment-attempts/${attemptId}`, TEACHER),
    );
    expect(detail["awardedScore"]).toBe(6);
  });

  test("publishing releases the grade and feedback once, to the student and the parent", async () => {
    const sheet = await json(
      await call(`/v1/assessments/${quizId}/gradebook`, TEACHER),
    );
    const version =
      (sheet["item"] as Record<string, number>)["gradebookVersion"];
    const published = await call(
      `/v1/assessments/${quizId}/grades/publish`,
      TEACHER,
      { expectedGradebookVersion: version },
    );
    expect(published.status).toBe(200);
    expect(await json(published)).toMatchObject({ published: 1, unmarked: 1 });

    // Publishing again has nothing new to release, and tells nobody twice.
    const again = await json(
      await call(`/v1/assessments/${quizId}/gradebook`, TEACHER),
    );
    expect(
      (await call(`/v1/assessments/${quizId}/grades/publish`, TEACHER, {
        expectedGradebookVersion: (again["item"] as Record<string, number>)[
          "gradebookVersion"
        ],
      })).status,
    ).toBe(409);
    const [outbox] = await sql<{ count: string }[]>`
      select count(*)::text from public.notification_outbox
      where source_event_id = ${quizId} and template_key = 'academic.grades_published'`;
    expect(outbox!.count).toBe("1");

    for (
      const [subject, query] of [
        [STUDENT_USER, ""],
        [PARENT, `?studentId=${STUDENT}`],
      ] as const
    ) {
      const results = await json(
        await call(`/v1/assessment-results/${quizId}${query}`, subject),
      );
      expect(results["grade"]).toMatchObject({
        score: 6,
        maximumScore: 6,
        feedback: "Well done.",
        state: "published",
      });
    }
    const list = await json(
      await call(`/v1/assessments/${quizId}/attempts`, TEACHER),
    );
    expect((list["items"] as Record<string, unknown>[])[0]!["gradeState"])
      .toBe("published");
  });

  test("changing a published mark needs a reason, and is a correction", async () => {
    const lower = { marks: [{ questionId: questions[2]!.id, score: 2 }] };
    const refused = await call(
      `/v1/assessment-attempts/${attemptId}/mark`,
      TEACHER,
      lower,
    );
    expect(refused.status).toBe(400);
    expect((await json(refused))["code"]).toBe("REASON_REQUIRED");
    // Refused means untouched: the answer still has its old mark.
    const unchanged = await json(
      await call(`/v1/assessment-attempts/${attemptId}`, TEACHER),
    );
    expect(unchanged["awardedScore"]).toBe(6);

    const corrected = await call(
      `/v1/assessment-attempts/${attemptId}/mark`,
      TEACHER,
      { ...lower, correctionReason: "Misread the second half." },
    );
    expect(corrected.status).toBe(200);
    expect((await json(corrected))["gradeState"]).toBe("published");
    const results = await json(
      await call(`/v1/assessment-results/${quizId}`, STUDENT_USER),
    );
    expect((results["grade"] as Record<string, unknown>)["score"]).toBe(5);
    const [history] = await sql<{ count: string }[]>`
      select count(*)::text from public.grade_result_events e
      join public.grade_results g on g.id = e.grade_result_id
      where g.assessment_id = ${quizId}::uuid and e.event_type = 'corrected'
        and e.reason = 'Misread the second half.' and e.previous_score = 6
        and e.next_score = 5`;
    expect(history!.count).toBe("1");

    // The same marks again change nothing, so need no reason and tell nobody.
    expect(
      (await call(`/v1/assessment-attempts/${attemptId}/mark`, TEACHER, lower))
        .status,
    ).toBe(200);
    const [notices] = await sql<{ count: string }[]>`
      select count(*)::text from public.notification_outbox
      where source_event_id = ${quizId} and template_key = 'academic.grades_corrected'`;
    expect(notices!.count).toBe("1");
  });

  test("after publication, feedback and comments need no reason; a mark does", async () => {
    const events = async (): Promise<number> => {
      const [row] = await sql<{ count: string }[]>`
        select count(*)::text from public.grade_result_events e
        join public.grade_results g on g.id = e.grade_result_id
        where g.assessment_id = ${quizId}::uuid and g.student_id = ${STUDENT}::uuid`;
      return Number(row!.count);
    };
    const notices = async (): Promise<string> => {
      const [row] = await sql<{ count: string }[]>`
        select count(*)::text from public.notification_outbox
        where source_event_id = ${quizId} and template_key = 'academic.grades_corrected'`;
      return row!.count;
    };
    const before = await events();
    const noticesBefore = await notices();
    const mark = (body: unknown) =>
      call(`/v1/assessment-attempts/${attemptId}/mark`, TEACHER, body);

    // Nothing changed: saved, nothing recorded.
    expect(
      (await mark({ marks: [{ questionId: questions[2]!.id, score: 2 }] }))
        .status,
    ).toBe(200);
    expect(await events()).toBe(before);

    // A comment on an answer: no reason, the grade untouched.
    expect(
      (await mark({
        marks: [{
          questionId: questions[2]!.id,
          score: 2,
          feedback: "Name Rayleigh scattering.",
        }],
      })).status,
    ).toBe(200);
    expect(await events()).toBe(before);

    // The feedback on the grade: no reason, applied, the old text kept.
    expect(
      (await mark({ marks: [], feedback: "Good work; see the model answer." }))
        .status,
    ).toBe(200);
    const results = await json(
      await call(`/v1/assessment-results/${quizId}`, STUDENT_USER),
    );
    expect(results["grade"]).toMatchObject({
      score: 5,
      feedback: "Good work; see the model answer.",
    });
    const [kept] = await sql<
      {
        reason: string | null;
        material: boolean;
        previous_feedback: string;
        next_score: string;
      }[]
    >`
      select e.reason, e.material, e.previous_feedback, e.next_score::text
      from public.grade_result_events e
      join public.grade_results g on g.id = e.grade_result_id
      where g.assessment_id = ${quizId}::uuid and g.student_id = ${STUDENT}::uuid
      order by e.id desc limit 1`;
    expect(kept).toEqual({
      reason: null,
      material: false,
      previous_feedback: "Well done.",
      next_score: "5.00",
    });
    expect(await notices()).toBe(noticesBefore);

    // A mark and a comment together: the mark makes it a correction.
    const mixed = {
      marks: [{
        questionId: questions[2]!.id,
        score: 3,
        feedback: "Full marks.",
      }],
    };
    const refused = await mark(mixed);
    expect(refused.status).toBe(400);
    expect((await json(refused))["code"]).toBe("REASON_REQUIRED");
    expect(
      (await mark({ ...mixed, correctionReason: "Second marker agreed." }))
        .status,
    ).toBe(200);
    expect(
      ((await json(
        await call(`/v1/assessment-results/${quizId}`, STUDENT_USER),
      ))[
        "grade"
      ] as Record<string, unknown>)["score"],
    ).toBe(6);
  });

  test("an attempt with some written answers marked is partly marked", async () => {
    const now = Date.now();
    const created = await json(
      await call("/v1/assessments", TEACHER, {
        classroomId: CLASS,
        title: "OA essays",
        category: "quiz",
        maximumScore: 10,
        scheduledAt: null,
        delivery: "online",
        opensAt: new Date(now - 3_600_000).toISOString(),
        closesAt: new Date(now + 3_600_000).toISOString(),
        questions: [1, 2].map((position) => ({
          position,
          kind: "essay",
          prompt: `Essay ${position}`,
          maximumScore: 5,
          preferredAnswer: null,
        })),
      }),
    );
    const id = created["id"] as string;
    await call(`/v1/assessments/${id}/publish`, TEACHER, {
      expectedVersion: created["version"],
    });
    const items = (await json(
      await call(`/v1/assessments/${id}/questions`, STUDENT_USER),
    ))["items"] as { id: string }[];
    const attempt = await json(
      await call(`/v1/assessments/${id}/submit`, STUDENT_USER, {
        answers: items.map((q) => ({
          questionId: q.id,
          answerText: "An answer.",
        })),
      }),
    );
    await call(`/v1/assessment-attempts/${attempt["id"]}/mark`, TEACHER, {
      marks: [{ questionId: items[0]!.id, score: 4, feedback: "Good start." }],
    });
    const list = await json(
      await call(`/v1/assessments/${id}/attempts`, TEACHER),
    );
    expect((list["items"] as Record<string, unknown>[])[0]).toMatchObject({
      needsMarking: true,
      pendingAnswers: 1,
      manualAnswers: 2,
      gradeState: "draft",
    });
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

  /** An open online quiz with one choice question, published. */
  async function openQuiz(title: string): Promise<{ id: string; q: string }> {
    const now = Date.now();
    const created = await json(
      await call("/v1/assessments", TEACHER, {
        classroomId: CLASS,
        title,
        category: "quiz",
        maximumScore: 2,
        scheduledAt: null,
        delivery: "online",
        opensAt: new Date(now - 3_600_000).toISOString(),
        closesAt: new Date(now + 3_600_000).toISOString(),
        questions: [{
          position: 1,
          kind: "single_choice",
          prompt: "Pick a",
          maximumScore: 2,
          preferredAnswer: null,
          options: [{ id: "a", text: "A" }, { id: "b", text: "B" }],
          correctOptionIds: ["a"],
        }],
      }),
    );
    const id = created["id"] as string;
    await call(`/v1/assessments/${id}/publish`, TEACHER, {
      expectedVersion: created["version"],
    });
    const items = (await json(
      await call(`/v1/assessments/${id}/questions`, STUDENT_USER),
    ))["items"] as { id: string }[];
    return { id, q: items[0]!.id };
  }

  async function sheet(id: string) {
    const body = await json(
      await call(`/v1/assessments/${id}/gradebook`, TEACHER),
    );
    const rows = body["items"] as {
      student: { id: string };
      grade: Record<string, unknown> | null;
    }[];
    return {
      version: (body["item"] as Record<string, number>)["gradebookVersion"]!,
      row: (student: string) =>
        rows.find((r) => r.student.id === student)!.grade,
    };
  }

  async function markAbsent(id: string, student: string, notes?: string) {
    const current = await sheet(id);
    return await call(`/v1/assessments/${id}/grades/drafts`, TEACHER, {
      expectedGradebookVersion: current.version,
      entries: [{
        studentId: student,
        expectedVersion: (current.row(student)?.["version"] as number) ?? 0,
        mark: "absent",
        feedback: notes ?? null,
      }],
    });
  }

  async function publish(id: string): Promise<number> {
    const current = await sheet(id);
    return (await call(`/v1/assessments/${id}/grades/publish`, TEACHER, {
      expectedGradebookVersion: current.version,
    })).status;
  }

  test("a non-submitter is marked absent, never with a score, and it is published as absent", async () => {
    const quiz = await openQuiz("OA absence");
    expect((await markAbsent(quiz.id, OTHER_STUDENT, "Off sick")).status).toBe(
      200,
    );
    expect((await sheet(quiz.id)).row(OTHER_STUDENT)).toMatchObject({
      mark: "absent",
      score: null,
      state: "reviewed",
      feedback: "Off sick",
    });
    // Absence is never a score, and online work is not scored by hand.
    const current = await sheet(quiz.id);
    expect(
      (await call(`/v1/assessments/${quiz.id}/grades/drafts`, TEACHER, {
        expectedGradebookVersion: current.version,
        entries: [{
          studentId: OTHER_STUDENT,
          expectedVersion: current.row(OTHER_STUDENT)!["version"],
          mark: "scored",
          score: 0,
        }],
      })).status,
    ).toBe(409);
    // Only the class's teachers mark it.
    expect(
      (await call(`/v1/assessments/${quiz.id}/grades/drafts`, ASSISTANT, {
        entries: [{
          studentId: OTHER_STUDENT,
          expectedVersion: 0,
          mark: "absent",
        }],
      })).status,
    ).toBe(404);
    const [history] = await sql<{ next_mark: string; next_feedback: string }[]>`
      select e.next_mark::text, e.next_feedback from public.grade_result_events e
      join public.grade_results g on g.id = e.grade_result_id
      where g.assessment_id = ${quiz.id}::uuid and g.student_id = ${OTHER_STUDENT}::uuid`;
    expect(history).toEqual({ next_mark: "absent", next_feedback: "Off sick" });

    // Private until published; then the parent sees an absence, not a zero.
    const parentView = async () =>
      (await json(
        await call(
          `/v1/assessment-results/${quiz.id}?studentId=${OTHER_STUDENT}`,
          OTHER_PARENT,
        ),
      ))["grade"] as Record<string, unknown> | null;
    expect(await parentView()).toBeNull();
    expect(await publish(quiz.id)).toBe(200);
    expect(await parentView()).toMatchObject({
      mark: "absent",
      score: null,
      feedback: "Off sick",
      state: "published",
    });

    // Corrected, with a reason, to not graded.
    const grade = (await sheet(quiz.id)).row(OTHER_STUDENT)!;
    expect(
      (await call(`/v1/assessments/${quiz.id}/grades/correct`, TEACHER, {
        reason: "Excused by the school office.",
        entries: [{
          gradeResultId: grade["id"],
          expectedVersion: grade["version"],
          mark: "not_graded",
          feedback: "Excused.",
        }],
      })).status,
    ).toBe(200);
    expect(await parentView()).toMatchObject({
      mark: "not_graded",
      score: null,
    });
  });

  test("a student who handed in cannot be marked absent", async () => {
    const quiz = await openQuiz("OA submitted");
    await call(`/v1/assessments/${quiz.id}/submit`, STUDENT_USER, {
      answers: [{ questionId: quiz.q, selectedOptionIds: ["a"] }],
    });
    expect((await markAbsent(quiz.id, STUDENT)).status).toBe(409);
  });

  test("handing in after an unpublished absence replaces it, on the record", async () => {
    const quiz = await openQuiz("OA late");
    expect((await markAbsent(quiz.id, STUDENT, "Not in class")).status).toBe(
      200,
    );
    expect(
      (await call(`/v1/assessments/${quiz.id}/submit`, STUDENT_USER, {
        answers: [{ questionId: quiz.q, selectedOptionIds: ["a"] }],
      })).status,
    ).toBe(201);
    expect((await sheet(quiz.id)).row(STUDENT)).toMatchObject({
      mark: "scored",
      score: 2,
      state: "reviewed",
    });
    const [replaced] = await sql<{ previous_mark: string; reason: string }[]>`
      select e.previous_mark::text, e.reason from public.grade_result_events e
      join public.grade_results g on g.id = e.grade_result_id
      where g.assessment_id = ${quiz.id}::uuid and g.student_id = ${STUDENT}::uuid
        and e.reason is not null`;
    expect(replaced).toEqual({
      previous_mark: "absent",
      reason: "Handed in after being marked absent",
    });
  });

  test("a published absence stands until the teacher corrects it with a reason", async () => {
    const quiz = await openQuiz("OA published absence");
    await markAbsent(quiz.id, STUDENT);
    expect(await publish(quiz.id)).toBe(200);
    const attempt = await json(
      await call(`/v1/assessments/${quiz.id}/submit`, STUDENT_USER, {
        answers: [{ questionId: quiz.q, selectedOptionIds: ["a"] }],
      }),
    );
    const own = async () =>
      (await json(
        await call(`/v1/assessment-results/${quiz.id}`, STUDENT_USER),
      ))[
        "grade"
      ] as Record<string, unknown>;
    expect(await own()).toMatchObject({ mark: "absent", score: null });
    const detail = await json(
      await call(`/v1/assessment-attempts/${attempt["id"]}`, TEACHER),
    );
    expect(detail).toMatchObject({
      gradeState: "published",
      gradeMark: "absent",
    });

    const apply = (body: Record<string, unknown>) =>
      call(`/v1/assessment-attempts/${attempt["id"]}/mark`, TEACHER, {
        marks: [],
        ...body,
      });
    expect((await apply({})).status).toBe(400);
    expect(
      (await apply({ correctionReason: "Sat it late with permission." }))
        .status,
    ).toBe(200);
    expect(await own()).toMatchObject({ mark: "scored", score: 2 });
  });

  test("a section has its content once a lesson filed for it is published", async () => {
    const [session] = await sql<{ id: string }[]>`
      insert into public.lesson_sessions (school_id, classroom_id, starts_at, ends_at, status, version)
      values (${SCHOOL}::uuid, ${CLASS}::uuid, now() - interval '1 day',
        now() - interval '1 day' + interval '45 minutes', 'completed', 1)
      returning id`;
    const sessionId = session!.id;
    const stateFor = async (subject: string): Promise<unknown> => {
      const page = await json(
        await call(
          `/v1/lesson-sessions?classroomId=${CLASS}&pageSize=100`,
          subject,
        ),
      );
      return (page["items"] as Record<string, unknown>[])
        .find((s) => s["id"] === sessionId)?.["contentState"];
    };
    expect(await stateFor(TEACHER)).toBe("none");

    const lesson = await json(
      await call("/v1/resources", TEACHER, {
        schoolId: SCHOOL,
        classroomId: CLASS,
        title: "Fractions",
        resourceType: "lesson_note",
        body: "Halves and quarters.",
        audience: "both",
        lessonSessionId: sessionId,
      }),
    );
    // A draft is not content the class can see.
    expect(await stateFor(TEACHER)).toBe("draft");
    expect(await stateFor(STUDENT_USER)).not.toBe("published");

    const published = await json(
      await call(`/v1/resources/${lesson["id"]}/publish`, TEACHER, {
        expectedVersion: lesson["version"],
      }),
    );
    expect(await stateFor(TEACHER)).toBe("published");

    await call(`/v1/resources/${lesson["id"]}/withdraw`, TEACHER, {
      expectedVersion: published["version"],
    });
    expect(await stateFor(TEACHER)).toBe("none");
  });

  /** An upload of the teacher's for the class, as the scan left it. */
  async function upload(
    id: string,
    purpose: string,
    scanState: "clean" | "rejected",
  ): Promise<string> {
    const session = crypto.randomUUID();
    await sql`
      insert into public.file_objects (id, school_id, bucket, object_key,
        uploader_id, size_bytes, declared_media_type, sha256, scan_state,
        scanned_at, owner_id, purpose, display_name)
      values (${id}::uuid, ${SCHOOL}::uuid, 'legacy', ${"oa/" + id},
        ${TEACHER}::uuid, 10, 'application/pdf', ${"b".repeat(64)},
        ${scanState}::public.file_scan_state, now(), ${TEACHER}::uuid,
        ${purpose}::public.file_purpose, 'Slides.pdf')`;
    await sql`
      insert into public.upload_sessions (id, school_id, uploader_id, purpose,
        expected_size_bytes, allowed_media_types, nonce_hash, expires_at,
        classroom_id)
      values (${session}::uuid, ${SCHOOL}::uuid, ${TEACHER}::uuid,
        ${purpose}::public.file_purpose, 10, array['application/pdf'],
        ${id.replaceAll("-", "").padEnd(64, "c")}, now() + interval '1 hour',
        ${CLASS}::uuid)`;
    await sql`
      insert into public.file_bindings (school_id, file_object_id, upload_session_id)
      values (${SCHOOL}::uuid, ${id}::uuid, ${session}::uuid)`;
    return id;
  }

  test("a lesson with a file the scan refused names that file, and saves once it is removed", async () => {
    const clean = await upload(
      "5f470000-0000-4000-8000-0000000002f1",
      "lesson_resource",
      "clean",
    );
    const refused = await upload(
      "5f470000-0000-4000-8000-0000000002f2",
      "lesson_resource",
      "rejected",
    );
    const lesson = {
      schoolId: SCHOOL,
      classroomId: CLASS,
      title: "Refused slides",
      resourceType: "lesson_note",
      body: "Notes.",
      audience: "both",
    };
    const response = await call("/v1/resources", TEACHER, {
      ...lesson,
      attachmentFileIds: [clean, refused],
    });
    expect(response.status).toBe(422);
    expect(response.headers.get("content-type")).toContain(
      "application/problem+json",
    );
    const problem = await json(response);
    expect(problem["code"]).toBe("ATTACHMENT_REFUSED");
    expect(problem["errors"]).toEqual([
      { path: "attachmentFileIds.1", code: "file_refused" },
    ]);

    // The same request again is refused the same way: nothing was kept.
    const again = await call("/v1/resources", TEACHER, {
      ...lesson,
      attachmentFileIds: [clean, refused],
    });
    expect(again.status).toBe(422);

    const saved = await call("/v1/resources", TEACHER, {
      ...lesson,
      attachmentFileIds: [clean],
    });
    expect(saved.status).toBe(201);
    expect(((await json(saved))["attachments"] as unknown[]).length).toBe(1);
  });

  test("a refused link on homework names the link", async () => {
    const response = await call("/v1/assignments", TEACHER, {
      classroomId: CLASS,
      title: "Reading with a bad link",
      instructions: null,
      dueAt: new Date(Date.now() + 86_400_000).toISOString(),
      closesAt: null,
      links: [
        { title: "Fine", url: "https://school.example.org/read" },
        { title: "Creds", url: "https://user:pw@evil.example.org/" },
      ],
    });
    expect(response.status).toBe(422);
    const problem = await json(response);
    expect(problem["code"]).toBe("ATTACHMENT_REFUSED");
    expect(problem["errors"]).toEqual([
      { path: "links.1", code: "link_not_allowed" },
    ]);
  });
});
