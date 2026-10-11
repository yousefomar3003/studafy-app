/**
 * INFRA-081 migration gate: migrations are forward-only. Compared with the
 * base ref (default origin/main), no existing migration may be modified,
 * renamed or deleted, and every new migration must sort after the newest
 * migration already on the base, so replay order never changes.
 *
 * It also refuses the rename-and-wrap pattern in new migrations (ADR-0030):
 * extending a SQL function by renaming it to `<name>_pre_<change>` and
 * delegating to it grew private.authz_authorize to twenty nested calls.
 * Change a function by replacing it, or add a named handler it dispatches to.
 * A wrap already applied somewhere is accepted only once a later migration
 * unwinds it, so the schema the migrations build holds no new layer.
 *
 * Usage: bun scripts/check-migration-immutability.ts [baseRef]
 */
import { $ } from "bun";
import { unresolvedWraps } from "./migration-wraps";

const base = process.argv[2] ?? process.env["MIGRATION_BASE_REF"] ??
  "origin/main";
const dir = "supabase/migrations/";

const baseFiles = (await $`git ls-tree --name-only ${base} ${dir}`.quiet()
  .text())
  .split("\n").map((line) => line.trim()).filter((line) =>
    line.endsWith(".sql")
  ).sort();
if (baseFiles.length === 0) {
  console.error(`no migrations found on ${base}; is the ref fetched?`);
  process.exit(2);
}
const newestOnBase = baseFiles.at(-1)!;

const violations: string[] = [];
for (const file of baseFiles) {
  const exists = await Bun.file(file).exists();
  if (!exists) {
    violations.push(
      `${file}: deleted or renamed (applied migrations are permanent)`,
    );
    continue;
  }
  const diff = await $`git diff --quiet ${base} -- ${file}`.nothrow().quiet();
  if (diff.exitCode !== 0) {
    violations.push(`${file}: modified (write a forward migration instead)`);
  }
}

const current = [...new Bun.Glob("*.sql").scanSync(dir)].map((name) =>
  `${dir}${name}`
).sort();
for (const file of current) {
  if (baseFiles.includes(file)) continue;
  if (file <= newestOnBase) {
    violations.push(
      `${file}: sorts before ${newestOnBase}; new migrations must come last`,
    );
  }
}

// Migrations from before the chains were flattened are history; only new
// ones are held to the rule. An applied migration that broke it cannot be
// edited, so its wrap passes only once a later migration has unwound it
// (see migration-wraps.ts).
const WRAPPING_BANNED_AFTER = `${dir}202609280001_flatten_authorization.sql`;
const texts = await Promise.all(
  current.map(async (file) => ({ file, text: await Bun.file(file).text() })),
);
for (const wrap of unresolvedWraps(texts, WRAPPING_BANNED_AFTER)) {
  violations.push(
    `${wrap.file}: renames a function to ${wrap.name} to wrap it, and no later migration unwinds it; replace it or add a named handler instead (ADR-0030)`,
  );
}

if (violations.length > 0) {
  console.error(`migration gate failed against ${base}:`);
  for (const violation of violations) console.error(`  - ${violation}`);
  process.exit(1);
}
console.log(JSON.stringify({
  event: "migration_gate",
  result: "pass",
  base,
  existing: baseFiles.length,
  added: current.length - baseFiles.length,
}));
