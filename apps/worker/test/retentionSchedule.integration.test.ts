/**
 * DL-057 retention schedule against a real local Postgres: the worker loop
 * reaches every purge and they act. The purges work on the whole database,
 * so everything here runs in one transaction that is rolled back - nothing
 * is left behind, including on a developer's local database. The SQL rules
 * themselves are covered in supabase/tests/retention_schedule.sql.
 */
import { afterAll, beforeAll, describe, expect, test } from "bun:test";
import { createDatabase, type Sql } from "@studafy/database";
import type { EmailMessage } from "@studafy/infrastructure";
import { createJsonLogger } from "@studafy/observability";
import { integrationSuite, LogCollector } from "@studafy/test-support";
import { startRetentionSchedule } from "../src/processors/retentionSweep";

const databaseUrl = process.env["DATABASE_URL"];
const suite = integrationSuite(describe);

const IDLE = "d1057000-0000-4000-8000-0000000000a1";
const SCHOOL = "d1057000-0000-4000-8000-0000000000b1";
const PHOTO = "d1057000-0000-4000-8000-0000000000c1";
let sql: Sql;

class Rollback extends Error {}

suite("DL-057 retention schedule", () => {
  beforeAll(() => {
    sql = createDatabase(databaseUrl!);
  });

  afterAll(async () => {
    if (sql) await sql.end({ timeout: 5 });
  });

  test("one pass purges old logs, warns an idle account, emails the warning and expires helper photos", async () => {
    const collector = new LogCollector();
    const logger = createJsonLogger("worker", "test", "debug", collector.sink);
    let checked = false;
    // The provider is stubbed: nothing leaves this machine.
    const emails: EmailMessage[] = [];
    const email = {
      send: (message: EmailMessage) => {
        emails.push(message);
        return Promise.resolve({ providerMessageId: "stub-1" });
      },
    };

    await sql.begin(async (tx) => {
      await tx`
        insert into auth.users (id, email, aud, role, created_at, updated_at,
          last_sign_in_at, instance_id, raw_app_meta_data, raw_user_meta_data)
        values (${IDLE}::uuid, ${`${IDLE}@synthetic.studafy.test`}, 'authenticated',
          'authenticated', now() - interval '23 months 2 days',
          now() - interval '23 months 2 days', now() - interval '23 months 2 days',
          '00000000-0000-0000-0000-000000000000', '{}'::jsonb,
          ${tx.json({ full_name: "Worker Idle" })})
      `;
      await tx`
        insert into public.audit_events (action, entity_type, entity_id, created_at)
        values ('worker_test.old', 'profile', ${IDLE}::uuid, now() - interval '25 months')
      `;

      // A study helper photo uploaded 31 days ago (DL-060).
      await tx`
        insert into public.schools (id, name, status)
        values (${SCHOOL}::uuid, 'Worker retention school', 'active')
      `;
      await tx`
        insert into public.file_objects (id, school_id, bucket, object_key,
          uploader_id, owner_id, size_bytes, declared_media_type, sha256,
          scan_state, scanned_at, purpose, display_name, created_at)
        values (${PHOTO}::uuid, ${SCHOOL}::uuid, 'legacy',
          'files/worker-retention-photo', ${IDLE}::uuid, ${IDLE}::uuid, 10,
          'image/jpeg', ${"9".repeat(64)}, 'clean', now(),
          'assistant_attachment', 'Photo.jpg', now() - interval '31 days')
      `;
      // No school membership and email turned off for `account`: the
      // warning is a required notice and is emailed all the same.
      await tx`
        insert into public.notification_preferences (user_id, channel, category, enabled)
        values (${IDLE}::uuid, 'email', 'account', false)
      `;

      const runtime = startRetentionSchedule(
        tx as unknown as Sql,
        logger,
        3_600_000,
        { email },
      );
      // The startup pass and this one share the transaction's connection.
      await runtime.runOnce();
      await runtime.close();

      const [left] = await tx<{ n: number }[]>`
        select count(*)::int as n from public.audit_events where action = 'worker_test.old'
      `;
      expect(left?.n).toBe(0);
      const [warning] = await tx<{ school: string | null }[]>`
        select notified_school_id as school from private.inactive_account_warnings
        where user_id = ${IDLE}::uuid
      `;
      expect(warning).toEqual({ school: null });
      const [photo] = await tx<{ due: boolean }[]>`
        select retention_until <= now() as due from public.file_objects
        where id = ${PHOTO}::uuid
      `;
      expect(photo).toEqual({ due: true });
      const [emailed] = await tx<{ emailed: boolean; id: string | null }[]>`
        select emailed_at is not null as emailed, email_provider_message_id as id
        from private.inactive_account_warnings where user_id = ${IDLE}::uuid
      `;
      expect(emailed).toEqual({ emailed: true, id: "stub-1" });
      checked = true;
      throw new Rollback();
    }).catch((error) => {
      if (!(error instanceof Rollback)) throw error;
    });

    expect(checked).toBe(true);
    const steps = collector.parsed()
      .filter((line) => line.event === "retention_purged")
      .map((line) => line.step);
    expect(steps).toContain("records");
    expect(steps).toContain("inactive_accounts");
    expect(steps).toContain("helper_photos");
    expect(collector.events()).not.toContain("retention_step_failed");
    expect(emails.filter((m) => m.to === `${IDLE}@synthetic.studafy.test`))
      .toHaveLength(1);
    expect(emails[0]?.subject).toBe("Your account will be deleted");

    const [gone] = await sql<{ n: number }[]>`
      select count(*)::int as n from auth.users where id = ${IDLE}::uuid
    `;
    expect(gone?.n).toBe(0);
  });
});
