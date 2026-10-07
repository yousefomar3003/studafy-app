import { z } from "zod";
import { V1AiAllowance } from "./studyPlans";
import { V1MaterialRef, V1MaterialScope } from "./materialSelection";

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
  /// Class material to answer from, exactly as chosen (2026-10-07): a whole
  /// lesson, a lesson's own text, one file or link on a lesson, or one of
  /// their own notes. The server reads the material itself - the app sends
  /// only which ones - and refuses any the student may not read; a chosen
  /// file that cannot be read is named in a MATERIAL_UNAVAILABLE refusal
  /// unless `skipUnavailable` (ADR-0037, ADR-0039).
  references: z.array(V1MaterialRef).max(40).optional(),
  /// Go on without chosen files that cannot be read now.
  skipUnavailable: z.boolean().optional(),
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
  /// The class material this answer was given, when there was any.
  scope: V1MaterialScope.nullable().optional(),
});
export type V1StudyAssistantAskResponse = z.infer<
  typeof V1StudyAssistantAskResponse
>;
