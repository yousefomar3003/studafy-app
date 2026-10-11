/**
 * Quizzes, flashcards and notes from exactly the chosen material, over real
 * SQL (ADR-0039): only what was chosen is read, a lesson the student cannot
 * see is refused, the same choice opens again for free, and notes say what
 * they were made from.
 */
import { afterAll, beforeAll, describe, expect, test } from "bun:test";
import { Hono } from "hono";
import { testAssurance } from "../support/assurance";
import type { LogLevel } from "@studafy/contracts";
import { createDatabase, type Sql } from "@studafy/database";
import { createJsonLogger } from "@studafy/observability";
import type { StudyAssistant } from "@studafy/infrastructure";
import { AuthContextRepository } from "../../src/auth/context";
import type { Actor } from "../../src/auth/middleware";
import type { AuthorizationEnv } from "../../src/authorization/middleware";
import { createAuthorizationDependencies } from "../../src/authorization/middleware";
import { PostgresAuthorizationRepository } from "../../src/authorization/repository";
import { PostgresIdempotencyRepository } from "../../src/platform/idempotency";
import { PostgresStudyRepository } from "../../src/study/repository";
import { PostgresMaterialRepository } from "../../src/study/material";
import {
  createSelectionRoutes,
  PostgresMaterialOutputRepository,
} from "../../src/study/selectionRoutes";
import { integrationSuite, removeFixtures } from "@studafy/test-support";

const databaseUrl = process.env["DATABASE_URL"];
const suite = integrationSuite(describe);

const P = "f0b30000-0000-4000-8000-0000000000";
const SCHOOL = `${P}01`;
const TERM = `${P}02`;
const CLASSROOM = `${P}03`;
const TEACHER = `${P}11`;
const STUDENT = `${P}12`;
const OUTSIDER = `${P}14`;
const STUDENT_ROW = `${P}21`;
const OUTSIDER_ROW = `${P}23`;
const LESSON = `${P}31`;
const LESSON_V1 = `${P}32`;
const LESSON2 = `${P}33`;
const LESSON2_V1 = `${P}34`;
const OTHER_CLASSROOM = `${P}04`;
const HIDDEN = `${P}35`;
const HIDDEN_V1 = `${P}36`;

const PRICES = { inputUsdPerMTok: 0.17, outputUsdPerMTok: 0.25 };

let sql: Sql;
let app: Hono<AuthorizationEnv>;
const calls: string[] = [];

const texts: string[] = [];
const assistant = {
  studySet: async (
    kind: "quiz" | "flashcards",
    _title: string,
    text: string,
  ) => {
    calls.push(kind);
    texts.push(text);
    const usage = { inputTokens: 300, outputTokens: 500, model: "stub" };
    return kind === "quiz"
      ? {
        kind,
        usage,
        questions: [{
          question: "Where is light captured?",
          options: ["Chloroplasts", "Roots", "Nucleus", "Stem"],
          answerIndex: 0,
          explanation: "In the chloroplasts.",
        }],
      }
      : { kind, usage, cards: [{ front: "Chlorophyll", back: "Pigment" }] };
  },
  lessonNotes: async (_title: string, text: string) => {
    calls.push("notes");
    texts.push(text);
    return {
      answer: "# Notes\n\n- Light makes food",
      usage: { inputTokens: 300, outputTokens: 200, model: "stub" },
    };
  },
} as unknown as StudyAssistant;

async function user(id: string, name: string): Promise<void> {
  await sql`
    insert into auth.users (
      id, email, encrypted_password, aud, role, email_confirmed_at,
      created_at, updated_at, instance_id, confirmation_token, recovery_token,
      email_change, email_change_token_new, email_change_token_current,
      phone_change_token, raw_app_meta_data, raw_user_meta_data
    ) values (
      ${id}::uuid, ${`notebook.${id.slice(-2)}@synthetic.studafy.test`},
      'synthetic-not-a-secret', 'authenticated', 'authenticated', now(), now(),
      now(), '00000000-0000-0000-0000-000000000000', '', '', '', '', '', '',
      '{}'::jsonb, ${JSON.stringify({ full_name: name })}::jsonb
    ) on conflict (id) do nothing`;
}

async function cleanup(): Promise<void> {
  await removeFixtures(sql, {
    schoolIds: [SCHOOL],
    userIds: [TEACHER, STUDENT, OUTSIDER],
  });
}

