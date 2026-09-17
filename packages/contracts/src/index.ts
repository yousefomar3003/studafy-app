import { z } from "zod";
export {
  ErrorCode,
  IdempotencyMode,
  ProblemDetails,
  ProblemField,
} from "./v1/platform";
export type {
  ErrorCode as ErrorCodeType,
  IdempotencyMode as IdempotencyModeType,
  ProblemDetails as ProblemDetailsType,
  ProblemField as ProblemFieldType,
} from "./v1/platform";

/** Shared vocabulary for all services. Contracts is the base of the dependency
 * graph: it imports only `zod` and is imported by every other member. */

export const LogLevel = z.enum(["debug", "info", "warn", "error"]);
export type LogLevel = z.infer<typeof LogLevel>;

export const Environment = z.enum([
  "synthetic",
  "development",
  "staging",
  "production",
]);
export type Environment = z.infer<typeof Environment>;

/** Machine-readable reason a service reports itself not ready. */
export const ReadinessReasonCode = z.enum([
  "database_unreachable",
  "redis_unreachable",
]);
export type ReadinessReasonCode = z.infer<typeof ReadinessReasonCode>;

export const ReadinessReport = z.object({
  ready: z.boolean(),
  reasons: z.array(ReadinessReasonCode),
});
export type ReadinessReport = z.infer<typeof ReadinessReport>;

export const ServiceInfo = z.object({
  service: z.string().min(1),
  version: z.string().min(1),
  environment: Environment,
});
export type ServiceInfo = z.infer<typeof ServiceInfo>;

/**
 * Stable machine error codes. Messages may change; codes may not.
 *
 * The authentication codes are deliberately coarse. There is no code for
 * "unknown account", "wrong provider", or "account deleted" — every such
 * outcome is `UNAUTHENTICATED`, so a caller cannot use error codes to learn
 * whether an address belongs to a Studafy user (AUTH-030 anti-enumeration).
 */
// Versioned API contracts (ARC-011).
export * from "./v1";
// Versioned job payload contracts (OPS-061).
export * from "./jobs";
