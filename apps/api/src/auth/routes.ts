/**
 * AUTH-030 `/v1` session lifecycle routes.
 *
 * Every handler reads identity from `c.var.actor`, which the middleware
 * derived from a verified token plus the database. No handler reads a user,
 * school, or role from the request.
 */
import { Hono } from "hono";
import {
  V1AuthDeviceRevokeRequest,
  V1AuthSignOutRequest,
  V1DeletionRequestRequest,
  V1IdentityLinkRequest,
  V1IdentityUnlinkRequest,
  V1ReauthChallengeRequest,
  V1ReauthVerifyRequest,
} from "@studafy/contracts";
import {
  type AuthDependencies,
  type AuthEnv,
  createAuthMiddleware,
  recordAuthEvent,
  requireAal2,
  requireRecentAuth,
  sha256Hex,
} from "./middleware";
import { conflict, invalidRequest } from "./errors";

/** Parses a JSON body against a contract, returning null on any mismatch. */
async function parseBody<T>(
  c: { req: { json: () => Promise<unknown> } },
  schema: { safeParse: (value: unknown) => { success: boolean; data?: T } },
): Promise<T | null> {
  let raw: unknown;
  try {
    raw = await c.req.json();
  } catch {
    return null;
  }
  const result = schema.safeParse(raw);
  return result.success ? (result.data as T) : null;
}

/** 43 base64url characters is 32 bytes of entropy. */
function opaqueGrant(): string {
  const bytes = crypto.getRandomValues(new Uint8Array(32));
  return btoa(String.fromCharCode(...bytes))
    .replaceAll("+", "-")
    .replaceAll("/", "_")
    .replace(/=+$/, "");
}

