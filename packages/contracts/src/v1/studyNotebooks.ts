import { z } from "zod";
import { V1Flashcard, V1QuizQuestion } from "./studyPlans";
import { V1MaterialRefs } from "./materialSelection";

/**
 * A student's study notebooks (2026-10-07): one per lesson, or per chosen
 * files of a lesson, made by the AI in a fixed structure and kept with the
 * student's own notes, highlights and bookmarks - which regenerating the AI
 * part never touches.
 */

const Id = z.string().uuid();
const Timestamp = z.string().datetime({ offset: true });

export const V1NotebookColor = z.enum([
  "navy",
  "teal",
  "coral",
  "violet",
  "amber",
  "green",
  "rose",
  "slate",
]);
export type V1NotebookColor = z.infer<typeof V1NotebookColor>;

export const V1NotebookIcon = z.enum([
  "book",
  "science",
  "math",
  "language",
  "globe",
  "history",
  "art",
  "music",
  "code",
  "star",
]);
export type V1NotebookIcon = z.infer<typeof V1NotebookIcon>;

export const V1NotebookPageStyle = z.enum(["lined", "plain", "grid"]);
export type V1NotebookPageStyle = z.infer<typeof V1NotebookPageStyle>;

export const V1NotebookCitation = z.strictObject({
  name: z.string().max(300),
  page: z.number().int().positive().nullable(),
  slide: z.number().int().positive().nullable(),
});
export type V1NotebookCitation = z.infer<typeof V1NotebookCitation>;

export const V1NotebookSection = z.strictObject({
  key: z.string().min(1).max(40),
  heading: z.string().min(1).max(160),
  paragraphs: z.array(z.string().max(1500)).max(6),
  points: z.array(z.string().max(400)).max(10),
  cites: z.array(V1NotebookCitation).max(20),
  extra: z.boolean(),
});
export type V1NotebookSection = z.infer<typeof V1NotebookSection>;

export const V1NotebookItem = z.strictObject({
  text: z.string().min(1).max(500),
  cite: V1NotebookCitation.nullable(),
  extra: z.boolean(),
});
export type V1NotebookItem = z.infer<typeof V1NotebookItem>;

export const V1NotebookTerm = z.strictObject({
  term: z.string().min(1).max(120),
  definition: z.string().min(1).max(500),
  cite: V1NotebookCitation.nullable(),
});
export type V1NotebookTerm = z.infer<typeof V1NotebookTerm>;

export const V1NotebookExample = z.strictObject({
  title: z.string().min(1).max(200),
  steps: z.array(z.string().max(600)).min(1).max(10),
  cite: V1NotebookCitation.nullable(),
});
export type V1NotebookExample = z.infer<typeof V1NotebookExample>;

/** What the AI wrote, checked: each part present only when it has content. */
export const V1NotebookContent = z.strictObject({
  overview: z.string().max(1200).nullable(),
  objectives: z.array(z.string().max(300)).max(8),
  keyTerms: z.array(V1NotebookTerm).max(20),
  sections: z.array(V1NotebookSection).max(12),
  examples: z.array(V1NotebookExample).max(6),
  facts: z.array(V1NotebookItem).max(12),
  mistakes: z.array(V1NotebookItem).max(8),
  summary: z.array(z.string().max(400)).max(10),
});
export type V1NotebookContent = z.infer<typeof V1NotebookContent>;

/** A note the student wrote, kept against a section of the notebook. */
export const V1NotebookNote = z.strictObject({
  id: z.string().min(1).max(40),
  sectionKey: z.string().min(1).max(40),
  text: z.string().min(1).max(4000),
});
export type V1NotebookNote = z.infer<typeof V1NotebookNote>;

/** A section the student added, in their order. */
export const V1NotebookOwnSection = z.strictObject({
  id: z.string().min(1).max(40),
  title: z.string().min(1).max(160),
  body: z.string().max(8000),
});
export type V1NotebookOwnSection = z.infer<typeof V1NotebookOwnSection>;

export const V1NotebookHighlight = z.strictObject({
  sectionKey: z.string().min(1).max(40),
  /** Which paragraph or point of the section. */
  index: z.number().int().min(0).max(40),
  color: z.enum(["yellow", "green", "blue", "pink"]),
});
export type V1NotebookHighlight = z.infer<typeof V1NotebookHighlight>;

export const V1NotebookHeading = z.strictObject({
  key: z.string().min(1).max(40),
  title: z.string().min(1).max(160),
});
export type V1NotebookHeading = z.infer<typeof V1NotebookHeading>;

/** Everything the student made: never touched by regenerating. */
export const V1NotebookPersonal = z.strictObject({
  notes: z.array(V1NotebookNote).max(200),
  sections: z.array(V1NotebookOwnSection).max(40),
  bookmarks: z.array(z.string().min(1).max(40)).max(60),
  highlights: z.array(V1NotebookHighlight).max(400),
});
export type V1NotebookPersonal = z.infer<typeof V1NotebookPersonal>;

/** A file or link of the lesson, as the notebook reads it. */
export const V1NotebookSource = z.strictObject({
  id: Id,
  kind: z.enum(["file", "link"]),
  name: z.string().max(300),
  state: z.enum(["processing", "ready", "unsupported", "failed"]),
  reason: z.string().max(60).nullable(),
  /** Part of this notebook. */
  chosen: z.boolean(),
});
export type V1NotebookSource = z.infer<typeof V1NotebookSource>;

export const V1NotebookUnreadable = z.strictObject({
  name: z.string().max(300),
  reason: z.string().max(60),
});
export type V1NotebookUnreadable = z.infer<typeof V1NotebookUnreadable>;

