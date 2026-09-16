/**
 * API-042 S9: provisions one deterministic, non-production reviewer/demo
 * tenant - one school, one account per role (admin/teacher/student/
 * guardian) - entirely through the real /v1 commands (provisionSchool,
 * createTerm, createClassroom, issueInvitation/acceptInvitation,
 * assignClassroomStaff, createStudent, enrollStudent, requestGuardianLink/
 * verifyGuardianLink), never a raw SQL insert of product data. Running it is
 * itself evidence those commands compose into a working onboarding path.
 *
 * The one sanctioned direct-SQL step is granting the seeding actor a
 * platform_operators row: that grant has deliberately never been exposed
 * over any API (see docs/adr for why), so an operational script running
 * with the service role is exactly where it belongs.
 *
 * Usage (local stack only for now - see the runbook for remote/staging):
 *   bunx supabase start
 *   bun scripts/seed-reviewer-tenant.ts --local
 *   bun scripts/seed-reviewer-tenant.ts --local --reset   # wipe and redo
 *
 * Credentials are fixed and printed at the end (not a secret: this tenant
 * only exists in non-production environments). Never run against
 * ENVIRONMENT=production - the script refuses outright.
 */
import { spawnSync } from "node:child_process";
import { createDatabase, type Sql } from "../packages/database/src/index";
import { buildReviewerSeedApp } from "../apps/api/src/bootstrap/seedApp";

if ((process.env["ENVIRONMENT"] ?? "").toLowerCase() === "production") {
  throw new Error(
    "Refusing to run: ENVIRONMENT=production. This seeds fixed, publicly " +
      "documented reviewer credentials and must never touch a production project.",
  );
}
if (!process.argv.includes("--local")) {
  throw new Error(
    "Only --local is supported today. Point DATABASE_URL/SUPABASE_URL/" +
      "SUPABASE_SERVICE_ROLE_KEY/SUPABASE_PUBLISHABLE_KEY at a non-production " +
      "project by hand for staging use - see docs/security/api042-operator-runbook.md.",
  );
}
const reset = process.argv.includes("--reset");

function readLocalStack(): {
  apiUrl: string;
  dbUrl: string;
  serviceRoleKey: string;
  publishableKey: string;
} {
  const status = spawnSync("bunx", ["supabase", "status", "-o", "env"], {
    encoding: "utf8",
  });
  if (status.status !== 0) {
    throw new Error("Could not read the local stack. Run `bunx supabase start` first.");
  }
  const values = new Map<string, string>();
  for (const line of status.stdout.split("\n")) {
    const match = /^([A-Z_]+)="(.*)"$/.exec(line.trim());
    if (match?.[1] && match[2] !== undefined) values.set(match[1], match[2]);
  }
  const apiUrl = values.get("API_URL");
  const dbUrl = values.get("DB_URL");
  const serviceRoleKey = values.get("SERVICE_ROLE_KEY");
  const publishableKey = values.get("PUBLISHABLE_KEY");
  if (!apiUrl || !dbUrl || !serviceRoleKey || !publishableKey) {
    throw new Error("The local stack did not report API_URL/DB_URL/SERVICE_ROLE_KEY/PUBLISHABLE_KEY.");
  }
  return { apiUrl, dbUrl, serviceRoleKey, publishableKey };
}

const stack = readLocalStack();
const sql: Sql = createDatabase(stack.dbUrl);

const SCHOOL_NAME = "Studafy Reviewer Tenant";
// Fixed, deterministic, documented - not a secret, since this only ever
// exists in a local/disposable non-production environment.
const REVIEWER_PASSWORD = "Reviewer-Studafy-2026!";

const ROLES = ["admin", "teacher", "student", "guardian"] as const;
type ReviewerRole = (typeof ROLES)[number];
const REVIEWER_EMAIL: Record<ReviewerRole, string> = {
  admin: "reviewer.admin@synthetic.studafy.test",
  teacher: "reviewer.teacher@synthetic.studafy.test",
  student: "reviewer.student@synthetic.studafy.test",
  guardian: "reviewer.guardian@synthetic.studafy.test",
};
const SEED_OPERATOR_EMAIL = "reviewer.seed-operator@synthetic.studafy.test";

const adminHeaders = {
  apikey: stack.serviceRoleKey,
  Authorization: `Bearer ${stack.serviceRoleKey}`,
  "Content-Type": "application/json",
};

async function findUserIdByEmail(email: string): Promise<string | null> {
  const res = await fetch(
    `${stack.apiUrl}/auth/v1/admin/users?email=${encodeURIComponent(email)}`,
    { headers: adminHeaders },
  );
  if (!res.ok) return null;
  const body = await res.json() as { users?: { id: string; email?: string }[] };
  return body.users?.find((user) => user.email === email)?.id ?? null;
}

