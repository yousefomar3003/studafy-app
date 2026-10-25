import { afterAll, beforeAll, describe, expect, test } from "bun:test";
import { createDatabase, type Sql } from "@studafy/database";
import type { MarkingReference, MarkingVerdict } from "@studafy/domain";
import { createJsonLogger } from "@studafy/observability";
import { integrationSuite, removeFixtures } from "@studafy/test-support";
import {
  createMarkingSuggestionsProcessor,
  postgresMarkingQueue,
} from "../src/processors/markingSuggestions";

// Suggested marks through the real SQL (ADR-0046): a suggestion the teacher
// asked for is claimed with a lease, carries the reference the run recorded
// and the class roster's names, is metered in the teacher's own ledger and
// finishes as a draft - never a mark. The provider is a stand-in. Who may
// call what is supabase/tests/marking_suggestions.sql.

const databaseUrl = process.env["DATABASE_URL"];
const suite = integrationSuite(describe);

const P = "f0b40000-0000-4000-8000-0000000000";
const SCHOOL = `${P}01`;
const TERM = `${P}02`;
const CLASSROOM = `${P}03`;
const TEACHER = `${P}11`;
const STUDENT = `${P}12`;
const STUDENT_ROW = `${P}21`;
const ASSESSMENT = `${P}31`;
const QUESTION = `${P}32`;
const ATTEMPT = `${P}33`;
const RUN = `${P}34`;
const SUGGESTION = `${P}35`;

const NAMES = { teacher: "Omar Khalil", student: "Layla Haddad" };

let sql: Sql;
const sent: { reference: MarkingReference; answer: string }[] = [];

const VERDICT: MarkingVerdict = {
  suggestedScore: 3,
  met: ["Names light as the energy source"],
  missed: ["Names oxygen"],
  rationale: "Two of the three key points.",
  feedback: "Say what the plant gives off.",
  conflict: null,
  reviewReason: null,
};

async function user(id: string, name: string): Promise<void> {
  await sql`
    insert into auth.users (
      id, email, encrypted_password, aud, role, email_confirmed_at,
      created_at, updated_at, instance_id, confirmation_token, recovery_token,
      email_change, email_change_token_new, email_change_token_current,
      phone_change_token, raw_app_meta_data, raw_user_meta_data
    ) values (
      ${id}::uuid, ${`marking.${id.slice(-2)}@synthetic.studafy.test`},
      'synthetic-not-a-secret', 'authenticated', 'authenticated', now(), now(),
      now(), '00000000-0000-0000-0000-000000000000', '', '', '', '', '', '',
      '{}'::jsonb, ${JSON.stringify({ full_name: name })}::jsonb
    ) on conflict (id) do nothing`;
  await sql`update public.profiles set display_name = ${name}
    where id = ${id}::uuid`;
}

async function cleanup(): Promise<void> {
  await sql`delete from private.marking_usage where user_id = ${TEACHER}::uuid`;
  await sql`delete from private.marking_plan_grants where user_id = ${TEACHER}::uuid`;
  await removeFixtures(sql, {
    schoolIds: [SCHOOL],
    userIds: [TEACHER, STUDENT],
  });
}

