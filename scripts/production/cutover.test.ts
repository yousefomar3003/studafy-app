import { afterAll, describe, expect, test } from "bun:test";
import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import {
  apiEnvSchema,
  workerEnvSchema,
} from "../../packages/config/src/index.ts";
import {
  APPS,
  type CommandResult,
  DEPLOY_ORDER,
  type FlyEnvs,
  type Io,
  OPTIONAL_SECRETS,
  parseArgs,
  planSecrets,
  readFlyEnvs,
  REQUIRED_SECRETS,
  runCutover,
  type Runner,
  STEP_IDS,
} from "./cutover.ts";
import { parseSecrets, serializeForFly } from "./secretsFile.ts";

const CA = [
  "-----BEGIN CERTIFICATE-----",
  "c3ludGhldGljLWNhLWZvci1jdXRvdmVyLXRlc3Rz",
  "-----END CERTIFICATE-----",
].join("\n");

/** Synthetic values; each is unique so a leak is easy to find. */
const VALUES: Record<string, string> = {
  API__DATABASE_URL:
    "postgresql://studafy_api_runtime.synthref:apiPw-7f3c9a1e@aws-0-eu-central-1.pooler.supabase.com:5432/postgres",
  WORKER__DATABASE_URL:
    "postgresql://studafy_worker_runtime.synthref:workerPw-2b8d4e6f@aws-0-eu-central-1.pooler.supabase.com:5432/postgres",
  DATABASE_CA_CERT: CA,
  REDIS_URL: "rediss://default:redisPw-91ac33@redis.synthetic.example:6380",
  SUPABASE_URL: "https://synthref.supabase.co",
  SUPABASE_SERVICE_ROLE_KEY: "service-role-synthetic-000000000000",
  API_CURSOR_SIGNING_KEY: "cursor-synthetic-000000000000000000000000000",
  RATE_LIMIT_HMAC_SIGNING_KEY: "ratelimit-synthetic-000000000000000000000000",
  CLASS_JOIN_CODE_KEY: "joincode-synthetic-0000000000000000000000000",
  FILE051_DELIVERY_SIGNING_KEY: "delivery-synthetic-0000000000000000000000000",
  TURNSTILE_SITE_KEY: "0x4AAAAAAAsyntheticSite",
  TURNSTILE_SECRET: "0x4AAAAAAAsyntheticTurnstileSecret",
  SENTRY_DSN: "https://publicsynthetic@o0.ingest.de.sentry.io/42",
  SCANNER_API_KEY: "scanner-synthetic-00000000000000000000000000000000",
  TELEGRAM_BOT_TOKEN: "000000000:synthetic-telegram-token-xyz",
  TELEGRAM_CHAT_ID: "-1000000000042",
  AI_API_KEY: "ai-synthetic-key-000000",
};

function fileText(values: Record<string, string>): string {
  return Object.entries(values).map(([name, value]) =>
    value.includes("\n") ? `${name}="""\n${value}\n"""` : `${name}=${value}`
  ).join("\n") + "\n";
}

const dir = mkdtempSync(join(tmpdir(), "studafy-cutover-test-"));
afterAll(() => rmSync(dir, { recursive: true, force: true }));
let fileCount = 0;
function secretsFile(values: Record<string, string>): string {
  const path = join(dir, `secrets-${fileCount++}.env`);
  writeFileSync(path, fileText(values), { mode: 0o600 });
  return path;
}

function without(...names: string[]): Record<string, string> {
  return Object.fromEntries(
    Object.entries(VALUES).filter(([name]) => !names.includes(name)),
  );
}

