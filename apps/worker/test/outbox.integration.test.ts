/**
 * OPS-061 end-to-end queue proofs against a real local Postgres + Redis. The
 * SQL state machine lives in supabase/tests/ops061_outbox.sql; this file
 * proves the BullMQ semantics on top of it: crash mid-job, failover,
 * duplicate delivery, poison message, backlog drain — each asserting that a
 * job which runs twice does not double-apply.
 */
import { afterAll, beforeAll, describe, expect, test } from "bun:test";
import type { Processor } from "bullmq";
import {
  closeQueue,
  closeWorker,
  createQueue,
  createWorker,
  type Queue,
  type Worker,
} from "@studafy/infrastructure";
import { createDatabase, type Sql } from "@studafy/database";
import { createJsonLogger } from "@studafy/observability";
import { LogCollector } from "@studafy/test-support";
import {
  buildNotificationRuntime,
  type NotificationRuntime,
} from "../src/bootstrap/queues";

const databaseUrl = process.env["DATABASE_URL"];
const redisUrl = process.env["REDIS_URL"];
const suite = databaseUrl && redisUrl ? describe : describe.skip;

const SCHOOL = "61061000-0000-4000-8000-0000000000a1";
const OTHER_SCHOOL = "61061000-0000-4000-8000-0000000000b1";
const ADMIN = "61061000-0000-4000-8000-0000000000c1";
const TEACHER = "61061000-0000-4000-8000-0000000000c2";
const CO_TEACHER = "61061000-0000-4000-8000-0000000000c3";
const SUSPENDED_TEACHER = "61061000-0000-4000-8000-0000000000c4";
const OTHER_SCHOOL_ADMIN = "61061000-0000-4000-8000-0000000000d1";
const WORKER = "ops061-worker";
const PREFIX = "studafy-development";

let sql: Sql;
let runtime: NotificationRuntime;
const scratchQueues: Queue[] = [];
const scratchWorkers: Worker[] = [];

beforeAll(async () => {
  sql = createDatabase(databaseUrl!);
  const logger = createJsonLogger(
    "worker",
    "test",
    "error",
    new LogCollector().sink,
  );
  runtime = buildNotificationRuntime(redisUrl!, sql, logger, {
    environment: "development",
    concurrency: 3,
  });
  await runtime.worker.waitUntilReady();
});

