/**
 * Seeds the synthetic schools the store screenshots are taken from (launch
 * plan A4): one in English and one in Arabic. Each is one teacher's own
 * teaching space (there is no school administrator in this release) with
 * Grade 8 maths and science classes, eight students, a parent linked to one
 * of them, lessons, homework, an online exam, paper tests with published
 * marks, attendance, a wellbeing note, announcements and a teacher-parent
 * conversation.
 *
 * Everything product-shaped goes through the real /v1 API over HTTP, as the
 * app sends it. The only other calls are Supabase Auth's admin API (to
 * create the accounts with a password, as Studafy provisions reviewer
 * accounts, after registering each address with
 * `allow_provisioned_email_account`) and the `record_policy_consent` RPC the
 * app calls when someone ticks the terms box.
 *
 *   bun --no-env-file scripts/store/seed-store-school.ts \
 *     --workdir <throwaway stack dir> --api http://127.0.0.1:8095 \
 *     [--messaging on]
 *
 * Without `--messaging on` no conversation is seeded, and
 * scripts/store/local-api.ts runs the API with MESSAGING_ENABLED off, so the
 * app shows no messaging. Messaging launches (DL-063), so for screenshots 6
 * and 15 start the API and run this with `--messaging on`: the school's own
 * switch is then turned on (a second direct database write; a new school
 * starts with it on since 202610160040, off between 202610160021 and that)
 * and the teacher-parent conversation seeded. AI is off when the API has no
 * AI key, as scripts/store/local-api.ts starts it.
 *
 * Names are fictional and every email is at synthetic.studafy.test. Run it
 * on a freshly reset throwaway stack: it is not idempotent.
 */
import { readStack } from "./local-api";
import postgres from "postgres";
import { CONTENT, type Question, type SchoolContent } from "./store-content";

function arg(name: string): string | undefined {
  const index = process.argv.indexOf(name);
  return index < 0 ? undefined : process.argv[index + 1];
}

/** Synthetic accounts on a local throwaway stack only; not a secret. */
export const STORE_PASSWORD = "Store-Screens-2026!";

type Json = Record<string, unknown>;
type Locale = "en" | "ar";

let supabaseUrl = "";
let serviceKey = "";
let anonKey = "";
let apiUrl = "";
let sql: postgres.Sql;

// --- Auth (Supabase) ----------------------------------------------------------

async function createUser(email: string, name: string): Promise<string> {
  // Email sign-up is refused unless the service role registered the address
  // minutes before (migration 202610150050).
  const allowed = await fetch(
    `${supabaseUrl}/rest/v1/rpc/allow_provisioned_email_account`,
    {
      method: "POST",
      headers: {
        apikey: serviceKey,
        Authorization: `Bearer ${serviceKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ requested_email: email }),
    },
  );
  if (!allowed.ok) {
    throw new Error(
      `allow ${email}: ${allowed.status} ${await allowed.text()}`,
    );
  }
  const res = await fetch(`${supabaseUrl}/auth/v1/admin/users`, {
    method: "POST",
    headers: {
      apikey: serviceKey,
      Authorization: `Bearer ${serviceKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      email,
      password: STORE_PASSWORD,
      email_confirm: true,
      user_metadata: { full_name: name },
    }),
  });
  if (!res.ok) {
    throw new Error(`create ${email}: ${res.status} ${await res.text()}`);
  }
  return ((await res.json()) as { id: string }).id;
}

async function signIn(email: string): Promise<string> {
  const res = await fetch(`${supabaseUrl}/auth/v1/token?grant_type=password`, {
    method: "POST",
    headers: { apikey: anonKey, "Content-Type": "application/json" },
    body: JSON.stringify({ email, password: STORE_PASSWORD }),
  });
  if (!res.ok) throw new Error(`sign in ${email}: ${res.status}`);
  return ((await res.json()) as { access_token: string }).access_token;
}

/** What the app records when the terms box is ticked at sign-in. */
async function recordConsent(token: string, locale: Locale): Promise<void> {
  const res = await fetch(`${supabaseUrl}/rest/v1/rpc/record_policy_consent`, {
    method: "POST",
    headers: {
      apikey: anonKey,
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      requested_purpose: "terms_and_privacy",
      requested_version: "2026-10-14",
      requested_locale: locale,
    }),
  });
  if (!res.ok) throw new Error(`consent: ${res.status} ${await res.text()}`);
}

// --- The API ------------------------------------------------------------------

