/**
 * AUTH-030 `/v1` session lifecycle routes.
 *
 * Every handler reads identity from `c.var.actor`, which the middleware
 * derived from a verified token plus the database. No handler reads a user,
 * school, or role from the request.
 */
import { Hono, type MiddlewareHandler } from "hono";
import {
  type V1AuthDeviceRevokeRequestType,
  type V1AuthSignOutRequestType,
  type V1DeletionRequestRequestType,
  type V1IdentityLinkRequestType,
  type V1IdentityUnlinkRequestType,
  type V1ReauthChallengeRequestType,
  type V1ReauthVerifyRequestType,
  v1Route,
} from "@studafy/contracts";
import {
  type AuthDependencies,
  createAuthMiddleware,
  recordAuthEvent,
  requireAal2,
  requireRecentAuth,
  sha256Hex,
} from "./middleware";
import type { AuthorizationEnv } from "../authorization/middleware";
import {
  type AuthorizationDependencies,
  createAuthorizationDependencies,
  requirePermission,
} from "../authorization/middleware";
import { problem } from "../platform/errors";
import {
  idempotency,
  type IdempotencyDependencies,
} from "../platform/idempotency";
import { validatedBody, validateRouteInput } from "../platform/validation";

/** 43 base64url characters is 32 bytes of entropy. */
function opaqueGrant(): string {
  const bytes = crypto.getRandomValues(new Uint8Array(32));
  return btoa(String.fromCharCode(...bytes))
    .replaceAll("+", "-")
    .replaceAll("/", "_")
    .replace(/=+$/, "");
}

