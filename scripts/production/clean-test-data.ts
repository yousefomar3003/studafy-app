/**
 * Removes the owner's TEST schools from the shared Frankfurt database at
 * launch (DL-064; docs/deployment/production-cutover.md). The SQL, and what
 * exactly it removes and keeps, is supabase/cutover/clean-test-data.sql.
 *
 * Dry run is the default and changes nothing:
 *
 *   # Every school, to choose from (ids, names, members, the reviewer school)
 *   bun --no-env-file scripts/production/clean-test-data.ts --secrets <file>
 *
 *   # What removing these would do: the removal runs inside one transaction,
 *   # is verified, printed, and rolled back.
 *   bun --no-env-file scripts/production/clean-test-data.ts --secrets <file> \
 *     --schools <id>,<id>
 *
 *   # Remove them: the same, committed; then their stored files are deleted
 *   # through the Storage API.
 *   bun --no-env-file scripts/production/clean-test-data.ts --secrets <file> \
 *     --execute --confirm-schools <id>,<id>
 *
 * Flags:
 *   --include-reviewer-school  needed to remove "Cedar Grove Review School"
 *                              (the store reviewers' school), even when named
 *   --release-legal-holds      removes active legal holds in these schools
 *                              with them; otherwise a hold refuses the run
 *   --yes                      no question before committing
 *   --objects-out <file>       where the list of stored files to delete is
 *                              saved (default ~/studafy-cutover-objects-<time>.json)
 *   --delete-objects <file>    retry deleting a saved list; nothing else
 *
 * The secrets file (format: secretsFile.ts) needs
 *   ADMIN_DATABASE_URL   a session connection as postgres: the direct
 *                        connection, or the session pooler on :5432. The
 *                        runtime roles cannot run the purges.
 *   DATABASE_CA_CERT     the Supabase root CA; the certificate is verified
 *   SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY   for deleting stored files
 * Values are never printed. Emails of removed accounts are shown masked.
 *
 * It refuses the developer's local stack (port 54322) always, and any other
 * loopback database unless --allow-local (the integration test's throwaway
 * stack).
 */
import { renameSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { resolve } from "node:path";
import { createInterface } from "node:readline/promises";
import postgres from "postgres";
import { databaseTls } from "../../packages/database/src/index.ts";
import { readSecretsFile, redact, SecretsFileError } from "./secretsFile.ts";

const REPOSITORY_ROOT = resolve(import.meta.dir, "..", "..");
export const SQL_FILE = resolve(
  REPOSITORY_ROOT,
  "supabase/cutover/clean-test-data.sql",
);
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const LOOPBACK = new Set(["127.0.0.1", "localhost", "::1", "[::1]"]);

export class UsageError extends Error {
  override name = "UsageError";
}

export interface CleanOptions {
  secretsPath?: string;
  schools: string[];
  execute: boolean;
  includeReviewer: boolean;
  releaseHolds: boolean;
  yes: boolean;
  allowLocal: boolean;
  objectsOut?: string;
  deleteObjects?: string;
}

function ids(value: string): string[] {
  const list = value.split(",").map((id) => id.trim().toLowerCase()).filter(
    Boolean,
  );
  for (const id of list) {
    if (!UUID.test(id)) throw new UsageError(`"${id}" is not a school id`);
  }
  if (list.length === 0) throw new UsageError("name at least one school id");
  return list;
}

export function parseArgs(argv: readonly string[]): CleanOptions {
  const options: CleanOptions = {
    schools: [],
    execute: false,
    includeReviewer: false,
    releaseHolds: false,
    yes: false,
    allowLocal: false,
  };
  let schools: string[] | undefined;
  let confirm: string[] | undefined;
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
      case "--secrets":
        options.secretsPath = value();
        break;
      case "--schools":
        schools = ids(value());
        break;
      case "--confirm-schools":
        confirm = ids(value());
        break;
      case "--execute":
        options.execute = true;
        break;
      case "--dry-run":
        break;
      case "--include-reviewer-school":
        options.includeReviewer = true;
        break;
      case "--release-legal-holds":
        options.releaseHolds = true;
        break;
      case "--yes":
        options.yes = true;
        break;
      case "--allow-local":
        options.allowLocal = true;
        break;
      case "--objects-out":
        options.objectsOut = value();
        break;
      case "--delete-objects":
        options.deleteObjects = value();
        break;
      default:
        throw new UsageError(`unknown argument ${arg}`);
    }
  }
  if (!options.secretsPath) {
    throw new UsageError("--secrets <file> is required");
  }
  if (options.execute && argv.includes("--dry-run")) {
    throw new UsageError("--execute and --dry-run cannot both be given");
  }
  if (options.deleteObjects) {
    if (options.execute || schools || confirm) {
      throw new UsageError("--delete-objects runs on its own");
    }
    return options;
  }
  if (options.execute) {
    if (!confirm) {
      throw new UsageError(
        "--execute needs --confirm-schools <ids>: exactly the schools to remove",
      );
    }
    if (schools && schools.join() !== confirm.join()) {
      throw new UsageError(
        "--schools and --confirm-schools name different schools",
      );
    }
    options.schools = confirm;
  } else {
    if (confirm) {
      throw new UsageError(
        "--confirm-schools is for --execute; a dry run takes --schools",
      );
    }
    options.schools = schools ?? [];
  }
  return options;
}