class FakeRunner implements Runner {
  calls: { argv: string[]; stdin?: string }[] = [];
  secretNames = new Map<string, string[]>();
  constructor(private existing: string[] = ["studafy-api"]) {}
  run(
    argv: readonly string[],
    options: { stdin?: string } = {},
  ): Promise<CommandResult> {
    this.calls.push({ argv: [...argv], stdin: options.stdin });
    const line = argv.join(" ");
    const ok = (stdout: string) =>
      Promise.resolve({ code: 0, stdout, stderr: "" });
    if (line === "fly apps list --json") {
      return ok(JSON.stringify(this.existing.map((Name) => ({ Name }))));
    }
    if (line.startsWith("fly secrets import")) {
      const app = argv[argv.indexOf("--app") + 1]!;
      this.secretNames.set(app, [
        ...parseSecrets(options.stdin ?? "").keys(),
      ]);
      return ok("");
    }
    if (line.startsWith("fly secrets list")) {
      const app = argv[argv.indexOf("--app") + 1]!;
      return ok(
        JSON.stringify(
          (this.secretNames.get(app) ?? []).map((Name) => ({ Name })),
        ),
      );
    }
    if (line.startsWith("fly ips list")) return ok("[]");
    if (line.startsWith("fly checks list")) {
      return ok(JSON.stringify([{ name: "healthz", status: "passing" }]));
    }
    if (line.startsWith("fly status")) {
      return ok(JSON.stringify({ Machines: [{ id: "m1", state: "stopped" }] }));
    }
    if (line.startsWith("fly logs")) {
      return ok('{"event":"queue_redis_posture"}\n{"event":"worker_ready"}');
    }
    return ok("");
  }
}

function recordingIo(answer = true): Io & { lines: string[] } {
  const lines: string[] = [];
  return {
    lines,
    log: (line) => lines.push(line),
    confirm: () => Promise.resolve(answer),
    sleep: () => Promise.resolve(),
    fetch: () => Promise.resolve({ status: 200 }),
  };
}

function expectNoValue(text: string) {
  for (const [name, value] of Object.entries(VALUES)) {
    for (const piece of value.split("\n")) {
      if (piece.startsWith("-----")) continue; // PEM armour is not secret
      expect({ name, leaked: text.includes(piece) }).toEqual({
        name,
        leaked: false,
      });
    }
  }
  for (
    const password of ["apiPw-7f3c9a1e", "workerPw-2b8d4e6f", "redisPw-91ac33"]
  ) {
    expect(text).not.toContain(password);
  }
}

let flyEnvs: FlyEnvs;
const envs = async () => flyEnvs ??= await readFlyEnvs();

function schemaKeys(schema: unknown): Set<string> {
  const node = schema as { shape?: object; in?: { shape?: object } };
  return new Set(Object.keys(node.shape ?? node.in?.shape ?? {}));
}

