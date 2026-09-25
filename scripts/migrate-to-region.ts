/**
 * Moves the hosted schema and its seed data to a Supabase project in another
 * region.
 *
 * Why this is a script and not a `pg_dump | psql`: the target project already
 * has its own `auth`, `storage` and `extensions` schemas, and the roles the
 * migrations grant to (`studafy_api_runtime`, `studafy_worker_runtime`) are
 * created by the migrations themselves. Replaying the migration files in
 * order reproduces the schema exactly as CI proves it, which a dump of a
 * live database - carrying whatever drift it has accumulated - does not.
 *
 * Deliberately does NOT copy `auth.users` or `auth.identities`. Those are
 * Supabase-internal, their shape is not ours to depend on, and a half-copied
 * identity is an account nobody can sign into. People sign in with Google
 * again on the new project; because the app now provisions teachers and
 * students on their own, there is nothing for an operator to recreate by
 * hand. Anything keyed by the old user ids is therefore deliberately left
 * behind, which is why this refuses to run against a target that already has
 * tenant data.
 *
 *   bun scripts/migrate-to-region.ts --target "postgresql://..." [--apply]
 *
 * Without --apply it reports what it would do and changes nothing.
 */
import postgres from "postgres";
import { readdir } from "node:fs/promises";

const args = process.argv.slice(2);
const apply = args.includes("--apply");
const targetUrl = args[args.indexOf("--target") + 1];

if (!targetUrl || targetUrl.startsWith("--")) {
  console.error(
    "usage: bun scripts/migrate-to-region.ts --target <url> [--apply]",
  );
  process.exit(2);
}

/** Catalogue rows that are configuration, not anyone's data. */
const SEED_TABLES = ["store_products"] as const;

function readEnv(text: string): Record<string, string> {
  const env: Record<string, string> = {};
  for (const line of text.split("\n")) {
    if (!line.trim() || line.trimStart().startsWith("#")) continue;
    const index = line.indexOf("=");
    if (index < 0) continue;
    env[line.slice(0, index).trim()] = line.slice(index + 1).trim();
  }
  return env;
}

const sourceUrl = readEnv(await Bun.file(".env.hosted").text())["DATABASE_URL"];
if (!sourceUrl) throw new Error("DATABASE_URL missing from .env.hosted");

const source = postgres(sourceUrl, { max: 1, connect_timeout: 20 });
const target = postgres(targetUrl, { max: 1, connect_timeout: 20 });

try {
  const files = (await readdir("supabase/migrations"))
    .filter((name) => name.endsWith(".sql"))
    .sort();

  const applied = new Set(
    (await target<{ version: string }[]>`
      select version from supabase_migrations.schema_migrations
    `.catch(() => [])).map((row) => row.version),
  );
  const pending = files.filter((name) => !applied.has(name.split("_")[0]!));

  console.log(
    `migrations: ${files.length} on disk, ${applied.size} already on target, ${pending.length} pending`,
  );

  // A target that already holds tenant data is not an empty region to move
  // into; continuing would interleave two worlds.
  const occupied = await target<{ count: number }[]>`
    select count(*)::int as count from public.schools
  `.catch(() => [{ count: 0 }]);
  if ((occupied[0]?.count ?? 0) > 0) {
    throw new Error(
      `target already has ${
        occupied[0]!.count
      } school(s); refusing to migrate into it`,
    );
  }

  if (!apply) {
    console.log("\n--- dry run, nothing written. Re-run with --apply ---");
    for (const name of pending.slice(0, 5)) {
      console.log(`  would apply ${name}`);
    }
    if (pending.length > 5) console.log(`  ... and ${pending.length - 5} more`);
    for (const table of SEED_TABLES) {
      const [row] = await source<{ count: number }[]>`
        select count(*)::int as count from ${source(`public.${table}`)}
      `;
      console.log(`  would copy ${row?.count ?? 0} row(s) of ${table}`);
    }
    process.exit(0);
  }

  for (const name of pending) {
    const sqlText = await Bun.file(`supabase/migrations/${name}`).text();
    await target.begin(async (tx) => {
      await tx.unsafe(sqlText);
      await tx`
        insert into supabase_migrations.schema_migrations (version, name)
        values (${name.split("_")[0]!}, ${
        name.replace(/^\d+_/, "").replace(/\.sql$/, "")
      })
        on conflict (version) do nothing
      `;
    });
    console.log(`applied ${name}`);
  }

  for (const table of SEED_TABLES) {
    const rows = await source`select * from ${source(`public.${table}`)}`;
    if (rows.length === 0) continue;
    await target`insert into ${target(`public.${table}`)} ${
      target(rows as never)
    }
                 on conflict do nothing`;
    console.log(`copied ${rows.length} row(s) into ${table}`);
  }

  const [{ count: functions }] = await target<{ count: number }[]>`
    select count(*)::int as count from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'private'
  `;
  const [{ count: policies }] = await target<{ count: number }[]>`
    select count(*)::int as count from pg_policies where schemaname = 'public'
  `;
  console.log(
    `\ntarget now has ${functions} private function(s) and ${policies} RLS policies`,
  );
  console.log(
    "auth.users was deliberately not copied: sign in with Google again on the new project",
  );
} finally {
  await source.end();
  await target.end();
}
