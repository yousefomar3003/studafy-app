/**
 * What one study notebook costs the API (docs/capacity/2026-10-16-notebooks.md).
 *
 * Starts the real API - and with --worker, the real worker - against a
 * throwaway database, then has synthetic students on Studafy Plus each ask
 * for notebooks of one lesson (its text and a file already read into
 * passages). It waits until every notebook is written, then reports per
 * notebook:
 *
 *   - the API process's CPU time, and the worker's;
 *   - database time and statements, by runtime role (pg_stat_statements),
 *     so the API's share and the worker's are told apart;
 *   - how long the request took, and how long until the notebook was ready.
 *
 * It serves its own stand-ins, so nothing real is called or charged: a
 * signing-key server for the tokens it signs, and an OpenAI-compatible
 * provider over HTTPS that answers with a canned notebook after --ai-ms.
 *
 *   openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -nodes \
 *     -days 2 -subj "/CN=127.0.0.1" -addext "subjectAltName=IP:127.0.0.1" \
 *     -keyout ai.key -out ai.pem
 *   bun scripts/scale/notebook-load.ts --cert ai.pem --key ai.key \
 *     --admin-url postgresql://postgres:postgres@127.0.0.1:55422/postgres \
 *     --redis redis://127.0.0.1:56382 [--worker]
 *
 * It gives the two runtime roles a login password on that database, so
 * point it only at a disposable local stack: never the developer database
 * on 54322, never a hosted one. Local, synthetic data only.
 */
import postgres from "postgres";
import { dirname, resolve } from "node:path";
import { removeFixtures } from "../../packages/test-support/src/database.ts";

const args = Bun.argv.slice(2);
const opt = (name: string, fallback: string) => {
  const i = args.indexOf(`--${name}`);
  return i >= 0 ? args[i + 1]! : fallback;
};
const flag = (name: string) => args.includes(`--${name}`);

const adminUrl = opt("admin-url", "");
const redisUrl = opt("redis", "");
const certPath = opt("cert", "");
const keyPath = opt("key", "");
const students = Number(opt("students", "40"));
const perStudent = Number(opt("notebooks", "2"));
const concurrency = Number(opt("concurrency", "8"));
const aiMs = Number(opt("ai-ms", "2500"));
const apiPort = Number(opt("api-port", "8898"));
const jwksPort = Number(opt("jwks-port", "54992"));
const aiPort = Number(opt("ai-port", "54993"));
const withWorker = flag("worker");

if (!adminUrl || !redisUrl || !certPath || !keyPath) {
  throw new Error("--admin-url, --redis, --cert and --key are required.");
}
const admin = new URL(adminUrl);
if (!["127.0.0.1", "localhost"].includes(admin.hostname)) {
  throw new Error("--admin-url must be a local, disposable database.");
}
if (admin.port === "54322") {
  throw new Error("54322 is the developer database; use a throwaway stack.");
}

const repo = resolve(dirname(Bun.main), "../..");
// Another checkout's API, e.g. the commit before a change, against the same
// database: how "before" figures are taken.
const apiRoot = resolve(opt("api-root", repo));
const sql = postgres(adminUrl, { max: 4, onnotice: () => {} });

// --- Ids ---------------------------------------------------------------------
function sid(kind: string, n = 0): string {
  const h = new Bun.CryptoHasher("md5").update(`nbload:${kind}:${n}`).digest(
    "hex",
  );
  return `${h.slice(0, 8)}-${h.slice(8, 12)}-4${h.slice(13, 16)}-8${
    h.slice(17, 20)
  }-${h.slice(20)}`;
}
const SCHOOL = sid("school");
const TERM = sid("term");
const CLASS = sid("class");
const TEACHER = sid("teacher");
const LESSON = sid("lesson");
const VERSION = sid("version");
const FILE = sid("file");
const student = (n: number) => sid("student", n);
const studentRow = (n: number) => sid("student-row", n);

// --- Synthetic data ------------------------------------------------------------
const LESSON_TEXT = Array.from(
  { length: 12 },
  (_, i) =>
    `Part ${
      i + 1
    }. Photosynthesis turns light into chemical energy in the chloroplasts. ` +
    "Chlorophyll absorbs red and blue light; water is split and oxygen " +
    "released, and carbon dioxide is fixed into glucose in the Calvin cycle.",
).join("\n\n");
const CHUNKS = Array.from({ length: 30 }, (_, i) => ({
  page: i + 1,
  heading: `Page ${i + 1}`,
  body: `Leaf structure, page ${i + 1}: the palisade layer holds most ` +
    "chloroplasts; stomata open to let carbon dioxide in and water out. " +
    "Guard cells swell in light. ".repeat(6),
}));