/** Creates the auth user if absent, and (re)sets its password either way, so the documented credential always works after a re-run. */
async function ensureUser(email: string, fullName: string): Promise<string> {
  const existing = await findUserIdByEmail(email);
  if (existing) {
    const res = await fetch(`${stack.apiUrl}/auth/v1/admin/users/${existing}`, {
      method: "PUT",
      headers: adminHeaders,
      body: JSON.stringify({ password: REVIEWER_PASSWORD }),
    });
    if (!res.ok) throw new Error(`Failed to reset password for ${email} (${res.status})`);
    return existing;
  }
  const res = await fetch(`${stack.apiUrl}/auth/v1/admin/users`, {
    method: "POST",
    headers: adminHeaders,
    body: JSON.stringify({
      email,
      password: REVIEWER_PASSWORD,
      email_confirm: true,
      user_metadata: { full_name: fullName },
    }),
  });
  if (!res.ok) throw new Error(`Failed to create ${email} (${res.status})`);
  const created = await res.json() as { id: string };
  return created.id;
}

async function passwordLogin(email: string): Promise<string> {
  const res = await fetch(`${stack.apiUrl}/auth/v1/token?grant_type=password`, {
    method: "POST",
    headers: { apikey: stack.publishableKey, "Content-Type": "application/json" },
    body: JSON.stringify({ email, password: REVIEWER_PASSWORD }),
  });
  if (!res.ok) throw new Error(`Login failed for ${email} (${res.status})`);
  const body = await res.json() as { access_token?: string };
  if (!body.access_token) throw new Error(`Login for ${email} returned no access token`);
  return body.access_token;
}

async function resetExistingTenant(): Promise<void> {
  const rows = await sql<{ id: string }[]>`
    select id from public.schools where name = ${SCHOOL_NAME}
  `;
  const schoolId = rows[0]?.id;
  if (!schoolId) return;
  console.log(`--reset: removing the existing reviewer tenant (${schoolId})`);
  await sql.begin(async (tx) => {
    await tx`alter table public.audit_events disable trigger db020_reject_mutation`;
    await tx`alter table public.membership_events disable trigger db020_reject_mutation`;
    await tx`delete from public.guardian_links where school_id = ${schoolId}::uuid`;
    await tx`delete from public.students where school_id = ${schoolId}::uuid`;
    await tx`delete from public.enrollments where classroom_id in (select id from public.classrooms where school_id = ${schoolId}::uuid)`;
    await tx`delete from public.classroom_staff where school_id = ${schoolId}::uuid`;
    await tx`delete from public.class_schedules where classroom_id in (select id from public.classrooms where school_id = ${schoolId}::uuid)`;
    await tx`delete from public.classrooms where school_id = ${schoolId}::uuid`;
    await tx`delete from public.terms where school_id = ${schoolId}::uuid`;
    await tx`delete from public.invitations where school_id = ${schoolId}::uuid`;
    await tx`delete from public.idempotency_records where school_id = ${schoolId}::uuid`;
    await tx`delete from public.notification_outbox where school_id = ${schoolId}::uuid`;
    await tx`delete from public.membership_events where school_id = ${schoolId}::uuid`;
    await tx`delete from public.audit_events where school_id = ${schoolId}::uuid`;
    await tx`delete from public.memberships where school_id = ${schoolId}::uuid`;
    await tx`delete from public.schools where id = ${schoolId}::uuid`;
    await tx`alter table public.membership_events enable trigger db020_reject_mutation`;
    await tx`alter table public.audit_events enable trigger db020_reject_mutation`;
  });
}

