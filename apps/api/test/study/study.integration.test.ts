/**
 * Studafy Plus / Max, the Notebook and the AI cost caps, over real SQL.
 *
 * The provider and object storage are stand-ins, so the tests are free and
 * repeatable; everything else - the routes, permission middleware,
 * idempotency, the plan lookup, the cost ledger and its caps - is the real
 * thing. The caps are the owner's hard rule (Plus never over $0.80, Max never
 * over $1.60 per student per month), so they are tested at the edge.
 */
import { afterAll, beforeAll, describe, expect, test } from "bun:test";
import { Hono } from "hono";
import { testAssurance } from "../support/assurance";
import type { LogLevel } from "@studafy/contracts";
import { createDatabase, type Sql } from "@studafy/database";
import { createJsonLogger } from "@studafy/observability";
import type { StudyAssistant } from "@studafy/infrastructure";
import { AuthContextRepository } from "../../src/auth/context";
import { withRequestContext } from "../../src/platform/dbContext";
import type { Actor } from "../../src/auth/middleware";
import type { AuthorizationEnv } from "../../src/authorization/middleware";
import { createAuthorizationDependencies } from "../../src/authorization/middleware";
import { PostgresAuthorizationRepository } from "../../src/authorization/repository";
import { PostgresIdempotencyRepository } from "../../src/platform/idempotency";
import { PostgresStudyRepository } from "../../src/study/repository";
import { createStudyRoutes } from "../../src/study/routes";
import { PostgresMaterialRepository } from "../../src/study/material";
import { costMicroUsd, holdFor, OUTPUT_TOKENS } from "../../src/study/metering";
import { createStudyAssistantRoutes } from "../../src/study-assistant/routes";
import { sha256Hex } from "@studafy/infrastructure";
import { integrationSuite, removeFixtures } from "@studafy/test-support";
import { PostgresAiAccessRepository } from "../../src/study/aiAccess";
import { consentToAi } from "../support/aiAccess";

const databaseUrl = process.env["DATABASE_URL"];
const suite = integrationSuite(describe);

const P = "f0b10000-0000-4000-8000-0000000000";
const SCHOOL = `${P}01`;
const TERM = `${P}02`;
const CLASSROOM = `${P}03`;
const OTHER_CLASSROOM = `${P}04`;
const TEACHER = `${P}11`;
const STUDENT = `${P}12`;
const CLASSMATE = `${P}13`;
const OUTSIDER = `${P}14`;
const STUDENT_ROW = `${P}21`;
const CLASSMATE_ROW = `${P}22`;
const OUTSIDER_ROW = `${P}23`;
const LESSON = `${P}31`;
const LESSON_V1 = `${P}32`;
const PHOTO = `${P}41`;

const PRICES = { inputUsdPerMTok: 0.17, outputUsdPerMTok: 0.25 };
const PHOTO_BYTES = new TextEncoder().encode(
  "a whiteboard, as far as the test knows",
);

let sql: Sql;
let app: Hono<AuthorizationEnv>;
const calls: string[] = [];

/** The provider, reporting fixed token counts so costs are exact. */
const assistant: StudyAssistant = {
  ask: async () => {
    calls.push("ask");
    return {
      answer: "An answer.",
      usage: { inputTokens: 200, outputTokens: 100, model: "Qwen/Qwen3.5-9B" },
    };
  },
  transcribe: async () => {
    calls.push("transcribe");
    return { answer: "A page." };
  },
  whiteboardNotes: async () => {
    calls.push("whiteboard");
    return {
      answer: "# Photosynthesis\n\n- Happens in chloroplasts",
      usage: { inputTokens: 700, outputTokens: 90, model: "stub" },
    };
  },
  lessonNotes: async () => {
    calls.push("lessonNotes");
    return {
      answer: "# Cells\n\n- The cell is the unit of life",
      usage: { inputTokens: 500, outputTokens: 200, model: "stub" },
    };
  },
  notebook: async () => {
    calls.push("notebook");
    throw new Error("not used here");
  },
  markAnswer: async () => {
    calls.push("markAnswer");
    throw new Error("not used here");
  },
  studySet: async (kind) => {
    calls.push(kind);
    const usage = { inputTokens: 280, outputTokens: 600, model: "stub" };
    return kind === "quiz"
      ? {
        kind,
        usage,
        questions: [{
          question: "Where does photosynthesis happen?",
          options: ["Chloroplasts", "Roots", "Nucleus", "Stem"],
          answerIndex: 0,
          explanation: "In the chloroplasts.",
        }],
      }
      : {
        kind,
        usage,
        cards: [{ front: "Chlorophyll", back: "Green pigment" }],
      };
  },
};

