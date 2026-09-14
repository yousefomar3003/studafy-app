import { describe, expect, test } from "bun:test";
import {
  apiEnvSchema,
  authIssuer,
  authJwksUrl,
  ConfigError,
  describeApiEnv,
  describeWorkerEnv,
  enforceApiFailClosed,
  parseEnv,
  redactUrl,
  workerEnvSchema,
} from "../src";

describe("parseEnv", () => {
  test("accepts a valid API environment with defaults", () => {
    const env = parseEnv(apiEnvSchema, {
      ENVIRONMENT: "development",
      DATABASE_URL: "postgresql://postgres:secret@127.0.0.1:54322/postgres",
      REDIS_URL: "redis://127.0.0.1:6379",
    });
    expect(env.API_PORT).toBe(8080);
    expect(env.LOG_LEVEL).toBe("info");
  });

  test("rejects an unknown environment with a stable error", () => {
    expect(() => parseEnv(apiEnvSchema, { ENVIRONMENT: "qa" })).toThrow(
      ConfigError,
    );
  });

  test("rejects a malformed DATABASE_URL", () => {
    expect(() =>
      parseEnv(apiEnvSchema, {
        ENVIRONMENT: "development",
        DATABASE_URL: "not-a-url",
      })
    ).toThrow(ConfigError);
  });

  test("worker env requires REDIS_URL", () => {
    expect(() => parseEnv(workerEnvSchema, { ENVIRONMENT: "development" }))
      .toThrow(ConfigError);
    const env = parseEnv(workerEnvSchema, {
      ENVIRONMENT: "development",
      REDIS_URL: "redis://127.0.0.1:6379",
    });
    expect(env.LOG_LEVEL).toBe("info");
  });
});

describe("production fail-closed", () => {
  test("production without DATABASE_URL/REDIS_URL refuses to start", () => {
    const env = parseEnv(apiEnvSchema, { ENVIRONMENT: "production" });
    expect(() => enforceApiFailClosed(env)).toThrow(ConfigError);
  });

  test("production without SUPABASE_URL refuses to start", () => {
    // AUTH-030: with no JWKS source the API cannot verify a token, and an API
    // that cannot authenticate must not serve rather than serve unauthorized.
    const env = parseEnv(apiEnvSchema, {
      ENVIRONMENT: "production",
      DATABASE_URL: "postgresql://u:p@example.com:5432/db",
      REDIS_URL: "rediss://example.com:6380",
    });
    expect(() => enforceApiFailClosed(env)).toThrow(ConfigError);
  });

  test("production with every dependency configured starts", () => {
    const env = parseEnv(apiEnvSchema, {
      ENVIRONMENT: "production",
      DATABASE_URL: "postgresql://u:p@example.com:5432/db",
      REDIS_URL: "rediss://example.com:6380",
      SUPABASE_URL: "https://project.supabase.co",
    });
    expect(() => enforceApiFailClosed(env)).not.toThrow();
  });

  test("the issuer and JWKS URL are derived from SUPABASE_URL", () => {
    // Deriving rather than configuring separately means a misconfiguration
    // cannot leave the API trusting one origin's keys for another's tokens.
    expect(authIssuer("https://project.supabase.co/")).toBe(
      "https://project.supabase.co/auth/v1",
    );
    expect(authJwksUrl("https://project.supabase.co")).toBe(
      "https://project.supabase.co/auth/v1/.well-known/jwks.json",
    );
  });

  test("auth tuning values are bounded", () => {
    // A large clock skew silently extends the life of expired tokens, and a
    // long reauth TTL makes a stolen grant valuable; both are capped.
    expect(() =>
      parseEnv(apiEnvSchema, {
        ENVIRONMENT: "development",
        AUTH_CLOCK_SKEW_SECONDS: "86400",
      })
    ).toThrow(ConfigError);
    expect(() =>
      parseEnv(apiEnvSchema, {
        ENVIRONMENT: "development",
        AUTH_REAUTH_TTL_SECONDS: "99999",
      })
    ).toThrow(ConfigError);
  });

  test("non-production may start degraded", () => {
    const env = parseEnv(apiEnvSchema, { ENVIRONMENT: "development" });
    expect(() => enforceApiFailClosed(env)).not.toThrow();
  });
});

describe("redaction", () => {
  test("redactUrl hides credentials but keeps host and path", () => {
    expect(
      redactUrl("postgresql://postgres:secret@127.0.0.1:54322/postgres"),
    ).toBe("postgresql://***@127.0.0.1:54322/postgres");
    expect(redactUrl("redis://:pw@redis.example.com:6379")).toBe(
      "redis://***@redis.example.com:6379",
    );
  });

  test("redactUrl marks unparsable values instead of echoing them", () => {
    expect(redactUrl("::not a url::")).toBe("***");
  });

  test("describeApiEnv never includes raw credentials", () => {
    const env = parseEnv(apiEnvSchema, {
      ENVIRONMENT: "development",
      DATABASE_URL: "postgresql://postgres:secret@127.0.0.1:54322/postgres",
    });
    const described = JSON.stringify(describeApiEnv(env));
    expect(described).not.toContain("secret");
    expect(described).toContain("127.0.0.1:54322");
  });

  test("describeWorkerEnv redacts the redis URL", () => {
    const env = parseEnv(workerEnvSchema, {
      ENVIRONMENT: "development",
      REDIS_URL: "redis://:pw@127.0.0.1:6379",
    });
    expect(JSON.stringify(describeWorkerEnv(env))).not.toContain(":pw@");
  });
});
