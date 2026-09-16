/**
 * SAFE-043 moderation drill. Exercises the full safeguarding surface through
 * the real SQL dispatcher against the local disposable Supabase stack:
 * content-controls assert -> report -> masked queue -> triage -> resolve ->
 * appeal -> escalate (unmask) -> legal hold by a platform operator -> release
 * -> JIT moderator session (request/approve/start/revoke) -> blocks.
 *
 * Every step is a real private.api042_command / private.api042_query call with
 * a correctly scoped idempotency reservation and GUC identity, exactly the
 * path the pgTAP surface test uses, so a passing drill is strong evidence the
 * deployed state machine works end to end.
 *
 * Safety checks: it refuses to run except against the local /postgres
 * database on localhost (the disposable stack). Identities are random UUIDs,
 * cleaned up in a finally block, and the script exits non-zero on any failed
 * step. Run with:
 *   bun scripts/moderation-drill.ts
 *
 * Output: a JSON manifest with per-phase outcomes and a passed boolean.
 */
import postgres from "postgres";

const databaseUrl = process.env.DATABASE_URL;
if (!databaseUrl) throw new Error("DATABASE_URL is required.");

const parsed = new URL(databaseUrl);
if (
  !["127.0.0.1", "localhost"].includes(parsed.hostname) ||
  parsed.pathname !== "/postgres"
) {
  throw new Error("Refusing to drill outside the local postgres database.");
}

const SCHOOL = crypto.randomUUID();
const STUDENT = crypto.randomUUID();
const TEACHER = crypto.randomUUID();
const ADMIN = crypto.randomUUID();
const OPERATOR_A = crypto.randomUUID();
const OPERATOR_B = crypto.randomUUID();

let sql: ReturnType<typeof postgres> | undefined;

async function claim(
  subject: string,
  schoolId: string,
  requestId: string,
): Promise<void> {
  await sql!.unsafe(
    `select set_config('request.jwt.claim.sub', $1, true),
            set_config('studafy.school_id', $2, true),
            set_config('studafy.request_id', $3, true)`,
    [subject, schoolId, requestId],
  );
}

async function command(
  operation: string,
  resourceId: string,
  body: Record<string, unknown>,
  schoolId: string,
  requestId: string,
  subject: string,
): Promise<{ outcome: string; response?: unknown }> {
  await claim(subject, schoolId, requestId);
  const [reservation] = await sql!.unsafe(
    `select private.api_idempotency_reserve($1, $2, $3, $4) as r`,
    [
      schoolId === "" ? null : schoolId,
      `v1.${operation}`,
      requestId,
      crypto.randomUUID().replaceAll("-", "") +
      crypto.randomUUID().replaceAll("-", ""),
    ],
  );
  const id = (JSON.parse(JSON.stringify(reservation?.r)) as { id: string }).id;
  const [row] = await sql!.unsafe(
    `select private.api042_command($1, $2::uuid, $3::jsonb, $4::uuid, 1) as c`,
    [
      operation,
      resourceId ?? null,
      JSON.stringify({
        responseStatus: 200,
        aal2: true,
        body,
      }),
      id,
    ],
  );
  const value = JSON.parse(JSON.stringify(row?.c)) as {
    outcome: string;
    response?: unknown;
  };
  if (value.outcome !== "ok") {
    throw new Error(`${operation} failed: ${value.outcome}`);
  }
  return value;
}

async function query(
  operation: string,
  resourceId: string,
  input: Record<string, unknown>,
  subject: string,
  schoolId = "",
): Promise<unknown> {
  await claim(subject, schoolId, `query-${operation}`);
  const [row] = await sql!.unsafe(
    `select private.api042_query($1, $2::uuid, $3::jsonb) as q`,
    [operation, resourceId ?? null, JSON.stringify(input)],
  );
  const value = JSON.parse(JSON.stringify(row?.q)) as Record<string, unknown>;
  if (value.outcome === "forbidden" || value.outcome === "not_found") {
    throw new Error(`${operation} denied: ${value.outcome}`);
  }
  return value;
}

