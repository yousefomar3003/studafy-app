/**
 * API-042 S9 end-to-end proof against a real local Postgres. The exhaustive
 * authorization/business-logic coverage lives in
 * supabase/tests/api042_roster.sql; this file proves the HTTP layer
 * (route paths, permission middleware, idempotency, response-schema
 * validation) createTerm/createStudent ride on top of, the same division of
 * labour every other API-042 integration test uses.
 */
import { afterAll, beforeAll, describe, expect, test } from "bun:test";
import { Hono } from "hono";
import type { LogLevel } from "@studafy/contracts";
import { createDatabase, type Sql } from "@studafy/database";
import { createJsonLogger } from "@studafy/observability";
import { AuthContextRepository } from "../../src/auth/context";
import type { Actor } from "../../src/auth/middleware";
import type { AuthorizationEnv } from "../../src/authorization/middleware";
import { createAuthorizationDependencies } from "../../src/authorization/middleware";
import { PostgresAuthorizationRepository } from "../../src/authorization/repository";
import { PostgresIdempotencyRepository } from "../../src/platform/idempotency";
import { PostgresSchoolAdminRepository } from "../../src/school-admin/repository";
import { createSchoolRosterRoutes } from "../../src/school-admin/routes";

const databaseUrl = process.env["DATABASE_URL"];
const suite = databaseUrl ? describe : describe.skip;

const ADMIN = "5f430000-0000-4000-8000-0000000000a1";
const TEACHER = "5f430000-0000-4000-8000-0000000000a2";
const SCHOOL = "5f430000-0000-4000-8000-0000000000b1";

const CURSOR_KEY = "api042-roster-integration-cursor-key-0000000001";

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
      (${ADMIN}::uuid, 'api042.roster.admin@synthetic.studafy.test', 'synthetic-not-a-secret', 'authenticated', 'authenticated', now(), now(), now(), '00000000-0000-0000-0000-000000000000', '', '', '', '', '', '', '{}'::jsonb, '{"full_name":"API-042 Roster Admin"}'::jsonb),
      (${TEACHER}::uuid, 'api042.roster.teacher@synthetic.studafy.test', 'synthetic-not-a-secret', 'authenticated', 'authenticated', now(), now(), now(), '00000000-0000-0000-0000-000000000000', '', '', '', '', '', '', '{}'::jsonb, '{"full_name":"API-042 Roster Teacher"}'::jsonb)
    on conflict (id) do nothing
  `;
  await sql`
    insert into public.schools (id, name, timezone, status) values (${SCHOOL}::uuid, 'API-042 Roster School', 'Asia/Riyadh', 'active')
    on conflict (id) do update set status = 'active'
  `;
  await sql`
    insert into public.memberships (school_id, user_id, role, active, status, version) values
      (${SCHOOL}::uuid, ${ADMIN}::uuid, 'school_admin', true, 'active', 1),
      (${SCHOOL}::uuid, ${TEACHER}::uuid, 'teacher', true, 'active', 1)
    on conflict (school_id, user_id, role) do nothing
  `;
}

async function cleanup(): Promise<void> {
  await sql.begin(async (tx) => {
    await tx`alter table public.audit_events disable trigger db020_reject_mutation`;
    await tx`delete from public.students where school_id = ${SCHOOL}::uuid`;
    await tx`delete from public.terms where school_id = ${SCHOOL}::uuid`;
    await tx`delete from public.audit_events where school_id = ${SCHOOL}::uuid`;
    await tx`delete from public.memberships where school_id = ${SCHOOL}::uuid`;
    await tx`delete from public.schools where id = ${SCHOOL}::uuid`;
    await tx`delete from auth.users where id in (${ADMIN}::uuid, ${TEACHER}::uuid)`;
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

suite(
  "API-042 S9 school roster (createTerm/createStudent) over the real /v1 stack",
  () => {
    beforeAll(async () => {
      sql = createDatabase(databaseUrl!);
      await cleanup();
      await seed();
      contexts = new AuthContextRepository(sql);
      const logger = createJsonLogger(
        "api",
        "api042-roster-integration",
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
        createSchoolRosterRoutes(
          {
            repository: new PostgresSchoolAdminRepository(sql),
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

    test("a teacher cannot create a term", async () => {
      // term.create/student.create use the resource() catalogue helper's
      // concealDeniedResource: true, so a denial reads as 404, not 403 - the
      // same existence-oracle protection every other resource-scoped
      // permission in API-042 uses.
      const res = await post(`/v1/schools/${SCHOOL}/terms`, {
        subject: TEACHER,
        body: {
          name: "Rogue Term",
          startsOn: "2026-09-01",
          endsOn: "2026-12-31",
        },
      });
      expect(res.status).toBe(404);
    });

    test("a school admin creates a term", async () => {
      const res = await post(`/v1/schools/${SCHOOL}/terms`, {
        subject: ADMIN,
        body: {
          name: "HTTP Term",
          startsOn: "2026-09-01",
          endsOn: "2026-12-31",
        },
      });
      expect(res.status).toBe(201);
      const body = await res.json() as { status: string; schoolId: string };
      expect(body.status).toBe("active");
      expect(body.schoolId).toBe(SCHOOL);
    });

    test("a school admin creates a provisional student and the response matches V1SchoolStudent", async () => {
      const res = await post(`/v1/schools/${SCHOOL}/students`, {
        subject: ADMIN,
        body: { displayName: "HTTP Student" },
      });
      expect(res.status).toBe(201);
      const body = await res.json() as {
        id: string;
        schoolId: string;
        userId: string | null;
        studafyId: string;
        provisional: boolean;
      };
      expect(body.schoolId).toBe(SCHOOL);
      expect(body.userId).toBeNull();
      expect(body.provisional).toBe(true);
      expect(body.studafyId.startsWith("STU-")).toBe(true);
    });
  },
);