export function createAuthRoutes(deps: AuthDependencies): Hono<AuthEnv> {
  const routes = new Hono<AuthEnv>();

  routes.use("*", createAuthMiddleware(deps));

  // ------------------------------------------------------------------
  // Identity and context
  // ------------------------------------------------------------------

  routes.get("/v1/me", (c) => {
    const { context } = c.get("actor");
    return c.json({
      id: context.userId,
      display_name: context.displayName,
      memberships: context.memberships.map((membership) => ({
        id: membership.id,
        school_id: membership.school_id,
        school_name: membership.school_name,
        role: membership.role,
        active: membership.active,
      })),
      active_term_id: context.memberships[0]?.active_term_id ?? null,
    });
  });

  routes.get("/v1/auth/context", (c) => {
    const actor = c.get("actor");
    return c.json({
      user_id: actor.context.userId,
      display_name: actor.context.displayName,
      locale: actor.context.locale,
      memberships: actor.context.memberships.map((membership) => ({
        id: membership.id,
        school_id: membership.school_id,
        school_name: membership.school_name,
        school_timezone: membership.school_timezone,
        role: membership.role,
        active_term_id: membership.active_term_id,
      })),
      membership_version: actor.context.membershipVersion,
      assurance_level: actor.aal2 ? "aal2" : "aal1",
      mfa_enrolled: actor.context.mfaEnrolled,
      mfa_required: actor.mfaRequiredByPolicy,
      pending_deletion: actor.context.deletionState !== null,
    });
  });

  // ------------------------------------------------------------------
  // Devices and sign-out
  // ------------------------------------------------------------------

  routes.get("/v1/auth/devices", async (c) => {
    const actor = c.get("actor");
    const devices = await deps.repository.listDevices(actor.token.subject);
    // "current" is resolved from the device header rather than stored, so a
    // stale server-side notion of the current device cannot mislabel a row.
    const currentHash = c.req.header("x-studafy-device");
    const currentDigest = currentHash ? await sha256Hex(currentHash) : null;
    return c.json({
      devices: devices.map((device) => ({
        id: device.id,
        platform: device.platform,
        app_version: device.app_version,
        display_label: device.display_label,
        first_seen_at: device.first_seen_at,
        last_seen_at: device.last_seen_at,
        revoked_at: device.revoked_at,
        current: currentDigest !== null && device.id === currentDigest
          ? true
          : false,
      })),
    });
  });

  routes.post(
    "/v1/auth/devices/revoke",
    requireRecentAuth(deps, "device_revoke"),
    async (c) => {
      const actor = c.get("actor");
      const body = await parseBody(c, V1AuthDeviceRevokeRequest);
      if (!body) return c.json(invalidRequest(c.get("requestId")), 400);

      const revoked = await deps.repository.revokeDevice(
        actor.token.subject,
        body.device_id,
      );
      await recordAuthEvent(deps, actor.token.subject, {
        eventType: "device_revoked",
        outcome: revoked ? "allowed" : "denied",
        reasonCode: revoked ? "user_revoked" : "not_owned_or_already_revoked",
        requestId: c.get("requestId"),
      });
      // The same answer whether the device belonged to someone else or was
      // already revoked: a distinguishable response would enumerate devices.
      return c.json({ revoked });
    },
  );

  routes.post("/v1/auth/sign-out", async (c) => {
    const actor = c.get("actor");
    const body = await parseBody(c, V1AuthSignOutRequest);
    if (!body) return c.json(invalidRequest(c.get("requestId")), 400);

    if (body.scope === "current") {
      // The current session's refresh token is revoked by the client's own
      // Supabase sign-out; the server records the event and nothing more.
      await recordAuthEvent(deps, actor.token.subject, {
        eventType: "session_revoked",
        outcome: "allowed",
        reasonCode: "current_device_sign_out",
        requestId: c.get("requestId"),
      });
      return c.json({ scope: "current", revoked_before: null });
    }

    const watermark = await deps.repository.signOutAll(actor.token.subject);
    await recordAuthEvent(deps, actor.token.subject, {
      eventType: "all_device_sign_out",
      outcome: "allowed",
      reasonCode: "user_requested",
      requestId: c.get("requestId"),
    });
    return c.json({ scope: "all", revoked_before: watermark });
  });

  // ------------------------------------------------------------------
  // Recent authentication
  // ------------------------------------------------------------------

  routes.post("/v1/auth/reauth/challenge", async (c) => {
    const actor = c.get("actor");
    const body = await parseBody(c, V1ReauthChallengeRequest);
    if (!body) return c.json(invalidRequest(c.get("requestId")), 400);

    await recordAuthEvent(deps, actor.token.subject, {
      eventType: "reauth_challenged",
      outcome: "allowed",
      reasonCode: body.purpose,
      requestId: c.get("requestId"),
    });

    return c.json({
      purpose: body.purpose,
      required_assurance: actor.mfaRequiredByPolicy ? "aal2" : "aal1",
      expires_at: new Date(
        (deps.now?.() ?? Date.now()) + deps.reauthTtlSeconds * 1000,
      ).toISOString(),
    });
  });

  routes.post("/v1/auth/reauth/verify", async (c) => {
    const actor = c.get("actor");
    const body = await parseBody(c, V1ReauthVerifyRequest);
    if (!body) return c.json(invalidRequest(c.get("requestId")), 400);

    const sessionId = actor.token.sessionId;
    if (!sessionId) return c.json(invalidRequest(c.get("requestId")), 400);

    // A grant is only minted when the session already satisfies the assurance
    // its roles demand; otherwise the challenge would be a formality.
    if (actor.mfaRequiredByPolicy && !actor.aal2) {
      return c.json(
        {
          error: {
            code: "MFA_REQUIRED",
            message: "Two-factor authentication is required for this action.",
            request_id: c.get("requestId"),
          },
        },
        403,
      );
    }

    const grant = opaqueGrant();
    const expiresAt = await deps.repository.issueReauthGrant(
      actor.token.subject,
      {
        purpose: body.purpose,
        grantHash: await sha256Hex(grant),
        sessionId,
        assuranceLevel: actor.aal2 ? "aal2" : "aal1",
        ttlSeconds: deps.reauthTtlSeconds,
      },
    );
    if (!expiresAt) return c.json(invalidRequest(c.get("requestId")), 400);

    return c.json({
      purpose: body.purpose,
      grant,
      expires_at: new Date(expiresAt).toISOString(),
    });
  });

  // ------------------------------------------------------------------
  // Identity linking
  // ------------------------------------------------------------------

  routes.post(
    "/v1/auth/identities/link",
    requireAal2(),
    requireRecentAuth(deps, "account_link"),
    async (c) => {
      const actor = c.get("actor");
      const body = await parseBody(c, V1IdentityLinkRequest);
      if (!body) return c.json(invalidRequest(c.get("requestId")), 400);

      // The provider's id token is verified before anything is linked, so a
      // caller cannot claim an identity it does not control.
      const providerSubject = await deps.verifyProviderIdentity?.(
        body.provider,
        body.id_token,
      );
      if (!providerSubject) {
        await recordAuthEvent(deps, actor.token.subject, {
          eventType: "identity_link_collision",
          outcome: "denied",
          reasonCode: "provider_token_invalid",
          requestId: c.get("requestId"),
        });
        return c.json(invalidRequest(c.get("requestId")), 400);
      }

      const outcome = await deps.repository.linkIdentity(
        actor.token.subject,
        body.provider,
        providerSubject,
        body.make_primary,
      );
      await recordAuthEvent(deps, actor.token.subject, {
        eventType: outcome === "collision"
          ? "identity_link_collision"
          : "identity_linked",
        outcome: outcome === "collision" ? "denied" : "allowed",
        reasonCode: outcome,
        method: body.provider,
        requestId: c.get("requestId"),
      });

      if (outcome === "collision") {
        return c.json(
          conflict(
            c.get("requestId"),
            "That sign-in method is already in use. Contact your school to merge accounts.",
          ),
          409,
        );
      }
      return c.json({ outcome });
    },
  );

  routes.post(
    "/v1/auth/identities/unlink",
    requireAal2(),
    requireRecentAuth(deps, "account_link"),
    async (c) => {
      const actor = c.get("actor");
      const body = await parseBody(c, V1IdentityUnlinkRequest);
      if (!body) return c.json(invalidRequest(c.get("requestId")), 400);

      const outcome = await deps.repository.unlinkIdentity(
        actor.token.subject,
        body.provider,
        body.subject,
      );
      await recordAuthEvent(deps, actor.token.subject, {
        eventType: "identity_unlinked",
        outcome: outcome === "unlinked" ? "allowed" : "denied",
        reasonCode: outcome,
        method: body.provider,
        requestId: c.get("requestId"),
      });
      return c.json({ outcome });
    },
  );

  // ------------------------------------------------------------------
  // Account deletion
  // ------------------------------------------------------------------

  routes.get("/v1/account/deletion-impact", async (c) => {
    const actor = c.get("actor");
    const impact = await deps.repository.deletionImpact(actor.token.subject);
    if (!impact) return c.json(invalidRequest(c.get("requestId")), 400);
    return c.json({ ...impact, grace_period_days: deps.deletionGraceDays });
  });

  routes.post(
    "/v1/account/deletion-request",
    requireRecentAuth(deps, "account_deletion"),
    async (c) => {
      const actor = c.get("actor");
      const body = await parseBody(c, V1DeletionRequestRequest);
      if (!body) return c.json(invalidRequest(c.get("requestId")), 400);

      // The impact is recomputed server-side and stored with the request, so
      // the record shows what was true at confirmation rather than whatever
      // the client happened to be displaying.
      const impact = await deps.repository.deletionImpact(actor.token.subject);
      const result = await deps.repository.requestDeletion(
        actor.token.subject,
        body.reason_code,
        impact,
        deps.deletionGraceDays,
      );
      if (!result) return c.json(invalidRequest(c.get("requestId")), 400);

      await recordAuthEvent(deps, actor.token.subject, {
        eventType: "account_deletion_requested",
        outcome: "allowed",
        reasonCode: body.reason_code,
        requestId: c.get("requestId"),
      });
      return c.json({
        id: result.id,
        state: result.state,
        execute_after: new Date(result.execute_after).toISOString(),
        created: result.created,
      });
    },
  );

  // Cancellation deliberately requires no recent-auth grant. Stopping a
  // destructive action is the safe direction, and adding friction here would
  // strand a user who cannot re-authenticate before the grace period ends.
  routes.post("/v1/account/deletion-cancel", async (c) => {
    const actor = c.get("actor");
    const cancelled = await deps.repository.cancelDeletion(
      actor.token.subject,
    );
    await recordAuthEvent(deps, actor.token.subject, {
      eventType: "account_deletion_cancelled",
      outcome: cancelled ? "allowed" : "denied",
      reasonCode: cancelled ? "user_cancelled" : "no_live_request",
      requestId: c.get("requestId"),
    });
    return c.json({ cancelled });
  });

  return routes;
}
