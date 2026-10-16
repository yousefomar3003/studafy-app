import { z } from "zod";

const Id = z.string().uuid();

/** Asked once, at first sign-in; "prefer not to say" is always offered. */
export const V1Gender = z.enum(["male", "female", "prefer_not_to_say"]);
export type V1Gender = z.infer<typeof V1Gender>;

export const V1AccountKind = z.enum(["student", "adult"]);
export type V1AccountKind = z.infer<typeof V1AccountKind>;

export const V1UpdateProfileRequest = z.strictObject({
  displayName: z.string().trim().min(1).max(160).optional(),
  locale: z.enum(["en", "ar"]).optional(),
  gender: V1Gender.optional(),
  /** Finishes first-sign-in setup; needs displayName and gender with it. */
  completeSetup: z.boolean().optional(),
  /** The kind of account, from the role the person signed in as. Recorded
   * once, for an account nothing has decided yet, and ignored after that. */
  accountKind: V1AccountKind.optional(),
});
export type V1UpdateProfileRequest = z.infer<typeof V1UpdateProfileRequest>;

export const V1ProfileResponse = z.strictObject({
  id: Id,
  displayName: z.string(),
  locale: z.enum(["en", "ar"]),
  /** The person's own answer; returned to them and nobody else. Absent from
   * servers older than 2026-09-28. */
  gender: V1Gender.nullable().optional(),
  /** False until the person has chosen their name and answered gender.
   * Absent from older servers, which have no setup to finish. */
  setupComplete: z.boolean().optional(),
  /** 'student' accounts are students only; 'adult' accounts may be a
   * teacher, a parent or both. Null until something decides it; absent from
   * servers older than 2026-10-01. */
  accountKind: V1AccountKind.nullable().optional(),
  /** The account's own ten-digit Studafy number, as a string so its digits
   * never change. Read-only, for the owner only; it grants nothing. Absent
   * from servers older than 2026-10-01. */
  publicId: z.string().regex(/^[1-9][0-9]{9}$/).optional(),
});
export type V1ProfileResponse = z.infer<typeof V1ProfileResponse>;

export const V1RequestDataExportRequest = z.strictObject({});
export type V1RequestDataExportRequest = z.infer<
  typeof V1RequestDataExportRequest
>;

export const V1DataExportRequest = z.strictObject({
  id: Id,
  status: z.enum(["pending", "ready", "failed", "expired"]),
  requestedAt: z.string().datetime({ offset: true }),
  readyAt: z.string().datetime({ offset: true }).nullable(),
  expiresAt: z.string().datetime({ offset: true }).nullable(),
});
export type V1DataExportRequest = z.infer<typeof V1DataExportRequest>;

export const V1ExportStatusResponse = z.strictObject({
  request: V1DataExportRequest.nullable(),
});
export type V1ExportStatusResponse = z.infer<typeof V1ExportStatusResponse>;

/**
 * GET /v1/account/export-download (DL-051): the caller's latest ready,
 * unexpired data export. Sections hold only the caller's own data. v2
 * (DL-060) adds exam answers, hand-ins, file lists, voice notes, messages
 * received, mark and attendance history, AI usage and `sections.about`; a
 * v1 document built before it is still served until it expires (7 days).
 */
export const V1DataExportDocument = z.strictObject({
  format: z.enum(["studafy-export/v1", "studafy-export/v2"]),
  generatedAt: z.string().datetime({ offset: true }),
  sections: z.record(z.string(), z.unknown()),
});
export type V1DataExportDocument = z.infer<typeof V1DataExportDocument>;
