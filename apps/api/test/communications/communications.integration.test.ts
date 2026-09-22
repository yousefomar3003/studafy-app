/**
 * API-042 S4 end-to-end proof against a real local Postgres. The exhaustive
 * state-machine coverage lives in supabase/tests/api042_communications.sql;
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
import { PostgresCommunicationsRepository } from "../../src/communications/repository";
import {
  createCommunicationsRoutes,
  createContactsRoutes,
} from "../../src/communications/routes";

const databaseUrl = process.env["DATABASE_URL"];
const suite = databaseUrl ? describe : describe.skip;

const ADMIN = "5f450000-0000-4000-8000-0000000000a1";
const TEACHER = "5f450000-0000-4000-8000-0000000000a2";
const GUARDIAN = "5f450000-0000-4000-8000-0000000000a3";
const SCHOOL = "5f450000-0000-4000-8000-0000000000b1";
const STUDENT_USER = "5f450000-0000-4000-8000-0000000000a4";
const STUDENT_ROW = "5f450000-0000-4000-8000-0000000000c1";
// A second family: its child is someone GUARDIAN must not be able to reach.
const OTHER_STUDENT_USER = "5f450000-0000-4000-8000-0000000000a5";
const OTHER_STUDENT_ROW = "5f450000-0000-4000-8000-0000000000c2";

const CURSOR_KEY = "api042-comms-integration-cursor-key-0000000001";

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
      (${ADMIN}::uuid, 'api042.comms.admin@synthetic.studafy.test', 'synthetic-not-a-secret', 'authenticated', 'authenticated', now(), now(), now(), '00000000-0000-0000-0000-000000000000', '', '', '', '', '', '', '{}'::jsonb, '{"full_name":"API-042 Comms Admin"}'::jsonb),
      (${TEACHER}::uuid, 'api042.comms.teacher@synthetic.studafy.test', 'synthetic-not-a-secret', 'authenticated', 'authenticated', now(), now(), now(), '00000000-0000-0000-0000-000000000000', '', '', '', '', '', '', '{}'::jsonb, '{"full_name":"API-042 Comms Teacher"}'::jsonb),
      (${GUARDIAN}::uuid, 'api042.comms.guardian@synthetic.studafy.test', 'synthetic-not-a-secret', 'authenticated', 'authenticated', now(), now(), now(), '00000000-0000-0000-0000-000000000000', '', '', '', '', '', '', '{}'::jsonb, '{"full_name":"API-042 Comms Guardian"}'::jsonb),
      (${STUDENT_USER}::uuid, 'api042.comms.student@synthetic.studafy.test', 'synthetic-not-a-secret', 'authenticated', 'authenticated', now(), now(), now(), '00000000-0000-0000-0000-000000000000', '', '', '', '', '', '', '{}'::jsonb, '{"full_name":"API-042 Comms Student"}'::jsonb),
      (${OTHER_STUDENT_USER}::uuid, 'api042.comms.student2@synthetic.studafy.test', 'synthetic-not-a-secret', 'authenticated', 'authenticated', now(), now(), now(), '00000000-0000-0000-0000-000000000000', '', '', '', '', '', '', '{}'::jsonb, '{"full_name":"API-042 Other Student"}'::jsonb)
    on conflict (id) do nothing
  `;
  await sql`
    insert into public.schools (id, name, timezone, status) values (${SCHOOL}::uuid, 'API-042 Comms School', 'Asia/Riyadh', 'active')
    on conflict (id) do update set status = 'active'
  `;
  await sql`
    insert into public.memberships (school_id, user_id, role, active, status, version) values
      (${SCHOOL}::uuid, ${ADMIN}::uuid, 'school_admin', true, 'active', 1),
      (${SCHOOL}::uuid, ${TEACHER}::uuid, 'teacher', true, 'active', 1),
      (${SCHOOL}::uuid, ${STUDENT_USER}::uuid, 'student', true, 'active', 1),
      (${SCHOOL}::uuid, ${OTHER_STUDENT_USER}::uuid, 'student', true, 'active', 1)
    on conflict (school_id, user_id, role) do nothing
  `;
  await sql`
    insert into public.students (id, school_id, user_id, studafy_id, display_name, provisional, created_by) values
      (${STUDENT_ROW}::uuid, ${SCHOOL}::uuid, ${STUDENT_USER}::uuid, 'STU-API042-COMMS', 'Comms Integration Student', false, ${ADMIN}::uuid),
      (${OTHER_STUDENT_ROW}::uuid, ${SCHOOL}::uuid, ${OTHER_STUDENT_USER}::uuid, 'STU-API042-COMMS2', 'Comms Other Student', false, ${ADMIN}::uuid)
    on conflict (id) do nothing
  `;
  await sql`
    insert into public.guardian_links (school_id, student_id, guardian_id, status, relationship, verified_by, verified_at) values
      (${SCHOOL}::uuid, ${STUDENT_ROW}::uuid, ${GUARDIAN}::uuid, 'verified', 'parent', ${ADMIN}::uuid, now())
    on conflict (student_id, guardian_id) do nothing
  `;
}

async function cleanup(): Promise<void> {
  await sql.begin(async (tx) => {
    await tx`alter table public.audit_events disable trigger db020_reject_mutation`;
    await tx`alter table public.messages disable trigger db020_reject_mutation`;
    await tx`delete from public.notification_deliveries where school_id = ${SCHOOL}::uuid`;
    await tx`delete from public.notification_outbox where school_id = ${SCHOOL}::uuid`;
    await tx`delete from public.school_content_controls where school_id = ${SCHOOL}::uuid`;
    await tx`delete from public.messages where school_id = ${SCHOOL}::uuid`;
    await tx`delete from public.conversation_participants where school_id = ${SCHOOL}::uuid`;
    await tx`delete from public.conversations where school_id = ${SCHOOL}::uuid`;
    await tx`delete from public.announcements where school_id = ${SCHOOL}::uuid`;
    await tx`delete from public.guardian_links where student_id in (${STUDENT_ROW}::uuid, ${OTHER_STUDENT_ROW}::uuid)`;
    await tx`delete from public.audit_events where school_id = ${SCHOOL}::uuid`;
    await tx`delete from public.students where id in (${STUDENT_ROW}::uuid, ${OTHER_STUDENT_ROW}::uuid)`;
    await tx`delete from public.memberships where school_id = ${SCHOOL}::uuid`;
    await tx`delete from public.schools where id = ${SCHOOL}::uuid`;
    await tx`delete from auth.users where id in (${ADMIN}::uuid, ${TEACHER}::uuid, ${GUARDIAN}::uuid, ${STUDENT_USER}::uuid, ${OTHER_STUDENT_USER}::uuid)`;
    await tx`alter table public.messages enable trigger db020_reject_mutation`;
    await tx`alter table public.audit_events enable trigger db020_reject_mutation`;
  });
}

interface RequestInput {
  method?: "GET" | "POST";
  subject: string;
  key?: string;
  body?: unknown;
}

async function request(path: string, input: RequestInput): Promise<Response> {
  const headers = new Headers();
  headers.set("x-test-subject", input.subject);
  if (input.body !== undefined) headers.set("content-type", "application/json");
  if ((input.method ?? "GET") === "POST") {
    headers.set("idempotency-key", input.key ?? crypto.randomUUID());
  }
  return await app.request(path, {
    method: input.method ?? "GET",
    headers,
    ...(input.body !== undefined ? { body: JSON.stringify(input.body) } : {}),
  });
}

suite("API-042 S4 communications over the real /v1 stack", () => {
  let conversationId: string;

  beforeAll(async () => {
    sql = createDatabase(databaseUrl!);
    await cleanup();
    await seed();
    contexts = new AuthContextRepository(sql);
    const logger = createJsonLogger(
      "api",
      "api042-comms-integration",
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
    const commsDeps = {
      repository: new PostgresCommunicationsRepository(sql),
      cursorSigningKey: CURSOR_KEY,
    };
    app.route(
      "/",
      createCommunicationsRoutes(commsDeps, authorization, idempotency),
    );
    app.route("/", createContactsRoutes(commsDeps, authorization, idempotency));
  });

  afterAll(async () => {
    if (!sql) return;
    await cleanup();
    await sql.end({ timeout: 5 });
  });

  test("no conversation can start while the school's messaging switch is off", async () => {
    const res = await request("/v1/conversations", {
      method: "POST",
      subject: TEACHER,
      body: { schoolId: SCHOOL, participantIds: [GUARDIAN] },
    });
    expect(res.status).toBe(403);
    expect((await res.json() as { code: string }).code).toBe(
      "MESSAGING_DISABLED",
    );
    await sql`
      insert into public.school_content_controls (school_id, messaging_enabled)
      values (${SCHOOL}::uuid, true)
      on conflict (school_id) do update set messaging_enabled = true
    `;
  });

  test("a guardian cannot open a conversation with another family's child", async () => {
    const res = await request("/v1/conversations", {
      method: "POST",
      subject: GUARDIAN,
      body: { schoolId: SCHOOL, participantIds: [OTHER_STUDENT_USER] },
    });
    expect(res.status).toBe(403);
    expect((await res.json() as { code: string }).code).toBe(
      "CONTACT_NOT_ALLOWED",
    );
  });

  test("students cannot open conversations with each other", async () => {
    const res = await request("/v1/conversations", {
      method: "POST",
      subject: STUDENT_USER,
      body: { schoolId: SCHOOL, participantIds: [OTHER_STUDENT_USER] },
    });
    expect(res.status).toBe(403);
  });

  test("a guardian's contacts are staff and their own child only", async () => {
    const res = await request(`/v1/contacts?schoolId=${SCHOOL}`, {
      subject: GUARDIAN,
    });
    expect(res.status).toBe(200);
    const body = await res.json() as {
      items: { userId: string; role: string; relatedStudentNames: string[] }[];
    };
    const ids = body.items.map((item) => item.userId).sort();
    expect(ids).toEqual([ADMIN, TEACHER, STUDENT_USER].sort());
    expect(body.items.every((item) => item.relatedStudentNames.length === 0))
      .toBe(true);
  });

  test("staff see which child a guardian contact belongs to", async () => {
    const res = await request(`/v1/contacts?schoolId=${SCHOOL}`, {
      subject: TEACHER,
    });
    const body = await res.json() as {
      items: { userId: string; relatedStudentNames: string[] }[];
    };
    expect(
      body.items.find((item) => item.userId === GUARDIAN)?.relatedStudentNames,
    ).toEqual(["Comms Integration Student"]);
  });

  test("staff see the child's id, not only their name", async () => {
    // A roster maps a child to their guardians. Two children in one class can
    // share a display name, so matching on name alone would attach one
    // family's contact to the other child's record.
    const res = await request(`/v1/contacts?schoolId=${SCHOOL}`, {
      subject: TEACHER,
    });
    const body = await res.json() as {
      items: { userId: string; relatedStudentIds: string[] }[];
    };
    expect(
      body.items.find((item) => item.userId === GUARDIAN)?.relatedStudentIds,
    ).toEqual([STUDENT_ROW]);
  });

  test("a guardian is told no student ids at all", async () => {
    // The ids are a staff projection; nobody else learns about other families.
    const res = await request(`/v1/contacts?schoolId=${SCHOOL}`, {
      subject: GUARDIAN,
    });
    const body = await res.json() as {
      items: { relatedStudentIds: string[] }[];
    };
    expect(body.items.every((item) => item.relatedStudentIds.length === 0))
      .toBe(true);
  });

  test("a teacher creates a conversation with a verified guardian", async () => {
    const res = await request("/v1/conversations", {
      method: "POST",
      subject: TEACHER,
      body: {
        schoolId: SCHOOL,
        subject: "About homework",
        participantIds: [GUARDIAN],
      },
    });
    expect(res.status).toBe(201);
    const body = await res.json() as {
      id: string;
      state: string;
      participants: { userId: string; role: string }[];
    };
    expect(body.state).toBe("active");
    expect(
      body.participants.map((p) => `${p.userId}:${p.role}`).sort(),
    ).toEqual([`${GUARDIAN}:guardian`, `${TEACHER}:staff`].sort());
    conversationId = body.id;
  });

  test("the guardian (no memberships row) sends a message in the conversation", async () => {
    const res = await request(`/v1/conversations/${conversationId}/messages`, {
      method: "POST",
      subject: GUARDIAN,
      body: {
        clientMessageId: crypto.randomUUID(),
        body: "Thank you for the update.",
      },
    });
    expect(res.status).toBe(201);
    const body = await res.json() as { body: string; senderId: string };
    expect(body.body).toBe("Thank you for the update.");
    expect(body.senderId).toBe(GUARDIAN);
  });

  test("only the other participant is notified, and never with the message text", async () => {
    const rows = await sql<{ recipient_id: string; payload: unknown }[]>`
      select d.recipient_id, o.payload
      from public.notification_deliveries d
      join public.notification_outbox o on o.id = d.outbox_id
      where o.school_id = ${SCHOOL}::uuid
        and o.template_key = 'communications.message_sent'
    `;
    expect(rows.map((row) => row.recipient_id)).toEqual([TEACHER]);
    expect(JSON.stringify(rows[0]?.payload)).not.toContain("Thank you");
    const broadcast = await sql<{ n: number }[]>`
      select count(*)::int as n from public.notification_outbox
      where school_id = ${SCHOOL}::uuid
        and template_key = 'communications.message_sent'
        and recipient_id is null
    `;
    expect(broadcast[0]?.n).toBe(0);
  });

  test("messages page newest first and paging loses nothing", async () => {
    for (const text of ["first note", "second note", "third note"]) {
      const sent = await request(
        `/v1/conversations/${conversationId}/messages`,
        {
          method: "POST",
          subject: TEACHER,
          body: { clientMessageId: crypto.randomUUID(), body: text },
        },
      );
      expect(sent.status).toBe(201);
    }
    const first = await request(
      `/v1/conversations/${conversationId}/messages?pageSize=2`,
      { subject: GUARDIAN },
    );
    const page1 = await first.json() as {
      items: { body: string }[];
      nextCursor: string | null;
    };
    expect(page1.items.map((m) => m.body)).toEqual([
      "third note",
      "second note",
    ]);
    expect(page1.nextCursor).not.toBeNull();
    const second = await request(
      `/v1/conversations/${conversationId}/messages?pageSize=2&cursor=${
        encodeURIComponent(page1.nextCursor!)
      }`,
      { subject: GUARDIAN },
    );
    const page2 = await second.json() as { items: { body: string }[] };
    expect(page2.items.map((m) => m.body)).toEqual([
      "first note",
      "Thank you for the update.",
    ]);
  });

  test("a non-participant cannot list messages", async () => {
    const res = await request(`/v1/conversations/${conversationId}/messages`, {
      subject: ADMIN,
    });
    expect(res.status).toBe(404);
  });

  test("a teacher cannot create a school-wide announcement", async () => {
    const res = await request("/v1/announcements", {
      method: "POST",
      subject: TEACHER,
      body: { schoolId: SCHOOL, title: "Rogue notice", body: "x" },
    });
    expect([403, 404]).toContain(res.status);
  });

  test("a school admin creates a school-wide announcement, visible to members", async () => {
    const create = await request("/v1/announcements", {
      method: "POST",
      subject: ADMIN,
      body: {
        schoolId: SCHOOL,
        title: "Term dates",
        body: "See the calendar.",
      },
    });
    expect(create.status).toBe(201);

    const list = await request(`/v1/announcements?schoolId=${SCHOOL}`, {
      subject: TEACHER,
    });
    expect(list.status).toBe(200);
    const body = await list.json() as { items: { title: string }[] };
    expect(body.items.some((a) => a.title === "Term dates")).toBe(true);
  });
});