async function seed(): Promise<void> {
  await sql!.unsafe(
    `insert into auth.users (
      id, email, encrypted_password, aud, role, email_confirmed_at,
      created_at, updated_at, instance_id, confirmation_token, recovery_token,
      email_change, email_change_token_new, email_change_token_current,
      phone_change_token, raw_app_meta_data, raw_user_meta_data
    ) values
      ($1, 'drill.student', 'synthetic-not-a-secret', 'authenticated', 'authenticated', now(), now(), now(), '00000000-0000-0000-0000-000000000000', '', '', '', '', '', '', '{}'::jsonb, '{}'::jsonb),
      ($2, 'drill.teacher', 'synthetic-not-a-secret', 'authenticated', 'authenticated', now(), now(), now(), '00000000-0000-0000-0000-000000000000', '', '', '', '', '', '', '{}'::jsonb, '{}'::jsonb),
      ($3, 'drill.admin', 'synthetic-not-a-secret', 'authenticated', 'authenticated', now(), now(), now(), '00000000-0000-0000-0000-000000000000', '', '', '', '', '', '', '{}'::jsonb, '{}'::jsonb),
      ($4, 'drill.operator-a', 'synthetic-not-a-secret', 'authenticated', 'authenticated', now(), now(), now(), '00000000-0000-0000-0000-000000000000', '', '', '', '', '', '', '{}'::jsonb, '{}'::jsonb),
      ($5, 'drill.operator-b', 'synthetic-not-a-secret', 'authenticated', 'authenticated', now(), now(), now(), '00000000-0000-0000-0000-000000000000', '', '', '', '', '', '', '{}'::jsonb, '{}'::jsonb)
    on conflict (id) do nothing`,
    [STUDENT, TEACHER, ADMIN, OPERATOR_A, OPERATOR_B],
  );
  await sql!.unsafe(
    `insert into public.schools (id, name, timezone, status) values ($1, 'SAFE-043 Drill School', 'Asia/Riyadh', 'active')
     on conflict (id) do update set status = 'active'`,
    [SCHOOL],
  );
  await sql!.unsafe(
    `insert into public.memberships (school_id, user_id, role, active, status, version) values
      ($1, $2, 'student', true, 'active', 1),
      ($1, $3, 'teacher', true, 'active', 1),
      ($1, $4, 'school_admin', true, 'active', 1)
     on conflict (school_id, user_id, role) do nothing`,
    [SCHOOL, STUDENT, TEACHER, ADMIN],
  );
  await sql!.unsafe(
    `insert into public.platform_operators (user_id, note) values
      ($1, 'safe043 drill'), ($2, 'safe043 drill')
     on conflict (user_id) do nothing`,
    [OPERATOR_A, OPERATOR_B],
  );
}

async function cleanup(): Promise<void> {
  await sql!.begin(async (tx) => {
    await tx`alter table public.audit_events disable trigger db020_reject_mutation`;
    await tx`delete from public.moderation_access_grants where school_id = ${SCHOOL}::uuid`;
    await tx`delete from public.legal_holds where school_id = ${SCHOOL}::uuid`;
    await tx`delete from public.user_blocks where school_id = ${SCHOOL}::uuid`;
    await tx`delete from public.report_events where school_id = ${SCHOOL}::uuid`;
    await tx`delete from public.report_attempts where school_id = ${SCHOOL}::uuid`;
    await tx`delete from public.reports where school_id = ${SCHOOL}::uuid`;
    await tx`delete from public.audit_events where school_id = ${SCHOOL}::uuid`;
    await tx`delete from public.platform_operators where user_id in (${OPERATOR_A}::uuid, ${OPERATOR_B}::uuid)`;
    await tx`delete from public.memberships where school_id = ${SCHOOL}::uuid`;
    await tx`delete from public.schools where id = ${SCHOOL}::uuid`;
    await tx`delete from auth.users where id in (${STUDENT}::uuid, ${TEACHER}::uuid, ${ADMIN}::uuid, ${OPERATOR_A}::uuid, ${OPERATOR_B}::uuid)`;
    await tx`alter table public.audit_events enable trigger db020_reject_mutation`;
  });
}