export const V1NotebookSetSummary = z.strictObject({
  id: Id,
  kind: z.enum(["quiz", "flashcards"]),
  /** Empty: made from the whole notebook. */
  sectionKeys: z.array(z.string().max(40)).max(30),
  count: z.number().int().nonnegative(),
  /** The notebook has been regenerated since. */
  outdated: z.boolean(),
  createdAt: Timestamp,
});
export type V1NotebookSetSummary = z.infer<typeof V1NotebookSetSummary>;

export const V1StudyNotebookSummary = z.strictObject({
  id: Id,
  classroomId: Id,
  resourceId: Id,
  lessonTitle: z.string().max(300),
  title: z.string().min(1).max(120),
  subtitle: z.string().max(160).nullable(),
  color: V1NotebookColor,
  icon: V1NotebookIcon.nullable(),
  pageStyle: V1NotebookPageStyle,
  status: z.enum(["creating", "ready", "failed"]),
  /** Why the last generation failed: a code the app words. */
  failure: z.string().max(60).nullable(),
  /** The lesson or its files changed since the AI part was written. */
  updateAvailable: z.boolean(),
  contentVersion: z.number().int().nonnegative(),
  /** How many of the lesson's sources it was made from; 0 = all. */
  sourceCount: z.number().int().nonnegative(),
  createdAt: Timestamp,
  updatedAt: Timestamp,
});
export type V1StudyNotebookSummary = z.infer<typeof V1StudyNotebookSummary>;

export const V1StudyNotebookList = z.strictObject({
  items: z.array(V1StudyNotebookSummary).max(500),
});
export type V1StudyNotebookList = z.infer<typeof V1StudyNotebookList>;

export const V1StudyNotebook = z.strictObject({
  summary: V1StudyNotebookSummary,
  className: z.string().max(200),
  content: V1NotebookContent.nullable(),
  unreadable: z.array(V1NotebookUnreadable).max(100),
  headings: z.array(V1NotebookHeading).max(40),
  personal: V1NotebookPersonal,
  personalVersion: z.number().int().positive(),
  sources: z.array(V1NotebookSource).max(100),
  /** The lesson's own text is part of it. */
  includeText: z.boolean(),
  /** Made from the whole lesson: files added to it later are read on an
   * update. Otherwise exactly the files marked [chosen]. */
  wholeLesson: z.boolean(),
  sets: z.array(V1NotebookSetSummary).max(40),
  generatedAt: Timestamp.nullable(),
});
export type V1StudyNotebook = z.infer<typeof V1StudyNotebook>;

export const V1CreateStudyNotebookRequest = z.strictObject({
  resourceId: Id,
  /** The lesson's files and links to read; empty for all of it. Older apps
   * send this; newer ones send [references]. */
  sourceIds: z.array(Id).max(20),
  /** Exactly what to make it from, all on [resourceId]: the whole lesson,
   * or its text and chosen files and links (2026-10-07). */
  references: V1MaterialRefs.optional(),
  /** Go on without chosen files that cannot be read now. */
  skipUnavailable: z.boolean().optional(),
  title: z.string().trim().min(1).max(120).optional(),
  language: z.enum(["ar", "en"]).optional(),
});
export type V1CreateStudyNotebookRequest = z.infer<
  typeof V1CreateStudyNotebookRequest
>;

export const V1RegenerateStudyNotebookRequest = z.strictObject({
  sourceIds: z.array(Id).max(20).optional(),
  skipUnavailable: z.boolean().optional(),
  language: z.enum(["ar", "en"]).optional(),
});
export type V1RegenerateStudyNotebookRequest = z.infer<
  typeof V1RegenerateStudyNotebookRequest
>;

export const V1StudyNotebookSettingsRequest = z.strictObject({
  title: z.string().trim().min(1).max(120),
  subtitle: z.string().trim().max(160).nullable(),
  color: V1NotebookColor,
  icon: V1NotebookIcon.nullable(),
  pageStyle: V1NotebookPageStyle,
  headings: z.array(V1NotebookHeading).max(40),
});
export type V1StudyNotebookSettingsRequest = z.infer<
  typeof V1StudyNotebookSettingsRequest
>;

export const V1StudyNotebookPersonalRequest = z.strictObject({
  /** The personal version this edit was made on; a stale one is refused. */
  expectedVersion: z.number().int().positive(),
  personal: V1NotebookPersonal,
});
export type V1StudyNotebookPersonalRequest = z.infer<
  typeof V1StudyNotebookPersonalRequest
>;

export const V1DeleteStudyNotebookRequest = z.strictObject({});
export type V1DeleteStudyNotebookRequest = z.infer<
  typeof V1DeleteStudyNotebookRequest
>;

export const V1DeleteStudyNotebookResponse = z.strictObject({
  deleted: z.boolean(),
});
export type V1DeleteStudyNotebookResponse = z.infer<
  typeof V1DeleteStudyNotebookResponse
>;

export const V1NotebookStudySetRequest = z.strictObject({
  kind: z.enum(["quiz", "flashcards"]),
  /** Sections to practise; empty for the whole notebook. */
  sectionKeys: z.array(z.string().min(1).max(40)).max(30),
});
export type V1NotebookStudySetRequest = z.infer<
  typeof V1NotebookStudySetRequest
>;

export const V1NotebookStudySet = z.strictObject({
  id: Id,
  notebookId: Id,
  kind: z.enum(["quiz", "flashcards"]),
  sectionKeys: z.array(z.string().max(40)).max(30),
  outdated: z.boolean(),
  questions: z.array(V1QuizQuestion).nullable(),
  cards: z.array(V1Flashcard).nullable(),
  createdAt: Timestamp,
});
export type V1NotebookStudySet = z.infer<typeof V1NotebookStudySet>;