async function seed(): Promise<void> {
  await sql.begin(async (tx) => {
    const ids = [
      TEACHER,
      ...Array.from({ length: students + 1 }, (_, i) => student(i)),
    ];
    for (const id of ids) {
      await tx`
        insert into auth.users (id, email, encrypted_password, aud, role,
          email_confirmed_at, created_at, updated_at, instance_id,
          confirmation_token, recovery_token, email_change,
          email_change_token_new, email_change_token_current,
          phone_change_token, raw_app_meta_data, raw_user_meta_data)
        values (${id}::uuid, ${`nbload.${id}@synthetic.studafy.test`},
          'synthetic-not-a-secret', 'authenticated', 'authenticated', now(),
          now(), now(), '00000000-0000-0000-0000-000000000000', '', '', '',
          '', '', '', '{}'::jsonb, '{"full_name":"Notebook Load"}'::jsonb)
        on conflict (id) do nothing`;
    }
    await tx`insert into public.schools (id, name, timezone, status)
      values (${SCHOOL}::uuid, 'Notebook Load School', 'Asia/Riyadh', 'active')`;
    await tx`insert into public.memberships (school_id, user_id, role, active, status, version)
      values (${SCHOOL}::uuid, ${TEACHER}::uuid, 'teacher', true, 'active', 1)`;
    await tx`insert into public.terms (id, school_id, name, starts_on, ends_on, active, status)
      values (${TERM}::uuid, ${SCHOOL}::uuid, 'Load Term', current_date - 10,
        current_date + 90, true, 'active')`;
    await tx`insert into public.classrooms (id, school_id, term_id, name, grade,
        section, teacher_id, status, version)
      values (${CLASS}::uuid, ${SCHOOL}::uuid, ${TERM}::uuid, 'Biology', '8',
        'A', ${TEACHER}::uuid, 'active', 1)`;
    await tx`insert into public.classroom_staff (school_id, classroom_id,
        membership_id, user_id, role)
      select ${SCHOOL}::uuid, ${CLASS}::uuid, m.id, m.user_id, 'lead_teacher'
      from public.memberships m
      where m.school_id = ${SCHOOL}::uuid and m.user_id = ${TEACHER}::uuid`;
    for (let n = 0; n <= students; n++) {
      await tx`insert into public.memberships (school_id, user_id, role, active, status, version)
        values (${SCHOOL}::uuid, ${
        student(n)
      }::uuid, 'student', true, 'active', 1)`;
      await tx`insert into public.students (id, school_id, user_id, studafy_id,
          display_name, provisional, created_by)
        values (${studentRow(n)}::uuid, ${SCHOOL}::uuid, ${student(n)}::uuid,
          ${`STU-NBL-${n}`}, ${`Load Student ${n}`}, false, ${TEACHER}::uuid)`;
      await tx`insert into public.enrollments (classroom_id, student_id, school_id, status, active)
        values (${CLASS}::uuid, ${
        studentRow(n)
      }::uuid, ${SCHOOL}::uuid, 'active', true)`;
      await tx`insert into private.study_plan_grants (user_id, plan, reason, ends_at)
        values (${
        student(n)
      }::uuid, 'plus', 'notebook load', now() + interval '1 day')`;
      // The AI consent (ADR-0043): without it the API refuses the request
      // and the ledger the worker's hold.
      await tx`insert into public.consent_records (user_id, purpose,
          policy_version, locale, policy_id, given_by, given_as)
        select ${student(n)}::uuid, 'ai_features', p.policy_version, 'en',
          p.id, ${student(n)}::uuid, 'self'
        from public.consent_policies p
        where p.purpose = 'ai_features' and p.locale = 'en'
        order by p.effective_at desc, p.policy_version desc limit 1
        on conflict (user_id, purpose, policy_version)
          do update set withdrawn_at = null`;
    }
    // A read PDF on the lesson: its passages are what the notebook reads.
    const digest = new Bun.CryptoHasher("sha256").update(FILE).digest("hex");
    await tx`insert into public.file_objects (id, school_id, bucket, object_key,
        uploader_id, size_bytes, declared_media_type, detected_media_type,
        sha256, stored_sha256, stored_size_bytes, scan_state, scanned_at,
        owner_id, purpose, display_name)
      values (${FILE}::uuid, ${SCHOOL}::uuid, 'legacy', ${`nbload/${FILE}`},
        ${TEACHER}::uuid, 10, 'application/pdf', 'application/pdf', ${digest},
        ${digest}, 10, 'clean', now(), ${TEACHER}::uuid, 'lesson_resource',
        'Leaves.pdf')`;
    await tx`insert into private.ai_material_docs (school_id, file_object_id)
      values (${SCHOOL}::uuid, ${FILE}::uuid) on conflict do nothing`;
    await tx`update private.ai_material_docs set state = 'processing',
        worker_id = 'nbload', lease_until = now() + interval '10 minutes'
      where file_object_id = ${FILE}::uuid`;
    const [doc] = await tx<{ id: string }[]>`
      select id from private.ai_material_docs where file_object_id = ${FILE}::uuid`;
    await tx`select private.ai_material_finish('nbload', ${doc!.id}::uuid, ${
      tx.json({
        outcome: "ready",
        extractor: "load",
        chunks: CHUNKS,
        detail: {},
        usage: [],
      })
    })`;
    await tx`insert into public.resources (id, school_id, title, resource_type,
        state, current_version, created_by)
      values (${LESSON}::uuid, ${SCHOOL}::uuid, 'Photosynthesis', 'lesson_note',
        'published', 1, ${TEACHER}::uuid)`;
    await tx`insert into public.resource_versions (id, school_id, resource_id,
        version, body, file_object_id, created_by)
      values (${VERSION}::uuid, ${SCHOOL}::uuid, ${LESSON}::uuid, 1,
        ${LESSON_TEXT}, ${FILE}::uuid, ${TEACHER}::uuid)`;
    await tx`insert into public.resource_publications (school_id,
        resource_version_id, classroom_id, audience, state, published_at,
        created_by)
      values (${SCHOOL}::uuid, ${VERSION}::uuid, ${CLASS}::uuid, 'both',
        'published', now(), ${TEACHER}::uuid)`;
  });
}

