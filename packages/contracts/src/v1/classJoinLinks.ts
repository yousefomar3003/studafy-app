import { z } from "zod";

const Id = z.string().uuid();
const Version = z.number().int().positive();

/// A shareable way into one classroom.
///
/// Distinct from an invitation: it names no recipient, always grants the
/// student role, and is redeemed many times until it expires, is revoked or
/// exhausts its use budget.
export const V1ClassJoinLink = z.strictObject({
  id: Id,
  schoolId: Id,
  classroomId: Id,
  classroomName: z.string().min(1).max(160),
  status: z.enum(["active", "revoked", "expired"]),
  expiresAt: z.string().datetime({ offset: true }),
  maxUses: z.number().int().positive().nullable(),
  useCount: z.number().int().nonnegative(),
  createdAt: z.string().datetime({ offset: true }),
  version: Version,
});
export type V1ClassJoinLink = z.infer<typeof V1ClassJoinLink>;

export const V1CreateClassJoinLinkRequest = z.strictObject({
  /// Defaults to 30 days when omitted.
  expiresAt: z.string().datetime({ offset: true }).optional(),
  /// Null or omitted means the link is limited only by its expiry.
  maxUses: z.number().int().positive().max(1000).optional(),
});
export type V1CreateClassJoinLinkRequest = z.infer<
  typeof V1CreateClassJoinLinkRequest
>;

/// The record plus the one-time shareable token.
///
/// The server stores only a hash, so this is the single moment the token
/// exists in readable form. A teacher who loses it creates a new link.
export const V1CreateClassJoinLinkResponse = V1ClassJoinLink.extend({
  token: z.string().min(32).max(128),
});
export type V1CreateClassJoinLinkResponse = z.infer<
  typeof V1CreateClassJoinLinkResponse
>;

export const V1RevokeClassJoinLinkRequest = z.strictObject({});
export type V1RevokeClassJoinLinkRequest = z.infer<
  typeof V1RevokeClassJoinLinkRequest
>;

export const V1RedeemClassJoinLinkRequest = z.strictObject({
  token: z.string().min(32).max(128),
});
export type V1RedeemClassJoinLinkRequest = z.infer<
  typeof V1RedeemClassJoinLinkRequest
>;

/// What the joiner is told: which class they are now in. Nothing about the
/// link's budget, which is the teacher's business rather than theirs.
export const V1RedeemClassJoinLinkResponse = z.strictObject({
  schoolId: Id,
  classroomId: Id,
  classroomName: z.string().min(1).max(160),
});
export type V1RedeemClassJoinLinkResponse = z.infer<
  typeof V1RedeemClassJoinLinkResponse
>;
