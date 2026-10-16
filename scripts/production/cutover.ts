/**
 * Launch-day production cutover on Fly.io (docs/deployment/production-cutover.md).
 *
 * A dry run is the default: it prints every step and every command it would
 * run, runs nothing, and never calls `fly`. `--execute` acts, asking before
 * each step unless `--yes` is given. Every step is safe to run again: apps
 * that exist are not created, secrets are re-imported as staged values,
 * deploys are re-deployed, stopped apps stay stopped. `--from <step>` resumes.
 *
 *   bun --no-env-file scripts/production/cutover.ts --secrets ~/studafy-secrets/production.env
 *   bun --no-env-file scripts/production/cutover.ts --secrets ~/studafy-secrets/production.env --execute
 *   bun --no-env-file scripts/production/cutover.ts --secrets <file> --execute --from deploy-worker
 *
 * Steps, in order:
 *   preflight        fly is installed and signed in; which apps exist; every
 *                    required secret is in the file and passes the same
 *                    production checks the API and worker run at start-up
 *   create-apps      studafy-scanner, studafy-worker (and studafy-api) if missing
 *   import-secrets   `fly secrets import --stage`, each app only its own names
 *   deploy-scanner   private, health-checked (ClamAV loads in up to 5 minutes)
 *   stop-test-apps   `fly scale count 0` for studafy-worker-test, -api-test,
 *                    -scanner-test: two workers on one database would both
 *                    drain the same queues
 *   clean-test-data  checkpoint: scripts/production/clean-test-data.ts
 *   deploy-worker    then waits for `worker_ready` in its log
 *   deploy-api       then waits for https://studafy-api.fly.dev/readyz = 200
 *   dns              printed only: api.studafy.com on Cloudflare, Fly cert
 *   alerts           printed only: the uptime check to api.studafy.com
 *
 * The secrets file (format: secretsFile.ts) holds every app's names once.
 * DATABASE_URL differs per app (each app's own runtime role), so it is
 * written API__DATABASE_URL and WORKER__DATABASE_URL. The scanner's
 * SCANNER_API_KEY is also imported into the worker as
 * MALWARE_SCANNER_API_KEY, so the two can never differ. Values are never
 * printed, passed on a command line, or written anywhere but `fly`'s stdin.
 */
import { spawn } from "node:child_process";
import { existsSync } from "node:fs";
import { createInterface } from "node:readline/promises";
import { resolve } from "node:path";
import {
  apiEnvSchema,
  billingStoresConfigured,
  enforceApiFailClosed,
  enforceWorkerFailClosed,
  parseEnv,
  usesPrivilegedDatabaseRole,
  workerEnvSchema,
} from "../../packages/config/src/index.ts";
import {
  readSecretsFile,
  redact,
  type Secrets,
  SecretsFileError,
  serializeForFly,
} from "./secretsFile.ts";

const REPOSITORY_ROOT = resolve(import.meta.dir, "..", "..");

export type AppKey = "scanner" | "worker" | "api";

export const APPS: Record<
  AppKey,
  { app: string; config: string; testApp: string }
> = {
  scanner: {
    app: "studafy-scanner",
    config: "fly.scanner.toml",
    testApp: "studafy-scanner-test",
  },
  worker: {
    app: "studafy-worker",
    config: "fly.worker.toml",
    testApp: "studafy-worker-test",
  },
  api: {
    app: "studafy-api",
    config: "fly.api.toml",
    testApp: "studafy-api-test",
  },
};

/** Deploy order: the worker needs the scanner, the API needs the worker. */
export const DEPLOY_ORDER: AppKey[] = ["scanner", "worker", "api"];
/** The test worker stops first: it drains the same queues. */
export const TEST_APPS_STOP_ORDER = [
  "studafy-worker-test",
  "studafy-api-test",
  "studafy-scanner-test",
] as const;

/**
 * The secrets each production app must have before its deploy. Pinned by
 * cutover.test.ts against the config schema and the Fly configs; the
 * credentials map (docs/security/credentials-map.md) lists the same names.
 */
export const REQUIRED_SECRETS: Record<AppKey, readonly string[]> = {
  scanner: ["SCANNER_API_KEY"],
  worker: [
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
  ],
  api: [
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
  ],
};

/**
 * Store billing (PAY-071). PAY071_BILLING_ENABLED and PAY071_ENVIRONMENT
 * are configuration in fly.api.toml and fly.worker.toml (DL-070), so not
 * secrets; billing runs once the APPLE_* or the GOOGLE_* set is complete.
 */
