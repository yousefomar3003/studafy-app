import { describe, expect, test } from "bun:test";
import { readdirSync } from "node:fs";
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
 * fly.*.toml fails here, not on deploy. The production rules the launch plan
 * lists (A6, C11, D3) are pinned here too, so changing one is a reviewed
 * change to this file as well as to the config.
 */
type FlyConfig = {
  app?: string;
  primary_region?: string;
  build?: { dockerfile?: string; image?: string };
  env?: Record<string, string>;
  http_service?: {
    internal_port?: number;
    force_https?: boolean;
    min_machines_running?: number;
    checks?: { method?: string; path?: string }[];
  };
  services?: unknown[];
  checks?: Record<
    string,
    { type?: string; port?: number; method?: string; path?: string }
  >;
  restart?: { policy?: string }[];
  vm?: Record<string, unknown>[];
};

async function flyConfig(file: string): Promise<FlyConfig> {
  return Bun.TOML.parse(await Bun.file(file).text()) as FlyConfig;
}

async function flyEnv(file: string): Promise<Record<string, string>> {
  return (await flyConfig(file)).env ?? {};
}

// Synthetic stand-ins for the secrets set with `fly secrets import`.
const secrets = {
  DATABASE_URL:
    "postgresql://studafy_api_runtime.synthetic:synthetic@aws-0-eu-central-1.pooler.supabase.com:5432/postgres",
  // The Supabase root CA; production refuses to start without it, so the
  // database certificate is verified, not only encrypted (go-live audit).
  DATABASE_CA_CERT:
    "-----BEGIN CERTIFICATE-----\nc3ludGhldGljLWNh\n-----END CERTIFICATE-----",
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
  // The scanner's URL is configuration (fly.worker.toml); only its key is a
  // secret, the same value as the scanner's SCANNER_API_KEY.
  MALWARE_SCANNER_API_KEY: "synthetic-scanner-key-0000000000000000",
  TELEGRAM_BOT_TOKEN: "000000000:synthetic-telegram-bot-token",
  TELEGRAM_CHAT_ID: "-1000000000000",
};

/** The production apps, each in Frankfurt next to the database. */
const PRODUCTION = {
  api: { file: "fly.api.toml", app: "studafy-api" },
  worker: { file: "fly.worker.toml", app: "studafy-worker" },
  scanner: { file: "fly.scanner.toml", app: "studafy-scanner" },
} as const;

