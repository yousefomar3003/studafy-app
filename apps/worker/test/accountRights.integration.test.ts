/**
 * DL-051 executors against a real local Postgres: the worker loops pick up
 * due work, complete it, and leave nothing pending. The SQL state machines
 * are covered in supabase/tests/account_deletion.sql and data_export.sql.
 */
import { afterAll, beforeAll, describe, expect, test } from "bun:test";
import { createDatabase, type Sql } from "@studafy/database";
import { createJsonLogger } from "@studafy/observability";
import { startAccountDeletionExecutor } from "../src/processors/accountDeletion";
import { startDataExportExecutor } from "../src/processors/dataExport";

const databaseUrl = process.env["DATABASE_URL"];
const suite = databaseUrl ? describe : describe.skip;

const LEAVER = "d1051000-0000-4000-8000-0000000000a1";
const EXPORTER = "d1051000-0000-4000-8000-0000000000a2";
const logger = createJsonLogger("worker", "test", "error", () => undefined);
let sql: Sql;

async function seedUser(id: string, name: string): Promise<void> {
  await sql`
    insert into auth.users (
      id, email, encrypted_password, aud, role, email_confirmed_at,
      created_at, updated_at, instance_id, confirmation_token, recovery_token,
      email_change, email_change_token_new, email_change_token_current,
      phone_change_token, raw_app_meta_data, raw_user_meta_data
    ) values (
      ${id}::uuid, ${`${id}@synthetic.studafy.test`}, 'x', 'authenticated',
      'authenticated', now(), now(), now(),
      '00000000-0000-0000-0000-000000000000', '', '', '', '', '', '',
      '{}'::jsonb, ${sql.json({ full_name: name })}
    ) on conflict (id) do nothing
  `;
}

async function cleanup(): Promise<void> {
  await sql`delete from public.data_export_requests where user_id in (${LEAVER}::uuid, ${EXPORTER}::uuid)`;
  await sql`delete from public.account_deletion_requests where user_id in (${LEAVER}::uuid, ${EXPORTER}::uuid)`;
  await sql`delete from auth.users where id in (${LEAVER}::uuid, ${EXPORTER}::uuid)`;
}

suite("DL-051 account rights executors", () => {
  beforeAll(async () => {
    sql = createDatabase(databaseUrl!);
    await cleanup();
    await seedUser(LEAVER, "Worker Leaver");
    await seedUser(EXPORTER, "Worker Exporter");
  });

  afterAll(async () => {
    if (!sql) return;
    await cleanup();
    await sql.end({ timeout: 5 });
  });

  test("a due deletion request is executed by the worker loop", async () => {
    await sql`
      insert into public.account_deletion_requests (user_id, execute_after, requested_at)
      values (${LEAVER}::uuid, now() - interval '1 minute', now() - interval '15 days')
    `;
    const runtime = startAccountDeletionExecutor(sql, logger, 3_600_000);
    try {
      await runtime.runOnce();
    } finally {
      await runtime.close();
    }
    const rows = await sql<{ state: string; display_name: string }[]>`
      select r.state, p.display_name
      from public.account_deletion_requests r
      join public.profiles p on p.id = r.user_id
      where r.user_id = ${LEAVER}::uuid
    `;
    expect(rows[0]?.state).toBe("completed");
    expect(rows[0]?.display_name).toBe("Deleted user");
  });

  test("a pending export is built by the worker loop", async () => {
    await sql`
      insert into public.data_export_requests (user_id, status)
      values (${EXPORTER}::uuid, 'pending')
    `;
    const runtime = startDataExportExecutor(sql, logger, 3_600_000);
    try {
      await runtime.runOnce();
    } finally {
      await runtime.close();
    }
    const rows = await sql<{ status: string; byte_size: number }[]>`
      select d.status, p.byte_size
      from public.data_export_requests d
      join public.data_export_payloads p on p.request_id = d.id
      where d.user_id = ${EXPORTER}::uuid
    `;
    expect(rows[0]?.status).toBe("ready");
    expect(rows[0]?.byte_size).toBeGreaterThan(0);
  });
});
