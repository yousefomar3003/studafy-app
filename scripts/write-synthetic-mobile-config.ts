/**
 * Writes an ignored Flutter dart-define file without echoing key values.
 * Only a public publishable key is ever accepted.
 *
 * Two modes:
 *
 *   Local stack (what you want for simulator testing):
 *     bun scripts/write-synthetic-mobile-config.ts --local
 *
 *   Remote project:
 *     supabase projects api-keys --project-ref <ref> --output json |
 *       bun scripts/write-synthetic-mobile-config.ts --project-ref=<ref>
 *
 * AUTH-030 made STUDAFY_API_URL mandatory for any non-synthetic build: the
 * API is what verifies tokens and resolves roles, so a remote build without
 * one has nothing to derive authority from and refuses to start.
 */
import { chmodSync, writeFileSync } from "node:fs";
import { spawnSync } from "node:child_process";
import { resolve } from "node:path";

type ProjectKey = { name?: string; type?: string; api_key?: string };

const local = process.argv.includes("--local");
const projectArgument = process.argv.find((argument) =>
  argument.startsWith("--project-ref=")
);
const apiArgument = process.argv.find((argument) =>
  argument.startsWith("--api-url=")
);

/** Reads the running local stack's values rather than hard-coding them. */
function readLocalStack(): { supabaseUrl: string; publishable: string } {
  const status = spawnSync("bunx", ["supabase", "status", "-o", "env"], {
    encoding: "utf8",
  });
  if (status.status !== 0) {
    throw new Error(
      "Could not read the local stack. Run `bunx supabase start` first.",
    );
  }
  // `status -o env` also prints a non-assignment "Stopped services" line.
  const values = new Map<string, string>();
  for (const line of status.stdout.split("\n")) {
    const match = /^([A-Z_]+)="(.*)"$/.exec(line.trim());
    if (match?.[1] && match[2] !== undefined) values.set(match[1], match[2]);
  }
  const supabaseUrl = values.get("API_URL");
  const publishable = values.get("PUBLISHABLE_KEY");
  if (!supabaseUrl || !publishable) {
    throw new Error("The local stack reported no API URL or publishable key");
  }
  return { supabaseUrl, publishable };
}

function readRemoteProject(): { supabaseUrl: string; publishable: string } {
  const projectRef = projectArgument?.substring("--project-ref=".length) ?? "";
  if (!/^[a-z]{20}$/.test(projectRef)) {
    throw new Error("A valid --project-ref is required (or pass --local)");
  }
  const keys = JSON.parse(
    require("node:fs").readFileSync(0, "utf8"),
  ) as ProjectKey[];
  const publishable = keys.find((key) => key.type === "publishable")?.api_key;
  if (!publishable) {
    throw new Error("The project did not return a publishable key");
  }
  return {
    supabaseUrl: `https://${projectRef}.supabase.co`,
    publishable,
  };
}

const { supabaseUrl, publishable } = local
  ? readLocalStack()
  : readRemoteProject();

// Preserved control: a secret or service-role key must never reach a client
// bundle, so anything that is not a publishable key is refused outright.
if (!publishable.startsWith("sb_publishable_")) {
  throw new Error("Refusing to write a key that is not sb_publishable_*");
}

const apiUrl = apiArgument?.substring("--api-url=".length) ??
  (local ? "http://127.0.0.1:8080" : "");
if (!apiUrl) {
  throw new Error(
    "Pass --api-url=<base url>: AUTH-030 requires STUDAFY_API_URL because " +
      "the API, not the client, decides authority.",
  );
}

const output = resolve("config/dart-defines.development.json");
writeFileSync(
  output,
  `${
    JSON.stringify(
      {
        APP_ENV: "development",
        SUPABASE_URL: supabaseUrl,
        SUPABASE_PUBLISHABLE_KEY: publishable,
        STUDAFY_API_URL: apiUrl,
      },
      null,
      2,
    )
  }\n`,
  { mode: 0o600 },
);
chmodSync(output, 0o600);
console.log(
  `Wrote ignored mobile configuration for the ${
    local ? "local stack" : "remote project"
  } (values not displayed).`,
);