const BILLING = [
  "APPLE_BUNDLE_ID",
  "APPLE_ENVIRONMENT",
  "APPLE_APP_APPLE_ID",
  "APPLE_ISSUER_ID",
  "APPLE_KEY_ID",
  "APPLE_PRIVATE_KEY",
  "APPLE_ROOT_CERTIFICATES_BASE64",
  "GOOGLE_PACKAGE_NAME",
  "GOOGLE_SERVICE_ACCOUNT_JSON",
  "GOOGLE_PUBSUB_SERVICE_ACCOUNT_EMAIL",
  "GOOGLE_PUBSUB_AUDIENCE",
] as const;

/**
 * Imported when present. Their switches are on in the Fly configs (DL-070),
 * so each feature starts once its names are here: email with the Resend
 * pair, push with the Firebase pair, billing with a complete store set.
 */
export const OPTIONAL_SECRETS: Record<AppKey, readonly string[]> = {
  scanner: [],
  worker: [
    // Email and push (DL-053), with NOTIFICATION_CHANNELS_ENABLED.
    "RESEND_API_KEY",
    "EMAIL_FROM_ADDRESS",
    "FCM_PROJECT_ID",
    "FCM_SERVICE_ACCOUNT_JSON",
    ...BILLING,
  ],
  api: [...BILLING],
};

/** Optional names that only work together. */
const PAIRS: readonly (readonly [string, string])[] = [
  ["RESEND_API_KEY", "EMAIL_FROM_ADDRESS"],
  ["FCM_PROJECT_ID", "FCM_SERVICE_ACCOUNT_JSON"],
];

/** Per-app names written with a prefix in the file (different values). */
const SCOPED_ONLY = new Set(["DATABASE_URL"]);
/** Runtime role each app's DATABASE_URL must log in as (ADR-0041). */
const RUNTIME_ROLE: Partial<Record<AppKey, string>> = {
  api: "studafy_api_runtime",
  worker: "studafy_worker_runtime",
};
const SIGNING_KEYS = [
  "API_CURSOR_SIGNING_KEY",
  "RATE_LIMIT_HMAC_SIGNING_KEY",
  "CLASS_JOIN_CODE_KEY",
  "FILE051_DELIVERY_SIGNING_KEY",
] as const;

const PREFIX: Record<AppKey, string> = {
  api: "API__",
  worker: "WORKER__",
  scanner: "SCANNER__",
};

export interface SecretPlan {
  /** Each app's secrets, by the name the app reads. */
  perApp: Record<AppKey, Map<string, string>>;
  /** Refusals: names only, never values. */
  problems: string[];
  /** Notes that do not stop the cutover. */
  warnings: string[];
}

export type FlyEnvs = Record<AppKey, Record<string, string>>;

export async function readFlyEnvs(
  root: string = REPOSITORY_ROOT,
): Promise<FlyEnvs> {
  const read = async (file: string) =>
    ((Bun.TOML.parse(await Bun.file(resolve(root, file)).text()) as {
      env?: Record<string, string>;
    }).env) ?? {};
  return {
    scanner: await read(APPS.scanner.config),
    worker: await read(APPS.worker.config),
    api: await read(APPS.api.config),
  };
}

function lookup(
  secrets: Secrets,
  app: AppKey,
  name: string,
): string | undefined {
  const scoped = secrets.get(`${PREFIX[app]}${name}`);
  if (scoped !== undefined) return scoped;
  if (SCOPED_ONLY.has(name)) return undefined;
  if (app === "worker" && name === "MALWARE_SCANNER_API_KEY") {
    return secrets.get("SCANNER__SCANNER_API_KEY") ??
      secrets.get("SCANNER_API_KEY");
  }
  return secrets.get(name);
}

function databaseRole(url: string): string | undefined {
  try {
    return decodeURIComponent(new URL(url).username).split(".")[0];
  } catch {
    return undefined;
  }
}

/**
 * Splits the file into each app's secrets and checks them. Every message
 * names a variable, never its value.
 */