async function cleanup(): Promise<void> {
  await removeFixtures(sql as never, {
    schoolIds: [SCHOOL],
    userIds: [
      TEACHER,
      ...Array.from({ length: students + 1 }, (_, i) => student(i)),
    ],
  });
}

// --- Stand-ins -------------------------------------------------------------------
const kid = "notebook-load";
const ecdsa = { name: "ECDSA", namedCurve: "P-256" };
const keys = await crypto.subtle.generateKey(ecdsa, true, [
  "sign",
  "verify",
]) as CryptoKeyPair;
const publicJwk = await crypto.subtle.exportKey("jwk", keys.publicKey);
const issuer = `http://127.0.0.1:${jwksPort}/auth/v1`;
const b64 = (bytes: Uint8Array | string) =>
  Buffer.from(bytes).toString("base64url");

async function token(sub: string): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const head = b64(JSON.stringify({ alg: "ES256", kid, typ: "JWT" }));
  const body = b64(JSON.stringify({
    iss: issuer,
    aud: "authenticated",
    sub,
    role: "authenticated",
    aal: "aal1",
    iat: now,
    exp: now + 3600,
  }));
  const signature = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" },
    keys.privateKey,
    new TextEncoder().encode(`${head}.${body}`),
  );
  return `${head}.${body}.${b64(new Uint8Array(signature))}`;
}

const jwksServer = Bun.serve({
  port: jwksPort,
  hostname: "127.0.0.1",
  fetch: (request) =>
    new URL(request.url).pathname === "/auth/v1/.well-known/jwks.json"
      ? Response.json({
        keys: [{ ...publicJwk, kid, alg: "ES256", use: "sig" }],
      })
      : new Response("not found", { status: 404 }),
});

