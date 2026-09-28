import postgres from "postgres";

const databaseUrl = process.env.DATABASE_URL;
if (!databaseUrl) throw new Error("DATABASE_URL is required.");

const parsed = new URL(databaseUrl);
if (
  !["127.0.0.1", "localhost"].includes(parsed.hostname) ||
  parsed.pathname !== "/postgres"
) {
  throw new Error(
    "Refusing to rehearse recovery outside the local postgres database.",
  );
}

async function run(command: string, args: string[]): Promise<string> {
  const process = Bun.spawn([command, ...args], {
    stdout: "pipe",
    stderr: "pipe",
  });
  const [stdout, stderr, exitCode] = await Promise.all([
    new Response(process.stdout).text(),
    new Response(process.stderr).text(),
    process.exited,
  ]);
  if (exitCode !== 0) {
    throw new Error(`${command} failed: ${stderr.trim()}`);
  }
  return stdout.trim();
}

const containers = (
  await run("docker", [
    "ps",
    "--filter",
    "label=com.supabase.cli.project=studafy",
    "--filter",
    "name=supabase_db_",
    "--format",
    "{{.Names}}",
  ])
).split("\n").filter(Boolean);

if (
  containers.length !== 1 ||
  !/^supabase_db_[a-zA-Z0-9_.-]+$/.test(containers[0]!)
) {
  throw new Error(
    `Expected exactly one local Supabase database container; found ${containers.length}.`,
  );
}

const container = containers[0]!;
const backupPath = "/tmp/studafy-db020-legacy.dump";
const recoveryDatabase = "studafy_db020_recovery";

const countQuery = `
  select jsonb_object_agg(relation_name, row_count order by relation_name)
  from (
    select 'auth.users' relation_name, count(*)::bigint row_count from auth.users
    union all select 'public.schools', count(*) from public.schools
    union all select 'public.memberships', count(*) from public.memberships
    union all select 'public.students', count(*) from public.students
    union all select 'public.classrooms', count(*) from public.classrooms
    union all select 'public.enrollments', count(*) from public.enrollments
    union all select 'public.assignments', count(*) from public.assignments
    union all select 'public.submissions', count(*) from public.submissions
    union all select 'public.grade_results', count(*) from public.grade_results
    union all select 'public.notifications', count(*) from public.notifications
    union all select 'public.audit_events', count(*) from public.audit_events
  ) counts
`;

const source = postgres(databaseUrl, { max: 1 });
let recovery: ReturnType<typeof postgres> | undefined;
try {
  const [sourceFingerprint] = await source.unsafe(countQuery);

  await run("docker", [
    "exec",
    container,
    "pg_dump",
    "--username=postgres",
    "--dbname=postgres",
    "--format=custom",
    "--no-owner",
    "--no-privileges",
    "--schema=auth",
    "--schema=public",
    `--file=${backupPath}`,
  ]);

  const checksumOutput = await run("docker", [
    "exec",
    container,
    "sha256sum",
    backupPath,
  ]);
  const checksum = checksumOutput.split(/\s+/)[0];
  if (!checksum || !/^[0-9a-f]{64}$/.test(checksum)) {
    throw new Error(
      "The logical backup did not produce a valid SHA-256 checksum.",
    );
  }

  await run("docker", [
    "exec",
    container,
    "dropdb",
    "--if-exists",
    "--force",
    "--username=postgres",
    recoveryDatabase,
  ]);
  await run("docker", [
    "exec",
    container,
    "createdb",
    "--username=postgres",
    recoveryDatabase,
  ]);
  await run("docker", [
    "exec",
    container,
    "psql",
    "--username=postgres",
    `--dbname=${recoveryDatabase}`,
    "--set=ON_ERROR_STOP=1",
    "--command=drop schema public cascade",
  ]);
  await run("docker", [
    "exec",
    container,
    "pg_restore",
    "--username=postgres",
    `--dbname=${recoveryDatabase}`,
    "--no-owner",
    "--no-privileges",
    "--exit-on-error",
    backupPath,
  ]);

  const recoveryUrl = new URL(databaseUrl);
  recoveryUrl.pathname = `/${recoveryDatabase}`;
  recovery = postgres(recoveryUrl.toString(), { max: 1 });
  const [recoveryFingerprint] = await recovery.unsafe(countQuery);

  const expected = JSON.stringify(sourceFingerprint?.jsonb_object_agg);
  const actual = JSON.stringify(recoveryFingerprint?.jsonb_object_agg);
  if (expected !== actual) {
    throw new Error(
      "Restored row-count fingerprint differs from the source backup.",
    );
  }

  console.log(JSON.stringify({
    event: "db020_recovery_rehearsal_passed",
    target: "local_disposable",
    checksum_algorithm: "sha256",
    checksum,
    relation_counts: sourceFingerprint?.jsonb_object_agg,
  }));
} finally {
  if (recovery) await recovery.end({ timeout: 5 });
  await source.end({ timeout: 5 });
  await run("docker", [
    "exec",
    container,
    "dropdb",
    "--if-exists",
    "--force",
    "--username=postgres",
    recoveryDatabase,
  ]);
  await run("docker", ["exec", container, "rm", "-f", backupPath]);
}