async function seedGraph(): Promise<void> {
  await sql`
    insert into auth.users (
      id, email, encrypted_password, aud, role, email_confirmed_at,
      created_at, updated_at, instance_id, confirmation_token, recovery_token,
      email_change, email_change_token_new, email_change_token_current,
      phone_change_token, raw_app_meta_data, raw_user_meta_data
    ) values
      (${ADMIN}::uuid, 'ops061.admin@synthetic.studafy.test', 'synthetic-not-a-secret', 'authenticated', 'authenticated', now(), now(), now(), '00000000-0000-0000-0000-000000000000', '', '', '', '', '', '', '{}'::jsonb, '{"full_name":"OPS-061 Admin"}'::jsonb),
      (${TEACHER}::uuid, 'ops061.teacher@synthetic.studafy.test', 'synthetic-not-a-secret', 'authenticated', 'authenticated', now(), now(), now(), '00000000-0000-0000-0000-000000000000', '', '', '', '', '', '', '{}'::jsonb, '{"full_name":"OPS-061 Teacher"}'::jsonb),
      (${CO_TEACHER}::uuid, 'ops061.coteacher@synthetic.studafy.test', 'synthetic-not-a-secret', 'authenticated', 'authenticated', now(), now(), now(), '00000000-0000-0000-0000-000000000000', '', '', '', '', '', '', '{}'::jsonb, '{"full_name":"OPS-061 CoTeacher"}'::jsonb),
      (${SUSPENDED_TEACHER}::uuid, 'ops061.suspended@synthetic.studafy.test', 'synthetic-not-a-secret', 'authenticated', 'authenticated', now(), now(), now(), '00000000-0000-0000-0000-000000000000', '', '', '', '', '', '', '{}'::jsonb, '{"full_name":"OPS-061 Suspended"}'::jsonb),
      (${OTHER_SCHOOL_ADMIN}::uuid, 'ops061.other@synthetic.studafy.test', 'synthetic-not-a-secret', 'authenticated', 'authenticated', now(), now(), now(), '00000000-0000-0000-0000-000000000000', '', '', '', '', '', '', '{}'::jsonb, '{"full_name":"OPS-061 Other"}'::jsonb)
    on conflict (id) do nothing
  `;
  await sql`
    insert into public.schools (id, name, timezone, status) values
      (${SCHOOL}::uuid, 'OPS-061 School', 'Asia/Riyadh', 'active'),
      (${OTHER_SCHOOL}::uuid, 'OPS-061 Other School', 'Asia/Riyadh', 'active')
    on conflict (id) do update set status = 'active'
  `;
  await sql`
    insert into public.memberships (school_id, user_id, role, active, status) values
      (${SCHOOL}::uuid, ${ADMIN}::uuid, 'school_admin', true, 'active'),
      (${SCHOOL}::uuid, ${TEACHER}::uuid, 'teacher', true, 'active'),
      (${SCHOOL}::uuid, ${CO_TEACHER}::uuid, 'teacher', true, 'active'),
      (${SCHOOL}::uuid, ${SUSPENDED_TEACHER}::uuid, 'teacher', true, 'active'),
      (${OTHER_SCHOOL}::uuid, ${OTHER_SCHOOL_ADMIN}::uuid, 'school_admin', true, 'active')
    on conflict (school_id, user_id, role) do nothing
  `;
  await sql`
    update public.profiles set status = 'suspended' where id = ${SUSPENDED_TEACHER}::uuid
  `;
}

async function cleanup(): Promise<void> {
  await sql.begin(async (tx) => {
    await tx`alter table public.audit_events disable trigger db020_reject_mutation`;
    await tx`delete from public.notification_deliveries where school_id = ${SCHOOL}::uuid`;
    await tx`delete from public.notification_outbox where school_id = ${SCHOOL}::uuid`;
    await tx`delete from public.audit_events where request_id like 'ops061-%'`;
    await tx`delete from public.schools where id in (${SCHOOL}::uuid, ${OTHER_SCHOOL}::uuid)`;
    await tx`delete from auth.users where id in (${ADMIN}::uuid, ${TEACHER}::uuid, ${CO_TEACHER}::uuid, ${SUSPENDED_TEACHER}::uuid, ${OTHER_SCHOOL_ADMIN}::uuid)`;
    await tx`alter table public.audit_events enable trigger db020_reject_mutation`;
  });
}

/** Seeds one audience outbox row and returns its id. */
async function seedAudienceRow(
  key: string,
  audience: unknown,
): Promise<number> {
  const rows = await sql<{ id: number }[]>`
    insert into public.notification_outbox(
      school_id, source_event_id, idempotency_key, channel, template_key, audience, payload
    ) values (
      ${SCHOOL}::uuid, ${"evt-" + key}, ${key}, 'in_app',
      'school_admin.membership_granted', ${
    sql.json(audience as never)
  }, '{}'::jsonb
    )
    returning id
  `;
  return Number(rows[0]!.id);
}

async function rowState(outboxId: number): Promise<string> {
  const rows = await sql<{ state: string }[]>`
    select state::text as state from public.notification_outbox where id = ${outboxId}
  `;
  return rows[0]!.state;
}

async function deliveryCount(outboxId: number): Promise<number> {
  const rows = await sql<{ n: number }[]>`
    select count(*)::int as n from public.notification_deliveries where outbox_id = ${outboxId}
  `;
  return rows[0]!.n;
}

async function deadLetterAudits(outboxId: number): Promise<number> {
  const rows = await sql<{ n: number }[]>`
    select count(*)::int as n from public.audit_events
    where request_id like 'ops061-dlq-%'
      and after_value->>'outboxId' = ${outboxId}::text
  `;
  return rows[0]!.n;
}

