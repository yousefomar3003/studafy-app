import { z } from "zod";
import {
  Environment,
  type Environment as EnvironmentType,
  type LogLevel,
  LogLevel as LogLevelSchema,
} from "@studafy/contracts";

export { Environment };
export type { EnvironmentType, LogLevel };

const url = z.string().min(1).refine((value) => {
  try {
    new URL(value);
    return true;
  } catch {
    return false;
  }
}, "must be a valid absolute URL");

const origins = z.string().default("").transform((value, context) => {
  const values = value.split(",").map((entry) => entry.trim()).filter(Boolean);
  for (const origin of values) {
    try {
      const parsed = new URL(origin);
      if (
        parsed.origin !== origin || parsed.username || parsed.password ||
        !["https:", "http:"].includes(parsed.protocol) ||
        parsed.hostname.includes("*")
      ) throw new Error();
    } catch {
      context.addIssue({
        code: "custom",
        message: "must contain exact comma-separated origins",
      });
      return z.NEVER;
    }
  }
  return [...new Set(values)];
});
const switchFlag = z.enum(["true", "false"]).default("true").transform(
  (value) => value === "true",
);
const disabledSwitchFlag = z.enum(["true", "false"]).default("false")
  .transform((value) => value === "true");

export const apiEnvSchema = z.object({
  ENVIRONMENT: Environment,
  API_PORT: z.coerce.number().int().min(1).max(65535).default(8080),
  DATABASE_URL: url.optional(),
  REDIS_URL: url.optional(),
  LOG_LEVEL: LogLevelSchema.default("info"),
  API_ALLOWED_ORIGINS: origins,
  API_MAX_BODY_BYTES: z.coerce.number().int().min(1024).max(1024 * 1024)
    .default(64 * 1024),
  API_REQUEST_TIMEOUT_MS: z.coerce.number().int().min(100).max(30_000).default(
    10_000,
  ),
  API_CURSOR_SIGNING_KEY: z.string().min(32).optional(),
  // OPS-060. The HMAC key is the only place account identifiers exist before
  // they enter a Redis key: every limiter/cache key carries HMAC(subject)
  // instead, so the key namespace itself is not an enumeration side channel.
  // The key is per-environment and rotatable (ROTATED key keeps old digests
  // readable for one grace window while new writes use the new digest).
  RATE_LIMIT_ENABLED: switchFlag,
  RATE_LIMIT_HMAC_SIGNING_KEY: z.string().min(32).optional(),
  API041_CLASSES_ENABLED: switchFlag,
  API041_CONTENT_ENABLED: switchFlag,
  API041_ASSIGNMENTS_ENABLED: switchFlag,
  API041_ASSESSMENTS_ENABLED: switchFlag,
  API041_GRADES_ENABLED: switchFlag,
  API041_ATTENDANCE_ENABLED: switchFlag,
  API041_WELLBEING_ENABLED: switchFlag,
  API042_SCHOOLS_ENABLED: switchFlag,
  API042_MEMBERSHIPS_ENABLED: switchFlag,
  API042_STAFFING_ENABLED: switchFlag,
  API042_ENROLLMENT_ENABLED: switchFlag,
  API042_INVITATIONS_ENABLED: switchFlag,
  API042_FAMILY_ENABLED: switchFlag,
  API042_CONVERSATIONS_ENABLED: switchFlag,
  API042_ANNOUNCEMENTS_ENABLED: switchFlag,
  API042_MEETINGS_ENABLED: switchFlag,
  API042_NOTIFICATIONS_ENABLED: switchFlag,
  API042_ACCOUNT_RIGHTS_ENABLED: switchFlag,
  API042_SUPPORT_ACCESS_ENABLED: switchFlag,
  SAFE043_REPORTING_ENABLED: switchFlag,
  SAFE043_BLOCKS_ENABLED: switchFlag,
  SAFE043_MODERATION_ENABLED: switchFlag,
  SAFE043_CONTENT_CONTROLS_ENABLED: switchFlag,
  FILE050_NEW_INTENTS_ENABLED: disabledSwitchFlag,
  // FILE-051 delivery/publication switches stay off unless explicitly enabled
  // in a disposable environment, exactly like the FILE-050 intent switch.
  FILE051_DELIVERY_ENABLED: disabledSwitchFlag,
  FILE051_PUBLISH_ENABLED: disabledSwitchFlag,
  FILE051_DELIVERY_SIGNING_KEY: z.string().min(32).optional(),
  FILE051_DELIVERY_PUBLIC_BASE_URL: url.optional(),
  SUPABASE_SERVICE_ROLE_KEY: z.string().min(20).optional(),

  // AUTH-030. The issuer is derived from SUPABASE_URL rather than configured
  // separately, so a misconfiguration cannot leave the API trusting one
  // origin's keys to authenticate another origin's tokens.
  SUPABASE_URL: url.optional(),
  AUTH_JWT_AUDIENCE: z.string().min(1).default("authenticated"),
  // Bounded clock skew. Generous enough for real device clocks, small enough
  // that it does not meaningfully extend the life of an expired token.
  AUTH_CLOCK_SKEW_SECONDS: z.coerce.number().int().min(0).max(300).default(30),
  // How long after a revocation a still-valid access token may keep working.
  // The watermark check makes this effectively zero; the value is the bound
  // the product commits to and is asserted in tests.
  AUTH_REVOCATION_BUDGET_SECONDS: z.coerce.number().int().min(0).max(300)
    .default(0),
  // Recent-auth grants are short by design: long enough to complete one
  // privileged action, too short to be worth stealing.
  AUTH_REAUTH_TTL_SECONDS: z.coerce.number().int().min(30).max(1800)
    .default(300),
  AUTH_DELETION_GRACE_DAYS: z.coerce.number().int().min(1).max(90).default(14),

  // PAY-071. Off by default, like every other module switch; the store
  // billing machinery is built even while the paid products stay gated at
  // the catalogue layer (storefront_listed), not by leaving this off.
  PAY071_BILLING_ENABLED: disabledSwitchFlag,
  PAY071_ENVIRONMENT: z.enum([
    "synthetic",
    "development",
    "staging",
    "production",
  ]).optional(),
  APPLE_BUNDLE_ID: z.string().min(1).optional(),
  APPLE_ENVIRONMENT: z.enum(["Sandbox", "Production"]).optional(),
  APPLE_APP_APPLE_ID: z.coerce.number().int().positive().optional(),
  APPLE_ISSUER_ID: z.string().min(1).optional(),
  APPLE_KEY_ID: z.string().min(1).optional(),
  APPLE_PRIVATE_KEY: z.string().min(1).optional(),
  // DER-encoded Apple root CA certificates, base64, comma-separated. Never
  // fetched or embedded by this codebase - obtained from Apple's own PKI
  // page and rotated per the runbook in docs/evidence/pay-071/README.md.
  APPLE_ROOT_CERTIFICATES_BASE64: z.string().min(1).optional(),
  GOOGLE_PACKAGE_NAME: z.string().min(1).optional(),
  // Raw service account JSON content, never a file path.
  GOOGLE_SERVICE_ACCOUNT_JSON: z.string().min(1).optional(),
  GOOGLE_PUBSUB_SERVICE_ACCOUNT_EMAIL: z.string().min(1).optional(),
  GOOGLE_PUBSUB_AUDIENCE: url.optional(),
  PARENTAL_GATE_SIGNING_KEY: z.string().min(32).optional(),
}).superRefine((value, context) => {
  if (!value.PAY071_BILLING_ENABLED) return;
  if (!value.PAY071_ENVIRONMENT) {
    context.addIssue({
      code: "custom",
      path: ["PAY071_ENVIRONMENT"],
      message: "required when billing is enabled",
    });
  }
  if (!value.PARENTAL_GATE_SIGNING_KEY) {
    context.addIssue({
      code: "custom",
      path: ["PARENTAL_GATE_SIGNING_KEY"],
      message: "required when billing is enabled",
    });
  } else if (
    value.PARENTAL_GATE_SIGNING_KEY === value.API_CURSOR_SIGNING_KEY ||
    value.PARENTAL_GATE_SIGNING_KEY === value.FILE051_DELIVERY_SIGNING_KEY
  ) {
    context.addIssue({
      code: "custom",
      path: ["PARENTAL_GATE_SIGNING_KEY"],
      message: "must differ from every other signing key",
    });
  }
});
export type ApiEnv = z.infer<typeof apiEnvSchema>;