export function planSecrets(secrets: Secrets, flyEnvs: FlyEnvs): SecretPlan {
  const problems: string[] = [];
  const warnings: string[] = [];
  const perApp = {
    scanner: new Map<string, string>(),
    worker: new Map<string, string>(),
    api: new Map<string, string>(),
  } satisfies Record<AppKey, Map<string, string>>;

  for (const app of DEPLOY_ORDER) {
    const missing: string[] = [];
    for (const name of REQUIRED_SECRETS[app]) {
      const value = lookup(secrets, app, name);
      if (value === undefined) {
        missing.push(
          SCOPED_ONLY.has(name) ? `${PREFIX[app]}${name}` : name ===
              "MALWARE_SCANNER_API_KEY"
            ? "SCANNER_API_KEY"
            : name,
        );
      } else perApp[app].set(name, value);
    }
    if (missing.length > 0) {
      problems.push(
        `${APPS[app].app} is missing: ${[...new Set(missing)].join(", ")}`,
      );
    }
    for (const name of OPTIONAL_SECRETS[app]) {
      const value = lookup(secrets, app, name);
      if (value !== undefined) perApp[app].set(name, value);
    }
    for (const name of perApp[app].keys()) {
      if (name in flyEnvs[app]) {
        problems.push(
          `${name} is set in ${
            APPS[app].config
          } [env]; it must not also be a secret`,
        );
      }
    }
  }

  if (secrets.has("DATABASE_URL")) {
    problems.push(
      "DATABASE_URL must be written per app: API__DATABASE_URL (studafy_api_runtime) and WORKER__DATABASE_URL (studafy_worker_runtime)",
    );
  }
  const scannerKey = perApp.scanner.get("SCANNER_API_KEY");
  const workerKey = secrets.get("MALWARE_SCANNER_API_KEY") ??
    secrets.get("WORKER__MALWARE_SCANNER_API_KEY");
  if (scannerKey && workerKey && scannerKey !== workerKey) {
    problems.push(
      "MALWARE_SCANNER_API_KEY differs from SCANNER_API_KEY; remove it (the worker gets SCANNER_API_KEY)",
    );
  }
  if (scannerKey !== undefined && scannerKey.length < 32) {
    problems.push("SCANNER_API_KEY must be at least 32 characters");
  }

  for (const app of ["api", "worker"] as const) {
    const url = perApp[app].get("DATABASE_URL");
    if (url === undefined) continue;
    const role = databaseRole(url);
    if (role !== RUNTIME_ROLE[app] || usesPrivilegedDatabaseRole(url)) {
      problems.push(
        `${PREFIX[app]}DATABASE_URL must log in as ${
          RUNTIME_ROLE[app]
        }.<project ref>, not ${role ? `"${role}"` : "an unreadable user"}`,
      );
    }
  }

  const keys = SIGNING_KEYS.map((name) => perApp.api.get(name)).filter((
    value,
  ): value is string => value !== undefined);
  if (new Set(keys).size !== keys.length) {
    problems.push(
      `${SIGNING_KEYS.join(", ")} must all be different (one key per purpose)`,
    );
  }

  for (const app of ["api", "worker"] as const) {
    for (const [a, b] of PAIRS) {
      if (perApp[app].has(a) !== perApp[app].has(b)) {
        problems.push(`${a} and ${b} go together; one is missing`);
      }
    }
  }
  if (
    (perApp.worker.has("RESEND_API_KEY") ||
      perApp.worker.has("FCM_PROJECT_ID")) &&
    flyEnvs.worker["NOTIFICATION_CHANNELS_ENABLED"] !== "true"
  ) {
    warnings.push(
      'Email/push secrets will be stored but stay unused: NOTIFICATION_CHANNELS_ENABLED is not "true" in fly.worker.toml (it is on since DL-070)',
    );
  }
  if (
    BILLING.some((name) => perApp.api.has(name)) &&
    flyEnvs.api["PAY071_BILLING_ENABLED"] !== "true"
  ) {
    warnings.push(
      'Billing secrets will be stored but stay unused: PAY071_BILLING_ENABLED is not "true" in fly.api.toml (it is on since DL-070)',
    );
  }
  if (BILLING.some((name) => perApp.api.has(name))) {
    const named = Object.fromEntries(perApp.api);
    const stores = billingStoresConfigured({
      ...named,
      PAY071_BILLING_ENABLED: true,
    });
    if (!stores.apple && !stores.google) {
      warnings.push(
        "Billing stays off: neither store's set is complete (App Store: APPLE_BUNDLE_ID, APPLE_ENVIRONMENT, APPLE_ISSUER_ID, APPLE_KEY_ID, APPLE_PRIVATE_KEY, APPLE_ROOT_CERTIFICATES_BASE64; Play: GOOGLE_PACKAGE_NAME, GOOGLE_SERVICE_ACCOUNT_JSON, GOOGLE_PUBSUB_SERVICE_ACCOUNT_EMAIL, GOOGLE_PUBSUB_AUDIENCE)",
      );
    }
  }

  const known = new Set<string>();
  for (const app of DEPLOY_ORDER) {
    for (
      const name of [...REQUIRED_SECRETS[app], ...OPTIONAL_SECRETS[app]]
    ) {
      known.add(name);
      known.add(`${PREFIX[app]}${name}`);
    }
  }
  known.add("SCANNER_API_KEY");
  const ignored = [...secrets.keys()].filter((name) =>
    !known.has(name) && name !== "DATABASE_URL"
  );
  if (ignored.length > 0) {
    warnings.push(
      `Not imported into any app (used by other tools, or a typo): ${
        ignored.sort().join(", ")
      }`,
    );
  }

  // Last, the same validation the processes run at start-up, on the Fly
  // config plus these secrets. Its messages are scrubbed of every value.
  if (problems.length === 0) {
    const values = [...secrets.values()];
    try {
      enforceApiFailClosed(
        parseEnv(apiEnvSchema, {
          ...flyEnvs.api,
          ...Object.fromEntries(perApp.api),
        }),
      );
    } catch (error) {
      problems.push(
        `studafy-api would refuse to start: ${
          redact(error instanceof Error ? error.message : String(error), values)
        }`,
      );
    }
    try {
      enforceWorkerFailClosed(
        parseEnv(workerEnvSchema, {
          ...flyEnvs.worker,
          ...Object.fromEntries(perApp.worker),
        }),
      );
    } catch (error) {
      problems.push(
        `studafy-worker would refuse to start: ${
          redact(error instanceof Error ? error.message : String(error), values)
        }`,
      );
    }
  }
  return { perApp, problems, warnings };
}

