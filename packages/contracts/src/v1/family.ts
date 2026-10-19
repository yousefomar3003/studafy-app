import { z } from "zod";

const Id = z.string().uuid();

export const V1LocateStudentRequest = z.strictObject({
  studafyId: z.string().trim().min(1).max(40),
  captchaToken: z.string().min(1).max(2048).optional(),
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

/** One of the caller's own guardian links, with the child it concerns. */
export const V1MyGuardianLink = z.strictObject({
  id: Id,
  schoolId: Id,
  schoolName: z.string(),
  studentId: Id,
  studentName: z.string(),
  relationship: z.string().nullable(),
  status: z.enum(["pending", "verified", "declined", "revoked"]),
  expiresAt: z.string().datetime({ offset: true }).nullable(),
  /**
   * Whether the child's school has messaging switched on (DL-049) - the
   * switch the server enforces on every new conversation and message. A
   * guardian holds no membership, so this is how the app learns it for
   * them and hides messaging where it is off. Absent from servers older
   * than 2026-10-16.
   */
  messagingEnabled: z.boolean().optional(),
  /**
   * Whether Family+ insights are open for this child: the same check
   * getFamilyInsights makes (the parent's family plan covers the child, or
   * a per-child subscription bought before family plans). This read is
   * served whether or not store billing is, so the app learns a plan given
   * without a purchase too. Absent from servers older than 2026-10-19.
   */
  familyPlus: z.boolean().optional(),
});
export type V1MyGuardianLink = z.infer<typeof V1MyGuardianLink>;

/**
 * The parent's own Family+ plan now: the largest live one, bought or given.
 * `granted` is true for a plan Studafy gave without a purchase (a comp
 * grant): there is no store subscription to manage, cancel or restore.
 */
export const V1FamilyPlusPlan = z.strictObject({
  featureKey: z.enum(["family_plus", "family_plus_large"]),
  endsAt: z.string().datetime({ offset: true }).nullable(),
  granted: z.boolean(),
  /** The linked children the plan covers now, decided by the server. */
  coveredStudentIds: z.array(Id).max(8),
});
export type V1FamilyPlusPlan = z.infer<typeof V1FamilyPlusPlan>;

export const V1MyGuardianLinksResponse = z.strictObject({
  items: z.array(V1MyGuardianLink).max(200),
  /** Always null: a guardian's links fit in one response. */
  nextCursor: z.string().nullable(),
  /**
   * The caller's Family+ plan, null without one. Absent from servers older
   * than 2026-10-19.
   */
  familyPlan: V1FamilyPlusPlan.nullable().optional(),
});
export type V1MyGuardianLinksResponse = z.infer<
  typeof V1MyGuardianLinksResponse
>;

/** Only the authenticated student can read or decide these requests. */
export const V1StudentFamily = z.strictObject({
  studentIds: z.array(
    z.strictObject({ id: Id, studafyId: z.string(), displayName: z.string() }),
  ),
  requests: z.array(
    z.strictObject({
      id: Id,
      guardianId: Id,
      guardianName: z.string(),
      studentId: Id,
      relationship: z.string().nullable(),
      status: z.enum(["pending", "verified", "declined", "revoked"]),
    }),
  ),
});
export const V1DecideGuardianLinkRequest = z.strictObject({
  decision: z.enum(["approve", "decline", "revoke"]),
});
