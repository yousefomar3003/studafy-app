/**
 * HTTP capacity test (launch plan 4.8, docs/capacity/2026-10-12.md).
 *
 * bench.ts measures the database alone. This drives a real API process,
 * with Redis, its rate limits, token checks and JSON, as people would:
 * each virtual user is one synthetic person from the scale seed (students
 * 70%, parents 20%, teachers 10%) opening screens with a pause between
 * them, including exams, study notebooks and AI questions.
 *
 * It serves two stand-ins itself, so nothing real is called or charged:
 *   - a signing-key server (JWKS) for tokens it signs for any seeded user;
 *     start the API with SUPABASE_URL pointing at it;
 *   - an OpenAI-compatible AI provider over HTTPS that waits as long as the
 *     real one does (--ai-ms) and reports token use; start the API with
 *     AI_BASE_URL pointing at it and NODE_EXTRA_CA_CERTS=<its certificate>.
 *
 *   bun scripts/scale/http-load.ts --cert c.pem --key k.pem \
 *     --users 50,100,200 --seconds 60 --think 4000
 *
 * Then start the API (the output prints the environment it needs) and the
 * load begins when /readyz answers. Local, synthetic data only.
 */

const args = Bun.argv.slice(2);
const opt = (name: string, fallback: string) => {
  const i = args.indexOf(`--${name}`);
  return i >= 0 ? args[i + 1]! : fallback;
};
const apiUrl = opt("api", "http://127.0.0.1:8899");
const jwksPort = Number(opt("jwks-port", "54990"));
const aiPort = Number(opt("ai-port", "54991"));
const userLevels = opt("users", "50,100,200").split(",").map(Number);
const seconds = Number(opt("seconds", "60"));
const think = Number(opt("think", "4000"));
const aiMs = Number(opt("ai-ms", "2500"));
const certPath = opt("cert", "");
const keyPath = opt("key", "");
const size = {
  schools: Number(opt("schools", "100")),
  students: Number(opt("students", "500")),
  teachers: Number(opt("teachers", "40")),
  classes: Number(opt("classes", "60")),
  enrol: Number(opt("enrol", "3")),
  exams: Number(opt("exams", "2")),
};
if (!["127.0.0.1", "localhost"].includes(new URL(apiUrl).hostname)) {
  throw new Error("--api must be a local API.");
}
if (!certPath || !keyPath) throw new Error("--cert and --key are required.");

function sid(kind: string, a: number, b = 0): string {
  const h = new Bun.CryptoHasher("md5").update(`${kind}:${a}:${b}`).digest(
    "hex",
  );
  // Version 4 shape, as seed-scale.sql makes them.
  return `${h.slice(0, 8)}-${h.slice(8, 12)}-4${h.slice(13, 16)}-8${
    h.slice(17, 20)
  }-${h.slice(20)}`;
}
const pick = (n: number) => 1 + Math.floor(Math.random() * n);

// --- Tokens: a P-256 key whose public half the JWKS server publishes. ------
// Kept in a file (--signing-key) so a running API, which caches the key it
// fetched, keeps accepting tokens across runs.
const kid = "capacity-test";
const keyFile = opt("signing-key", `${certPath}.signing.jwk`);
const ecdsa = { name: "ECDSA", namedCurve: "P-256" };
let privateJwk: JsonWebKey;
if (await Bun.file(keyFile).exists()) {
  privateJwk = await Bun.file(keyFile).json();
} else {
  const fresh = await crypto.subtle.generateKey(ecdsa, true, [
    "sign",
    "verify",
  ]) as CryptoKeyPair;
  privateJwk = await crypto.subtle.exportKey("jwk", fresh.privateKey);
  await Bun.write(keyFile, JSON.stringify(privateJwk));
}
const pair = {
  privateKey: await crypto.subtle.importKey("jwk", privateJwk, ecdsa, false, [
    "sign",
  ]),
};
const { d: _secret, key_ops: _ops, ext: _ext, ...publicJwk } = privateJwk;
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
    exp: now + 4 * 3600,
  }));
  const signature = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" },
    pair.privateKey,
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

