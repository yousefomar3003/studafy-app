import { unlink } from "node:fs/promises";

const outputPath = "packages/database/src/database.types.generated.ts";
const checkOnly = Bun.argv.includes("--check");

const process = Bun.spawn([
  "bunx",
  "supabase",
  "gen",
  "types",
  "typescript",
  "--local",
  "--schema",
  "public",
], {
  stdout: "pipe",
  stderr: "pipe",
});

const [generated, stderr, exitCode] = await Promise.all([
  new Response(process.stdout).text(),
  new Response(process.stderr).text(),
  process.exited,
]);

if (exitCode !== 0) {
  throw new Error(`Local Supabase type generation failed: ${stderr.trim()}`);
}

const unformattedContent =
  "// Generated from the local public schema. Do not edit manually.\n" +
  generated.trimEnd() +
  "\n";

const temporaryPath = `/tmp/studafy-db-types-${crypto.randomUUID()}.ts`;
await Bun.write(temporaryPath, unformattedContent);
const formatter = Bun.spawn(["deno", "fmt", temporaryPath], {
  stdout: "pipe",
  stderr: "pipe",
});
const [, formatError, formatExitCode] = await Promise.all([
  new Response(formatter.stdout).text(),
  new Response(formatter.stderr).text(),
  formatter.exited,
]);
if (formatExitCode !== 0) {
  await unlink(temporaryPath);
  throw new Error(
    `Generated database type formatting failed: ${formatError.trim()}`,
  );
}
const content = await Bun.file(temporaryPath).text();
await unlink(temporaryPath);

if (checkOnly) {
  const checkedIn = await Bun.file(outputPath).text();
  if (checkedIn !== content) {
    throw new Error(
      `Database type drift detected. Run: bun scripts/generate-db-types.ts`,
    );
  }
  console.log(
    JSON.stringify({ event: "database_type_drift_check", result: "pass" }),
  );
} else {
  await Bun.write(outputPath, content);
  console.log(
    JSON.stringify({ event: "database_types_generated", output: outputPath }),
  );
}