class Person {
  token = "";
  id = "";
  constructor(
    readonly email: string,
    readonly name: string,
    readonly gender: "male" | "female",
    readonly kind: "student" | "adult",
  ) {}

  async call(
    method: "GET" | "POST",
    path: string,
    body?: unknown,
  ): Promise<Json> {
    const headers = new Headers({ Authorization: `Bearer ${this.token}` });
    if (method === "POST") {
      headers.set("content-type", "application/json");
      headers.set("idempotency-key", crypto.randomUUID());
    }
    const res = await fetch(`${apiUrl}${path}`, {
      method,
      headers,
      ...(body === undefined ? {} : { body: JSON.stringify(body) }),
    });
    const text = await res.text();
    if (!res.ok) {
      throw new Error(
        `${method} ${path} as ${this.email}: ${res.status} ${text}`,
      );
    }
    return text ? (JSON.parse(text) as Json) : {};
  }

  get = (path: string) => this.call("GET", path);
  post = (path: string, body: unknown = {}) => this.call("POST", path, body);

  async open(locale: Locale): Promise<this> {
    this.id = await createUser(this.email, this.name);
    this.token = await signIn(this.email);
    await recordConsent(this.token, locale);
    await this.post("/v1/account/profile", {
      displayName: this.name,
      locale,
      gender: this.gender,
      accountKind: this.kind,
      completeSetup: true,
    });
    return this;
  }
}

// --- Dates --------------------------------------------------------------------

const DAY = 86_400_000;
/** The school is in Amman: UTC+3 all year. */
const AMMAN = 3;
const now = new Date(Date.now() + AMMAN * 3_600_000);
const today = Date.UTC(
  now.getUTCFullYear(),
  now.getUTCMonth(),
  now.getUTCDate(),
);
/** An Amman wall-clock time, `days` from today, as an ISO instant. */
const at = (days: number, hour = 0, minute = 0) =>
  new Date(today + days * DAY + ((hour - AMMAN) * 60 + minute) * 60_000)
    .toISOString();
const isoDate = (days: number) =>
  new Date(today + days * DAY).toISOString().slice(0, 10);
const weekdayOf = (days: number) =>
  new Date(today + days * DAY).getUTCDay() || 7;

// --- The school -----------------------------------------------------------------