// --------------------------------------------------------------------------
// Running commands.

export interface CommandResult {
  code: number;
  stdout: string;
  stderr: string;
}

export interface Runner {
  /**
   * Runs argv from the repository root. With [capture] the output is
   * returned; without, it streams to the terminal. [stdin] is written to
   * the process and never shown.
   */
  run(
    argv: readonly string[],
    options?: { stdin?: string; capture?: boolean },
  ): Promise<CommandResult>;
}

export const processRunner = (cwd: string = REPOSITORY_ROOT): Runner => ({
  run(argv, options = {}) {
    return new Promise((done) => {
      const [command, ...args] = argv;
      const child = spawn(command ?? "false", args, {
        cwd,
        stdio: [
          options.stdin === undefined ? "ignore" : "pipe",
          options.capture ? "pipe" : "inherit",
          options.capture ? "pipe" : "inherit",
        ],
      });
      let stdout = "";
      let stderr = "";
      child.stdout?.on("data", (chunk) => stdout += String(chunk));
      child.stderr?.on("data", (chunk) => stderr += String(chunk));
      child.on("error", () => done({ code: 127, stdout, stderr }));
      child.on("close", (code) => done({ code: code ?? 1, stdout, stderr }));
      if (options.stdin !== undefined) child.stdin?.end(options.stdin);
    });
  },
});

export interface Io {
  log(line: string): void;
  confirm(question: string): Promise<boolean>;
  sleep(ms: number): Promise<void>;
  fetch(url: string): Promise<{ status: number }>;
}

export const terminalIo: Io = {
  log: (line) => console.log(line),
  async confirm(question) {
    if (!process.stdin.isTTY) return false;
    const rl = createInterface({
      input: process.stdin,
      output: process.stdout,
    });
    try {
      const answer = await rl.question(`${question} [y/N] `);
      return /^y(es)?$/i.test(answer.trim());
    } finally {
      rl.close();
    }
  },
  sleep: (ms) => new Promise((done) => setTimeout(done, ms)),
  async fetch(url) {
    try {
      const response = await fetch(url, {
        signal: AbortSignal.timeout(10_000),
        redirect: "manual",
      });
      return { status: response.status };
    } catch {
      return { status: 0 };
    }
  },
};

// --------------------------------------------------------------------------
// Steps.

export const STEP_IDS = [
  "preflight",
  "create-apps",
  "import-secrets",
  "deploy-scanner",
  "stop-test-apps",
  "clean-test-data",
  "deploy-worker",
  "deploy-api",
  "dns",
  "alerts",
] as const;
export type StepId = (typeof STEP_IDS)[number];

export interface CutoverOptions {
  execute: boolean;
  yes: boolean;
  secretsPath?: string;
  from?: StepId;
  org: string;
}

interface Context {
  options: CutoverOptions;
  plan?: SecretPlan;
  runner: Runner;
  io: Io;
  existingApps?: Set<string>;
}

interface Step {
  id: StepId;
  title: string;
  /** What the step does, with the exact commands. */
  describe(context: Context): string[];
  /** Absent: the step is printed only, for the owner to do. */
  run?(context: Context): Promise<void>;
  /** Needs a "go" even with --yes (stops the test copy). */
  alwaysConfirm?: boolean;
}

