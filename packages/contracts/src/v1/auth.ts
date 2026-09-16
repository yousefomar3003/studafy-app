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

/** @deprecated All v1 failures use ProblemDetails. */
export const V1AuthError = z.never();
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
export const V1ContextMembership = z.strictObject({
  id: uuid,
  schoolId: uuid,
  schoolName: z.string().min(1),
  schoolTimezone: z.string().min(1),
  role: V1AuthRole,
  activeTermId: uuid.nullable(),
});
export type V1ContextMembership = z.infer<typeof V1ContextMembership>;

/**
 * GET /v1/auth/context — everything a client needs to render authority.
 *
 * `membership_version` is echoed so a client can detect that its cached
 * authority is stale; it is not accepted as an input.
 */
export const V1AuthContextResponse = z.strictObject({
  userId: uuid,
  displayName: z.string().min(1),
  locale: z.enum(["en", "ar"]),
  memberships: z.array(V1ContextMembership),
  membershipVersion: z.string().min(1),
  assuranceLevel: V1AssuranceLevel,
  mfaEnrolled: z.boolean(),
  mfaRequired: z.boolean(),
  pendingDeletion: z.boolean(),
});
export type V1AuthContextResponse = z.infer<typeof V1AuthContextResponse>;

export const V1AuthDevice = z.strictObject({
  id: uuid,
  platform: z.enum(["ios", "android", "other"]),
  appVersion: z.string().nullable(),
  displayLabel: z.string().nullable(),
  firstSeenAt: isoTimestamp,
  lastSeenAt: isoTimestamp,
  revokedAt: isoTimestamp.nullable(),
  current: z.boolean(),
});
export type V1AuthDevice = z.infer<typeof V1AuthDevice>;

export const V1AuthDeviceListResponse = z.strictObject({
  devices: z.array(V1AuthDevice),
});
export type V1AuthDeviceListResponse = z.infer<
  typeof V1AuthDeviceListResponse
>;

export const V1AuthDeviceRevokeRequest = z.strictObject({
  deviceId: uuid,
});
export type V1AuthDeviceRevokeRequest = z.infer<
  typeof V1AuthDeviceRevokeRequest
>;

export const V1AuthDeviceRevokeResponse = z.strictObject({
  revoked: z.boolean(),
});
export type V1AuthDeviceRevokeResponse = z.infer<
  typeof V1AuthDeviceRevokeResponse
>;

export const V1AuthSignOutRequest = z.strictObject({
  scope: z.enum(["current", "all"]),
});
export type V1AuthSignOutRequest = z.infer<typeof V1AuthSignOutRequest>;

export const V1AuthSignOutResponse = z.strictObject({
  scope: z.enum(["current", "all"]),
  /** Present for scope "all": tokens issued before this instant are refused. */
  revokedBefore: isoTimestamp.nullable(),
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
  "account_data_export",
]);
export type V1ReauthPurpose = z.infer<typeof V1ReauthPurpose>;

export const V1ReauthChallengeRequest = z.strictObject({
  purpose: V1ReauthPurpose,
});
export type V1ReauthChallengeRequest = z.infer<
  typeof V1ReauthChallengeRequest
>;

/**
 * The challenge states what the caller must do; it never says whether the
 * account has a password, which providers it uses, or who owns it.
 */
export const V1ReauthChallengeResponse = z.strictObject({
  purpose: V1ReauthPurpose,
  requiredAssurance: V1AssuranceLevel,
  expiresAt: isoTimestamp,
});
export type V1ReauthChallengeResponse = z.infer<
  typeof V1ReauthChallengeResponse
>;

export const V1ReauthVerifyRequest = z.strictObject({
  purpose: V1ReauthPurpose,
});
export type V1ReauthVerifyRequest = z.infer<typeof V1ReauthVerifyRequest>;

/**
 * The opaque grant is returned once and never again; the server keeps only
 * its digest. The client presents it in `X-Studafy-Reauth` on the privileged
 * command, and it is consumed on first use.
 */
export const V1ReauthVerifyResponse = z.strictObject({
  purpose: V1ReauthPurpose,
  grant: z.string().min(43),
  expiresAt: isoTimestamp,
});
export type V1ReauthVerifyResponse = z.infer<typeof V1ReauthVerifyResponse>;

export const V1IdentityLinkRequest = z.strictObject({
  provider: z.enum(["google", "azure", "apple", "email"]),
  /** The provider's id token, verified server-side before anything is linked. */
  idToken: z.string().min(1).max(16_384),
  makePrimary: z.boolean(),
});
export type V1IdentityLinkRequest = z.infer<typeof V1IdentityLinkRequest>;

export const V1IdentityLinkResponse = z.strictObject({
  outcome: z.enum(["linked", "already_linked", "collision"]),
});
export type V1IdentityLinkResponse = z.infer<typeof V1IdentityLinkResponse>;

export const V1IdentityUnlinkRequest = z.strictObject({
  provider: z.enum(["google", "azure", "apple", "email"]),
  subject: z.string().min(1),
});
export type V1IdentityUnlinkRequest = z.infer<typeof V1IdentityUnlinkRequest>;

export const V1IdentityUnlinkResponse = z.strictObject({
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
export const V1DeletionImpactMembership = z.strictObject({
  schoolName: z.string().min(1),
  role: V1AuthRole,
});
export type V1DeletionImpactMembership = z.infer<
  typeof V1DeletionImpactMembership
>;

export const V1DeletionRetainedRecords = z.strictObject({
  attendance: z.number().int().min(0),
  grades: z.number().int().min(0),
  submissions: z.number().int().min(0),
  wellbeing: z.number().int().min(0),
});
export type V1DeletionRetainedRecords = z.infer<
  typeof V1DeletionRetainedRecords
>;

export const V1DeletionDeletedData = z.strictObject({
  profile: z.number().int().min(0),
  devices: z.number().int().min(0),
  consents: z.number().int().min(0),
  notifications: z.number().int().min(0),
});
export type V1DeletionDeletedData = z.infer<typeof V1DeletionDeletedData>;

export const V1DeletionImpactResponse = z.strictObject({
  memberships: z.array(V1DeletionImpactMembership),
  retainedSchoolRecords: V1DeletionRetainedRecords,
  deletedPersonalData: V1DeletionDeletedData,
  guardianLinks: z.number().int().min(0),
  activeEntitlements: z.number().int().min(0),
  gracePeriodDays: z.number().int().min(1),
});
export type V1DeletionImpactResponse = z.infer<
  typeof V1DeletionImpactResponse
>;

export const V1DeletionRequestRequest = z.strictObject({
  reasonCode: z.enum([
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

export const V1DeletionRequestResponse = z.strictObject({
  id: uuid,
  state: z.enum(["grace_period", "executing", "cancelled", "completed"]),
  executeAfter: isoTimestamp,
  created: z.boolean(),
});
export type V1DeletionRequestResponse = z.infer<
  typeof V1DeletionRequestResponse
>;

export const V1DeletionCancelRequest = z.strictObject({});
export type V1DeletionCancelRequest = z.infer<typeof V1DeletionCancelRequest>;

export const V1DeletionCancelResponse = z.strictObject({
  cancelled: z.boolean(),
});
export type V1DeletionCancelResponse = z.infer<
  typeof V1DeletionCancelResponse
>;
