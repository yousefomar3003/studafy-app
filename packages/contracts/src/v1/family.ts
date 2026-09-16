import { z } from "zod";

const Id = z.string().uuid();

export const V1LocateStudentRequest = z.strictObject({
  studafyId: z.string().trim().min(1).max(40),
});
export type V1LocateStudentRequest = z.infer<typeof V1LocateStudentRequest>;

// Uniform shape whether found or not: only these two fields go null.
export const V1LocateStudentResponse = z.strictObject({
  found: z.boolean(),
  studentId: Id.nullable(),
  displayName: z.string().nullable(),
});
export type V1LocateStudentResponse = z.infer<typeof V1LocateStudentResponse>;

export const V1GuardianLink = z.strictObject({
  id: Id,
  schoolId: Id,
  studentId: Id,
  guardianId: Id,
  relationship: z.string().nullable(),
  status: z.enum(["pending", "verified", "declined", "revoked"]),
  expiresAt: z.string().datetime({ offset: true }).nullable(),
});
export type V1GuardianLink = z.infer<typeof V1GuardianLink>;

export const V1RequestGuardianLinkRequest = z.strictObject({
  studentId: Id,
  relationship: z.string().trim().max(60).optional(),
});
export type V1RequestGuardianLinkRequest = z.infer<
  typeof V1RequestGuardianLinkRequest
>;

export const V1VerifyGuardianLinkRequest = z.strictObject({
  expiresInDays: z.number().int().min(1).max(1825).optional(),
});
export type V1VerifyGuardianLinkRequest = z.infer<
  typeof V1VerifyGuardianLinkRequest
>;

export const V1RevokeGuardianLinkRequest = z.strictObject({});
export type V1RevokeGuardianLinkRequest = z.infer<
  typeof V1RevokeGuardianLinkRequest
>;