/** Dispatches and waits until the row reaches a terminal state. */
async function drain(outboxId: number, timeoutMs = 20_000): Promise<string> {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    await runtime.runDispatchOnce();
    const state = await rowState(outboxId);
    if (state === "completed" || state === "dead_letter") return state;
    await new Promise((resolve) => setTimeout(resolve, 100));
  }
  throw new Error(`outbox row ${outboxId} did not reach a terminal state`);
}

/** Polls an async condition until it holds or the timeout expires. */
async function waitFor(
  predicate: () => boolean | Promise<boolean>,
  timeoutMs = 15_000,
): Promise<void> {
  const started = Date.now();
  while (!(await predicate())) {
    if (Date.now() - started > timeoutMs) {
      throw new Error("condition not reached");
    }
    await new Promise((resolve) => setTimeout(resolve, 100));
  }
}

async function drainBacklog(
  timeoutMs = 30_000,
): Promise<Record<string, number>> {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    await runtime.runDispatchOnce();
    const rows = await sql<{ backlog: Record<string, number> }[]>`
      select private.api061_outbox_backlog() as backlog
    `;
    const backlog = rows[0]!.backlog;
    if ((backlog.pending ?? 0) === 0 && (backlog.retry ?? 0) === 0) {
      return backlog;
    }
    await new Promise((resolve) => setTimeout(resolve, 100));
  }
  throw new Error("the dispatchable backlog did not drain");
}

beforeAll(async () => {
  await cleanup();
  await seedGraph();
});

afterAll(async () => {
  await cleanup();
  await Promise.all(scratchWorkers.map((worker) => closeWorker(worker)));
  await Promise.all(scratchQueues.map((queue) => closeQueue(queue)));
  await runtime.close();
  await sql.end({ timeout: 5 });
});