describe("per-app secret lists", () => {
  test("pinned: the names each production app is given", () => {
    expect(REQUIRED_SECRETS.scanner).toEqual(["SCANNER_API_KEY"]);
    expect(REQUIRED_SECRETS.worker).toEqual([
      "DATABASE_URL",
      "DATABASE_CA_CERT",
      "REDIS_URL",
      "SUPABASE_URL",
      "SUPABASE_SERVICE_ROLE_KEY",
      "MALWARE_SCANNER_API_KEY",
      "SENTRY_DSN",
      "TELEGRAM_BOT_TOKEN",
      "TELEGRAM_CHAT_ID",
      "AI_API_KEY",
    ]);
    expect(REQUIRED_SECRETS.api).toEqual([
      "DATABASE_URL",
      "DATABASE_CA_CERT",
      "REDIS_URL",
      "SUPABASE_URL",
      "SUPABASE_SERVICE_ROLE_KEY",
      "API_CURSOR_SIGNING_KEY",
      "RATE_LIMIT_HMAC_SIGNING_KEY",
      "CLASS_JOIN_CODE_KEY",
      "FILE051_DELIVERY_SIGNING_KEY",
      "TURNSTILE_SITE_KEY",
      "TURNSTILE_SECRET",
      "SENTRY_DSN",
      "AI_API_KEY",
    ]);
  });

  test("every name is one the app's config schema reads", () => {
    const api = schemaKeys(apiEnvSchema);
    const worker = schemaKeys(workerEnvSchema);
    expect(api.size).toBeGreaterThan(20);
    expect(worker.size).toBeGreaterThan(20);
    for (const name of [...REQUIRED_SECRETS.api, ...OPTIONAL_SECRETS.api]) {
      expect({ name, known: api.has(name) }).toEqual({ name, known: true });
    }
    for (
      const name of [...REQUIRED_SECRETS.worker, ...OPTIONAL_SECRETS.worker]
    ) {
      expect({ name, known: worker.has(name) }).toEqual({ name, known: true });
    }
  });

  test("no secret is also set in the app's Fly config, and the configs' secrets are all covered", async () => {
    const fly = await envs();
    for (const app of DEPLOY_ORDER) {
      for (
        const name of [...REQUIRED_SECRETS[app], ...OPTIONAL_SECRETS[app]]
      ) {
        expect(fly[app][name]).toBeUndefined();
      }
    }
    // The scanner's URL is configuration; only its key is a secret.
    expect(fly.worker["MALWARE_SCANNER_URL"]).toBeDefined();
    // DL-062: AI is on in both, so both need the key.
    expect(fly.api["AI_LESSON_TOOLS_ENABLED"]).toBe("true");
    expect(fly.worker["AI_LESSON_TOOLS_ENABLED"]).toBe("true");
  });

  test("the full set passes the API's and worker's production start-up checks", async () => {
    const plan = planSecrets(parseSecrets(fileText(VALUES)), await envs());
    expect(plan.problems).toEqual([]);
    expect([...plan.perApp.scanner.keys()]).toEqual(["SCANNER_API_KEY"]);
    expect([...plan.perApp.worker.keys()].sort()).toEqual(
      [...REQUIRED_SECRETS.worker].sort(),
    );
    expect([...plan.perApp.api.keys()].sort()).toEqual(
      [...REQUIRED_SECRETS.api].sort(),
    );
    // Each app gets its own runtime role; the worker gets the scanner's key.
    expect(plan.perApp.api.get("DATABASE_URL")).toBe(VALUES.API__DATABASE_URL);
    expect(plan.perApp.worker.get("DATABASE_URL")).toBe(
      VALUES.WORKER__DATABASE_URL,
    );
    expect(plan.perApp.worker.get("MALWARE_SCANNER_API_KEY")).toBe(
      VALUES.SCANNER_API_KEY,
    );
    expect(plan.perApp.api.has("SCANNER_API_KEY")).toBe(false);
    expect(plan.perApp.worker.has("TURNSTILE_SECRET")).toBe(false);
  });

  test("optional names go only to the apps that read them", async () => {
    const plan = planSecrets(
      parseSecrets(fileText({
        ...VALUES,
        RESEND_API_KEY: "re_synthetic_0000000000",
        EMAIL_FROM_ADDRESS: "Studafy <hello@studafy.com>",
        ADMIN_DATABASE_URL:
          "postgresql://postgres.x:y@db.example:5432/postgres",
      })),
      await envs(),
    );
    expect(plan.problems).toEqual([]);
    expect(plan.perApp.worker.has("RESEND_API_KEY")).toBe(true);
    expect(plan.perApp.api.has("RESEND_API_KEY")).toBe(false);
    // DL-070: email and push are switched on in fly.worker.toml, so the
    // Resend pair is used as soon as it is imported.
    expect(plan.warnings.join("\n")).not.toContain(
      "NOTIFICATION_CHANNELS_ENABLED",
    );
    expect(plan.warnings.join("\n")).toContain("ADMIN_DATABASE_URL");
  });

  test("billing: on in the Fly configs, and running once a store's set is complete", async () => {
    const flyEnvs = await envs();
    // DL-070: configuration, not secrets.
    expect(flyEnvs.api["PAY071_BILLING_ENABLED"]).toBe("true");
    expect(flyEnvs.api["PAY071_ENVIRONMENT"]).toBe("production");
    expect(OPTIONAL_SECRETS.api).not.toContain("PAY071_ENVIRONMENT");
    const partial = planSecrets(
      parseSecrets(fileText({
        ...VALUES,
        GOOGLE_PACKAGE_NAME: "com.studafy.light",
      })),
      flyEnvs,
    );
    expect(partial.problems).toEqual([]);
    expect(partial.warnings.join("\n")).toContain("Billing stays off");
    const play = planSecrets(
      parseSecrets(fileText({
        ...VALUES,
        GOOGLE_PACKAGE_NAME: "com.studafy.light",
        GOOGLE_SERVICE_ACCOUNT_JSON: '{"type":"service_account"}',
        GOOGLE_PUBSUB_SERVICE_ACCOUNT_EMAIL:
          "pubsub@synthetic.iam.gserviceaccount.com",
        GOOGLE_PUBSUB_AUDIENCE: "https://api.studafy.com/webhooks/google",
      })),
      flyEnvs,
    );
    expect(play.problems).toEqual([]);
    expect(play.warnings.join("\n")).not.toContain("Billing");
    expect(play.perApp.api.has("GOOGLE_PACKAGE_NAME")).toBe(true);
    expect(play.perApp.worker.has("GOOGLE_PACKAGE_NAME")).toBe(true);
  });
});

