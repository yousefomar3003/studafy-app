/**
 * AI-072 (ADR-0026) removal probe for an explicitly named synthetic Supabase
 * project. After the owner has deleted the retired AI Edge Functions from the
 * project, both slugs must be absent: the gateway answers 404 and no function
 * code runs. No user is created and nothing is mutated.
 *
 * The publishable key is read from stdin (the `supabase projects api-keys
 * --output json` array). Key values are never printed or written to disk.
 */
type ProjectKey = { type?: string; api_key?: string };

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
  throw new Error("Synthetic project publishable key is unavailable");
}

const origin = `https://${projectRef}.supabase.co`;
const retiredSlugs = ["study-coach", "propose-paper-grade"];
const results = [];
for (const slug of retiredSlugs) {
  const response = await fetch(`${origin}/functions/v1/${slug}`, {
    method: "POST",
    headers: { apikey: publishable, "Content-Type": "application/json" },
    body: JSON.stringify({ probe: "ai072-removal" }),
  });
  await response.body?.cancel();
  results.push({
    slug,
    status: response.status,
    absent: response.status === 404,
  });
}

const passed = results.every((result) => result.absent);
console.log(JSON.stringify({
  timestamp: new Date().toISOString(),
  project_ref: projectRef,
  results,
  passed,
}));
if (!passed) process.exitCode = 1;