suite("OPS-061 notifications queue", () => {
  test(
    "happy path: one audience row produces exactly one delivery per active staff member",
    async () => {
      const id = await seedAudienceRow("ops061-happy", { schoolId: SCHOOL });
      expect(await drain(id)).toBe("completed");
      expect(await deliveryCount(id)).toBe(3);
      expect(await rowState(id)).toBe("completed");
    },
    20000,
  );

  test(
    "duplicate delivery: a repeat run of the same job does not double-apply",
    async () => {
      const id = await seedAudienceRow("ops061-duplicate", {
        schoolId: SCHOOL,
      });
      expect(await drain(id)).toBe("completed");
      expect(await deliveryCount(id)).toBe(3);
      // Simulate duplicate BullMQ delivery: the same finish runs twice more
      // on the committed row and inserts nothing.
      const outcomes = await Promise.all([
        sql<
          { outcome: string }[]
        >`select private.api061_finish_notification(${id}) as outcome`,
        sql<
          { outcome: string }[]
        >`select private.api061_finish_notification(${id}) as outcome`,
      ]);
      for (const row of outcomes) {
        expect(row[0]!.outcome).toBe("completed");
      }
      expect(await deliveryCount(id)).toBe(3);
    },
    20000,
  );

  test(
    "failover: two concurrent processors of the same job still apply it once",
    async () => {
      const id = await seedAudienceRow("ops061-failover", { schoolId: SCHOOL });
      await runtime.runDispatchOnce();
      expect(await rowState(id)).toBe("processing");
      // Two worker instances re-run the finish concurrently (the shape a
      // failover produces); the deliveries unique constraint serializes them.
      const outcomes = await Promise.all([
        sql<
          { outcome: string }[]
        >`select private.api061_finish_notification(${id}) as outcome`,
        sql<
          { outcome: string }[]
        >`select private.api061_finish_notification(${id}) as outcome`,
      ]);
      const values = outcomes.map((row) => row[0]!.outcome);
      expect(values.filter((v) => v === "completed")).toHaveLength(2);
      expect(await deliveryCount(id)).toBe(3);
      expect(await rowState(id)).toBe("completed");
    },
    20000,
  );

  test(
    "poison message: deterministic failure dead-letters once and unrelated work continues",
    async () => {
      const poison = await seedAudienceRow("ops061-poison", {
        unexpected: true,
      });
      const healthy = await seedAudienceRow("ops061-healthy", {
        schoolId: SCHOOL,
      });
      expect(await drain(poison)).toBe("dead_letter");
      expect(await rowState(poison)).toBe("dead_letter");
      expect(await deliveryCount(poison)).toBe(0);
      // Exactly one dead_letter audit row: the poison never looped.
      expect(await deadLetterAudits(poison)).toBe(1);
      // The poison did not stop unrelated work.
      expect(await drain(healthy)).toBe("completed");
      expect(await deliveryCount(healthy)).toBe(3);
    },
    25000,
  );

  test(
    "backlog drain: a full backlog reaches completion with zero lag",
    async () => {
      const ids: number[] = [];
      for (let i = 0; i < 8; i += 1) {
        ids.push(
          await seedAudienceRow(`ops061-backlog-${i}`, { schoolId: SCHOOL }),
        );
      }
      const backlog = await drainBacklog();
      expect(backlog.pending).toBe(0);
      expect(backlog.retry).toBe(0);
      for (const id of ids) {
        expect(await rowState(id)).toBe("completed");
        expect(await deliveryCount(id)).toBe(3);
      }
    },
    30000,
  );

  test(
    "crash mid-job: recovery applies the side effect exactly once",
    async () => {
      const id = await seedAudienceRow("ops061-crash", { schoolId: SCHOOL });
      // A dedicated scratch queue hosts the crash scenario so the shared
      // runtime worker cannot race the crashed one for the same job.
      const scratch = createQueue("notifications-crash", redisUrl!, {
        prefix: PREFIX,
      });
      scratchQueues.push(scratch);

      let released!: () => void;
      const blocker = new Promise<void>((resolve) => {
        released = resolve;
      });
      let runs = 0;
      const processor: Processor = async () => {
        runs += 1;
        // The side effect commits inside the first run; the crash happens
        // before BullMQ can acknowledge, so the job must re-run.
        await sql`select private.api061_finish_notification(${id})`;
        if (runs === 1) await blocker;
        return { ok: true, run: runs };
      };
      const crashedWorker = createWorker(
        "notifications-crash",
        processor,
        redisUrl!,
        {
          prefix: PREFIX,
          lockDurationMs: 1_000,
          stalledIntervalMs: 400,
          maxStalledCount: 3,
        },
      );
      await crashedWorker.waitUntilReady();

      const claimed = await sql<{ jobs: { outboxId: number }[] }[]>`
        select private.api061_claim_outbox_dispatch(${WORKER}, 50) as jobs
      `;
      expect(claimed[0]!.jobs.some((j) => j.outboxId === id)).toBe(true);
      const jobId = `outbox-${id}`;
      await scratch.add("school_admin.membership_granted", {
        outboxId: id,
        schoolId: SCHOOL,
        templateKey: "school_admin.membership_granted",
        channel: "in_app",
        audience: { schoolId: SCHOOL },
        payload: {},
      }, { jobId });
      // Side effect committed by the first run, worker still hung.
      await waitFor(() => runs >= 1);
      await waitFor(async () => (await deliveryCount(id)) === 3);
      const committed = await deliveryCount(id);
      expect(committed).toBe(3);
      // Hard-crash: no graceful close, the processing lock dies with it.
      await crashedWorker.close(true);

      // A fresh worker recovers the stalled job and re-runs the finish.
      const recoveredWorker = createWorker(
        "notifications-crash",
        processor,
        redisUrl!,
        {
          prefix: PREFIX,
          lockDurationMs: 1_000,
          stalledIntervalMs: 400,
          maxStalledCount: 3,
        },
      );
      await recoveredWorker.waitUntilReady();
      await waitFor(() => runs >= 2);
      released();
      await closeWorker(recoveredWorker);

      expect(runs).toBeGreaterThanOrEqual(2);
      expect(await deliveryCount(id)).toBe(3);
      expect(await rowState(id)).toBe("completed");
    },
    30000,
  );
});
