import { z } from "zod";

/** GET /v1/me — the authenticated user's profile, memberships, and term. */
export const V1Membership = z.strictObject({
  id: z.string().uuid(),
  schoolId: z.string().uuid(),
  schoolName: z.string().min(1),
  role: z.enum(["school_admin", "teacher", "parent", "guardian", "student"]),
  active: z.boolean(),
});
export type V1Membership = z.infer<typeof V1Membership>;

export const V1MeResponse = z.strictObject({
  id: z.string().uuid(),
  displayName: z.string().min(1),
  memberships: z.array(V1Membership),
  activeTermId: z.string().uuid().nullable(),
});
export type V1MeResponse = z.infer<typeof V1MeResponse>;

/** @deprecated All v1 failures use ProblemDetails. */
export const V1MeError = z.never();
export type V1MeError = z.infer<typeof V1MeError>;