async function seedSchool(locale: Locale, c: SchoolContent): Promise<Json> {
  // --prefix lets a second run sit beside the first while the script is
  // being changed; the screenshots use the default.
  const prefix = arg("--prefix") ?? "store";
  const email = (who: string) =>
    `${prefix}.${locale}.${who}@synthetic.studafy.test`;
  console.log(`[${locale}] accounts`);
  const teacher = await new Person(
    email("teacher"),
    c.teacher.name,
    c.teacher.gender,
    "adult",
  ).open(locale);
  const parent = await new Person(
    email("parent"),
    c.parent.name,
    c.parent.gender,
    "adult",
  ).open(locale);
  const students: Person[] = [];
  for (const [index, s] of c.students.entries()) {
    const who = index === 0 ? "student" : `student${index + 1}`;
    students.push(
      await new Person(email(who), s.name, s.gender, "student").open(locale),
    );
  }
  const student = students[0]!;

  console.log(`[${locale}] teaching space and classes`);
  const space = await teacher.post("/v1/onboarding/teacher-workspace", {
    name: c.school,
    timezone: "Asia/Amman",
    locale,
  });
  const schoolId = space["id"] as string;
  const classIds: Record<string, string> = {};
  for (const cls of c.classes) {
    const created = await teacher.post("/v1/classrooms", {
      schoolId,
      name: cls.name,
      grade: cls.grade,
      section: cls.section,
      room: cls.room,
      schedule: cls.schedule.map(([weekday, startsAt, endsAt]) => ({
        weekday,
        startsAt,
        endsAt,
        effectiveFrom: isoDate(-60),
        effectiveUntil: null,
      })),
    });
    const id = created["id"] as string;
    classIds[cls.key] = id;
    const link = await teacher.post(`/v1/classrooms/${id}/join-link`, {});
    for (const index of cls.students) {
      await students[index]!.post("/v1/class-join-links/redeem", {
        token: link["token"],
      });
    }
  }

  // The one direct database write: the students joined just now, but the
  // screenshots show a class some weeks into term, with attendance already
  // taken. Enrolment start dates are moved back to the start of term; the
  // API refuses attendance for days before a student's enrolment.
  await sql`
    update public.enrollments set starts_on = ${isoDate(-45)}::date
    where school_id = ${schoolId}::uuid
  `;

  console.log(`[${locale}] parent link`);
  // The Studafy ID the student reads out from their Family screen.
  const family = await student.get("/v1/me/student-family");
  const ids = family["studentIds"] as Json[];
  const found = await parent.post("/v1/students/locate", {
    studafyId: ids[0]!["studafyId"],
  });
  if (!found["found"]) throw new Error(`locate: ${JSON.stringify(found)}`);
  const link = await parent.post("/v1/guardian-links", {
    studentId: found["studentId"],
    relationship: c.parent.relationship,
  });
  await student.post(`/v1/guardian-links/${link["id"]}/student-decision`, {
    decision: "approve",
  });

  console.log(`[${locale}] lessons`);
  for (const lesson of c.lessons) {
    const created = await teacher.post("/v1/resources", {
      schoolId,
      classroomId: classIds[lesson.classKey],
      title: lesson.title,
      resourceType: "lesson_note",
      body: lesson.body,
      audience: "both",
      ...(lesson.links ? { links: lesson.links } : {}),
    });
    await teacher.post(`/v1/resources/${created["id"]}/publish`, {
      expectedVersion: created["version"],
    });
  }

  console.log(`[${locale}] homework`);
  for (const item of c.homework) {
    const created = await teacher.post("/v1/assignments", {
      classroomId: classIds[item.classKey],
      title: item.title,
      instructions: item.instructions,
      dueAt: at(item.dueInDays, 18),
      closesAt: null,
    });
    await teacher.post(`/v1/assignments/${created["id"]}/publish`, {
      expectedVersion: created["version"],
    });
    for (const index of item.handedInBy) {
      await students[index]!.post(`/v1/assignments/${created["id"]}/submit`, {
        answerText: c.handInText,
      });
    }
  }

  console.log(`[${locale}] online exam`);
  const exam = c.exam;
  const createdExam = await teacher.post("/v1/assessments", {
    classroomId: classIds[exam.classKey],
    title: exam.title,
    category: exam.category,
    maximumScore: exam.questions.reduce((sum, q) => sum + q.maximumScore, 0),
    scheduledAt: at(0, 9),
    delivery: "online",
    opensAt: at(-1, 7),
    closesAt: at(3, 20),
    maxAttempts: 1,
    attemptPolicy: "best",
    answerRelease: "after_grading",
    questions: exam.questions.map((q, index) => ({
      position: index + 1,
      ...q,
    })),
  });
  await teacher.post(`/v1/assessments/${createdExam["id"]}/publish`, {
    expectedVersion: createdExam["version"],
  });
  // Two classmates have already sat it; the main student has not.
  const questions = (await students[1]!.get(
    `/v1/assessments/${createdExam["id"]}/questions`,
  ))["items"] as Json[];
  for (const s of students.slice(1, 3)) {
    await s.post(`/v1/assessments/${createdExam["id"]}/submit`, {
      answers: questions.map((q, index) =>
        answerFor(q, exam.questions[index]!)
      ),
    });
  }

  console.log(`[${locale}] paper tests and marks`);
  for (const test of c.paperTests) {
    const created = await teacher.post("/v1/assessments", {
      classroomId: classIds[test.classKey],
      title: test.title,
      category: test.category,
      maximumScore: test.maximumScore,
      scheduledAt: at(-test.daysAgo, 9),
      delivery: "paper",
      questions: [],
      weight: test.weight,
    });
    const id = created["id"] as string;
    const book = await teacher.get(`/v1/assessments/${id}/gradebook`);
    const rows = book["items"] as { student: Json }[];
    const entries = rows.map(({ student: row }) => {
      const index = students.findIndex((s) => s.name === row["displayName"]);
      return {
        studentId: row["id"],
        expectedVersion: 0,
        mark: "scored",
        score: test.scores[index]!,
        feedback: index === 0 ? test.feedback : null,
      };
    });
    const drafts = await teacher.post(`/v1/assessments/${id}/grades/drafts`, {
      expectedGradebookVersion: (book["item"] as Json)["gradebookVersion"],
      entries,
    });
    await teacher.post(`/v1/assessments/${id}/grades/publish`, {
      expectedGradebookVersion: drafts["gradebookVersion"],
    });
  }

  console.log(`[${locale}] attendance`);
  for (const cls of c.classes.filter((cls) => cls.attendance)) {
    const classroomId = classIds[cls.key]!;
    const roster = (await teacher.get(
      `/v1/classrooms/${classroomId}/students`,
    ))["items"] as Json[];
    let taken = 0;
    for (let day = -1; day > -30 && taken < 6; day--) {
      const slot = cls.schedule.find(([weekday]) => weekday === weekdayOf(day));
      if (!slot) continue;
      const [sh, sm] = slot[1].split(":").map(Number) as [number, number];
      const [eh, em] = slot[2].split(":").map(Number) as [number, number];
      await teacher.post("/v1/attendance/record", {
        classroomId,
        startsAt: at(day, sh, sm),
        endsAt: at(day, eh, em),
        expectedVersion: 0,
        // Past registers are locked; the class's lead teacher may still fill
        // one in, with a reason, as the app offers.
        override: true,
        correctionReason: c.attendanceReason,
        entries: roster.map((row) => {
          const index = students.findIndex((s) =>
            s.name === row["displayName"]
          );
          const state = taken === 2 && index === 3
            ? "absent"
            : taken === 1 && index === 0
            ? "late"
            : "present";
          return { studentId: row["id"], state, reason: null };
        }),
      });
      taken++;
    }
  }

  console.log(`[${locale}] wellbeing, announcements, messages, notebook`);
  const maths = classIds["maths"]!;
  const roster = (await teacher.get(`/v1/classrooms/${maths}/students`))[
    "items"
  ] as Json[];
  const mainRow = roster.find((row) => row["displayName"] === student.name)!;
  await teacher.post("/v1/wellbeing", {
    studentId: mainRow["id"],
    classroomId: maths,
    kind: "strength",
    title: c.wellbeing.title,
    context: c.wellbeing.context,
    followUp: null,
    visibility: "student_guardian_shared",
    severity: null,
  });
  for (const item of c.announcements) {
    await teacher.post("/v1/announcements", {
      schoolId,
      classroomId: classIds[item.classKey],
      title: item.title,
      body: item.body,
      audience: "both",
      important: item.important,
    });
  }
  if (arg("--messaging") === "on") {
    // The second direct database write: the school's own messaging switch,
    // on when a teaching space is made (DL-063) but off on a stack between
    // 202610160021 and 202610160040, so set either way. Only a school
    // administrator - of whom this release has none - may change it through
    // the API.
    await sql`
      update public.school_content_controls set messaging_enabled = true
      where school_id = ${schoolId}::uuid
    `;
    const conversation = await parent.post("/v1/conversations", {
      schoolId,
      participantIds: [teacher.id],
    });
    for (const [from, body] of c.conversation) {
      const who = from === "teacher" ? teacher : parent;
      await who.post(`/v1/conversations/${conversation["id"]}/messages`, {
        clientMessageId: crypto.randomUUID(),
        body,
      });
    }
  }
  await student.post(`/v1/classrooms/${maths}/notebook`, {
    title: c.note.title,
    body: c.note.body,
  });

  return { schoolId, classIds };
}

