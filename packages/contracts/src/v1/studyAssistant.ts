import { z } from "zod";
import { V1AiAllowance } from "./studyPlans";

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
  /// Class material to answer from: a lesson the student can see (with all
  /// its files and links), one file or link on such a lesson, or one of
  /// their own notes. The server reads the material itself - the app sends
  /// only which ones - and skips any the student may not read (ADR-0037).
  references: z.array(z.strictObject({
    kind: z.enum(["lesson", "file", "link", "note"]),
    id: z.string().uuid(),
    /// The lesson a file or link belongs to.
    lessonId: z.string().uuid().optional(),
  })).max(5).optional(),
  /// The app's language, so the answer is in it.
  language: z.enum(["ar", "en"]).optional(),
  /// The same id for a retry of the same question: a retry is never charged
  /// twice.
  requestId: z.string().uuid().optional(),
  /// Photos the student sent: their own uploads of purpose
  /// `assistant_attachment`, once scanned. Studafy Plus.
  attachmentFileIds: z.array(z.string().uuid()).max(3).optional(),
});
export type V1StudyAssistantAskRequest = z.infer<
  typeof V1StudyAssistantAskRequest
>;

/// Where a fact in an answer came from: [n] in the answer is citations[n-1].
export const V1StudyCitation = z.strictObject({
  n: z.number().int().positive(),
  sourceKind: z.enum(["lesson", "file", "link", "note"]),
  name: z.string().max(300),
  lessonTitle: z.string().max(300).nullable(),
  page: z.number().int().positive().nullable(),
  slide: z.number().int().positive().nullable(),
});
export type V1StudyCitation = z.infer<typeof V1StudyCitation>;

export const V1StudyAssistantAskResponse = z.strictObject({
  answer: z.string().min(1).max(12000),
  citations: z.array(V1StudyCitation).max(40),
  /// Chosen material that could not be read, and why - so the student is
  /// told, and the answer never pretends otherwise.
  unreadable: z.array(z.strictObject({
    name: z.string().max(300),
    reason: z.string().max(60),
  })).max(40),
  /// What is left of the allowance after this answer.
  allowance: V1AiAllowance,
});
export type V1StudyAssistantAskResponse = z.infer<
  typeof V1StudyAssistantAskResponse
>;
