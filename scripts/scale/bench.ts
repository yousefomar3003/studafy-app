/**
 * Capacity benchmark (docs/operations/capacity.md).
 *
 * Replays what the API does for each request - the authorization call and
 * the module query, each its own transaction with the request's identity set
 * exactly as withVerifiedActor / withRequestContext set it - for students,
 * parents and teachers opening their everyday screens, against a database
 * seeded by prepare-scale-db.sh. It measures the database side, which is
 * where a system like this saturates first; the API adds a few milliseconds
 * of CPU per request on top and scales out by adding instances.
 *
 *   SCALE_DATABASE_URL=postgresql://postgres:postgres@127.0.0.1:54322/studafy_scale \
 *   bun scripts/scale/bench.ts --pool 5 --users 10,25,50,100 --seconds 20
 *
 * --pool      connections, like the API's pool (default 5, the API's own)
 * --users     concurrent virtual users to run, one run per value
 * --seconds   length of each run
 * --think     ms a user waits between requests (default 0: flat out)
 * --max-p95   fail (exit 1) when any screen's p95 exceeds this many ms, or
 *             any request errors - the CI regression guard
 * Sizes must match the seed: --schools --students --teachers --classes --enrol
 */
import postgres from "postgres";

const args = Bun.argv.slice(2);
const opt = (name: string, fallback: string) => {
  const i = args.indexOf(`--${name}`);
  return i >= 0 ? args[i + 1]! : fallback;
};
const url = process.env.SCALE_DATABASE_URL ?? "";
const parsed = new URL(url);
if (
  !["127.0.0.1", "localhost"].includes(parsed.hostname) ||
  !parsed.pathname.includes("scale")
) {
  throw new Error("SCALE_DATABASE_URL must be a local *scale* database.");
}
const pool = Number(opt("pool", "5"));
const userLevels = opt("users", "10,25,50,100").split(",").map(Number);
const seconds = Number(opt("seconds", "20"));
const think = Number(opt("think", "0"));
const maxP95 = Number(opt("max-p95", "0"));
const size = {
  schools: Number(opt("schools", "100")),
  students: Number(opt("students", "500")),
  teachers: Number(opt("teachers", "40")),
  classes: Number(opt("classes", "60")),
  enrol: Number(opt("enrol", "3")),
};

function sid(kind: string, a: number, b = 0): string {
  const h = new Bun.CryptoHasher("md5").update(`${kind}:${a}:${b}`).digest(
    "hex",
  );
  return `${h.slice(0, 8)}-${h.slice(8, 12)}-${h.slice(12, 16)}-${
    h.slice(16, 20)
  }-${h.slice(20)}`;
}
const pick = (n: number) => 1 + Math.floor(Math.random() * n);

const sql = postgres(url, {
  max: pool,
  prepare: true,
  onnotice: () => {},
  idle_timeout: 30,
});

type Call = {
  name: string;
  subject: string;
  school: string | null;
  permission: string | null;
  resource: string | null;
  dispatcher: string;
  operation: string;
  target: string | null;
  input: Record<string, unknown>;
  write?: boolean;
};