function answerFor(question: Json, spec: Question): Json {
  const questionId = question["id"] as string;
  switch (spec.kind) {
    case "single_choice":
    case "multiple_choice":
      return { questionId, selectedOptionIds: spec.correctOptionIds ?? [] };
    case "true_false":
      return { questionId, choice: spec.correctChoice ?? true };
    default:
      return {
        questionId,
        answerText: spec.acceptedAnswers?.[0] ?? spec.preferredAnswer ?? "-",
      };
  }
}

if (import.meta.main) {
  const workdir = arg("--workdir");
  if (!workdir) throw new Error("Pass --workdir <throwaway stack dir>.");
  const stack = readStack(workdir);
  supabaseUrl = stack.get("API_URL")!;
  serviceKey = stack.get("SERVICE_ROLE_KEY")!;
  anonKey = stack.get("ANON_KEY")!;
  sql = postgres(stack.get("DB_URL")!, { max: 1 });
  apiUrl = arg("--api") ?? "http://127.0.0.1:8095";
  const only = arg("--locale") as Locale | undefined;
  for (const locale of ["en", "ar"] as const) {
    if (only && only !== locale) continue;
    const ids = await seedSchool(locale, CONTENT[locale]);
    console.log(`[${locale}] done`, JSON.stringify(ids));
  }
  await sql.end({ timeout: 5 });
}
