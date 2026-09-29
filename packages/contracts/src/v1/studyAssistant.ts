import { z } from "zod";

/// One question a student typed, and nothing else.
///
/// Deliberately carries no student id, class id, assignment id or attachment.
/// The server builds the whole prompt from this field alone, so there is no
/// parameter a caller could use to make the assistant read something it was
/// not given - which is how the previous integration ended up forwarding
/// lesson material (ADR-0026).
export const V1StudyAssistantTurn = z.strictObject({
  role: z.enum(["student", "assistant"]),
  text: z.string().trim().min(1).max(4000),
});
export type V1StudyAssistantTurn = z.infer<typeof V1StudyAssistantTurn>;

export const V1StudyAssistantAskRequest = z.strictObject({
  question: z.string().trim().min(3).max(1000),
  /// The chat so far, oldest first, so the helper can carry on from it. Kept
  /// on the student's device, never on the server, and like the question it
  /// is only what the student typed and what the helper said back - redacted
  /// before it is sent on. The app sends what fits the plan's chat memory
  /// (`chatMemoryChars` on the study plan); the server trims it to that too.
  history: z.array(V1StudyAssistantTurn).max(400).optional(),
  /// Class material to answer from: a lesson the student can see or one of
  /// their own notes. The server reads the text itself - the app sends only
  /// which ones - and skips any the student may not read.
  references: z.array(z.strictObject({
    kind: z.enum(["lesson", "note"]),
    id: z.string().uuid(),
  })).max(5).optional(),
  /// Photos the student sent: their own uploads of purpose
  /// `assistant_attachment`, once scanned. Studafy Plus.
  attachmentFileIds: z.array(z.string().uuid()).max(3).optional(),
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