export const workerEnvSchema = z.object({
  ENVIRONMENT: Environment,
  REDIS_URL: url,
  LOG_LEVEL: LogLevelSchema.default("info"),
  DATABASE_URL: url.optional(),
  SUPABASE_URL: url.optional(),
  SUPABASE_SERVICE_ROLE_KEY: z.string().min(20).optional(),
  FILE050_CLEANUP_ENABLED: disabledSwitchFlag,
  // FILE-051 scan/retention workers stay off unless explicitly enabled.
  FILE051_SCAN_ENABLED: disabledSwitchFlag,
  FILE051_RETENTION_ENABLED: disabledSwitchFlag,
  // OPS-061. The outbox drain is producer+consumer over BullMQ: the
  // dispatcher claims notification_outbox rows and enqueues deterministic
  // jobs; the processor expands audiences into deliveries. Off by default;
  // enabling it requires the database (durable outbox + idempotency fence).
  OPS061_NOTIFICATIONS_ENABLED: disabledSwitchFlag,
  OPS061_OUTBOX_POLL_INTERVAL_MS: z.coerce.number().int().min(250).max(60_000)
    .default(5000),
  OPS061_OUTBOX_CONCURRENCY: z.coerce.number().int().min(1).max(20).default(5),
  // PAY-071. Mirrors the API's billing config: the worker re-verifies
  // authoritative state through the same official APIs rather than trusting
  // a webhook payload, and acknowledges Google purchases within its 3-day
  // auto-refund window.
  PAY071_BILLING_ENABLED: disabledSwitchFlag,
  PAY071_ENVIRONMENT: z.enum([
    "synthetic",
    "development",
    "staging",
    "production",
  ]).optional(),
  PAY071_RECONCILIATION_ENABLED: disabledSwitchFlag,
  PAY071_OUTBOX_POLL_INTERVAL_MS: z.coerce.number().int().min(250).max(60_000)
    .default(5000),
  PAY071_OUTBOX_CONCURRENCY: z.coerce.number().int().min(1).max(20).default(5),
  APPLE_BUNDLE_ID: z.string().min(1).optional(),
  APPLE_ENVIRONMENT: z.enum(["Sandbox", "Production"]).optional(),
  APPLE_APP_APPLE_ID: z.coerce.number().int().positive().optional(),
  APPLE_ISSUER_ID: z.string().min(1).optional(),
  APPLE_KEY_ID: z.string().min(1).optional(),
  APPLE_PRIVATE_KEY: z.string().min(1).optional(),
  APPLE_ROOT_CERTIFICATES_BASE64: z.string().min(1).optional(),
  GOOGLE_PACKAGE_NAME: z.string().min(1).optional(),
  GOOGLE_SERVICE_ACCOUNT_JSON: z.string().min(1).optional(),
  GOOGLE_PUBSUB_SERVICE_ACCOUNT_EMAIL: z.string().min(1).optional(),
  GOOGLE_PUBSUB_AUDIENCE: url.optional(),
  // The external malware scanner. Absent in local/disposable use (the
  // deterministic structural scanner runs instead); production refuses to
  // scan without it, because structural validation is not signature-grade.
  MALWARE_SCANNER_URL: url.optional(),
  MALWARE_SCANNER_API_KEY: z.string().min(20).optional(),
}).superRefine((value, context) => {
  const dependentKeys = [
    "DATABASE_URL",
    "SUPABASE_URL",
    "SUPABASE_SERVICE_ROLE_KEY",
  ] as const;
  for (
    const enabled of [
      value.FILE050_CLEANUP_ENABLED,
      value.FILE051_SCAN_ENABLED,
      value.FILE051_RETENTION_ENABLED,
    ]
  ) {
    if (!enabled) continue;
    for (const key of dependentKeys) {
      if (!value[key]) {
        context.addIssue({
          code: "custom",
          path: [key],
          message: `required when a file worker is enabled (${key})`,
        });
      }
    }
    break;
  }
  if (value.ENVIRONMENT === "production" && value.FILE051_SCAN_ENABLED) {
    for (
      const key of ["MALWARE_SCANNER_URL", "MALWARE_SCANNER_API_KEY"] as const
    ) {
      if (!value[key]) {
        context.addIssue({
          code: "custom",
          path: [key],
          message: "required when scanning is enabled in production",
        });
      }
    }
  }
  if (value.OPS061_NOTIFICATIONS_ENABLED && !value.DATABASE_URL) {
    context.addIssue({
      code: "custom",
      path: ["DATABASE_URL"],
      message: "required when the outbox drain is enabled (DATABASE_URL)",
    });
  }
  if (value.PAY071_BILLING_ENABLED) {
    if (!value.DATABASE_URL) {
      context.addIssue({
        code: "custom",
        path: ["DATABASE_URL"],
        message: "required when billing is enabled",
      });
    }
    if (!value.PAY071_ENVIRONMENT) {
      context.addIssue({
        code: "custom",
        path: ["PAY071_ENVIRONMENT"],
        message: "required when billing is enabled",
      });
    }
  }
});
export type WorkerEnv = z.infer<typeof workerEnvSchema>;

