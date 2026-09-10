import type { Environment } from "@studafy/contracts";
import type { Logger } from "./logger";

/** Emits the startup event with safe, non-secret fields. */
export function logStartup(
  logger: Logger,
  meta: {
    environment: Environment;
    runtime: string;
    configuration: Record<string, unknown>;
    extra?: Record<string, unknown>;
  },
): void {
  logger.info("startup", {
    environment: meta.environment,
    runtime: meta.runtime,
    configuration: meta.configuration,
    ...meta.extra,
  });
}

/** Emits the listening event for an HTTP service. */
export function logListening(
  logger: Logger,
  meta: { port: number },
): void {
  logger.info("listening", { port: meta.port });
}

/** Emits a structured shutdown step. */
export function logShutdownStep(
  logger: Logger,
  phase: string,
  fields: Record<string, unknown> = {},
): void {
  logger.info("shutdown", { phase, ...fields });
}
