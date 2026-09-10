/**
 * Writes an ignored Flutter dart-define file from `supabase projects api-keys`
 * JSON without echoing key values. Only the public publishable key is accepted.
 *
 * Usage:
 *   supabase projects api-keys --project-ref <ref> --output json |
 *     bun scripts/write-synthetic-mobile-config.ts --project-ref=<ref>
 */
import { chmodSync, writeFileSync } from "node:fs";
import { resolve } from "node:path";

type ProjectKey = { name?: string; type?: string; api_key?: string };

const projectArgument = process.argv.find((argument) =>
  argument.startsWith("--project-ref=")
);
const projectRef = projectArgument?.substring("--project-ref=".length) ?? "";
if (!/^[a-z]{20}$/.test(projectRef)) {
  throw new Error("A valid --project-ref is required");
}

const keys = JSON.parse(await Bun.stdin.text()) as ProjectKey[];
const publishable = keys.find((key) => key.type === "publishable")?.api_key;
if (!publishable?.startsWith("sb_publishable_")) {
  throw new Error("The project did not return a public publishable key");
}

const output = resolve("config/dart-defines.development.json");
writeFileSync(
  output,
  `${
    JSON.stringify(
      {
        APP_ENV: "development",
        SUPABASE_URL: `https://${projectRef}.supabase.co`,
        SUPABASE_PUBLISHABLE_KEY: publishable,
      },
      null,
      2,
    )
  }\n`,
  { mode: 0o600 },
);
chmodSync(output, 0o600);
console.log(
  "Wrote ignored public mobile configuration (values not displayed).",
);
