/**
 * Real upload intents for every attachment path, through the real SQL.
 *
 * The suites that first covered chat, announcement and submission
 * attachments seeded finished file_objects rows directly, so they never ran
 * the upload intent - and two faults lived there: an upload-session check that
 * refused the new purposes outright, and a student's own submission upload
 * that could not name the student it belonged to. These call
 * private.api050_issue_intent with a real idempotency reservation, as the
 * route does, for each role that attaches something.
 */
import { afterAll, beforeAll, describe, expect, test } from "bun:test";
import { createDatabase, type Sql } from "@studafy/database";
import { withRequestContext } from "../../src/platform/dbContext";

const databaseUrl = process.env["DATABASE_URL"];
const suite = databaseUrl ? describe : describe.skip;

const P = "f05a0000-0000-4000-8000-0000000000";
const SCHOOL = `${P}01`;
const TERM = `${P}02`;
const CLASSROOM = `${P}03`;
const ASSIGNMENT = `${P}04`;
const TEACHER = `${P}11`;
const STUDENT_USER = `${P}12`;
const OTHER_STUDENT_USER = `${P}13`;
const GUARDIAN = `${P}14`;
const STUDENT_ROW = `${P}21`;
const OTHER_STUDENT_ROW = `${P}22`;

let sql: Sql;

async function authUser(id: string, name: string): Promise<void> {
  await sql`
    insert into auth.users (
      id, email, encrypted_password, aud, role, email_confirmed_at,
      created_at, updated_at, instance_id, confirmation_token, recovery_token,
      email_change, email_change_token_new, email_change_token_current,
      phone_change_token, raw_app_meta_data, raw_user_meta_data
    ) values (
      ${id}::uuid, ${`attach.${id.slice(-2)}@synthetic.studafy.test`},
      'synthetic-not-a-secret', 'authenticated', 'authenticated', now(), now(),
      now(), '00000000-0000-0000-0000-000000000000', '', '', '', '', '', '',
      '{}'::jsonb, ${JSON.stringify({ full_name: name })}::jsonb
    ) on conflict (id) do nothing
  `;
}

async function cleanup(): Promise<void> {
  await sql.begin(async (tx) => {
    await tx`alter table public.audit_events disable trigger db020_reject_mutation`;
    await tx`delete from public.file_job_outbox where school_id = ${SCHOOL}::uuid`;
    await tx`delete from public.file_bindings where school_id = ${SCHOOL}::uuid`;
    await tx`delete from public.upload_sessions where school_id = ${SCHOOL}::uuid`;
    await tx`delete from public.file_objects where school_id = ${SCHOOL}::uuid`;
    await tx`delete from public.idempotency_records where school_id = ${SCHOOL}::uuid`;
    await tx`delete from public.audit_events where school_id = ${SCHOOL}::uuid`;
    await tx`delete from public.guardian_links where school_id = ${SCHOOL}::uuid`;
    await tx`delete from public.assignments where school_id = ${SCHOOL}::uuid`;
    await tx`delete from public.enrollments where school_id = ${SCHOOL}::uuid`;
    await tx`delete from public.students where school_id = ${SCHOOL}::uuid`;
    await tx`delete from public.classroom_staff where school_id = ${SCHOOL}::uuid`;
    await tx`delete from public.classrooms where school_id = ${SCHOOL}::uuid`;
    await tx`delete from public.terms where school_id = ${SCHOOL}::uuid`;
    await tx`delete from public.file_quota_policies where school_id = ${SCHOOL}::uuid`;
    await tx`delete from public.memberships where school_id = ${SCHOOL}::uuid`;
    await tx`delete from public.schools where id = ${SCHOOL}::uuid`;
    await tx`delete from auth.users where id in (
      ${TEACHER}::uuid, ${STUDENT_USER}::uuid,
      ${OTHER_STUDENT_USER}::uuid, ${GUARDIAN}::uuid)`;
    await tx`alter table public.audit_events enable trigger db020_reject_mutation`;
  });
}

