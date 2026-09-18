import { readdirSync, readFileSync, statSync } from "node:fs";
import { join, relative, resolve } from "node:path";

const root = resolve(import.meta.dir, "..");
const roots = [
  join(root, "apps", "api", "src"),
  join(root, "apps", "worker", "src"),
  join(root, "lib"),
];
const deliveryRoutes = join(root, "apps", "api", "src", "files", "routes.ts");
const scanWorker = join(
  root,
  "apps",
  "worker",
  "src",
  "processors",
  "fileScan.ts",
);
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
    // FILE-051: bytes leave storage only through the re-authorizing
    // delivery route — never through a storage-signed download URL.
    if (/createSignedUrls?\s*\(/.test(source)) {
      violations.push(
        `${relative(root, file)} mints a storage-signed download URL`,
      );
    }
    if (/\/delivery\/v1\//.test(source) && file !== deliveryRoutes) {
      violations.push(
        `${
          relative(root, file)
        } builds a delivery link outside the delivery route`,
      );
    }
    if (/\.replaceObject\s*\(/.test(source) && file !== scanWorker) {
      violations.push(
        `${
          relative(root, file)
        } overwrites stored bytes outside the scan worker`,
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
const scanner = readFileSync(
  join(root, "packages", "infrastructure", "src", "fileScanner.ts"),
  "utf8",
);
if (!scanner.includes('redirect: "error"')) {
  violations.push("external scanner client may follow redirects");
}
for (
  const entry of readdirSync(join(root, "packages", "domain", "src"), {
    recursive: true,
  })
) {
  const file = join(root, "packages", "domain", "src", String(entry));
  if (!statSync(file).isFile()) continue;
  if (/\bfetch\s*\(/.test(readFileSync(file, "utf8"))) {
    violations.push(`${relative(root, file)} performs network I/O in domain`);
  }
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
  "FILE-050/051 boundary check passed: no client/handler path construction, direct storage calls, signed download URLs, or stray byte overwrites",
);
