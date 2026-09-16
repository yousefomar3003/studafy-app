import { z } from "zod";

const Id = z.string().uuid();
const Version = z.number().int().positive();

export const V1Invitation = z.strictObject({
  id: Id,
  schoolId: Id,
  role: z.enum(["school_admin", "teacher", "parent", "guardian", "student"]),
  email: z.string().email(),
  status: z.enum(["pending", "accepted", "revoked", "expired"]),
  expiresAt: z.string().datetime({ offset: true }),
  version: Version,
});
export type V1Invitation = z.infer<typeof V1Invitation>;

export const V1InvitationPage = z.strictObject({
  items: z.array(V1Invitation),
  nextCursor: z.string().nullable(),
});
export type V1InvitationPage = z.infer<typeof V1InvitationPage>;

export const V1IssueInvitationRequest = z.strictObject({
  email: z.string().trim().toLowerCase().email().max(254),
  role: z.enum(["school_admin", "teacher", "parent", "guardian", "student"]),
  classroomId: Id.optional(),
});
export type V1IssueInvitationRequest = z.infer<typeof V1IssueInvitationRequest>;

// The response the caller actually receives on issue: the invitation record
// plus the one-time raw token. Never persisted or returned again after this.
export const V1IssueInvitationResponse = V1Invitation.extend({
  token: z.string().min(32).max(128),
});
export type V1IssueInvitationResponse = z.infer<
  typeof V1IssueInvitationResponse
>;

export const V1RevokeInvitationRequest = z.strictObject({});
export type V1RevokeInvitationRequest = z.infer<
  typeof V1RevokeInvitationRequest
>;

export const V1AcceptInvitationRequest = z.strictObject({
  token: z.string().min(32).max(128),
});
export type V1AcceptInvitationRequest = z.infer<
  typeof V1AcceptInvitationRequest
>;

export const V1AcceptInvitationResponse = z.strictObject({
  id: Id,
  schoolId: Id,
  userId: Id,
  role: z.enum(["school_admin", "teacher", "parent", "guardian", "student"]),
  status: z.enum(["invited", "active", "suspended", "revoked", "expired"]),
  version: Version,
});
export type V1AcceptInvitationResponse = z.infer<
  typeof V1AcceptInvitationResponse
>;