async function main(): Promise<void> {
  if (reset) await resetExistingTenant();

  const existing = await sql<{ id: string }[]>`
    select id from public.schools where name = ${SCHOOL_NAME}
  `;
  if (existing[0]) {
    console.log(
      `A reviewer tenant already exists (school ${existing[0].id}). ` +
        `Pass --reset to wipe and reprovision it. Leaving it as-is.`,
    );
    printCredentials();
    await sql.end({ timeout: 5 });
    return;
  }

  console.log("Creating reviewer accounts...");
  const userIds: Record<ReviewerRole, string> = {
    admin: await ensureUser(REVIEWER_EMAIL.admin, "Reviewer Admin"),
    teacher: await ensureUser(REVIEWER_EMAIL.teacher, "Reviewer Teacher"),
    student: await ensureUser(REVIEWER_EMAIL.student, "Reviewer Student"),
    guardian: await ensureUser(REVIEWER_EMAIL.guardian, "Reviewer Guardian"),
  };
  const seedOperatorId = await ensureUser(SEED_OPERATOR_EMAIL, "Reviewer Seed Operator");

  // The one sanctioned direct-SQL step - see the module docstring.
  await sql`
    insert into public.platform_operators (user_id, note) values
      (${seedOperatorId}::uuid, 'S9 reviewer-tenant seed script - provisioning only, never used to service a real request')
    on conflict (user_id) do nothing
  `;

  console.log("Logging in as each account to obtain real, JWKS-verifiable tokens...");
  const tokens: Record<ReviewerRole, string> = {
    admin: await passwordLogin(REVIEWER_EMAIL.admin),
    teacher: await passwordLogin(REVIEWER_EMAIL.teacher),
    student: await passwordLogin(REVIEWER_EMAIL.student),
    guardian: await passwordLogin(REVIEWER_EMAIL.guardian),
  };
  const seedOperatorToken = await passwordLogin(SEED_OPERATOR_EMAIL);

  console.log("Building the real API-042 request pipeline in-process...");
  const app = buildReviewerSeedApp(sql, stack.apiUrl);

  async function call(
    role: "seedOperator" | ReviewerRole,
    method: "GET" | "POST",
    path: string,
    body?: unknown,
  ): Promise<Record<string, unknown>> {
    const token = role === "seedOperator" ? seedOperatorToken : tokens[role];
    const headers = new Headers({
      Authorization: `Bearer ${token}`,
      "content-type": "application/json",
    });
    if (method === "POST") headers.set("idempotency-key", crypto.randomUUID());
    const res = await app.request(path, {
      method,
      headers,
      ...(body !== undefined ? { body: JSON.stringify(body) } : {}),
    });
    const parsed = await res.json().catch(() => ({})) as Record<string, unknown>;
    if (!res.ok) {
      throw new Error(`${method} ${path} as ${role} failed (${res.status}): ${JSON.stringify(parsed)}`);
    }
    return parsed;
  }

  console.log("Provisioning the school (real provisionSchool command)...");
  const school = await call("seedOperator", "POST", "/v1/schools", {
    name: SCHOOL_NAME,
    timezone: "Asia/Riyadh",
    locale: "en",
    initialAdminUserId: userIds.admin,
  });
  const schoolId = school["id"] as string;

  console.log("Creating the term and classroom (real createTerm/createClassroom)...");
  await call("admin", "POST", `/v1/schools/${schoolId}/terms`, {
    name: "Reviewer Term",
    startsOn: "2026-09-01",
    endsOn: "2027-06-30",
  });
  const classroom = await call("admin", "POST", "/v1/classrooms", {
    schoolId,
    name: "Reviewer Classroom",
    grade: "G6",
    section: "A",
    room: null,
    schedule: [],
  });
  const classroomId = classroom["id"] as string;

  console.log("Inviting the teacher, student and guardian (real issueInvitation/acceptInvitation)...");
  for (const role of ["teacher", "student", "guardian"] as const) {
    const invitation = await call("admin", "POST", `/v1/schools/${schoolId}/invitations`, {
      email: REVIEWER_EMAIL[role],
      role,
    });
    await call(role, "POST", "/v1/invitations/accept", { token: invitation["token"] });
  }

  console.log("Assigning the teacher and enrolling the student (real assignClassroomStaff/createStudent/enrollStudent)...");
  await call("admin", "POST", `/v1/classrooms/${classroomId}/staff/assign`, {
    userId: userIds.teacher,
    role: "co_teacher",
  });
  const student = await call("admin", "POST", `/v1/schools/${schoolId}/students`, {
    displayName: "Reviewer Student",
    userId: userIds.student,
  });
  const studentId = student["id"] as string;
  await call("admin", "POST", `/v1/classrooms/${classroomId}/enrollments/enroll`, {
    studentId,
  });

  console.log("Linking and verifying the guardian (real requestGuardianLink/verifyGuardianLink)...");
  const link = await call("guardian", "POST", "/v1/guardian-links", {
    studentId,
    relationship: "parent",
  });
  await call("admin", "POST", `/v1/guardian-links/${link["id"]}/verify`, {
    expiresInDays: 365,
  });

  console.log(`Reviewer tenant provisioned: school ${schoolId}.`);
  printCredentials();
  await sql.end({ timeout: 5 });
}

function printCredentials(): void {
  console.log("\nReviewer credentials (non-production only):");
  for (const role of ROLES) {
    console.log(`  ${role.padEnd(9)} ${REVIEWER_EMAIL[role]}  password: ${REVIEWER_PASSWORD}`);
  }
  console.log(
    "\nThe seed-operator account is provisioning-only and is not meant to " +
      "be handed to a reviewer.",
  );
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : error);
  process.exitCode = 1;
});