describe("Fly configs pass production validation", () => {
  test("the API", async () => {
    const fly = await flyEnv("fly.api.toml");
    expect(fly.ENVIRONMENT).toBe("production");
    const env = parseEnv(apiEnvSchema, { ...fly, ...secrets });
    expect(() => enforceApiFailClosed(env)).not.toThrow();
    expect(env.LOG_SAMPLE_SUCCESS_RATE).toBe(0.1);
    expect(env.LOG_SAMPLE_ROUTINE_RATE).toBe(0.01);
    // DL-062: the AI study tools are on from launch.
    expect(env.AI_LESSON_TOOLS_ENABLED).toBe(true);
    // DL-063: messaging launches, with one report reviewer.
    expect(env.MESSAGING_ENABLED).toBe(true);
    // Security audit 2026-10-08: never X-Forwarded-For in production.
    expect(env.CLIENT_IP_SOURCE).toBe("cloudflare");
    // Launch plan 2.2: AI calls need longer than the 10 s default.
    expect(env.API_REQUEST_TIMEOUT_MS).toBe(20_000);
    expect(env.RATE_LIMIT_ENABLED).toBe(true);
  });

  test("the worker", async () => {
    const fly = await flyEnv("fly.worker.toml");
    expect(fly.ENVIRONMENT).toBe("production");
    const env = parseEnv(workerEnvSchema, { ...fly, ...secrets });
    expect(() => enforceWorkerFailClosed(env)).not.toThrow();
    expect(env.OPS061_NOTIFICATIONS_ENABLED).toBe(true);
    expect(env.FILE051_SCAN_ENABLED).toBe(true);
    // Launch plan 2.1: account deletion and data export must complete.
    expect(env.ACCOUNT_DELETION_EXECUTOR_ENABLED).toBe(true);
    expect(env.DATA_EXPORT_EXECUTOR_ENABLED).toBe(true);
    // DL-062: AI on from launch; notebooks are written by the worker.
    expect(env.AI_LESSON_TOOLS_ENABLED).toBe(true);
    // DPIA D7: a filed safety report always reaches a reviewer.
    expect(env.REPORT_ALERTS_ENABLED).toBe(true);
  });

  test("the production worker refuses report alerts without Telegram", async () => {
    const fly = await flyEnv("fly.worker.toml");
    const { TELEGRAM_BOT_TOKEN: _, ...withoutBot } = secrets;
    expect(() => parseEnv(workerEnvSchema, { ...fly, ...withoutBot }))
      .toThrow(/REPORT_ALERTS_ENABLED/);
  });

  test("production refuses client addresses from X-Forwarded-For", async () => {
    const fly = await flyEnv("fly.api.toml");
    const env = parseEnv(apiEnvSchema, {
      ...fly,
      ...secrets,
      CLIENT_IP_SOURCE: "forwarded",
    });
    expect(() => enforceApiFailClosed(env)).toThrow(/X-Forwarded-For/);
  });

  test("production refuses a database URL that turns TLS off", async () => {
    const fly = await flyEnv("fly.api.toml");
    const env = parseEnv(apiEnvSchema, {
      ...fly,
      ...secrets,
      DATABASE_URL: `${secrets.DATABASE_URL}?sslmode=disable`,
    });
    expect(() => enforceApiFailClosed(env)).toThrow(/TLS/);
    const worker = await flyEnv("fly.worker.toml");
    expect(() =>
      enforceWorkerFailClosed(
        parseEnv(workerEnvSchema, {
          ...worker,
          ...secrets,
          DATABASE_URL: `${secrets.DATABASE_URL}?sslmode=disable`,
        }),
      )
    ).toThrow(/TLS/);
  });

  test("production refuses a database whose certificate is not verified", async () => {
    const api = await flyEnv("fly.api.toml");
    const worker = await flyEnv("fly.worker.toml");
    const { DATABASE_CA_CERT: _ca, ...withoutCa } = secrets;
    expect(() =>
      enforceApiFailClosed(parseEnv(apiEnvSchema, { ...api, ...withoutCa }))
    ).toThrow(/DATABASE_CA_CERT/);
    expect(() =>
      enforceWorkerFailClosed(
        parseEnv(workerEnvSchema, { ...worker, ...withoutCa }),
      )
    ).toThrow(/DATABASE_CA_CERT/);
  });

  test("production refuses a privileged database login", async () => {
    const fly = await flyEnv("fly.api.toml");
    for (
      const user of ["postgres.synthetic", "postgres", "supabase_admin"]
    ) {
      const env = parseEnv(apiEnvSchema, {
        ...fly,
        ...secrets,
        DATABASE_URL:
          `postgresql://${user}:x@aws-0-eu-central-1.pooler.supabase.com:5432/postgres`,
      });
      expect(() => enforceApiFailClosed(env)).toThrow(/runtime role/);
    }
    const worker = await flyEnv("fly.worker.toml");
    expect(() =>
      enforceWorkerFailClosed(
        parseEnv(workerEnvSchema, {
          ...worker,
          ...secrets,
          DATABASE_URL:
            "postgresql://postgres.synthetic:x@aws-0-eu-central-1.pooler.supabase.com:5432/postgres",
        }),
      )
    ).toThrow(/runtime role/);
  });

  test("production refuses plaintext or passwordless Redis", async () => {
    const api = await flyEnv("fly.api.toml");
    const worker = await flyEnv("fly.worker.toml");
    for (
      const redis of [
        "redis://default:synthetic@redis.synthetic.example:6379",
        "rediss://redis.synthetic.example:6380",
      ]
    ) {
      expect(() =>
        enforceApiFailClosed(
          parseEnv(apiEnvSchema, { ...api, ...secrets, REDIS_URL: redis }),
        )
      ).toThrow(/Redis posture/);
      expect(() =>
        enforceWorkerFailClosed(
          parseEnv(workerEnvSchema, {
            ...worker,
            ...secrets,
            REDIS_URL: redis,
          }),
        )
      ).toThrow(/Redis posture/);
    }
  });

  test("the production worker refuses to scan without the scanner key", async () => {
    const fly = await flyEnv("fly.worker.toml");
    const { MALWARE_SCANNER_API_KEY: _key, ...withoutKey } = secrets;
    expect(() => parseEnv(workerEnvSchema, { ...fly, ...withoutKey })).toThrow(
      /MALWARE_SCANNER_API_KEY/,
    );
  });

  test("the test copy loads in development mode", async () => {
    const api = await flyEnv("fly.test.api.toml");
    expect(api.ENVIRONMENT).toBe("development");
    // *.fly.dev has no Cloudflare in front: Fly's own header only.
    expect(api.CLIENT_IP_SOURCE).toBe("fly");
    // Messaging is on in the test copy too, as in production (DL-063).
    expect(api.MESSAGING_ENABLED).toBe("true");
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
    const files = readdirSync(".").filter((name) =>
      /^fly\..*\.toml$/.test(name)
    );
    // Every Fly config in the repository is checked, including new ones.
    expect(files).toEqual(
      expect.arrayContaining([
        "fly.api.toml",
        "fly.worker.toml",
        "fly.scanner.toml",
        "fly.log-shipper.toml",
        "fly.test.api.toml",
        "fly.test.worker.toml",
        "fly.scanner.test.toml",
      ]),
    );
    for (const file of files) {
      const env = await flyEnv(file);
      for (const key of Object.keys(env)) {
        expect(key).not.toMatch(
          /SECRET|_KEY$|TOKEN|PASSWORD|DSN|DATABASE_URL|REDIS_URL/,
        );
      }
    }
  });

  test("the log shipper image is pinned to a digest", async () => {
    const parsed = Bun.TOML.parse(
      await Bun.file("fly.log-shipper.toml").text(),
    ) as { build?: { image?: string } };
    // A floating tag would let a new upstream image change where logs go
    // without review (observability review, October 2026).
    expect(parsed.build?.image).toMatch(
      /^ghcr\.io\/superfly\/fly-log-shipper:[\w.-]+@sha256:[0-9a-f]{64}$/,
    );
  });
});

