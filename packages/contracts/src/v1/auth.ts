import { z } from "zod";

/**
 * AUTH-030 session lifecycle contracts.
 *
 * Two rules shape every schema here.
 *
 * Roles and tenancy are outputs, never inputs. No request carries a user id,
 * school id, or role, because the server derives all three from the verified
 * token and the membership rows. A client that could name its own tenant
 * would make the tenant boundary advisory.
 *
 * Failures are indistinguishable. `V1AuthErrorCode` deliberately has no code
 * meaning "no such account", "wrong provider", or "account deleted": every
 * one of those answers `UNAUTHENTICATED` with the same message, so the API
 * cannot be used to test whether an email belongs to a Studafy user.
 */

const uuid = z.string().uuid();
const isoTimestamp = z.string().datetime({ offset: true });

export const V1AuthErrorCode = z.enum([
  "UNAUTHENTICATED",
  "REAUTH_REQUIRED",
  "MFA_REQUIRED",
  "FORBIDDEN",
  "NOT_FOUND",
  "RATE_LIMITED",
  "INVALID_REQUEST",
  "CONFLICT",
  "INTERNAL_ERROR",
]);
export type V1AuthErrorCode = z.infer<typeof V1AuthErrorCode>;

export const V1AuthError = z.object({
  error: z.object({
    code: V1AuthErrorCode,
    message: z.string().min(1),
    request_id: z.string().min(1),
  }),
});
export type V1AuthError = z.infer<typeof V1AuthError>;

/** Authorization assurance level, mirroring the verified token. */
export const V1AssuranceLevel = z.enum(["aal1", "aal2"]);
export type V1AssuranceLevel = z.infer<typeof V1AssuranceLevel>;

export const V1AuthRole = z.enum([
  "school_admin",
  "teacher",
  "parent",
  "guardian",
  "student",
]);
export type V1AuthRole = z.infer<typeof V1AuthRole>;

/** One active membership. Resolved from the database, never from a claim. */
export const V1ContextMembership = z.object({
  id: uuid,
  school_id: uuid,
  school_name: z.string().min(1),
  school_timezone: z.string().min(1),
  role: V1AuthRole,
  active_term_id: uuid.nullable(),
});
export type V1ContextMembership = z.infer<typeof V1ContextMembership>;

/**
 * GET /v1/auth/context — everything a client needs to render authority.
 *
 * `membership_version` is echoed so a client can detect that its cached
 * authority is stale; it is not accepted as an input.
 */
export const V1AuthContextResponse = z.object({
  user_id: uuid,
  display_name: z.string().min(1),
  locale: z.enum(["en", "ar"]),
  memberships: z.array(V1ContextMembership),
  membership_version: z.string().min(1),
  assurance_level: V1AssuranceLevel,
  mfa_enrolled: z.boolean(),
  mfa_required: z.boolean(),
  pending_deletion: z.boolean(),
});
export type V1AuthContextResponse = z.infer<typeof V1AuthContextResponse>;

export const V1AuthDevice = z.object({
  id: uuid,
  platform: z.enum(["ios", "android", "other"]),
  app_version: z.string().nullable(),
  display_label: z.string().nullable(),
  first_seen_at: isoTimestamp,
  last_seen_at: isoTimestamp,
  revoked_at: isoTimestamp.nullable(),
  current: z.boolean(),
});
export type V1AuthDevice = z.infer<typeof V1AuthDevice>;

export const V1AuthDeviceListResponse = z.object({
  devices: z.array(V1AuthDevice),
});
export type V1AuthDeviceListResponse = z.infer<
  typeof V1AuthDeviceListResponse
>;

export const V1AuthDeviceRevokeRequest = z.object({
  device_id: uuid,
});
export type V1AuthDeviceRevokeRequest = z.infer<
  typeof V1AuthDeviceRevokeRequest
>;

export const V1AuthDeviceRevokeResponse = z.object({
  revoked: z.boolean(),
});
export type V1AuthDeviceRevokeResponse = z.infer<
  typeof V1AuthDeviceRevokeResponse
>;

export const V1AuthSignOutRequest = z.object({
  scope: z.enum(["current", "all"]),
});
export type V1AuthSignOutRequest = z.infer<typeof V1AuthSignOutRequest>;

export const V1AuthSignOutResponse = z.object({
  scope: z.enum(["current", "all"]),
  /** Present for scope "all": tokens issued before this instant are refused. */
  revoked_before: isoTimestamp.nullable(),
});
export type V1AuthSignOutResponse = z.infer<typeof V1AuthSignOutResponse>;

