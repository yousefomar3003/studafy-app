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
  RECENT_SIGN_IN_REQUIRED: {
    title: "Sign in again",
    detail: "Sign in again to confirm it is you, then try once more.",
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
  // Since DL-071 only a retired student product (Student Notebook, Student
  // AI) can reach this; Studafy Plus and Max need no approval.
  PARENTAL_GATE_REQUIRED: {
    title: "Not sold to students",
    detail: "This product can no longer be bought from a student account.",
  },
  MESSAGING_DISABLED: {
    title: "Messaging is off",
    detail: "This school has not turned on messaging.",
  },
  CONTACT_NOT_ALLOWED: {
    title: "Contact not allowed",
    detail: "You cannot message this person in this school.",
  },
  // Distinct from FORBIDDEN so the app can tell "prove you are a person" from
  // "you may not", and show the check only when this server wants one. The
  // app used to decide from a build flag, and a flag that disagreed with the
  // server opened a challenge page that did not exist.
  CAPTCHA_REQUIRED: {
    title: "Security check required",
    detail: "Complete the security check, then try again.",
  },
  PLAN_REQUIRED: {
    title: "Plan required",
    detail: "This needs Studafy Plus or Studafy Max.",
  },
  AI_ALLOWANCE_USED: {
    title: "AI allowance used",
    detail:
      "The AI usage limit for this plan has been reached. It resets on the plan's reset date, or a bigger plan gives more.",
  },
  AI_REQUEST_IN_PROGRESS: {
    title: "Already being answered",
    detail: "This request is still being answered.",
  },
  MATERIAL_PROCESSING: {
    title: "Material still being read",
    detail:
      "The lesson's files are still being read. Try again in a minute so nothing is left out.",
  },
  MATERIAL_UNAVAILABLE: {
    title: "Some chosen material cannot be used",
    detail:
      "Some of the chosen files or links cannot be used right now. Try again later, or continue without them.",
  },
  AI_FEATURE_DISABLED: {
    title: "Not available",
    detail: "This feature is not available yet.",
  },
  AI_STUDENTS_ONLY: {
    title: "For students",
    detail:
      "The AI study tools are for student accounts. Parent and teacher accounts cannot use them.",
  },
  AI_CONSENT_REQUIRED: {
    title: "AI consent required",
    detail:
      "Read and agree to the AI study tools notice before using them. They can be turned off at any time.",
  },
  AI_GUARDIAN_CONSENT_REQUIRED: {
    title: "A parent's consent is required",
    detail:
      "The parent who manages this account turns the AI study tools on for it, from their own account.",
  },
  PHOTO_NOT_READY: {
    title: "Photo still being checked",
    detail: "The photo is still being checked. Try again in a moment.",
  },
  PHOTO_UNREADABLE: {
    title: "Nothing to read",
    detail: "No writing could be read in that photo. Try a clearer one.",
  },
  LESSON_HAS_NO_TEXT: {
    title: "Nothing to study from",
    detail: "This lesson has no text to make a quiz or flashcards from.",
  },
  GUARDIAN_LINK_REQUIRED: {
    title: "Guardian link required",
    detail: "A verified guardian link is required for this.",
  },
  STUDENT_PURCHASE_DISABLED: {
    title: "Student purchases disabled",
    detail: "This school has turned off student purchases.",
  },
  PURCHASE_APPROVAL_RETIRED: {
    title: "No approval needed",
    detail:
      "Purchases no longer need a parent's approval in Studafy. Update the app to subscribe.",
  },
  ENTITLEMENT_OWNED_BY_OTHER_ACCOUNT: {
    title: "Owned by another account",
    detail: "This purchase belongs to a different Studafy account.",
  },
  PRODUCT_NOT_FOUND: {
    title: "Product not available",
    detail: "This product is not currently offered.",
  },
  MANAGED_CHILD_LIMIT: {
    title: "Child account limit reached",
    detail: "One account can manage up to six child accounts.",
  },
  GRADE_ENTRIES_INVALID: {
    title: "Some entries were refused",
    detail: "Nothing was saved. The errors list which rows to fix and why.",
  },
  REASON_REQUIRED: {
    title: "Reason required",
    detail: "Changing this record needs a reason, which is kept with it.",
  },
  ATTENDANCE_LOCKED: {
    title: "Register locked",
    detail: "This register is locked by the school's attendance policy.",
  },
  SUBMISSION_LOCKED: {
    title: "Work already marked",
    detail: "This work has a published mark and cannot be replaced.",
  },
  ATTACHMENT_REFUSED: {
    title: "An attachment was refused",
    detail:
      "Nothing was saved. The errors list which files or links to remove and why.",
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
  // For the access log: which refusal, and which fields - never their
  // values - so a 4xx in the logs says why without a reproduction.
  (c as unknown as { set(key: string, value: unknown): void }).set(
    "problem",
    {
      code,
      fields: (options.errors ?? []).slice(0, 16).map((error) =>
        `${error.path}:${error.code}`
      ),
    },
  );
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
