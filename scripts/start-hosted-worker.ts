import { parseEnv } from "node:util";
import { resolve } from "node:path";

import { validateHostedEnvironment } from "./start-hosted-api.ts";

/**
 * The worker settings the hosted launcher allows. Hosted development runs
 * the worker for files only - the scan that clears an upload before anyone
 * can open it, and the cleanup of abandoned uploads. Notifications, billing,
 * account-rights executors and database housekeeping stay off, whatever
 * `.env.hosted` says, until each is set up for the hosted project on its own.
 */
export function hostedWorkerEnvironment(
  env: Record<string, string>,
): Record<string, string> {
  validateHostedEnvironment(env);
  if (env.FILE051_SCAN_ENABLED !== "true") {
    throw new Error(
      "Hosted worker needs FILE051_SCAN_ENABLED=true in .env.hosted; without the scan, uploads are never cleared.",
    );
  }
  return {
    ...env,
    DB_HOUSEKEEPING_ENABLED: "false",
    OPS061_NOTIFICATIONS_ENABLED: "false",
    PAY071_BILLING_ENABLED: "false",
    PAY071_RECONCILIATION_ENABLED: "false",
    ACCOUNT_DELETION_EXECUTOR_ENABLED: "false",
    DATA_EXPORT_EXECUTOR_ENABLED: "false",
    MEETINGS_PROCESSOR_ENABLED: "false",
    FILE051_RETENTION_ENABLED: "false",
  };
}

if (import.meta.main) {
  try {
    const file = resolve(".env.hosted");
    const env = hostedWorkerEnvironment(
      parseEnv(await Bun.file(file).text()) as Record<string, string>,
    );
    // Prevent Bun's automatic root .env load from silently adding local DB
    // credentials, exactly as the hosted API launcher does.
    const child = Bun.spawn([
      process.execPath,
      "--no-env-file",
      "apps/worker/src/index.ts",
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
        error.message.startsWith("Hosted worker needs") ||
        error.message.startsWith("This launcher is only") ||
        error.message.startsWith("SUPABASE_URL must")
      )
      ? error.message
      : "Cannot load hosted configuration. Check .env.hosted without sharing its secrets.";
    console.error(message);
    process.exitCode = 1;
  }
}
