/**
 * ARC-010 architecture boundary checker (ADR-0011).
 *
 * Enforces the import allowlist matrix on every workspace member's src/ code.
 * Test files are not enforced (they may import bun:test); production code is.
 * Exit code 1 on any violation, so CI fails closed on boundary drift.
 *
 * Usage: bun scripts/check-bounds.ts [--root <repo root>]
 */
import { readdirSync, readFileSync, statSync } from "node:fs";
import { join, relative, resolve } from "node:path";

const rootArg = process.argv.find((arg) => arg.startsWith("--root"));
const root = resolve(
  rootArg ? rootArg.slice("--root=".length) || process.cwd() : process.cwd(),
);

/** Permitted external imports per member. node:* builtins are always allowed. */
const ALLOWED: Record<string, string[]> = {
  "@studafy/domain": [],
  "@studafy/contracts": ["zod"],
  "@studafy/config": ["zod", "@studafy/contracts"],
  "@studafy/observability": ["@studafy/contracts"],
  "@studafy/database": [
    "postgres",
    "@studafy/config",
    "@studafy/observability",
  ],
  "@studafy/infrastructure": [
    "@supabase/supabase-js",
    "ioredis",
    "bullmq",
    "@apple/app-store-server-library",
    "google-auth-library",
    "googleapis",
    "@studafy/config",
    "@studafy/domain",
    "@studafy/observability",
  ],
  "@studafy/test-support": [],
  "@studafy/api": [
    "hono",
    "zod",
    "@studafy/config",
    "@studafy/contracts",
    "@studafy/database",
    "@studafy/domain",
    "@studafy/infrastructure",
    "@studafy/observability",
    "@studafy/test-support",
  ],
  "@studafy/worker": [
    "bullmq",
    "@studafy/config",
    "@studafy/contracts",
    "@studafy/database",
    "@studafy/domain",
    "@studafy/infrastructure",
    "@studafy/observability",
    "@studafy/test-support",
  ],
};

interface Member {
  name: string;
  dir: string;
}

function readJson(path: string): Record<string, unknown> {
  return JSON.parse(readFileSync(path, "utf8")) as Record<string, unknown>;
}

function discoverMembers(): Member[] {
  const rootManifest = readJson(join(root, "package.json"));
  const patterns = (rootManifest["workspaces"] as string[] | undefined) ?? [];
  const members: Member[] = [];
  const globDirs = patterns
    .map((pattern) => pattern.replace(/\*$/, ""))
    .map((dir) => join(root, dir));
  for (const globDir of globDirs) {
    for (const entry of readdirSync(globDir)) {
      const memberDir = join(globDir, entry);
      const manifestPath = join(memberDir, "package.json");
      if (!statSync(manifestPath).isFile()) continue;
      const name = readJson(manifestPath)["name"];
      if (typeof name !== "string") continue;
      members.push({ name, dir: memberDir });
    }
  }
  return members;
}

function listSourceFiles(dir: string): string[] {
  const srcDir = join(dir, "src");
  let entries: string[];
  try {
    entries = readdirSync(srcDir, { recursive: true });
  } catch {
    return [];
  }
  return entries
    .map((entry) => join(srcDir, String(entry)))
    .filter((path) => path.endsWith(".ts") && statSync(path).isFile());
}

const IMPORT_PATTERNS: RegExp[] = [
  /\bimport\s[^;]*?\bfrom\s*["']([^"']+)["']/g,
  /\bimport\s*["']([^"']+)["']/g,
  /\bexport\s[^;]*?\bfrom\s*["']([^"']+)["']/g,
  /\bimport\s*\(\s*["']([^"']+)["']\s*\)/g,
];

function extractImports(source: string): string[] {
  const specifiers = new Set<string>();
  for (const pattern of IMPORT_PATTERNS) {
    for (const match of source.matchAll(pattern)) {
      const specifier = match[1];
      if (specifier) specifiers.add(specifier);
    }
  }
  return [...specifiers];
}

function packageName(specifier: string): string | null {
  if (specifier.startsWith(".") || specifier.startsWith("/")) return null;
  if (specifier.startsWith("node:")) return "node:";
  if (specifier.startsWith("bun:")) return "bun:";
  if (specifier.startsWith("data:") || specifier.startsWith("http")) {
    return "(remote)";
  }
  const segments = specifier.split("/");
  return specifier.startsWith("@")
    ? segments.slice(0, 2).join("/")
    : (segments[0] ?? specifier);
}

const members = discoverMembers();
const knownNames = new Set(members.map((member) => member.name));
const unknownMembers = members.filter(
  (member) => !Object.prototype.hasOwnProperty.call(ALLOWED, member.name),
);

const violations: string[] = [];

for (const member of unknownMembers) {
  violations.push(
    `${member.name}: no boundary rule declared in scripts/check-bounds.ts (add ALLOWED entry or remove the member)`,
  );
}

for (const member of members) {
  const allowed = ALLOWED[member.name];
  if (!allowed) continue;
  for (const file of listSourceFiles(member.dir)) {
    const source = readFileSync(file, "utf8");
    for (const specifier of extractImports(source)) {
      const pkg = packageName(specifier);
      if (pkg === null || pkg === "node:" || pkg === "bun:") continue;
      if (allowed.includes(pkg)) continue;
      if (pkg === "(remote)") {
        violations.push(
          `${member.name} ${
            relative(root, file)
          }: remote import "${specifier}" — floating runtime imports are forbidden`,
        );
        continue;
      }
      if (knownNames.has(pkg)) {
        violations.push(
          `${member.name} ${
            relative(root, file)
          }: workspace import "${pkg}" is not allowed for this member`,
        );
      } else {
        violations.push(
          `${member.name} ${
            relative(root, file)
          }: external import "${pkg}" is not allowed for this member`,
        );
      }
    }
  }
}

if (violations.length > 0) {
  console.error(
    `architecture boundary violations (${violations.length}):\n${
      violations.join("\n")
    }`,
  );
  process.exit(1);
}

const enforced = members.filter((member) =>
  Object.prototype.hasOwnProperty.call(ALLOWED, member.name)
);
console.log(
  `boundary check passed: ${enforced.length} members, ${
    enforced
      .map((member) => listSourceFiles(member.dir).length)
      .reduce((a, b) => a + b, 0)
  } source files, 0 violations`,
);
