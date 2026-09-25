import { z } from "zod";

/// One question a student typed, and nothing else.
///
/// Deliberately carries no student id, class id, assignment id or attachment.
/// The server builds the whole prompt from this field alone, so there is no
/// parameter a caller could use to make the assistant read something it was
/// not given - which is how the previous integration ended up forwarding
/// lesson material (ADR-0026).
export const V1StudyAssistantAskRequest = z.strictObject({
  question: z.string().trim().min(3).max(1000),
});
export type V1StudyAssistantAskRequest = z.infer<
  typeof V1StudyAssistantAskRequest
>;

export const V1StudyAssistantAskResponse = z.strictObject({
  answer: z.string().min(1).max(8000),
  /// Questions left today, so the app can say so before the limit is hit.
  remainingToday: z.number().int().nonnegative(),
});
export type V1StudyAssistantAskResponse = z.infer<
  typeof V1StudyAssistantAskResponse
>;