// --- The AI provider stand-in. --------------------------------------------
const ai = { calls: 0, inFlight: 0, maxInFlight: 0, input: 0, output: 0 };
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
    ai.inFlight++;
    ai.maxInFlight = Math.max(ai.maxInFlight, ai.inFlight);
    // The real provider's time, give or take a third.
    await Bun.sleep(aiMs * (0.67 + Math.random() * 0.67));
    ai.inFlight--;
    const promptChars = (body.messages ?? []).reduce(
      (sum, m) => sum + (m.content?.length ?? 0),
      0,
    );
    const prompt = Math.ceil(promptChars / 4);
    const completion = 280 + Math.floor(Math.random() * 120);
    ai.input += prompt;
    ai.output += completion;
    return Response.json({
      model: body.model ?? "capacity-mock",
      choices: [{
        message: {
          content:
            "Photosynthesis is how plants use light, water and carbon dioxide to make glucose and oxygen. The chlorophyll in their leaves absorbs the light.",
        },
      }],
      usage: { prompt_tokens: prompt, completion_tokens: completion },
    });
  },
});

console.log(JSON.stringify({
  event: "stand_ins_ready",
  start_the_api_with: {
    SUPABASE_URL: `http://127.0.0.1:${jwksPort}`,
    AI_BASE_URL: `https://127.0.0.1:${aiPort}/v1`,
    AI_API_KEY: "capacity-mock",
    AI_LESSON_TOOLS_ENABLED: "true",
    NODE_EXTRA_CA_CERTS: certPath,
  },
}));

// --- People and their visits. ----------------------------------------------
type Step = {
  name: string;
  method: "GET" | "POST";
  path: string;
  body?: Record<string, unknown>;
  /** What to do next with this response, if anything. */
  next?: (response: Record<string, unknown>) => Step | null;
};

interface Person {
  role: "student" | "parent" | "teacher";
  s: number;
  n: number;
  token: string;
  ip: string;
}

async function person(index: number): Promise<Person> {
  const s = pick(size.schools);
  const roll = Math.random();
  const role = roll < 0.7 ? "student" : roll < 0.9 ? "parent" : "teacher";
  const n = role === "teacher" ? pick(size.teachers) : pick(size.students);
  const kind = role === "student" ? "su" : role === "parent" ? "gu" : "tu";
  return {
    role,
    s,
    n,
    token: await token(sid(kind, s, n)),
    // One address per person, as phones on different networks have.
    ip: `10.${(index >> 16) & 255}.${(index >> 8) & 255}.${index & 255}`,
  };
}

const page = "pageSize=20";

