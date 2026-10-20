import { describe, expect, test } from "bun:test";
import {
  apiEnvSchema,
  ConfigError,
  DatabasePoolerModeError,
  databasePoolerProblem,
  describeApiEnv,
  describeWorkerEnv,
  enforceApiFailClosed,
  enforceWorkerFailClosed,
  isSupabasePoolerHost,
  parseEnv,
  resolveDatabaseConnection,
  workerEnvSchema,
} from "../src";

// Synthetic credentials only: never a real project ref or password.
const POOLER_HOST = "aws-1-eu-central-1.pooler.supabase.com";
const TRANSACTION_URL =
  `postgresql://studafy_worker_runtime.synthetic:pw-secret@${POOLER_HOST}:6543/postgres`;
const SESSION_URL =
  `postgresql://studafy_worker_runtime.synthetic:pw-secret@${POOLER_HOST}:5432/postgres`;
const SYNTHETIC_CA =
  "-----BEGIN CERTIFICATE-----\nc3ludGhldGljLWNh\n-----END CERTIFICATE-----";

describe("DATABASE_POOLER_MODE URL rewrite", () => {
  test("session moves a Supabase transaction-pooler URL to 5432, same host and credentials", () => {
    const target = resolveDatabaseConnection(TRANSACTION_URL, "session");
    expect(target.url).toBe(SESSION_URL);
    expect(target.port).toBe(5432);
    expect(target.rewritten).toBe(true);
    expect(target.transactionPooler).toBe(false);
    const parsed = new URL(target.url);
    expect(parsed.hostname).toBe(POOLER_HOST);
    expect(parsed.username).toBe("studafy_worker_runtime.synthetic");
    expect(parsed.password).toBe("pw-secret");
    expect(parsed.pathname).toBe("/postgres");
  });

  test("query parameters and encoded passwords survive the rewrite", () => {
    const url =
      `postgresql://role.ref:p%40ss%2Fw%3Ard@${POOLER_HOST}:6543/postgres?application_name=worker`;
    const target = resolveDatabaseConnection(url, "session");
    expect(target.url).toBe(
      `postgresql://role.ref:p%40ss%2Fw%3Ard@${POOLER_HOST}:5432/postgres?application_name=worker`,
    );
  });

  test("the host match is the Supabase pooler domain, case-insensitive, and nothing else", () => {
    expect(isSupabasePoolerHost(POOLER_HOST)).toBe(true);
    expect(isSupabasePoolerHost("AWS-0-EU-CENTRAL-1.POOLER.SUPABASE.COM"))
      .toBe(true);
    expect(isSupabasePoolerHost("db.ref.supabase.co")).toBe(false);
    expect(isSupabasePoolerHost("pooler.supabase.com.evil.example")).toBe(
      false,
    );
    expect(isSupabasePoolerHost("localhost")).toBe(false);
  });

  test("session leaves session-capable URLs untouched", () => {
    for (
      const url of [
        SESSION_URL,
        "postgresql://postgres:pw@db.ref.supabase.co:5432/postgres",
        "postgresql://postgres:pw@db.ref.supabase.co/postgres",
        "postgresql://postgres:postgres@127.0.0.1:54322/postgres",
        "postgresql://postgres:postgres@localhost/postgres",
      ]
    ) {
      const target = resolveDatabaseConnection(url, "session");
      expect(target.url).toBe(url);
      expect(target.rewritten).toBe(false);
      expect(target.transactionPooler).toBe(false);
    }
  });

  test("session refuses a 6543 URL it cannot move (not a Supabase pooler host)", () => {
    for (
      const url of [
        "postgresql://postgres:pw@db.ref.supabase.co:6543/postgres",
        "postgresql://postgres.pooler-dev:postgres@127.0.0.1:6543/postgres",
      ]
    ) {
      expect(databasePoolerProblem(url, "session")).toMatch(/6543/);
      expect(() => resolveDatabaseConnection(url, "session")).toThrow(
        DatabasePoolerModeError,
      );
      // Transaction mode keeps it as written.
      expect(databasePoolerProblem(url, "transaction")).toBeUndefined();
    }
  });

  test("transaction keeps every URL as written", () => {
    const target = resolveDatabaseConnection(TRANSACTION_URL, "transaction");
    expect(target.url).toBe(TRANSACTION_URL);
    expect(target.port).toBe(6543);
    expect(target.rewritten).toBe(false);
    expect(target.transactionPooler).toBe(true);
    expect(resolveDatabaseConnection(TRANSACTION_URL).url).toBe(
      TRANSACTION_URL,
    );
  });
});

