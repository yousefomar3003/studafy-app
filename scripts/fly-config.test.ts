import { describe, expect, test } from "bun:test";
import {
  apiEnvSchema,
  enforceApiFailClosed,
  enforceWorkerFailClosed,
  parseEnv,
  workerEnvSchema,
} from "../packages/config/src/index.ts";

/**
 * The Fly configs (ADR-0035) hold the non-secret production settings. Each
 * must load through the same production validation the processes run at
 * start-up, once the documented secrets are added - so a typo in a
 * fly.*.toml fails here, not on deploy.
 */
async function flyEnv(file: string): Promise<Record<string, string>> {
  const parsed = Bun.TOML.parse(await Bun.file(file).text()) as {
    env?: Record<string, string>;
  };
  return parsed.env ?? {};
}

// Synthetic stand-ins for the secrets set with `fly secrets set`.
const secrets = {
  DATABASE_URL:
    "postgresql://postgres.synthetic:synthetic@aws-0-eu-central-1.pooler.supabase.com:5432/postgres",
  REDIS_URL: "rediss://default:synthetic@redis.synthetic.example:6380",
  SUPABASE_URL: "https://synthetic.supabase.co",
  SUPABASE_SERVICE_ROLE_KEY: "synthetic-service-role-key-000000000000",
  API_CURSOR_SIGNING_KEY: "synthetic-cursor-key-0000000000000000000000",
  RATE_LIMIT_HMAC_SIGNING_KEY: "synthetic-rate-key-000000000000000000000000",
  CLASS_JOIN_CODE_KEY: "synthetic-join-key-0000000000000000000000000",
  FILE051_DELIVERY_SIGNING_KEY: "synthetic-delivery-key-00000000000000000000",
  TURNSTILE_SITE_KEY: "0x4AAAAAAAsynthetic",
  TURNSTILE_SECRET: "0x4AAAAAAAsynthetic-secret",
  SENTRY_DSN: "https://public@o0.ingest.de.sentry.io/0",
  // The scanner vendor is still to be chosen (docs/security/credentials-map.md).
  MALWARE_SCANNER_URL: "https://scanner.synthetic.example",
  MALWARE_SCANNER_API_KEY: "synthetic-scanner-key-0000000000000000",
};

describe("Fly configs pass production validation", () => {
  test("the API", async () => {
    const fly = await flyEnv("fly.api.toml");
    expect(fly.ENVIRONMENT).toBe("production");
    const env = parseEnv(apiEnvSchema, { ...fly, ...secrets });
    expect(() => enforceApiFailClosed(env)).not.toThrow();
    expect(env.LOG_SAMPLE_SUCCESS_RATE).toBe(0.1);
    expect(env.LOG_SAMPLE_ROUTINE_RATE).toBe(0.01);
    // ADR-0034: on only at launch, after the DPA and DPIA.
    expect(env.AI_LESSON_TOOLS_ENABLED).toBe(false);
  });

  test("the worker", async () => {
    const fly = await flyEnv("fly.worker.toml");
    expect(fly.ENVIRONMENT).toBe("production");
    const env = parseEnv(workerEnvSchema, { ...fly, ...secrets });
    expect(() => enforceWorkerFailClosed(env)).not.toThrow();
    expect(env.OPS061_NOTIFICATIONS_ENABLED).toBe(true);
    expect(env.FILE051_SCAN_ENABLED).toBe(true);
  });

  test("the test copy loads in development mode", async () => {
    const api = await flyEnv("fly.test.api.toml");
    expect(api.ENVIRONMENT).toBe("development");
    expect(() =>
      enforceApiFailClosed(parseEnv(apiEnvSchema, { ...api, ...secrets }))
    ).not.toThrow();
    const worker = await flyEnv("fly.test.worker.toml");
    expect(worker.ENVIRONMENT).toBe("development");
    expect(() =>
      enforceWorkerFailClosed(
        parseEnv(workerEnvSchema, { ...worker, ...secrets }),
      )
    ).not.toThrow();
  });

  test("no secret is written into a Fly config", async () => {
    for (
      const file of [
        "fly.api.toml",
        "fly.worker.toml",
        "fly.log-shipper.toml",
        "fly.test.api.toml",
        "fly.test.worker.toml",
      ]
    ) {
      const env = await flyEnv(file);
      for (const key of Object.keys(env)) {
        expect(key).not.toMatch(
          /SECRET|_KEY$|TOKEN|PASSWORD|DSN|DATABASE_URL|REDIS_URL/,
        );
      }
    }
  });
});
