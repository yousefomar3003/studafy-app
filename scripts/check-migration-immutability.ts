/**
 * INFRA-081 migration gate: migrations are forward-only. Compared with the
 * base ref (default origin/main), no existing migration may be modified,
 * renamed or deleted, and every new migration must sort after the newest
 * migration already on the base, so replay order never changes.
 *
 * Usage: bun scripts/check-migration-immutability.ts [baseRef]
 */
import { $ } from "bun";

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
