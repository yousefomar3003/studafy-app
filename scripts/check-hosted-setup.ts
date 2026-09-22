import { parseEnv } from "node:util";
import { validateHostedEnvironment } from "./start-hosted-api";

const env = parseEnv(await Bun.file(".env.hosted").text());
const mobile = await Bun.file("config/dart-defines.development.json")
  .json() as Record<string, unknown>;
const project = new URL(env.SUPABASE_URL ?? "");
if (
  !/^[a-z0-9]+\.supabase\.co$/.test(project.hostname) ||
  project.protocol !== "https:"
) {
  throw new Error("Expected the hosted Supabase HTTPS project URL.");
}
async function probe(
  name: string,
  run: () => Promise<Record<string, unknown>>,
) {
  try {
    console.log(JSON.stringify({ check: name, ...await run() }));
  } catch {
    console.log(
      JSON.stringify({
        check: name,
        status: "unreachable_or_invalid_response",
      }),
    );
  }
}
await Promise.all([
  probe("turnstile_secret", async () => {
    const response = await fetch(
      "https://challenges.cloudflare.com/turnstile/v0/siteverify",
      {
        method: "POST",
        signal: AbortSignal.timeout(10000),
        body: new URLSearchParams({
          secret: env.TURNSTILE_SECRET ?? "",
          response: "XXXX.DUMMY.TOKEN.XXXX",
        }),
      },
    );
    const body = await response.json() as {
      success?: boolean;
      "error-codes"?: string[];
    };
    return {
      http: response.status,
      acceptedSecret: body.success === false &&
        body["error-codes"]?.includes("invalid-input-response") &&
        !body["error-codes"]?.includes("invalid-input-secret"),
    };
  }),
  probe("stripe_sandbox", async () => {
    if (!env.STRIPE_SECRET_KEY?.startsWith("sk_test_")) {
      return { status: "missing_test_key" };
    }
    const response = await fetch("https://api.stripe.com/v1/balance", {
      signal: AbortSignal.timeout(10000),
      headers: { Authorization: `Bearer ${env.STRIPE_SECRET_KEY}` },
    });
    const body = await response.json() as { livemode?: boolean };
    return { http: response.status, sandbox: body.livemode === false };
  }),
  probe("supabase_providers", async () => {
    if (mobile.SUPABASE_URL !== project.origin) {
      return { status: "mobile_project_mismatch" };
    }
    const response = await fetch(new URL("/auth/v1/settings", project), {
      signal: AbortSignal.timeout(10000),
      headers: { apikey: String(mobile.SUPABASE_PUBLISHABLE_KEY ?? "") },
    });
    const body = await response.json() as {
      external?: Record<string, boolean>;
    };
    return {
      http: response.status,
      google: body.external?.google === true,
      microsoft: body.external?.azure === true,
      apple: body.external?.apple === true,
    };
  }),
  probe("supabase_server_key", async () => {
    const response = await fetch(
      new URL("/rest/v1/profiles?select=id&limit=0", project),
      {
        signal: AbortSignal.timeout(10000),
        headers: { apikey: env.SUPABASE_SERVICE_ROLE_KEY ?? "" },
      },
    );
    await response.body?.cancel();
    return { http: response.status };
  }),
]);
let databaseConfigured = false;
try {
  validateHostedEnvironment(env);
  databaseConfigured = true;
} catch { /* no credentials in output */ }
console.log(JSON.stringify({
  check: "runtime_setup",
  databaseConfigured,
  turnstileEnabled: env.TURNSTILE_ENABLED === "true",
  turnstileHostnamesConfigured: Boolean(env.TURNSTILE_HOSTNAMES?.trim()),
  stripeCheckoutImplemented: false,
}));
