/**
 * scripts/production/clean-test-data.ts against a THROWAWAY Supabase stack:
 * two schools are seeded, one is removed, and the other - the reviewer
 * school - is proved intact, row for row, along with every account that
 * belongs anywhere else and the platform operator.
 *
 * Skipped unless the stack is named explicitly (never the developer's own
 * stack on 54322, never a hosted database):
 *
 *   CUTOVER_TEST_DATABASE_URL=postgresql://postgres:postgres@127.0.0.1:<db port>/postgres
 *   CUTOVER_TEST_SUPABASE_URL=http://127.0.0.1:<api port>
 *   CUTOVER_TEST_SERVICE_ROLE_KEY=<that stack's service role key>
 *   bun test scripts/production/clean-test-data.integration.test.ts
 *
 * It commits fixtures and removes a school: a throwaway stack only.
 */
import { afterAll, beforeAll, describe, expect, test } from "bun:test";
import { mkdtempSync, readdirSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import postgres from "postgres";
import { main } from "./clean-test-data.ts";

const DATABASE_URL = process.env["CUTOVER_TEST_DATABASE_URL"];
const SUPABASE_URL = process.env["CUTOVER_TEST_SUPABASE_URL"];
const SERVICE_KEY = process.env["CUTOVER_TEST_SERVICE_ROLE_KEY"];

function throwaway(): boolean {
  if (!DATABASE_URL || !SUPABASE_URL || !SERVICE_KEY) return false;
  const db = new URL(DATABASE_URL);
  const api = new URL(SUPABASE_URL);
  const local = (host: string) => ["127.0.0.1", "localhost"].includes(host);
  if (!local(db.hostname) || !local(api.hostname)) {
    throw new Error("CUTOVER_TEST_* must name a local throwaway stack");
  }
  if (db.port === "54322" || api.port === "54321") {
    throw new Error("refusing the developer's own stack (54321/54322)");
  }
  return true;
}

const enabled = throwaway();
const BUCKET = "private-school-files";
const run = crypto.randomUUID().slice(0, 8);
const id = () => crypto.randomUUID();

const A = {
  school: id(),
  name: `Synthetic Test School ${run}`,
  teacher: id(),
  student: id(),
  parent: id(),
  term: id(),
  classroom: id(),
  studentRow: id(),
  session: id(),
  assessment: id(),
  conversation: id(),
  file: id(),
  key: `quarantine/v1/${id()}/${"a".repeat(22)}`,
};
const B = {
  school: id(),
  name: "Cedar Grove Review School",
  teacher: id(),
  student: id(),
  parent: id(),
  term: id(),
  classroom: id(),
  studentRow: id(),
  session: id(),
  assessment: id(),
  conversation: id(),
  file: id(),
  key: `quarantine/v1/${id()}/${"b".repeat(22)}`,
};
const SHARED_TEACHER = id();
const OPERATOR = id();
type School = typeof A;

const dir = mkdtempSync(join(tmpdir(), "studafy-clean-test-"));
let secretsPath = "";
let sql: ReturnType<typeof postgres>;

async function seedUser(user: string, label: string) {
  await sql`
    insert into auth.users (
      id, email, encrypted_password, aud, role, email_confirmed_at, created_at,
      updated_at, instance_id, confirmation_token, recovery_token, email_change,
      email_change_token_new, email_change_token_current, phone_change_token,
      raw_app_meta_data, raw_user_meta_data)
    values (${user}, ${`${label}.${run}@synthetic.studafy.test`},
      'synthetic-not-a-secret', 'authenticated', 'authenticated', now(), now(),
      now(), '00000000-0000-0000-0000-000000000000', '', '', '', '', '', '',
      '{}'::jsonb, ${sql.json({ full_name: `Synthetic ${label}` })})`;
}

async function storeObject(key: string) {
  const response = await fetch(
    `${SUPABASE_URL}/storage/v1/object/${BUCKET}/${key}`,
    {
      method: "POST",
      headers: {
        authorization: `Bearer ${SERVICE_KEY}`,
        apikey: SERVICE_KEY!,
        "content-type": "application/pdf",
      },
      body: `%PDF-1.4 synthetic ${key}`,
    },
  );
  if (!response.ok) {
    throw new Error(`storage upload failed: ${response.status}`);
  }
}

async function objectExists(key: string): Promise<boolean> {
  const [row] = await sql<{ n: number }[]>`
    select count(*)::int as n from storage.objects
    where bucket_id = ${BUCKET} and name = ${key}`;
  return row!.n === 1;
}

async function seedSchool(s: School, extraTeachers: string[]) {
  for (
    const [user, label] of [
      [s.teacher, `teacher-${s.school.slice(0, 4)}`],
      [s.student, `student-${s.school.slice(0, 4)}`],
      [s.parent, `parent-${s.school.slice(0, 4)}`],
    ] as const
  ) await seedUser(user, label);
  await sql`insert into public.schools (id, name, status)
    values (${s.school}, ${s.name}, 'active')`;
  await sql`insert into public.memberships (school_id, user_id, role, active) values
    (${s.school}, ${s.teacher}, 'teacher', true),
    (${s.school}, ${s.student}, 'student', true),
    (${s.school}, ${s.parent}, 'parent', true)`;
  for (const teacher of extraTeachers) {
    await sql`insert into public.memberships (school_id, user_id, role, active)
      values (${s.school}, ${teacher}, 'teacher', true)`;
  }
  await sql`insert into public.terms (id, school_id, name, starts_on, ends_on, active)
    values (${s.term}, ${s.school}, 'Synthetic Term', '2026-09-01', '2026-12-31', true)`;
  await sql`insert into public.students (id, school_id, user_id, studafy_id, display_name, provisional, created_by)
    values (${s.studentRow}, ${s.school}, ${s.student}, ${`STU-${run}-${
    s.school.slice(0, 4)
  }`}, 'Synthetic Student', false, ${s.teacher})`;
  await sql`insert into public.guardian_links (student_id, guardian_id, status, relationship, verified_by, verified_at)
    values (${s.studentRow}, ${s.parent}, 'verified', 'parent', ${s.teacher}, now())`;
  await sql`insert into public.classrooms (id, school_id, term_id, name, grade, section, teacher_id)
    values (${s.classroom}, ${s.school}, ${s.term}, 'Synthetic Class', 'G6', 'A', ${s.teacher})`;
  await sql`insert into public.classroom_staff (school_id, classroom_id, membership_id, user_id, role)
    select ${s.school}, ${s.classroom}, m.id, ${s.teacher}, 'lead_teacher'
    from public.memberships m
    where m.school_id = ${s.school} and m.user_id = ${s.teacher} and m.role = 'teacher'`;
  await sql`insert into public.enrollments (classroom_id, student_id, active)
    values (${s.classroom}, ${s.studentRow}, true)`;
  await sql`insert into public.lesson_sessions (id, classroom_id, starts_at, ends_at, title)
    values (${s.session}, ${s.classroom}, '2026-09-10 08:00+00', '2026-09-10 09:00+00', 'Synthetic Session')`;
  await sql`insert into public.assessments (id, classroom_id, title, category, maximum_score, scheduled_at, state, delivery, created_by, published_at)
    values (${s.assessment}, ${s.classroom}, 'Synthetic Quiz', 'quiz', 10, '2026-09-10 09:00+00', 'published', 'paper', ${s.teacher}, now())`;
  await sql`insert into public.grade_results (assessment_id, student_id, score, state, reviewed_by, reviewed_at, published_at)
    values (${s.assessment}, ${s.studentRow}, 8, 'published', ${s.teacher}, now(), now())`;
  await sql`insert into public.attendance_records (session_id, student_id, state, recorded_by)
    values (${s.session}, ${s.studentRow}, 'present', ${s.teacher})`;
  await sql`insert into public.audit_events (school_id, actor_id, action, entity_type, entity_id)
    values (${s.school}, ${s.teacher}, 'fixture.seed', 'school', ${s.school})`;
  // Append-only histories, which only the purge switch lets go.
  await sql`insert into public.membership_events (school_id, membership_id, actor_id, event_type, idempotency_key)
    select ${s.school}, m.id, ${s.teacher}, 'granted', 'seed-' || m.id::text
    from public.memberships m where m.school_id = ${s.school}`;
  await sql`insert into public.grade_result_events (school_id, grade_result_id, actor_id, event_type, next_state, idempotency_key)
    select ${s.school}, g.id, ${s.teacher}, 'published', 'published', 'seed-' || g.id::text
    from public.grade_results g where g.assessment_id = ${s.assessment}`;
  await sql`insert into public.attendance_record_revisions (school_id, attendance_record_id, session_id, student_id, previous_state, previous_recorded_at, next_state, actor_id, operation_id)
    select ${s.school}, r.id, r.session_id, r.student_id, 'absent', now(), 'present', ${s.teacher}, ${id()}
    from public.attendance_records r where r.session_id = ${s.session}`;
  await sql`insert into public.auth_security_events (actor_id, school_id, event_type, outcome, reason_code)
    values (${s.teacher}, ${s.school}, 'sign_in_succeeded', 'allowed', 'seed')`;
  await sql`insert into public.conversations (id, school_id, subject, created_by)
    values (${s.conversation}, ${s.school}, 'Synthetic', ${s.teacher})`;
  await sql`insert into public.conversation_participants (school_id, conversation_id, user_id) values
    (${s.school}, ${s.conversation}, ${s.teacher}),
    (${s.school}, ${s.conversation}, ${s.parent})`;
  await sql`insert into public.messages (school_id, conversation_id, sender_id, client_message_id, body)
    values (${s.school}, ${s.conversation}, ${s.teacher}, ${id()}, 'Synthetic message')`;
  await storeObject(s.key);
  await sql`insert into public.file_objects (id, school_id, bucket, object_key, uploader_id, size_bytes, sha256, scan_state, scanned_at, policy_version)
    values (${s.file}, ${s.school}, ${BUCKET}, ${s.key}, ${s.teacher}, 20,
      ${"0".repeat(64)}, 'clean', now(), 'legacy')`;
}

/** md5 of each school-scoped table's rows for [school], and their counts. */
async function snapshot(school: string) {
  // The same tables the SQL treats as a school's (cutover_school_tables).
  const tables = await sql<{ rel: string; col: string }[]>`
    select distinct x.rel::text as rel, x.col from (
      select c.conrelid::regclass as rel, a.attname::text as col
      from pg_constraint c
      join pg_attribute a on a.attrelid = c.conrelid and a.attnum = c.conkey[1]
      where c.contype = 'f' and c.confrelid = 'public.schools'::regclass
        and cardinality(c.conkey) = 1 and c.confdeltype in ('c', 'r', 'a')
      union
      select c.oid::regclass, a.attname::text
      from pg_class c
      join pg_namespace n on n.oid = c.relnamespace
      join pg_attribute a on a.attrelid = c.oid and a.attname = 'school_id'
        and not a.attisdropped
      where c.relkind in ('r', 'p') and n.nspname in ('public', 'private')
    ) x order by 1`;
  expect(tables.length).toBeGreaterThan(70);
  const out: Record<string, { rows: number; md5: string }> = {};
  for (const { rel, col } of tables) {
    const [row] = await sql.unsafe<{ rows: number; md5: string }[]>(
      `select count(*)::int as rows,
         md5(coalesce(string_agg(x::text, E'\\n' order by x::text), '')) as md5
       from ${rel} x where x.${col} = $1`,
      [school],
    );
    out[rel] = row!;
  }
  const [schoolRow] = await sql<{ md5: string }[]>`
    select md5(x::text) as md5 from public.schools x where x.id = ${school}`;
  out["public.schools"] = {
    rows: schoolRow ? 1 : 0,
    md5: schoolRow?.md5 ?? "",
  };
  return out;
}

async function profile(user: string) {
  const [row] = await sql<
    {
      status: string;
      deleted_at: Date | null;
      email: string;
      banned_until: Date | null;
    }[]
  >`
    select p.status::text as status, p.deleted_at, u.email, u.banned_until
    from public.profiles p join auth.users u on u.id = p.id where p.id = ${user}`;
  return row!;
}

async function cli(...args: string[]) {
  const lines: string[] = [];
  const code = await main(
    ["--secrets", secretsPath, "--allow-local", ...args],
    (line) => lines.push(line),
    () => Promise.resolve(false),
  );
  return { code, out: lines.join("\n") };
}

describe.skipIf(!enabled)("clean-test-data on a throwaway stack", () => {
  let reviewerBefore: Awaited<ReturnType<typeof snapshot>>;
  let operatorsBefore: string;

  beforeAll(async () => {
    sql = postgres(DATABASE_URL!, { max: 1, onnotice: () => {} });
    secretsPath = join(dir, "cutover.env");
    writeFileSync(
      secretsPath,
      [
        `ADMIN_DATABASE_URL=${DATABASE_URL}`,
        `SUPABASE_URL=${SUPABASE_URL}`,
        `SUPABASE_SERVICE_ROLE_KEY=${SERVICE_KEY}`,
        "",
      ].join("\n"),
      { mode: 0o600 },
    );
    await seedUser(SHARED_TEACHER, "shared-teacher");
    await seedUser(OPERATOR, "operator");
    await seedSchool(A, [SHARED_TEACHER, OPERATOR]);
    await seedSchool(B, [SHARED_TEACHER]);
    await sql`insert into public.platform_operators (user_id, note)
      values (${OPERATOR}, 'synthetic operator')`;
    // The shared teacher is in a conversation in the removed school too.
    await sql`insert into public.conversation_participants (school_id, conversation_id, user_id)
      values (${A.school}, ${A.conversation}, ${SHARED_TEACHER})`;
    reviewerBefore = await snapshot(B.school);
    const [row] = await sql<{ md5: string }[]>`
      select md5(coalesce(string_agg(x::text, E'\\n' order by x::text), '')) as md5
      from public.platform_operators x`;
    operatorsBefore = row!.md5;
  });

  afterAll(async () => {
    await sql?.end({ timeout: 5 });
    rmSync(dir, { recursive: true, force: true });
  });

  test("with no school named, it lists them and marks the reviewer school", async () => {
    const { code, out } = await cli();
    expect(code).toBe(0);
    expect(out).toContain(`${A.school}  ${A.name}`);
    expect(out).toMatch(
      new RegExp(`${B.school}  Cedar Grove Review School .*REVIEWER SCHOOL`),
    );
  });

  test("the reviewer school is refused unless the flag names it too", async () => {
    const { code, out } = await cli("--schools", B.school);
    expect(code).toBe(1);
    expect(out).toContain("store reviewer school");
    expect(out).toContain("Nothing was changed.");
  });

  test("an unknown id is refused", async () => {
    const { code, out } = await cli("--schools", id());
    expect(code).toBe(1);
    expect(out).toContain("no school has id");
  });

  test("--execute without --confirm-schools is refused", async () => {
    const { code, out } = await cli("--execute", "--schools", A.school);
    expect(code).toBe(64);
    expect(out).toContain("--confirm-schools");
  });

  test("an active legal hold blocks, unless released with the school", async () => {
    await sql`insert into public.legal_holds (school_id, subject_user_id, applied_to, reason, ticket_ref, granted_by)
      values (${A.school}, ${A.student}, 'account', 'synthetic hold for the test', 'T-1', ${A.teacher})`;
    const blocked = await cli("--schools", A.school);
    expect(blocked.code).toBe(1);
    expect(blocked.out).toContain("legal hold");
  });

  test("if anything kept would change, nothing is committed", async () => {
    // A stand-in for a mistake in the SQL: removing school A's term also
    // edits the reviewer school's. The fingerprint check must catch it.
    await sql.unsafe(`
      create function pg_temp.cutover_test_side_effect() returns trigger
      language plpgsql as $$ begin
        update public.terms set name = name || ' (changed)'
        where school_id = '${B.school}';
        return old;
      end $$;
      create trigger cutover_test_side_effect before delete on public.terms
        for each row when (old.school_id = '${A.school}')
        execute function pg_temp.cutover_test_side_effect();`);
    try {
      const { code, out } = await cli(
        "--execute",
        "--confirm-schools",
        A.school,
        "--release-legal-holds",
        "--yes",
      );
      expect(code).toBe(1);
      expect(out).toContain("CUTOVER_KEPT_DATA_CHANGED");
      expect(out).toContain("terms changed");
      expect(out).not.toContain("Committed.");
    } finally {
      await sql.unsafe(
        "drop trigger cutover_test_side_effect on public.terms",
      );
    }
    expect(await snapshot(B.school)).toEqual(reviewerBefore);
    const [school] =
      await sql`select 1 from public.schools where id = ${A.school}`;
    expect(school).toBeDefined();
    expect((await profile(A.teacher)).deleted_at).toBeNull();
  });

  test("the dry run does the whole removal, reports it, and rolls back", async () => {
    const { code, out } = await cli(
      "--schools",
      A.school,
      "--release-legal-holds",
    );
    expect(out).not.toContain("Refused");
    expect(code).toBe(0);
    expect(out).toContain("DRY RUN");
    expect(out).toContain("Accounts de-identified (test-only): 3");
    expect(out).toContain('"with_another_school":1');
    expect(out).toContain('"platform_operators":1');
    expect(out).toContain("1 stored file(s) to delete");
    expect(out).toContain("Rolled back.");
    // Emails are masked.
    expect(out).not.toContain(`teacher-${A.school.slice(0, 4)}.${run}@`);
    expect(out).toMatch(/t\*\*\*@synthetic\.studafy\.test/);
    // Nothing changed.
    expect((await profile(A.teacher)).deleted_at).toBeNull();
    expect(await objectExists(A.key)).toBe(true);
    const [school] =
      await sql`select 1 from public.schools where id = ${A.school}`;
    expect(school).toBeDefined();
  });

  test("execute removes the named school and nothing else", async () => {
    const { code, out } = await cli(
      "--execute",
      "--confirm-schools",
      A.school,
      "--release-legal-holds",
      "--yes",
      "--objects-out",
      join(dir, "objects.json"),
    );
    expect(out).not.toContain("Refused");
    expect(out).toContain("Committed.");
    expect(out).toContain("Stored files deleted: 1; not deleted: 0");
    expect(code).toBe(0);

    // The school and every row of it are gone.
    const removed = await snapshot(A.school);
    for (const [table, { rows }] of Object.entries(removed)) {
      expect({ table, rows }).toEqual({ table, rows: 0 });
    }
    expect(await objectExists(A.key)).toBe(false);

    // Its test-only accounts went through the account-deletion executor.
    for (const user of [A.teacher, A.student, A.parent]) {
      const row = await profile(user);
      expect(row.status).toBe("deleted");
      expect(row.email).toBe(`deleted+${user}@deleted.invalid`);
      expect(row.banned_until).not.toBeNull();
    }

    // The reviewer school is untouched, row for row, and so is its file.
    expect(await snapshot(B.school)).toEqual(reviewerBefore);
    expect(await objectExists(B.key)).toBe(true);
    for (const user of [B.teacher, B.student, B.parent]) {
      expect((await profile(user)).deleted_at).toBeNull();
    }

    // The shared teacher and the operator keep their accounts.
    for (const user of [SHARED_TEACHER, OPERATOR]) {
      const row = await profile(user);
      expect(row.deleted_at).toBeNull();
      expect(row.banned_until).toBeNull();
    }
    const [operators] = await sql<{ md5: string }[]>`
      select md5(coalesce(string_agg(x::text, E'\\n' order by x::text), '')) as md5
      from public.platform_operators x`;
    expect(operators!.md5).toBe(operatorsBefore);
    const shared = await sql`select school_id from public.memberships
      where user_id = ${SHARED_TEACHER}`;
    expect(shared.map((row) => row["school_id"])).toEqual([B.school]);

    // The audit trail names the removed school by id.
    const [audit] = await sql`select 1 from public.audit_events
      where action = 'cutover_test_school_removed' and entity_id = ${A.school}`;
    expect(audit).toBeDefined();
    // The list of stored files was saved before they were deleted.
    expect(readdirSync(dir)).toContain("objects.json");
  });

  test("running it again refuses: the school no longer exists", async () => {
    const { code, out } = await cli(
      "--execute",
      "--confirm-schools",
      A.school,
      "--yes",
    );
    expect(code).toBe(1);
    expect(out).toContain("no school has id");
  });
});