/** One API request: authorization, then the query, as the API runs them. */
async function request(call: Call): Promise<void> {
  if (call.permission) {
    await sql.begin(async (tx) => {
      await tx`select set_config('request.jwt.claim.sub', ${call.subject}, true)`;
      const [row] = await tx<{ d: { allowed: boolean } }[]>`
        select private.authz_authorize(${call.permission}, ${call.resource}::uuid) as d`;
      if (!row?.d?.allowed) throw new Error(`denied: ${call.name}`);
    });
  }
  await sql.begin(async (tx) => {
    await tx`select
      set_config('request.jwt.claim.sub', ${call.subject}, true),
      set_config('studafy.school_id', ${call.school ?? ""}, true),
      set_config('studafy.request_id', ${crypto.randomUUID()}, true)`;
    if (call.write) {
      const [reserved] = await tx<{ r: { id: string } }[]>`
        select private.api_idempotency_reserve(${call.school}::uuid,
          ${"v1." + call.operation}, ${crypto.randomUUID()}, ${
        "0".repeat(64)
      }) as r`;
      const [done] = await tx<{ r: { outcome: string } }[]>`
        select private.api042_command(${call.operation}, ${call.target}::uuid,
          ${tx.json(call.input as never)}, ${reserved!.r.id}::uuid, 1) as r`;
      if (done?.r?.outcome !== "ok") {
        throw new Error(`${call.name}: ${done?.r?.outcome}`);
      }
      return;
    }
    const rows = await tx.unsafe<{ r: Record<string, unknown> | null }[]>(
      `select ${call.dispatcher}($1, $2::uuid, $3::jsonb) as r`,
      [call.operation, call.target, tx.json(call.input as never)],
    );
    const result = rows[0]?.r;
    if (!result || (result.outcome && result.outcome !== "ok")) {
      throw new Error(`${call.name}: ${String(result?.outcome ?? "null")}`);
    }
  });
}

const page = { limit: 20, position: null };

/** The screens one person opens in a visit, as API requests. */
function visit(): Call[] {
  const s = pick(size.schools);
  const school = sid("school", s);
  const role = Math.random();
  if (role < 0.7) {
    const n = pick(size.students);
    const me = sid("su", s, n);
    const cls = sid("cl", s, (n * size.enrol) % size.classes);
    const conv = sid("cv", s, (n * size.enrol) % size.classes);
    const base = { subject: me, school, target: null as string | null };
    return [
      {
        ...base,
        name: "student.classes",
        permission: "classroom.list",
        resource: school,
        dispatcher: "private.api041_query",
        operation: "listClassrooms",
        input: page,
      },
      {
        ...base,
        name: "student.assignments",
        permission: "assignment.list",
        resource: school,
        dispatcher: "private.api041_query",
        operation: "listAssignments",
        input: page,
      },
      {
        ...base,
        name: "student.lessons",
        permission: "resource.list",
        resource: cls,
        dispatcher: "private.api041_query",
        operation: "listResources",
        target: cls,
        input: { ...page, classroomId: cls },
      },
      {
        ...base,
        name: "student.grades",
        permission: "grade_result.list",
        resource: school,
        dispatcher: "private.api041_query",
        operation: "listGradeResults",
        input: page,
      },
      {
        ...base,
        name: "student.unread",
        permission: null,
        resource: null,
        dispatcher: "private.api042_query",
        operation: "getUnreadCount",
        input: {},
      },
      {
        ...base,
        name: "student.notifications",
        permission: null,
        resource: null,
        dispatcher: "private.api042_query",
        operation: "listNotifications",
        input: page,
      },
      {
        ...base,
        name: "student.chats",
        permission: null,
        resource: null,
        dispatcher: "private.api042_query",
        operation: "listConversations",
        input: page,
      },
      {
        ...base,
        name: "student.messages",
        permission: "message.list",
        resource: conv,
        dispatcher: "private.api042_query",
        operation: "listMessages",
        target: conv,
        input: page,
      },
    ];
  }
  if (role < 0.9) {
    const n = pick(size.students);
    const me = sid("gu", s, n);
    const child = sid("st", s, n);
    const base = { subject: me, school: null, target: null as string | null };
    return [
      {
        ...base,
        name: "parent.children",
        permission: null,
        resource: null,
        dispatcher: "private.api042_query",
        operation: "listMyGuardianLinks",
        input: {},
      },
      {
        ...base,
        name: "parent.assignments",
        permission: "assignment.list",
        resource: child,
        dispatcher: "private.api041_query",
        operation: "listAssignments",
        input: { ...page, studentId: child },
      },
      {
        ...base,
        name: "parent.grades",
        permission: "grade_result.list",
        resource: child,
        dispatcher: "private.api041_query",
        operation: "listGradeResults",
        input: { ...page, studentId: child },
      },
      {
        ...base,
        name: "parent.unread",
        permission: null,
        resource: null,
        dispatcher: "private.api042_query",
        operation: "getUnreadCount",
        input: {},
      },
    ];
  }
  const t = pick(size.teachers);
  const me = sid("tu", s, t);
  const c = (t - 1) % size.classes;
  const cls = sid("cl", s, c);
  const conv = sid("cv", s, c);
  const base = { subject: me, school, target: null as string | null };
  return [
    {
      ...base,
      name: "teacher.classes",
      permission: "classroom.list",
      resource: school,
      dispatcher: "private.api041_query",
      operation: "listClassrooms",
      input: page,
    },
    {
      ...base,
      name: "teacher.roster",
      permission: "classroom.roster.read",
      resource: cls,
      dispatcher: "private.api041_query",
      operation: "listClassroomStudents",
      target: cls,
      input: page,
    },
    {
      ...base,
      name: "teacher.attendance",
      permission: "attendance_roster.read",
      resource: cls,
      dispatcher: "private.api041_query",
      operation: "listAttendanceRoster",
      target: cls,
      input: page,
    },
    {
      ...base,
      name: "teacher.submissions",
      permission: "submission.list",
      resource: sid("as", s, c * 1000 + 1),
      dispatcher: "private.api041_query",
      operation: "listAssignmentSubmissions",
      target: sid("as", s, c * 1000 + 1),
      input: page,
    },
    {
      ...base,
      name: "teacher.message",
      permission: "message.send",
      resource: conv,
      dispatcher: "",
      operation: "sendMessage",
      target: conv,
      write: true,
      input: {
        body: {
          clientMessageId: crypto.randomUUID(),
          body: "Reminder: homework is due Thursday.",
        },
      },
    },
  ];
}