/** The database URL, refused when it is the developer's own local stack. */
export function checkTarget(url: string, allowLocal: boolean): void {
  let parsed: URL;
  try {
    parsed = new URL(url);
  } catch {
    throw new UsageError("ADMIN_DATABASE_URL is not a URL");
  }
  if (LOOPBACK.has(parsed.hostname)) {
    if (["54322", "5432", ""].includes(parsed.port)) {
      throw new UsageError(
        "refusing the local development database (port 54322 or the default port); use a throwaway stack",
      );
    }
    if (!allowLocal) {
      throw new UsageError(
        "ADMIN_DATABASE_URL is a local database; pass --allow-local for a throwaway stack",
      );
    }
  }
  const user = decodeURIComponent(parsed.username).split(".")[0];
  if (user !== "postgres") {
    throw new UsageError(
      `ADMIN_DATABASE_URL must log in as postgres (it runs the retention purges), not "${user}"`,
    );
  }
  if (parsed.port === "6543") {
    throw new UsageError(
      "ADMIN_DATABASE_URL must be a session connection (direct, or the pooler on :5432), not the transaction pooler (:6543)",
    );
  }
}

export interface StorageObject {
  bucket: string;
  key: string;
}

export interface CleanResult {
  plan: Record<string, unknown>;
  classes_purged: number;
  accounts_deidentified: number;
  storage_objects: StorageObject[];
  kept_fingerprint_tables: number;
}

export type Sql = ReturnType<typeof postgres>;

/**
 * One transaction: load the SQL, plan, and (unless only listing) clean.
 * Commits only when [commit]; otherwise rolls back whatever happened.
 */
export async function runInTransaction(
  sql: Sql,
  options: Pick<
    CleanOptions,
    "schools" | "includeReviewer" | "releaseHolds"
  >,
  commit: (result: CleanResult) => Promise<boolean>,
): Promise<
  | { kind: "list"; schools: Record<string, unknown>[] }
  | { kind: "refused"; plan?: Record<string, unknown>; reason: string }
  | { kind: "done"; result: CleanResult; committed: boolean }
> {
  const source = await Bun.file(SQL_FILE).text();
  const reserved = await sql.reserve();
  let open = false;
  try {
    await reserved.unsafe("begin isolation level repeatable read");
    open = true;
    await reserved.unsafe("set local lock_timeout = '10s'");
    await reserved.unsafe("set local statement_timeout = '15min'");
    await reserved.unsafe(source);
    if (options.schools.length === 0) {
      const [row] = await reserved.unsafe<
        { schools: Record<string, unknown>[] }[]
      >(
        "select pg_temp.cutover_list_schools() as schools",
      );
      return { kind: "list", schools: row?.schools ?? [] };
    }
    let plan: Record<string, unknown>;
    try {
      const [row] = await reserved.unsafe<{ plan: Record<string, unknown> }[]>(
        "select pg_temp.cutover_plan($1::uuid[], $2, $3) as plan",
        [options.schools, options.includeReviewer, options.releaseHolds],
      );
      plan = row!.plan;
    } catch (error) {
      return { kind: "refused", reason: databaseMessage(error) };
    }
    if ((plan["blockers"] as unknown[]).length > 0) {
      return {
        kind: "refused",
        plan,
        reason: (plan["blockers"] as string[]).join("; "),
      };
    }
    let result: CleanResult;
    try {
      const [row] = await reserved.unsafe<{ result: CleanResult }[]>(
        "select pg_temp.cutover_clean($1::uuid[], $2, $3) as result",
        [options.schools, options.includeReviewer, options.releaseHolds],
      );
      result = row!.result;
    } catch (error) {
      return { kind: "refused", plan, reason: databaseMessage(error) };
    }
    if (await commit(result)) {
      await reserved.unsafe("commit");
      open = false;
      return { kind: "done", result, committed: true };
    }
    return { kind: "done", result, committed: false };
  } finally {
    if (open) await reserved.unsafe("rollback").catch(() => {});
    reserved.release();
  }
}

