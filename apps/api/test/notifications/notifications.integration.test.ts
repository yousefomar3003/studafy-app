/**
 * API-042 S6 end-to-end proof against a real local Postgres. The exhaustive
 * state-machine coverage lives in supabase/tests/api042_notifications.sql;
 * this file proves the HTTP layer on top of it.
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
import { PostgresNotificationsRepository } from "../../src/notifications/repository";
import { createNotificationsRoutes } from "../../src/notifications/routes";

const databaseUrl = process.env["DATABASE_URL"];
const suite = databaseUrl ? describe : describe.skip;

const USER_A = "5f470000-0000-4000-8000-0000000000a1";
const SCHOOL = "5f470000-0000-4000-8000-0000000000b1";

const CURSOR_KEY = "api042-notifications-integration-cursor-key-0000000001";

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
      (${USER_A}::uuid, 'api042.notif.user@synthetic.studafy.test', 'synthetic-not-a-secret', 'authenticated', 'authenticated', now(), now(), now(), '00000000-0000-0000-0000-000000000000', '', '', '', '', '', '', '{}'::jsonb, '{"full_name":"API-042 Notif User"}'::jsonb)
    on conflict (id) do nothing
  `;
  await sql`
    insert into public.schools (id, name, timezone, status) values (${SCHOOL}::uuid, 'API-042 Notifications School', 'Asia/Riyadh', 'active')
    on conflict (id) do update set status = 'active'
  `;
  await sql`select private.notify_recipient(${SCHOOL}::uuid, ${USER_A}::uuid, 'academic.grade_published', '{}'::jsonb, 'http-evt-1', 'http-notify-1')`;
  await sql`select private.notify_recipient(${SCHOOL}::uuid, ${USER_A}::uuid, 'academic.grade_published', '{}'::jsonb, 'http-evt-2', 'http-notify-2')`;
}

async function cleanup(): Promise<void> {
  await sql.begin(async (tx) => {
    await tx`alter table public.audit_events disable trigger db020_reject_mutation`;
    await tx`delete from public.notification_preferences where user_id = ${USER_A}::uuid`;
    await tx`delete from public.notification_deliveries where recipient_id = ${USER_A}::uuid`;
    await tx`delete from public.notification_outbox where school_id = ${SCHOOL}::uuid`;
    await tx`delete from public.audit_events where actor_id = ${USER_A}::uuid`;
    await tx`delete from public.schools where id = ${SCHOOL}::uuid`;
    await tx`delete from auth.users where id = ${USER_A}::uuid`;
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

suite("API-042 S6 notifications over the real /v1 stack", () => {
  beforeAll(async () => {
    sql = createDatabase(databaseUrl!);
    await cleanup();
    await seed();
    contexts = new AuthContextRepository(sql);
    const logger = createJsonLogger(
      "api",
      "api042-notifications-integration",
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
      createNotificationsRoutes(
        {
          repository: new PostgresNotificationsRepository(sql),
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

  test("a user with no school membership lists their own notifications", async () => {
    const res = await request("/v1/notifications", { subject: USER_A });
    expect(res.status).toBe(200);
    const body = await res.json() as {
      items: unknown[];
      nextCursor: string | null;
    };
    expect(body.items.length).toBe(2);
    expect(body.nextCursor).toBeNull();
  });

  test("the unread count matches, then drops after marking all read", async () => {
    const before = await request("/v1/notifications/unread-count", {
      subject: USER_A,
    });
    expect((await before.json() as { unreadCount: number }).unreadCount).toBe(
      2,
    );

    const mark = await request("/v1/notifications/mark-read", {
      method: "POST",
      subject: USER_A,
      body: { all: true },
    });
    expect(mark.status).toBe(200);
    expect((await mark.json() as { markedCount: number }).markedCount).toBe(2);

    const after = await request("/v1/notifications/unread-count", {
      subject: USER_A,
    });
    expect((await after.json() as { unreadCount: number }).unreadCount).toBe(0);
  });

  test("preferences round-trip through get/update", async () => {
    const update = await request("/v1/notifications/preferences", {
      method: "POST",
      subject: USER_A,
      body: { channel: "email", category: "academic", enabled: false },
    });
    expect(update.status).toBe(200);

    const list = await request("/v1/notifications/preferences", {
      subject: USER_A,
    });
    expect(list.status).toBe(200);
    const body = await list.json() as {
      items: { channel: string; category: string; enabled: boolean }[];
    };
    expect(
      body.items.some((p) =>
        p.channel === "email" && p.category === "academic" && !p.enabled
      ),
    )
      .toBe(true);
  });
});