function pct(values: number[], p: number): number {
  if (values.length === 0) return 0;
  const sorted = [...values].sort((a, b) => a - b);
  return sorted[Math.min(sorted.length - 1, Math.floor(p * sorted.length))]!;
}

async function run(users: number) {
  const latencies = new Map<string, number[]>();
  const errors = new Map<string, number>();
  let done = 0;
  const end = performance.now() + seconds * 1000;
  await Promise.all(Array.from({ length: users }, async () => {
    while (performance.now() < end) {
      for (const call of visit()) {
        if (performance.now() >= end) break;
        const started = performance.now();
        try {
          await request(call);
          const list = latencies.get(call.name) ?? [];
          list.push(performance.now() - started);
          latencies.set(call.name, list);
          done++;
        } catch (error) {
          const key = error instanceof Error
            ? error.message.slice(0, 80)
            : "error";
          errors.set(key, (errors.get(key) ?? 0) + 1);
        }
        if (think) await Bun.sleep(think);
      }
    }
  }));
  const all = [...latencies.values()].flat();
  return {
    users,
    requestsPerSecond: Math.round(done / seconds),
    p50: Math.round(pct(all, 0.5)),
    p95: Math.round(pct(all, 0.95)),
    p99: Math.round(pct(all, 0.99)),
    errors: Object.fromEntries(errors),
    slowest: [...latencies.entries()]
      .map(([name, v]) => ({
        name,
        p95: Math.round(pct(v, 0.95)),
        n: v.length,
      }))
      .sort((a, b) => b.p95 - a.p95)
      .slice(0, 5),
  };
}

let failed = false;

try {
  // Warm the pool and the caches before measuring.
  await Promise.all(Array.from({ length: pool }, () => request(visit()[0]!)));
  for (const users of userLevels) {
    const result = await run(users);
    console.log(JSON.stringify({ pool, ...result }));
    if (maxP95 > 0) {
      const slow = result.slowest.filter((row) => row.p95 > maxP95);
      if (slow.length > 0 || Object.keys(result.errors).length > 0) {
        console.error(
          JSON.stringify({
            event: "capacity_regression",
            maxP95,
            slow,
            errors: result.errors,
          }),
        );
        failed = true;
      }
    }
  }
} finally {
  await sql.end({ timeout: 5 });
}
if (failed) process.exit(1);