/** Purposes a recent-authentication grant may be minted for. */
export const V1ReauthPurpose = z.enum([
  "account_deletion",
  "account_deletion_cancel",
  "account_link",
  "all_device_sign_out",
  "device_revoke",
  "school_admin_privileged",
]);
export type V1ReauthPurpose = z.infer<typeof V1ReauthPurpose>;

export const V1ReauthChallengeRequest = z.object({
  purpose: V1ReauthPurpose,
});
export type V1ReauthChallengeRequest = z.infer<
  typeof V1ReauthChallengeRequest
>;

/**
 * The challenge states what the caller must do; it never says whether the
 * account has a password, which providers it uses, or who owns it.
 */
export const V1ReauthChallengeResponse = z.object({
  purpose: V1ReauthPurpose,
  required_assurance: V1AssuranceLevel,
  expires_at: isoTimestamp,
});
export type V1ReauthChallengeResponse = z.infer<
  typeof V1ReauthChallengeResponse
>;

export const V1ReauthVerifyRequest = z.object({
  purpose: V1ReauthPurpose,
});
export type V1ReauthVerifyRequest = z.infer<typeof V1ReauthVerifyRequest>;

/**
 * The opaque grant is returned once and never again; the server keeps only
 * its digest. The client presents it in `X-Studafy-Reauth` on the privileged
 * command, and it is consumed on first use.
 */
export const V1ReauthVerifyResponse = z.object({
  purpose: V1ReauthPurpose,
  grant: z.string().min(43),
  expires_at: isoTimestamp,
});
export type V1ReauthVerifyResponse = z.infer<typeof V1ReauthVerifyResponse>;

export const V1IdentityLinkRequest = z.object({
  provider: z.enum(["google", "azure", "apple", "email"]),
  /** The provider's id token, verified server-side before anything is linked. */
  id_token: z.string().min(1),
  make_primary: z.boolean(),
});
export type V1IdentityLinkRequest = z.infer<typeof V1IdentityLinkRequest>;

export const V1IdentityLinkResponse = z.object({
  outcome: z.enum(["linked", "already_linked", "collision"]),
});
export type V1IdentityLinkResponse = z.infer<typeof V1IdentityLinkResponse>;

export const V1IdentityUnlinkRequest = z.object({
  provider: z.enum(["google", "azure", "apple", "email"]),
  subject: z.string().min(1),
});
export type V1IdentityUnlinkRequest = z.infer<typeof V1IdentityUnlinkRequest>;

export const V1IdentityUnlinkResponse = z.object({
  outcome: z.enum(["unlinked", "not_linked", "last_identity"]),
});
export type V1IdentityUnlinkResponse = z.infer<
  typeof V1IdentityUnlinkResponse
>;

/**
 * GET /v1/account/deletion-impact — what deletion actually does to this
 * account, computed server-side.
 *
 * `retained_school_records` exists because a student cannot delete records
 * the school owns. Saying so with counts is what separates a lawful retention
 * boundary from what a store reviewer reads as a broken deletion flow.
 */
export const V1DeletionImpactResponse = z.object({
  memberships: z.array(z.object({
    school_name: z.string().min(1),
    role: V1AuthRole,
  })),
  retained_school_records: z.object({
    attendance: z.number().int().min(0),
    grades: z.number().int().min(0),
    submissions: z.number().int().min(0),
    wellbeing: z.number().int().min(0),
  }),
  deleted_personal_data: z.object({
    profile: z.number().int().min(0),
    devices: z.number().int().min(0),
    consents: z.number().int().min(0),
    notifications: z.number().int().min(0),
  }),
  guardian_links: z.number().int().min(0),
  active_entitlements: z.number().int().min(0),
  grace_period_days: z.number().int().min(1),
});
export type V1DeletionImpactResponse = z.infer<
  typeof V1DeletionImpactResponse
>;

export const V1DeletionRequestRequest = z.object({
  reason_code: z.enum([
    "no_longer_using",
    "changing_schools",
    "privacy_concern",
    "duplicate_account",
    "undisclosed",
  ]),
  confirmation: z.literal("DELETE"),
});
export type V1DeletionRequestRequest = z.infer<
  typeof V1DeletionRequestRequest
>;

export const V1DeletionRequestResponse = z.object({
  id: uuid,
  state: z.enum(["grace_period", "executing", "cancelled", "completed"]),
  execute_after: isoTimestamp,
  created: z.boolean(),
});
export type V1DeletionRequestResponse = z.infer<
  typeof V1DeletionRequestResponse
>;

export const V1DeletionCancelResponse = z.object({
  cancelled: z.boolean(),
});
export type V1DeletionCancelResponse = z.infer<
  typeof V1DeletionCancelResponse
>;
