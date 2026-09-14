/**
 * AUTH-030 authentication and recent-auth middleware.
 *
 * `requireAuth` is the only place a request becomes authenticated. It
 * verifies the token, loads the database context, and evaluates revocation;
 * a handler downstream can assume `c.var.actor` is a live, non-suspended,
 * non-revoked identity whose roles came from `public.memberships`.
 */
import type { Context, MiddlewareHandler } from "hono";
import type { Logger } from "@studafy/observability";
import {
  type AuthContextRepository,
  evaluateSession,
  type SessionContext,
} from "./context";
import type { CryptoData, JwksKeySource } from "./jwks";
import {
  bearerToken,
  TokenError,
  type VerifiedToken,
  verifyAccessToken,
} from "./verify";
import {
  type AuthDenialReason,
  denyUnauthenticated,
  mfaRequired,
  reauthRequired,
} from "./errors";

export interface Actor {
  token: VerifiedToken;
  context: SessionContext;
  /** True when the token proves a second factor was used for this session. */
  aal2: boolean;
  /** True when any active membership requires MFA by policy. */
  mfaRequiredByPolicy: boolean;
}

export interface AuthEnv {
  Variables: {
    requestId: string;
    actor: Actor;
    authDenialReason?: string;
  };
}

export interface AuthDependencies {
  keys: JwksKeySource;
  repository: AuthContextRepository;
  logger: Logger;
  issuer: string;
  audience: string;
  clockSkewSeconds: number;
  revocationBudgetSeconds: number;
  reauthTtlSeconds: number;
  deletionGraceDays: number;
  now?: () => number;
  /**
   * Verifies a provider id token and returns its subject, or null.
   *
   * Injected rather than implemented here because each provider has its own
   * issuer, audience, and key set. Absent it, identity linking refuses
   * everything — the correct default for an unconfigured provider.
   */
  verifyProviderIdentity?: (
    provider: string,
    idToken: string,
  ) => Promise<string | null>;
}

/**
 * Roles for which a second factor is mandatory.
 *
 * School administrators can read and export every record in a school, so an
 * admin session behind one reusable provider credential is the highest-value
 * target in the product.
 */
const MFA_REQUIRED_ROLES = new Set(["school_admin"]);

function tokenRejectionReason(error: unknown): AuthDenialReason {
  if (error instanceof TokenError) {
    switch (error.rejection) {
      case "malformed":
        return "malformed_token";
      case "unsupported_algorithm":
        return "unsupported_algorithm";
      case "unknown_key":
        return "unknown_key";
      case "bad_signature":
        return "bad_signature";
      case "expired":
        return "expired";
      case "not_yet_valid":
        return "not_yet_valid";
      case "wrong_issuer":
        return "wrong_issuer";
      case "wrong_audience":
        return "wrong_audience";
      case "missing_subject":
        return "missing_subject";
    }
  }
  return "jwks_unavailable";
}

/** Coarse client family. Never the full user-agent, which is identifying. */
export function userAgentFamily(header: string | undefined | null): string {
  if (!header) return "unknown";
  if (/Dart|Flutter/i.test(header)) return "flutter";
  if (/Android/i.test(header)) return "android";
  if (/iPhone|iPad|CFNetwork|Darwin/i.test(header)) return "ios";
  if (/Mozilla/i.test(header)) return "browser";
  return "other";
}

export function createAuthMiddleware(
  deps: AuthDependencies,
): MiddlewareHandler<AuthEnv> {
  return async (c, next) => {
    const requestId = c.get("requestId");
    const token = bearerToken(c.req.header("authorization"));

    if (!token) {
      logDenial(deps, c, "no_credentials");
      return denyUnauthenticated(c, "no_credentials");
    }

    let verified: VerifiedToken;
    try {
      verified = await verifyAccessToken(token, {
        keys: deps.keys,
        issuer: deps.issuer,
        audience: deps.audience,
        clockSkewSeconds: deps.clockSkewSeconds,
        ...(deps.now ? { now: deps.now } : {}),
      });
    } catch (error) {
      const reason = tokenRejectionReason(error);
      logDenial(deps, c, reason);
      await recordDenial(deps, null, reason, requestId, c);
      return denyUnauthenticated(c, reason);
    }

    const context = await deps.repository.load(verified.subject);
    const decision = evaluateSession(
      verified,
      context,
      deps.revocationBudgetSeconds,
    );
    if (!decision.allowed) {
      logDenial(deps, c, decision.reason);
      await recordDenial(deps, verified.subject, decision.reason, requestId, c);
      return denyUnauthenticated(c, decision.reason);
    }

    const mfaRequiredByPolicy = decision.context.memberships.some((
      membership,
    ) => MFA_REQUIRED_ROLES.has(membership.role));

    c.set("actor", {
      token: verified,
      context: decision.context,
      aal2: verified.assuranceLevel === "aal2",
      mfaRequiredByPolicy,
    });

    await next();
  };
}