export class ConfigError extends Error {
  readonly code = "CONFIG_INVALID";
  constructor(message: string) {
    super(message);
    this.name = "ConfigError";
  }
}

export function parseEnv<T>(
  schema: z.ZodType<T>,
  source: Record<string, string | undefined>,
): T {
  const result = schema.safeParse(source);
  if (!result.success) {
    const details = result.error.issues
      .map((issue) => `${issue.path.join(".") || "(root)"}: ${issue.message}`)
      .join("; ");
    throw new ConfigError(`Environment configuration rejected: ${details}`);
  }
  return result.data;
}

/**
 * Production fails closed: the API refuses to start without its authoritative
 * dependencies, because silently serving unready infrastructure is worse than
 * not starting. Non-production environments may start degraded and report the
 * missing dependencies as readiness reason codes instead.
 */

/**
 * OPS-060: Redis carries rate-limit counters and revocation-safe caches, so a
 * production connection must never be plaintext or passwordless — TLS
 * (rediss) plus AUTH, on a private-network address. Development keeps the
 * docker-compose dev stack (plain redis:// on loopback) as the documented
 * local posture; TLS and private networking land with Phase 8 IaC.
 */
export function redisUrlPostureProblems(
  value: string | undefined,
): string[] {
  if (!value) return [];
  const problems: string[] = [];
  try {
    const parsed = new URL(value);
    if (parsed.protocol !== "rediss:") {
      problems.push("REDIS_URL must use rediss:// (TLS) in production.");
    }
    if (!parsed.password && !parsed.username) {
      problems.push("REDIS_URL must carry AUTH credentials in production.");
    }
  } catch {
    problems.push("REDIS_URL must be a valid URL in production.");
  }
  return problems;
}

