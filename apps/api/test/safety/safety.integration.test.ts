/**
 * SAFE-043 end-to-end proof against a real local Postgres. The exhaustive
 * state-machine and masking coverage lives in supabase/tests/safe043_surface.sql;
 * this file proves the HTTP layer (route paths, permission middleware,
 * slice gating, idempotency, response-schema validation, and that AAL2 for
 * the moderator JIT session has to come from the session, not a body field)
 * on top of it. The operator-only hold backstop is asserted here too: a
 * school admin passes the authorisation layer, and the SQL dispatcher still
 * refuses the hold, returning 403.
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
import { PostgresSafetyRepository } from "../../src/safety/repository";
import { createSafetyRoutes } from "../../src/safety/routes";

const databaseUrl = process.env["DATABASE_URL"];
const suite = databaseUrl ? describe : describe.skip;

const OPERATOR_A = "5f4a0000-0000-4000-8000-0000000000a1";
const OPERATOR_B = "5f4a0000-0000-4000-8000-0000000000a2";
const ADMIN = "5f4a0000-0000-4000-8000-0000000000a3";
const TEACHER = "5f4a0000-0000-4000-8000-0000000000a4";
const STUDENT = "5f4a0000-0000-4000-8000-0000000000a5";
const SCHOOL = "5f4a0000-0000-4000-8000-0000000000b1";

const CURSOR_KEY = "safe043-safety-integration-cursor-key-01";

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
      (${OPERATOR_A}::uuid, 'safe043.operator-a@synthetic.studafy.test', 'synthetic-not-a-secret', 'authenticated', 'authenticated', now(), now(), now(), '00000000-0000-0000-0000-000000000000', '', '', '', '', '', '', '{}'::jsonb, '{"full_name":"SAFE-043 Operator A"}'::jsonb),
      (${OPERATOR_B}::uuid, 'safe043.operator-b@synthetic.studafy.test', 'synthetic-not-a-secret', 'authenticated', 'authenticated', now(), now(), now(), '00000000-0000-0000-0000-000000000000', '', '', '', '', '', '', '{}'::jsonb, '{"full_name":"SAFE-043 Operator B"}'::jsonb),
      (${ADMIN}::uuid, 'safe043.admin@synthetic.studafy.test', 'synthetic-not-a-secret', 'authenticated', 'authenticated', now(), now(), now(), '00000000-0000-0000-0000-000000000000', '', '', '', '', '', '', '{}'::jsonb, '{"full_name":"SAFE-043 Admin"}'::jsonb),
      (${TEACHER}::uuid, 'safe043.teacher@synthetic.studafy.test', 'synthetic-not-a-secret', 'authenticated', 'authenticated', now(), now(), now(), '00000000-0000-0000-0000-000000000000', '', '', '', '', '', '', '{}'::jsonb, '{"full_name":"SAFE-043 Teacher"}'::jsonb),
      (${STUDENT}::uuid, 'safe043.student@synthetic.studafy.test', 'synthetic-not-a-secret', 'authenticated', 'authenticated', now(), now(), now(), '00000000-0000-0000-0000-000000000000', '', '', '', '', '', '', '{}'::jsonb, '{"full_name":"SAFE-043 Student"}'::jsonb)
    on conflict (id) do nothing
  `;
  await sql`
    insert into public.schools (id, name, timezone, status) values (${SCHOOL}::uuid, 'SAFE-043 Safety School', 'Asia/Riyadh', 'active')
    on conflict (id) do update set status = 'active'
  `;
  await sql`
    insert into public.memberships (school_id, user_id, role, active, status, version) values
      (${SCHOOL}::uuid, ${ADMIN}::uuid, 'school_admin', true, 'active', 1),
      (${SCHOOL}::uuid, ${TEACHER}::uuid, 'teacher', true, 'active', 1),
      (${SCHOOL}::uuid, ${STUDENT}::uuid, 'student', true, 'active', 1)
    on conflict (school_id, user_id, role) do nothing
  `;
  await sql`
    insert into public.platform_operators (user_id, note) values
      (${OPERATOR_A}::uuid, 'safe043 integration fixture'),
      (${OPERATOR_B}::uuid, 'safe043 integration fixture')
    on conflict (user_id) do nothing
  `;
}

async function cleanup(): Promise<void> {
  await sql.begin(async (tx) => {
    await tx`alter table public.audit_events disable trigger db020_reject_mutation`;
    await tx`delete from public.moderation_access_grants where school_id = ${SCHOOL}::uuid`;
    await tx`delete from public.legal_holds where school_id = ${SCHOOL}::uuid`;
    await tx`delete from public.user_blocks where school_id = ${SCHOOL}::uuid`;
    await tx`delete from public.report_events where school_id = ${SCHOOL}::uuid`;
    await tx`delete from public.report_attempts where school_id = ${SCHOOL}::uuid`;
    await tx`delete from public.reports where school_id = ${SCHOOL}::uuid`;
    await tx`delete from public.audit_events where school_id = ${SCHOOL}::uuid`;
    await tx`delete from public.platform_operators where user_id in (${OPERATOR_A}::uuid, ${OPERATOR_B}::uuid)`;
    await tx`delete from public.memberships where school_id = ${SCHOOL}::uuid`;
    await tx`delete from public.schools where id = ${SCHOOL}::uuid`;
    await tx`delete from auth.users where id in (${OPERATOR_A}::uuid, ${OPERATOR_B}::uuid, ${ADMIN}::uuid, ${TEACHER}::uuid, ${STUDENT}::uuid)`;
    await tx`alter table public.audit_events enable trigger db020_reject_mutation`;
  });
}

interface RequestInput {
  method?: "GET" | "POST";
  subject: string;
  aal2?: boolean;
  key?: string;
  body?: unknown;
}

async function request(path: string, input: RequestInput): Promise<Response> {
  const headers = new Headers();
  headers.set("x-test-subject", input.subject);
  headers.set("x-test-aal2", input.aal2 ? "true" : "false");
  if ((input.method ?? "GET") === "POST") {
    headers.set("content-type", "application/json");
    headers.set("idempotency-key", input.key ?? crypto.randomUUID());
  }
  return await app.request(path, {
    method: input.method ?? "GET",
    headers,
    ...(input.body !== undefined ? { body: JSON.stringify(input.body) } : {}),
  });
}

suite("SAFE-043 safety & safeguarding over the real /v1 stack", () => {
  let reportId: string;
  let blockId: string;
  let grantId: string;

  beforeAll(async () => {
    sql = createDatabase(databaseUrl!);
    await cleanup();
    await seed();
    contexts = new AuthContextRepository(sql);
    const logger = createJsonLogger(
      "api",
      "safe043-safety-integration",
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
          assuranceLevel: c.req.header("x-test-aal2") === "true"
            ? "aal2"
            : "aal1",
          authMethods: [],
          claims: {},
        },
        context,
        aal2: c.req.header("x-test-aal2") === "true",
        mfaRequiredByPolicy: false,
      };
      c.set("requestId", crypto.randomUUID());
      c.set("actor", actor);
      await next();
    });
    app.route(
      "/",
      createSafetyRoutes(
        {
          repository: new PostgresSafetyRepository(sql),
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

  test("an active member reads the school's content-controls defaults", async () => {
    const res = await request(
      `/v1/control-panel/content-controls/${SCHOOL}`,
      { subject: TEACHER },
    );
    expect(res.status).toBe(200);
    const body = await res.json() as {
      contentFilterLevel: string;
      messagingEnabled: boolean;
      version: number;
    };
    expect(body.contentFilterLevel).toBe("strict");
    expect(body.messagingEnabled).toBe(false);
    expect(body.version).toBe(1);
  });

  test("the school admin asserts a policy and the teacher sees it", async () => {
    const res = await request(
      `/v1/control-panel/content-controls/${SCHOOL}`,
      {
        method: "POST",
        subject: ADMIN,
        body: {
          expectedVersion: 1,
          messagingEnabled: true,
          contentFilterLevel: "moderate",
          classifierAssistEnabled: true,
          supportContact: "safeguarding@seed.test",
        },
      },
    );
    expect(res.status).toBe(200);
    const body = await res.json() as {
      contentFilterLevel: string;
      version: number;
    };
    expect(body.contentFilterLevel).toBe("moderate");
    expect(body.version).toBe(2);

    const read = await request(
      `/v1/control-panel/content-controls/${SCHOOL}`,
      { subject: TEACHER },
    );
    expect(read.status).toBe(200);
    expect((await read.json() as { supportContact: string }).supportContact)
      .toBe("safeguarding@seed.test");
  });

  test("a student files a report and reads it back", async () => {
    const res = await request("/v1/reports", {
      method: "POST",
      subject: STUDENT,
      body: {
        schoolId: SCHOOL,
        kind: "user",
        subjectUserId: TEACHER,
        details: "She said she would hurt you if you keep talking to me",
      },
    });
    expect(res.status).toBe(201);
    const created = await res.json() as { id: string; status: string };
    expect(created.status).toBe("queued");
    reportId = created.id;

    const read = await request(`/v1/reports/${reportId}`, {
      subject: STUDENT,
    });
    expect(read.status).toBe(200);
    const body = await read.json() as { id: string; subjectUserId: string };
    expect(body.id).toBe(reportId);
    expect(body.subjectUserId).toBe(TEACHER);
  });

  test("a teacher without moderation role cannot open the school's queue", async () => {
    const res = await request(
      `/internal/moderation/queue?schoolId=${SCHOOL}`,
      { subject: TEACHER },
    );
    expect(res.status).toBe(404);
  });

  test("the school admin sees the queue and the overview, masked", async () => {
    const queue = await request(
      `/internal/moderation/queue?schoolId=${SCHOOL}`,
      { subject: ADMIN },
    );
    expect(queue.status).toBe(200);
    const queueBody = await queue.json() as {
      items: { id: string; reporterId: string | null }[];
    };
    expect(queueBody.items.length).toBe(1);
    expect(queueBody.items[0]!.id).toBe(reportId);
    expect(queueBody.items[0]!.reporterId).toBeNull();

    const overview = await request(
      `/internal/moderation/overview?schoolId=${SCHOOL}`,
      { subject: ADMIN },
    );
    expect(overview.status).toBe(200);
    const overviewBody = await overview.json() as { submitted: number };
    expect(overviewBody.submitted).toBe(1);
  });

  test("triage, resolve, appeal, and escalate move the report along; escalation unmasks the reporter", async () => {
    const triage = await request(`/internal/moderation/reports/${reportId}/triage`, {
      method: "POST",
      subject: ADMIN,
      body: {
        expectedVersion: 1,
        priority: "critical",
        note: "assigned to reviewer",
      },
    });
    expect(triage.status).toBe(200);
    expect((await triage.json() as { status: string }).status).toBe("under_review");

    const resolve = await request(`/internal/moderation/reports/${reportId}/resolve`, {
      method: "POST",
      subject: ADMIN,
      body: { expectedVersion: 2, resolution: "upheld", note: "upskilling" },
    });
    expect(resolve.status).toBe(200);
    expect((await resolve.json() as { resolution: string }).resolution).toBe("upheld");

    const appeal = await request(`/v1/reports/${reportId}/appeal`, {
      method: "POST",
      subject: STUDENT,
      body: {
        expectedVersion: 3,
        reason: "the reported concern was never actionable",
      },
    });
    expect(appeal.status).toBe(200);
    expect((await appeal.json() as { status: string }).status).toBe("under_review");

    const escalate = await request(`/internal/moderation/reports/${reportId}/escalate`, {
      method: "POST",
      subject: ADMIN,
      body: { expectedVersion: 4, note: "platform operator review" },
    });
    expect(escalate.status).toBe(200);
    const escalated = await escalate.json() as { reporterId: string | null };
    expect(escalated.reporterId).toBe(STUDENT);
  });

  test("a school admin may pass authorisation but the SQL dispatcher still refuses a legal hold", async () => {
    const res = await request(`/internal/moderation/reports/${reportId}/hold`, {
      method: "POST",
      subject: ADMIN,
      body: {
        schoolId: SCHOOL,
        expectedVersion: 5,
        appliedTo: "report",
        reason: "court order retention",
        ticketRef: "LEG-HTTP-1",
      },
    });
    expect(res.status).toBe(403);
  });

  test("an operator without MFA cannot request a moderator session", async () => {
    const res = await request("/internal/moderation/access", {
      method: "POST",
      subject: OPERATOR_A,
      aal2: false,
      body: {
        schoolId: SCHOOL,
        reason: "uncovered review window",
        ticketRef: "TICK-HTTP-1",
        durationMinutes: 60,
      },
    });
    expect(res.status).toBe(403);
  });

  test("an operator with a fresh MFA step requests moderation access", async () => {
    const res = await request("/internal/moderation/access", {
      method: "POST",
      subject: OPERATOR_A,
      aal2: true,
      body: {
        schoolId: SCHOOL,
        reason: "uncovered review window",
        ticketRef: "TICK-HTTP-2",
        durationMinutes: 60,
      },
    });
    expect(res.status).toBe(201);
    const body = await res.json() as { id: string; status: string };
    expect(body.status).toBe("pending");
    grantId = body.id;
  });

  test("the requester cannot approve their own grant", async () => {
    const res = await request(
      `/internal/moderation/access/${grantId}/approve`,
      {
        method: "POST",
        subject: OPERATOR_A,
        aal2: true,
        body: { expectedVersion: 1 },
      },
    );
    expect(res.status).toBe(404);
  });

  test("a second operator with a fresh MFA step approves, and the requester starts and revokes", async () => {
    const approve = await request(
      `/internal/moderation/access/${grantId}/approve`,
      {
        method: "POST",
        subject: OPERATOR_B,
        aal2: true,
        body: { expectedVersion: 1 },
      },
    );
    expect(approve.status).toBe(200);
    expect((await approve.json() as { status: string }).status).toBe("approved");

    const start = await request(
      `/internal/moderation/access/${grantId}/start`,
      {
        method: "POST",
        subject: OPERATOR_A,
        aal2: true,
        body: { expectedVersion: 1 },
      },
    );
    expect(start.status).toBe(200);
    const started = await start.json() as {
      status: string;
      startedAt: string | null;
    };
    expect(started.status).toBe("active");
    expect(started.startedAt).not.toBeNull();

    const revoke = await request(
      `/internal/moderation/access/${grantId}/revoke`,
      {
        method: "POST",
        subject: OPERATOR_A,
        aal2: true,
        body: { expectedVersion: 2, reason: "coverage resolved" },
      },
    );
    expect(revoke.status).toBe(200);
    expect((await revoke.json() as { status: string }).status).toBe("revoked");

    const revived = await request(
      `/internal/moderation/access/${grantId}/revoke`,
      {
        method: "POST",
        subject: OPERATOR_A,
        aal2: true,
        body: { expectedVersion: 3 },
      },
    );
    expect(revived.status).toBe(409);
  });

  test("blocks are created and unblocked over the HTTP surface", async () => {
    const created = await request("/v1/blocks", {
      method: "POST",
      subject: TEACHER,
      body: {
        schoolId: SCHOOL,
        blockedUserId: STUDENT,
        scope: "messages",
        reason: "avoiding off-topic pings",
        durationHours: 24,
      },
    });
    expect(created.status).toBe(201);
    const block = await created.json() as {
      id: string;
      blockerId: string;
      blockedId: string;
    };
    expect(block.blockerId).toBe(TEACHER);
    expect(block.blockedId).toBe(STUDENT);
    blockId = block.id;

    const unblock = await request(`/v1/blocks/${blockId}/unblock`, {
      method: "POST",
      subject: TEACHER,
    });
    expect(unblock.status).toBe(200);
  });
});