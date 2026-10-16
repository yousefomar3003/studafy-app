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
  channelCopyTemplates,
} from "../src/processors/notificationCopy";
import { integrationSuite, removeFixtures } from "@studafy/test-support";

const databaseUrl = process.env["DATABASE_URL"];
const suite = integrationSuite(describe);

const SCHOOL = "d1053000-0000-4000-8000-0000000000b1";
const EMAIL_USER = "d1053000-0000-4000-8000-0000000000a1";
const PUSH_USER = "d1053000-0000-4000-8000-0000000000a2";
const GOOD_TOKEN = "good-token-".padEnd(48, "g");
const DEAD_TOKEN = "dead-token-".padEnd(48, "d");
const logger = createJsonLogger("worker", "test", "error", () => undefined);
let sql: Sql;

async function cleanup(): Promise<void> {
  await removeFixtures(sql, {
    schoolIds: [SCHOOL],
    userIds: [EMAIL_USER, PUSH_USER],
  });
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

test("subscription copy is specific, in both languages, and never claims a charge", () => {
  const templates = channelCopyTemplates();
  expect(templates.ar).toEqual(templates.en);
  expect(templates.en).toContain("billing.payment_problem");
  for (const locale of ["en", "ar"]) {
    for (const key of templates.en) {
      const text = channelCopy(key, locale);
      expect(text).not.toEqual(channelCopy("billing.anything", locale));
      expect(text.body).not.toMatch(/[$€£]|\d/);
    }
  }
});

test("mark release and correction copy is specific but names no mark", () => {
  for (const locale of ["en", "ar"]) {
    for (
      const key of ["academic.grades_published", "academic.grades_corrected"]
    ) {
      const text = channelCopy(key, locale);
      expect(text).not.toEqual(channelCopy("academic.anything", locale));
      expect(`${text.title} ${text.body}`).not.toMatch(/\d/);
    }
  }
  expect(channelCopy("academic.grades_corrected", "en")).not.toEqual(
    channelCopy("academic.grades_published", "en"),
  );
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

  async function channelRows(): Promise<{ channel: string }[]> {
    return [
      ...(await sql<{ channel: string }[]>`
        select channel from public.notification_deliveries
        where school_id = ${SCHOOL}::uuid and channel <> 'in_app'
        order by channel
      `),
    ];
  }

  test("with no sender configured, nothing is fanned out or claimed", async () => {
    // DL-070: production runs with NOTIFICATION_CHANNELS_ENABLED on before
    // the Resend and Firebase keys exist. No rows may pile up to be sent
    // late once a key arrives.
    const runtime = startChannelDelivery(sql, {}, logger, 3_600_000);
    try {
      expect(await runtime.runOnce()).toBe(0);
    } finally {
      await runtime.close();
    }
    expect(await channelRows()).toEqual([]);
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

  test("with only push configured, email is not fanned out", async () => {
    // EMAIL_USER opted in to academic email but has no phone: with only a
    // push sender, the new notification gets no email delivery at all.
    await sql`select private.notify_recipient(${SCHOOL}::uuid, ${EMAIL_USER}::uuid, 'academic.grade_published', '{}'::jsonb, 'dl070-push-only', 'dl070:push-only')`;
    const pushes: PushMessage[] = [];
    const runtime = startChannelDelivery(
      sql,
      {
        push: {
          send: async (m) => {
            pushes.push(m);
            return { providerMessageId: "push-2" };
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
    const rows = await sql<{ count: number }[]>`
      select count(*)::int as count from public.notification_deliveries d
      join public.notification_outbox o on o.id = d.outbox_id
      where o.source_event_id = 'dl070-push-only' and d.channel = 'email'
    `;
    expect(rows[0]?.count).toBe(0);
    expect(pushes).toEqual([]);
  });
});
