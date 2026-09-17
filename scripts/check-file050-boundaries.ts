import { readdirSync, readFileSync, statSync } from "node:fs";
import { join, relative, resolve } from "node:path";

const root = resolve(import.meta.dir, "..");
const roots = [join(root, "apps", "api", "src"), join(root, "lib")];
const allowedStorageAdapter = join(
  root,
  "packages",
  "infrastructure",
  "src",
  "privateFileStorage.ts",
);
const violations: string[] = [];

for (const base of roots) {
  for (const entry of readdirSync(base, { recursive: true })) {
    const file = join(base, String(entry));
    if (!statSync(file).isFile() || !/\.(ts|dart)$/.test(file)) continue;
    const source = readFileSync(file, "utf8");
    if (/storage\s*\.\s*from\s*\(/.test(source)) {
      violations.push(
        `${relative(root, file)} calls Supabase Storage directly`,
      );
    }
    if (/quarantine\/v1\//.test(source)) {
      violations.push(`${relative(root, file)} constructs a quarantine path`);
    }
    if (
      /SUPABASE_SERVICE_ROLE_KEY/.test(source) && !file.endsWith("index.ts")
    ) {
      violations.push(
        `${relative(root, file)} references the service-role credential`,
      );
    }
  }
}

const adapter = readFileSync(allowedStorageAdapter, "utf8");
if (
  !adapter.includes("quarantine/v1/${uploadId}/") ||
  !adapter.includes("upsert: false")
) {
  violations.push(
    "private storage adapter lost its server-owned, no-upsert key policy",
  );
}
if (violations.length) {
  console.error(
    `FILE-050 boundary violations (${violations.length}):\n${
      violations.join("\n")
    }`,
  );
  process.exit(1);
}
console.log(
  "FILE-050 boundary check passed: no client/handler path construction or direct storage calls",
);