export function enforceApiFailClosed(env: ApiEnv): void {
  if (env.ENVIRONMENT !== "production") return;
  const missing: string[] = [];
  if (!env.DATABASE_URL) missing.push("DATABASE_URL");
  if (!env.REDIS_URL) missing.push("REDIS_URL");
  // Without SUPABASE_URL there is no JWKS to verify against, and an API that
  // cannot verify a token must not start rather than start unauthenticated.
  if (!env.SUPABASE_URL) missing.push("SUPABASE_URL");
  if (!env.API_CURSOR_SIGNING_KEY) missing.push("API_CURSOR_SIGNING_KEY");
  if (env.FILE050_NEW_INTENTS_ENABLED && !env.SUPABASE_SERVICE_ROLE_KEY) {
    missing.push("SUPABASE_SERVICE_ROLE_KEY");
  }
  if (env.FILE051_DELIVERY_ENABLED) {
    if (!env.FILE051_DELIVERY_SIGNING_KEY) {
      missing.push("FILE051_DELIVERY_SIGNING_KEY");
    } else if (
      env.FILE051_DELIVERY_SIGNING_KEY === env.API_CURSOR_SIGNING_KEY
    ) {
      // One key per purpose: a cursor must never verify as a delivery token.
      throw new ConfigError(
        "FILE051_DELIVERY_SIGNING_KEY must differ from API_CURSOR_SIGNING_KEY.",
      );
    }
    if (!env.FILE051_DELIVERY_PUBLIC_BASE_URL) {
      missing.push("FILE051_DELIVERY_PUBLIC_BASE_URL");
    } else if (!env.FILE051_DELIVERY_PUBLIC_BASE_URL.startsWith("https://")) {
      throw new ConfigError(
        "Production delivery URLs must use an HTTPS public base URL.",
      );
    }
    if (!env.SUPABASE_SERVICE_ROLE_KEY) {
      missing.push("SUPABASE_SERVICE_ROLE_KEY");
    }
  }
  if (env.RATE_LIMIT_ENABLED && !env.RATE_LIMIT_HMAC_SIGNING_KEY) {
    missing.push("RATE_LIMIT_HMAC_SIGNING_KEY");
  }
  if (missing.length > 0) {
    throw new ConfigError(
      `Production requires ${missing.join(", ")} to be configured.`,
    );
  }
  const posture = redisUrlPostureProblems(env.REDIS_URL);
  if (posture.length > 0) {
    throw new ConfigError(
      `Production Redis posture rejected: ${posture.join(" ")}`,
    );
  }
}

