import { z } from "zod";
import { V1FileAttachment } from "./attachments";
import { V1AiAccess } from "./aiConsent";

const Id = z.string().uuid();
const Timestamp = z.string().datetime({ offset: true });

/**
 * Studafy's student plans (2026-09-27).
 *
 *   free - Lessons (all class material), the Notebook for typed notes, and
 *          the question box a few times a day.
 *   plus - Studafy Plus: turns a photo of the lesson whiteboard into notes.
 *   max  - Studafy Max: Plus, and quizzes and flashcards from lessons.
 *
 * Prices live in the stores; the app reads them from the store listing.
 */
export const V1StudyPlanId = z.enum(["free", "plus", "max"]);
export type V1StudyPlanId = z.infer<typeof V1StudyPlanId>;

export const V1StudyFeature = z.enum([
  "ask",
  "whiteboard",
  "notes",
  "quiz",
  "flashcards",
]);
export type V1StudyFeature = z.infer<typeof V1StudyFeature>;

/**
 * A student's AI allowance, in tokens (ADR-0037). One allowance covers the
 * helper and every other AI study tool. Free resets every Monday 00:00 UTC;
 * Studafy Plus and Max on the 1st of each month, 00:00 UTC.
 */
export const V1AiAllowance = z.strictObject({
  period: z.enum(["week", "month"]),
  total: z.number().int().nonnegative(),
  used: z.number().int().nonnegative(),
  remaining: z.number().int().nonnegative(),
  resetsAt: Timestamp,
});
export type V1AiAllowance = z.infer<typeof V1AiAllowance>;

/** The caller's plan and its AI allowance. */
export const V1StudyPlanSummary = z.strictObject({
  plan: V1StudyPlanId,
  features: z.array(V1StudyFeature).max(8),
  /**
   * What this server can do right now, whatever the plan: the question box
   * needs an AI provider, and whiteboard notes and study sets also need the
   * lesson-tools switch (ADR-0029). The app hides or explains a feature that
   * is not here instead of offering one that always fails. Absent from
   * servers older than 2026-09-28.
   */
  available: z.array(V1StudyFeature).max(8).optional(),
  /**
   * How much of a chat the helper remembers on this plan, in characters.
   * The app sends no more than this with a question.
   */
  chatMemoryChars: z.number().int().nonnegative().optional(),
  allowance: V1AiAllowance,
  /**
   * Whether this account may use the AI study tools (ADR-0043). Anything
   * but "ok" or a consent still to give means `available` is empty: the
   * tools are for students in a class. Absent from servers older than
   * 2026-10-15.
   */
  aiAccess: V1AiAccess.optional(),
});
export type V1StudyPlanSummary = z.infer<typeof V1StudyPlanSummary>;

/** One entry in a student's notebook for one class. */
export const V1NotebookEntry = z.strictObject({
  id: Id,
  classroomId: Id,
  title: z.string().min(1).max(200),
  body: z.string().min(1).max(20000),
  /** 'whiteboard' when Studafy Plus wrote it from a photo; 'lesson' when it
   * was made from one of the class's lessons. */
  source: z.enum(["typed", "whiteboard", "lesson"]),
  createdAt: Timestamp,
  /** The whiteboard photo it came from, when there was one. */
  photo: V1FileAttachment.nullable(),
});
export type V1NotebookEntry = z.infer<typeof V1NotebookEntry>;

/** Every notebook a student has, by class - deleted classes included. */
export const V1MyNotebooks = z.strictObject({
  classes: z.array(z.strictObject({
    classroomId: Id,
    name: z.string(),
    /** The class was deleted; its notes are still the student's. */
    archived: z.boolean(),
    entries: z.array(V1NotebookEntry).max(2000),
  })).max(200),
});
export type V1MyNotebooks = z.infer<typeof V1MyNotebooks>;

/** Turning a lesson into study notes in the student's notebook (Plus). */
export const V1CreateLessonNotesRequest = z.strictObject({});
export type V1CreateLessonNotesRequest = z.infer<
  typeof V1CreateLessonNotesRequest
