import {
  describeWorkerEnv,
  parseEnv,
  workerEnvSchema,
  type WorkerEnv,
} from "@studafy/config";

/** Loads and validates the worker environment exactly once at startup.
 * REDIS_URL is required in every environment: a worker without a queue
 * backend has no purpose, so configuration fails closed via the schema. */
export function loadWorkerEnv(
  source: Record<string, string | undefined> = process.env,
): WorkerEnv {
  return parseEnv(workerEnvSchema, source);
}

export { describeWorkerEnv };