/**
 * Refuses a privileged action unless the session actually carries the second
 * factor its roles require. Enrolment alone is not enough — a session that
 * only ever presented one factor stays at aal1.
 */
export function requireAal2(): MiddlewareHandler<AuthEnv> {
  return async (c, next) => {
    const actor = c.get("actor");
    if (actor.mfaRequiredByPolicy && !actor.aal2) {
      return c.json(mfaRequired(c.get("requestId")), 403);
    }
    await next();
  };
}

/**
 * Requires a single-use recent-auth grant for this exact purpose.
 *
 * The grant is consumed here, so a replay of the same request fails even if
 * the first attempt errored downstream. That is the intended trade: a user
 * who hits a server error re-confirms rather than leaving a redeemable grant
 * in play.
 */
export function requireRecentAuth(
  deps: AuthDependencies,
  purpose: string,
): MiddlewareHandler<AuthEnv> {
  return async (c, next) => {
    const actor = c.get("actor");
    const requestId = c.get("requestId");
    const presented = c.req.header("x-studafy-reauth");
    const sessionId = actor.token.sessionId;

    if (!presented || !sessionId) {
      await recordAuthEvent(deps, actor.token.subject, {
        eventType: "privileged_action_denied",
        outcome: "denied",
        reasonCode: "reauth_missing",
        requestId,
      });
      return c.json(reauthRequired(requestId), 401);
    }

    const consumed = await deps.repository.consumeReauthGrant(
      actor.token.subject,
      {
        purpose,
        grantHash: await sha256Hex(presented),
        sessionId,
        requestId,
      },
    );

    if (!consumed) {
      await recordAuthEvent(deps, actor.token.subject, {
        eventType: "reauth_failed",
        outcome: "denied",
        reasonCode: "reauth_invalid",
        requestId,
      });
      return c.json(reauthRequired(requestId), 401);
    }

    await recordAuthEvent(deps, actor.token.subject, {
      eventType: "reauth_verified",
      outcome: "allowed",
      reasonCode: purpose,
      requestId,
    });
    await next();
  };
}

export async function sha256Hex(value: string): Promise<string> {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(value) as unknown as CryptoData,
  );
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

function logDenial(
  deps: AuthDependencies,
  c: Context<AuthEnv>,
  reason: AuthDenialReason,
): void {
  // The reason is safe to log: it describes the check, never the account.
  deps.logger.warn("auth_denied", {
    request_id: c.get("requestId"),
    method: c.req.method,
    path: c.req.path,
    reason,
  });
}

async function recordDenial(
  deps: AuthDependencies,
  subject: string | null,
  reason: AuthDenialReason,
  requestId: string,
  c: Context<AuthEnv>,
): Promise<void> {
  await recordAuthEvent(deps, subject, {
    eventType: subject ? "session_revoked" : "token_verification_failed",
    outcome: "denied",
    reasonCode: reason,
    requestId,
    userAgentFamily: userAgentFamily(c.req.header("user-agent")),
  });
}

/**
 * Security-event writes must never turn a denial into a 500, so a storage
 * failure is logged and swallowed.
 */
export async function recordAuthEvent(
  deps: AuthDependencies,
  subject: string | null,
  event: {
    eventType: string;
    outcome: "allowed" | "denied";
    reasonCode: string;
    requestId: string;
    method?: string;
    assuranceLevel?: string;
    userAgentFamily?: string;
    schoolId?: string;
  },
): Promise<void> {
  try {
    await deps.repository.recordEvent({
      subject,
      eventType: event.eventType,
      outcome: event.outcome,
      reasonCode: event.reasonCode,
      requestId: event.requestId,
      method: event.method ?? null,
      assuranceLevel: event.assuranceLevel ?? null,
      userAgentFamily: event.userAgentFamily ?? null,
      schoolId: event.schoolId ?? null,
    });
  } catch (error) {
    deps.logger.error("auth_event_write_failed", {
      request_id: event.requestId,
      event_type: event.eventType,
      error_message: error instanceof Error ? error.message : String(error),
    });
  }
}
