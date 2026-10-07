import { z } from "zod";
import { V1Flashcard, V1QuizQuestion } from "./studyPlans";

/**
 * Exactly which class material an AI feature uses (2026-10-07).
 *
 * The app sends ids, never text. Each one is checked on the request: the
 * lesson must be one the student can see now, and a file or link must be
 * on that lesson. Nothing is added that was not chosen, and a chosen file
 * that cannot be read is named in a refusal rather than dropped - unless
 * the student chose to continue without it (`skipUnavailable`).
 */

const Id = z.string().uuid();
const Timestamp = z.string().datetime({ offset: true });

/**
 * One piece of chosen material:
 * - `lesson`: the whole lesson - its text and every file and link on it;
 * - `text`: only the lesson's own text (`id` is the lesson);
 * - `file` / `link`: one file or link (`lessonId` is its lesson);
 * - `note`: one of the student's own notebook notes (the helper only).
 */
export const V1MaterialRef = z.strictObject({
  kind: z.enum(["lesson", "text", "file", "link", "note"]),
  id: Id,
  lessonId: Id.optional(),
});
export type V1MaterialRef = z.infer<typeof V1MaterialRef>;

export const V1MaterialRefs = z.array(V1MaterialRef).min(1).max(40);

/** What a result was actually made from, so the student can check it. */
export const V1MaterialScope = z.strictObject({
  lessons: z.array(z.strictObject({
    resourceId: Id,
    classroomId: Id,
    title: z.string().max(300),
    /** The lesson's own text was used. */
    includeText: z.boolean(),
    /** Every file and link on the lesson was used. */
    wholeLesson: z.boolean(),
    sources: z.array(z.strictObject({
      id: Id,
      kind: z.enum(["file", "link"]),
      name: z.string().max(300),
    })).max(40),
  })).max(10),
  /** Chosen, but left out because the student continued without them. */
  skipped: z.array(z.strictObject({
    id: Id,
    name: z.string().max(300),
    reason: z.string().max(60),
  })).max(40),
});
export type V1MaterialScope = z.infer<typeof V1MaterialScope>;

/** A quiz or flashcards from chosen material (Studafy Max). */
export const V1SelectionStudySetRequest = z.strictObject({
  kind: z.enum(["quiz", "flashcards"]),
  references: V1MaterialRefs,
  skipUnavailable: z.boolean().optional(),
});
export type V1SelectionStudySetRequest = z.infer<
  typeof V1SelectionStudySetRequest
>;

export const V1SelectionStudySet = z.strictObject({
  id: Id,
  kind: z.enum(["quiz", "flashcards"]),
  questions: z.array(V1QuizQuestion).nullable(),
  cards: z.array(V1Flashcard).nullable(),
  scope: V1MaterialScope,
  createdAt: Timestamp,
});
export type V1SelectionStudySet = z.infer<typeof V1SelectionStudySet>;

/**
 * Study notes from chosen material, filed in the class notebook (Plus).
 * The answer is the new notebook entry; it ends with the lessons and files
 * it was made from, written by the server.
 */
export const V1SummariseMaterialRequest = z.strictObject({
  references: V1MaterialRefs,
  skipUnavailable: z.boolean().optional(),
  /** The app's language, for the "Made from" line. */
  language: z.enum(["ar", "en"]).optional(),
});
export type V1SummariseMaterialRequest = z.infer<
  typeof V1SummariseMaterialRequest
>;