export function createAuthRoutes(
  deps: AuthDependencies,
  authorization: AuthorizationDependencies = createAuthorizationDependencies(
    deps.logger,
  ),
  idempotencyDependencies: IdempotencyDependencies = { logger: deps.logger },
  academicRoutes?: Hono<AuthorizationEnv>,
): Hono<AuthorizationEnv> {
  const routes = new Hono<AuthorizationEnv>();

  // AuthorizationEnv extends AuthEnv with variables populated later in the
  // chain; authentication therefore remains the valid first middleware.
  routes.use(
    "*",
    createAuthMiddleware(deps) as unknown as MiddlewareHandler<
      AuthorizationEnv
    >,
  );

  // ------------------------------------------------------------------
  // Identity and context
  // ------------------------------------------------------------------

  routes.get(
    "/v1/me",
    validateRouteInput(v1Route("getMe")) as never,
    requirePermission(authorization, "account.profile.read"),
    (c) => {
      const { context } = c.get("actor");
      return c.json({
        id: context.userId,
        displayName: context.displayName,
        memberships: context.memberships.map((membership) => ({
          id: membership.id,
          schoolId: membership.school_id,
          schoolName: membership.school_name,
          role: membership.role,
          active: membership.active,
        })),
        activeTermId: context.memberships[0]?.active_term_id ?? null,
      });
    },
  );

  routes.get(
    "/v1/auth/context",
    validateRouteInput(v1Route("getAuthContext")) as never,
    requirePermission(authorization, "account.context.read"),
    (c) => {
      const actor = c.get("actor");
      return c.json({
        userId: actor.context.userId,
        displayName: actor.context.displayName,
        locale: actor.context.locale,
        memberships: actor.context.memberships.map((membership) => ({
          id: membership.id,
          schoolId: membership.school_id,
          schoolName: membership.school_name,
          schoolTimezone: membership.school_timezone,
          role: membership.role,
          activeTermId: membership.active_term_id,
        })),
        membershipVersion: actor.context.membershipVersion,
        assuranceLevel: actor.aal2 ? "aal2" : "aal1",
        mfaEnrolled: actor.context.mfaEnrolled,
        mfaRequired: actor.mfaRequiredByPolicy,
        pendingDeletion: actor.context.deletionState !== null,
      });
    },
  );

  // ------------------------------------------------------------------
  // Devices and sign-out
  // ------------------------------------------------------------------

  routes.get(
    "/v1/auth/devices",
    validateRouteInput(v1Route("listAuthDevices")) as never,
    requirePermission(authorization, "account.devices.read"),
    async (c) => {
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
          appVersion: device.app_version,
          displayLabel: device.display_label,
          firstSeenAt: device.first_seen_at,
          lastSeenAt: device.last_seen_at,
          revokedAt: device.revoked_at,
          current: currentDigest !== null && device.id === currentDigest
            ? true
            : false,
        })),
      });
    },
  );

  routes.post(
    "/v1/auth/devices/revoke",
    validateRouteInput(v1Route("revokeAuthDevice")) as never,
    requirePermission(authorization, "account.device.revoke"),
    idempotency(idempotencyDependencies, "revokeAuthDevice", "required"),
    requireRecentAuth(deps, "device_revoke"),
    async (c) => {
      const actor = c.get("actor");
      const body = validatedBody<V1AuthDeviceRevokeRequestType>(c as never);

      const revoked = await deps.repository.revokeDevice(
        actor.token.subject,
        body.deviceId,
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

  routes.post(
    "/v1/auth/sign-out",
    validateRouteInput(v1Route("signOut")) as never,
    requirePermission(authorization, "account.session.revoke"),
    idempotency(idempotencyDependencies, "signOut", "required"),
    async (c) => {
      const actor = c.get("actor");
      const body = validatedBody<V1AuthSignOutRequestType>(c as never);

      if (body.scope === "current") {
        // The current session's refresh token is revoked by the client's own
        // Supabase sign-out; the server records the event and nothing more.
        await recordAuthEvent(deps, actor.token.subject, {
          eventType: "session_revoked",
          outcome: "allowed",
          reasonCode: "current_device_sign_out",
          requestId: c.get("requestId"),
        });
        return c.json({ scope: "current", revokedBefore: null });
      }

      const watermark = await deps.repository.signOutAll(actor.token.subject);
      await recordAuthEvent(deps, actor.token.subject, {
        eventType: "all_device_sign_out",
        outcome: "allowed",
        reasonCode: "user_requested",
        requestId: c.get("requestId"),
      });
      return c.json({ scope: "all", revokedBefore: watermark });
    },
  );

  // ------------------------------------------------------------------
  // Recent authentication
  // ------------------------------------------------------------------

  routes.post(
    "/v1/auth/reauth/challenge",
    validateRouteInput(v1Route("challengeReauth")) as never,
    requirePermission(authorization, "account.reauth.challenge"),
    idempotency(idempotencyDependencies, "challengeReauth", "required"),
    async (c) => {
      const actor = c.get("actor");
      const body = validatedBody<V1ReauthChallengeRequestType>(c as never);

      await recordAuthEvent(deps, actor.token.subject, {
        eventType: "reauth_challenged",
        outcome: "allowed",
        reasonCode: body.purpose,
        requestId: c.get("requestId"),
      });

      return c.json({
        purpose: body.purpose,
        requiredAssurance: actor.mfaRequiredByPolicy ? "aal2" : "aal1",
        expiresAt: new Date(
          (deps.now?.() ?? Date.now()) + deps.reauthTtlSeconds * 1000,
        ).toISOString(),
      });
    },
  );

  routes.post(
    "/v1/auth/reauth/verify",
    validateRouteInput(v1Route("verifyReauth")) as never,
    requirePermission(authorization, "account.reauth.verify"),
    idempotency(idempotencyDependencies, "verifyReauth", "forbidden"),
    async (c) => {
      const actor = c.get("actor");
      const body = validatedBody<V1ReauthVerifyRequestType>(c as never);

      const sessionId = actor.token.sessionId;
      if (!sessionId) return problem(c, "INVALID_REQUEST", 400);

      // A grant is only minted when the session already satisfies the assurance
      // its roles demand; otherwise the challenge would be a formality.
      if (actor.mfaRequiredByPolicy && !actor.aal2) {
        return problem(c, "MFA_REQUIRED", 403);
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
      if (!expiresAt) return problem(c, "INVALID_REQUEST", 400);

      return c.json({
        purpose: body.purpose,
        grant,
        expiresAt: new Date(expiresAt).toISOString(),
      });
    },
  );

  // ------------------------------------------------------------------
  // Identity linking
  // ------------------------------------------------------------------

  routes.post(
    "/v1/auth/identities/link",
    validateRouteInput(v1Route("linkIdentity")) as never,
    requirePermission(authorization, "account.identity.link"),
    idempotency(idempotencyDependencies, "linkIdentity", "required"),
    requireAal2(),
    requireRecentAuth(deps, "account_link"),
    async (c) => {
      const actor = c.get("actor");
      const body = validatedBody<V1IdentityLinkRequestType>(c as never);

      // The provider's id token is verified before anything is linked, so a
      // caller cannot claim an identity it does not control.
      const providerSubject = await deps.verifyProviderIdentity?.(
        body.provider,
        body.idToken,
      );
      if (!providerSubject) {
        await recordAuthEvent(deps, actor.token.subject, {
          eventType: "identity_link_collision",
          outcome: "denied",
          reasonCode: "provider_token_invalid",
          requestId: c.get("requestId"),
        });
        return problem(c, "INVALID_REQUEST", 400);
      }

      const outcome = await deps.repository.linkIdentity(
        actor.token.subject,
        body.provider,
        providerSubject,
        body.makePrimary,
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
        return problem(c, "CONFLICT", 409, {
          detail:
            "That sign-in method is already in use. Contact your school to merge accounts.",
        });
      }
      return c.json({ outcome });
    },
  );

  routes.post(
    "/v1/auth/identities/unlink",
    validateRouteInput(v1Route("unlinkIdentity")) as never,
    requirePermission(authorization, "account.identity.unlink"),
    idempotency(idempotencyDependencies, "unlinkIdentity", "required"),
    requireAal2(),
    requireRecentAuth(deps, "account_link"),
    async (c) => {
      const actor = c.get("actor");
      const body = validatedBody<V1IdentityUnlinkRequestType>(c as never);

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

  routes.get(
    "/v1/account/deletion-impact",
    validateRouteInput(v1Route("getDeletionImpact")) as never,
    requirePermission(authorization, "account.deletion.impact"),
    async (c) => {
      const actor = c.get("actor");
      const impact = await deps.repository.deletionImpact(actor.token.subject);
      if (!impact) return problem(c, "INVALID_REQUEST", 400);
      const raw = impact as {
        memberships: { school_name: string; role: string }[];
        retained_school_records: Record<string, number>;
        deleted_personal_data: Record<string, number>;
        guardian_links: number;
        active_entitlements: number;
      };
      return c.json({
        memberships: raw.memberships.map((membership) => ({
          schoolName: membership.school_name,
          role: membership.role,
        })),
        retainedSchoolRecords: raw.retained_school_records,
        deletedPersonalData: raw.deleted_personal_data,
        guardianLinks: raw.guardian_links,
        activeEntitlements: raw.active_entitlements,
        gracePeriodDays: deps.deletionGraceDays,
      });
    },
  );

  routes.post(
    "/v1/account/deletion-request",
    validateRouteInput(v1Route("requestAccountDeletion")) as never,
    requirePermission(authorization, "account.deletion.request"),
    idempotency(idempotencyDependencies, "requestAccountDeletion", "required"),
    requireRecentAuth(deps, "account_deletion"),
    async (c) => {
      const actor = c.get("actor");
      const body = validatedBody<V1DeletionRequestRequestType>(c as never);

      // The impact is recomputed server-side and stored with the request, so
      // the record shows what was true at confirmation rather than whatever
      // the client happened to be displaying.
      const impact = await deps.repository.deletionImpact(actor.token.subject);
      const result = await deps.repository.requestDeletion(
        actor.token.subject,
        body.reasonCode,
        impact,
        deps.deletionGraceDays,
      );
      if (!result) return problem(c, "INVALID_REQUEST", 400);

      await recordAuthEvent(deps, actor.token.subject, {
        eventType: "account_deletion_requested",
        outcome: "allowed",
        reasonCode: body.reasonCode,
        requestId: c.get("requestId"),
      });
      return c.json({
        id: result.id,
        state: result.state,
        executeAfter: new Date(result.execute_after).toISOString(),
        created: result.created,
      });
    },
  );

  // Cancellation deliberately requires no recent-auth grant. Stopping a
  // destructive action is the safe direction, and adding friction here would
  // strand a user who cannot re-authenticate before the grace period ends.
  routes.post(
    "/v1/account/deletion-cancel",
    validateRouteInput(v1Route("cancelAccountDeletion")) as never,
    requirePermission(authorization, "account.deletion.cancel"),
    idempotency(idempotencyDependencies, "cancelAccountDeletion", "required"),
    async (c) => {
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
    },
  );

  if (academicRoutes) routes.route("/", academicRoutes);
  return routes;
}