async function seed(): Promise<void> {
  await user(TEACHER, "Notebook Teacher");
  await user(STUDENT, "Notebook Student");
  await user(OUTSIDER, "Notebook Outsider");
  await sql`insert into public.schools (id, name, timezone, status)
    values (${SCHOOL}::uuid, 'Notebook School', 'Asia/Riyadh', 'active')`;
  await sql`
    insert into public.memberships (school_id, user_id, role, active, status, version) values
      (${SCHOOL}::uuid, ${TEACHER}::uuid, 'teacher', true, 'active', 1),
      (${SCHOOL}::uuid, ${STUDENT}::uuid, 'student', true, 'active', 1),
      (${SCHOOL}::uuid, ${OUTSIDER}::uuid, 'student', true, 'active', 1)`;
  await sql`insert into public.terms (id, school_id, name, starts_on, ends_on, active, status)
    values (${TERM}::uuid, ${SCHOOL}::uuid, 'Notebook Term', current_date - 10, current_date + 90, true, 'active')`;
  await sql`insert into public.classrooms (id, school_id, term_id, name, grade, section, teacher_id, status, version)
    values (${CLASSROOM}::uuid, ${SCHOOL}::uuid, ${TERM}::uuid, 'Biology', '8', 'A', ${TEACHER}::uuid, 'active', 1)`;
  await sql`
    insert into public.classroom_staff (school_id, classroom_id, membership_id, user_id, role)
    select ${SCHOOL}::uuid, ${CLASSROOM}::uuid, m.id, m.user_id, 'lead_teacher'
    from public.memberships m where m.school_id = ${SCHOOL}::uuid and m.user_id = ${TEACHER}::uuid`;
  await sql`
    insert into public.students (id, school_id, user_id, studafy_id, display_name, provisional, created_by) values
      (${STUDENT_ROW}::uuid, ${SCHOOL}::uuid, ${STUDENT}::uuid, 'STU-NB-1', 'Notebook Student', false, ${TEACHER}::uuid),
      (${OUTSIDER_ROW}::uuid, ${SCHOOL}::uuid, ${OUTSIDER}::uuid, 'STU-NB-3', 'Notebook Outsider', false, ${TEACHER}::uuid)`;
  await sql`
    insert into public.enrollments (classroom_id, student_id, school_id, status, active) values
      (${CLASSROOM}::uuid, ${STUDENT_ROW}::uuid, ${SCHOOL}::uuid, 'active', true)`;
  await sql`insert into public.resources (id, school_id, title, resource_type, state, current_version, created_by)
    values (${LESSON}::uuid, ${SCHOOL}::uuid, 'Photosynthesis', 'lesson_note', 'published', 1, ${TEACHER}::uuid)`;
  await sql`insert into public.resource_versions (id, school_id, resource_id, version, body, created_by)
    values (${LESSON_V1}::uuid, ${SCHOOL}::uuid, ${LESSON}::uuid, 1,
      'Photosynthesis turns light into chemical energy in the chloroplasts. Chlorophyll absorbs the light.',
      ${TEACHER}::uuid)`;
  await sql`insert into public.resource_publications (school_id, resource_version_id, classroom_id, audience, state, published_at, created_by)
    values (${SCHOOL}::uuid, ${LESSON_V1}::uuid, ${CLASSROOM}::uuid, 'both', 'published', now(), ${TEACHER}::uuid)`;
  // A second lesson in the class, and one in a class the student is not in.
  await sql`insert into public.classrooms (id, school_id, term_id, name, grade, section, teacher_id, status, version)
    values (${OTHER_CLASSROOM}::uuid, ${SCHOOL}::uuid, ${TERM}::uuid, 'Chemistry', '8', 'B', ${TEACHER}::uuid, 'active', 1)`;
  await sql`insert into public.resources (id, school_id, title, resource_type, state, current_version, created_by) values
    (${LESSON2}::uuid, ${SCHOOL}::uuid, 'Respiration', 'lesson_note', 'published', 1, ${TEACHER}::uuid),
    (${HIDDEN}::uuid, ${SCHOOL}::uuid, 'Acids', 'lesson_note', 'published', 1, ${TEACHER}::uuid)`;
  await sql`insert into public.resource_versions (id, school_id, resource_id, version, body, created_by) values
    (${LESSON2_V1}::uuid, ${SCHOOL}::uuid, ${LESSON2}::uuid, 1,
      'Respiration releases energy from glucose in the mitochondria of every cell.', ${TEACHER}::uuid),
    (${HIDDEN_V1}::uuid, ${SCHOOL}::uuid, ${HIDDEN}::uuid, 1,
      'Acids have a pH below seven and turn blue litmus paper red.', ${TEACHER}::uuid)`;
  await sql`insert into public.resource_publications (school_id, resource_version_id, classroom_id, audience, state, published_at, created_by) values
    (${SCHOOL}::uuid, ${LESSON2_V1}::uuid, ${CLASSROOM}::uuid, 'both', 'published', now(), ${TEACHER}::uuid),
    (${SCHOOL}::uuid, ${HIDDEN_V1}::uuid, ${OTHER_CLASSROOM}::uuid, 'both', 'published', now(), ${TEACHER}::uuid)`;
}

async function grant(userId: string, plan: "plus" | "max"): Promise<void> {
  await sql`delete from private.study_plan_grants where user_id = ${userId}::uuid`;
  await sql`insert into private.study_plan_grants (user_id, plan, reason, ends_at)
    values (${userId}::uuid, ${plan}, 'integration test', now() + interval '1 day')`;
}