async function user(id: string, name: string): Promise<void> {
  await sql`
    insert into auth.users (
      id, email, encrypted_password, aud, role, email_confirmed_at,
      created_at, updated_at, instance_id, confirmation_token, recovery_token,
      email_change, email_change_token_new, email_change_token_current,
      phone_change_token, raw_app_meta_data, raw_user_meta_data
    ) values (
      ${id}::uuid, ${`study.${id.slice(-2)}@synthetic.studafy.test`},
      'synthetic-not-a-secret', 'authenticated', 'authenticated', now(), now(),
      now(), '00000000-0000-0000-0000-000000000000', '', '', '', '', '', '',
      '{}'::jsonb, ${JSON.stringify({ full_name: name })}::jsonb
    ) on conflict (id) do nothing`;
}

async function cleanup(): Promise<void> {
  await removeFixtures(sql, {
    schoolIds: [SCHOOL],
    userIds: [TEACHER, STUDENT, CLASSMATE, OUTSIDER],
  });
}

async function seed(): Promise<void> {
  await user(TEACHER, "Study Teacher");
  await user(STUDENT, "Study Student");
  await user(CLASSMATE, "Study Classmate");
  await user(OUTSIDER, "Study Outsider");
  await sql`insert into public.schools (id, name, timezone, status)
    values (${SCHOOL}::uuid, 'Study School', 'Asia/Riyadh', 'active')`;
  await sql`
    insert into public.memberships (school_id, user_id, role, active, status, version) values
      (${SCHOOL}::uuid, ${TEACHER}::uuid, 'teacher', true, 'active', 1),
      (${SCHOOL}::uuid, ${STUDENT}::uuid, 'student', true, 'active', 1),
      (${SCHOOL}::uuid, ${CLASSMATE}::uuid, 'student', true, 'active', 1),
      (${SCHOOL}::uuid, ${OUTSIDER}::uuid, 'student', true, 'active', 1)`;
  await sql`insert into public.terms (id, school_id, name, starts_on, ends_on, active, status)
    values (${TERM}::uuid, ${SCHOOL}::uuid, 'Study Term', current_date - 10, current_date + 90, true, 'active')`;
  await sql`insert into public.classrooms (id, school_id, term_id, name, grade, section, teacher_id, status, version)
    values (${CLASSROOM}::uuid, ${SCHOOL}::uuid, ${TERM}::uuid, 'Biology', '8', 'A', ${TEACHER}::uuid, 'active', 1)`;
  await sql`
    insert into public.classroom_staff (school_id, classroom_id, membership_id, user_id, role)
    select ${SCHOOL}::uuid, ${CLASSROOM}::uuid, m.id, m.user_id, 'lead_teacher'
    from public.memberships m where m.school_id = ${SCHOOL}::uuid and m.user_id = ${TEACHER}::uuid`;
  await sql`
    insert into public.students (id, school_id, user_id, studafy_id, display_name, provisional, created_by) values
      (${STUDENT_ROW}::uuid, ${SCHOOL}::uuid, ${STUDENT}::uuid, 'STU-STUDY-1', 'Study Student', false, ${TEACHER}::uuid),
      (${CLASSMATE_ROW}::uuid, ${SCHOOL}::uuid, ${CLASSMATE}::uuid, 'STU-STUDY-2', 'Study Classmate', false, ${TEACHER}::uuid),
      (${OUTSIDER_ROW}::uuid, ${SCHOOL}::uuid, ${OUTSIDER}::uuid, 'STU-STUDY-3', 'Study Outsider', false, ${TEACHER}::uuid)`;
  // The outsider is a student of the school, but not of this class.
  await sql`
    insert into public.enrollments (classroom_id, student_id, school_id, status, active) values
      (${CLASSROOM}::uuid, ${STUDENT_ROW}::uuid, ${SCHOOL}::uuid, 'active', true),
      (${CLASSROOM}::uuid, ${CLASSMATE_ROW}::uuid, ${SCHOOL}::uuid, 'active', true)`;
  // The outsider is in another class of the school: a student who may use
  // the AI tools (ADR-0043), just not this class's lessons.
  await sql`insert into public.classrooms (id, school_id, term_id, name, grade, section, teacher_id, status, version)
    values (${OTHER_CLASSROOM}::uuid, ${SCHOOL}::uuid, ${TERM}::uuid, 'Chemistry', '8', 'B', ${TEACHER}::uuid, 'active', 1)`;
  await sql`
    insert into public.enrollments (classroom_id, student_id, school_id, status, active) values
      (${OTHER_CLASSROOM}::uuid, ${OUTSIDER_ROW}::uuid, ${SCHOOL}::uuid, 'active', true)`;
  // Every student has agreed to the AI notice (ADR-0043).
  await consentToAi(sql, [STUDENT, CLASSMATE, OUTSIDER]);

  // A published text lesson.
  await sql`insert into public.resources (id, school_id, title, resource_type, state, current_version, created_by)
    values (${LESSON}::uuid, ${SCHOOL}::uuid, 'Photosynthesis', 'lesson_note', 'published', 1, ${TEACHER}::uuid)`;
  await sql`insert into public.resource_versions (id, school_id, resource_id, version, body, created_by)
    values (${LESSON_V1}::uuid, ${SCHOOL}::uuid, ${LESSON}::uuid, 1,
      'Photosynthesis turns light into chemical energy in the chloroplasts. Chlorophyll absorbs the light.',
      ${TEACHER}::uuid)`;
  await sql`insert into public.resource_publications (school_id, resource_version_id, classroom_id, audience, state, published_at, created_by)
    values (${SCHOOL}::uuid, ${LESSON_V1}::uuid, ${CLASSROOM}::uuid, 'both', 'published', now(), ${TEACHER}::uuid)`;

  // A whiteboard photo the student uploaded for this class, already cleared.
  const hash = await sha256Hex(PHOTO_BYTES);
  const membership = (await sql<{ id: string }[]>`
    select id from public.memberships where school_id = ${SCHOOL}::uuid and user_id = ${STUDENT}::uuid`)[
    0
  ]!.id;
  await sql`
    insert into public.file_objects(
      id, school_id, bucket, object_key, uploader_id, owner_id, owner_membership_id,
      purpose, display_name, size_bytes, sha256, declared_media_type,
      detected_media_type, scan_state, policy_version, scanned_at,
      scan_policy_version, stored_sha256, stored_size_bytes)
    values (${PHOTO}::uuid, ${SCHOOL}::uuid, 'private-school-files',
      ${
    "quarantine/v1/" + PHOTO + "/" + PHOTO.replaceAll("-", "")
  }, ${STUDENT}::uuid, ${STUDENT}::uuid,
      ${membership}::uuid, 'notebook_photo', 'board.jpg', ${PHOTO_BYTES.length},
      ${hash}, 'image/jpeg', 'image/jpeg', 'clean', 'notebook-photo-v1', now(),
      'test', ${hash}, ${PHOTO_BYTES.length})`;
  const session = crypto.randomUUID();
  await sql`
    insert into public.upload_sessions(id, school_id, uploader_id, owner_id, purpose,
      expected_size_bytes, allowed_media_types, nonce_hash, expires_at, classroom_id)
    values (${session}::uuid, ${SCHOOL}::uuid, ${STUDENT}::uuid, ${STUDENT}::uuid,
      'notebook_photo', ${PHOTO_BYTES.length}, array['image/jpeg'],
      ${crypto.randomUUID()}, now() + interval '1 hour', ${CLASSROOM}::uuid)`;
  await sql`insert into public.file_bindings(school_id, file_object_id, upload_session_id)
    values (${SCHOOL}::uuid, ${PHOTO}::uuid, ${session}::uuid)`;
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

async function spent(userId: string): Promise<number> {
  const rows = await sql<{ total: string }[]>`
    select coalesce(sum(cost_micro_usd), 0)::text as total from private.ai_usage
    where user_id = ${userId}::uuid and status = 'settled'`;
  return Number(rows[0]!.total);
}

suite("Studafy Plus / Max over real SQL", () => {
  beforeAll(async () => {
    sql = createDatabase(databaseUrl!);
    await cleanup();
    await seed();
    const contexts = new AuthContextRepository(sql);
    const logger = createJsonLogger(
      "api",
      "study-it",
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
    const repository = new PostgresStudyRepository(sql);
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
      createStudyAssistantRoutes(
        {
          assistant,
          aiAccess: new PostgresAiAccessRepository(sql),
          repository,
          prices: PRICES,
          chatMemory: {
            contextWindowTokens: 262_144,
            freeTokens: 4_000,
            paidTokens: 32_000,
          },
        },
        authorization,
      ),
    );
    app.route(
      "/",
      createStudyRoutes(
        {
          aiAccess: new PostgresAiAccessRepository(sql),
          repository,
          prices: PRICES,
          assistant,
          lessonToolsEnabled: true,
          storage: {
            openObject: async () => ({ bytes: PHOTO_BYTES }),
          } as never,
          // The lesson's material, read through the real SQL (ADR-0037).
          material: new PostgresMaterialRepository(sql),
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

  // -------------------------------------------------------------------------
  // Free.
  // -------------------------------------------------------------------------
  test("lessons are free: a student with no plan reads the class's lessons", async () => {
    const result = await withRequestContext(
      sql,
      { subject: STUDENT, schoolId: SCHOOL, requestId: crypto.randomUUID() },
      async (tx) =>
        (await tx<{ r: Record<string, unknown> }[]>`
          select private.api041_query('listResources', null,
            ${tx.json({ classroomId: CLASSROOM } as never)}) as r`)[0]!.r,
    );
    expect(result["outcome"]).toBeUndefined();
    expect((result["items"] as unknown[]).length).toBe(1);
  });

  test("a new student is on the free plan", async () => {
    const res = await request("/v1/me/study-plan", STUDENT);
    expect(res.status).toBe(200);
    const body = await res.json() as {
      plan: string;
      features: string[];
      allowance: Record<string, unknown>;
    };
    expect(body.plan).toBe("free");
    expect(body.features).toEqual(["ask"]);
    expect(body.allowance).toMatchObject({
      period: "week",
      total: 40_000,
      used: 0,
      remaining: 40_000,
    });
    // Free resets every Monday, 00:00 UTC.
    const resets = new Date(String(body.allowance["resetsAt"]));
    expect(resets.getUTCDay()).toBe(1);
    expect(resets.getUTCHours()).toBe(0);
  });

  test("a typed note goes in that class's notebook, dated", async () => {
    const create = await request(
      `/v1/classrooms/${CLASSROOM}/notebook`,
      STUDENT,
      {
        method: "POST",
        body: {
          title: "Revision",
          body: "Leaves are green because of chlorophyll.",
        },
      },
    );
    expect(create.status).toBe(201);
    const entry = await create.json() as { source: string; createdAt: string };
    expect(entry.source).toBe("typed");
    expect(Date.parse(entry.createdAt)).toBeGreaterThan(0);

    const list = await request(`/v1/classrooms/${CLASSROOM}/notebook`, STUDENT);
    expect(list.status).toBe(200);
    expect(((await list.json()) as { items: unknown[] }).items).toHaveLength(1);
  });

  test("nobody else reads a student's notebook", async () => {
    // A classmate sees their own (empty) notebook, never the student's.
    const classmate = await request(
      `/v1/classrooms/${CLASSROOM}/notebook`,
      CLASSMATE,
    );
    expect(((await classmate.json()) as { items: unknown[] }).items)
      .toHaveLength(0);
    // Someone not in the class has no notebook for it at all.
    expect(
      (await request(`/v1/classrooms/${CLASSROOM}/notebook`, OUTSIDER)).status,
    )
      .toBe(404);
    // Nor the teacher: the notebook is the student's.
    expect(
      (await request(`/v1/classrooms/${CLASSROOM}/notebook`, TEACHER)).status,
    )
      .toBe(404);
  });

  test("a free question is charged the tokens the provider reported", async () => {
    await sql`delete from private.ai_usage where user_id = ${CLASSMATE}::uuid`;
    const res = await request("/v1/study-assistant/ask", CLASSMATE, {
      method: "POST",
      body: { question: "What is a cell?" },
    });
    expect(res.status).toBe(200);
    const body = await res.json() as {
      allowance: { used: number; remaining: number };
    };
    // 200 in + 100 out, the reference model's tokens counting one each.
    expect(body.allowance.used).toBe(300);
    expect(body.allowance.remaining).toBe(40_000 - 300);
  });

  test("when the week's tokens are used, the question costs nothing", async () => {
    await sql`
      insert into private.ai_usage (user_id, feature, plan, month, status,
        reserved_micro_usd, cost_micro_usd, metered_tokens, settled_at)
      values (${CLASSMATE}::uuid, 'ask', 'free',
        date_trunc('month', now() at time zone 'utc')::date, 'settled',
        0, 0, 39_000, now())`;
    const before = calls.length;
    const res = await request("/v1/study-assistant/ask", CLASSMATE, {
      method: "POST",
      body: { question: "One more question?" },
    });
    expect(res.status).toBe(429);
    expect(((await res.json()) as { code: string }).code).toBe(
      "AI_ALLOWANCE_USED",
    );
    expect(calls.length).toBe(before);
  });

  test("last week's tokens do not count this week", async () => {
    await sql`delete from private.ai_usage where user_id = ${CLASSMATE}::uuid`;
    await sql`
      insert into private.ai_usage (user_id, feature, plan, month, status,
        reserved_micro_usd, cost_micro_usd, metered_tokens, created_at, settled_at)
      values (${CLASSMATE}::uuid, 'ask', 'free',
        date_trunc('month', now() at time zone 'utc')::date, 'settled',
        0, 0, 40_000, private.ai_period_start('week') - interval '1 second',
        now())`;
    const plan = await request("/v1/me/study-plan", CLASSMATE);
    expect(
      ((await plan.json()) as { allowance: { used: number } }).allowance.used,
    )
      .toBe(0);
  });

  test("whiteboard notes need Studafy Plus", async () => {
    const before = calls.length;
    const res = await request(
      `/v1/classrooms/${CLASSROOM}/notebook/whiteboard`,
      STUDENT,
      {
        method: "POST",
        body: { photoFileId: PHOTO },
      },
    );
    expect(res.status).toBe(403);
    expect(((await res.json()) as { code: string }).code).toBe("PLAN_REQUIRED");
    // Refused before the provider was called: nothing was spent.
    expect(calls.length).toBe(before);
  });

  // -------------------------------------------------------------------------
  // Plus.
  // -------------------------------------------------------------------------
  test("on Plus, a whiteboard photo becomes notes, charged at its real cost", async () => {
    await grant(STUDENT, "plus");
    const res = await request(
      `/v1/classrooms/${CLASSROOM}/notebook/whiteboard`,
      STUDENT,
      {
        method: "POST",
        body: { photoFileId: PHOTO },
      },
    );
    expect(res.status).toBe(201);
    const entry = await res.json() as {
      title: string;
      source: string;
      photo: { id: string } | null;
    };
    expect(entry.source).toBe("whiteboard");
    expect(entry.title).toBe("Photosynthesis");
    expect(entry.photo?.id).toBe(PHOTO);
    // Exactly the provider's tokens at the model's prices - not the hold.
    expect(await spent(STUDENT)).toBe(costMicroUsd(PRICES, 700, 90));
  });

  test("Plus does not include quizzes", async () => {
    const res = await request(`/v1/resources/${LESSON}/study-set`, STUDENT, {
      method: "POST",
      body: { kind: "quiz" },
    });
    expect(res.status).toBe(403);
    expect(((await res.json()) as { code: string }).code).toBe("PLAN_REQUIRED");
  });

  // -------------------------------------------------------------------------
  // Max.
  // -------------------------------------------------------------------------
  let quizId = "";

  test("on Max, a lesson becomes a quiz", async () => {
    await grant(STUDENT, "max");
    const res = await request(`/v1/resources/${LESSON}/study-set`, STUDENT, {
      method: "POST",
      body: { kind: "quiz" },
    });
    expect(res.status).toBe(201);
    const set = await res.json() as {
      id: string;
      kind: string;
      questions: unknown[] | null;
      cards: unknown[] | null;
    };
    expect(set.kind).toBe("quiz");
    expect(set.questions).toHaveLength(1);
    expect(set.cards).toBeNull();
    quizId = set.id;
  });

  test("a classmate on Max gets the same quiz without a second charge", async () => {
    await grant(CLASSMATE, "max");
    const before = calls.length;
    const spentBefore = await spent(CLASSMATE);
    const res = await request(`/v1/resources/${LESSON}/study-set`, CLASSMATE, {
      method: "POST",
      body: { kind: "quiz" },
    });
    expect(res.status).toBe(201);
    expect(((await res.json()) as { id: string }).id).toBe(quizId);
    expect(calls.length).toBe(before);
    expect(await spent(CLASSMATE)).toBe(spentBefore);
  });

  test("a student not in the class cannot use its lesson", async () => {
    await grant(OUTSIDER, "max");
    const res = await request(`/v1/resources/${LESSON}/study-set`, OUTSIDER, {
      method: "POST",
      body: { kind: "flashcards" },
    });
    expect(res.status).toBe(404);
  });

  // -------------------------------------------------------------------------
  // The caps.
  // -------------------------------------------------------------------------
  test("at the Max cap, the next generation is refused before the provider is called", async () => {
    // Bring the student to just under $1.60, less than one call's hold away.
    const month = new Date();
    await sql`
      insert into private.ai_usage (user_id, feature, plan, month, status,
        reserved_micro_usd, cost_micro_usd, settled_at)
      values (${STUDENT}::uuid, 'quiz', 'max',
        date_trunc('month', now() at time zone 'utc')::date, 'settled',
        0, ${1_600_000 - (await spent(STUDENT)) - 50}, now())`;
    void month;
    const before = calls.length;
    const res = await request(`/v1/resources/${LESSON}/study-set`, STUDENT, {
      method: "POST",
      body: { kind: "flashcards" },
    });
    expect(res.status).toBe(429);
    expect(((await res.json()) as { code: string }).code).toBe(
      "AI_ALLOWANCE_USED",
    );
    expect(calls.length).toBe(before);
    // Never over the cap.
    expect(await spent(STUDENT)).toBeLessThanOrEqual(1_600_000);

    // The dollar cap is the backstop under the tokens: it held even though
    // this student's token count was nowhere near 6,000,000.
  });

  test("two requests at once cannot both slip under the allowance", async () => {
    // Room for exactly one whiteboard hold on Plus.
    await grant(CLASSMATE, "plus");
    await sql`delete from private.ai_usage where user_id = ${CLASSMATE}::uuid`;
    const hold = holdFor(PRICES, 0, OUTPUT_TOKENS.long, 1);
    await sql`
      insert into private.ai_usage (user_id, feature, plan, month, status,
        reserved_micro_usd, cost_micro_usd, metered_tokens, settled_at)
      values (${CLASSMATE}::uuid, 'whiteboard', 'plus',
        date_trunc('month', now() at time zone 'utc')::date, 'settled',
        0, 0, ${3_000_000 - hold.tokens - Math.floor(hold.tokens / 2)}, now())`;
    const repository = new PostgresStudyRepository(sql);
    const outcomes = await Promise.all([1, 2, 3].map(() =>
      repository.usage(
        {
          subject: CLASSMATE,
          schoolId: null,
          requestId: crypto.randomUUID(),
          aal2: false,
        },
        "reserve",
        {
          feature: "whiteboard",
          estimateMicroUsd: hold.microUsd,
          estimateTokens: hold.tokens,
        },
      )
    ));
    expect(outcomes.filter((o) => o["outcome"] === "ok")).toHaveLength(1);
    expect(
      outcomes.filter((o) => o["outcome"] === "allowance_exhausted"),
    ).toHaveLength(2);
  });

  test("a teacher cannot use the AI study tools (ADR-0043)", async () => {
    const before = calls.length;
    const res = await request("/v1/study-assistant/ask", TEACHER, {
      method: "POST",
      body: { question: "What is photosynthesis?" },
    });
    expect(res.status).toBe(403);
    expect((await res.json() as { code: string }).code).toBe(
      "AI_STUDENTS_ONLY",
    );
    expect(calls.length).toBe(before);
    const plan = await request("/v1/me/study-plan", TEACHER);
    expect(await plan.json()).toMatchObject({
      aiAccess: "not_student",
      available: [],
    });
  });

  test("a retried request is answered again, never charged twice", async () => {
    await sql`delete from private.ai_usage where user_id = ${OUTSIDER}::uuid`;
    const repository = new PostgresStudyRepository(sql);
    const context = {
      subject: OUTSIDER,
      schoolId: null,
      requestId: crypto.randomUUID(),
      aal2: false,
    };
    const reserve = () =>
      repository.usage(context, "reserve", {
        feature: "ask",
        estimateMicroUsd: 500,
        estimateTokens: 2_000,
        requestKey: "ask:retry-test",
      });
    const first = await reserve();
    expect(first["outcome"]).toBe("ok");
    // Still running: the same request again is refused, not run twice.
    expect((await reserve())["outcome"]).toBe("in_progress");
    await repository.usage(context, "settle", {
      usageId: first["usageId"],
      costMicroUsd: 100,
      inputTokens: 400,
      outputTokens: 100,
      model: "Qwen/Qwen3.5-9B",
    });
    // Answered already: once more, free.
    const replay = await reserve();
    expect(replay).toMatchObject({ outcome: "ok", replay: true });
    const settled = await repository.usage(context, "settle", {
      usageId: replay["usageId"],
      costMicroUsd: 100,
      inputTokens: 400,
      outputTokens: 100,
      model: "Qwen/Qwen3.5-9B",
    });
    expect(settled["meteredTokens"]).toBe(0);
    expect((await reserve())["outcome"]).toBe("duplicate");
    const summary = await repository.usage(context, "summary", {});
    expect((summary["allowance"] as { used: number }).used).toBe(500);
  });

  test("a model that costs more counts more", async () => {
    await sql`delete from private.ai_usage where user_id = ${OUTSIDER}::uuid`;
    const repository = new PostgresStudyRepository(sql);
    const context = {
      subject: OUTSIDER,
      schoolId: null,
      requestId: crypto.randomUUID(),
      aal2: false,
    };
    const reserved = await repository.usage(context, "reserve", {
      feature: "ask",
      estimateMicroUsd: 500,
      estimateTokens: 2_000,
    });
    const settled = await repository.usage(context, "settle", {
      usageId: reserved["usageId"],
      costMicroUsd: 100,
      inputTokens: 400,
      outputTokens: 100,
      // Not in private.ai_model_rates: counted at twice the reference.
      model: "someone/else",
    });
    expect(settled["meteredTokens"]).toBe(1_000);
  });

  test("upgrading mid-month gives the bigger allowance, minus what was used", async () => {
    await sql`delete from private.ai_usage where user_id = ${OUTSIDER}::uuid`;
    await sql`delete from private.study_plan_grants where user_id = ${OUTSIDER}::uuid`;
    await sql`
      insert into private.ai_usage (user_id, feature, plan, month, status,
        reserved_micro_usd, cost_micro_usd, metered_tokens, settled_at)
      values (${OUTSIDER}::uuid, 'ask', 'free',
        date_trunc('month', now() at time zone 'utc')::date, 'settled',
        0, 0, 12_000, now())`;
    await grant(OUTSIDER, "plus");
    const plan = await request("/v1/me/study-plan", OUTSIDER);
    const body = await plan.json() as {
      plan: string;
      allowance: Record<string, unknown>;
    };
    expect(body.plan).toBe("plus");
    expect(body.allowance).toMatchObject({
      period: "month",
      total: 3_000_000,
      used: 12_000,
      remaining: 2_988_000,
    });
  });

  test("a hold for a call that failed is released, and costs nothing", async () => {
    await sql`delete from private.ai_usage where user_id = ${OUTSIDER}::uuid`;
    const repository = new PostgresStudyRepository(sql);
    const context = {
      subject: OUTSIDER,
      schoolId: null,
      requestId: crypto.randomUUID(),
      aal2: false,
    };
    await sql`delete from private.study_plan_grants where user_id = ${OUTSIDER}::uuid`;
    const reserved = await repository.usage(context, "reserve", {
      feature: "ask",
      estimateMicroUsd: 500,
      estimateTokens: 2_000,
    });
    expect(reserved["outcome"]).toBe("ok");
    await repository.usage(context, "release", {
      usageId: reserved["usageId"],
    });
    const summary = await repository.usage(context, "summary", {});
    expect(summary["committedMicroUsd"]).toBe(0);
    expect((summary["allowance"] as { used: number }).used).toBe(0);
  });
});
