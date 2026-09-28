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

/**
 * The /v1 stack both suites run against. The first builds it without a code
 * key, proving links alone still work; the second switches JOIN-053 on.
 */
function buildApp(
  repository: PostgresClassJoinRepository,
  authorization: ReturnType<typeof createAuthorizationDependencies>,
  idempotency: {
    logger: ReturnType<typeof createJsonLogger>;
    repository: PostgresIdempotencyRepository;
  },
): Hono<AuthorizationEnv> {
  const built = new Hono<AuthorizationEnv>();
  built.use("*", async (c, next) => {
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
  built.route(
    "/",
    createClassJoinRoutes(
      { repository, cursorSigningKey: CURSOR_KEY },
      authorization,
      idempotency,
    ),
  );
  return built;
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

    app = buildApp(
      new PostgresClassJoinRepository(sql),
      authorization,
      idempotency,
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
    // Without a code key the token is random and was never stored, so there
    // is nothing to re-derive: the field is present but empty.
    expect(body["token"] ?? null).toBeNull();
    expect(body["derivationSalt"]).toBeUndefined();
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

// ---------------------------------------------------------------------------
// JOIN-053: the same link as an eight-character code.
//
// A code is short enough to guess in a way a 43-character token is not, so
// these assert what stops that mattering: it is stored keyed, it resolves to
// exactly one live link, and it dies with the link it belongs to.
// ---------------------------------------------------------------------------
const CODE_KEY = "join053-integration-code-key-000000000001";
const CODE_SHAPE = /^[A-HJ-NP-Z2-9]{4}-[A-HJ-NP-Z2-9]{4}$/;

suite("JOIN-053 class codes over the real /v1 stack", () => {
  let code: string;

  async function mint(): Promise<{ code: string | null; token: string }> {
    const res = await request(`/v1/classrooms/${CLASSROOM}/join-link`, {
      method: "POST",
      subject: TEACHER,
      body: {},
    });
    expect(res.status).toBe(201);
    return await res.json() as { code: string | null; token: string };
  }

  beforeAll(async () => {
    sql = createDatabase(databaseUrl!);
    await cleanup();
    await seed();
    contexts = new AuthContextRepository(sql);
    const logger = createJsonLogger(
      "api",
      "join053-integration",
      "debug" as LogLevel,
      () => undefined,
    );
    app = buildApp(
      new PostgresClassJoinRepository(sql, CODE_KEY),
      createAuthorizationDependencies(
        logger,
        new PostgresAuthorizationRepository(sql),
      ),
      { logger, repository: new PostgresIdempotencyRepository(sql) },
    );
  });

  afterAll(async () => {
    if (!sql) return;
    await cleanup();
    await sql.end({ timeout: 5 });
  });

  test("minting a link also yields a readable code", async () => {
    const minted = await mint();
    expect(minted.code).toMatch(CODE_SHAPE);
    code = minted.code!;
  });

  test("the stored code is keyed, not the code or its plain digest", async () => {
    const rows = await sql<{ code_hash: string }[]>`
      select code_hash from public.class_join_links
      where classroom_id = ${CLASSROOM}::uuid and status = 'active'
    `;
    const stored = rows[0]!.code_hash;
    expect(stored).toMatch(/^[0-9a-f]{64}$/);
    const canonical = code.replace("-", "");
    expect(stored).not.toContain(canonical);
    const plain = [
      ...new Uint8Array(
        await crypto.subtle.digest(
          "SHA-256",
          new TextEncoder().encode(canonical),
        ),
      ),
    ].map((byte) => byte.toString(16).padStart(2, "0")).join("");
    expect(stored).not.toBe(plain);
  });

  test("a student types the code, however loosely, and joins", async () => {
    // Lower case and no dash: what a child actually types.
    const typed = code.toLowerCase().replace("-", " ");
    const res = await request("/v1/class-join-links/redeem", {
      method: "POST",
      subject: JOINER,
      body: { code: typed },
    });
    expect(res.status).toBe(200);
    const body = await res.json() as { classroomId: string };
    expect(body.classroomId).toBe(CLASSROOM);
    const enrolled = await sql<{ count: string }[]>`
      select count(*)::text as count from public.enrollments e
      join public.students s on s.id = e.student_id
      where s.user_id = ${JOINER}::uuid and e.classroom_id = ${CLASSROOM}::uuid
    `;
    expect(enrolled[0]!.count).toBe("1");
  });

  test("a wrong code joins nothing", async () => {
    const res = await request("/v1/class-join-links/redeem", {
      method: "POST",
      subject: JOINER,
      body: { code: "ZZZZ-ZZZZ" },
    });
    expect(res.status).toBe(404);
  });

  test("a code and a token together are refused", async () => {
    const res = await request("/v1/class-join-links/redeem", {
      method: "POST",
      subject: JOINER,
      body: { code, token: "x".repeat(43) },
    });
    expect(res.status).toBe(400);
  });

  test("something that cannot be a code is refused without a lookup", async () => {
    const res = await request("/v1/class-join-links/redeem", {
      method: "POST",
      subject: JOINER,
      body: { code: "0000-0000" },
    });
    expect(res.status).toBe(400);
  });

  async function readBack() {
    const res = await request(`/v1/classrooms/${CLASSROOM}/join-link`, {
      subject: TEACHER,
    });
    expect(res.status).toBe(200);
    return await res.json() as Record<string, unknown>;
  }

  test("opening the invite again shows the same code, not a new one", async () => {
    // The teacher shares a code once. Looking it up again must not change
    // it, and must not revoke the one already on the board.
    const first = await readBack();
    const second = await readBack();
    expect(first["code"]).toBe(code);
    expect(second["code"]).toBe(code);
    expect(typeof first["token"]).toBe("string");
    expect(second["token"]).toBe(first["token"]);
    // The salt the API derives them from never leaves it.
    expect(first["derivationSalt"]).toBeUndefined();
  });

  test("the code read back is the one that joins", async () => {
    const res = await request("/v1/class-join-links/redeem", {
      method: "POST",
      subject: JOINER,
      body: { code: (await readBack())["code"] },
    });
    // The joiner is already in the class from the test above, so the answer
    // is "already a member" - which proves the code resolved to this link.
    // A code that matched nothing would be 404.
    expect(res.status).not.toBe(404);
    expect(res.status).toBeLessThan(500);
  });

  test("another class's teacher cannot read this class's code", async () => {
    const res = await request(`/v1/classrooms/${CLASSROOM}/join-link`, {
      subject: OTHER_TEACHER,
    });
    expect(res.status).toBe(404);
  });

  test("re-issuing the link retires the old code with it", async () => {
    const replacement = await mint();
    expect(replacement.code).toMatch(CODE_SHAPE);
    expect(replacement.code).not.toBe(code);
    // OTHER_TEACHER is staff at this school and would be refused anyway, so a
    // fresh probe of the retired code is made as the enrolled joiner: a dead
    // code is simply not found.
    const old = await request("/v1/class-join-links/redeem", {
      method: "POST",
      subject: JOINER,
      body: { code },
    });
    expect(old.status).toBe(404);
    code = replacement.code!;
    // And reading it back now shows the new code.
    expect((await readBack())["code"]).toBe(code);
  });

  test("revoking the link kills its code", async () => {
    const link = await sql<{ id: string }[]>`
      select id from public.class_join_links
      where classroom_id = ${CLASSROOM}::uuid and status = 'active'
    `;
    const revoke = await request(
      `/v1/class-join-links/${link[0]!.id}/revoke`,
      { method: "POST", subject: TEACHER, body: {} },
    );
    expect(revoke.status).toBe(200);
    const res = await request("/v1/class-join-links/redeem", {
      method: "POST",
      subject: JOINER,
      body: { code },
    });
    expect(res.status).toBe(404);
  });
});
