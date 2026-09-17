/**
 * FILE-050 quota races against a real local Postgres.
 *
 * The pgTAP suite runs inside one transaction, so it can only prove
 * *sequential* quota enforcement. The claim that actually matters is
 * concurrent: when two requests contend for the last session slot or the last
 * quota byte, exactly one reservation may succeed. That needs two real
 * connections racing for the same `file_quota_policies` row lock, which is
 * what this file does.
 */
import { afterAll, beforeAll, describe, expect, test } from "bun:test";
import { createDatabase, type Sql } from "@studafy/database";
import { withRequestContext } from "../../src/auth/context";

const databaseUrl = process.env["DATABASE_URL"];
const suite = databaseUrl ? describe : describe.skip;

const SCHOOL = "f0500000-0000-4000-8000-0000000000c1";
const TEACHER = "f0500000-0000-4000-8000-0000000000c2";

let sql: Sql;

interface IssueOutcome {
  outcome: string;
}

interface Contender {
  outcome: string;
  backendPid: number;
}

async function cleanup(): Promise<void> {
  await sql.begin(async (tx) => {
    await tx`alter table public.audit_events disable trigger db020_reject_mutation`;
    await tx`delete from public.file_job_outbox where school_id = ${SCHOOL}::uuid`;
    await tx`delete from public.file_bindings where school_id = ${SCHOOL}::uuid`;
    // upload_sessions.file_object_id references file_objects, and a completed
    // session must keep that reference, so sessions are removed first.
    await tx`delete from public.upload_sessions where school_id = ${SCHOOL}::uuid`;
    await tx`delete from public.file_objects where school_id = ${SCHOOL}::uuid`;
    await tx`delete from public.idempotency_records where school_id = ${SCHOOL}::uuid`;
    await tx`delete from public.audit_events where school_id = ${SCHOOL}::uuid`;
    await tx`delete from public.file_quota_policies where school_id = ${SCHOOL}::uuid`;
    await tx`delete from public.memberships where school_id = ${SCHOOL}::uuid`;
    await tx`delete from public.schools where id = ${SCHOOL}::uuid`;
    await tx`delete from auth.users where id = ${TEACHER}::uuid`;
    await tx`alter table public.audit_events enable trigger db020_reject_mutation`;
  });
}

async function seed(): Promise<void> {
  await sql`
    insert into auth.users (
      id, email, encrypted_password, aud, role, email_confirmed_at,
      created_at, updated_at, instance_id, confirmation_token, recovery_token,
      email_change, email_change_token_new, email_change_token_current,
      phone_change_token, raw_app_meta_data, raw_user_meta_data
    ) values (
      ${TEACHER}::uuid, 'file050.quota@synthetic.studafy.test',
      'synthetic-not-a-secret', 'authenticated', 'authenticated', now(),
      now(), now(), '00000000-0000-0000-0000-000000000000', '', '', '', '',
      '', '', '{}'::jsonb, '{"full_name":"FILE-050 Quota Teacher"}'::jsonb
    )
    on conflict (id) do nothing
  `;
  // The schools insert fires file050_seed_school_quota, which creates the
  // quota row this test then tightens.
  await sql`
    insert into public.schools (id, name, timezone, status)
    values (${SCHOOL}::uuid, 'FILE-050 Quota School', 'Asia/Riyadh', 'active')
    on conflict (id) do update set status = 'active'
  `;
  await sql`
    insert into public.memberships (school_id, user_id, role, active, status, version)
    values (${SCHOOL}::uuid, ${TEACHER}::uuid, 'teacher', true, 'active', 1)
    on conflict (school_id, user_id, role) do nothing
  `;
}

/** Clears sessions and their objects between cases, respecting the FK order. */
async function resetSessions(): Promise<void> {
  await sql.begin(async (tx) => {
    await tx`delete from public.file_job_outbox where school_id = ${SCHOOL}::uuid`;
    await tx`delete from public.file_bindings where school_id = ${SCHOOL}::uuid`;
    await tx`delete from public.upload_sessions where school_id = ${SCHOOL}::uuid`;
    await tx`delete from public.file_objects where school_id = ${SCHOOL}::uuid`;
  });
}

