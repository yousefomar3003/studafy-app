/**
 * A guardian link follows the child account across schools.
 *
 * A child with an account has one students row per school. A parent linked
 * through one of them must be the child's parent at every school the child
 * attends, and stop being so everywhere when the link is revoked.
 */
import { afterAll, beforeAll, describe, expect, test } from "bun:test";
import { createDatabase, type Sql } from "@studafy/database";
import { integrationSuite, removeFixtures } from "@studafy/test-support";

const databaseUrl = process.env["DATABASE_URL"];
const suite = integrationSuite(describe);

const P = "f07a0000-0000-4000-8000-0000000000";
const SCHOOL_A = `${P}01`;
const SCHOOL_B = `${P}02`;
const SCHOOL_C = `${P}03`;
const CHILD = `${P}11`;
const PARENT = `${P}12`;
const OTHER_PARENT = `${P}13`;
const STAFF = `${P}14`;
const ROW_A = `${P}21`;
const ROW_B = `${P}22`;
const ROW_C = `${P}23`;
const NO_ACCOUNT_A = `${P}24`;
const NO_ACCOUNT_B = `${P}25`;

let sql: Sql;

async function user(id: string): Promise<void> {
  await sql`
    insert into auth.users (
      id, email, encrypted_password, aud, role, email_confirmed_at,
      created_at, updated_at, instance_id, confirmation_token, recovery_token,
      email_change, email_change_token_new, email_change_token_current,
      phone_change_token, raw_app_meta_data, raw_user_meta_data
    ) values (
      ${id}::uuid, ${`follow.${id.slice(-2)}@synthetic.studafy.test`},
      'synthetic-not-a-secret', 'authenticated', 'authenticated', now(), now(),
      now(), '00000000-0000-0000-0000-000000000000', '', '', '', '', '', '',
      '{}'::jsonb, '{"full_name":"Follow Test"}'::jsonb
    ) on conflict (id) do nothing`;
}

async function cleanup(): Promise<void> {
  const schools = [SCHOOL_A, SCHOOL_B, SCHOOL_C];
  await removeFixtures(sql, {
    schoolIds: [...schools],
    userIds: [CHILD, PARENT, OTHER_PARENT, STAFF],
  });
}

async function link(student: string, guardian: string) {
  const rows = await sql<{ status: string }[]>`
    select status::text from public.guardian_links
    where student_id = ${student}::uuid and guardian_id = ${guardian}::uuid`;
  return rows[0]?.status ?? null;
}

suite("guardian links follow the child account", () => {
  beforeAll(async () => {
    sql = createDatabase(databaseUrl!);
    await cleanup();
    for (const id of [CHILD, PARENT, OTHER_PARENT, STAFF]) await user(id);
    await sql`
      insert into public.schools (id, name, timezone, status) values
        (${SCHOOL_A}::uuid, 'Follow A', 'Asia/Riyadh', 'active'),
        (${SCHOOL_B}::uuid, 'Follow B', 'Asia/Riyadh', 'active'),
        (${SCHOOL_C}::uuid, 'Follow C', 'Asia/Riyadh', 'active')`;
    await sql`
      insert into public.students (id, school_id, user_id, studafy_id, display_name, provisional, created_by) values
        (${ROW_A}::uuid, ${SCHOOL_A}::uuid, ${CHILD}::uuid, 'STU-FOLLOW-A', 'Child', false, ${STAFF}::uuid),
        (${ROW_B}::uuid, ${SCHOOL_B}::uuid, ${CHILD}::uuid, 'STU-FOLLOW-B', 'Child', false, ${STAFF}::uuid),
        (${NO_ACCOUNT_A}::uuid, ${SCHOOL_A}::uuid, null, 'STU-FOLLOW-NA', 'Little one', true, ${STAFF}::uuid),
        (${NO_ACCOUNT_B}::uuid, ${SCHOOL_B}::uuid, null, 'STU-FOLLOW-NB', 'Little one', true, ${STAFF}::uuid)`;
  });

  afterAll(async () => {
    if (!sql) return;
    await cleanup();
    await sql.end({ timeout: 5 });
  });

  test("a pending request stays one request", async () => {
    await sql`
      insert into public.guardian_links (school_id, student_id, guardian_id, status, relationship)
      values (${SCHOOL_A}::uuid, ${ROW_A}::uuid, ${PARENT}::uuid, 'pending', 'parent')`;
    expect(await link(ROW_B, PARENT)).toBeNull();
  });

  test("verifying it links the parent at the child's other school", async () => {
    await sql`
      update public.guardian_links
      set status = 'verified', verified_by = ${CHILD}::uuid, verified_at = now()
      where student_id = ${ROW_A}::uuid and guardian_id = ${PARENT}::uuid`;
    expect(await link(ROW_B, PARENT)).toBe("verified");
  });

  test("a school the child joins later inherits the link", async () => {
    await sql`
      insert into public.students (id, school_id, user_id, studafy_id, display_name, provisional, created_by)
      values (${ROW_C}::uuid, ${SCHOOL_C}::uuid, ${CHILD}::uuid, 'STU-FOLLOW-C', 'Child', false, ${STAFF}::uuid)`;
    expect(await link(ROW_C, PARENT)).toBe("verified");
  });

  test("revoking it ends the link everywhere", async () => {
    await sql`
      update public.guardian_links set status = 'revoked'
      where student_id = ${ROW_B}::uuid and guardian_id = ${PARENT}::uuid`;
    expect(await link(ROW_A, PARENT)).toBe("revoked");
    expect(await link(ROW_C, PARENT)).toBe("revoked");
  });

  test("children without an account are never joined up", async () => {
    // Two records with the same name at two schools are not known to be the
    // same child; nothing may link across them.
    await sql`
      insert into public.guardian_links (school_id, student_id, guardian_id, status, relationship, verified_by, verified_at)
      values (${SCHOOL_A}::uuid, ${NO_ACCOUNT_A}::uuid, ${OTHER_PARENT}::uuid, 'verified', 'parent', ${STAFF}::uuid, now())`;
    expect(await link(NO_ACCOUNT_B, OTHER_PARENT)).toBeNull();
  });
});