async function request(
  path: string,
  subject: string,
  init: { method?: "GET" | "POST"; body?: unknown; key?: string } = {},
): Promise<Response> {
  const headers = new Headers({ "x-test-subject": subject });
  if (init.body !== undefined) headers.set("content-type", "application/json");
  if ((init.method ?? "GET") === "POST") {
    headers.set("idempotency-key", init.key ?? crypto.randomUUID());
  }
  return await app.request(path, {
    method: init.method ?? "GET",
    headers,
    ...(init.body !== undefined ? { body: JSON.stringify(init.body) } : {}),
  });
}

suite("Material chosen exactly, over real SQL", () => {
  beforeAll(async () => {
    sql = createDatabase(databaseUrl!);
    await cleanup();
    await seed();
    const contexts = new AuthContextRepository(sql);
    const logger = createJsonLogger(
      "api",
      "selection-it",
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
        aal2: false,
        mfaRequiredByPolicy: false,
      };
      c.set("requestId", crypto.randomUUID());
      c.set("actor", actor);
      await next();
    });
    app.route(
      "/",
      createSelectionRoutes(
        {
          material: new PostgresMaterialRepository(sql),
          outputs: new PostgresMaterialOutputRepository(sql),
          repository: new PostgresStudyRepository(sql),
          prices: PRICES,
          assistant,
          lessonToolsEnabled: true,
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

  const quiz = (subject: string, references: unknown[]) =>
    request("/v1/study-sets", subject, {
      method: "POST",
      body: { kind: "quiz", references },
    });

  test("a quiz from chosen material needs Studafy Max", async () => {
    await grant(STUDENT, "plus");
    const res = await quiz(STUDENT, [{ kind: "lesson", id: LESSON }]);
    expect(res.status).toBe(403);
    expect(calls).toEqual([]);
  });

  let quizId = "";

  test("only the chosen lesson is read, and the answer says so", async () => {
    await grant(STUDENT, "max");
    const res = await quiz(STUDENT, [{ kind: "lesson", id: LESSON }]);
    expect(res.status).toBe(201);
    const set = await res.json() as {
      id: string;
      scope: { lessons: { resourceId: string; includeText: boolean }[] };
    };
    quizId = set.id;
    expect(set.scope.lessons.map((l) => l.resourceId)).toEqual([LESSON]);
    expect(texts.at(-1)).toContain("chloroplasts");
    expect(texts.at(-1)).not.toContain("mitochondria");
  });

  test("the same choice again opens the same quiz, free", async () => {
    const before = calls.length;
    const tokens = await sql<{ n: string }[]>`
      select count(*)::text as n from private.ai_usage where user_id = ${STUDENT}::uuid`;
    const res = await quiz(STUDENT, [{ kind: "lesson", id: LESSON }]);
    expect(((await res.json()) as { id: string }).id).toBe(quizId);
    expect(calls.length).toBe(before);
    const after = await sql<{ n: string }[]>`
      select count(*)::text as n from private.ai_usage where user_id = ${STUDENT}::uuid`;
    expect(after[0]!.n).toBe(tokens[0]!.n);
  });

  test("adding a lesson changes what is read, and makes a new quiz", async () => {
    const res = await quiz(STUDENT, [
      { kind: "lesson", id: LESSON },
      { kind: "text", id: LESSON2 },
    ]);
    const set = await res.json() as { id: string };
    expect(set.id).not.toBe(quizId);
    expect(texts.at(-1)).toContain("chloroplasts");
    expect(texts.at(-1)).toContain("mitochondria");
  });

  test("a lesson the student cannot see is refused, never skipped", async () => {
    const before = calls.length;
    const res = await quiz(STUDENT, [
      { kind: "lesson", id: LESSON },
      { kind: "lesson", id: HIDDEN },
    ]);
    expect(res.status).toBe(404);
    expect(calls.length).toBe(before);
  });

  test("notes from chosen material say what they were made from", async () => {
    const res = await request(
      `/v1/classrooms/${CLASSROOM}/notebook/summary`,
      STUDENT,
      {
        method: "POST",
        body: { references: [{ kind: "text", id: LESSON2 }] },
      },
    );
    expect(res.status).toBe(201);
    const entry = await res.json() as { body: string; source: string };
    expect(entry.source).toBe("lesson");
    expect(entry.body).toContain("**Made from:** Respiration (lesson text)");
    expect(texts.at(-1)).toContain("mitochondria");
    expect(texts.at(-1)).not.toContain("chloroplasts");
  });

  test("notes for one class's notebook come from that class only", async () => {
    await sql`insert into public.enrollments (classroom_id, student_id, school_id, status, active)
      values (${OTHER_CLASSROOM}::uuid, ${STUDENT_ROW}::uuid, ${SCHOOL}::uuid, 'active', true)`;
    const res = await request(
      `/v1/classrooms/${CLASSROOM}/notebook/summary`,
      STUDENT,
      {
        method: "POST",
        body: { references: [{ kind: "lesson", id: HIDDEN }] },
      },
    );
    expect(res.status).toBe(400);
  });
});