>;

export const V1NotebookPage = z.strictObject({
  items: z.array(V1NotebookEntry).max(200),
  nextCursor: z.string().nullable(),
});
export type V1NotebookPage = z.infer<typeof V1NotebookPage>;

export const V1CreateNotebookEntryRequest = z.strictObject({
  title: z.string().trim().min(1).max(200),
  body: z.string().trim().min(1).max(20000),
});
export type V1CreateNotebookEntryRequest = z.infer<
  typeof V1CreateNotebookEntryRequest
>;

/**
 * Studafy Plus: a completed upload of purpose `notebook_photo` for this class,
 * owned by the caller, to be turned into notes.
 */
export const V1WhiteboardNoteRequest = z.strictObject({
  photoFileId: Id,
  title: z.string().trim().min(1).max(200).optional(),
});
export type V1WhiteboardNoteRequest = z.infer<typeof V1WhiteboardNoteRequest>;

export const V1DeleteNotebookEntryRequest = z.strictObject({});
export type V1DeleteNotebookEntryRequest = z.infer<
  typeof V1DeleteNotebookEntryRequest
>;
export const V1DeleteNotebookEntryResponse = z.strictObject({
  id: Id,
  deleted: z.literal(true),
});
export type V1DeleteNotebookEntryResponse = z.infer<
  typeof V1DeleteNotebookEntryResponse
>;

export const V1QuizQuestion = z.strictObject({
  question: z.string().min(1).max(500),
  options: z.array(z.string().min(1).max(200)).length(4),
  answerIndex: z.number().int().min(0).max(3),
  explanation: z.string().max(600),
});
export type V1QuizQuestion = z.infer<typeof V1QuizQuestion>;

export const V1Flashcard = z.strictObject({
  front: z.string().min(1).max(300),
  back: z.string().min(1).max(600),
});
export type V1Flashcard = z.infer<typeof V1Flashcard>;

/**
 * A quiz or a set of flashcards from one lesson. Made once per lesson
 * version and shared by every Studafy Max student in the class.
 */
export const V1StudySet = z.strictObject({
  id: Id,
  resourceId: Id,
  kind: z.enum(["quiz", "flashcards"]),
  /** Set when kind is 'quiz'. */
  questions: z.array(V1QuizQuestion).max(30).nullable(),
  /** Set when kind is 'flashcards'. */
  cards: z.array(V1Flashcard).max(30).nullable(),
  createdAt: Timestamp,
});
export type V1StudySet = z.infer<typeof V1StudySet>;

export const V1GenerateStudySetRequest = z.strictObject({
  kind: z.enum(["quiz", "flashcards"]),
});
export type V1GenerateStudySetRequest = z.infer<
  typeof V1GenerateStudySetRequest
>;

/**
 * One file or link on a lesson, and how far reading it for the study helper
 * has got (ADR-0037). "unsupported" and "failed" carry a reason the app
 * words; a teacher may ask for either to be read again.
 */
export const V1MaterialSource = z.strictObject({
  id: Id,
  kind: z.enum(["file", "link"]),
  name: z.string().max(300),
  url: z.string().max(2048).nullable(),
  mediaType: z.string().max(120).nullable(),
  state: z.enum(["processing", "ready", "unsupported", "failed"]),
  reason: z.string().max(60).nullable(),
  pages: z.number().int().nonnegative().nullable(),
  skippedPages: z.number().int().nonnegative().nullable(),
});
export type V1MaterialSource = z.infer<typeof V1MaterialSource>;

export const V1LessonMaterial = z.strictObject({
  resourceId: Id,
  sources: z.array(V1MaterialSource).max(40),
});
export type V1LessonMaterial = z.infer<typeof V1LessonMaterial>;

export const V1RetryLessonMaterialRequest = z.strictObject({});
export type V1RetryLessonMaterialRequest = z.infer<
  typeof V1RetryLessonMaterialRequest
>;
