import type { Context, Env } from "hono";
import {
  ErrorCode,
  type ErrorCodeType,
  type ProblemFieldType,
} from "@studafy/contracts";

const BASE = "https://api.studafy.io/problems";

const DEFINITIONS: Record<
  ErrorCodeType,
  { title: string; detail: string }
> = {
  NOT_FOUND: { title: "Not found", detail: "No such resource." },
  NOT_IMPLEMENTED: {
    title: "Not implemented",
    detail: "This API resource is not available.",
  },
  INTERNAL_ERROR: {
    title: "Internal error",
    detail: "An unexpected error occurred.",
  },
  UNAUTHENTICATED: {
    title: "Authentication required",
    detail: "Authentication required.",
  },
  REAUTH_REQUIRED: {
    title: "Recent authentication required",
    detail: "Confirm it is you before continuing.",
  },
  MFA_REQUIRED: {
    title: "Two-factor authentication required",
    detail: "Two-factor authentication is required for this action.",
  },
  FORBIDDEN: {
    title: "Forbidden",
    detail: "You do not have access to this resource.",
  },
  RATE_LIMITED: { title: "Too many requests", detail: "Try again later." },
  INVALID_REQUEST: {
    title: "Invalid request",
    detail: "The request could not be processed.",
  },
  INVALID_HEADER: {
    title: "Invalid header",
    detail: "A request header is invalid or ambiguous.",
  },
  METHOD_NOT_ALLOWED: {
    title: "Method not allowed",
    detail: "The request method is not supported.",
  },
  UNSUPPORTED_MEDIA_TYPE: {
    title: "Unsupported media type",
    detail: "Requests with a body must use application/json.",
  },
  PAYLOAD_TOO_LARGE: {
    title: "Payload too large",
    detail: "The request body exceeds the allowed size.",
  },
  REQUEST_TIMEOUT: {
    title: "Request timeout",
    detail: "The request did not complete in time.",
  },
  SERVICE_UNAVAILABLE: {
    title: "Service unavailable",
    detail: "A required service is temporarily unavailable.",
  },
  CONFLICT: {
    title: "Conflict",
    detail: "The request conflicts with the current state.",
  },
  VERSION_CONFLICT: {
    title: "Version conflict",
    detail: "The resource changed since it was read.",
  },
  INVALID_STATE: {
    title: "Invalid state",
    detail: "The command is not valid in the resource's current state.",
  },
  WINDOW_CLOSED: {
    title: "Submission window closed",
    detail: "The server-enforced submission window has closed.",
  },
  CURSOR_INVALID: {
    title: "Invalid cursor",
    detail: "The cursor is invalid or does not match this query.",
  },
  IDEMPOTENCY_KEY_REQUIRED: {
    title: "Idempotency key required",
    detail: "This operation requires an Idempotency-Key header.",
  },
  IDEMPOTENCY_KEY_NOT_ALLOWED: {
    title: "Idempotency key not allowed",
    detail: "This operation does not accept an Idempotency-Key header.",
  },
  IDEMPOTENCY_KEY_REUSED: {
    title: "Idempotency key reused",
    detail: "The idempotency key was already used for a different request.",
  },
  IDEMPOTENCY_IN_PROGRESS: {
    title: "Request in progress",
    detail: "A request with this idempotency key is still in progress.",
  },
  UPLOAD_QUOTA_EXCEEDED: {
    title: "Upload quota exceeded",
    detail: "The upload quota has been exhausted.",
  },
  UPLOAD_CONCURRENCY_LIMIT: {
    title: "Too many active uploads",
    detail: "Complete or wait for an active upload before starting another.",
  },
  UPLOAD_EXPIRED: {
    title: "Upload expired",
    detail: "The upload intent has expired.",
  },
  UPLOAD_ALREADY_COMPLETED: {
    title: "Upload already completed",
    detail: "The upload intent has already been completed.",
  },
  UPLOAD_INCOMPLETE: {
    title: "Upload incomplete",
    detail: "The expected object has not arrived in private storage.",
  },
  UPLOAD_SIZE_MISMATCH: {
    title: "Upload size mismatch",
    detail: "The uploaded object size does not match the reservation.",
  },
  UPLOAD_TYPE_MISMATCH: {
    title: "Upload type mismatch",
    detail: "The uploaded bytes do not match the declared file type.",
  },
  UPLOAD_CHECKSUM_MISMATCH: {
    title: "Upload checksum mismatch",
    detail: "The uploaded object checksum does not match the reservation.",
  },
  FILE_NOT_CLEAN: {
    title: "File unavailable",
    detail: "The file has not passed security processing.",
  },
  FILE_DELIVERY_DISABLED: {
    title: "File delivery disabled",
    detail:
      "File delivery remains disabled until secure processing is available.",
  },
  FILE_PUBLISH_DISABLED: {
    title: "File publication disabled",
    detail: "File publication is currently disabled.",
  },
  DELIVERY_GRANT_INVALID: {
    title: "Download link invalid",
    detail:
      "The download link is expired, already used, or not valid for this account.",
  },
  STORAGE_UNAVAILABLE: {
    title: "Storage unavailable",
    detail: "Private file storage is temporarily unavailable.",
  },
  RECEIPT_INVALID: {
    title: "Purchase could not be verified",
    detail: "The store could not verify this purchase.",
  },
  BENEFICIARY_LINK_INVALID: {
    title: "Guardian link invalid",
    detail: "No verified, unexpired guardian link exists for this student.",
  },
  PARENTAL_GATE_REQUIRED: {
    title: "Guardian approval required",
    detail:
      "A linked guardian must approve this purchase before it can continue.",
  },
  MESSAGING_DISABLED: {
    title: "Messaging is off",
    detail: "This school has not turned on messaging.",
  },
  CONTACT_NOT_ALLOWED: {
    title: "Contact not allowed",
    detail: "You cannot message this person in this school.",
  },
  GUARDIAN_LINK_REQUIRED: {
    title: "Guardian link required",
    detail:
      "A verified guardian must be linked before a student can request a purchase.",
  },
  STUDENT_PURCHASE_DISABLED: {
    title: "Student purchases disabled",
    detail: "This school has not enabled student self-purchase.",
  },
  ENTITLEMENT_OWNED_BY_OTHER_ACCOUNT: {
    title: "Owned by another account",
    detail: "This purchase belongs to a different Studafy account.",
  },
  PRODUCT_NOT_FOUND: {
    title: "Product not available",
    detail: "This product is not currently offered.",
  },
};