export class CutoverError extends Error {
  override name = "CutoverError";
}

const API_HEALTH_URL = "https://studafy-api.fly.dev/readyz";
const PRODUCTION_URL = "https://api.studafy.com/readyz";

function secretsLabel(context: Context, app: AppKey): string {
  const names = context.plan
    ? [...context.plan.perApp[app].keys()]
    : [...REQUIRED_SECRETS[app]];
  return `< [${names.length} values from ${
    context.options.secretsPath ?? "--secrets <file>"
  }, never shown: ${names.join(", ")}]`;
}

const deployArgv = (app: AppKey) => [
  "fly",
  "deploy",
  "--config",
  APPS[app].config,
  "--app",
  APPS[app].app,
  "--remote-only",
];

async function must(
  context: Context,
  argv: readonly string[],
  options: { stdin?: string; capture?: boolean } = {},
): Promise<CommandResult> {
  context.io.log(`  $ ${argv.join(" ")}${options.stdin ? " < [hidden]" : ""}`);
  const result = await context.runner.run(argv, options);
  if (result.code !== 0) {
    const values = context.plan
      ? DEPLOY_ORDER.flatMap((app) => [...context.plan!.perApp[app].values()])
      : [];
    const detail = redact(`${result.stderr}${result.stdout}`.trim(), values)
      .split("\n").slice(-5).join("\n    ");
    throw new CutoverError(
      `"${argv.slice(0, 3).join(" ")}" failed (exit ${result.code})${
        detail ? `:\n    ${detail}` : ""
      }`,
    );
  }
  return result;
}

/** Every string under a key named [key] anywhere in a JSON value. */
export function collect(value: unknown, key: string): string[] {
  const found: string[] = [];
  const walk = (node: unknown) => {
    if (Array.isArray(node)) node.forEach(walk);
    else if (node && typeof node === "object") {
      for (const [name, child] of Object.entries(node)) {
        if (
          name.toLowerCase() === key.toLowerCase() && typeof child === "string"
        ) {
          found.push(child);
        } else walk(child);
      }
    }
  };
  walk(value);
  return found;
}

function parseJson(text: string): unknown {
  try {
    return JSON.parse(text);
  } catch {
    return undefined;
  }
}

async function poll(
  context: Context,
  what: string,
  timeoutMs: number,
  intervalMs: number,
  check: () => Promise<boolean>,
): Promise<void> {
  const deadline = Date.now() + timeoutMs;
  for (;;) {
    if (await check()) return;
    if (Date.now() >= deadline) {
      throw new CutoverError(`timed out waiting for ${what}`);
    }
    await context.io.sleep(intervalMs);
  }
}

async function machineStates(context: Context, app: string) {
  const status = await must(context, [
    "fly",
    "status",
    "--app",
    app,
    "--json",
  ], { capture: true });
  return collect(parseJson(status.stdout), "state");
}