async function seed(): Promise<void> {
  await user(TEACHER, NAMES.teacher);
  await user(STUDENT, NAMES.student);
  await sql`insert into public.schools (id, name, timezone, status)
    values (${SCHOOL}::uuid, 'Marking School', 'Asia/Riyadh', 'active')`;
  await sql`
    insert into public.memberships (school_id, user_id, role, active, status, version) values
      (${SCHOOL}::uuid, ${TEACHER}::uuid, 'teacher', true, 'active', 1),
      (${SCHOOL}::uuid, ${STUDENT}::uuid, 'student', true, 'active', 1)`;
  await sql`insert into public.terms (id, school_id, name, starts_on, ends_on, active, status)
    values (${TERM}::uuid, ${SCHOOL}::uuid, 'Marking Term', current_date - 10, current_date + 90, true, 'active')`;
  await sql`insert into public.classrooms (id, school_id, term_id, name, grade, section, teacher_id, status, version)
    values (${CLASSROOM}::uuid, ${SCHOOL}::uuid, ${TERM}::uuid, 'Biology', '8', 'A', ${TEACHER}::uuid, 'active', 1)`;
  await sql`
    insert into public.classroom_staff (school_id, classroom_id, membership_id, user_id, role)
    select ${SCHOOL}::uuid, ${CLASSROOM}::uuid, m.id, m.user_id, 'lead_teacher'
    from public.memberships m where m.school_id = ${SCHOOL}::uuid and m.user_id = ${TEACHER}::uuid`;
  await sql`
    insert into public.students (id, school_id, user_id, studafy_id, display_name, provisional, created_by)
    values (${STUDENT_ROW}::uuid, ${SCHOOL}::uuid, ${STUDENT}::uuid, 'STU-MK-1', ${NAMES.student}, false, ${TEACHER}::uuid)`;
  await sql`
    insert into public.enrollments (classroom_id, student_id, school_id, status, active)
    values (${CLASSROOM}::uuid, ${STUDENT_ROW}::uuid, ${SCHOOL}::uuid, 'active', true)`;
  await sql`insert into public.assessments (id, school_id, classroom_id, title, category,
      maximum_score, state, delivery, created_by, published_at)
    values (${ASSESSMENT}::uuid, ${SCHOOL}::uuid, ${CLASSROOM}::uuid, 'Photosynthesis check',
      'quiz', 5, 'published', 'online', ${TEACHER}::uuid, now())`;
  await sql`insert into public.assessment_questions (id, school_id, assessment_id, position,
      prompt, maximum_score, kind, preferred_answer, options, answer_key)
    values (${QUESTION}::uuid, ${SCHOOL}::uuid, ${ASSESSMENT}::uuid, 1,
      'Explain photosynthesis.', 5, 'essay',
      'Light, water and carbon dioxide make glucose and oxygen.', '[]', null)`;
  await sql`insert into private.marking_references (school_id, assessment_id, question_id, key_points)
    values (${SCHOOL}::uuid, ${ASSESSMENT}::uuid, ${QUESTION}::uuid,
      '[{"text": "Names light as the energy source", "marks": 2}]')`;
  await sql`insert into public.assessment_attempts (id, school_id, assessment_id, student_id,
      operation_id, submitted_at)
    values (${ATTEMPT}::uuid, ${SCHOOL}::uuid, ${ASSESSMENT}::uuid, ${STUDENT_ROW}::uuid,
      gen_random_uuid(), now())`;
  await sql`insert into public.assessment_answers (school_id, attempt_id, question_id, answer_text)
    values (${SCHOOL}::uuid, ${ATTEMPT}::uuid, ${QUESTION}::uuid,
      ${`${NAMES.student} - plants use light from the sun to make sugar.`})`;
  await sql`insert into private.marking_plan_grants (user_id, reason, ends_at)
    values (${TEACHER}::uuid, 'integration test', now() + interval '1 day')`;
  // What the request does: a run with its snapshot, and one job.
  await sql`insert into private.marking_runs (id, school_id, assessment_id, requested_by,
      reference_version, strictness, reference_snapshot, scope)
    values (${RUN}::uuid, ${SCHOOL}::uuid, ${ASSESSMENT}::uuid, ${TEACHER}::uuid, 1,
      'balanced', private.marking_references_json(${ASSESSMENT}::uuid), 'unmarked')`;
  await sql`insert into private.marking_suggestions (id, school_id, run_id, assessment_id,
      student_id, attempt_id, question_id, maximum_score, reference_version, strictness)
    values (${SUGGESTION}::uuid, ${SCHOOL}::uuid, ${RUN}::uuid, ${ASSESSMENT}::uuid,
      ${STUDENT_ROW}::uuid, ${ATTEMPT}::uuid, ${QUESTION}::uuid, 5, 1, 'balanced')`;
}

suite("marking suggestions through the real SQL", () => {
  beforeAll(async () => {
    sql = createDatabase(databaseUrl!, { max: 2 });
    await cleanup();
    await seed();
  });

  afterAll(async () => {
    await cleanup();
    await sql.end({ timeout: 5 });
  });

  test("a claimed job is suggested, metered and kept as a draft", async () => {
    const processor = createMarkingSuggestionsProcessor({
      queue: postgresMarkingQueue(sql),
      storage: { openObject: () => Promise.reject(new Error("none")) } as never,
      assistant: {
        markAnswer: async (reference, answer) => {
          sent.push({ reference, answer });
          return {
            verdict: VERDICT,
            usage: { inputTokens: 900, outputTokens: 120, model: "stub" },
          };
        },
        transcribe: () => Promise.reject(new Error("no files here")),
      },
      prices: { inputUsdPerMTok: 0.17, outputUsdPerMTok: 0.25 },
      logger: createJsonLogger("worker", "marking-it", "error"),
      concurrency: 2,
    });
    expect(await processor.runOnce()).toBe(1);

    // The recorded reference, with the teacher's key points, and the work
    // with the student's name replaced.
    expect(sent).toHaveLength(1);
    expect(sent[0]!.reference.keyPoints).toEqual([
      { text: "Names light as the energy source", marks: 2 },
    ]);
    expect(sent[0]!.reference.preferredAnswer).toContain("glucose");
    expect(sent[0]!.answer).not.toContain("Layla");
    expect(sent[0]!.answer).toContain("[student]");

    const [row] = await sql<
      { status: string; suggested_score: string; feedback: string }[]
    >`select status, suggested_score::text, feedback
      from private.marking_suggestions where id = ${SUGGESTION}::uuid`;
    expect(row).toEqual({
      status: "ready",
      suggested_score: "3",
      feedback: "Say what the plant gives off.",
    });
    // Never a mark.
    const [answer] = await sql<{ awarded_score: string | null }[]>`
      select awarded_score::text from public.assessment_answers
      where attempt_id = ${ATTEMPT}::uuid`;
    expect(answer!.awarded_score).toBeNull();
    const [usage] = await sql<{ state: string; tokens: string }[]>`
      select state, tokens::text from private.marking_usage
      where user_id = ${TEACHER}::uuid`;
    expect(usage).toEqual({ state: "settled", tokens: "1020" });
  });

  test("nothing pending is claimed twice", async () => {
    const rows = await postgresMarkingQueue(sql).claim("other-worker", 5);
    expect(rows.filter((job) => job.id === SUGGESTION)).toEqual([]);
  });
});
