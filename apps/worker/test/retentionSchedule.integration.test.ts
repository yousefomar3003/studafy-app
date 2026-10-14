/**
 * DL-057 retention schedule against a real local Postgres: the worker loop
 * reaches every purge and they act. The purges work on the whole database,
 * so everything here runs in one transaction that is rolled back - nothing
 * is left behind, including on a developer's local database. The SQL rules
 * themselves are covered in supabase/tests/retention_schedule.sql.
 */
import { afterAll, beforeAll, describe, expect, test } from "bun:test";
import { createDatabase, type Sql } from "@studafy/database";
import { createJsonLogger } from "@studafy/observability";
import { integrationSuite, LogCollector } from "@studafy/test-support";
import { startRetentionSchedule } from "../src/processors/retentionSweep";

const databaseUrl = process.env["DATABASE_URL"];
const suite = integrationSuite(describe);

const IDLE = "d1057000-0000-4000-8000-0000000000a1";
let sql: Sql;

class Rollback extends Error {}

suite("DL-057 retention schedule", () => {
  beforeAll(() => {
    sql = createDatabase(databaseUrl!);
  });

  afterAll(async () => {
    if (sql) await sql.end({ timeout: 5 });
  });

  test("one pass purges old logs and warns an idle account", async () => {
    const collector = new LogCollector();
    const logger = createJsonLogger("worker", "test", "debug", collector.sink);
    let checked = false;

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

      const runtime = startRetentionSchedule(
        tx as unknown as Sql,
        logger,
        3_600_000,
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
    expect(collector.events()).not.toContain("retention_step_failed");

    const [gone] = await sql<{ n: number }[]>`
      select count(*)::int as n from auth.users where id = ${IDLE}::uuid
    `;
    expect(gone?.n).toBe(0);
  });
});
