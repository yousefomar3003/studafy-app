/**
 * The platform operator's safety review in the app (DL-063), over the real
 * /v1 stack and a real local Postgres: who is an operator, the metadata-only
 * queue, opening a report under a grant (audited, MFA-gated), and triage and
 * resolution by an operator who holds no membership in the report's school.
 * Single-reviewer self-approval is proven in supabase/tests; here the
 * fixture has two operators, so the second operator approves.
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
import { integrationSuite, removeFixtures } from "@studafy/test-support";

const databaseUrl = process.env["DATABASE_URL"];
const suite = integrationSuite(describe);

const OPERATOR_A = "5f4b0000-0000-4000-8000-0000000000a1";
const OPERATOR_B = "5f4b0000-0000-4000-8000-0000000000a2";
const TEACHER = "5f4b0000-0000-4000-8000-0000000000a4";
const STUDENT = "5f4b0000-0000-4000-8000-0000000000a5";
const SCHOOL = "5f4b0000-0000-4000-8000-0000000000b1";

const CURSOR_KEY = "safety-review-integration-cursor-key-000000000000000000";

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
      (${OPERATOR_A}::uuid, 'safety-review.operator-a@synthetic.studafy.test', 'synthetic-not-a-secret', 'authenticated', 'authenticated', now(), now(), now(), '00000000-0000-0000-0000-000000000000', '', '', '', '', '', '', '{}'::jsonb, '{"full_name":"Safety Review Operator A"}'::jsonb),
      (${OPERATOR_B}::uuid, 'safety-review.operator-b@synthetic.studafy.test', 'synthetic-not-a-secret', 'authenticated', 'authenticated', now(), now(), now(), '00000000-0000-0000-0000-000000000000', '', '', '', '', '', '', '{}'::jsonb, '{"full_name":"Safety Review Operator B"}'::jsonb),
      (${TEACHER}::uuid, 'safety-review.teacher@synthetic.studafy.test', 'synthetic-not-a-secret', 'authenticated', 'authenticated', now(), now(), now(), '00000000-0000-0000-0000-000000000000', '', '', '', '', '', '', '{}'::jsonb, '{"full_name":"Safety Review Teacher"}'::jsonb),
      (${STUDENT}::uuid, 'safety-review.student@synthetic.studafy.test', 'synthetic-not-a-secret', 'authenticated', 'authenticated', now(), now(), now(), '00000000-0000-0000-0000-000000000000', '', '', '', '', '', '', '{}'::jsonb, '{"full_name":"Safety Review Student"}'::jsonb)
    on conflict (id) do nothing
  `;
  await sql`
    insert into public.schools (id, name, timezone, status) values (${SCHOOL}::uuid, 'Safety Review School', 'Asia/Riyadh', 'active')
    on conflict (id) do update set status = 'active'
  `;
  await sql`
    insert into public.memberships (school_id, user_id, role, active, status, version) values
      (${SCHOOL}::uuid, ${TEACHER}::uuid, 'teacher', true, 'active', 1),
      (${SCHOOL}::uuid, ${STUDENT}::uuid, 'student', true, 'active', 1)
    on conflict (school_id, user_id, role) do nothing
  `;
  await sql`
    insert into public.platform_operators (user_id, note) values
      (${OPERATOR_A}::uuid, 'safety review integration fixture'),
      (${OPERATOR_B}::uuid, 'safety review integration fixture')
    on conflict (user_id) do nothing
  `;
  // A user report needs messaging on in the school.
  await sql`
    select private.ensure_school_safety_defaults(${SCHOOL}::uuid)
  `;
  await sql`
    update public.school_content_controls set messaging_enabled = true
    where school_id = ${SCHOOL}::uuid
  `;
}

async function cleanup(): Promise<void> {
  await removeFixtures(sql, {
    schoolIds: [SCHOOL],
    userIds: [OPERATOR_A, OPERATOR_B, TEACHER, STUDENT],
  });
}

interface RequestInput {
  method?: "GET" | "POST";
  subject: string;
  aal2?: boolean;
  body?: unknown;
}

async function request(path: string, input: RequestInput): Promise<Response> {
  const headers = new Headers();
  headers.set("x-test-subject", input.subject);
  headers.set("x-test-aal2", (input.aal2 ?? true) ? "true" : "false");
  if ((input.method ?? "GET") === "POST") {
    headers.set("content-type", "application/json");
    headers.set("idempotency-key", crypto.randomUUID());
  }
  return await app.request(path, {
    method: input.method ?? "GET",
    headers,
    ...(input.body !== undefined ? { body: JSON.stringify(input.body) } : {}),
  });
}

interface QueueItem {
  id: string;
  schoolId: string;
  kind: string;
  priority: string;
  status: string;
  createdAt: string;
  grantActive: boolean;
}

async function queue(subject: string, aal2 = false) {
  const res = await request("/internal/safety-review/reports", {
    subject,
    aal2,
  });
  return {
    status: res.status,
    body: res.status === 200
      ? await res.json() as {
        items: QueueItem[];
        nextCursor: string | null;
        singleReviewer: boolean;
      }
      : null,
  };
}

suite("the operator's safety review over the real /v1 stack", () => {
  let reportId: string;
  let grantId: string;

  beforeAll(async () => {
    sql = createDatabase(databaseUrl!);
    await cleanup();
    await seed();
    contexts = new AuthContextRepository(sql);
    const logger = createJsonLogger(
      "api",
      "safety-review-integration",
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
      const aal2 = c.req.header("x-test-aal2") === "true";
      const actor: Actor = {
        token: {
          subject,
          sessionId: null,
          issuedAt: 1,
          expiresAt: 4_000_000_000,
          assuranceLevel: aal2 ? "aal2" : "aal1",
          authMethods: [],
          claims: {},
        },
        context,
        aal2,
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

    const filed = await request("/v1/reports", {
      method: "POST",
      subject: STUDENT,
      aal2: false,
      body: {
        schoolId: SCHOOL,
        kind: "user",
        subjectUserId: TEACHER,
        details: "He keeps sending me messages after I asked him to stop",
      },
    });
    expect(filed.status).toBe(201);
    reportId = (await filed.json() as { id: string }).id;
  });

  afterAll(async () => {
    if (!sql) return;
    await cleanup();
    await sql.end({ timeout: 5 });
  });

  test("the session context says who is a platform operator", async () => {
    expect((await contexts.load(OPERATOR_A))?.platformOperator).toBe(true);
    expect((await contexts.load(TEACHER))?.platformOperator).toBe(false);
  });

  test("a school member cannot list the queue or open a report", async () => {
    expect((await queue(TEACHER)).status).toBe(403);
    const open = await request(`/internal/safety-review/reports/${reportId}`, {
      subject: TEACHER,
    });
    expect(open.status).toBe(403);
  });

  test("an operator lists open reports as metadata only, without MFA", async () => {
    const { status, body } = await queue(OPERATOR_A);
    expect(status).toBe(200);
    const item = body!.items.find((row) => row.id === reportId)!;
    expect(Object.keys(item).sort()).toEqual([
      "createdAt",
      "grantActive",
      "id",
      "kind",
      "priority",
      "schoolId",
      "status",
    ]);
    expect(item.schoolId).toBe(SCHOOL);
    expect(item.kind).toBe("user");
    expect(item.grantActive).toBe(false);
    // Two operators: every grant needs a second approver.
    expect(body!.singleReviewer).toBe(false);
  });

  test("opening a report needs MFA, then a grant", async () => {
    const path = `/internal/safety-review/reports/${reportId}`;
    const aal1 = await request(path, { subject: OPERATOR_A, aal2: false });
    expect(aal1.status).toBe(403);
    expect((await aal1.json() as { code: string }).code).toBe("MFA_REQUIRED");
    const noGrant = await request(path, { subject: OPERATOR_A });
    expect(noGrant.status).toBe(403);
    expect((await noGrant.json() as { code: string }).code).toBe("FORBIDDEN");
  });

  test("with two operators a self-approved grant is refused, and the other operator approves", async () => {
    const requested = await request("/internal/moderation/access", {
      method: "POST",
      subject: OPERATOR_A,
      body: {
        schoolId: SCHOOL,
        reason: "Report alert received in the safety channel",
        ticketRef: reportId,
        resourceScope: { reportIds: [reportId] },
        requiresSecondApprover: false,
        durationMinutes: 60,
      },
    });
    expect(requested.status).toBe(201);
    grantId = (await requested.json() as { id: string }).id;

    const self = await request(
      `/internal/moderation/access/${grantId}/approve`,
      { method: "POST", subject: OPERATOR_A, body: { expectedVersion: 1 } },
    );
    expect(self.status).toBe(404);

    const approved = await request(
      `/internal/moderation/access/${grantId}/approve`,
      { method: "POST", subject: OPERATOR_B, body: { expectedVersion: 1 } },
    );
    expect(approved.status).toBe(200);
    const started = await request(
      `/internal/moderation/access/${grantId}/start`,
      { method: "POST", subject: OPERATOR_A, body: { expectedVersion: 2 } },
    );
    expect(started.status).toBe(200);
  });

  test("under the grant the operator reads, triages and resolves the report with no membership", async () => {
    const { body } = await queue(OPERATOR_A);
    expect(body!.items.find((row) => row.id === reportId)!.grantActive).toBe(
      true,
    );

    const opened = await request(
      `/internal/safety-review/reports/${reportId}`,
      { subject: OPERATOR_A },
    );
    expect(opened.status).toBe(200);
    const report = await opened.json() as {
      details: string;
      reporterId: string | null;
      version: number;
      status: string;
    };
    expect(report.details).toBe(
      "He keeps sending me messages after I asked him to stop",
    );
    expect(report.reporterId).toBeNull();

    const teacherTriage = await request(
      `/internal/moderation/reports/${reportId}/triage`,
      {
        method: "POST",
        subject: TEACHER,
        body: { expectedVersion: report.version },
      },
    );
    expect(teacherTriage.status).toBe(404);

    const triaged = await request(
      `/internal/moderation/reports/${reportId}/triage`,
      {
        method: "POST",
        subject: OPERATOR_A,
        body: { expectedVersion: report.version, note: "Opened in the app" },
      },
    );
    expect(triaged.status).toBe(200);
    const underReview = await triaged.json() as {
      status: string;
      version: number;
    };
    expect(underReview.status).toBe("under_review");

    const resolved = await request(
      `/internal/moderation/reports/${reportId}/resolve`,
      {
        method: "POST",
        subject: OPERATOR_A,
        body: {
          expectedVersion: underReview.version,
          resolution: "upheld",
          note: "Sender warned; messages removed.",
        },
      },
    );
    expect(resolved.status).toBe(200);
    expect((await resolved.json() as { status: string }).status).toBe(
      "resolved",
    );

    const after = await queue(OPERATOR_A);
    expect(after.body!.items.some((row) => row.id === reportId)).toBe(false);

    const audit = await sql<{ action: string; via: string | null }[]>`
      select action, after_value->>'via' as via from public.audit_events
      where entity_type = 'report' and entity_id = ${reportId}::uuid
      order by id
    `;
    expect(audit.map((row) => `${row.action}:${row.via ?? "-"}`)).toEqual([
      "report_submitted:-",
      "report_review_refused:app",
      "report_review_opened:app",
      "report_triaged:-",
      "report_resolved:-",
    ]);
  });

  test("a grant that has ended closes the report again", async () => {
    // Expiry is lazy and its clock cannot be moved here (created_at is
    // immutable), so the grant is ended the other way: revoked.
    const revoked = await request(
      `/internal/moderation/access/${grantId}/revoke`,
      {
        method: "POST",
        subject: OPERATOR_A,
        body: { expectedVersion: 3, reason: "review finished" },
      },
    );
    expect(revoked.status).toBe(200);
    const res = await request(`/internal/safety-review/reports/${reportId}`, {
      subject: OPERATOR_A,
    });
    expect(res.status).toBe(403);
    const { body } = await queue(OPERATOR_A);
    expect(body!.items.every((row) => !row.grantActive)).toBe(true);
  });
});
