/**
 * Logical backup of Studafy's database (docs/deployment/backups.md).
 *
 * Writes to $BACKUP_OUT (default ./backup-out):
 *   studafy.dump    pg_dump custom format: schema and data of the app's
 *                   schemas, with owners and grants
 *   roles.sql       the custom roles those grants name (roles are
 *                   cluster-wide, so no database dump contains them)
 *   row-counts.tsv  exact row count of every table, taken in the same
 *                   snapshot as the dump; restore-database.sh checks them
 *   manifest.json   when, which migration, which schemas, the dump's sha256
 *
 * The output is plaintext personal data. The caller encrypts it and deletes
 * the plaintext (the workflow uses age); files are created owner-only.
 *
 * Env:
 *   BACKUP_DATABASE_URL  required. A session-mode connection (direct, or the
 *                        Supabase session pooler on :5432): the transaction
 *                        pooler cannot hold the exported snapshot.
 *   PG_DUMP              the pg_dump command (>= the server's major version)
 */
import { chmod, mkdir, rm } from "node:fs/promises";
import { join } from "node:path";
import postgres from "postgres";
import { databaseTls } from "../../packages/database/src/index.ts";

/** Encrypted unless the database is on this machine (packages/database). */
const tls = (url: string) => {
  const ssl = databaseTls(url, process.env.DATABASE_CA_CERT);
  return ssl === undefined ? {} : { ssl };
};

const url = process.env.BACKUP_DATABASE_URL;
if (!url) throw new Error("BACKUP_DATABASE_URL is required.");
const out = process.env.BACKUP_OUT ?? "backup-out";
const pgDump = (process.env.PG_DUMP ?? "pg_dump").split(" ").filter(Boolean);

// The app's schemas, plus Supabase's auth (accounts) and storage (file
// metadata; the bytes are exported by export-storage.ts), and the migration
// history, which says which migrations a restore corresponds to.
const SCHEMAS = ["public", "private", "auth", "storage", "supabase_migrations"];

// pg_dump reads the password from the environment, so it never appears in
// the process list or in a log line.
const target = new URL(url);
const password = decodeURIComponent(target.password);
target.password = "";

await mkdir(out, { recursive: true, mode: 0o700 });
for (
  const name of ["studafy.dump", "roles.sql", "row-counts.tsv", "manifest.json"]
) {
  await rm(join(out, name), { force: true });
}

const sql = postgres(url, {
  ...tls(url),
  max: 1,
  prepare: false,
  onnotice: () => {},
  connection: { application_name: "studafy-backup" },
});

try {
  const counts = await sql.begin(
    "isolation level repeatable read read only",
    async (tx) => {
      const [{ snapshot }] = await tx<{ snapshot: string }[]>`
        select pg_export_snapshot() as snapshot
      `;
      const dump = Bun.spawn(
        [
          ...pgDump,
          "--format=custom",
          "--compress=9",
          "--no-password",
          `--snapshot=${snapshot}`,
          ...SCHEMAS.map((schema) => `--schema=${schema}`),
          target.toString(),
        ],
        {
          stdout: Bun.file(join(out, "studafy.dump")),
          stderr: "inherit",
          env: { ...process.env, PGPASSWORD: password },
        },
      );
      if ((await dump.exited) !== 0) throw new Error("pg_dump failed.");

      // Counted inside the same snapshot the dump read.
      return await tx<{ table: string; rows: string }[]>`
        select t.table_schema || '.' || t.table_name as table,
          (xpath('/row/c/text()', query_to_xml(
            format('select count(*) as c from %I.%I', t.table_schema, t.table_name),
            false, true, '')))[1]::text as rows
        from information_schema.tables t
        where t.table_schema in ${sql(SCHEMAS)} and t.table_type = 'BASE TABLE'
        order by 1
      `;
    },
  );

  // Only custom roles: Supabase's own exist in every Supabase cluster.
  const roles = await sql<{ statement: string }[]>`
    select format(
      'do $r$ begin if not exists (select 1 from pg_roles where rolname = %L) '
        || 'then create role %I nologin; end if; end $r$;',
      rolname, rolname) as statement
    from pg_roles where rolname like 'studafy\_%' order by rolname
  `;
  const [{ migration, server }] = await sql<
    { migration: string; server: string }[]
  >`
    select coalesce(max(version), '') as migration,
      current_setting('server_version') as server
    from supabase_migrations.schema_migrations
  `;

  const dumpFile = Bun.file(join(out, "studafy.dump"));
  const digest = new Bun.CryptoHasher("sha256")
    .update(await dumpFile.arrayBuffer())
    .digest("hex");

  await Bun.write(
    join(out, "row-counts.tsv"),
    counts.map((row) => `${row.table}\t${row.rows}\n`).join(""),
  );
  await Bun.write(
    join(out, "roles.sql"),
    roles.map((row) => `${row.statement}\n`).join(""),
  );
  await Bun.write(
    join(out, "manifest.json"),
    JSON.stringify(
      {
        format: 1,
        createdAt: new Date().toISOString(),
        serverVersion: server,
        latestMigration: migration,
        schemas: SCHEMAS,
        tables: counts.length,
        dumpSha256: digest,
      },
      null,
      2,
    ) + "\n",
  );
  for (
    const name of [
      "studafy.dump",
      "roles.sql",
      "row-counts.tsv",
      "manifest.json",
    ]
  ) {
    await chmod(join(out, name), 0o600);
  }

  // Sizes and counts only: never a row, a name or the connection string.
  console.log(JSON.stringify({
    event: "backup_written",
    latestMigration: migration,
    tables: counts.length,
    rows: counts.reduce((sum, row) => sum + Number(row.rows), 0),
    dumpBytes: dumpFile.size,
  }));
} finally {
  await sql.end({ timeout: 5 });
}