export function enforceWorkerFailClosed(env: WorkerEnv): void {
  if (env.ENVIRONMENT !== "production") return;
  const posture = redisUrlPostureProblems(env.REDIS_URL);
  if (posture.length > 0) {
    throw new ConfigError(
      `Production Redis posture rejected: ${posture.join(" ")}`,
    );
  }
}

/** The exact issuer the API will accept, derived from the project URL. */
export function authIssuer(supabaseUrl: string): string {
  return `${supabaseUrl.replace(/\/+$/, "")}/auth/v1`;
}

/** The JWKS endpoint for the configured project. */
export function authJwksUrl(supabaseUrl: string): string {
  return `${authIssuer(supabaseUrl)}/.well-known/jwks.json`;
}

/** Redacts credentials in a connection URL so only scheme/host/port/path remain. */
export function redactUrl(value: string): string {
  try {
    const parsed = new URL(value);
    if (parsed.password || parsed.username) {
      parsed.username = "***";
      parsed.password = "";
    }
    return parsed.toString();
  } catch {
    return "***";
  }
}

/** Produces a log-safe snapshot of the API environment (values are public config only). */
export function describeApiEnv(env: ApiEnv): Record<string, unknown> {
  return {
    environment: env.ENVIRONMENT,
    port: env.API_PORT,
    log_level: env.LOG_LEVEL,
    allowed_origins: env.API_ALLOWED_ORIGINS,
    max_body_bytes: env.API_MAX_BODY_BYTES,
    request_timeout_ms: env.API_REQUEST_TIMEOUT_MS,
    database_url: env.DATABASE_URL ? redactUrl(env.DATABASE_URL) : null,
    redis_url: env.REDIS_URL ? redactUrl(env.REDIS_URL) : null,
    supabase_url: env.SUPABASE_URL ? redactUrl(env.SUPABASE_URL) : null,
    auth_jwt_audience: env.AUTH_JWT_AUDIENCE,
    auth_clock_skew_seconds: env.AUTH_CLOCK_SKEW_SECONDS,
    auth_revocation_budget_seconds: env.AUTH_REVOCATION_BUDGET_SECONDS,
    auth_reauth_ttl_seconds: env.AUTH_REAUTH_TTL_SECONDS,
    auth_deletion_grace_days: env.AUTH_DELETION_GRACE_DAYS,
    cursor_signing_key_configured: Boolean(env.API_CURSOR_SIGNING_KEY),
    rate_limit_enabled: env.RATE_LIMIT_ENABLED,
    rate_limit_hmac_key_configured: Boolean(env.RATE_LIMIT_HMAC_SIGNING_KEY),
    api041_slices: {
      classes: env.API041_CLASSES_ENABLED,
      content: env.API041_CONTENT_ENABLED,
      assignments: env.API041_ASSIGNMENTS_ENABLED,
      assessments: env.API041_ASSESSMENTS_ENABLED,
      grades: env.API041_GRADES_ENABLED,
      attendance: env.API041_ATTENDANCE_ENABLED,
      wellbeing: env.API041_WELLBEING_ENABLED,
    },
    api042_slices: {
      schools: env.API042_SCHOOLS_ENABLED,
      memberships: env.API042_MEMBERSHIPS_ENABLED,
      staffing: env.API042_STAFFING_ENABLED,
      enrollment: env.API042_ENROLLMENT_ENABLED,
      invitations: env.API042_INVITATIONS_ENABLED,
      family: env.API042_FAMILY_ENABLED,
      conversations: env.API042_CONVERSATIONS_ENABLED,
      announcements: env.API042_ANNOUNCEMENTS_ENABLED,
      meetings: env.API042_MEETINGS_ENABLED,
      notifications: env.API042_NOTIFICATIONS_ENABLED,
      accountRights: env.API042_ACCOUNT_RIGHTS_ENABLED,
      supportAccess: env.API042_SUPPORT_ACCESS_ENABLED,
    },
    safe043_slices: {
      reporting: env.SAFE043_REPORTING_ENABLED,
      blocks: env.SAFE043_BLOCKS_ENABLED,
      moderation: env.SAFE043_MODERATION_ENABLED,
      contentControls: env.SAFE043_CONTENT_CONTROLS_ENABLED,
    },
    file050: {
      newIntentsEnabled: env.FILE050_NEW_INTENTS_ENABLED,
      serviceRoleConfigured: Boolean(env.SUPABASE_SERVICE_ROLE_KEY),
    },
    file051: {
      deliveryEnabled: env.FILE051_DELIVERY_ENABLED,
      publishEnabled: env.FILE051_PUBLISH_ENABLED,
      deliverySigningKeyConfigured: Boolean(env.FILE051_DELIVERY_SIGNING_KEY),
      deliveryPublicBaseUrl: env.FILE051_DELIVERY_PUBLIC_BASE_URL ?? null,
    },
    pay071: {
      billingEnabled: env.PAY071_BILLING_ENABLED,
      environment: env.PAY071_ENVIRONMENT ?? null,
      appleConfigured: Boolean(
        env.APPLE_BUNDLE_ID && env.APPLE_ISSUER_ID && env.APPLE_KEY_ID &&
          env.APPLE_PRIVATE_KEY && env.APPLE_ROOT_CERTIFICATES_BASE64,
      ),
      googleConfigured: Boolean(
        env.GOOGLE_PACKAGE_NAME && env.GOOGLE_SERVICE_ACCOUNT_JSON &&
          env.GOOGLE_PUBSUB_AUDIENCE,
      ),
      parentalGateKeyConfigured: Boolean(env.PARENTAL_GATE_SIGNING_KEY),
    },
  };
}

