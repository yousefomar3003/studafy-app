import postgres from "postgres";

const [path] = Bun.argv.slice(2);
const databaseUrl = process.env.DATABASE_URL;

if (!path?.startsWith("supabase/tests/") || !path.endsWith(".sql")) {
  throw new Error("Expected a SQL file under supabase/tests/.");
}
if (!databaseUrl) throw new Error("DATABASE_URL is required.");

const parsed = new URL(databaseUrl);
if (!["127.0.0.1", "localhost"].includes(parsed.hostname)) {
  throw new Error(
    "Refusing to execute fixture SQL against a non-local database.",
  );
}

const sql = postgres(databaseUrl, { max: 1 });
try {
  const source = await Bun.file(path).text();
  await sql.unsafe(source);
  console.log(JSON.stringify({ event: "local_sql_applied", path }));
} finally {
  await sql.end({ timeout: 5 });
}
