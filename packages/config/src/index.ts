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

export const apiEnvSchema = z.object({
  ENVIRONMENT: Environment,
  API_PORT: z.coerce.number().int().min(1).max(65535).default(8080),
  DATABASE_URL: url.optional(),
  REDIS_URL: url.optional(),
  LOG_LEVEL: LogLevelSchema.default("info"),
});
export type ApiEnv = z.infer<typeof apiEnvSchema>;

export const workerEnvSchema = z.object({
  ENVIRONMENT: Environment,
  REDIS_URL: url,
  LOG_LEVEL: LogLevelSchema.default("info"),
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
export function enforceApiFailClosed(env: ApiEnv): void {
  if (env.ENVIRONMENT !== "production") return;
  const missing: string[] = [];
  if (!env.DATABASE_URL) missing.push("DATABASE_URL");
  if (!env.REDIS_URL) missing.push("REDIS_URL");
  if (missing.length > 0) {
    throw new ConfigError(
      `Production requires ${missing.join(" and ")} to be configured.`,
    );
  }
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
    database_url: env.DATABASE_URL ? redactUrl(env.DATABASE_URL) : null,
    redis_url: env.REDIS_URL ? redactUrl(env.REDIS_URL) : null,
  };
}

/** Produces a log-safe snapshot of the worker environment. */
export function describeWorkerEnv(env: WorkerEnv): Record<string, unknown> {
  return {
    environment: env.ENVIRONMENT,
    log_level: env.LOG_LEVEL,
    redis_url: redactUrl(env.REDIS_URL),
  };
}
