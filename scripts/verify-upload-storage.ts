/**
 * Runs the destructive FILE-050 path-binding check against local Supabase
 * only. Outside CI the stack must be named: SUPABASE_WORKDIR=<stack dir>.
 */
import { localStackOrExit } from "../packages/test-support/src/localStack";

const local = localStackOrExit("FILE-050 storage verification");
console.log(`Supabase: ${local.apiUrl}`);
const test = Bun.spawnSync([
  process.execPath,
  "test",
  "apps/api/test/files/storage.integration.test.ts",
], {
  cwd: `${import.meta.dir}/..`,
  env: {
    ...process.env,
    FILE050_STORAGE_INTEGRATION: "true",
    SUPABASE_URL: local.apiUrl,
    SUPABASE_SERVICE_ROLE_KEY: local.serviceRoleKey,
  },
  stdout: "inherit",
  stderr: "inherit",
});
process.exit(test.exitCode);