describe("DATABASE_POOLER_MODE config validation", () => {
  const worker = {
    ENVIRONMENT: "development",
    REDIS_URL: "redis://127.0.0.1:6379",
  } as const;

  test("defaults to transaction, and accepts only transaction or session", () => {
    expect(parseEnv(workerEnvSchema, worker).DATABASE_POOLER_MODE).toBe(
      "transaction",
    );
    expect(
      parseEnv(apiEnvSchema, { ENVIRONMENT: "development" })
        .DATABASE_POOLER_MODE,
    ).toBe("transaction");
    expect(() =>
      parseEnv(workerEnvSchema, { ...worker, DATABASE_POOLER_MODE: "Session" })
    ).toThrow(/DATABASE_POOLER_MODE/);
    expect(() =>
      parseEnv(apiEnvSchema, {
        ENVIRONMENT: "development",
        DATABASE_POOLER_MODE: "statement",
      })
    ).toThrow(/DATABASE_POOLER_MODE/);
  });

  test("both schemas refuse session with a 6543 URL that cannot be moved", () => {
    const url = "postgresql://postgres:pw@db.ref.supabase.co:6543/postgres";
    expect(() =>
      parseEnv(workerEnvSchema, {
        ...worker,
        DATABASE_URL: url,
        DATABASE_POOLER_MODE: "session",
      })
    ).toThrow(/DATABASE_POOLER_MODE: session mode/);
    expect(() =>
      parseEnv(apiEnvSchema, {
        ENVIRONMENT: "development",
        DATABASE_URL: url,
        DATABASE_POOLER_MODE: "session",
      })
    ).toThrow(/DATABASE_POOLER_MODE: session mode/);
  });

  test("session with a local URL is accepted and left alone", () => {
    const env = parseEnv(workerEnvSchema, {
      ...worker,
      DATABASE_URL: "postgresql://postgres:postgres@127.0.0.1:54322/postgres",
      DATABASE_POOLER_MODE: "session",
    });
    expect(describeWorkerEnv(env).database_connection).toEqual({
      pooler_mode: "session",
      port: 54322,
      rewritten_from_transaction_pooler: false,
      transaction_pooler: false,
    });
  });

  test("the startup log shows the effective port and mode, never the credentials", () => {
    const api = parseEnv(apiEnvSchema, {
      ENVIRONMENT: "development",
      DATABASE_URL: TRANSACTION_URL,
      DATABASE_POOLER_MODE: "session",
    });
    const described = describeApiEnv(api);
    expect(described.database_url).toBe(
      `postgresql://***@${POOLER_HOST}:5432/postgres`,
    );
    expect(described.database_connection).toEqual({
      pooler_mode: "session",
      port: 5432,
      rewritten_from_transaction_pooler: true,
      transaction_pooler: false,
    });
    const workerEnv = parseEnv(workerEnvSchema, {
      ...worker,
      DATABASE_URL: TRANSACTION_URL,
      DATABASE_POOLER_MODE: "session",
    });
    const both = JSON.stringify([described, describeWorkerEnv(workerEnv)]);
    expect(both).not.toContain("pw-secret");
    expect(both).not.toContain("studafy_worker_runtime");
    expect(both).not.toContain(":6543");
  });
});

describe("production refuses the transaction pooler (worker stall 2026-10-20)", () => {
  const api = {
    ENVIRONMENT: "production",
    DATABASE_URL: TRANSACTION_URL.replace(
      "studafy_worker_runtime",
      "studafy_api_runtime",
    ),
    DATABASE_CA_CERT: SYNTHETIC_CA,
    REDIS_URL: "rediss://:pw@redis.example.com:6380",
    SUPABASE_URL: "https://project.supabase.co",
    API_CURSOR_SIGNING_KEY: "a-development-test-key-with-32-bytes",
    RATE_LIMIT_HMAC_SIGNING_KEY: "a-development-test-key-with-32-bytes",
  } as const;
  const worker = {
    ENVIRONMENT: "production",
    DATABASE_URL: TRANSACTION_URL,
    DATABASE_CA_CERT: SYNTHETIC_CA,
    REDIS_URL: "rediss://:pw@redis.example.com:6380",
  } as const;

  test("a 6543 URL in transaction mode does not start", () => {
    expect(() => enforceApiFailClosed(parseEnv(apiEnvSchema, api))).toThrow(
      ConfigError,
    );
    expect(() => enforceApiFailClosed(parseEnv(apiEnvSchema, api))).toThrow(
      /DATABASE_POOLER_MODE=session/,
    );
    expect(() => enforceWorkerFailClosed(parseEnv(workerEnvSchema, worker)))
      .toThrow(/DATABASE_POOLER_MODE=session/);
  });

  test("the same URL in session mode starts", () => {
    expect(() =>
      enforceApiFailClosed(
        parseEnv(apiEnvSchema, { ...api, DATABASE_POOLER_MODE: "session" }),
      )
    ).not.toThrow();
    expect(() =>
      enforceWorkerFailClosed(
        parseEnv(workerEnvSchema, {
          ...worker,
          DATABASE_POOLER_MODE: "session",
        }),
      )
    ).not.toThrow();
  });

  test("development may still use the transaction pooler", () => {
    expect(() =>
      enforceWorkerFailClosed(
        parseEnv(workerEnvSchema, { ...worker, ENVIRONMENT: "development" }),
      )
    ).not.toThrow();
  });
});