/** Reserves an idempotency record the way the middleware would, up front. */
async function reserve(key: string, hash: string): Promise<string> {
  const rows = await withRequestContext(
    sql,
    { subject: TEACHER, schoolId: SCHOOL, requestId: crypto.randomUUID() },
    async (tx) =>
      await tx<{ result: { id: string } }[]>`
        select private.api_idempotency_reserve(
          ${SCHOOL}::uuid, 'v1.createUploadIntent', ${key}, ${hash}
        ) as result
      `,
  );
  const id = rows[0]?.result?.id;
  if (!id) throw new Error(`reservation failed for ${key}`);
  return id;
}

/**
 * One contender. `gate` is awaited *inside* the transaction but before the
 * command, so both transactions are open and racing for the same quota-row
 * lock rather than running one after the other.
 */
function issue(
  uploadId: string,
  sizeBytes: number,
  reservationId: string,
  gate: Promise<void>,
): Promise<Contender> {
  return withRequestContext(
    sql,
    { subject: TEACHER, schoolId: SCHOOL, requestId: crypto.randomUUID() },
    async (tx) => {
      // Recorded so the assertions can prove the two contenders really ran on
      // separate backends. Were they sharing one pooled connection, the second
      // would simply queue behind the first and the quota result would look
      // correct without the row lock having done anything.
      const backend = await tx<{ pid: number }[]>`
        select pg_backend_pid() as pid
      `;
      const pid = backend[0]!.pid;
      await gate;
      const rows = await tx<{ result: IssueOutcome }[]>`
        select private.api050_issue_intent(
          ${
        tx.json({
          schoolId: SCHOOL,
          purpose: "profile_image",
          displayName: "race.png",
          expectedSizeBytes: sizeBytes,
          declaredMediaType: "image/png",
          sha256: "a".repeat(64),
        } as never)
      },
          ${
        tx.json({
          uploadId,
          bucket: "private-school-files",
          objectKey: `quarantine/v1/${uploadId}/${"z".repeat(24)}`,
          nonceHash: "b".repeat(64),
          uploadUrl: "https://storage.invalid/upload",
          expiresAt: new Date(Date.now() + 90 * 60 * 1000).toISOString(),
        } as never)
      },
          ${reservationId}::uuid, 1
        ) as result
      `;
      return {
        ...(rows[0]?.result ?? { outcome: "missing" }),
        backendPid: pid,
      };
    },
  );
}

/** Reserves under the completion scope, which the complete command requires. */
async function reserveCompletion(key: string, hash: string): Promise<string> {
  const rows = await withRequestContext(
    sql,
    { subject: TEACHER, schoolId: SCHOOL, requestId: crypto.randomUUID() },
    async (tx) =>
      await tx<{ result: { id: string } }[]>`
        select private.api_idempotency_reserve(
          ${SCHOOL}::uuid, 'v1.completeUpload', ${key}, ${hash}
        ) as result
      `,
  );
  const id = rows[0]?.result?.id;
  if (!id) throw new Error(`completion reservation failed for ${key}`);
  return id;
}

/** Issues one intent outside a race and returns its server-owned upload id. */
async function issueOne(key: string, hash: string): Promise<string> {
  const uploadId = crypto.randomUUID();
  const reservationId = await reserve(key, hash);
  let open!: () => void;
  const gate = new Promise<void>((resolve) => open = resolve);
  open();
  const result = await issue(uploadId, 8, reservationId, gate);
  if (result.outcome !== "ok") {
    throw new Error(`intent was not issued: ${result.outcome}`);
  }
  return uploadId;
}

