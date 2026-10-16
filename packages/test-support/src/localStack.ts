/**
 * Which local Supabase stack a test or verification script may use.
 *
 * The Supabase CLI's default stack (API 54321, database 54322) is the one
 * `supabase status` reports for this checkout. In CI that is the job's only,
 * throwaway stack. On a developer's machine it is their working stack, and
 * throwaway stacks run beside it on other ports, so a script that falls back
 * to the default reaches the wrong one (it has, more than once).
 *
 * The rule: outside CI (`CI` unset) a script names its stack - with
 * SUPABASE_WORKDIR (or a --workdir flag), or with an explicit URL variable of
 * its own - and refuses, or skips, when it would otherwise use the default.
 */
import { spawnSync } from "node:child_process";
import { resolve } from "node:path";

type Env = Record<string, string | undefined>;

/** The CLI's default ports: the developer's working stack outside CI. */
export const DEFAULT_STACK = {
  apiUrl: "http://127.0.0.1:54321",
  dbPort: "54322",
} as const;

/** A script was about to use a stack nobody named. */
export class StackTargetError extends Error {
  override name = "StackTargetError";
}

/** True on a CI runner (GitHub Actions sets CI=true). */
export function inCi(env: Env = process.env): boolean {
  const value = env["CI"]?.trim().toLowerCase();
  return !!value && value !== "false" && value !== "0";
}

/**
 * The `--workdir` to ask the Supabase CLI about: the flag, else
 * SUPABASE_WORKDIR, else - in CI only - none (the default stack). Outside CI
 * with neither, it throws.
 */
export function stackWorkdir(
  purpose: string,
  options: { env?: Env; workdir?: string } = {},
): string | undefined {
  const env = options.env ?? process.env;
  const workdir = options.workdir || env["SUPABASE_WORKDIR"] || undefined;
  if (workdir) return resolve(workdir);
  if (inCi(env)) return undefined;
  throw new StackTargetError(
    `${purpose}: name the Supabase stack to use. Outside CI the default ` +
      `stack (${DEFAULT_STACK.apiUrl}, database port ${DEFAULT_STACK.dbPort}) ` +
      "is the developer's working one, so it is never assumed. Set " +
      "SUPABASE_WORKDIR=<throwaway stack dir>: the directory whose " +
      "supabase/config.toml started that stack.",
  );
}

/**
 * A Supabase URL that belongs to the stack DATABASE_URL names: the explicit
 * variable if set; else, in CI and only when DATABASE_URL is the default
 * database, the default API. Otherwise undefined, and the caller skips or
 * refuses.
 */
export function stackApiUrl(
  explicitVariable: string,
  env: Env = process.env,
): string | undefined {
  const explicit = env[explicitVariable];
  if (explicit) return explicit;
  const databaseUrl = env["DATABASE_URL"];
  if (!inCi(env) || !databaseUrl) return undefined;
  try {
    return new URL(databaseUrl).port === DEFAULT_STACK.dbPort
      ? DEFAULT_STACK.apiUrl
      : undefined;
  } catch {
    return undefined;
  }
}

/** The KEY="value" lines of `supabase status -o env`. */
export function parseStatusEnv(text: string): Map<string, string> {
  const values = new Map<string, string>();
  for (const line of text.split("\n")) {
    const match = /^([A-Z_0-9]+)="(.*)"$/.exec(line.trim());
    if (match?.[1] && match[2] !== undefined) values.set(match[1], match[2]);
  }
  return values;
}

export interface LocalStack {
  /** The stack's directory, or undefined for CI's default stack. */
  workdir: string | undefined;
  apiUrl: string;
  dbUrl: string;
  serviceRoleKey: string;
  /** Every value the CLI reported (ANON_KEY, SECRET_KEY, ...). */
  values: Map<string, string>;
}

const LOOPBACK = /^[a-z]+:\/\/([^/@]*@)?(127\.0\.0\.1|localhost)(:\d+)?(\/|$)/;

/** Checks a status report and picks out what every caller needs. */
export function stackFromStatus(
  purpose: string,
  workdir: string | undefined,
  statusText: string,
): LocalStack {
  const values = parseStatusEnv(statusText);
  const apiUrl = values.get("API_URL") ?? "";
  const dbUrl = values.get("DB_URL") ?? "";
  const serviceRoleKey = values.get("SERVICE_ROLE_KEY") ?? "";
  if (!apiUrl || !dbUrl || !serviceRoleKey) {
    throw new StackTargetError(
      `${purpose}: the stack did not report API_URL, DB_URL and ` +
        "SERVICE_ROLE_KEY. Is it running?",
    );
  }
  for (const url of [apiUrl, dbUrl]) {
    if (!LOOPBACK.test(url)) {
      throw new StackTargetError(
        `${purpose}: refusing a stack that is not on this machine.`,
      );
    }
  }
  return { workdir, apiUrl, dbUrl, serviceRoleKey, values };
}

/** Runs `supabase status -o env`; replaceable in tests. */
export type StatusRunner = (
  args: string[],
) => { ok: boolean; stdout: string };

const runSupabase: StatusRunner = (args) => {
  const result = spawnSync("bunx", ["supabase", ...args], {
    encoding: "utf8",
    stdio: ["ignore", "pipe", "pipe"],
  });
  return { ok: result.status === 0, stdout: result.stdout ?? "" };
};

/**
 * The local stack a script may use, read from `supabase status`. Outside CI
 * the stack must be named (see stackWorkdir), or this throws.
 */
export function readLocalStack(
  purpose: string,
  options: { env?: Env; workdir?: string; run?: StatusRunner } = {},
): LocalStack {
  const workdir = stackWorkdir(purpose, options);
  const run = options.run ?? runSupabase;
  const status = run([
    "status",
    "-o",
    "env",
    ...(workdir ? ["--workdir", workdir] : []),
  ]);
  if (!status.ok) {
    throw new StackTargetError(
      `${purpose}: could not read the Supabase stack` +
        `${workdir ? ` in ${workdir}` : ""}. Is it running?`,
    );
  }
  return stackFromStatus(purpose, workdir, status.stdout);
}

/**
 * readLocalStack for a script's entry point: a refusal is printed and the
 * process exits 2, without a stack trace.
 */
export function localStackOrExit(
  purpose: string,
  options: { env?: Env; workdir?: string; run?: StatusRunner } = {},
): LocalStack {
  try {
    return readLocalStack(purpose, options);
  } catch (error) {
    if (!(error instanceof StackTargetError)) throw error;
    console.error(error.message);
    process.exit(2);
  }
}