function databaseMessage(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}

/** Deletes stored objects through the Storage API, 100 keys per call. */
export async function deleteStoredObjects(
  objects: readonly StorageObject[],
  storage: { url: string; serviceRoleKey: string },
  fetcher: typeof fetch = fetch,
): Promise<{ deleted: number; failed: StorageObject[] }> {
  const byBucket = new Map<string, string[]>();
  for (const { bucket, key } of objects) {
    byBucket.set(bucket, [...(byBucket.get(bucket) ?? []), key]);
  }
  let deleted = 0;
  const failed: StorageObject[] = [];
  for (const [bucket, keys] of byBucket) {
    for (let start = 0; start < keys.length; start += 100) {
      const batch = keys.slice(start, start + 100);
      try {
        const response = await fetcher(
          `${storage.url.replace(/\/+$/, "")}/storage/v1/object/${
            encodeURIComponent(bucket)
          }`,
          {
            method: "DELETE",
            headers: {
              authorization: `Bearer ${storage.serviceRoleKey}`,
              apikey: storage.serviceRoleKey,
              "content-type": "application/json",
            },
            body: JSON.stringify({ prefixes: batch }),
            signal: AbortSignal.timeout(30_000),
          },
        );
        if (!response.ok) throw new Error(`HTTP ${response.status}`);
        const removed = await response.json() as { name?: string }[];
        const names = new Set(removed.map((item) => item.name));
        deleted += names.size;
        for (const key of batch) {
          if (!names.has(key)) failed.push({ bucket, key });
        }
      } catch {
        failed.push(...batch.map((key) => ({ bucket, key })));
      }
    }
  }
  return { deleted, failed };
}

function printPlan(plan: Record<string, unknown>, log: (line: string) => void) {
  const schools = plan["schools"] as {
    id: string;
    name: string;
    status: string;
    reviewer_school: boolean;
  }[];
  log("Schools to remove:");
  for (const school of schools) {
    log(
      `  ${school.id}  ${school.name}  (${school.status}${
        school.reviewer_school ? ", REVIEWER SCHOOL" : ""
      })`,
    );
  }
  log(`Classes: ${plan["classes"]}`);
  log("Rows removed, per table:");
  const rows = Object.entries(plan["rows"] as Record<string, number>).sort();
  for (const [table, count] of rows) log(`  ${table}: ${count}`);
  const removed = plan["accounts_removed"] as {
    email: string | null;
    kind: string | null;
    roles: string[] | null;
  }[];
  log(`Accounts de-identified (test-only): ${removed.length}`);
  for (const account of removed) {
    log(
      `  ${account.email ?? "(no email)"}  ${account.kind ?? "-"}  ${
        (account.roles ?? []).join(",")
      }`,
    );
  }
  log(`Accounts kept: ${JSON.stringify(plan["accounts_kept"])}`);
  log(`Files by scan state: ${JSON.stringify(plan["files_by_state"])}`);
  if (Number(plan["kept_accounts_personal_files"]) > 0) {
    log(
      `Note: ${
        plan["kept_accounts_personal_files"]
      } personal file(s) of kept accounts are stored in these schools and go with them`,
    );
  }
  log(`File jobs in flight (cancelled): ${plan["file_jobs_in_flight"]}`);
  log(`Active legal holds: ${plan["legal_holds_active"]}`);
}

async function ask(question: string): Promise<boolean> {
  if (!process.stdin.isTTY) return false;
  const rl = createInterface({ input: process.stdin, output: process.stdout });
  try {
    return /^y(es)?$/i.test((await rl.question(`${question} [y/N] `)).trim());
  } finally {
    rl.close();
  }
}

