/**
 * The AI study tools over real SQL (ADR-0043): students in a class only,
 * after an AI consent the student gives - or, for a managed child account,
 * the parent - and withdraws; and no known name in what the provider gets.
 *
 * The provider is a stand-in that records what it was sent; everything
 * else - routes, permission middleware, the AI gate, idempotency, the
 * consent records and the ledger - is the real thing.
 */
import { afterAll, beforeAll, describe, expect, test } from "bun:test";
import { Hono } from "hono";
import type { LogLevel } from "@studafy/contracts";
import { createDatabase, type Sql } from "@studafy/database";
import { createJsonLogger } from "@studafy/observability";
import type { StudyAssistant } from "@studafy/infrastructure";
import { integrationSuite, removeFixtures } from "@studafy/test-support";
import { AuthContextRepository } from "../../src/auth/context";
import type { Actor } from "../../src/auth/middleware";
import type { AuthorizationEnv } from "../../src/authorization/middleware";
import { createAuthorizationDependencies } from "../../src/authorization/middleware";
import { PostgresAuthorizationRepository } from "../../src/authorization/repository";
import { PostgresIdempotencyRepository } from "../../src/platform/idempotency";
import { PostgresStudyRepository } from "../../src/study/repository";
import { createStudyRoutes } from "../../src/study/routes";
import { createStudyAssistantRoutes } from "../../src/study-assistant/routes";
import { PostgresAiAccessRepository } from "../../src/study/aiAccess";
import { createAiConsentRoutes } from "../../src/study/aiConsentRoutes";
import { testAssurance } from "../support/assurance";

const databaseUrl = process.env["DATABASE_URL"];
const suite = integrationSuite(describe);

const P = "a1c00000-0000-4000-8000-0000000000";
const SCHOOL = `${P}01`;
const TERM = `${P}02`;
const CLASSROOM = `${P}03`;
const TEACHER = `${P}11`;
const STUDENT = `${P}12`;
const CLASSMATE = `${P}13`;
const PARENT = `${P}14`;
const LONER = `${P}15`;
const CHILD = `${P}16`;
const STUDENT_ROW = `${P}21`;
const CLASSMATE_ROW = `${P}22`;
const CHILD_ROW = `${P}23`;
const VERSION = "2026-10-25";

let sql: Sql;
let app: Hono<AuthorizationEnv>;
const asked: string[] = [];

const assistant = {
  ask: async (question: string) => {
    asked.push(question);
    return {
      answer: "An answer.",
      usage: { inputTokens: 100, outputTokens: 50, model: "stub" },
    };
  },
} as unknown as StudyAssistant;

async function user(id: string, name: string, appMeta = {}): Promise<void> {
  await sql`
    insert into auth.users (
      id, email, encrypted_password, aud, role, email_confirmed_at,
      created_at, updated_at, instance_id, confirmation_token, recovery_token,
      email_change, email_change_token_new, email_change_token_current,
      phone_change_token, raw_app_meta_data, raw_user_meta_data
    ) values (
      ${id}::uuid, ${`aiconsent.${id.slice(-2)}@synthetic.studafy.test`},
      'synthetic-not-a-secret', 'authenticated', 'authenticated', now(), now(),
      now(), '00000000-0000-0000-0000-000000000000', '', '', '', '', '', '',
      ${JSON.stringify(appMeta)}::jsonb, ${
    JSON.stringify({ full_name: name })
  }::jsonb
    ) on conflict (id) do nothing`;
  // The name the person gave at setup, as teachers and classmates see it.
  await sql`update public.profiles set display_name = ${name} where id = ${id}::uuid`;
}

async function cleanup(): Promise<void> {
  await removeFixtures(sql, {
    schoolIds: [SCHOOL],
    userIds: [TEACHER, STUDENT, CLASSMATE, PARENT, LONER, CHILD],
  });
}

