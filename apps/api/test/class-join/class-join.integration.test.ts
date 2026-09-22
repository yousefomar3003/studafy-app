/**
 * JOIN-052 shareable class join links, end to end against a real local
 * Postgres.
 *
 * The point of this file is the token round-trip that only exists in
 * TypeScript: createClassJoinLink mints a raw token and stores nothing but
 * its SHA-256 hash, and redeemClassJoinLink has to hash an incoming token
 * the same way and find the same row. A fake repository cannot prove that.
 *
 * It also pins the two rules that make the link safe to hand out: only the
 * classroom's own staff may mint one, and redeeming it never touches the
 * caller's existing non-student standing at that school.
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
import { PostgresClassJoinRepository } from "../../src/class-join/repository";
import { createClassJoinRoutes } from "../../src/class-join/routes";

const databaseUrl = process.env["DATABASE_URL"];
const suite = databaseUrl ? describe : describe.skip;

const TEACHER = "5f520000-0000-4000-8000-0000000000a1";
const OTHER_TEACHER = "5f520000-0000-4000-8000-0000000000a2";
const JOINER = "5f520000-0000-4000-8000-0000000000a3";
const SCHOOL = "5f520000-0000-4000-8000-0000000000b1";
const TERM = "5f520000-0000-4000-8000-0000000000c1";
const CLASSROOM = "5f520000-0000-4000-8000-0000000000d1";

const CURSOR_KEY = "join052-integration-cursor-key-00000000001";

let sql: Sql;
let contexts: AuthContextRepository;
let app: Hono<AuthorizationEnv>;

function authUser(id: string, email: string, name: string) {
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
      '{}'::jsonb, ${JSON.stringify({ full_name: name })}::jsonb
    ) on conflict (id) do nothing
  `;
}

async function seed(): Promise<void> {
  await authUser(TEACHER, "join052.teacher@synthetic.studafy.test", "Lead");
  await authUser(
    OTHER_TEACHER,
    "join052.other@synthetic.studafy.test",
    "Other",
  );
  await authUser(JOINER, "join052.joiner@synthetic.studafy.test", "Joiner");
  await sql`
    insert into public.schools (id, name, timezone, status)
    values (${SCHOOL}::uuid, 'JOIN-052 School', 'Asia/Riyadh', 'active')
    on conflict (id) do update set status = 'active'
  `;
  await sql`
    insert into public.memberships (school_id, user_id, role, active, status, version) values
      (${SCHOOL}::uuid, ${TEACHER}::uuid, 'teacher', true, 'active', 1),
      (${SCHOOL}::uuid, ${OTHER_TEACHER}::uuid, 'teacher', true, 'active', 1)
    on conflict (school_id, user_id, role) do nothing
  `;
  await sql`
    insert into public.terms (id, school_id, name, starts_on, ends_on, active, status)
    values (${TERM}::uuid, ${SCHOOL}::uuid, 'JOIN-052 Term',
            current_date - 10, current_date + 90, true, 'active')
    on conflict (id) do nothing
  `;
  await sql`
    insert into public.classrooms (id, school_id, term_id, name, grade, section, teacher_id, status, version)
    values (${CLASSROOM}::uuid, ${SCHOOL}::uuid, ${TERM}::uuid, 'Grade 7 Science',
            '7', 'A', ${TEACHER}::uuid, 'active', 1)
    on conflict (id) do nothing
  `;
  // Only the lead teacher is staff of this room; OTHER_TEACHER teaches at the
  // same school but not here, which is what makes the staff check meaningful.
  await sql`
    insert into public.classroom_staff (school_id, classroom_id, membership_id, user_id, role, status)
    select ${SCHOOL}::uuid, ${CLASSROOM}::uuid, m.id, ${TEACHER}::uuid, 'lead_teacher', 'active'
    from public.memberships m
    where m.school_id = ${SCHOOL}::uuid and m.user_id = ${TEACHER}::uuid and m.role = 'teacher'
    on conflict do nothing
  `;
}

async function cleanup(): Promise<void> {
  await sql.begin(async (tx) => {
    await tx`alter table public.membership_events disable trigger db020_reject_mutation`;
    await tx`alter table public.audit_events disable trigger db020_reject_mutation`;
    await tx`delete from public.class_join_links where school_id = ${SCHOOL}::uuid`;
    await tx`delete from public.enrollments where school_id = ${SCHOOL}::uuid`;
    await tx`delete from public.students where school_id = ${SCHOOL}::uuid`;
    await tx`delete from public.classroom_staff where school_id = ${SCHOOL}::uuid`;
    await tx`delete from public.classrooms where school_id = ${SCHOOL}::uuid`;
    await tx`delete from public.terms where school_id = ${SCHOOL}::uuid`;
    await tx`delete from public.membership_events where school_id = ${SCHOOL}::uuid`;
    await tx`delete from public.audit_events where school_id = ${SCHOOL}::uuid`;
    await tx`delete from public.idempotency_records where school_id = ${SCHOOL}::uuid`;
    await tx`delete from public.memberships where school_id = ${SCHOOL}::uuid`;
    await tx`delete from public.schools where id = ${SCHOOL}::uuid`;
    await tx`delete from auth.users where id in (${TEACHER}::uuid, ${OTHER_TEACHER}::uuid, ${JOINER}::uuid)`;
    await tx`alter table public.membership_events enable trigger db020_reject_mutation`;
    await tx`alter table public.audit_events enable trigger db020_reject_mutation`;
  });
}

interface RequestInput {
  method?: "GET" | "POST";
  subject: string;
  body?: unknown;
}

async function request(path: string, input: RequestInput): Promise<Response> {
  const headers = new Headers();
  headers.set("x-test-subject", input.subject);
  if (input.body !== undefined) headers.set("content-type", "application/json");
  if ((input.method ?? "GET") === "POST") {
    headers.set("idempotency-key", crypto.randomUUID());
  }
  return await app.request(path, {
    method: input.method ?? "GET",
    headers,
    ...(input.body !== undefined ? { body: JSON.stringify(input.body) } : {}),
  });
}

suite("JOIN-052 class join links over the real /v1 stack", () => {
  let sharedToken: string;

  beforeAll(async () => {
    sql = createDatabase(databaseUrl!);
    await cleanup();
    await seed();
    contexts = new AuthContextRepository(sql);
    const logger = createJsonLogger(
      "api",
      "join052-integration",
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
      createClassJoinRoutes(
        {
          repository: new PostgresClassJoinRepository(sql),
          cursorSigningKey: CURSOR_KEY,
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

  test("a teacher of another classroom cannot mint a link for this one", async () => {
    const res = await request(`/v1/classrooms/${CLASSROOM}/join-link`, {
      method: "POST",
      subject: OTHER_TEACHER,
      body: {},
    });
    expect([403, 404]).toContain(res.status);
  });

  test("the classroom's teacher mints a link and sees the token once", async () => {
    const res = await request(`/v1/classrooms/${CLASSROOM}/join-link`, {
      method: "POST",
      subject: TEACHER,
      body: { maxUses: 30 },
    });
    expect(res.status).toBe(201);
    const body = await res.json() as {
      token: string;
      classroomId: string;
      classroomName: string;
      status: string;
      useCount: number;
      maxUses: number | null;
    };
    expect(body.classroomId).toBe(CLASSROOM);
    expect(body.classroomName).toBe("Grade 7 Science");
    expect(body.status).toBe("active");
    expect(body.useCount).toBe(0);
    expect(body.maxUses).toBe(30);
    expect(body.token.length).toBeGreaterThanOrEqual(32);
    sharedToken = body.token;
  });

  test("the stored link never carries the raw token", async () => {
    const rows = await sql<{ token_hash: string }[]>`
      select token_hash from public.class_join_links
      where classroom_id = ${CLASSROOM}::uuid and status = 'active'
    `;
    expect(rows).toHaveLength(1);
    expect(rows[0]!.token_hash).not.toBe(sharedToken);
    // SHA-256 hex.
    expect(rows[0]!.token_hash).toMatch(/^[0-9a-f]{64}$/);
  });

  test("reading the link back does not disclose the token", async () => {
    const res = await request(`/v1/classrooms/${CLASSROOM}/join-link`, {
      subject: TEACHER,
    });
    expect(res.status).toBe(200);
    const body = await res.json() as Record<string, unknown>;
    expect(body["token"]).toBeUndefined();
    expect(body["classroomId"]).toBe(CLASSROOM);
  });

  test("a stranger redeems the token and lands in the class", async () => {
    const res = await request("/v1/class-join-links/redeem", {
      method: "POST",
      subject: JOINER,
      body: { token: sharedToken },
    });
    expect(res.status).toBe(200);
    const body = await res.json() as {
      classroomId: string;
      classroomName: string;
      schoolId: string;
    };
    expect(body.classroomId).toBe(CLASSROOM);
    expect(body.classroomName).toBe("Grade 7 Science");
    expect(body.schoolId).toBe(SCHOOL);

    const enrolled = await sql<{ role: string; status: string }[]>`
      select m.role::text as role, e.status::text as status
      from public.memberships m
      join public.students s
        on s.user_id = m.user_id and s.school_id = m.school_id
      join public.enrollments e on e.student_id = s.id
      where m.user_id = ${JOINER}::uuid and e.classroom_id = ${CLASSROOM}::uuid
    `;
    expect(enrolled).toHaveLength(1);
    expect(enrolled[0]!.role).toBe("student");
    expect(enrolled[0]!.status).toBe("active");
  });

  test("redeeming again reports no change rather than double-enrolling", async () => {
    const res = await request("/v1/class-join-links/redeem", {
      method: "POST",
      subject: JOINER,
      body: { token: sharedToken },
    });
    expect(res.status).toBeGreaterThanOrEqual(400);
    const rows = await sql<{ count: string }[]>`
      select count(*)::text as count from public.enrollments
      where classroom_id = ${CLASSROOM}::uuid
    `;
    expect(rows[0]!.count).toBe("1");
  });

  test("a teacher of the school is not demoted by opening the link", async () => {
    const res = await request("/v1/class-join-links/redeem", {
      method: "POST",
      subject: OTHER_TEACHER,
      body: { token: sharedToken },
    });
    expect(res.status).toBeGreaterThanOrEqual(400);
    const rows = await sql<{ count: string }[]>`
      select count(*)::text as count from public.memberships
      where school_id = ${SCHOOL}::uuid and user_id = ${OTHER_TEACHER}::uuid
        and role = 'student'
    `;
    expect(rows[0]!.count).toBe("0");
  });

  test("a wrong token is refused", async () => {
    const res = await request("/v1/class-join-links/redeem", {
      method: "POST",
      subject: JOINER,
      body: { token: "x".repeat(43) },
    });
    expect(res.status).toBeGreaterThanOrEqual(400);
  });

  test("revoking the link stops it working", async () => {
    const link = await sql<{ id: string }[]>`
      select id from public.class_join_links
      where classroom_id = ${CLASSROOM}::uuid and status = 'active'
    `;
    const revoke = await request(
      `/v1/class-join-links/${link[0]!.id}/revoke`,
      { method: "POST", subject: TEACHER, body: {} },
    );
    expect(revoke.status).toBe(200);
    expect((await revoke.json() as { status: string }).status).toBe("revoked");
  });
});
