/**
 * API-042 S3 end-to-end proof against a real local Postgres. The exhaustive
 * state-machine/rate-limit coverage lives in supabase/tests/api042_family.sql;
 * this file proves the HTTP layer (route paths, permission middleware,
 * idempotency, response-schema validation) on top of it.
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
import { PostgresFamilyRepository } from "../../src/family/repository";
import {
  createFamilyReadRoutes,
  createFamilyRoutes,
  createStudentFamilyRoutes,
} from "../../src/family/routes";

const databaseUrl = process.env["DATABASE_URL"];
const suite = databaseUrl ? describe : describe.skip;

const ADMIN = "5f440000-0000-4000-8000-0000000000a1";
const GUARDIAN = "5f440000-0000-4000-8000-0000000000a2";
const SCHOOL = "5f440000-0000-4000-8000-0000000000b1";
const STUDENT_USER = "5f440000-0000-4000-8000-0000000000a3";
const STUDENT_ROW = "5f440000-0000-4000-8000-0000000000c1";

const CURSOR_KEY = "api042-family-integration-cursor-key-0000000001";

let sql: Sql;
let contexts: AuthContextRepository;
let app: Hono<AuthorizationEnv>;

async function seed(): Promise<void> {
  await sql`
    insert into auth.users (
      id, email, encrypted_password, aud, role, email_confirmed_at,
      created_at, updated_at, instance_id, confirmation_token, recovery_token,
      email_change, email_change_token_new, email_change_token_current,
      phone_change_token, raw_app_meta_data, raw_user_meta_data
    ) values
      (${ADMIN}::uuid, 'api042.fam.admin@synthetic.studafy.test', 'synthetic-not-a-secret', 'authenticated', 'authenticated', now(), now(), now(), '00000000-0000-0000-0000-000000000000', '', '', '', '', '', '', '{}'::jsonb, '{"full_name":"API-042 Fam Admin"}'::jsonb),
      (${GUARDIAN}::uuid, 'api042.fam.guardian@synthetic.studafy.test', 'synthetic-not-a-secret', 'authenticated', 'authenticated', now(), now(), now(), '00000000-0000-0000-0000-000000000000', '', '', '', '', '', '', '{}'::jsonb, '{"full_name":"API-042 Fam Guardian"}'::jsonb),
      (${STUDENT_USER}::uuid, 'api042.fam.student@synthetic.studafy.test', 'synthetic-not-a-secret', 'authenticated', 'authenticated', now(), now(), now(), '00000000-0000-0000-0000-000000000000', '', '', '', '', '', '', '{}'::jsonb, '{"full_name":"API-042 Fam Student"}'::jsonb)
    on conflict (id) do nothing
  `;
  await sql`
    insert into public.schools (id, name, timezone, status) values (${SCHOOL}::uuid, 'API-042 Family School', 'Asia/Riyadh', 'active')
    on conflict (id) do update set status = 'active'
  `;
  await sql`
    insert into public.memberships (school_id, user_id, role, active, status, version) values
      (${SCHOOL}::uuid, ${ADMIN}::uuid, 'school_admin', true, 'active', 1)
    on conflict (school_id, user_id, role) do nothing
  `;
  await sql`
    insert into public.students (id, school_id, user_id, studafy_id, display_name, provisional, created_by) values
      (${STUDENT_ROW}::uuid, ${SCHOOL}::uuid, ${STUDENT_USER}::uuid, 'STU-API042-FAM', 'Family Integration Student', false, ${ADMIN}::uuid)
    on conflict (id) do nothing
  `;
}

async function cleanup(): Promise<void> {
  await sql.begin(async (tx) => {
    await tx`alter table public.audit_events disable trigger db020_reject_mutation`;
    await tx`delete from public.guardian_links where student_id = ${STUDENT_ROW}::uuid`;
    await tx`delete from public.audit_events where school_id = ${SCHOOL}::uuid or actor_id = ${GUARDIAN}::uuid`;
    await tx`delete from public.students where id = ${STUDENT_ROW}::uuid`;
    await tx`delete from public.memberships where school_id = ${SCHOOL}::uuid`;
    await tx`delete from public.schools where id = ${SCHOOL}::uuid`;
    await tx`delete from auth.users where id in (${ADMIN}::uuid, ${GUARDIAN}::uuid, ${STUDENT_USER}::uuid)`;
    await tx`alter table public.audit_events enable trigger db020_reject_mutation`;
  });
}

interface RequestInput {
  subject: string;
  key?: string;
  body?: unknown;
}

async function post(path: string, input: RequestInput): Promise<Response> {
  const headers = new Headers();
  headers.set("x-test-subject", input.subject);
  headers.set("content-type", "application/json");
  headers.set("idempotency-key", input.key ?? crypto.randomUUID());
  return await app.request(path, {
    method: "POST",
    headers,
    body: JSON.stringify(input.body ?? {}),
  });
}

suite("API-042 S3 family over the real /v1 stack", () => {
  let guardianLinkId: string;

  beforeAll(async () => {
    sql = createDatabase(databaseUrl!);
    await cleanup();
    await seed();
    contexts = new AuthContextRepository(sql);
    const logger = createJsonLogger(
      "api",
      "api042-family-integration",
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
    const familyDeps = {
      repository: new PostgresFamilyRepository(sql),
      cursorSigningKey: CURSOR_KEY,
    };
    app.route("/", createFamilyRoutes(familyDeps, authorization, idempotency));
    app.route(
      "/",
      createStudentFamilyRoutes(familyDeps, authorization, idempotency),
    );
    app.route(
      "/",
      createFamilyReadRoutes(familyDeps, authorization, idempotency),
    );
  });

  afterAll(async () => {
    if (!sql) return;
    await cleanup();
    await sql.end({ timeout: 5 });
  });

  test("locating a real student code reports found with matching identity", async () => {
    const res = await post("/v1/students/locate", {
      subject: GUARDIAN,
      body: { studafyId: "STU-API042-FAM" },
    });
    expect(res.status).toBe(200);
    const body = await res.json() as { found: boolean; studentId: string };
    expect(body.found).toBe(true);
    expect(body.studentId).toBe(STUDENT_ROW);
  });

  test("locating an unknown code reports not found with the same response shape", async () => {
    const res = await post("/v1/students/locate", {
      subject: GUARDIAN,
      body: { studafyId: "NOPE-DOES-NOT-EXIST" },
    });
    expect(res.status).toBe(200);
    const body = await res.json() as {
      found: boolean;
      studentId: null;
      displayName: null;
    };
    expect(body.found).toBe(false);
    expect(body.studentId).toBeNull();
    expect(body.displayName).toBeNull();
  });

  test("a guardian requests a link, which starts pending", async () => {
    const res = await post("/v1/guardian-links", {
      subject: GUARDIAN,
      body: { studentId: STUDENT_ROW, relationship: "parent" },
    });
    expect(res.status).toBe(201);
    const body = await res.json() as { id: string; status: string };
    expect(body.status).toBe("pending");
    guardianLinkId = body.id;
  });

  test("students see their ID and requests, while a guardian sees no student requests", async () => {
    const mine = await app.request("/v1/me/student-family", {
      headers: { "x-test-subject": STUDENT_USER },
    });
    expect(mine.status).toBe(200);
    const body = await mine.json() as {
      studentIds: { studafyId: string }[];
      requests: { id: string }[];
    };
    expect(body.studentIds[0]?.studafyId).toBe("STU-API042-FAM");
    expect(body.requests[0]?.id).toBe(guardianLinkId);
    const other = await app.request("/v1/me/student-family", {
      headers: { "x-test-subject": GUARDIAN },
    });
    expect((await other.json() as { requests: unknown[] }).requests).toEqual(
      [],
    );
  });

  test("guardians and unrelated accounts cannot approve a student link", async () => {
    for (const subject of [GUARDIAN, ADMIN]) {
      const response = await post(
        `/v1/guardian-links/${guardianLinkId}/student-decision`,
        { subject, body: { decision: "approve" } },
      );
      expect(response.status).toBe(404);
    }
    const [link] =
      await sql`select status from public.guardian_links where id=${guardianLinkId}::uuid`;
    expect(link?.status).toBe("pending");
  });

  test("the student can decline without granting access", async () => {
    const res = await post(
      `/v1/guardian-links/${guardianLinkId}/student-decision`,
      { subject: STUDENT_USER, body: { decision: "decline" } },
    );
    expect(res.status).toBe(200);
    expect((await res.json() as { status: string }).status).toBe("declined");
    const request = await post("/v1/guardian-links", {
      subject: GUARDIAN,
      body: { studentId: STUDENT_ROW, relationship: "parent" },
    });
    expect(request.status).toBe(201);
  });

  test("the owning student approves, duplicate replay is safe and stale decisions fail", async () => {
    const key = crypto.randomUUID();
    const path = `/v1/guardian-links/${guardianLinkId}/student-decision`;
    const res = await post(path, {
      subject: STUDENT_USER,
      key,
      body: { decision: "approve" },
    });
    expect(res.status).toBe(200);
    const body = await res.json() as { status: string; expiresAt: string };
    expect(body.status).toBe("verified");
    expect(new Date(body.expiresAt).getTime()).toBeGreaterThan(Date.now());
    const replay = await post(path, {
      subject: STUDENT_USER,
      key,
      body: { decision: "approve" },
    });
    expect(replay.status).toBe(200);
    const stale = await post(path, {
      subject: STUDENT_USER,
      body: { decision: "decline" },
    });
    expect(stale.status).toBe(409);
    const [link] =
      await sql`select verified_by from public.guardian_links where id=${guardianLinkId}::uuid`;
    expect(link?.verified_by).toBe(STUDENT_USER);
  });

  test("the guardian lists their own children, and nobody else sees them", async () => {
    const mine = await app.request("/v1/me/guardian-links", {
      headers: { "x-test-subject": GUARDIAN },
    });
    expect(mine.status).toBe(200);
    const body = await mine.json() as {
      items: {
        studentId: string;
        studentName: string;
        status: string;
        schoolId: string;
      }[];
    };
    expect(body.items).toHaveLength(1);
    expect(body.items[0]?.studentId).toBe(STUDENT_ROW);
    expect(body.items[0]?.status).toBe("verified");
    expect(body.items[0]?.schoolId).toBe(SCHOOL);
    expect(body.items[0]?.studentName.length).toBeGreaterThan(0);

    const theirs = await app.request("/v1/me/guardian-links", {
      headers: { "x-test-subject": ADMIN },
    });
    expect(((await theirs.json()) as { items: unknown[] }).items).toEqual([]);
  });

  test("the student can remove previously granted access", async () => {
    const res = await post(
      `/v1/guardian-links/${guardianLinkId}/student-decision`,
      {
        subject: STUDENT_USER,
        body: { decision: "revoke" },
      },
    );
    expect(res.status).toBe(200);
    const body = await res.json() as { status: string };
    expect(body.status).toBe("revoked");
  });
});