describe("refusals", () => {
  test("a missing secret: names listed, nothing run, no value printed", async () => {
    const runner = new FakeRunner();
    const io = recordingIo();
    const code = await runCutover(
      {
        execute: true,
        yes: true,
        org: "personal",
        secretsPath: secretsFile(
          without("TURNSTILE_SECRET", "WORKER__DATABASE_URL", "AI_API_KEY"),
        ),
      },
      { runner, io, flyEnvs: await envs() },
    );
    expect(code).toBe(1);
    expect(runner.calls).toEqual([]);
    const out = io.lines.join("\n");
    expect(out).toContain(
      "studafy-worker is missing: WORKER__DATABASE_URL, AI_API_KEY",
    );
    expect(out).toContain(
      "studafy-api is missing: TURNSTILE_SECRET, AI_API_KEY",
    );
    expect(out).toContain("Nothing was run.");
    expectNoValue(out);
  });

  test("--execute without --secrets refuses before anything runs", async () => {
    const runner = new FakeRunner();
    const io = recordingIo();
    const code = await runCutover(
      { ...parseArgs(["--execute", "--yes"]) },
      { runner, io, flyEnvs: await envs() },
    );
    expect(code).toBe(2);
    expect(runner.calls).toEqual([]);
    expect(io.lines.join("\n")).toContain("--execute needs --secrets");
  });

  test("transaction-pooler URLs (6543) pass, because the Fly configs move them to the session pooler", async () => {
    const pooled = {
      ...VALUES,
      API__DATABASE_URL: VALUES.API__DATABASE_URL!.replace(":5432/", ":6543/"),
      WORKER__DATABASE_URL: VALUES.WORKER__DATABASE_URL!.replace(
        ":5432/",
        ":6543/",
      ),
    };
    const fly = await envs();
    expect(fly.api["DATABASE_POOLER_MODE"]).toBe("session");
    expect(fly.worker["DATABASE_POOLER_MODE"]).toBe("session");
    expect(planSecrets(parseSecrets(fileText(pooled)), fly).problems).toEqual(
      [],
    );

    // Without the mode, production refuses the transaction pooler (the
    // worker stall of 2026-10-20).
    const { DATABASE_POOLER_MODE: _api, ...apiEnv } = fly.api;
    const { DATABASE_POOLER_MODE: _worker, ...workerEnv } = fly.worker;
    const problems = planSecrets(parseSecrets(fileText(pooled)), {
      ...fly,
      api: apiEnv,
      worker: workerEnv,
    }).problems.join("\n");
    expect(problems).toContain(
      "studafy-api would refuse to start: Production DATABASE_URL must not run through the transaction pooler",
    );
    expect(problems).toContain("studafy-worker would refuse to start");
    expectNoValue(problems);
  });

  test("a 6543 URL that is not the Supabase pooler is refused in session mode", async () => {
    const problems = planSecrets(
      parseSecrets(fileText({
        ...VALUES,
        WORKER__DATABASE_URL:
          "postgresql://studafy_worker_runtime.synthref:workerPw-2b8d4e6f@db.synthref.supabase.co:6543/postgres",
      })),
      await envs(),
    ).problems.join("\n");
    expect(problems).toContain(
      "studafy-worker would refuse to start: Environment configuration rejected: DATABASE_POOLER_MODE: session mode",
    );
    expectNoValue(problems);
  });

  test("one shared DATABASE_URL, a wrong role, equal signing keys, a different scanner key", async () => {
    const plan = planSecrets(
      parseSecrets(fileText({
        ...VALUES,
        DATABASE_URL: VALUES.API__DATABASE_URL!,
        WORKER__DATABASE_URL: VALUES.API__DATABASE_URL!,
        CLASS_JOIN_CODE_KEY: VALUES.API_CURSOR_SIGNING_KEY!,
        MALWARE_SCANNER_API_KEY: "another-scanner-key-00000000000000000000",
      })),
      await envs(),
    );
    const problems = plan.problems.join("\n");
    expect(problems).toContain("DATABASE_URL must be written per app");
    expect(problems).toContain(
      "WORKER__DATABASE_URL must log in as studafy_worker_runtime",
    );
    expect(problems).toContain("must all be different");
    expect(problems).toContain("MALWARE_SCANNER_API_KEY differs");
    expectNoValue(problems);
  });

  test("the production start-up checks run on the file (a plaintext Redis)", async () => {
    const plan = planSecrets(
      parseSecrets(fileText({
        ...VALUES,
        REDIS_URL:
          "redis://default:redisPw-91ac33@redis.synthetic.example:6379",
      })),
      await envs(),
    );
    expect(plan.problems.join("\n")).toContain("would refuse to start");
    expect(plan.problems.join("\n")).toContain("rediss://");
    expectNoValue(plan.problems.join("\n"));
  });

  test("a file others can read is refused", async () => {
    const path = join(dir, "open.env");
    writeFileSync(path, fileText(VALUES), { mode: 0o644 });
    const io = recordingIo();
    const code = await runCutover(
      { execute: false, yes: false, org: "personal", secretsPath: path },
      { runner: new FakeRunner(), io, flyEnvs: await envs() },
    );
    expect(code).toBe(2);
    expect(io.lines.join("\n")).toContain("chmod 600");
  });
});

