/**
 * Family+ insights over the real /v1 stack (launch plan 7.1). The SQL rules
 * (who may read, what is filtered) are proven in
 * supabase/tests/family_insights.sql; this proves the HTTP layer on top:
 * the route, the permission middleware, the paywall and the "no such child"
 * refusal looking identical, and the response schema.
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
import { PostgresFamilyInsightsRepository } from "../../src/family-insights/repository";
import { createFamilyInsightsRoutes } from "../../src/family-insights/routes";

const databaseUrl = process.env["DATABASE_URL"];
const suite = integrationSuite(describe);

const SCHOOL = "7b000000-0000-4000-8000-0000000000f1";
const TERM = "7b000000-0000-4000-8000-0000000000f2";
const CLASS = "7b000000-0000-4000-8000-0000000000f3";
const TEACHER = "7b000000-0000-4000-8000-0000000000a1";
const PARENT = "7b000000-0000-4000-8000-0000000000a2";
const STRANGER = "7b000000-0000-4000-8000-0000000000a3";
const KID = "7b000000-0000-4000-8000-0000000000a4";
const STUDENT = "7b000000-0000-4000-8000-0000000000b1";
const ASSESSMENT = "7b000000-0000-4000-8000-0000000000d1";
const TXN = "7b000000-0000-4000-8000-0000000000c1";
const USERS = [TEACHER, PARENT, STRANGER, KID];

let sql: Sql;
let app: Hono<AuthorizationEnv>;

async function seed(): Promise<void> {
  await sql`
    insert into auth.users (id, email, aud, role)
    select id, 'insights.' || n || '@synthetic.studafy.test', 'authenticated', 'authenticated'
    from unnest(${USERS}::uuid[]) with ordinality as u(id, n)
    on conflict (id) do nothing`;
  await sql`
    insert into public.profiles (id, display_name, status)
    select id, 'Insights ' || n, 'active'
    from unnest(${USERS}::uuid[]) with ordinality as u(id, n)
    on conflict (id) do update set status = 'active'`;
  await sql`
    insert into public.schools (id, name, timezone, locale, status)
    values (${SCHOOL}, 'Insights School', 'Asia/Amman', 'en', 'active')`;
  await sql`
    insert into public.memberships (school_id, user_id, role, active, status) values
      (${SCHOOL}, ${TEACHER}, 'teacher', true, 'active'),
      (${SCHOOL}, ${PARENT}, 'parent', true, 'active'),
      (${SCHOOL}, ${STRANGER}, 'parent', true, 'active'),
      (${SCHOOL}, ${KID}, 'student', true, 'active')`;
  await sql`
    insert into public.terms (id, school_id, name, starts_on, ends_on, active, status)
    values (${TERM}, ${SCHOOL}, 'T', current_date - 30, current_date + 300, true, 'active')`;
  await sql`
    insert into public.classrooms (id, school_id, term_id, name, grade, section, room, teacher_id, status)
    values (${CLASS}, ${SCHOOL}, ${TERM}, 'Science', '9', 'A', 'R', ${TEACHER}, 'active')`;
  await sql`
    insert into public.students (id, school_id, user_id, studafy_id, display_name, created_by)
    values (${STUDENT}, ${SCHOOL}, ${KID}, 'SJ-INSIGHTS', 'Kid Student', ${TEACHER})`;
  await sql`
    insert into public.enrollments (school_id, classroom_id, student_id, active, status, starts_on)
    values (${SCHOOL}, ${CLASS}, ${STUDENT}, true, 'active', current_date - 20)`;
  await sql`
    insert into public.guardian_links (school_id, student_id, guardian_id, status, relationship, verified_by, verified_at)
    values (${SCHOOL}, ${STUDENT}, ${PARENT}, 'verified', 'parent', ${KID}, now())`;
  // One published mark, a note shared with home, and one the school kept
  // to safeguarding staff, which must never reach a parent.
  await sql`
    insert into public.assessments (id, school_id, classroom_id, title, category, maximum_score, state, published_at, created_by)
    values (${ASSESSMENT}, ${SCHOOL}, ${CLASS}, 'Cells quiz', 'quiz', 20, 'published', now() - interval '3 days', ${TEACHER})`;
  await sql`
    insert into public.grade_results (assessment_id, student_id, school_id, score, state, reviewed_by, reviewed_at, published_at, published_by)
    values (${ASSESSMENT}, ${STUDENT}, ${SCHOOL}, 15, 'published', ${TEACHER}, now(), now() - interval '2 days', ${TEACHER})`;
  // Homework due soon and handed in late, and a week of attendance.
  await sql`
    insert into public.assignments (id, school_id, classroom_id, title, due_at, state, published_at, created_by) values
      ('7b000000-0000-4000-8000-0000000000d2', ${SCHOOL}, ${CLASS}, 'Read chapter 3', now() + interval '2 days', 'published', now() - interval '5 days', ${TEACHER}),
      ('7b000000-0000-4000-8000-0000000000d3', ${SCHOOL}, ${CLASS}, 'Cell diagram', now() - interval '1 day', 'published', now() - interval '6 days', ${TEACHER})`;
  await sql`
    insert into public.submissions (assignment_id, student_id, school_id, status, submitted_at)
    values ('7b000000-0000-4000-8000-0000000000d3', ${STUDENT}, ${SCHOOL}, 'submitted', now() - interval '2 days')`;
  await sql`
    insert into public.lesson_sessions (id, school_id, classroom_id, starts_at, ends_at, status, filed_at)
    select ('7b000000-0000-4000-8000-0000000001' || lpad(d::text, 2, '0'))::uuid, ${SCHOOL}, ${CLASS},
      now() - (d || ' days')::interval, now() - (d || ' days')::interval + interval '45 minutes',
      'completed', now() - (d || ' days')::interval
    from generate_series(1, 5) d`;
  await sql`
    insert into public.attendance_records (session_id, student_id, school_id, state, recorded_by)
    select ('7b000000-0000-4000-8000-0000000001' || lpad(d::text, 2, '0'))::uuid, ${STUDENT}, ${SCHOOL},
      (case when d = 3 then 'absent' else 'present' end)::public.attendance_state, ${TEACHER}
    from generate_series(1, 5) d`;
  await sql`
    insert into public.wellbeing_events (school_id, student_id, classroom_id, kind, title, visibility, created_by) values
      (${SCHOOL}, ${STUDENT}, ${CLASS}, 'note', 'Shared with home', 'guardian_shared', ${TEACHER}),
      (${SCHOOL}, ${STUDENT}, ${CLASS}, 'note', 'RESTRICTED SAFEGUARDING', 'safeguarding_restricted', ${TEACHER})`;
}

async function subscribe(endsAt: string): Promise<void> {
  await sql`
    insert into public.store_transactions (
      id, platform, environment, transaction_id, original_transaction_id,
      product_id, beneficiary_id, purchaser_id, state, signed_data_hash, purchased_at)
    values (${TXN}, 'app_store', (select environment from private.notebook_runtime),
      'insights-txn-1', 'insights-txn-1',
      (select p.id from public.store_products p
        where p.feature_key = 'parent_insights' and p.platform = 'app_store'
          and p.environment = (select environment from private.notebook_runtime)
        limit 1),
      ${KID}, ${PARENT}, 'active', ${"e".repeat(64)}, now())
    on conflict (id) do nothing`;
  await sql`
    insert into public.entitlements (user_id, school_id, feature_key, source, source_transaction_id, status, starts_at, ends_at)
    values (${KID}, ${SCHOOL}, 'parent_insights', 'app_store', ${TXN}, 'active', now() - interval '1 day', ${endsAt}::timestamptz)`;
}

async function cleanup(): Promise<void> {
  await removeFixtures(sql, { schoolIds: [SCHOOL], userIds: USERS });
}

async function insights(subject: string, query: string): Promise<Response> {
  return await app.request(`/v1/family/insights?${query}`, {
    headers: { "x-test-subject": subject },
  });
}

suite("Family+ insights over the real /v1 stack", () => {
  beforeAll(async () => {
    sql = createDatabase(databaseUrl!);
    await cleanup();
    await seed();
    const contexts = new AuthContextRepository(sql);
    const logger = createJsonLogger(
      "api",
      "family-insights-integration",
      "debug" as LogLevel,
      () => undefined,
    );
    const authorization = createAuthorizationDependencies(
      logger,
      new PostgresAuthorizationRepository(sql),
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
      createFamilyInsightsRoutes(
        { repository: new PostgresFamilyInsightsRepository(sql) },
        authorization,
      ),
    );
  });

  afterAll(async () => {
    if (!sql) return;
    await cleanup();
    await sql.end({ timeout: 5 });
  });

  test("a linked parent without Family+ gets the same refusal as for no child", async () => {
    const unpaid = await insights(PARENT, `studentId=${STUDENT}`);
    const unknown = await insights(
      PARENT,
      "studentId=7b000000-0000-4000-8000-00000000ffff",
    );
    expect(unpaid.status).toBe(404);
    expect(unknown.status).toBe(404);
    expect(await unpaid.json()).toMatchObject({ code: "NOT_FOUND" });
  });

  test("with Family+ the parent gets their child's insights, schema-checked", async () => {
    await subscribe(new Date(Date.now() + 30 * 86_400_000).toISOString());
    const res = await insights(PARENT, `studentId=${STUDENT}&period=term`);
    expect(res.status).toBe(200);
    const body = await res.json() as Record<string, unknown>;
    expect(body.studentId).toBe(STUDENT);
    expect(body.studentName).toBe("Kid Student");
    expect(body.period).toBe("term");
    // Homework still due is listed as upcoming.
    expect(JSON.stringify(body)).toContain("Read chapter 3");
    const text = JSON.stringify(body);
    expect(text).toContain("Shared with home");
    // Safeguarding notes never reach a parent, paid or not.
    expect(text).not.toContain("RESTRICTED SAFEGUARDING");
  });

  test("another parent at the same school is refused (tenant isolation)", async () => {
    const res = await insights(STRANGER, `studentId=${STUDENT}`);
    expect(res.status).toBe(404);
  });

  test("a teacher is refused: this is the guardian surface only", async () => {
    const res = await insights(TEACHER, `studentId=${STUDENT}`);
    expect([403, 404]).toContain(res.status);
  });

  test("an expired subscription is refused again", async () => {
    await sql`
      update public.entitlements set ends_at = now() - interval '1 second'
      where user_id = ${KID} and feature_key = 'parent_insights'`;
    const res = await insights(PARENT, `studentId=${STUDENT}`);
    expect(res.status).toBe(404);
  });

  test("a malformed student id is a validation error, not a lookup", async () => {
    const res = await insights(PARENT, "studentId=not-a-uuid");
    expect(res.status).toBe(400);
  });
});