export const STEPS: readonly Step[] = [
  {
    id: "preflight",
    title: "Preflight: fly, the apps, the secrets file",
    describe: (context) => [
      "fly version",
      "fly auth whoami",
      "fly apps list --json   (which of studafy-scanner, studafy-worker, studafy-api exist)",
      context.options.secretsPath
        ? `check ${context.options.secretsPath}: every required name present, per-app roles, production start-up checks`
        : "check the --secrets file (none given: --execute refuses)",
    ],
    async run(context) {
      await must(context, ["fly", "version"], { capture: true });
      await must(context, ["fly", "auth", "whoami"], { capture: true });
      const listed = await must(context, ["fly", "apps", "list", "--json"], {
        capture: true,
      });
      context.existingApps = new Set(collect(parseJson(listed.stdout), "name"));
      for (const app of DEPLOY_ORDER) {
        context.io.log(
          `  ${APPS[app].app}: ${
            context.existingApps.has(APPS[app].app) ? "exists" : "to create"
          }`,
        );
      }
    },
  },
  {
    id: "create-apps",
    title: "Create the production apps that do not exist",
    describe: (context) =>
      DEPLOY_ORDER.map((app) =>
        `fly apps create ${
          APPS[app].app
        } --org ${context.options.org}   (only if missing${
          app === "api" ? "; studafy-api already exists, suspended" : ""
        })`
      ),
    async run(context) {
      if (!context.existingApps) {
        const listed = await must(context, ["fly", "apps", "list", "--json"], {
          capture: true,
        });
        context.existingApps = new Set(
          collect(parseJson(listed.stdout), "name"),
        );
      }
      for (const app of DEPLOY_ORDER) {
        const name = APPS[app].app;
        if (context.existingApps.has(name)) {
          context.io.log(`  ${name} exists; not created`);
          continue;
        }
        await must(context, [
          "fly",
          "apps",
          "create",
          name,
          "--org",
          context.options.org,
        ], { capture: true });
        context.existingApps.add(name);
      }
    },
  },
  {
    id: "import-secrets",
    title: "Import each app's secrets (staged; applied by its deploy)",
    describe: (context) =>
      DEPLOY_ORDER.map((app) =>
        `fly secrets import --app ${APPS[app].app} --stage ${
          secretsLabel(context, app)
        }`
      ),
    async run(context) {
      const plan = context.plan;
      if (!plan) throw new CutoverError("no secrets file was read");
      for (const app of DEPLOY_ORDER) {
        const values = plan.perApp[app];
        await must(context, [
          "fly",
          "secrets",
          "import",
          "--app",
          APPS[app].app,
          "--stage",
        ], { stdin: serializeForFly(values), capture: true });
        const listed = await must(context, [
          "fly",
          "secrets",
          "list",
          "--app",
          APPS[app].app,
          "--json",
        ], { capture: true });
        const names = new Set(collect(parseJson(listed.stdout), "name"));
        const absent = [...values.keys()].filter((name) => !names.has(name));
        if (absent.length > 0) {
          throw new CutoverError(
            `${APPS[app].app} does not list ${
              absent.join(", ")
            } after the import`,
          );
        }
        context.io.log(`  ${APPS[app].app}: ${values.size} secrets staged`);
      }
    },
  },
  {
    id: "deploy-scanner",
    title: "Deploy the private malware scanner and wait for its health check",
    describe: () => [
      deployArgv("scanner").join(" "),
      "fly ips list --app studafy-scanner --json   (must be empty: no public address)",
      "fly checks list --app studafy-scanner --json   (until every check is passing; up to 6 minutes)",
    ],
    async run(context) {
      await must(context, deployArgv("scanner"));
      const ips = await must(context, [
        "fly",
        "ips",
        "list",
        "--app",
        APPS.scanner.app,
        "--json",
      ], { capture: true });
      const addresses = collect(parseJson(ips.stdout), "address");
      if (addresses.length > 0) {
        throw new CutoverError(
          "studafy-scanner has a public IP address; release it (fly ips release) before going on",
        );
      }
      await poll(
        context,
        "the scanner's /healthz check",
        6 * 60_000,
        15_000,
        async () => {
          const checks = await must(context, [
            "fly",
            "checks",
            "list",
            "--app",
            APPS.scanner.app,
            "--json",
          ], { capture: true });
          const statuses = collect(parseJson(checks.stdout), "status");
          context.io.log(`  checks: ${statuses.join(", ") || "none yet"}`);
          return statuses.length > 0 &&
            statuses.every((status) => status === "passing");
        },
      );
    },
  },
  {
    id: "stop-test-apps",
    title: "Stop the test copy (two workers must never share the database)",
    alwaysConfirm: true,
    describe: () => [
      ...TEST_APPS_STOP_ORDER.map((app) =>
        `fly scale count 0 --app ${app} --yes`
      ),
      "fly status --app <each> --json   (until no machine is started)",
      "Rollback: fly scale count 1 --app <each> --yes",
    ],
    async run(context) {
      for (const app of TEST_APPS_STOP_ORDER) {
        await must(context, [
          "fly",
          "scale",
          "count",
          "0",
          "--app",
          app,
          "--yes",
        ], {
          capture: true,
        });
        await poll(context, `${app} to stop`, 3 * 60_000, 10_000, async () => {
          const states = await machineStates(context, app);
          return !states.some((state) =>
            state === "started" || state === "starting"
          );
        });
        context.io.log(`  ${app}: stopped`);
      }
    },
  },
  {
    id: "clean-test-data",
    title: "Checkpoint: remove the owner's test schools (separate script)",
    describe: () => [
      "bun --no-env-file scripts/production/clean-test-data.ts --secrets <file>                    (lists the schools)",
      "bun --no-env-file scripts/production/clean-test-data.ts --secrets <file> --schools <ids>    (dry run, rolled back)",
      "bun --no-env-file scripts/production/clean-test-data.ts --secrets <file> --execute --confirm-schools <ids>",
      "Run it in another terminal now, while no worker runs, then answer yes to go on.",
    ],
    async run(context) {
      if (context.options.yes) {
        context.io.log(
          "  --yes: not waiting; run the cleanup before real users arrive",
        );
        return;
      }
      if (
        !(await context.io.confirm(
          "  Is the test data cleaned (or deliberately kept)?",
        ))
      ) {
        throw new CutoverError(
          "stopped at the cleanup checkpoint; resume with --from clean-test-data",
        );
      }
    },
  },
  {
    id: "deploy-worker",
    title: "Deploy the worker and wait for worker_ready",
    describe: () => [
      deployArgv("worker").join(" "),
      "fly logs --app studafy-worker --no-tail   (until worker_ready; refuses on database_privileged_role, redis_plaintext_remote or a configuration error)",
    ],
    async run(context) {
      await must(context, deployArgv("worker"));
      await poll(
        context,
        "worker_ready in the worker's log",
        5 * 60_000,
        15_000,
        async () => {
          const logs = await context.runner.run([
            "fly",
            "logs",
            "--app",
            APPS.worker.app,
            "--no-tail",
          ], { capture: true });
          const text = logs.stdout;
          for (
            const refusal of [
              "database_privileged_role",
              "redis_plaintext_remote",
              "CONFIG_INVALID",
              "Environment configuration rejected",
              "Production requires",
            ]
          ) {
            if (text.includes(refusal)) {
              throw new CutoverError(
                `the worker refused to start (${refusal}); see fly logs --app studafy-worker`,
              );
            }
          }
          return text.includes("worker_ready");
        },
      );
    },
  },
  {
    id: "deploy-api",
    title: "Deploy the API and wait for /readyz",
    describe: () => [
      deployArgv("api").join(" "),
      `GET ${API_HEALTH_URL}   (until 200; up to 5 minutes)`,
    ],
    async run(context) {
      await must(context, deployArgv("api"));
      await poll(
        context,
        `${API_HEALTH_URL} to return 200`,
        5 * 60_000,
        10_000,
        async () => {
          const { status } = await context.io.fetch(API_HEALTH_URL);
          context.io.log(`  /readyz: ${status || "no answer"}`);
          return status === 200;
        },
      );
    },
  },
  {
    id: "dns",
    title: "Domain: api.studafy.com (owner, or a later step; not run here)",
    describe: () => [
      "fly certs add api.studafy.com --app studafy-api",
      "If api.studafy.com still has the old Cloudflare Tunnel route to the Mac (docs/deployment/studafy-domain.md), remove that route and its record first",
      "Cloudflare DNS, zone studafy.com: CNAME api -> studafy-api.fly.dev, Proxied (orange cloud)",
      "Cloudflare DNS: the _acme-challenge CNAME that `fly certs add` prints, DNS only (grey cloud), so Fly can issue the certificate behind the proxy",
      "Cloudflare SSL/TLS mode: Full (strict)",
      "fly certs check api.studafy.com --app studafy-api   (until the certificate is issued)",
      `Check: GET ${PRODUCTION_URL} returns 200`,
      'Then a reviewed PR sets ORIGIN_REQUIRE_CLOUDFLARE = "true" in fly.api.toml (and scripts/fly-config.test.ts) and redeploys the API',
    ],
  },
  {
    id: "alerts",
    title: "Uptime alert: watch production, not the test copy (not run here)",
    describe: () => [
      `ops/alert-relay/wrangler.toml: UPTIME_URL = "${PRODUCTION_URL}" (a reviewed PR)`,
      "cd ops/alert-relay && npx wrangler deploy   (only once api.studafy.com answers, or the relay reports an outage)",
      "Check: a test alert from the deployed worker reaches Telegram (docs/deployment/queue-alerts.md)",
    ],
  },
];