/** Produces a log-safe snapshot of the worker environment. */
export function describeWorkerEnv(env: WorkerEnv): Record<string, unknown> {
  return {
    environment: env.ENVIRONMENT,
    log_level: env.LOG_LEVEL,
    redis_url: redactUrl(env.REDIS_URL),
    database_url: env.DATABASE_URL ? redactUrl(env.DATABASE_URL) : null,
    supabase_url: env.SUPABASE_URL ? redactUrl(env.SUPABASE_URL) : null,
    file050_cleanup_enabled: env.FILE050_CLEANUP_ENABLED,
    service_role_configured: Boolean(env.SUPABASE_SERVICE_ROLE_KEY),
    ops061: {
      notificationsEnabled: env.OPS061_NOTIFICATIONS_ENABLED,
      outboxPollIntervalMs: env.OPS061_OUTBOX_POLL_INTERVAL_MS,
      outboxConcurrency: env.OPS061_OUTBOX_CONCURRENCY,
    },
    file051: {
      scanEnabled: env.FILE051_SCAN_ENABLED,
      retentionEnabled: env.FILE051_RETENTION_ENABLED,
      malwareScannerConfigured: Boolean(
        env.MALWARE_SCANNER_URL && env.MALWARE_SCANNER_API_KEY,
      ),
    },
    pay071: {
      billingEnabled: env.PAY071_BILLING_ENABLED,
      environment: env.PAY071_ENVIRONMENT ?? null,
      reconciliationEnabled: env.PAY071_RECONCILIATION_ENABLED,
      appleConfigured: Boolean(
        env.APPLE_BUNDLE_ID && env.APPLE_ISSUER_ID && env.APPLE_KEY_ID &&
          env.APPLE_PRIVATE_KEY && env.APPLE_ROOT_CERTIFICATES_BASE64,
      ),
      googleConfigured: Boolean(
        env.GOOGLE_PACKAGE_NAME && env.GOOGLE_SERVICE_ACCOUNT_JSON &&
          env.GOOGLE_PUBSUB_AUDIENCE,
      ),
    },
  };
}
