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
   * Whether this account may use the AI study tools (ADR-0043, ADR-0045).
   * Anything but "ok" or a consent still to give means `available` is
   * empty: the tools are for student accounts, in a class or not.
   * "no_class" now means an account not yet known to be a student. Absent
   * from servers older than 2026-10-15.
   */
  aiAccess: V1AiAccess.optional(),
  /**
   * Whether this server has the AI study tools at all: an AI provider is
   * configured. It does not say this account may use them (`aiAccess` and
   * `available` do). True with `aiAccess` "no_class" lets the app show a
   * student the helper's tab with "join a class first" instead of hiding
   * it; false means the tools are off for everyone. Absent from servers
   * older than 2026-10-17.
   */
  aiEnabled: z.boolean().optional(),
});
export type V1StudyPlanSummary = z.infer<typeof V1StudyPlanSummary>;

/**
 * One entry in a student's notebook: in a class's notebook, or in their
 * personal notebook, which belongs to no class (2026-10-21, ADR-0045).
 */
export const V1NotebookEntry = z.strictObject({
  id: Id,
  /** Null for a personal note. */
  classroomId: Id.nullable(),
  title: z.string().min(1).max(200),
  body: z.string().min(1).max(20000),
  /** 'whiteboard' when Studafy Plus wrote it from a photo or screenshot;
   * 'lesson' when it was made from one of the class's lessons. */
  source: z.enum(["typed", "whiteboard", "lesson"]),
  createdAt: Timestamp,
  /** When it was last written or edited. Absent from servers older than
   * 2026-10-21. */
  updatedAt: Timestamp.optional(),
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

/** Renaming or correcting one of the student's own notes. */
export const V1UpdateNotebookEntryRequest = z.strictObject({
  title: z.string().trim().min(1).max(200).optional(),
  body: z.string().trim().min(1).max(20000).optional(),
}).refine((value) => value.title !== undefined || value.body !== undefined, {
  message: "title or body is required",
});
export type V1UpdateNotebookEntryRequest = z.infer<
  typeof V1UpdateNotebookEntryRequest
>;

/**
 * A photo or screenshot sent with the request itself, for a student with no
 * school to upload into (2026-10-21). Checked, re-encoded, sent to the model
 * once, and never stored. About 1.5 MB at most once decoded.
 */
export const V1InlineImage = z.strictObject({
  mediaType: z.enum(["image/jpeg", "image/png", "image/webp"]),
  data: z.string().min(16).max(2_000_000).regex(/^[A-Za-z0-9+/]+={0,2}$/),
});
export type V1InlineImage = z.infer<typeof V1InlineImage>;

/** Studafy Plus: a photo or screenshot into a note in the personal
 * notebook. */
export const V1PhotoNoteRequest = z.strictObject({
  image: V1InlineImage,
  title: z.string().trim().min(1).max(200).optional(),
});
export type V1PhotoNoteRequest = z.infer<typeof V1PhotoNoteRequest>;

/** Studafy Max: a quiz or flashcards from some of the student's own notes. */
export const V1NotesPracticeRequest = z.strictObject({
  kind: z.enum(["quiz", "flashcards"]),
  entryIds: z.array(Id).min(1).max(20),
});
export type V1NotesPracticeRequest = z.infer<typeof V1NotesPracticeRequest>;

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

/**
 * A quiz or flashcards made from the student's own notes. Theirs alone, so
 * it is not kept on the server: the app holds it while they practise.
 */
export const V1NotesPractice = z.strictObject({
  kind: z.enum(["quiz", "flashcards"]),
  /** Set when kind is 'quiz'. */
  questions: z.array(V1QuizQuestion).max(30).nullable(),
  /** Set when kind is 'flashcards'. */
  cards: z.array(V1Flashcard).max(30).nullable(),
  createdAt: Timestamp,
});
export type V1NotesPractice = z.infer<typeof V1NotesPractice>;

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
