/**
 * DL-053 channel delivery against a real local Postgres with fake senders.
 * The fan-out/claim/finish SQL is covered in
 * supabase/tests/notification_channels.sql.
 */
import { afterAll, beforeAll, describe, expect, test } from "bun:test";
import { createDatabase, type Sql } from "@studafy/database";
import { createJsonLogger } from "@studafy/observability";
import {
  ChannelSendError,
  type EmailMessage,
  type PushMessage,
} from "@studafy/infrastructure";
import { startChannelDelivery } from "../src/processors/channelDelivery";
import {
  channelCopy,
  channelCopyCategories,
} from "../src/processors/notificationCopy";

const databaseUrl = process.env["DATABASE_URL"];
const suite = databaseUrl ? describe : describe.skip;

const SCHOOL = "d1053000-0000-4000-8000-0000000000b1";
const EMAIL_USER = "d1053000-0000-4000-8000-0000000000a1";
const PUSH_USER = "d1053000-0000-4000-8000-0000000000a2";
const GOOD_TOKEN = "good-token-".padEnd(48, "g");
const DEAD_TOKEN = "dead-token-".padEnd(48, "d");
const logger = createJsonLogger("worker", "test", "error", () => undefined);
let sql: Sql;

async function cleanup(): Promise<void> {
  await sql`delete from public.push_devices where user_id in (${EMAIL_USER}::uuid, ${PUSH_USER}::uuid)`;
  await sql`delete from public.notification_preferences where user_id in (${EMAIL_USER}::uuid, ${PUSH_USER}::uuid)`;
  await sql`delete from public.notification_deliveries where school_id = ${SCHOOL}::uuid`;
  await sql`delete from public.notification_outbox where school_id = ${SCHOOL}::uuid`;
  await sql`delete from public.schools where id = ${SCHOOL}::uuid`;
  await sql`delete from auth.users where id in (${EMAIL_USER}::uuid, ${PUSH_USER}::uuid)`;
}

test("channel copy exists in both languages and carries no placeholders", () => {
  const categories = channelCopyCategories();
  expect(categories.ar).toEqual(categories.en);
  for (const locale of ["en", "ar"]) {
    for (const category of categories.en) {
      const text = channelCopy(`${category}.anything`, locale);
      expect(text.body).not.toContain("{");
    }
  }
});

suite("DL-053 channel delivery", () => {
  beforeAll(async () => {
    sql = createDatabase(databaseUrl!);
    await cleanup();
    for (
      const [id, locale] of [[EMAIL_USER, "en"], [PUSH_USER, "ar"]] as const
    ) {
      await sql`
        insert into auth.users (
          id, email, encrypted_password, aud, role, email_confirmed_at,
          created_at, updated_at, instance_id, confirmation_token,
          recovery_token, email_change, email_change_token_new,
          email_change_token_current, phone_change_token,
          raw_app_meta_data, raw_user_meta_data
        ) values (
          ${id}::uuid, ${`${id}@synthetic.studafy.test`}, 'x',
          'authenticated', 'authenticated', now(), now(), now(),
          '00000000-0000-0000-0000-000000000000', '', '', '', '', '', '',
          '{}'::jsonb, '{"full_name":"DL053 User"}'::jsonb
        )
      `;
      await sql`update public.profiles set locale = ${locale} where id = ${id}::uuid`;
    }
    await sql`insert into public.schools (id, name, timezone, status) values (${SCHOOL}::uuid, 'DL053 School', 'Asia/Riyadh', 'active')`;
    await sql`insert into public.notification_preferences (user_id, school_id, channel, category, enabled) values (${EMAIL_USER}::uuid, null, 'email', 'academic', true)`;
    await sql`insert into public.push_devices (user_id, platform, token) values (${PUSH_USER}::uuid, 'android', ${GOOD_TOKEN}), (${PUSH_USER}::uuid, 'ios', ${DEAD_TOKEN})`;
    for (const id of [EMAIL_USER, PUSH_USER]) {
      await sql`select private.notify_recipient(${SCHOOL}::uuid, ${id}::uuid, 'academic.grade_published', '{"gradeId":"secret"}'::jsonb, ${`dl053-${id}`}, ${`dl053:${id}`})`;
    }
  });

  afterAll(async () => {
    if (!sql) return;
    await cleanup();
    await sql.end({ timeout: 5 });
  });

  test("sends content-free email and push, and revokes a dead token", async () => {
    const emails: EmailMessage[] = [];
    const pushes: PushMessage[] = [];
    const runtime = startChannelDelivery(
      sql,
      {
        email: {
          send: async (m) => {
            emails.push(m);
            return { providerMessageId: "email-1" };
          },
        },
        push: {
          send: async (m) => {
            if (m.token === DEAD_TOKEN) {
              throw new ChannelSendError("UNREGISTERED", true, true);
            }
            pushes.push(m);
            return { providerMessageId: "push-1" };
          },
        },
      },
      logger,
      3_600_000,
    );
    try {
      await runtime.runOnce();
    } finally {
      await runtime.close();
    }
    expect(emails.map((m) => m.to)).toEqual([
      `${EMAIL_USER}@synthetic.studafy.test`,
    ]);
    expect(emails[0]?.subject).toBe("New school update");
    expect(pushes).toHaveLength(1);
    expect(pushes[0]?.title).toBe("تحديث مدرسي جديد");
    expect(JSON.stringify([...emails, ...pushes])).not.toContain("secret");

    const states = await sql<{ channel: string; state: string }[]>`
      select channel, state::text from public.notification_deliveries
      where school_id = ${SCHOOL}::uuid and channel <> 'in_app'
      order by channel
    `;
    expect(states.map((row) => ({ ...row }))).toEqual([
      { channel: "email", state: "sent" },
      { channel: "push", state: "sent" },
    ]);
    const dead = await sql<{ revoked: boolean }[]>`
      select revoked_at is not null as revoked from public.push_devices
      where token = ${DEAD_TOKEN}
    `;
    expect(dead[0]?.revoked).toBe(true);
  });
});