/** A notebook the size of a real one (~2.5k output tokens). */
const NOTEBOOK_REPLY = JSON.stringify({
  overview: "Plants turn light, water and carbon dioxide into glucose and " +
    "oxygen. This notebook follows the lesson and its file.",
  objectives: [
    "Explain where photosynthesis happens",
    "Describe the light and dark reactions",
  ],
  keyTerms: Array.from({ length: 8 }, (_, i) => ({
    term: `Term ${i + 1}`,
    definition: "A part of the process described in the lesson, in a sentence.",
    source: "Photosynthesis",
  })),
  sections: Array.from({ length: 8 }, (_, i) => ({
    heading: `Section ${i + 1}: how leaves capture light`,
    paragraphs: Array.from(
      { length: 3 },
      () =>
        "Chloroplasts in the palisade layer absorb light with chlorophyll. " +
        "The energy splits water, releasing oxygen, and drives the making " +
        "of glucose from carbon dioxide in the Calvin cycle.",
    ),
    points: ["Stomata let carbon dioxide in", "Guard cells swell in light"],
    sources: ["Leaves.pdf"],
  })),
  examples: [{
    title: "A leaf in the dark",
    steps: ["No light", "No glucose"],
  }],
  facts: ["6CO2 + 6H2O -> C6H12O6 + 6O2"],
  mistakes: ["Plants do not get their food from the soil"],
  summary: ["Light becomes chemical energy", "Oxygen is a by-product"],
});

const ai = { calls: 0 };
const aiServer = Bun.serve({
  port: aiPort,
  hostname: "127.0.0.1",
  tls: { cert: Bun.file(certPath), key: Bun.file(keyPath) },
  async fetch(request) {
    if (!new URL(request.url).pathname.endsWith("/chat/completions")) {
      return new Response("not found", { status: 404 });
    }
    const body = await request.json() as {
      messages?: { content?: string }[];
      model?: string;
    };
    ai.calls++;
    await Bun.sleep(aiMs * (0.67 + Math.random() * 0.67));
    const chars = (body.messages ?? []).reduce(
      (sum, m) => sum + (typeof m.content === "string" ? m.content.length : 0),
      0,
    );
    return Response.json({
      model: body.model ?? "notebook-load",
      choices: [{ message: { content: NOTEBOOK_REPLY } }],
      usage: {
        prompt_tokens: Math.ceil(chars / 4),
        completion_tokens: Math.ceil(NOTEBOOK_REPLY.length / 4),
      },
    });
  },
});

// --- The API and worker, as their own processes ------------------------------------
const password = `nbload-${crypto.randomUUID()}`;
const roleUrl = (role: string) => {
  const url = new URL(adminUrl);
  url.username = role;
  url.password = password;
  return url.toString();
};
const quiet = { LOG_LEVEL: "error", PATH: process.env["PATH"] ?? "" };
const shared = {
  ...quiet,
  ENVIRONMENT: "development",
  REDIS_URL: redisUrl,
  AI_API_KEY: "notebook-load",
  AI_BASE_URL: `https://127.0.0.1:${aiPort}`,
  AI_LESSON_TOOLS_ENABLED: "true",
  NODE_EXTRA_CA_CERTS: resolve(certPath),
};
const random = () => crypto.randomUUID().replaceAll("-", "");
// The repository's .env is never read: each process runs from a directory
// without one, with exactly this environment.
const outside = dirname(resolve(certPath));

function cpuSeconds(pid: number): number {
  for (let attempt = 0; attempt < 5; attempt++) {
    const out = Bun.spawnSync(["ps", "-o", "cputime=", "-p", String(pid)])
      .stdout.toString().trim();
    // [[dd-]hh:]mm:ss.cc
    if (/^[\d:.-]+$/.test(out)) {
      return out.split(/[-:]/).map(Number)
        .reduce((total, part) => total * 60 + part, 0);
    }
  }
  throw new Error(`no CPU time for process ${pid}`);
}

interface RoleStats {
  calls: number;
  ms: number;
  /** Shared buffers read or hit: the database's work, which, unlike its
   * time, does not depend on what else the machine is doing. */
  blocks: number;
}
async function statementsByRole(): Promise<Record<string, RoleStats>> {
  const rows = await sql<
    { role: string; calls: string; ms: number; blocks: string }[]
  >`
    select r.rolname as role, sum(s.calls)::text as calls,
      sum(s.total_exec_time)::float8 as ms,
      sum(s.shared_blks_hit + s.shared_blks_read)::text as blocks
    from extensions.pg_stat_statements s
    join pg_roles r on r.oid = s.userid
    where r.rolname in ('studafy_api_runtime', 'studafy_worker_runtime')
    group by r.rolname`;
  return Object.fromEntries(
    rows.map((
      r,
    ) => [r.role, {
      calls: Number(r.calls),
      ms: r.ms,
      blocks: Number(r.blocks),
    }]),
  );
}

