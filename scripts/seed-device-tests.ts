/**
 * The synthetic school the backend-driven device tests sign in to
 * (integration_test/exam_workflow_device_test.dart and
 * integration_test/coursework_files_device_test.dart). Fictional data only.
 *
 *   school   7e570000-…-b1  "Device Test School"
 *   class    7e570000-…-d1  "Physics 10A"  dev.teacher's online exam class
 *              Dev Student (dev.student, …-e1)
 *              Dev Absentee (…-e2, a student with no account)
 *   class    7e570000-…-d2  "Science"      the files test's class
 *              Device Student (dev.student2, …-e3)
 *              "Device worksheet", a published assignment
 *   dev.parent: the verified parent of Dev Student only
 *
 * All four accounts are at synthetic.studafy.test and share the password
 * in E2E_PASSWORD.
 *
 * How each part is made:
 *   - the accounts through Supabase Auth's admin API, so passwords are hashed
 *     and confirmed as for any account;
 *   - the school, classes, students, enrolments and the parent link in SQL,
 *     because the exam test names their ids and no API command takes an id
 *     (createTeacherWorkspace, class join links and guardian links all mint
 *     their own). The rows mirror what those commands write;
 *   - the assignment through the running API (createAssignment and
 *     publishAssignment as dev.teacher), as the app makes one.
 *
 * Safe to re-run: nothing is created twice, passwords are reset to
 * E2E_PASSWORD, and the assignment is reused while it is open.
 *
 * Local and throwaway only. It reads only E2E_* variables - never the
 * DATABASE_URL or SUPABASE_URL a developer's .env holds - refuses any URL
 * that is not 127.0.0.1 or localhost, and refuses a database holding any
 * school but its own. Reset the stack first.
 *
 *   E2E_API_URL=http://127.0.0.1:8090 \
 *   E2E_SUPABASE_URL=http://127.0.0.1:54321 \
 *   E2E_DATABASE_URL=postgresql://postgres:postgres@127.0.0.1:54322/postgres \
 *   E2E_ANON_KEY=... E2E_SERVICE_ROLE_KEY=... E2E_PASSWORD=... \
 *   bun --no-env-file scripts/seed-device-tests.ts [--defines <file>]
 *
 * --defines writes the dart-defines both tests read (including the password
 * and three small synthetic files) to a JSON file for
 * `flutter drive --dart-define-from-file`. Default:
 * build/device-tests/defines.json, which git ignores.
 */
import { mkdirSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { deflateSync } from "node:zlib";
import postgres from "postgres";
import { buildDocx } from "../packages/test-support/src/officeFixtures";
import { buildPdf } from "../packages/test-support/src/pdfFixtures";

export const DEVICE_SCHOOL = {
  schoolId: "7e570000-0000-4000-8000-0000000000b1",
  termId: "7e570000-0000-4000-8000-0000000000c1",
  examClassId: "7e570000-0000-4000-8000-0000000000d1",
  filesClassId: "7e570000-0000-4000-8000-0000000000d2",
  devStudentId: "7e570000-0000-4000-8000-0000000000e1",
  absenteeId: "7e570000-0000-4000-8000-0000000000e2",
  deviceStudentId: "7e570000-0000-4000-8000-0000000000e3",
  users: {
    teacher: {
      id: "7e570000-0000-4000-8000-0000000000a1",
      email: "dev.teacher@synthetic.studafy.test",
      name: "Dev Teacher",
    },
    student: {
      id: "7e570000-0000-4000-8000-0000000000a2",
      email: "dev.student@synthetic.studafy.test",
      name: "Dev Student",
    },
    parent: {
      id: "7e570000-0000-4000-8000-0000000000a3",
      email: "dev.parent@synthetic.studafy.test",
      name: "Dev Parent",
    },
    student2: {
      id: "7e570000-0000-4000-8000-0000000000a4",
      email: "dev.student2@synthetic.studafy.test",
      name: "Device Student",
    },
  },
  assignmentTitle: "Device worksheet",
} as const;

const LOCAL_HOSTS = new Set(["127.0.0.1", "localhost", "[::1]", "::1"]);

/** Throws unless [value] is a URL on this machine. */
export function requireLocalUrl(name: string, value: string | undefined): URL {
  if (!value) throw new Error(`${name} is not set.`);
  let url: URL;
  try {
    url = new URL(value);
  } catch {
    throw new Error(`${name} is not a URL.`);
  }
  if (!LOCAL_HOSTS.has(url.hostname)) {
    throw new Error(
      `Refusing to run: ${name} must point at 127.0.0.1 or localhost, ` +
        `not ${url.hostname}. This seed is for a throwaway local stack only.`,
    );
  }
  return url;
}

function requireValue(name: string, value: string | undefined): string {
  if (!value) throw new Error(`${name} is not set.`);
  return value;
}

/** An 8x8 PNG, one flat colour, built byte for byte. */
export function buildPng(): Uint8Array {
  const crcTable = Array.from({ length: 256 }, (_, n) => {
    let c = n;
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    return c >>> 0;
  });
  const crc = (bytes: Uint8Array) => {
    let c = 0xffffffff;
    for (const byte of bytes) c = crcTable[(c ^ byte) & 0xff]! ^ (c >>> 8);
    return (c ^ 0xffffffff) >>> 0;
  };
  const u32 = (n: number) =>
    Uint8Array.of(n >>> 24, (n >>> 16) & 0xff, (n >>> 8) & 0xff, n & 0xff);
  const chunk = (type: string, data: Uint8Array) => {
    const typed = Uint8Array.from([
      ...new TextEncoder().encode(type),
      ...data,
    ]);
    return Uint8Array.from([
      ...u32(data.length),
      ...typed,
      ...u32(crc(typed)),
    ]);
  };
  const size = 8;
  const raw: number[] = [];
  for (let y = 0; y < size; y++) {
    raw.push(0); // no filter
    for (let x = 0; x < size; x++) raw.push(0x2f, 0x6f, 0xb3);
  }
  return Uint8Array.from([
    0x89,
    0x50,
    0x4e,
    0x47,
    0x0d,
    0x0a,
    0x1a,
    0x0a,
    ...chunk(
      "IHDR",
      Uint8Array.from([...u32(size), ...u32(size), 8, 2, 0, 0, 0]),
    ),
    ...chunk("IDAT", new Uint8Array(deflateSync(Uint8Array.from(raw)))),
    ...chunk("IEND", new Uint8Array()),
  ]);
}

const base64 = (bytes: Uint8Array) => Buffer.from(bytes).toString("base64");

async function main(): Promise<void> {
  const env = process.env;
  const apiUrl = requireLocalUrl("E2E_API_URL", env["E2E_API_URL"]);
  const supabaseUrl = requireLocalUrl(
    "E2E_SUPABASE_URL",
    env["E2E_SUPABASE_URL"],
  );
  const databaseUrl = requireLocalUrl(
    "E2E_DATABASE_URL",
    env["E2E_DATABASE_URL"],
  );
  const anonKey = requireValue("E2E_ANON_KEY", env["E2E_ANON_KEY"]);
  const serviceKey = requireValue(
    "E2E_SERVICE_ROLE_KEY",
    env["E2E_SERVICE_ROLE_KEY"],
  );
  const password = requireValue("E2E_PASSWORD", env["E2E_PASSWORD"]);
  if (password.length < 8) {
    throw new Error("E2E_PASSWORD must be at least 8 characters.");
  }
  const definesIndex = process.argv.indexOf("--defines");
  const definesPath = resolve(
    definesIndex > 0
      ? requireValue("--defines", process.argv[definesIndex + 1])
      : "build/device-tests/defines.json",
  );

  const auth = supabaseUrl.origin;
  const api = apiUrl.origin + apiUrl.pathname.replace(/\/$/, "");
  const s = DEVICE_SCHOOL;
  const sql = postgres(databaseUrl.href, {
    max: 1,
    connect_timeout: 5,
    onnotice: () => {},
  });

  try {
    // A throwaway stack holds nothing but this school.
    const others = await sql<{ n: number }[]>`
      select count(*)::int as n from public.schools where id <> ${s.schoolId}
    `;
    if ((others[0]?.n ?? 0) > 0) {
      throw new Error(
        "Refusing to run: this database holds other schools, so it is not a " +
          "throwaway stack. Reset it (supabase db reset) and run again.",
      );
    }

    // 1. Accounts, through Supabase Auth's admin API.
    const admin = {
      apikey: serviceKey,
      Authorization: `Bearer ${serviceKey}`,
      "Content-Type": "application/json",
    };
    for (const user of Object.values(s.users)) {
      const taken = await sql<{ id: string }[]>`
        select id from auth.users where lower(email) = ${user.email}
      `;
      if (taken[0] && taken[0].id !== user.id) {
        throw new Error(
          `${user.email} exists with another id; reset the stack first.`,
        );
      }
      const attributes = {
        email: user.email,
        password,
        email_confirm: true,
        user_metadata: { full_name: user.name, locale: "en" },
      };
      const res = taken[0]
        ? await fetch(`${auth}/auth/v1/admin/users/${user.id}`, {
          method: "PUT",
          headers: admin,
          body: JSON.stringify(attributes),
        })
        : await fetch(`${auth}/auth/v1/admin/users`, {
          method: "POST",
          headers: admin,
          body: JSON.stringify({ id: user.id, ...attributes }),
        });
      if (!res.ok) {
        throw new Error(
          `Supabase Auth refused ${user.email} (${res.status}): ${await res
            .text()}`,
        );
      }
    }

    // Storage must hold the files bucket (a migration makes it). Asking also
    // wakes Storage, whose first request can take seconds.
    const bucket = await fetch(
      `${auth}/storage/v1/bucket/private-school-files`,
      { headers: admin },
    );
    if (!bucket.ok) {
      throw new Error(
        `Storage has no private-school-files bucket (${bucket.status}).`,
      );
    }
    await bucket.body?.cancel();

    // 2. The school, mirroring createTeacherWorkspace, class join and
    //    guardian link verification. Fixed ids, so every insert is a no-op
    //    on a re-run.
    const { teacher, student, parent, student2 } = s.users;
    await sql.begin(async (tx) => {
      await tx`
        update public.profiles p set
          display_name = v.name,
          account_kind = v.kind,
          profile_completed_at = coalesce(p.profile_completed_at, now())
        from (values
          (${teacher.id}::uuid, ${teacher.name}, 'adult'),
          (${parent.id}::uuid, ${parent.name}, 'adult'),
          (${student.id}::uuid, ${student.name}, 'student'),
          (${student2.id}::uuid, ${student2.name}, 'student')
        ) as v(id, name, kind)
        where p.id = v.id
      `;
      await tx`
        insert into public.schools (id, name, timezone, locale, status, version)
        values (${s.schoolId}, 'Device Test School', 'Asia/Amman', 'en', 'active', 1)
        on conflict (id) do nothing
      `;
      await tx`
        insert into public.terms (id, school_id, name, starts_on, ends_on, active, status)
        values (${s.termId}, ${s.schoolId}, 'Device Test Year',
          current_date - 30, current_date + 365, true, 'active')
        on conflict (id) do nothing
      `;
      await tx`
        insert into public.school_content_controls (
          school_id, messaging_enabled, content_filter_level,
          classifier_assist_enabled, updated_by)
        select ${s.schoolId}, true, 'strict', false, ${teacher.id}
        where not exists (
          select 1 from public.school_content_controls
          where school_id = ${s.schoolId})
      `;
      await tx`
        insert into public.memberships (school_id, user_id, role, active, status, version)
        values
          (${s.schoolId}, ${teacher.id}, 'teacher', true, 'active', 1),
          (${s.schoolId}, ${student.id}, 'student', true, 'active', 1),
          (${s.schoolId}, ${student2.id}, 'student', true, 'active', 1)
        on conflict (school_id, user_id, role) do nothing
      `;
      await tx`
        insert into public.classrooms (
          id, school_id, term_id, name, grade, section, teacher_id, status)
        values
          (${s.examClassId}, ${s.schoolId}, ${s.termId}, 'Physics 10A', '10', 'A',
            ${teacher.id}, 'active'),
          (${s.filesClassId}, ${s.schoolId}, ${s.termId}, 'Science', '10', 'B',
            ${teacher.id}, 'active')
        on conflict (id) do nothing
      `;
      await tx`
        insert into public.classroom_staff (
          school_id, classroom_id, membership_id, user_id, role)
        select ${s.schoolId}, c.id, m.id, ${teacher.id}, 'lead_teacher'
        from public.memberships m
        cross join (values (${s.examClassId}::uuid), (${s.filesClassId}::uuid)) as c(id)
        where m.school_id = ${s.schoolId} and m.user_id = ${teacher.id}
          and m.role = 'teacher'
          and not exists (
            select 1 from public.classroom_staff cs
            where cs.classroom_id = c.id and cs.user_id = ${teacher.id})
      `;
      await tx`
        insert into public.students (
          id, school_id, user_id, studafy_id, display_name, provisional, created_by)
        values
          (${s.devStudentId}, ${s.schoolId}, ${student.id}, 'STU-DEV-0001',
            'Dev Student', false, ${teacher.id}),
          (${s.absenteeId}, ${s.schoolId}, null, 'STU-DEV-0002',
            'Dev Absentee', false, ${teacher.id}),
          (${s.deviceStudentId}, ${s.schoolId}, ${student2.id}, 'STU-DEV-0003',
            'Device Student', false, ${teacher.id})
        on conflict (id) do nothing
      `;
      await tx`
        insert into public.enrollments (
          classroom_id, student_id, active, school_id, status, starts_on)
        values
          (${s.examClassId}, ${s.devStudentId}, true, ${s.schoolId}, 'active', current_date),
          (${s.examClassId}, ${s.absenteeId}, true, ${s.schoolId}, 'active', current_date),
          (${s.filesClassId}, ${s.deviceStudentId}, true, ${s.schoolId}, 'active', current_date)
        on conflict (classroom_id, student_id) do nothing
      `;
      await tx`
        insert into public.guardian_links (
          school_id, student_id, guardian_id, status, relationship,
          verified_by, verified_at)
        values (${s.schoolId}, ${s.devStudentId}, ${parent.id}, 'verified',
          'parent', ${teacher.id}, now())
        on conflict (student_id, guardian_id) do nothing
      `;
    });

    // 3. The files test's assignment, through the real API as dev.teacher.
    const signIn = await fetch(`${auth}/auth/v1/token?grant_type=password`, {
      method: "POST",
      headers: { apikey: anonKey, "Content-Type": "application/json" },
      body: JSON.stringify({ email: teacher.email, password }),
    });
    const session = await signIn.json() as { access_token?: string };
    if (!signIn.ok || !session.access_token) {
      throw new Error(`dev.teacher could not sign in (${signIn.status}).`);
    }
    const call = async (
      method: "GET" | "POST",
      path: string,
      body?: unknown,
    ): Promise<Record<string, unknown>> => {
      const headers: Record<string, string> = {
        Authorization: `Bearer ${session.access_token}`,
        Accept: "application/json",
      };
      if (method === "POST") {
        headers["Content-Type"] = "application/json";
        headers["Idempotency-Key"] = crypto.randomUUID();
      }
      const res = await fetch(`${api}${path}`, {
        method,
        headers,
        ...(body === undefined ? {} : { body: JSON.stringify(body) }),
      });
      const parsed = await res.json().catch(() => ({})) as Record<
        string,
        unknown
      >;
      if (!res.ok) {
        throw new Error(
          `${method} ${path} failed (${res.status}): ${JSON.stringify(parsed)}`,
        );
      }
      return parsed;
    };

    type Assignment = {
      id: string;
      title: string;
      state: string;
      version: number;
      dueAt: string;
      closesAt: string | null;
    };
    const page = await call(
      "GET",
      `/v1/assignments?classroomId=${s.filesClassId}&pageSize=100`,
    );
    const open = (page["items"] as Assignment[] | undefined ?? []).find((a) =>
      a.title === s.assignmentTitle && a.state === "published" &&
      a.closesAt === null &&
      Date.parse(a.dueAt) > Date.now() + 24 * 3600 * 1000
    );
    let assignmentId = open?.id;
    if (!assignmentId) {
      const created = await call("POST", "/v1/assignments", {
        classroomId: s.filesClassId,
        title: s.assignmentTitle,
        instructions: "Answer the questions and attach your work.",
        dueAt: new Date(Date.now() + 180 * 24 * 3600 * 1000).toISOString(),
        closesAt: null,
        attachmentFileIds: [],
        links: [],
      }) as unknown as Assignment;
      await call("POST", `/v1/assignments/${created.id}/publish`, {
        expectedVersion: created.version,
      });
      assignmentId = created.id;
    }

    // 4. What the two tests read.
    const defines = {
      E2E_API_URL: api,
      E2E_SUPABASE_URL: auth,
      E2E_ANON_KEY: anonKey,
      E2E_PASSWORD: password,
      E2E_TEACHER_EMAIL: teacher.email,
      E2E_STUDENT_EMAIL: student2.email,
      E2E_SCHOOL_ID: s.schoolId,
      E2E_CLASSROOM_ID: s.filesClassId,
      E2E_ASSIGNMENT_ID: assignmentId,
      E2E_PDF_BASE64: base64(
        buildPdf([{ text: ["Device test notes", "Plants need light."] }]),
      ),
      E2E_DOCX_BASE64: base64(
        buildDocx([{ heading: "Device test slides" }, {
          paragraph: "Leaves make food from light.",
        }]),
      ),
      E2E_PNG_BASE64: base64(buildPng()),
    };
    mkdirSync(dirname(definesPath), { recursive: true });
    writeFileSync(definesPath, JSON.stringify(defines, null, 2), {
      mode: 0o600,
    });
    console.log(
      `Seeded the device test school ${s.schoolId}: classes ` +
        `${s.examClassId} and ${s.filesClassId}, assignment ${assignmentId}.`,
    );
    console.log(`Dart defines written to ${definesPath}.`);
  } finally {
    await sql.end({ timeout: 5 });
  }
}

if (import.meta.main) {
  main().catch((error) => {
    console.error(error instanceof Error ? error.message : error);
    process.exitCode = 1;
  });
}
