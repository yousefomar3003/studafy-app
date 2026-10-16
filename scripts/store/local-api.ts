/**
 * Starts the real API against a THROWAWAY Supabase stack, for the store
 * screenshots (launch plan A4). Usage:
 *
 *   bun --no-env-file scripts/store/local-api.ts --workdir <stack dir> [--port 8095]
 *
 * <stack dir> holds a supabase/config.toml copied from the repo's, with its
 * own project_id and ports (never the working stack `studafy` on 54322).
 * Every value is passed explicitly: the repo's .env points at the working
 * database, so it is never read (--no-env-file here and in the child).
 *
 * AI is off: no AI_API_KEY is set, so the study tools report themselves
 * switched off and nothing is sent to a provider. Billing is off too.
 */
import { spawnSync } from "node:child_process";
import { randomBytes } from "node:crypto";

function arg(name: string): string | undefined {
  const index = process.argv.indexOf(name);
  return index < 0 ? undefined : process.argv[index + 1];
}

export function readStack(workdir: string): Map<string, string> {
  const status = spawnSync(
    "bunx",
    ["supabase", "status", "--workdir", workdir, "-o", "env"],
    { encoding: "utf8" },
  );
  if (status.status !== 0) {
    throw new Error(`Could not read the stack in ${workdir}: is it running?`);
  }
  const values = new Map<string, string>();
  for (const line of status.stdout.split("\n")) {
    const match = /^([A-Z_0-9]+)="(.*)"$/.exec(line.trim());
    if (match?.[1] && match[2] !== undefined) values.set(match[1], match[2]);
  }
  const db = values.get("DB_URL") ?? "";
  // The working database: refuse outright, whatever the workdir says.
  if (/:54322\//.test(db) || !/127\.0\.0\.1|localhost/.test(db)) {
    throw new Error(`Refusing: ${workdir} is not a local throwaway stack.`);
  }
  return values;
}

if (import.meta.main) {
  const workdir = arg("--workdir");
  if (!workdir) throw new Error("Pass --workdir <throwaway stack dir>.");
  const port = arg("--port") ?? "8095";
  const stack = readStack(workdir);
  const key = () => randomBytes(32).toString("hex");
  const env: Record<string, string> = {
    PATH: process.env["PATH"] ?? "",
    HOME: process.env["HOME"] ?? "",
    ENVIRONMENT: "development",
    API_PORT: port,
    LOG_LEVEL: "warn",
    DATABASE_URL: stack.get("DB_URL")!,
    SUPABASE_URL: stack.get("API_URL")!,
    SUPABASE_SERVICE_ROLE_KEY: stack.get("SERVICE_ROLE_KEY")!,
    STORAGE_URL: stack.get("API_URL")!,
    STORAGE_SERVICE_ROLE_KEY: stack.get("SERVICE_ROLE_KEY")!,
    API_CURSOR_SIGNING_KEY: key(),
    RATE_LIMIT_HMAC_SIGNING_KEY: key(),
    RATE_LIMIT_ENABLED: "false",
    CLASS_JOIN_CODE_KEY: key(),
    FILE051_DELIVERY_SIGNING_KEY: key(),
    FILE050_NEW_INTENTS_ENABLED: "true",
    FILE051_PUBLISH_ENABLED: "true",
    FILE051_DELIVERY_ENABLED: "true",
    FILE051_DELIVERY_PUBLIC_BASE_URL: `http://127.0.0.1:${port}`,
    API_REQUEST_TIMEOUT_MS: "20000",
    PAY071_BILLING_ENABLED: "false",
    // Off unless `--messaging on` (production has it on, DL-063): the
    // launch screenshots so far were taken with it off.
    MESSAGING_ENABLED: arg("--messaging") === "on" ? "true" : "false",
  };
  const child = Bun.spawn(
    [process.execPath, "--no-env-file", "apps/api/src/index.ts"],
    { env, stdout: "inherit", stderr: "inherit" },
  );
  process.on("SIGINT", () => child.kill());
  process.on("SIGTERM", () => child.kill());
  process.exitCode = await child.exited;
}