async function seed(): Promise<void> {
  await authUser(TEACHER, "Attach Teacher");
  await authUser(STUDENT_USER, "Attach Student");
  await authUser(OTHER_STUDENT_USER, "Other Student");
  await authUser(GUARDIAN, "Attach Guardian");
  await sql`
    insert into public.schools (id, name, timezone, status)
    values (${SCHOOL}::uuid, 'Attach School', 'Asia/Riyadh', 'active')
    on conflict (id) do update set status = 'active'
  `;
  // No guardian membership: the case where a parent's standing is the
  // verified link alone, which is the common one.
  await sql`
    insert into public.memberships (school_id, user_id, role, active, status, version) values
      (${SCHOOL}::uuid, ${TEACHER}::uuid, 'teacher', true, 'active', 1),
      (${SCHOOL}::uuid, ${STUDENT_USER}::uuid, 'student', true, 'active', 1),
      (${SCHOOL}::uuid, ${OTHER_STUDENT_USER}::uuid, 'student', true, 'active', 1)
    on conflict (school_id, user_id, role) do nothing
  `;
  await sql`
    insert into public.terms (id, school_id, name, starts_on, ends_on, active, status)
    values (${TERM}::uuid, ${SCHOOL}::uuid, 'Attach Term',
            current_date - 10, current_date + 90, true, 'active')
  `;
  await sql`
    insert into public.classrooms (id, school_id, term_id, name, grade, section, teacher_id, status, version)
    values (${CLASSROOM}::uuid, ${SCHOOL}::uuid, ${TERM}::uuid, 'Attach Class',
            '7', 'A', ${TEACHER}::uuid, 'active', 1)
  `;
  // Staffing is what makes someone a writer of the class; teacher_id alone is
  // not, and material uploads are checked against it.
  await sql`
    insert into public.classroom_staff (school_id, classroom_id, membership_id, user_id, role)
    select ${SCHOOL}::uuid, ${CLASSROOM}::uuid, m.id, m.user_id, 'lead_teacher'
    from public.memberships m
    where m.school_id = ${SCHOOL}::uuid and m.user_id = ${TEACHER}::uuid
  `;
  await sql`
    insert into public.students (id, school_id, user_id, studafy_id, display_name, provisional, created_by) values
      (${STUDENT_ROW}::uuid, ${SCHOOL}::uuid, ${STUDENT_USER}::uuid, 'STU-ATT-1', 'Attach Student', false, ${TEACHER}::uuid),
      (${OTHER_STUDENT_ROW}::uuid, ${SCHOOL}::uuid, ${OTHER_STUDENT_USER}::uuid, 'STU-ATT-2', 'Other Student', false, ${TEACHER}::uuid)
  `;
  await sql`
    insert into public.enrollments (classroom_id, student_id, school_id, status, active) values
      (${CLASSROOM}::uuid, ${STUDENT_ROW}::uuid, ${SCHOOL}::uuid, 'active', true),
      (${CLASSROOM}::uuid, ${OTHER_STUDENT_ROW}::uuid, ${SCHOOL}::uuid, 'active', true)
  `;
  await sql`
    insert into public.assignments (id, school_id, classroom_id, title, due_at, closes_at, state, published_at, created_by)
    values (${ASSIGNMENT}::uuid, ${SCHOOL}::uuid, ${CLASSROOM}::uuid, 'Attach Homework',
            now() + interval '7 days', now() + interval '8 days', 'published', now(),
            ${TEACHER}::uuid)
  `;
  await sql`
    insert into public.guardian_links (school_id, student_id, guardian_id, status, relationship, verified_by, verified_at)
    values (${SCHOOL}::uuid, ${STUDENT_ROW}::uuid, ${GUARDIAN}::uuid, 'verified', 'parent', ${TEACHER}::uuid, now())
  `;
}

interface Issued {
  outcome: string;
  uploadId: string;
}

/** Reserve then issue, as the route does, all as [subject]. */
async function intent(
  subject: string,
  body: Record<string, unknown>,
): Promise<Issued> {
  const uploadId = crypto.randomUUID();
  const key = `attach-${crypto.randomUUID()}`;
  return await withRequestContext(
    sql,
    { subject, schoolId: SCHOOL, requestId: crypto.randomUUID() },
    async (tx) => {
      const reserved = await tx<
        { result: { id?: string; outcome?: string } }[]
      >`
        select private.api_idempotency_reserve(
          ${SCHOOL}::uuid, 'v1.createUploadIntent', ${key}, ${"c".repeat(64)}
        ) as result
      `;
      const reservation = reserved[0]?.result;
      if (!reservation?.id) {
        return {
          outcome: `reserve:${reservation?.outcome ?? "refused"}`,
          uploadId,
        };
      }
      const rows = await tx<{ result: { outcome: string } }[]>`
        select private.api050_issue_intent(
          ${
        tx.json({
          schoolId: SCHOOL,
          displayName: "work.pdf",
          expectedSizeBytes: 1024,
          declaredMediaType: "application/pdf",
          sha256: "a".repeat(64),
          ...body,
        } as never)
      },
          ${
        tx.json({
          uploadId,
          bucket: "private-school-files",
          objectKey: `quarantine/v1/${uploadId}/${"z".repeat(24)}`,
          // Unique per session, as the route mints it: the schema refuses a
          // reused nonce within a school.
          nonceHash: crypto.randomUUID().replaceAll("-", "").repeat(2),
          uploadUrl: "https://storage.invalid/upload",
          expiresAt: new Date(Date.now() + 90 * 60 * 1000).toISOString(),
        } as never)
      },
          ${reservation.id}::uuid, 1
        ) as result
      `;
      return { outcome: rows[0]?.result?.outcome ?? "missing", uploadId };
    },
  );
}

