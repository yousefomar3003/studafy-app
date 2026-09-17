import {
  describeWorkerEnv,
  enforceWorkerFailClosed,
  parseEnv,
  type WorkerEnv,
  workerEnvSchema,
} from "@studafy/config";

/** Loads and validates the worker environment exactly once at startup.
 * REDIS_URL is required in every environment: a worker without a queue
 * backend has no purpose, so configuration fails closed via the schema.
 * OPS-060: in production the URL must additionally be TLS (rediss) with
 * AUTH credentials on a private network. */
export function loadWorkerEnv(
  source: Record<string, string | undefined> = process.env,
): WorkerEnv {
  const env = parseEnv(workerEnvSchema, source);
  enforceWorkerFailClosed(env);
  return env;
}

export { describeWorkerEnv };