async function seed(): Promise<void> {
  await user(TEACHER, "Grace Hopper");
  await user(STUDENT, "Sara Haddad");
  await user(CLASSMATE, "Yousef Khatib");
  await user(PARENT, "Omar Haddad");
  await user(LONER, "Lone Student");
  await user(CHILD, "Layla", { studafy_managed_by: PARENT });
  await sql`update public.profiles set account_kind = 'student' where id = ${LONER}::uuid`;
  await sql`insert into public.schools (id, name, timezone, status)
    values (${SCHOOL}::uuid, 'Consent School', 'Asia/Riyadh', 'active')`;
  await sql`
    insert into public.memberships (school_id, user_id, role, active, status, version) values
      (${SCHOOL}::uuid, ${TEACHER}::uuid, 'teacher', true, 'active', 1),
      (${SCHOOL}::uuid, ${STUDENT}::uuid, 'student', true, 'active', 1),
      (${SCHOOL}::uuid, ${CLASSMATE}::uuid, 'student', true, 'active', 1)`;
  await sql`insert into public.terms (id, school_id, name, starts_on, ends_on, active, status)
    values (${TERM}::uuid, ${SCHOOL}::uuid, 'Term', current_date - 10, current_date + 90, true, 'active')`;
  await sql`insert into public.classrooms (id, school_id, term_id, name, grade, section, teacher_id, status, version)
    values (${CLASSROOM}::uuid, ${SCHOOL}::uuid, ${TERM}::uuid, 'Biology', '8', 'A', ${TEACHER}::uuid, 'active', 1)`;
  await sql`
    insert into public.classroom_staff (school_id, classroom_id, membership_id, user_id, role)
    select ${SCHOOL}::uuid, ${CLASSROOM}::uuid, m.id, m.user_id, 'lead_teacher'
    from public.memberships m where m.school_id = ${SCHOOL}::uuid and m.user_id = ${TEACHER}::uuid`;
  await sql`insert into private.managed_accounts (child_id, guardian_id)
    values (${CHILD}::uuid, ${PARENT}::uuid)`;
  await sql`
    insert into public.students (id, school_id, user_id, studafy_id, display_name, provisional, created_by) values
      (${STUDENT_ROW}::uuid, ${SCHOOL}::uuid, ${STUDENT}::uuid, 'STU-AIC-1', 'Sara Haddad', false, ${TEACHER}::uuid),
      (${CLASSMATE_ROW}::uuid, ${SCHOOL}::uuid, ${CLASSMATE}::uuid, 'STU-AIC-2', 'Yousef Khatib', false, ${TEACHER}::uuid),
      (${CHILD_ROW}::uuid, ${SCHOOL}::uuid, ${CHILD}::uuid, 'STU-AIC-3', 'Layla Haddad', false, ${TEACHER}::uuid)`;
  await sql`
    insert into public.enrollments (classroom_id, student_id, school_id, status, active) values
      (${CLASSROOM}::uuid, ${STUDENT_ROW}::uuid, ${SCHOOL}::uuid, 'active', true),
      (${CLASSROOM}::uuid, ${CLASSMATE_ROW}::uuid, ${SCHOOL}::uuid, 'active', true),
      (${CLASSROOM}::uuid, ${CHILD_ROW}::uuid, ${SCHOOL}::uuid, 'active', true)`;
  await sql`
    insert into public.guardian_links (student_id, guardian_id, status, relationship, verified_by, verified_at)
    values (${STUDENT_ROW}::uuid, ${PARENT}::uuid, 'verified', 'parent', ${TEACHER}::uuid, now())
    on conflict (student_id, guardian_id) do nothing`;
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

async function ask(subject: string, question = "What is a cell?") {
  const res = await request("/v1/study-assistant/ask", subject, { question });
  return {
    status: res.status,
    code: res.status === 200
      ? null
      : (await res.json() as { code: string }).code,
  };
}

const agree = (locale = "en") => ({ given: true, version: VERSION, locale });

suite("AI access and consent over real SQL (ADR-0043)", () => {
  beforeAll(async () => {
    sql = createDatabase(databaseUrl!);
    await cleanup();
    await seed();
    const contexts = new AuthContextRepository(sql);
    const logger = createJsonLogger(
      "api",
      "ai-consent-it",
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
    const aiAccess = new PostgresAiAccessRepository(sql);
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
          aiAccess,
          repository,
          prices: { inputUsdPerMTok: 0.17, outputUsdPerMTok: 0.25 },
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
          aiAccess,
          repository,
          prices: { inputUsdPerMTok: 0.17, outputUsdPerMTok: 0.25 },
          assistant,
          lessonToolsEnabled: true,
          storage: null,
        },
        authorization,
        idempotency,
      ),
    );
    app.route(
      "/",
      createAiConsentRoutes(
        { repository: aiAccess, toolsEnabled: true },
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

  test("parents and teachers are refused (D4)", async () => {
    asked.length = 0;
    for (const subject of [TEACHER, PARENT]) {
      expect(await ask(subject)).toEqual({
        status: 403,
        code: "AI_STUDENTS_ONLY",
      });
    }
    expect(asked).toEqual([]);
    const plan = await request("/v1/me/study-plan", PARENT);
    expect(await plan.json()).toMatchObject({
      aiAccess: "not_student",
      available: [],
    });
  });

  test("a student with no class is asked for consent, not refused (ADR-0045)", async () => {
    asked.length = 0;
    expect(await ask(LONER)).toEqual({
      status: 403,
      code: "AI_CONSENT_REQUIRED",
    });
    expect(asked).toEqual([]);
    const loner = await request("/v1/me/study-plan", LONER);
    const body = await loner.json() as {
      aiAccess: string;
      available: string[];
    };
    expect(body.aiAccess).toBe("consent_required");
    expect(body.available).toContain("ask");
  });

  test("a parent or teacher cannot consent to tools they cannot use", async () => {
    const res = await request("/v1/me/study-tools-consent", TEACHER, agree());
    expect(res.status).toBe(403);
    expect((await res.json() as { code: string }).code).toBe(
      "AI_STUDENTS_ONLY",
    );
  });

  test("a student is asked to consent before their first AI use (D2)", async () => {
    asked.length = 0;
    const state = await request("/v1/me/study-tools-consent", STUDENT);
    expect(await state.json()).toEqual({
      access: "consent_required",
      version: VERSION,
      consent: null,
      toolsEnabled: true,
    });
    expect(await ask(STUDENT)).toEqual({
      status: 403,
      code: "AI_CONSENT_REQUIRED",
    });
    expect(asked).toEqual([]);
    // The plan still offers the tools: the app shows the notice on first use.
    const plan = await request("/v1/me/study-plan", STUDENT);
    const body = await plan.json() as { aiAccess: string; available: string[] };
    expect(body.aiAccess).toBe("consent_required");
    expect(body.available).toContain("ask");
  });

  test("a consent to a notice that is not the current one is refused", async () => {
    const res = await request("/v1/me/study-tools-consent", STUDENT, {
      given: true,
      version: "2025-01-01",
      locale: "en",
    });
    expect(res.status).toBe(409);
  });

  test("once the student consents, names never reach the provider (D1)", async () => {
    asked.length = 0;
    const given = await request(
      "/v1/me/study-tools-consent",
      STUDENT,
      agree("ar"),
    );
    expect(given.status).toBe(200);
    expect(await given.json()).toMatchObject({
      access: "ok",
      consent: { version: VERSION, locale: "ar", givenAs: "self" },
    });
    expect(
      await ask(
        STUDENT,
        "I'm Sara Haddad. Can Yousef Khatib, Mr Hopper or my dad Omar help?",
      ),
    ).toEqual({ status: 200, code: null });
    expect(asked).toEqual([
      "I'm [student]. Can [classmate], Mr [teacher] or my dad [parent] help?",
    ]);
  });

  test("withdrawing turns the tools off, and is recorded", async () => {
    const withdrawn = await request("/v1/me/study-tools-consent", STUDENT, {
      given: false,
    });
    expect(withdrawn.status).toBe(200);
    expect((await withdrawn.json() as { access: string }).access).toBe(
      "consent_required",
    );
    expect(await ask(STUDENT)).toEqual({
      status: 403,
      code: "AI_CONSENT_REQUIRED",
    });
    const rows = await sql<{ withdrawn_by: string }[]>`
      select withdrawn_by from public.consent_records
      where user_id = ${STUDENT}::uuid and purpose = 'ai_features'`;
    expect(rows[0]?.withdrawn_by).toBe(STUDENT);
  });

  test("a managed child's parent consents for them, from their own account", async () => {
    asked.length = 0;
    expect(await ask(CHILD)).toEqual({
      status: 403,
      code: "AI_GUARDIAN_CONSENT_REQUIRED",
    });
    const self = await request("/v1/me/study-tools-consent", CHILD, agree());
    expect(self.status).toBe(403);
    expect((await self.json() as { code: string }).code).toBe(
      "AI_GUARDIAN_CONSENT_REQUIRED",
    );
    // Nobody else can, and is not told the child exists.
    const teacher = await request(
      `/v1/me/managed-children/${CHILD}/study-tools-consent`,
      TEACHER,
      agree(),
    );
    expect(teacher.status).toBe(404);
    const parent = await request(
      `/v1/me/managed-children/${CHILD}/study-tools-consent`,
      PARENT,
      agree(),
    );
    expect(parent.status).toBe(200);
    expect(await parent.json()).toMatchObject({
      access: "ok",
      consent: { givenAs: "guardian" },
    });
    expect(await ask(CHILD)).toEqual({ status: 200, code: null });
    const rows = await sql<{ given_by: string; given_as: string }[]>`
      select given_by, given_as from public.consent_records
      where user_id = ${CHILD}::uuid and purpose = 'ai_features'`;
    expect([...rows]).toEqual([{ given_by: PARENT, given_as: "guardian" }]);
    // The parent can turn it off again, and sees that.
    const off = await request(
      `/v1/me/managed-children/${CHILD}/study-tools-consent`,
      PARENT,
      { given: false },
    );
    expect((await off.json() as { access: string }).access).toBe(
      "guardian_consent_required",
    );
    const read = await request(
      `/v1/me/managed-children/${CHILD}/study-tools-consent`,
      PARENT,
    );
    expect((await read.json() as { access: string }).access).toBe(
      "guardian_consent_required",
    );
  });
});
