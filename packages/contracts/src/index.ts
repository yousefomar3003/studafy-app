import { z } from "zod";

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

/** Stable machine error codes. Messages may change; codes may not. */
export const ErrorCode = {
  NOT_FOUND: "NOT_FOUND",
  NOT_IMPLEMENTED: "NOT_IMPLEMENTED",
  INTERNAL_ERROR: "INTERNAL_ERROR",
} as const;
export type ErrorCode = (typeof ErrorCode)[keyof typeof ErrorCode];

export const ErrorBody = z.object({
  error: z.object({
    code: z.string().min(1),
    message: z.string().min(1),
    request_id: z.string().min(1),
  }),
});
export type ErrorBody = z.infer<typeof ErrorBody>;

/** The empty /v1 router answers every request with this contract. */
export const notImplementedError = (
  requestId: string,
): { code: string; message: string; request_id: string } => ({
  code: ErrorCode.NOT_IMPLEMENTED,
  message: "No /v1 resources are implemented yet.",
  request_id: requestId,
});

// Versioned API contracts (ARC-011).
export * from "./v1";
