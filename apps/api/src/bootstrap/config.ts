import {
  type ApiEnv,
  apiEnvSchema,
  describeApiEnv,
  enforceApiFailClosed,
  parseEnv,
} from "@studafy/config";

/** Loads and validates the API environment exactly once at startup. */
export function loadApiEnv(
  source: Record<string, string | undefined> = process.env,
): ApiEnv {
  const env = parseEnv(apiEnvSchema, source);
  enforceApiFailClosed(env);
  return env;
}

export { describeApiEnv };