/** Where each role's database time went, largest first. */
async function topStatements(): Promise<Record<string, unknown>[]> {
  return await sql`
    select r.rolname as role, s.calls::int as calls,
      round(s.total_exec_time::numeric, 1)::float8 as ms,
      left(regexp_replace(s.query, '\\s+', ' ', 'g'), 90) as statement
    from extensions.pg_stat_statements s
    join pg_roles r on r.oid = s.userid
    where r.rolname in ('studafy_api_runtime', 'studafy_worker_runtime')
    order by s.total_exec_time desc
    limit 12`;
}

function pct(values: number[], p: number): number {
  if (values.length === 0) return 0;
  const sorted = [...values].sort((a, b) => a - b);
  return sorted[Math.min(sorted.length - 1, Math.floor(p * sorted.length))]!;
}

async function create(n: number, ip: string): Promise<number | null> {
  const started = performance.now();
  const response = await fetch(
    `http://127.0.0.1:${apiPort}/v1/classrooms/${CLASS}/study-notebooks`,
    {
      method: "POST",
      headers: {
        authorization: `Bearer ${await token(student(n))}`,
        "content-type": "application/json",
        "idempotency-key": crypto.randomUUID(),
        "x-forwarded-for": ip,
      },
      body: JSON.stringify({ resourceId: LESSON, sourceIds: [] }),
    },
  );
  const took = performance.now() - started;
  if (response.status !== 201) {
    const problem = await response.json().catch(() => ({})) as {
      code?: string;
    };
    const key = `${response.status} ${problem.code ?? ""}`.trim();
    errors.set(key, (errors.get(key) ?? 0) + 1);
    return null;
  }
  await response.body?.cancel();
  return took;
}
const errors = new Map<string, number>();

async function waitForNotebooks(expected: number): Promise<void> {
  for (let i = 0; i < 1200; i++) {
    const [row] = await sql<{ waiting: number; done: number }[]>`
      select count(*) filter (where status = 'creating')::int as waiting,
        count(*) filter (where status <> 'creating')::int as done
      from public.study_notebooks where school_id = ${SCHOOL}::uuid`;
    if (row!.waiting === 0 && row!.done >= expected) return;
    await Bun.sleep(250);
  }
  throw new Error("notebooks were still being written after 5 minutes");
}