function visit(p: Person): Step[] {
  const { s, n } = p;
  // School-wide lists name the school, as the app does.
  const school = sid("school", s);
  if (p.role === "parent") {
    const child = sid("st", s, n);
    return [
      { name: "parent.children", method: "GET", path: "/v1/me/guardian-links" },
      {
        name: "parent.assignments",
        method: "GET",
        path: `/v1/assignments?studentId=${child}&${page}`,
      },
      {
        name: "parent.grades",
        method: "GET",
        path: `/v1/grade-results?studentId=${child}&${page}`,
      },
      {
        name: "parent.unread",
        method: "GET",
        path: "/v1/notifications/unread-count",
      },
    ];
  }
  if (p.role === "teacher") {
    const c = (n - 1) % size.classes;
    const cls = sid("cl", s, c);
    const steps: Step[] = [
      {
        name: "teacher.classes",
        method: "GET",
        path: `/v1/classrooms?schoolId=${school}&${page}`,
      },
      {
        name: "teacher.roster",
        method: "GET",
        path: `/v1/classrooms/${cls}/students?${page}`,
      },
      {
        name: "teacher.attendance",
        method: "GET",
        path: `/v1/classrooms/${cls}/attendance-roster?${page}`,
      },
      {
        name: "teacher.submissions",
        method: "GET",
        path: `/v1/assignments/${
          sid("as", s, c * 1000 + 1)
        }/submissions?${page}`,
      },
      {
        name: "teacher.exam.attempts",
        method: "GET",
        path: `/v1/assessments/${
          sid("ex", s, c * 1000 + pick(size.exams))
        }/attempts?${page}`,
      },
    ];
    if (Math.random() < 0.3) {
      steps.push({
        name: "teacher.message",
        method: "POST",
        path: `/v1/conversations/${sid("cv", s, c)}/messages`,
        body: {
          clientMessageId: crypto.randomUUID(),
          body: "Reminder: homework is due Thursday.",
        },
      });
    }
    return steps;
  }
  const c = (n * size.enrol) % size.classes;
  const cls = sid("cl", s, c);
  const steps: Step[] = [
    {
      name: "student.classes",
      method: "GET",
      path: `/v1/classrooms?schoolId=${school}&${page}`,
    },
    {
      name: "student.assignments",
      method: "GET",
      path: `/v1/assignments?schoolId=${school}&${page}`,
    },
    {
      name: "student.lessons",
      method: "GET",
      path: `/v1/resources?classroomId=${cls}&${page}`,
    },
    {
      name: "student.grades",
      method: "GET",
      path: `/v1/grade-results?schoolId=${school}&${page}`,
    },
    {
      name: "student.unread",
      method: "GET",
      path: "/v1/notifications/unread-count",
    },
  ];
  const roll = Math.random();
  if (roll < 0.4) {
    const e = pick(size.exams);
    const exam = sid("ex", s, c * 1000 + e);
    steps.push(
      {
        name: "student.exams",
        method: "GET",
        path: `/v1/assessments?schoolId=${school}&${page}`,
      },
      {
        name: "student.exam.questions",
        method: "GET",
        path: `/v1/assessments/${exam}/questions?${page}`,
      },
    );
    if (Math.random() < 0.3) {
      steps.push({
        name: "student.exam.submit",
        method: "POST",
        path: `/v1/assessments/${exam}/submit`,
        body: {
          answers: [1, 2, 3, 4, 5].map((q) => {
            const questionId = sid("eq", s, (c * 1000 + e) * 10 + q);
            return q <= 3
              ? { questionId, selectedOptionIds: ["a"] }
              : { questionId, answerText: "Chlorophyll absorbs light." };
          }),
        },
      });
    }
  } else if (roll < 0.8) {
    const notebook = sid("nb", s, n);
    steps.push(
      {
        name: "student.notebooks",
        method: "GET",
        path: `/v1/classrooms/${cls}/study-notebooks`,
      },
      {
        name: "student.notebook.open",
        method: "GET",
        path: `/v1/study-notebooks/${notebook}`,
        next: (opened) => {
          const version = opened.personalVersion as number | undefined;
          if (!version || Math.random() >= 0.5) return null;
          return {
            name: "student.notebook.save",
            method: "POST",
            path: `/v1/study-notebooks/${notebook}/personal`,
            body: {
              expectedVersion: version,
              personal: {
                notes: [{
                  id: crypto.randomUUID().slice(0, 8),
                  sectionKey: "cells",
                  text: "Revise for Friday.",
                }],
                sections: [],
                bookmarks: [],
                highlights: [],
              },
            },
          };
        },
      },
    );
  } else {
    steps.push({
      name: "student.ai.plan",
      method: "GET",
      path: "/v1/me/study-plan",
    });
    if (Math.random() < 0.6) {
      steps.push({
        name: "student.ai.ask",
        method: "POST",
        path: "/v1/study-assistant/ask",
        body: {
          question: "How does photosynthesis work?",
          language: "en",
          requestId: crypto.randomUUID(),
        },
      });
    }
  }
  return steps;
}

// --- Running it. -------------------------------------------------------------
function pct(values: number[], p: number): number {
  if (values.length === 0) return 0;
  const sorted = [...values].sort((a, b) => a - b);
  return sorted[Math.min(sorted.length - 1, Math.floor(p * sorted.length))]!;
}

