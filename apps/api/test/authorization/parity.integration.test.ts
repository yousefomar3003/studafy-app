/**
 * Cross-layer AUTH-031 proof against a real local Postgres.
 *
 * A /v1 handler runs the production permission and tenant middleware, then
 * its result is compared with a direct query under the DB-021 authenticated
 * role and RLS. The test intentionally includes cross-tenant substitution and
 * a membership-revocation race.
 */
import { afterAll, beforeAll, describe, expect, test } from "bun:test";
import { Hono } from "hono";
import type { LogLevel } from "@studafy/contracts";
import { createDatabase, type Sql } from "@studafy/database";
import { createJsonLogger } from "@studafy/observability";
import { AuthContextRepository } from "../../src/auth/context";
import type { Actor } from "../../src/auth/middleware";
import { VersionedTenantContextCache } from "../../src/authorization/cache";
import {
  type AuthorizationEnv,
  requirePermission,
} from "../../src/authorization/middleware";
import { PostgresAuthorizationRepository } from "../../src/authorization/repository";

const databaseUrl = process.env["DATABASE_URL"];
const suite = databaseUrl ? describe : describe.skip;

const USER_A = "4f310000-0000-4000-8000-0000000000a1";
const USER_B = "4f310000-0000-4000-8000-0000000000a2";
const SCHOOL_A = "4f310000-0000-4000-8000-0000000000b1";
const SCHOOL_B = "4f310000-0000-4000-8000-0000000000b2";
const TERM_A = "4f310000-0000-4000-8000-0000000000c1";
const CLASS_A = "4f310000-0000-4000-8000-0000000000d1";

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
      (${USER_A}::uuid, 'auth031.a@synthetic.studafy.test',
       'synthetic-not-a-secret', 'authenticated', 'authenticated', now(),
       now(), now(), '00000000-0000-0000-0000-000000000000',
       '', '', '', '', '', '', '{}'::jsonb, '{"full_name":"AUTH-031 A"}'::jsonb),
      (${USER_B}::uuid, 'auth031.b@synthetic.studafy.test',
       'synthetic-not-a-secret', 'authenticated', 'authenticated', now(),
       now(), now(), '00000000-0000-0000-0000-000000000000',
       '', '', '', '', '', '', '{}'::jsonb, '{"full_name":"AUTH-031 B"}'::jsonb)
    on conflict (id) do nothing
  `;
  await sql`
    insert into public.schools (id, name, timezone, status)
    values
      (${SCHOOL_A}::uuid, 'AUTH-031 School A', 'Asia/Riyadh', 'active'),
      (${SCHOOL_B}::uuid, 'AUTH-031 School B', 'Asia/Riyadh', 'active')
    on conflict (id) do update set status = 'active'
  `;
  await sql`
    insert into public.memberships (school_id, user_id, role, active, status)
    values
      (${SCHOOL_A}::uuid, ${USER_A}::uuid, 'teacher', true, 'active'),
      (${SCHOOL_B}::uuid, ${USER_B}::uuid, 'teacher', true, 'active')
    on conflict (school_id, user_id, role) do update
      set active = true, status = 'active'
  `;
  await sql`
    insert into public.terms (
      id, school_id, name, starts_on, ends_on, active, status
    ) values (
      ${TERM_A}::uuid, ${SCHOOL_A}::uuid, 'AUTH-031 Term',
      current_date - 30, current_date + 30, true, 'active'
    ) on conflict (id) do update set active = true, status = 'active'
  `;
  await sql`
    insert into public.classrooms (
      id, school_id, term_id, name, teacher_id, status
    ) values (
      ${CLASS_A}::uuid, ${SCHOOL_A}::uuid, ${TERM_A}::uuid,
      'AUTH-031 Class', ${USER_A}::uuid, 'active'
    ) on conflict (id) do update set status = 'active'
  `;
  await sql`
    insert into public.classroom_staff (
      school_id, classroom_id, membership_id, user_id, role, status
    )
    select ${SCHOOL_A}::uuid, ${CLASS_A}::uuid, m.id,
      ${USER_A}::uuid, 'lead_teacher', 'active'
    from public.memberships m
    where m.school_id = ${SCHOOL_A}::uuid and m.user_id = ${USER_A}::uuid
    on conflict do nothing
  `;
}

async function cleanup(): Promise<void> {
  await sql`delete from public.classroom_staff where classroom_id = ${CLASS_A}::uuid`;
  await sql`delete from public.classrooms where id = ${CLASS_A}::uuid`;
  await sql`delete from public.terms where id = ${TERM_A}::uuid`;
  await sql`delete from public.memberships where user_id in (${USER_A}::uuid, ${USER_B}::uuid)`;
  await sql`delete from public.schools where id in (${SCHOOL_A}::uuid, ${SCHOOL_B}::uuid)`;
  await sql`delete from auth.users where id in (${USER_A}::uuid, ${USER_B}::uuid)`;
}

async function directRls(subject: string): Promise<boolean> {
  return await sql.begin(async (tx) => {
    await tx`set local role authenticated`;
    await tx`select set_config('request.jwt.claim.sub', ${subject}, true)`;
    const rows = await tx<{ allowed: boolean }[]>`
      select exists(
        select 1 from public.classrooms where id = ${CLASS_A}::uuid
      ) as allowed
    `;
    return rows[0]?.allowed ?? false;
  }) as boolean;
}

suite("/v1 authorization and DB-021 RLS parity", () => {
  beforeAll(async () => {
    sql = createDatabase(databaseUrl!);
    await cleanup();
    await seed();
    contexts = new AuthContextRepository(sql);
    const repository = new PostgresAuthorizationRepository(sql);
    const logger = createJsonLogger(
      "api",
      "auth031-integration",
      "debug" as LogLevel,
      () => undefined,
    );
    const cache = new VersionedTenantContextCache({ ttlMs: 60_000 });

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
    app.get(
      "/v1/test/classrooms/:id",
      requirePermission(
        { repository, cache, logger },
        "classroom.read",
        (c) => c.req.param("id") ?? null,
      ),
      (c) => c.json({ school_id: c.get("authorization").tenant?.schoolId }),
    );
  });

  afterAll(async () => {
    if (!sql) return;
    await cleanup();
    await sql.end({ timeout: 5 });
  });

  test("assigned relationship succeeds identically through /v1 and RLS", async () => {
    const response = await app.request(`/v1/test/classrooms/${CLASS_A}`, {
      headers: { "x-test-subject": USER_A, "x-school-id": SCHOOL_B },
    });
    expect(response.status === 200).toBe(await directRls(USER_A));
    expect(response.status).toBe(200);
    expect(await response.json()).toEqual({ school_id: SCHOOL_A });
  });

  test("cross-tenant identifier substitution is denied identically", async () => {
    const response = await app.request(`/v1/test/classrooms/${CLASS_A}`, {
      headers: { "x-test-subject": USER_B, "x-school-id": SCHOOL_A },
    });
    expect(response.status === 200).toBe(await directRls(USER_B));
    expect(response.status).toBe(404);
  });

  test("membership revocation invalidates cached context on the next request", async () => {
    expect(
      (await app.request(`/v1/test/classrooms/${CLASS_A}`, {
        headers: { "x-test-subject": USER_A },
      })).status,
    ).toBe(200);

    await sql`
      update public.memberships
      set active = false, status = 'revoked', version = version + 1
      where school_id = ${SCHOOL_A}::uuid and user_id = ${USER_A}::uuid
    `;

    const response = await app.request(`/v1/test/classrooms/${CLASS_A}`, {
      headers: { "x-test-subject": USER_A },
    });
    expect(response.status === 200).toBe(await directRls(USER_A));
    expect(response.status).toBe(404);
  });
});