export async function main(
  argv: readonly string[],
  log: (line: string) => void = console.log,
  confirm: (question: string) => Promise<boolean> = ask,
): Promise<number> {
  let options: CleanOptions;
  let secrets: Map<string, string>;
  try {
    options = parseArgs(argv);
    secrets = readSecretsFile(resolve(options.secretsPath!));
  } catch (error) {
    if (error instanceof UsageError || error instanceof SecretsFileError) {
      log(`Refusing: ${error.message}`);
      return 64;
    }
    throw error;
  }
  const values = [...secrets.values()];
  const storage = secrets.get("SUPABASE_URL") &&
      secrets.get("SUPABASE_SERVICE_ROLE_KEY")
    ? {
      url: secrets.get("SUPABASE_URL")!,
      serviceRoleKey: secrets.get("SUPABASE_SERVICE_ROLE_KEY")!,
    }
    : undefined;

  if (options.deleteObjects) {
    if (!storage) {
      log("Refusing: SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are needed");
      return 64;
    }
    const objects = JSON.parse(
      await Bun.file(resolve(options.deleteObjects)).text(),
    ) as StorageObject[];
    const { deleted, failed } = await deleteStoredObjects(objects, storage);
    log(`Stored files deleted: ${deleted}; not deleted: ${failed.length}`);
    if (failed.length > 0) {
      writeFileSync(resolve(options.deleteObjects), JSON.stringify(failed), {
        mode: 0o600,
      });
      log(`The rest are saved in ${options.deleteObjects}; run again later.`);
      return 1;
    }
    return 0;
  }

  const url = secrets.get("ADMIN_DATABASE_URL");
  try {
    if (!url) {
      throw new UsageError("the secrets file has no ADMIN_DATABASE_URL");
    }
    checkTarget(url, options.allowLocal);
  } catch (error) {
    if (!(error instanceof UsageError)) throw error;
    log(`Refusing: ${error.message}`);
    return 64;
  }
  if (options.execute && !storage) {
    log(
      "Refusing: --execute needs SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY in the secrets file, to delete the schools' stored files",
    );
    return 64;
  }

  const ssl = databaseTls(url, secrets.get("DATABASE_CA_CERT"));
  const sql = postgres(url, {
    ...(ssl === undefined ? {} : { ssl }),
    max: 1,
    prepare: false,
    onnotice: () => {},
    connection: { application_name: "studafy-cutover-clean-test-data" },
  });
  try {
    log(
      options.execute
        ? "CLEAN TEST DATA - EXECUTE"
        : "CLEAN TEST DATA - DRY RUN (rolled back; nothing changes)",
    );
    const outcome = await runInTransaction(sql, options, async (result) => {
      printPlan(result.plan, log);
      log(
        `Done in the transaction: ${result.classes_purged} class(es) purged, ${result.accounts_deidentified} account(s) de-identified, ${result.storage_objects.length} stored file(s) to delete; ${result.kept_fingerprint_tables} kept tables verified unchanged.`,
      );
      if (!options.execute) return false;
      return options.yes ||
        await confirm(
          `Commit the removal of ${options.schools.length} school(s)?`,
        );
    });

    if (outcome.kind === "list") {
      log("Schools (choose the test ones; the reviewer school is marked):");
      for (const school of outcome.schools) {
        log(
          `  ${school["id"]}  ${school["name"]}  status=${
            school["status"]
          } members=${school["members"]} classes=${school["classes"]}${
            school["reviewer_school"] ? "  REVIEWER SCHOOL" : ""
          }`,
        );
      }
      log("Next: --schools <ids> for a dry run of their removal.");
      return 0;
    }
    if (outcome.kind === "refused") {
      if (outcome.plan) printPlan(outcome.plan, log);
      log(`Refused: ${redact(outcome.reason, values)}`);
      log("Nothing was changed.");
      return 1;
    }
    if (!outcome.committed) {
      log(
        options.execute
          ? "Not committed; nothing was changed."
          : `Rolled back. To do it: --execute --confirm-schools ${
            options.schools.join(",")
          }`,
      );
      return options.execute ? 3 : 0;
    }

    log("Committed.");
    const objects = outcome.result.storage_objects;
    if (objects.length === 0) return 0;
    const path = resolve(
      options.objectsOut ??
        resolve(homedir(), `studafy-cutover-objects-${Date.now()}.json`),
    );
    writeFileSync(`${path}.tmp`, JSON.stringify(objects), { mode: 0o600 });
    renameSync(`${path}.tmp`, path);
    const { deleted, failed } = await deleteStoredObjects(objects, storage!);
    log(`Stored files deleted: ${deleted}; not deleted: ${failed.length}`);
    if (failed.length > 0) {
      writeFileSync(path, JSON.stringify(failed), { mode: 0o600 });
      log(
        `The rest are saved in ${path}; retry: --secrets <file> --delete-objects ${path}`,
      );
      return 1;
    }
    return 0;
  } catch (error) {
    log(
      `Failed: ${
        redact(error instanceof Error ? error.message : String(error), values)
      }`,
    );
    log("Nothing was committed unless the line above says Committed.");
    return 1;
  } finally {
    await sql.end({ timeout: 5 });
  }
}

if (import.meta.main) {
  process.exit(await main(Bun.argv.slice(2)));
}