async function send(p: Person, step: Step) {
  const headers: Record<string, string> = {
    authorization: `Bearer ${p.token}`,
    "x-forwarded-for": p.ip,
    accept: "application/json",
  };
  if (step.method === "POST") {
    headers["content-type"] = "application/json";
    headers["idempotency-key"] = crypto.randomUUID();
  }
  const response = await fetch(`${apiUrl}${step.path}`, {
    method: step.method,
    headers,
    body: step.body ? JSON.stringify(step.body) : undefined,
    signal: AbortSignal.timeout(30_000),
  });
  const text = await response.text();
  let json: Record<string, unknown> = {};
  try {
    json = JSON.parse(text);
  } catch { /* not JSON */ }
  return { status: response.status, json };
}

async function run(users: number) {
  const latencies = new Map<string, number[]>();
  const errors = new Map<string, number>();
  const aiBefore = { ...ai };
  let done = 0;
  const people = await Promise.all(
    Array.from({ length: users }, (_, i) => person(i + 1)),
  );
  const end = performance.now() + seconds * 1000;
  await Promise.all(people.map(async (p) => {
    // Arrive spread over the first think interval, not all at once.
    await Bun.sleep(Math.random() * think);
    while (performance.now() < end) {
      for (const first of visit(p)) {
        let step: Step | null = first;
        while (step && performance.now() < end) {
          const started = performance.now();
          try {
            const { status, json } = await send(p, step);
            const took = performance.now() - started;
            if (status >= 200 && status < 300) {
              const list = latencies.get(step.name) ?? [];
              list.push(took);
              latencies.set(step.name, list);
              done++;
              step = step.next?.(json) ?? null;
            } else {
              const code = String(json.code ?? json.title ?? "");
              const key = `${step.name} ${status} ${code}`.trim();
              errors.set(key, (errors.get(key) ?? 0) + 1);
              step = null;
            }
          } catch (error) {
            const key = `${step.name} ${
              error instanceof Error ? error.name : "error"
            }`;
            errors.set(key, (errors.get(key) ?? 0) + 1);
            step = null;
          }
          // A person reads the screen before the next one.
          await Bun.sleep(-Math.log(1 - Math.random()) * think);
        }
      }
    }
  }));
  const all = [...latencies.entries()]
    .filter(([name]) => name !== "student.ai.ask")
    .flatMap(([, v]) => v);
  const errorCount = [...errors.values()].reduce((a, b) => a + b, 0);
  return {
    users,
    requestsPerSecond: Math.round(done / seconds),
    // Everything but AI questions, whose time is mostly the provider's.
    p50: Math.round(pct(all, 0.5)),
    p95: Math.round(pct(all, 0.95)),
    p99: Math.round(pct(all, 0.99)),
    errorRate: Number((errorCount / Math.max(1, done + errorCount)).toFixed(4)),
    errors: Object.fromEntries(errors),
    ai: {
      calls: ai.calls - aiBefore.calls,
      maxInFlight: ai.maxInFlight,
      inputTokens: ai.input - aiBefore.input,
      outputTokens: ai.output - aiBefore.output,
    },
    screens: Object.fromEntries(
      [...latencies.entries()].sort(([a], [b]) => a.localeCompare(b)).map((
        [name, v],
      ) => [name, {
        n: v.length,
        p50: Math.round(pct(v, 0.5)),
        p95: Math.round(pct(v, 0.95)),
      }]),
    ),
  };
}

try {
  for (let i = 0; i < 300; i++) {
    const ready = await fetch(`${apiUrl}/readyz`).then((r) => r.ok).catch(() =>
      false
    );
    if (ready) break;
    if (i === 299) throw new Error(`the API at ${apiUrl} never became ready`);
    await Bun.sleep(1000);
  }
  for (const users of userLevels) {
    ai.maxInFlight = 0;
    console.log(JSON.stringify(await run(users)));
  }
} finally {
  jwksServer.stop(true);
  aiServer.stop(true);
}