describe("production Fly apps (launch plan A6, C11)", () => {
  test("app names and region", async () => {
    for (const { file, app } of Object.values(PRODUCTION)) {
      const config = await flyConfig(file);
      expect(config.app).toBe(app);
      expect(config.primary_region).toBe("fra");
      // Production never points at a test app or a *.fly.dev address.
      for (const value of Object.values(config.env ?? {})) {
        expect(value).not.toMatch(/-test\b|\.fly\.dev/);
      }
    }
  });

  test("the API: production mode, public over HTTPS, health-checked", async () => {
    const config = await flyConfig(PRODUCTION.api.file);
    const env = config.env ?? {};
    expect(env.ENVIRONMENT).toBe("production");
    expect(config.build?.dockerfile).toBe("apps/api/Dockerfile");
    expect(config.http_service?.internal_port).toBe(Number(env.API_PORT));
    expect(config.http_service?.force_https).toBe(true);
    expect(config.http_service?.min_machines_running).toBeGreaterThanOrEqual(
      1,
    );
    expect(config.http_service?.checks).toContainEqual(
      expect.objectContaining({ method: "GET", path: "/healthz" }),
    );
    expect(env.CLIENT_IP_SOURCE).toBe("cloudflare");
    expect(env.API_REQUEST_TIMEOUT_MS).toBe("20000");
    // Launch plan C8 / 4.2: switched on only once api.studafy.com is
    // proxied by Cloudflare; on before that, every request is refused.
    expect(env.ORIGIN_REQUIRE_CLOUDFLARE).toBe("false");
    // Real Turnstile keys (C9) are checked against the API's own host,
    // where the widget page (/auth/bot-check) is served - the same host the
    // delivery links use.
    expect(env.TURNSTILE_ENABLED).toBe("true");
    expect(env.TURNSTILE_HOSTNAMES).toBe("api.studafy.com");
    expect(env.FILE051_DELIVERY_PUBLIC_BASE_URL).toBe(
      "https://api.studafy.com",
    );
    expect(env.AI_LESSON_TOOLS_ENABLED).toBe("true");
    // DL-063: messaging launches; the switch stays to turn it off fast.
    expect(env.MESSAGING_ENABLED).toBe("true");
  });

  test("the worker: production mode, executors on, retention purge off", async () => {
    const config = await flyConfig(PRODUCTION.worker.file);
    const env = config.env ?? {};
    expect(env.ENVIRONMENT).toBe("production");
    expect(config.build?.dockerfile).toBe("apps/worker/Dockerfile");
    // The worker serves no HTTP.
    expect(config.http_service).toBeUndefined();
    expect(config.services).toBeUndefined();
    expect(env.ACCOUNT_DELETION_EXECUTOR_ENABLED).toBe("true");
    expect(env.DATA_EXPORT_EXECUTOR_ENABLED).toBe("true");
    expect(env.OPS061_NOTIFICATIONS_ENABLED).toBe("true");
    expect(env.FILE051_SCAN_ENABLED).toBe("true");
    expect(env.QUEUE_ALERTS_ENABLED).toBe("true");
    // Launch plan D3: off until the store release carrying consent version
    // 2026-10-14 is live. Turning it on changes this line, with the owner's
    // "go".
    expect(env.RETENTION_SCHEDULE_ENABLED).toBe("false");
    const parsed = parseEnv(workerEnvSchema, { ...env, ...secrets });
    expect(parsed.RETENTION_SCHEDULE_ENABLED).toBe(false);
    // DL-065: no Google Meet creation at launch; the switch stays unset.
    expect(env.MEETINGS_PROCESSOR_ENABLED).toBeUndefined();
  });

  test("the worker scans through the private production scanner", async () => {
    const worker = await flyEnv(PRODUCTION.worker.file);
    const scanner = await flyConfig(PRODUCTION.scanner.file);
    expect(worker.MALWARE_SCANNER_URL).toBe(
      "http://studafy-scanner.internal:8080/scan",
    );
    const url = new URL(worker.MALWARE_SCANNER_URL ?? "");
    // Fly's private network: <app>.internal, never a public address.
    expect(url.hostname).toBe(`${scanner.app}.internal`);
    expect(url.port).toBe(String(scanner.env?.PORT));
    expect(url.pathname).toBe("/scan");
  });

  test("the scanner is private: no public service, no http_service", async () => {
    for (const file of [PRODUCTION.scanner.file, "fly.scanner.test.toml"]) {
      const config = await flyConfig(file);
      // Either section would give the app a public address on fly deploy.
      expect(config.http_service).toBeUndefined();
      expect(config.services).toBeUndefined();
      const text = await Bun.file(file).text();
      expect(text).not.toMatch(/^\s*\[\[?(services|http_service)\b/m);
    }
  });

  test("the scanner restarts itself and is health-checked", async () => {
    const config = await flyConfig(PRODUCTION.scanner.file);
    expect(config.build?.dockerfile).toBe("infra/scanner/Dockerfile");
    expect(config.restart).toContainEqual({ policy: "always" });
    expect(config.checks?.healthz).toMatchObject({
      type: "http",
      port: Number(config.env?.PORT),
      path: "/healthz",
    });
    // clamd holds the signature database in memory.
    expect(config.vm).toContainEqual(
      expect.objectContaining({ memory: "2gb" }),
    );
  });

  test("the production scanner is the test scanner under its own name", async () => {
    const { app, ...production } = await flyConfig(PRODUCTION.scanner.file);
    const { app: testApp, ...testCopy } = await flyConfig(
      "fly.scanner.test.toml",
    );
    expect(app).toBe("studafy-scanner");
    expect(testApp).toBe("studafy-scanner-test");
    expect(production).toEqual(testCopy);
  });
});
