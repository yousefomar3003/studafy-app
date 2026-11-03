import { z } from "zod";

/**
 * Reporting an AI answer (DL-076). Google Play's AI-Generated Content policy
 * and Apple's review ask that a person can flag offensive AI output from
 * inside the app. Any signed-in account files one for itself, with or
 * without a school: the safety reports are school-scoped and a student with
 * no class has none.
 */

/** Which AI feature wrote what is reported. */
export const V1AiOutputFeature = z.enum([
  "tutor",
  "notes",
  "notebook",
  "quiz",
  "flashcards",
  "summary",
]);
export type V1AiOutputFeature = z.infer<typeof V1AiOutputFeature>;

/** Why it is reported. */
export const V1AiOutputReportReason = z.enum([
  "offensive",
  "harmful",
  "wrong",
  "other",
]);
export type V1AiOutputReportReason = z.infer<typeof V1AiOutputReportReason>;

export const V1ReportAiOutputRequest = z.strictObject({
  feature: V1AiOutputFeature,
  reason: V1AiOutputReportReason,
  /** What the person wants to add, if anything. */
  details: z.string().trim().max(1000).optional(),
  /** The AI output itself, as the app showed it; the first 4,000 characters. */
  excerpt: z.string().trim().min(1).max(4000),
});
export type V1ReportAiOutputRequest = z.infer<typeof V1ReportAiOutputRequest>;

export const V1ReportAiOutputResponse = z.strictObject({
  id: z.string().uuid(),
  createdAt: z.string().datetime({ offset: true }),
});
export type V1ReportAiOutputResponse = z.infer<
  typeof V1ReportAiOutputResponse
>;