export class RequestTimeoutError extends Error {
  constructor() {
    super("request deadline exceeded");
    this.name = "RequestTimeoutError";
  }
}

export interface ProblemOptions {
  detail?: string;
  errors?: ProblemFieldType[];
}

export function problemBody(
  code: ErrorCodeType,
  status: number,
  requestId: string,
  options: ProblemOptions = {},
) {
  const definition = DEFINITIONS[code];
  return {
    type: `${BASE}/${code.toLowerCase().replaceAll("_", "-")}`,
    title: definition.title,
    status,
    code,
    detail: options.detail ?? definition.detail,
    requestId,
    ...(options.errors?.length ? { errors: options.errors.slice(0, 16) } : {}),
  };
}

export function problem<E extends Env>(
  c: Context<E>,
  code: ErrorCodeType,
  status:
    | 400
    | 401
    | 403
    | 404
    | 405
    | 409
    | 413
    | 415
    | 422
    | 429
    | 500
    | 503
    | 504,
  options: ProblemOptions = {},
): Response {
  const requestId = (c.var as { requestId?: unknown }).requestId;
  return c.json(
    problemBody(
      code,
      status,
      typeof requestId === "string" ? requestId : crypto.randomUUID(),
      options,
    ),
    status,
    { "Content-Type": "application/problem+json; charset=UTF-8" },
  ) as Response;
}

export { ErrorCode };
