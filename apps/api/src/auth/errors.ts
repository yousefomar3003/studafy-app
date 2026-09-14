/**
 * AUTH-030 authentication error surface.
 *
 * Every way authentication can fail — no header, malformed token, bad
 * signature, expired, revoked device, signed-out session, suspended profile,
 * deleted account, user that never existed — produces one byte-identical
 * response apart from the request id. The private reason is logged, never
 * returned.
 *
 * This is deliberate: an API that answers "unknown account" differently from
 * "wrong credential" is an account-existence oracle, and for a product whose
 * users are schoolchildren, confirming that a given email is a Studafy user
 * is itself a disclosure.
 */
import type { Context } from "hono";
import { problem, problemBody } from "../platform/errors";

/** Private reasons. These reach logs and metrics; they never reach a client. */
export type AuthDenialReason =
  | "no_credentials"
  | "malformed_token"
  | "unsupported_algorithm"
  | "unknown_key"
  | "bad_signature"
  | "expired"
  | "not_yet_valid"
  | "wrong_issuer"
  | "wrong_audience"
  | "missing_subject"
  | "jwks_unavailable"
  | "no_profile"
  | "profile_suspended"
  | "profile_deleted"
  | "session_revoked"
  | "device_revoked"
  | "deletion_in_progress";

/** The single message every authentication failure returns. */
export const UNAUTHENTICATED_MESSAGE = "Authentication required.";

export interface AuthErrorBody {
  type: string;
  title: string;
  status: number;
  code: string;
  detail: string;
  requestId: string;
}

export function unauthenticated(requestId: string): AuthErrorBody {
  return problemBody("UNAUTHENTICATED", 401, requestId) as AuthErrorBody;
}

export function forbidden(requestId: string): AuthErrorBody {
  return problemBody("FORBIDDEN", 403, requestId) as AuthErrorBody;
}

export function reauthRequired(requestId: string): AuthErrorBody {
  return problemBody("REAUTH_REQUIRED", 401, requestId) as AuthErrorBody;
}

export function mfaRequired(requestId: string): AuthErrorBody {
  return problemBody("MFA_REQUIRED", 403, requestId) as AuthErrorBody;
}

export function invalidRequest(requestId: string): AuthErrorBody {
  return problemBody("INVALID_REQUEST", 400, requestId) as AuthErrorBody;
}

export function conflict(requestId: string, message: string): AuthErrorBody {
  return problemBody("CONFLICT", 409, requestId, {
    detail: message,
  }) as AuthErrorBody;
}

/**
 * Denies a request uniformly.
 *
 * `reason` is recorded against the request for the log line; the response is
 * identical whichever reason applied.
 */
export function denyUnauthenticated<
  E extends {
    Variables: { requestId: string; authDenialReason?: string | undefined };
  },
>(
  c: Context<E>,
  reason: AuthDenialReason,
): Response {
  c.set("authDenialReason", reason);
  // WWW-Authenticate carries no error detail for the same reason the body
  // does not: `error_description` would reintroduce the oracle.
  c.header("WWW-Authenticate", 'Bearer realm="studafy"');
  return problem(c, "UNAUTHENTICATED", 401);
}
