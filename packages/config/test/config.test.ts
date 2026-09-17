import { describe, expect, test } from "bun:test";
import {
  apiEnvSchema,
  authIssuer,
  authJwksUrl,
  ConfigError,
  describeApiEnv,
  describeWorkerEnv,
  enforceApiFailClosed,
  enforceWorkerFailClosed,
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
    expect(env.API_ALLOWED_ORIGINS).toEqual([]);
    expect(env.API_MAX_BODY_BYTES).toBe(64 * 1024);
    expect(env.API_REQUEST_TIMEOUT_MS).toBe(10_000);
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

  test("browser origins are exact, unique, and never wildcard patterns", () => {
    const env = parseEnv(apiEnvSchema, {
      ENVIRONMENT: "development",
      API_ALLOWED_ORIGINS: "https://app.studafy.test,https://app.studafy.test",
    });
    expect(env.API_ALLOWED_ORIGINS).toEqual(["https://app.studafy.test"]);
    for (
      const invalid of [
        "*",
        "https://*.studafy.test",
        "https://user:pass@app.test",
        "https://app.test/path",
      ]
    ) {
      expect(() =>
        parseEnv(apiEnvSchema, {
          ENVIRONMENT: "development",
          API_ALLOWED_ORIGINS: invalid,
        })
      )
        .toThrow(ConfigError);
    }
  });

  test("request byte and deadline configuration is bounded", () => {
    expect(() =>
      parseEnv(apiEnvSchema, {
        ENVIRONMENT: "development",
        API_MAX_BODY_BYTES: "9999999",
      })
    )
      .toThrow(ConfigError);
    expect(() =>
      parseEnv(apiEnvSchema, {
        ENVIRONMENT: "development",
        API_REQUEST_TIMEOUT_MS: "50",
      })
    )
      .toThrow(ConfigError);
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
      REDIS_URL: "rediss://:pw@example.com:6380",
    });
    expect(() => enforceApiFailClosed(env)).toThrow(ConfigError);
  });

  test("production with every dependency configured starts", () => {
    const env = parseEnv(apiEnvSchema, {
      ENVIRONMENT: "production",
      DATABASE_URL: "postgresql://u:p@example.com:5432/db",
      REDIS_URL: "rediss://:pw@example.com:6380",
      SUPABASE_URL: "https://project.supabase.co",
      API_CURSOR_SIGNING_KEY: "a-development-test-key-with-32-bytes",
      RATE_LIMIT_HMAC_SIGNING_KEY: "a-development-test-key-with-32-bytes",
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

describe("redis production posture (OPS-060)", () => {
  const productionEnv = {
    ENVIRONMENT: "production",
    DATABASE_URL: "postgresql://u:p@example.com:5432/db",
    SUPABASE_URL: "https://project.supabase.co",
    API_CURSOR_SIGNING_KEY: "a-development-test-key-with-32-bytes",
    RATE_LIMIT_HMAC_SIGNING_KEY: "a-development-test-key-with-32-bytes",
  } as const;

  test("accepts redis:// with credentials in development", () => {
    const env = parseEnv(apiEnvSchema, {
      ENVIRONMENT: "development",
      REDIS_URL: "redis://127.0.0.1:6379",
    });
    expect(() => enforceApiFailClosed(env)).not.toThrow();
  });

  test("rejects plaintext redis:// in production", () => {
    const env = parseEnv(apiEnvSchema, {
      ...productionEnv,
      REDIS_URL: "redis://:pw@redis.example.com:6379",
    });
    expect(() => enforceApiFailClosed(env)).toThrow(
      /must use rediss:\/\/ \(TLS\)/,
    );
  });

  test("rejects rediss:// without AUTH credentials in production", () => {
    const env = parseEnv(apiEnvSchema, {
      ...productionEnv,
      REDIS_URL: "rediss://redis.example.com:6379",
    });
    expect(() => enforceApiFailClosed(env)).toThrow(
      /must carry AUTH credentials/,
    );
  });

  test("accepts rediss:// with AUTH credentials in production", () => {
    const env = parseEnv(apiEnvSchema, {
      ...productionEnv,
      REDIS_URL: "rediss://:pw@redis.example.com:6379",
    });
    expect(() => enforceApiFailClosed(env)).not.toThrow();
  });

  test("worker production posture is enforced by enforceWorkerFailClosed", () => {
    const plaintext = parseEnv(workerEnvSchema, {
      ENVIRONMENT: "production",
      REDIS_URL: "redis://:pw@redis.example.com:6379",
    });
    expect(() => enforceWorkerFailClosed(plaintext)).toThrow(ConfigError);
    const tls = parseEnv(workerEnvSchema, {
      ENVIRONMENT: "production",
      REDIS_URL: "rediss://:pw@redis.example.com:6379",
    });
    expect(() => enforceWorkerFailClosed(tls)).not.toThrow();
  });
});

describe("rate limiting configuration (OPS-060)", () => {
  test("rate limiting is enabled by default and requires an HMAC key in production", () => {
    const env = parseEnv(apiEnvSchema, { ENVIRONMENT: "development" });
    expect(env.RATE_LIMIT_ENABLED).toBe(true);
    expect(env.RATE_LIMIT_HMAC_SIGNING_KEY).toBeUndefined();
    const env2 = parseEnv(apiEnvSchema, {
      ENVIRONMENT: "production",
      DATABASE_URL: "postgresql://u:p@example.com:5432/db",
      REDIS_URL: "rediss://:pw@redis.example.com:6379",
      SUPABASE_URL: "https://project.supabase.co",
      API_CURSOR_SIGNING_KEY: "a-development-test-key-with-32-bytes",
    });
    expect(() => enforceApiFailClosed(env2)).toThrow(
      /RATE_LIMIT_HMAC_SIGNING_KEY/,
    );
  });

  test("the HMAC key must be at least 32 bytes and can be disabled explicitly", () => {
    expect(() =>
      parseEnv(apiEnvSchema, {
        ENVIRONMENT: "development",
        RATE_LIMIT_HMAC_SIGNING_KEY: "short",
      })
    ).toThrow(ConfigError);
    const env = parseEnv(apiEnvSchema, {
      ENVIRONMENT: "development",
      RATE_LIMIT_ENABLED: "false",
      RATE_LIMIT_HMAC_SIGNING_KEY: "a-development-test-key-with-32-bytes",
    });
    expect(env.RATE_LIMIT_ENABLED).toBe(false);
  });

  test("describeApiEnv reports rate limiting without leaking the key", () => {
    const env = parseEnv(apiEnvSchema, {
      ENVIRONMENT: "development",
      RATE_LIMIT_HMAC_SIGNING_KEY: "a-development-test-key-with-32-bytes",
    });
    const described = JSON.stringify(describeApiEnv(env));
    expect(described).toContain('"rate_limit_enabled":true');
    expect(described).toContain('"rate_limit_hmac_key_configured":true');
    expect(described).not.toContain("a-development-test-key-with-32-bytes");
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

describe("outbox drain configuration (OPS-061)", () => {
  test("the drain is off by default", () => {
    const env = parseEnv(workerEnvSchema, {
      ENVIRONMENT: "development",
      REDIS_URL: "redis://127.0.0.1:6379",
    });
    expect(env.OPS061_NOTIFICATIONS_ENABLED).toBe(false);
    expect(env.OPS061_OUTBOX_POLL_INTERVAL_MS).toBe(5000);
    expect(env.OPS061_OUTBOX_CONCURRENCY).toBe(5);
  });

  test("enabling the drain requires the durable outbox database", () => {
    expect(() =>
      parseEnv(workerEnvSchema, {
        ENVIRONMENT: "development",
        REDIS_URL: "redis://127.0.0.1:6379",
        OPS061_NOTIFICATIONS_ENABLED: "true",
      })
    ).toThrow(/DATABASE_URL/);
    const env = parseEnv(workerEnvSchema, {
      ENVIRONMENT: "development",
      REDIS_URL: "redis://127.0.0.1:6379",
      DATABASE_URL: "postgresql://postgres@127.0.0.1:54322/postgres",
      OPS061_NOTIFICATIONS_ENABLED: "true",
    });
    expect(env.OPS061_NOTIFICATIONS_ENABLED).toBe(true);
  });

  test("poll interval and concurrency are bounded", () => {
    for (const value of ["0", "249", "60001"]) {
      expect(() =>
        parseEnv(workerEnvSchema, {
          ENVIRONMENT: "development",
          REDIS_URL: "redis://127.0.0.1:6379",
          OPS061_OUTBOX_POLL_INTERVAL_MS: value,
        })
      ).toThrow(/OPS061_OUTBOX_POLL_INTERVAL_MS/);
    }
    expect(() =>
      parseEnv(workerEnvSchema, {
        ENVIRONMENT: "development",
        REDIS_URL: "redis://127.0.0.1:6379",
        OPS061_OUTBOX_CONCURRENCY: "21",
      })
    ).toThrow(/OPS061_OUTBOX_CONCURRENCY/);
  });

  test("describeWorkerEnv reports the drain without identifiers", () => {
    const env = parseEnv(workerEnvSchema, {
      ENVIRONMENT: "development",
      REDIS_URL: "redis://127.0.0.1:6379",
      DATABASE_URL: "postgresql://postgres@127.0.0.1:54322/postgres",
      OPS061_NOTIFICATIONS_ENABLED: "true",
    });
    const described = describeWorkerEnv(env);
    expect(described["ops061"]).toEqual({
      notificationsEnabled: true,
      outboxPollIntervalMs: 5000,
      outboxConcurrency: 5,
    });
  });
});
