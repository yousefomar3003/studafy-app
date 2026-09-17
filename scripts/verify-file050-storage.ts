/** Runs the destructive FILE-050 path-binding check against local Supabase only. */
const status = Bun.spawnSync([
  `${import.meta.dir}/../node_modules/.bin/supabase`,
  "status",
  "--output",
  "json",
], { cwd: `${import.meta.dir}/..`, stdout: "pipe", stderr: "pipe" });
if (status.exitCode !== 0) {
  throw new Error("local Supabase is unavailable");
}
const local = JSON.parse(status.stdout.toString()) as Record<string, string>;
const origin = local.API_URL;
const serviceKey = local.SERVICE_ROLE_KEY;
if (!origin?.startsWith("http://127.0.0.1:") || !serviceKey) {
  throw new Error(
    "refusing to run storage verification outside local Supabase",
  );
}
const test = Bun.spawnSync([
  process.execPath,
  "test",
  "apps/api/test/files/storage.integration.test.ts",
], {
  cwd: `${import.meta.dir}/..`,
  env: {
    ...process.env,
    FILE050_STORAGE_INTEGRATION: "true",
    SUPABASE_URL: origin,
    SUPABASE_SERVICE_ROLE_KEY: serviceKey,
  },
  stdout: "inherit",
  stderr: "inherit",
});
process.exit(test.exitCode);