// --------------------------------------------------------------------------
// The run.

export async function runCutover(
  options: CutoverOptions,
  dependencies: { runner: Runner; io: Io; flyEnvs: FlyEnvs },
): Promise<number> {
  const { runner, io } = dependencies;
  if (options.execute && !options.secretsPath) {
    io.log(
      "Refusing: --execute needs --secrets <file> (the production secrets, never printed). Nothing was run.",
    );
    return 2;
  }
  const context: Context = { options, runner, io };
  io.log(
    options.execute
      ? "PRODUCTION CUTOVER - EXECUTE. Each step asks first" +
        (options.yes ? " (--yes: only stopping the test copy asks)." : ".")
      : "PRODUCTION CUTOVER - DRY RUN. Nothing is run; this is what --execute would do.",
  );

  if (options.secretsPath) {
    try {
      context.plan = planSecrets(
        readSecretsFile(options.secretsPath),
        dependencies.flyEnvs,
      );
    } catch (error) {
      if (!(error instanceof SecretsFileError)) throw error;
      io.log(`Refusing: ${error.message}. Nothing was run.`);
      return 2;
    }
    for (const app of DEPLOY_ORDER) {
      io.log(
        `  ${APPS[app].app}: ${
          [...context.plan.perApp[app].keys()].join(", ") || "(none)"
        }`,
      );
    }
    for (const warning of context.plan.warnings) io.log(`  note: ${warning}`);
    if (context.plan.problems.length > 0) {
      io.log("Refusing: the secrets file is not ready:");
      for (const problem of context.plan.problems) io.log(`  - ${problem}`);
      io.log("Nothing was run.");
      return 1;
    }
    io.log("  secrets file: every required name present and checked");
  } else {
    io.log(
      "  no --secrets file: required names are listed below; --execute will refuse",
    );
    for (const app of DEPLOY_ORDER) {
      io.log(`  ${APPS[app].app}: ${REQUIRED_SECRETS[app].join(", ")}`);
    }
  }

  // Resuming still runs the preflight first: fly signed in, apps known.
  const start = options.from ? STEP_IDS.indexOf(options.from) : 0;
  const steps = start > 0 ? [STEPS[0]!, ...STEPS.slice(start)] : [...STEPS];
  for (const step of steps) {
    io.log("");
    io.log(
      `Step ${
        STEP_IDS.indexOf(step.id) + 1
      }/${STEPS.length} [${step.id}]: ${step.title}`,
    );
    for (const line of step.describe(context)) io.log(`  ${line}`);
    if (!options.execute) continue;
    if (!step.run) {
      io.log("  (printed only: for the owner, not run here)");
      continue;
    }
    if (
      (step.alwaysConfirm || !options.yes) &&
      !(await io.confirm(`  Run step ${step.id}?`))
    ) {
      io.log(`Stopped before ${step.id}. Resume with --from ${step.id}.`);
      return 3;
    }
    try {
      await step.run(context);
    } catch (error) {
      if (!(error instanceof CutoverError)) throw error;
      io.log(`Step ${step.id} failed: ${error.message}`);
      io.log(`Fix it, then resume with --from ${step.id}.`);
      return 1;
    }
  }
  io.log("");
  io.log(
    options.execute
      ? "Cutover steps done. Remaining: dns and alerts above, then the checks in docs/deployment/production-cutover.md."
      : "Dry run complete. Run again with --execute to act.",
  );
  return 0;
}