async function sessionFor(uploadId: string) {
  const rows = await sql<{
    student_id: string | null;
    owner_membership_id: string | null;
    owner_guardian_link_id: string | null;
  }[]>`
    select student_id, owner_membership_id, owner_guardian_link_id
    from public.upload_sessions where id = ${uploadId}::uuid
  `;
  return rows[0];
}

suite("attachment upload intents over real SQL", () => {
  beforeAll(async () => {
    sql = createDatabase(databaseUrl!);
    await cleanup();
    await seed();
  });

  afterAll(async () => {
    if (!sql) return;
    await cleanup();
    await sql.end({ timeout: 5 });
  });

  test("a teacher can start a chat attachment upload", async () => {
    const issued = await intent(TEACHER, { purpose: "message_attachment" });
    expect(issued.outcome).toBe("ok");
  });

  test("a teacher can start an announcement attachment upload", async () => {
    const issued = await intent(TEACHER, {
      purpose: "announcement_attachment",
    });
    expect(issued.outcome).toBe("ok");
  });

  test("a student uploads for their own work without naming themselves", async () => {
    const issued = await intent(STUDENT_USER, {
      purpose: "assignment_submission",
      assignmentId: ASSIGNMENT,
    });
    expect(issued.outcome).toBe("ok");
    // The server resolved and recorded whose work it is.
    expect((await sessionFor(issued.uploadId))?.student_id).toBe(STUDENT_ROW);
  });

  test("a student cannot upload as another student", async () => {
    const issued = await intent(STUDENT_USER, {
      purpose: "assignment_submission",
      assignmentId: ASSIGNMENT,
      studentId: OTHER_STUDENT_ROW,
    });
    expect(issued.outcome).not.toBe("ok");
  });

  test("a guardian with no membership uploads for their linked child", async () => {
    const issued = await intent(GUARDIAN, {
      purpose: "assignment_submission",
      assignmentId: ASSIGNMENT,
      studentId: STUDENT_ROW,
    });
    expect(issued.outcome).toBe("ok");
    const session = await sessionFor(issued.uploadId);
    expect(session?.student_id).toBe(STUDENT_ROW);
    // Owned through the link, since there is no membership to own it through.
    expect(session?.owner_membership_id).toBeNull();
    expect(session?.owner_guardian_link_id).not.toBeNull();
  });

  test("a guardian cannot upload for a child they are not linked to", async () => {
    const issued = await intent(GUARDIAN, {
      purpose: "assignment_submission",
      assignmentId: ASSIGNMENT,
      studentId: OTHER_STUDENT_ROW,
    });
    expect(issued.outcome).not.toBe("ok");
  });

  test("a guardian with no membership can attach in chat", async () => {
    // What the app actually sends: a chat attachment names no student. The
    // guardian's standing in the school is their verified link to a child.
    const issued = await intent(GUARDIAN, { purpose: "message_attachment" });
    expect(issued.outcome).toBe("ok");
  });

  test("a teacher starts material for work still being written", async () => {
    // No assignment exists yet; the class is what the upload is checked
    // against, and the session records it for the bind to check again.
    const issued = await intent(TEACHER, {
      purpose: "assignment_material",
      classroomId: CLASSROOM,
    });
    expect(issued.outcome).toBe("ok");
    const rows = await sql<{ classroom_id: string | null }[]>`
      select classroom_id from public.upload_sessions
      where id = ${issued.uploadId}::uuid`;
    expect(rows[0]?.classroom_id).toBe(CLASSROOM);
  });

  test("a student cannot start material for their class", async () => {
    const issued = await intent(STUDENT_USER, {
      purpose: "assignment_material",
      classroomId: CLASSROOM,
    });
    expect(issued.outcome).not.toBe("ok");
  });

  test("a student uploads a whiteboard photo for a class they are in", async () => {
    const issued = await intent(STUDENT_USER, {
      purpose: "notebook_photo",
      classroomId: CLASSROOM,
      declaredMediaType: "image/jpeg",
      displayName: "board.jpg",
    });
    expect(issued.outcome).toBe("ok");
  });

  test("nobody uploads a whiteboard photo for a class they are not in", async () => {
    // The teacher is staff, not a student of the class; the notebook is a
    // student's.
    const teacher = await intent(TEACHER, {
      purpose: "notebook_photo",
      classroomId: CLASSROOM,
      declaredMediaType: "image/jpeg",
      displayName: "board.jpg",
    });
    expect(teacher.outcome).not.toBe("ok");
    const elsewhere = await intent(STUDENT_USER, {
      purpose: "notebook_photo",
      classroomId: crypto.randomUUID(),
      declaredMediaType: "image/jpeg",
      displayName: "board.jpg",
    });
    expect(elsewhere.outcome).not.toBe("ok");
  });
});