/** One completion contender, matching the reservation exactly. */
function complete(
  uploadId: string,
  reservationId: string,
  gate: Promise<void>,
): Promise<Contender> {
  return withRequestContext(
    sql,
    { subject: TEACHER, schoolId: SCHOOL, requestId: crypto.randomUUID() },
    async (tx) => {
      const backend = await tx<{ pid: number }[]>`
        select pg_backend_pid() as pid
      `;
      const pid = backend[0]!.pid;
      await gate;
      const rows = await tx<{ result: IssueOutcome }[]>`
        select private.api050_complete_upload(
          ${uploadId}::uuid,
          ${
        tx.json({
          exists: true,
          sizeBytes: 8,
          detectedMediaType: "image/png",
          sha256: "a".repeat(64),
        } as never)
      },
          ${reservationId}::uuid, 1
        ) as result
      `;
      return {
        ...(rows[0]?.result ?? { outcome: "missing" }),
        backendPid: pid,
      };
    },
  );
}

suite("FILE-050 quota races against the real database", () => {
  beforeAll(async () => {
    sql = createDatabase(databaseUrl!);
    await cleanup();
    await seed();
  });

  afterAll(async () => {
    await cleanup();
    await sql.end();
  });

  test("the last session slot is won by exactly one of two racing intents", async () => {
    await sql`
      update public.file_quota_policies
      set user_active_sessions = 1, user_hourly_intents = 30
      where school_id = ${SCHOOL}::uuid
    `;
    const [first, second] = await Promise.all([
      reserve("file050-race-slot-a", "1".repeat(64)),
      reserve("file050-race-slot-b", "2".repeat(64)),
    ]);

    let open!: () => void;
    const gate = new Promise<void>((resolve) => open = resolve);
    const race = Promise.all([
      issue(crypto.randomUUID(), 1024, first, gate),
      issue(crypto.randomUUID(), 1024, second, gate),
    ]);
    open();
    const results = await race;

    expect(results[0]!.backendPid).not.toBe(results[1]!.backendPid);
    const outcomes = results.map((r) => r.outcome).sort();
    expect(outcomes).toEqual(["concurrency_limit", "ok"]);

    const sessions = await sql<{ count: string }[]>`
      select count(*) as count from public.upload_sessions
      where school_id = ${SCHOOL}::uuid
    `;
    expect(Number(sessions[0]!.count)).toBe(1);
  });

  test("the last quota byte is won by exactly one of two racing intents", async () => {
    await resetSessions();
    // Room for exactly one more 1 MiB reservation, and enough session slots
    // that concurrency is not what rejects the loser.
    await sql`
      update public.file_quota_policies
      set user_active_sessions = 5, user_rolling_bytes = 1048576
      where school_id = ${SCHOOL}::uuid
    `;
    const [first, second] = await Promise.all([
      reserve("file050-race-byte-a", "3".repeat(64)),
      reserve("file050-race-byte-b", "4".repeat(64)),
    ]);

    let open!: () => void;
    const gate = new Promise<void>((resolve) => open = resolve);
    const race = Promise.all([
      issue(crypto.randomUUID(), 1048576, first, gate),
      issue(crypto.randomUUID(), 1048576, second, gate),
    ]);
    open();
    const results = await race;

    expect(results[0]!.backendPid).not.toBe(results[1]!.backendPid);
    const outcomes = results.map((r) => r.outcome).sort();
    expect(outcomes).toEqual(["ok", "quota_exceeded"]);

    const sessions = await sql<{ count: string }[]>`
      select count(*) as count from public.upload_sessions
      where school_id = ${SCHOOL}::uuid
    `;
    expect(Number(sessions[0]!.count)).toBe(1);
  });
  test("concurrent completion of one session produces exactly one object", async () => {
    await sql`
      update public.file_quota_policies
      set user_active_sessions = 5, user_rolling_bytes = 104857600
      where school_id = ${SCHOOL}::uuid
    `;
    await resetSessions();
    const uploadId = await issueOne("file050-complete-race", "5".repeat(64));

    const [first, second] = await Promise.all([
      reserveCompletion("file050-complete-race-a", "6".repeat(64)),
      reserveCompletion("file050-complete-race-b", "7".repeat(64)),
    ]);

    let open!: () => void;
    const gate = new Promise<void>((resolve) => open = resolve);
    const race = Promise.all([
      complete(uploadId, first, gate),
      complete(uploadId, second, gate),
    ]);
    open();
    const results = await race;

    expect(results[0]!.backendPid).not.toBe(results[1]!.backendPid);
    const outcomes = results.map((r) => r.outcome).sort();
    expect(outcomes).toEqual(["already_completed", "ok"]);

    const counts = await sql<
      { objects: string; bindings: string; jobs: string; audits: string }[]
    >`
      select
        (select count(*) from public.file_objects
          where school_id = ${SCHOOL}::uuid) as objects,
        (select count(*) from public.file_bindings
          where school_id = ${SCHOOL}::uuid) as bindings,
        (select count(*) from public.file_job_outbox
          where school_id = ${SCHOOL}::uuid and job_type = 'scan') as jobs,
        (select count(*) from public.audit_events
          where school_id = ${SCHOOL}::uuid
            and action = 'upload_completed') as audits
    `;
    const row = counts[0]!;
    expect(Number(row.objects)).toBe(1);
    expect(Number(row.bindings)).toBe(1);
    expect(Number(row.jobs)).toBe(1);
    expect(Number(row.audits)).toBe(1);

    const state = await sql<{ scan_state: string }[]>`
      select scan_state from public.file_objects
      where school_id = ${SCHOOL}::uuid
    `;
    expect(state[0]!.scan_state).toBe("quarantined");
  });

  test("a failing outbox insert rolls the whole registration back", async () => {
    await sql`delete from public.file_job_outbox where school_id = ${SCHOOL}::uuid`;
    await sql.begin(async (tx) => {
      await tx`alter table public.audit_events disable trigger db020_reject_mutation`;
      await tx`delete from public.file_bindings where school_id = ${SCHOOL}::uuid`;
      await tx`delete from public.upload_sessions where school_id = ${SCHOOL}::uuid`;
      await tx`delete from public.file_objects where school_id = ${SCHOOL}::uuid`;
      await tx`delete from public.audit_events where school_id = ${SCHOOL}::uuid`;
      await tx`alter table public.audit_events enable trigger db020_reject_mutation`;
    });
    const uploadId = await issueOne("file050-rollback", "8".repeat(64));
    const reservationId = await reserveCompletion(
      "file050-rollback-complete",
      "9".repeat(64),
    );

    // Force the outbox leg of the registration transaction to fail.
    await sql`
      create function public.file050_force_outbox_failure()
      returns trigger language plpgsql as $$
      begin
        raise exception 'FILE050_SYNTHETIC_OUTBOX_FAILURE';
      end;
      $$
    `;
    await sql`
      create trigger file050_force_outbox_failure
      before insert on public.file_job_outbox
      for each row execute function public.file050_force_outbox_failure()
    `;
    try {
      let open!: () => void;
      const gate = new Promise<void>((resolve) => open = resolve);
      open();
      await expect(complete(uploadId, reservationId, gate)).rejects.toThrow(
        /FILE050_SYNTHETIC_OUTBOX_FAILURE/,
      );
    } finally {
      await sql`drop trigger file050_force_outbox_failure on public.file_job_outbox`;
      await sql`drop function public.file050_force_outbox_failure()`;
    }

    // Nothing from the registration may survive the failure.
    const after = await sql<
      { objects: string; bindings: string; state: string; status: string }[]
    >`
      select
        (select count(*) from public.file_objects
          where school_id = ${SCHOOL}::uuid) as objects,
        (select count(*) from public.file_bindings
          where school_id = ${SCHOOL}::uuid) as bindings,
        (select state::text from public.upload_sessions
          where id = ${uploadId}::uuid) as state,
        (select status from public.idempotency_records
          where id = ${reservationId}::uuid) as status
    `;
    const row = after[0]!;
    expect(Number(row.objects)).toBe(0);
    expect(Number(row.bindings)).toBe(0);
    expect(row.state).toBe("initiated");
    expect(row.status).not.toBe("completed");
  });
});