describe("dry run (the default)", () => {
  test("prints every step and command in order, runs nothing, shows no value", async () => {
    expect(parseArgs([]).execute).toBe(false);
    const runner = new FakeRunner();
    const io = recordingIo();
    const code = await runCutover(
      { ...parseArgs([]), secretsPath: secretsFile(VALUES) },
      { runner, io, flyEnvs: await envs() },
    );
    expect(code).toBe(0);
    expect(runner.calls).toEqual([]);
    const out = io.lines.join("\n");
    expect(out).toContain("DRY RUN");
    for (const id of STEP_IDS) expect(out).toContain(`[${id}]`);
    const at = (text: string) => {
      const index = out.indexOf(text);
      expect({ text, found: index >= 0 }).toEqual({ text, found: true });
      return index;
    };
    // Scanner, then the test copy stops, then the worker, then the API.
    const order = [
      "fly deploy --config fly.scanner.toml --app studafy-scanner --remote-only",
      "fly scale count 0 --app studafy-worker-test --yes",
      "fly scale count 0 --app studafy-api-test --yes",
      "fly scale count 0 --app studafy-scanner-test --yes",
      "scripts/production/clean-test-data.ts",
      "fly deploy --config fly.worker.toml --app studafy-worker --remote-only",
      "fly deploy --config fly.api.toml --app studafy-api --remote-only",
      "https://studafy-api.fly.dev/readyz",
      "fly certs add api.studafy.com --app studafy-api",
      "CNAME api -> studafy-api.fly.dev, Proxied",
      'UPTIME_URL = "https://api.studafy.com/readyz"',
    ].map(at);
    expect(order).toEqual([...order].sort((a, b) => a - b));
    expect(out).toContain(
      "fly secrets import --app studafy-scanner --stage < [1 values",
    );
    expect(out).toContain("SCANNER_API_KEY]");
    expect(out).toMatch(
      /fly secrets import --app studafy-api --stage < \[13 values from .*never shown: DATABASE_URL, DATABASE_CA_CERT/,
    );
    expect(out).toContain("Dry run complete");
    expectNoValue(out);
  });

  test("without a secrets file it lists the required names and still runs nothing", async () => {
    const runner = new FakeRunner();
    const io = recordingIo();
    expect(
      await runCutover(parseArgs([]), { runner, io, flyEnvs: await envs() }),
    ).toBe(0);
    expect(runner.calls).toEqual([]);
    expect(io.lines.join("\n")).toContain("--execute will refuse");
  });
});

describe("execute (against a fake fly)", () => {
  test("creates only missing apps, imports each app's own names, deploys in order", async () => {
    const runner = new FakeRunner(["studafy-api", "studafy-worker-test"]);
    const io = recordingIo(true);
    const code = await runCutover(
      {
        execute: true,
        yes: true,
        org: "personal",
        secretsPath: secretsFile(VALUES),
      },
      { runner, io, flyEnvs: await envs() },
    );
    expect(io.lines.join("\n")).not.toContain("failed");
    expect(code).toBe(0);
    const lines = runner.calls.map((call) => call.argv.join(" "));
    expect(lines).toContain("fly apps create studafy-scanner --org personal");
    expect(lines).toContain("fly apps create studafy-worker --org personal");
    expect(lines).not.toContain("fly apps create studafy-api --org personal");
    for (const app of DEPLOY_ORDER) {
      const call = runner.calls.find((c) =>
        c.argv.join(" ") ===
          `fly secrets import --app ${APPS[app].app} --stage`
      );
      // Values go only through stdin, never argv.
      expect(call?.stdin).toBeDefined();
      expect([...parseSecrets(call!.stdin!).keys()].sort()).toEqual(
        [...REQUIRED_SECRETS[app]].sort(),
      );
    }
    for (const call of runner.calls) expectNoValue(call.argv.join(" "));
    const deploys = lines.filter((line) => line.startsWith("fly deploy"))
      .map((line) => line.split(" ")[3]);
    expect(deploys).toEqual([
      "fly.scanner.toml",
      "fly.worker.toml",
      "fly.api.toml",
    ]);
    const stopWorker = lines.indexOf(
      "fly scale count 0 --app studafy-worker-test --yes",
    );
    expect(stopWorker).toBeGreaterThan(
      lines.indexOf(
        "fly deploy --config fly.scanner.toml --app studafy-scanner --remote-only",
      ),
    );
    expect(stopWorker).toBeLessThan(
      lines.indexOf(
        "fly deploy --config fly.worker.toml --app studafy-worker --remote-only",
      ),
    );
    expectNoValue(io.lines.join("\n"));
  });

  test("stopping the test copy asks even with --yes; no stops the run", async () => {
    const runner = new FakeRunner();
    const asked: string[] = [];
    const io = {
      ...recordingIo(),
      confirm: (question: string) => {
        asked.push(question);
        return Promise.resolve(false);
      },
    };
    const code = await runCutover(
      {
        execute: true,
        yes: true,
        org: "personal",
        secretsPath: secretsFile(VALUES),
        from: "stop-test-apps",
      },
      { runner, io, flyEnvs: await envs() },
    );
    expect(code).toBe(3);
    expect(asked).toEqual(["  Run step stop-test-apps?"]);
    expect(runner.calls.some((c) => c.argv.includes("scale"))).toBe(false);
  });

  test("a public scanner address stops the cutover before the test copy stops", async () => {
    const runner = new FakeRunner();
    const original = runner.run.bind(runner);
    runner.run = (argv, options) =>
      argv.join(" ").startsWith("fly ips list")
        ? Promise.resolve({
          code: 0,
          stdout: JSON.stringify([{ Address: "2a09:8280::1" }]),
          stderr: "",
        })
        : original(argv, options);
    const io = recordingIo(true);
    const code = await runCutover(
      {
        execute: true,
        yes: true,
        org: "personal",
        secretsPath: secretsFile(VALUES),
      },
      { runner, io, flyEnvs: await envs() },
    );
    expect(code).toBe(1);
    expect(io.lines.join("\n")).toContain("public IP address");
    expect(runner.calls.some((c) => c.argv.includes("scale"))).toBe(false);
  });
});

describe("the secrets file", () => {
  test("multi-line values round-trip into fly's import format", () => {
    const parsed = parseSecrets(fileText(VALUES));
    expect(parsed.get("DATABASE_CA_CERT")).toBe(CA);
    const again = parseSecrets(serializeForFly(parsed));
    expect([...again.entries()]).toEqual([...parsed.entries()]);
  });

  test("quoted, duplicated, empty and malformed lines are refused without the value", () => {
    expect(() => parseSecrets('AI_API_KEY="quoted-secret-value"')).toThrow(
      /AI_API_KEY is wrapped in quotes/,
    );
    expect(() => parseSecrets("A=1\nA=2")).toThrow(/A is set twice/);
    expect(() => parseSecrets("A=")).toThrow(/A is empty/);
    expect(() => parseSecrets("just-a-secret-value-on-its-own")).toThrow(
      /line 1: expected NAME=value \(the line is not shown\)/,
    );
    expect(() => parseSecrets('CA="""\nabc')).toThrow(/never closes/);
    try {
      parseSecrets("TOKEN=supersecretvalue\nlowercase=supersecretvalue2");
    } catch (error) {
      expect(String(error)).not.toContain("supersecretvalue2");
    }
  });
});
