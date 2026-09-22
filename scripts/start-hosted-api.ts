import { parseEnv } from "node:util";
import { resolve } from "node:path";

/** Reject a mixed local database / hosted identity configuration before boot. */
export function validateHostedEnvironment(env: Record<string, string>): void {
  if (env.ENVIRONMENT !== "development") {
    throw new Error("This launcher is only for hosted development testing.");
  }
  const project = new URL(env.SUPABASE_URL ?? "").hostname;
  const ref = project.replace(/\.supabase\.co$/, "");
  if (project === ref || !/^[a-z0-9]+$/.test(ref)) {
    throw new Error("SUPABASE_URL must identify the hosted Supabase project.");
  }
  if (!env.DATABASE_URL) {
    throw new Error(
      "Add this project's complete DATABASE_URL to ignored .env.hosted. The supplied URL still has a password placeholder.",
    );
  }
  const db = new URL(env.DATABASE_URL);
  const direct = db.hostname === `db.${ref}.supabase.co`;
  const pooler = db.hostname.endsWith(".pooler.supabase.com") &&
    decodeURIComponent(db.username).endsWith(`.${ref}`);
  if (
    !["postgres:", "postgresql:"].includes(db.protocol) ||
    (!direct && !pooler) ||
    !db.password || decodeURIComponent(db.password).includes("[YOUR-PASSWORD]")
  ) {
    throw new Error(
      "DATABASE_URL must contain a real password and match the hosted Supabase project. Local databases are not accepted.",
    );
  }
  if (!env.API_CURSOR_SIGNING_KEY || !env.RATE_LIMIT_HMAC_SIGNING_KEY) {
    throw new Error(
      "Hosted development requires its own cursor and rate-limit signing keys.",
    );
  }
}

if (import.meta.main) {
  try {
    const file = resolve(".env.hosted");
    const env = parseEnv(await Bun.file(file).text());
    validateHostedEnvironment(env);
    // Prevent Bun's automatic root .env load from silently adding local DB credentials.
    const child = Bun.spawn([
      process.execPath,
      "--no-env-file",
      "apps/api/src/index.ts",
    ], {
      cwd: process.cwd(),
      env: {
        PATH: process.env.PATH ?? "",
        HOME: process.env.HOME ?? "",
        TMPDIR: process.env.TMPDIR ?? "/tmp",
        ...env,
      },
      stdin: "inherit",
      stdout: "inherit",
      stderr: "inherit",
    });
    process.exit(await child.exited);
  } catch (error) {
    // Do not print parser exceptions containing input URLs or credential values.
    const message = error instanceof Error && (
        error.message.startsWith("Add this project's") ||
        error.message.startsWith("DATABASE_URL must") ||
        error.message.startsWith("Hosted development requires") ||
        error.message.startsWith("This launcher is only") ||
        error.message.startsWith("SUPABASE_URL must")
      )
      ? error.message
      : "Cannot load hosted configuration. Check .env.hosted without sharing its secrets.";
    console.error(message);
    process.exitCode = 1;
  }
}
