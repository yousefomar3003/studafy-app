import { z } from "zod";

/** Stable machine codes used by every HTTP problem response. */
export const ErrorCode = {
  NOT_FOUND: "NOT_FOUND",
  NOT_IMPLEMENTED: "NOT_IMPLEMENTED",
  INTERNAL_ERROR: "INTERNAL_ERROR",
  UNAUTHENTICATED: "UNAUTHENTICATED",
  REAUTH_REQUIRED: "REAUTH_REQUIRED",
  MFA_REQUIRED: "MFA_REQUIRED",
  FORBIDDEN: "FORBIDDEN",
  RATE_LIMITED: "RATE_LIMITED",
  INVALID_REQUEST: "INVALID_REQUEST",
  INVALID_HEADER: "INVALID_HEADER",
  METHOD_NOT_ALLOWED: "METHOD_NOT_ALLOWED",
  UNSUPPORTED_MEDIA_TYPE: "UNSUPPORTED_MEDIA_TYPE",
  PAYLOAD_TOO_LARGE: "PAYLOAD_TOO_LARGE",
  REQUEST_TIMEOUT: "REQUEST_TIMEOUT",
  SERVICE_UNAVAILABLE: "SERVICE_UNAVAILABLE",
  CONFLICT: "CONFLICT",
  IDEMPOTENCY_KEY_REQUIRED: "IDEMPOTENCY_KEY_REQUIRED",
  IDEMPOTENCY_KEY_NOT_ALLOWED: "IDEMPOTENCY_KEY_NOT_ALLOWED",
  IDEMPOTENCY_KEY_REUSED: "IDEMPOTENCY_KEY_REUSED",
  IDEMPOTENCY_IN_PROGRESS: "IDEMPOTENCY_IN_PROGRESS",
  VERSION_CONFLICT: "VERSION_CONFLICT",
  INVALID_STATE: "INVALID_STATE",
  WINDOW_CLOSED: "WINDOW_CLOSED",
  CURSOR_INVALID: "CURSOR_INVALID",
} as const;
export type ErrorCode = (typeof ErrorCode)[keyof typeof ErrorCode];

export const ProblemField = z.strictObject({
  path: z.string().min(1).max(128),
  code: z.string().min(1).max(64),
});
export type ProblemField = z.infer<typeof ProblemField>;

/** RFC 9457 problem details with stable Studafy extensions. */
export const ProblemDetails = z.strictObject({
  type: z.string().url(),
  title: z.string().min(1).max(120),
  status: z.number().int().min(400).max(599),
  code: z.enum(Object.values(ErrorCode) as [ErrorCode, ...ErrorCode[]]),
  detail: z.string().min(1).max(300),
  requestId: z.string().uuid(),
  errors: z.array(ProblemField).max(16).optional(),
});
export type ProblemDetails = z.infer<typeof ProblemDetails>;

export const IdempotencyMode = z.enum(["none", "required", "forbidden"]);
export type IdempotencyMode = z.infer<typeof IdempotencyMode>;