export class UsageError extends Error {
  override name = "UsageError";
}

export function parseArgs(argv: readonly string[]): CutoverOptions {
  const options: CutoverOptions = {
    execute: false,
    yes: false,
    org: "personal",
  };
  for (let index = 0; index < argv.length; index++) {
    const arg = argv[index];
    const value = () => {
      const next = argv[++index];
      if (next === undefined || next.startsWith("--")) {
        throw new UsageError(`${arg} needs a value`);
      }
      return next;
    };
    switch (arg) {
      case "--execute":
        options.execute = true;
        break;
      case "--dry-run":
        options.execute = false;
        break;
      case "--yes":
        options.yes = true;
        break;
      case "--secrets":
        options.secretsPath = value();
        break;
      case "--org":
        options.org = value();
        break;
      case "--from": {
        const step = value();
        if (!(STEP_IDS as readonly string[]).includes(step)) {
          throw new UsageError(
            `--from takes one of: ${STEP_IDS.join(", ")}`,
          );
        }
        options.from = step as StepId;
        break;
      }
      default:
        throw new UsageError(`unknown argument ${arg}`);
    }
  }
  if (argv.includes("--execute") && argv.includes("--dry-run")) {
    throw new UsageError("--execute and --dry-run cannot both be given");
  }
  return options;
}

if (import.meta.main) {
  let options: CutoverOptions;
  try {
    options = parseArgs(Bun.argv.slice(2));
  } catch (error) {
    if (!(error instanceof UsageError)) throw error;
    console.error(
      `${error.message}\n\nUsage: bun --no-env-file scripts/production/cutover.ts [--secrets <file>] [--execute [--yes]] [--from <step>] [--org <fly org>]`,
    );
    process.exit(64);
  }
  if (options.secretsPath) options.secretsPath = resolve(options.secretsPath);
  if (options.secretsPath && !existsSync(options.secretsPath)) {
    console.error(`No such file: ${options.secretsPath}`);
    process.exit(2);
  }
  process.exit(
    await runCutover(options, {
      runner: processRunner(),
      io: terminalIo,
      flyEnvs: await readFlyEnvs(),
    }),
  );
}