const children: Bun.Subprocess[] = [];
try {
  await cleanup();
  await seed();
  for (const role of ["studafy_api_runtime", "studafy_worker_runtime"]) {
    await sql.unsafe(`alter role ${role} login password '${password}'`);
  }

  const api = Bun.spawn(["bun", resolve(apiRoot, "apps/api/src/index.ts")], {
    cwd: outside,
    env: {
      ...shared,
      API_PORT: String(apiPort),
      DATABASE_URL: roleUrl("studafy_api_runtime"),
      SUPABASE_URL: `http://127.0.0.1:${jwksPort}`,
      CLIENT_IP_SOURCE: "forwarded",
      API_CURSOR_SIGNING_KEY: random(),
      CLASS_JOIN_CODE_KEY: random(),
      RATE_LIMIT_HMAC_SIGNING_KEY: random(),
    },
    stdout: "inherit",
    stderr: "inherit",
  });
  children.push(api);
  if (withWorker) {
    children.push(
      Bun.spawn(["bun", resolve(repo, "apps/worker/src/index.ts")], {
        cwd: outside,
        env: {
          ...shared,
          DATABASE_URL: roleUrl("studafy_worker_runtime"),
          DB_HOUSEKEEPING_ENABLED: "false",
        },
        stdout: "inherit",
        stderr: "inherit",
      }),
    );
  }
  for (let i = 0;; i++) {
    const ready = await fetch(`http://127.0.0.1:${apiPort}/readyz`)
      .then((r) => r.ok).catch(() => false);
    if (ready) break;
    if (i === 120) throw new Error("the API never became ready");
    await Bun.sleep(500);
  }

  // Warm up: one notebook end to end, so first-use costs are not counted.
  await create(0, "10.9.0.1");
  await waitForNotebooks(1);
  await Bun.sleep(1_000);

  await sql`select extensions.pg_stat_statements_reset()`;
  const apiCpu = cpuSeconds(api.pid);
  const workerCpu = withWorker ? cpuSeconds(children[1]!.pid) : 0;
  const aiBefore = ai.calls;
  const started = performance.now();

  const jobs = Array.from(
    { length: students * perStudent },
    (_, i) => 1 + (i % students),
  );
  const latencies: number[] = [];
  let next = 0;
  await Promise.all(
    Array.from({ length: concurrency }, async () => {
      while (next < jobs.length) {
        const n = jobs[next++]!;
        const took = await create(n, `10.9.${n >> 8}.${n & 255}`);
        if (took !== null) latencies.push(took);
      }
    }),
  );
  const requestsDone = performance.now();
  await waitForNotebooks(latencies.length + 1);
  const allDone = performance.now();
  // Let in-flight bookkeeping land before counting.
  await Bun.sleep(1_000);

  const roles = await statementsByRole();
  const top = flag("top") ? await topStatements() : undefined;
  const apiCpuMs = (cpuSeconds(api.pid) - apiCpu) * 1000;
  const workerCpuMs = withWorker
    ? (cpuSeconds(children[1]!.pid) - workerCpu) * 1000
    : 0;
  const [states] = await sql<{ ready: number; failed: number }[]>`
    select count(*) filter (where status = 'ready')::int as ready,
      count(*) filter (where status = 'failed')::int as failed
    from public.study_notebooks where school_id = ${SCHOOL}::uuid`;
  const [ages] = await sql<{ p50: number; p95: number }[]>`
    select percentile_cont(0.5) within group (order by extract(epoch from
        generated_at - created_at))::float8 * 1000 as p50,
      percentile_cont(0.95) within group (order by extract(epoch from
        generated_at - created_at))::float8 * 1000 as p95
    from public.study_notebooks
    where school_id = ${SCHOOL}::uuid and status = 'ready'
      and created_at > now() - interval '1 hour'`;
  const per = (value: number) =>
    Number((value / Math.max(1, latencies.length)).toFixed(2));
  const none = { calls: 0, ms: 0, blocks: 0 };
  const apiDb = roles["studafy_api_runtime"] ?? none;
  const workerDb = roles["studafy_worker_runtime"] ?? none;
  console.log(JSON.stringify(
    {
      mode: withWorker ? "api + worker" : "api only",
      notebooks: latencies.length,
      requested: jobs.length,
      concurrency,
      aiMs,
      ready: states!.ready - 1,
      failed: states!.failed,
      aiCalls: ai.calls - aiBefore,
      errors: Object.fromEntries(errors),
      seconds: {
        requests: Number(((requestsDone - started) / 1000).toFixed(1)),
        allWritten: Number(((allDone - started) / 1000).toFixed(1)),
      },
      request: {
        p50: Math.round(pct(latencies, 0.5)),
        p95: Math.round(pct(latencies, 0.95)),
      },
      readyAfter: { p50: Math.round(ages!.p50), p95: Math.round(ages!.p95) },
      perNotebook: {
        api: {
          cpuMs: per(apiCpuMs),
          dbMs: per(apiDb.ms),
          dbStatements: per(apiDb.calls),
          dbBlocks: per(apiDb.blocks),
        },
        worker: {
          cpuMs: per(workerCpuMs),
          dbMs: per(workerDb.ms),
          dbStatements: per(workerDb.calls),
          dbBlocks: per(workerDb.blocks),
        },
      },
      ...(top ? { top } : {}),
    },
    null,
    2,
  ));
} finally {
  for (const child of children) child.kill();
  await Promise.all(children.map((c) => c.exited));
  for (const role of ["studafy_api_runtime", "studafy_worker_runtime"]) {
    await sql.unsafe(`alter role ${role} password null`).catch(() => {});
  }
  await sql.unsafe(`alter role studafy_worker_runtime nologin`).catch(
    () => {},
  );
  await cleanup().catch((error) => console.error("cleanup failed", error));
  await sql.end({ timeout: 5 });
  jwksServer.stop(true);
  aiServer.stop(true);
}