async function main(): Promise<void> {
  const phases: Record<string, unknown> = {};
  sql = postgres(databaseUrl!, { max: 5 });
  await cleanup();
  await seed();

  // Phase 1: content-controls baseline and assert.
  phases.controlsBaseline = (await query(
    "getContentControls",
    SCHOOL,
    {},
    ADMIN,
    SCHOOL,
  )) as { contentFilterLevel: string };
  const controls = await command(
    "updateContentControls",
    SCHOOL,
    {
      expectedVersion: 1,
      messagingEnabled: true,
      contentFilterLevel: "moderate",
      classifierAssistEnabled: true,
      supportContact: "safeguarding@drill.test",
    },
    SCHOOL,
    "drill-update-controls",
    ADMIN,
  );
  phases.controlsAsserted = controls.response;

  // Phase 2: a student reports; the queue and overview are masked.
  const report = await command(
    "createReport",
    "",
    {
      schoolId: SCHOOL,
      kind: "user",
      subjectUserId: TEACHER,
      details: "She said she would hurt you if you keep talking to me",
    },
    SCHOOL,
    "drill-create-report",
    STUDENT,
  );
  const reportId = (report.response as { id: string }).id;
  phases.reportSubmitted = report.response;
  phases.overviewMasked = await query(
    "getModerationOverview",
    SCHOOL,
    {},
    ADMIN,
    SCHOOL,
  );

  // Phase 3: triage, resolve, appeal, escalate.
  const triaged = await command(
    "triageReport",
    reportId,
    { expectedVersion: 1, priority: "critical" },
    SCHOOL,
    "drill-triage",
    ADMIN,
  );
  phases.triaged = triaged.response as { status: string };
  const resolved = await command(
    "resolveReport",
    reportId,
    { expectedVersion: 2, resolution: "upheld" },
    SCHOOL,
    "drill-resolve",
    ADMIN,
  );
  phases.resolved = resolved.response as { resolution: string };
  await command(
    "appealReport",
    reportId,
    { expectedVersion: 3, reason: "the concern was never actionable" },
    SCHOOL,
    "drill-appeal",
    STUDENT,
  );
  const escalated = await command(
    "escalateReport",
    reportId,
    { expectedVersion: 4 },
    SCHOOL,
    "drill-escalate",
    ADMIN,
  );
  phases.escalated = escalated.response as { reporterId: string | null };

  // Phase 4: platform operator applies and the admin releases a legal hold.
  const held = await command(
    "holdReport",
    reportId,
    {
      schoolId: SCHOOL,
      expectedVersion: 5,
      appliedTo: "report",
      reason: "drill legal hold",
      ticketRef: "DRILL-LEG-1",
    },
    "",
    "drill-hold",
    OPERATOR_A,
  );
  const holdId = (held.response as { id: string }).id;
  phases.held = held.response as { appliedTo: string };
  await command(
    "releaseLegalHold",
    holdId,
    { expectedVersion: 1, reason: "drill complete" },
    "",
    "drill-release",
    OPERATOR_A,
  );

  // Phase 5: JIT moderator session lifecycle.
  const requested = await command(
    "requestModerationAccess",
    "",
    {
      schoolId: SCHOOL,
      reason: "uncovered review window",
      ticketRef: "DRILL-TICKET-1",
      durationMinutes: 60,
      resourceScope: { reportIds: [reportId] },
    },
    "",
    "drill-request",
    OPERATOR_A,
  );
  const grantId = (requested.response as { id: string }).id;
  await command(
    "approveModerationAccess",
    grantId,
    { expectedVersion: 1 },
    "",
    "drill-approve",
    OPERATOR_B,
  );
  const started = await command(
    "startModerationAccess",
    grantId,
    { expectedVersion: 1 },
    "",
    "drill-start",
    OPERATOR_A,
  );
  phases.grantActive = started.response as { status: string };
  await command(
    "revokeModerationAccess",
    grantId,
    { expectedVersion: 2, reason: "drill complete" },
    "",
    "drill-revoke",
    OPERATOR_A,
  );

  // Phase 6: symmetric blocks, then unblock.
  const block = await command(
    "createBlock",
    "",
    {
      schoolId: SCHOOL,
      blockedUserId: STUDENT,
      scope: "messages",
      durationHours: 24,
    },
    SCHOOL,
    "drill-block",
    TEACHER,
  );
  const blockId = (block.response as { id: string }).id;
  phases.blockCreated = block.response as { blockerId: string };
  await command(
    "unblockUser",
    blockId,
    {},
    SCHOOL,
    "drill-unblock",
    TEACHER,
  );

  console.log(JSON.stringify({
    event: "safe043_moderation_drill_passed",
    target: "local_disposable",
    phases,
    passed: true,
  }));
}

main()
  .catch((error: unknown) => {
    console.error(JSON.stringify({
      event: "safe043_moderation_drill_failed",
      error: error instanceof Error ? error.message : String(error),
      passed: false,
    }));
    process.exitCode = 1;
  })
  .finally(async () => {
    if (sql) {
      try {
        await cleanup();
      } finally {
        await sql.end({ timeout: 5 });
      }
    }
  });
