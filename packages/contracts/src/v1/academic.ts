import { z } from "zod";
import { attachmentFileIds, V1FileAttachment } from "./attachments";

const Id = z.string().uuid();
const Timestamp = z.string().datetime({ offset: true });
const Version = z.number().int().positive();
/// A wall-clock time on the school's clock, e.g. 2026-10-01T23:59.
const LocalDateTime = z.string().regex(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}$/);
const GradeWeight = z.number().min(0).max(100);

/// How a student did on a piece of marked work. A mark that has not been
/// entered is null - never a zero.
export const V1GradeMark = z.enum(["scored", "absent", "not_graded"]);
export type V1GradeMark = z.infer<typeof V1GradeMark>;

/// A titled link a teacher put on a lesson, work, a question or a grade.
/// Only https with a real host; the reader is shown where it goes.
export const V1ContentLink = z.strictObject({
  id: Id,
  title: z.string().min(1).max(120),
  url: z.string().url().max(2048),
});
export type V1ContentLink = z.infer<typeof V1ContentLink>;

/// A link to add. The server checks it again: https, a host, no
/// credentials.
export const V1ContentLinkDraft = z.strictObject({
  title: z.string().trim().min(1).max(120),
  url: z.string().trim().url().max(2048).regex(/^https:\/\//),
});
export type V1ContentLinkDraft = z.infer<typeof V1ContentLinkDraft>;

const contentLinks = (max: number) =>
  z.array(V1ContentLinkDraft).max(max).optional();
const removedIds = (max: number) => z.array(Id).max(max).optional();

/// More time one student was given for one piece of work.
export const V1AssignmentExtensionSummary = z.strictObject({
  id: Id,
  extendedUntil: Timestamp,
  extendedUntilLocal: LocalDateTime,
  reason: z.string().min(1),
  createdAt: Timestamp,
});
export type V1AssignmentExtensionSummary = z.infer<
  typeof V1AssignmentExtensionSummary
>;

export const V1PageQuery = z.strictObject({
  schoolId: Id.optional(),
  classroomId: Id.optional(),
  studentId: Id.optional(),
  date: z.string().date().optional(),
  /// Names one meeting of a class. A register belongs to a session rather
  /// than to a day, and a class commonly meets more than once a day, so a
  /// date alone cannot say which lesson is being read.
  startsAt: z.string().datetime({ offset: true }).optional(),
  cursor: z.string().min(16).max(2048).optional(),
  pageSize: z.coerce.number().int().min(1).max(100).default(50),
});
export type V1PageQuery = z.infer<typeof V1PageQuery>;

export const V1School = z.strictObject({
  id: Id,
  name: z.string().min(1).max(160),
  timezone: z.string().min(1).max(100),
  locale: z.enum(["en", "ar"]),
});
export type V1School = z.infer<typeof V1School>;

export const V1Term = z.strictObject({
  id: Id,
  schoolId: Id,
  name: z.string().min(1).max(120),
  startsOn: z.string().date(),
  endsOn: z.string().date(),
  status: z.enum(["planned", "active", "closed", "cancelled"]),
});
export type V1Term = z.infer<typeof V1Term>;

export const V1TermPage = z.strictObject({
  items: z.array(V1Term),
  nextCursor: z.string().nullable(),
});
export type V1TermPage = z.infer<typeof V1TermPage>;

export const V1ScheduleSlot = z.strictObject({
  id: Id.nullable(),
  weekday: z.number().int().min(1).max(7),
  startsAt: z.string().regex(/^\d{2}:\d{2}(:\d{2})?$/),
  endsAt: z.string().regex(/^\d{2}:\d{2}(:\d{2})?$/),
  effectiveFrom: z.string().date(),
  effectiveUntil: z.string().date().nullable(),
});
export type V1ScheduleSlot = z.infer<typeof V1ScheduleSlot>;

export const V1ScheduleSlotInput = V1ScheduleSlot.omit({ id: true });
export type V1ScheduleSlotInput = z.infer<typeof V1ScheduleSlotInput>;

/** A week's lessons: two at the same day and start time are one lesson
 * entered twice, refused here rather than by the table's unique key. */
const V1ScheduleInput = z.array(V1ScheduleSlotInput).max(21).superRefine(
  (slots, context) => {
    const seen = new Set<string>();
    slots.forEach((slot, index) => {
      const key = [
        slot.weekday,
        slot.startsAt.slice(0, 5),
        slot.effectiveFrom,
      ].join("|");
      if (seen.has(key)) {
        context.addIssue({
          code: "custom",
          path: [index, "startsAt"],
          message: "two lessons start at the same day and time",
        });
      }
      seen.add(key);
    });
  },
);

export const V1AcademicClassroom = z.strictObject({
  id: Id,
  schoolId: Id,
  termId: Id,
  name: z.string().min(1).max(160),
  grade: z.string().max(40),
  section: z.string().max(40),
  room: z.string().max(80).nullable(),
  status: z.enum(["draft", "active", "archived"]),
  version: Version,
  studentCount: z.number().int().min(0),
  weeklySessions: z.number().int().min(0),
  termName: z.string().nullable(),
});
export type V1AcademicClassroom = z.infer<typeof V1AcademicClassroom>;

export const V1ClassroomPage = z.strictObject({
  items: z.array(V1AcademicClassroom),
  nextCursor: z.string().nullable(),
});
export type V1ClassroomPage = z.infer<typeof V1ClassroomPage>;

export const V1ClassroomDetail = z.strictObject({
  classroom: V1AcademicClassroom,
  schedule: z.array(V1ScheduleSlot),
});
export type V1ClassroomDetail = z.infer<typeof V1ClassroomDetail>;

export const V1CreateClassroomRequest = z.strictObject({
  schoolId: Id,
  name: z.string().trim().min(1).max(160),
  grade: z.string().trim().max(40),
  section: z.string().trim().max(40),
  room: z.string().trim().max(80).nullable(),
  schedule: V1ScheduleInput,
});
export type V1CreateClassroomRequest = z.infer<typeof V1CreateClassroomRequest>;

export const V1UpdateClassroomRequest = z.strictObject({
  expectedVersion: Version,
  name: z.string().trim().min(1).max(160),
  grade: z.string().trim().max(40),
  section: z.string().trim().max(40),
  room: z.string().trim().max(80).nullable(),
});
export type V1UpdateClassroomRequest = z.infer<typeof V1UpdateClassroomRequest>;

/** Deleting a class: it is archived, and students keep their notebooks. */
export const V1ArchiveClassroomRequest = z.strictObject({
  expectedVersion: Version,
});
export type V1ArchiveClassroomRequest = z.infer<
  typeof V1ArchiveClassroomRequest
>;

export const V1ReplaceScheduleRequest = z.strictObject({
  expectedVersion: Version,
  schedule: V1ScheduleInput,
});
export type V1ReplaceScheduleRequest = z.infer<typeof V1ReplaceScheduleRequest>;

export const V1StudentSummary = z.strictObject({
  id: Id,
  displayName: z.string().min(1),
  studafyId: z.string().min(1),
});
export type V1StudentSummary = z.infer<typeof V1StudentSummary>;

export const V1StudentPage = z.strictObject({
  items: z.array(V1StudentSummary),
  nextCursor: z.string().nullable(),
});
export type V1StudentPage = z.infer<typeof V1StudentPage>;

export const V1ClassroomStaff = z.strictObject({
  id: Id,
  userId: Id,
  displayName: z.string().min(1),
  role: z.enum(["lead_teacher", "co_teacher", "assistant"]),
});
export type V1ClassroomStaff = z.infer<typeof V1ClassroomStaff>;
export const V1ClassroomStaffPage = z.strictObject({
  items: z.array(V1ClassroomStaff),
  nextCursor: z.string().nullable(),
});
export type V1ClassroomStaffPage = z.infer<typeof V1ClassroomStaffPage>;

export const V1LessonSession = z.strictObject({
  id: Id,
  classroomId: Id,
  startsAt: Timestamp,
  endsAt: Timestamp,
  title: z.string().nullable(),
  status: z.enum(["scheduled", "completed", "cancelled"]),
  /**
   * When the content taught in this section was filed, null while it is
   * still outstanding. Status cannot stand in for it: recordAttendance also
   * leaves a session 'completed'.
   */
  filedAt: Timestamp.nullable(),
  version: Version,
  /**
   * The lessons filed for this section: 'published' once one the class can
   * see is filed, 'draft' while the only ones are drafts (told to the
   * class's teachers alone), else 'none'. A draft never counts as content.
   */
  contentState: z.enum(["none", "draft", "published"]).optional(),
});
export type V1LessonSession = z.infer<typeof V1LessonSession>;
export const V1LessonSessionPage = z.strictObject({
  items: z.array(V1LessonSession),
  nextCursor: z.string().nullable(),
});
export type V1LessonSessionPage = z.infer<typeof V1LessonSessionPage>;

export const V1Resource = z.strictObject({
  id: Id,
  schoolId: Id,
  classroomId: Id.nullable(),
  title: z.string().min(1),
  resourceType: z.string().min(1),
  body: z.string().nullable(),
  state: z.enum(["draft", "published", "withdrawn", "archived"]),
  version: Version,
  publishedAt: Timestamp.nullable(),
  /**
   * The lesson's current file, when it has one, for the app to offer as a
   * download. A replaced file is not listed: only the school's staff can
   * still open it.
   */
  attachments: z.array(V1FileAttachment).max(11).optional(),
  /// Titled links on the lesson.
  links: z.array(V1ContentLink).max(10).optional(),
});
export type V1Resource = z.infer<typeof V1Resource>;

export const V1ResourcePage = z.strictObject({
  items: z.array(V1Resource),
  nextCursor: z.string().nullable(),
});
export type V1ResourcePage = z.infer<typeof V1ResourcePage>;

export const V1CreateResourceRequest = z.strictObject({
  schoolId: Id,
  classroomId: Id.nullable(),
  title: z.string().trim().min(1).max(200),
  resourceType: z.enum(["lesson_note", "text", "link"]),
  body: z.string().max(30_000).nullable(),
  audience: z.enum(["students", "guardians", "both"]),
  /**
   * The meeting this content was taught in. A section is not closeable
   * until something is filed against it, so this is how the content and
   * the lesson are tied together.
   */
  lessonSessionId: Id.optional(),
  /// Uploads of purpose `lesson_resource`, started for this class: the
  /// lesson's files, bound in the same transaction.
  attachmentFileIds: z.array(Id).max(10).optional(),
  links: contentLinks(10),
});
export type V1CreateResourceRequest = z.infer<typeof V1CreateResourceRequest>;

export const V1ReviseResourceRequest = z.strictObject({
  expectedVersion: Version,
  title: z.string().trim().min(1).max(200),
  body: z.string().max(30_000).nullable(),
});
export type V1ReviseResourceRequest = z.infer<typeof V1ReviseResourceRequest>;

export const V1VersionCommandRequest = z.strictObject({
  expectedVersion: Version,
});

export const V1CloseLessonSessionRequest = z.strictObject({});
export type V1CloseLessonSessionRequest = z.infer<
  typeof V1CloseLessonSessionRequest
>;

/// A closed section: the content taught in it has been filed.
export const V1CloseLessonSessionResponse = z.strictObject({
  id: Id,
  filedAt: Timestamp,
});
export type V1CloseLessonSessionResponse = z.infer<
  typeof V1CloseLessonSessionResponse
>;
export type V1VersionCommandRequest = z.infer<typeof V1VersionCommandRequest>;

export const V1Assignment = z.strictObject({
  id: Id,
  classroomId: Id,
  title: z.string().min(1),
  instructions: z.string().nullable(),
  dueAt: Timestamp,
  closesAt: Timestamp.nullable(),
  state: z.enum(["draft", "published", "withdrawn"]),
  version: Version,
  submissionId: Id.nullable(),
  submittedAt: Timestamp.nullable(),
  /**
   * Set when the work is graded: what it is marked out of. The mark itself
   * lives on the linked assessment, which the gradebook reads.
   */
  maximumScore: z.number().positive().nullable().optional(),
  /**
   * Files the teacher attached when setting the work. Optional only because
   * an idempotent replay of work created before material existed carries
   * none; every current read includes it.
   */
  attachments: z.array(V1FileAttachment).max(5).optional(),
  /** The school's time zone, in which due times are set and shown. */
  timeZone: z.string().min(1).max(100).optional(),
  /** dueAt as the school's wall-clock time, e.g. 2026-10-01T23:59. */
  dueLocal: LocalDateTime.optional(),
  closesLocal: LocalDateTime.nullable().optional(),
  /**
   * For a student (or a guardian reading a child's work): the last moment
   * work can be handed in or replaced - the later of the closing time and
   * any extension - and whether it still can be.
   */
  deadlineAt: Timestamp.optional(),
  deadlineLocal: LocalDateTime.optional(),
  submissionState: z.enum(["open", "closed", "graded_locked"]).optional(),
  extension: V1AssignmentExtensionSummary.nullable().optional(),
  /** When the work was set for the class; null while it is a draft. */
  publishedAt: Timestamp.nullable().optional(),
  /** Titled links the teacher put on the work. */
  links: z.array(V1ContentLink).max(10).optional(),
});
export type V1Assignment = z.infer<typeof V1Assignment>;

export const V1AssignmentPage = z.strictObject({
  items: z.array(V1Assignment),
  nextCursor: z.string().nullable(),
});
export type V1AssignmentPage = z.infer<typeof V1AssignmentPage>;

export const V1CreateAssignmentRequest = z.strictObject({
  classroomId: Id,
  title: z.string().trim().min(1).max(200),
  instructions: z.string().max(30_000).nullable(),
  dueAt: Timestamp,
  closesAt: Timestamp.nullable(),
  /**
   * The due time as the teacher picked it, on the school's clock. When sent
   * it wins over dueAt, which the device worked out in its own time zone.
   */
  dueLocal: LocalDateTime.optional(),
  closesLocal: LocalDateTime.nullable().optional(),
  /**
   * Uploads of purpose `assignment_material`, started for this class. Bound
   * when the work is created, in the same transaction: a refused file means
   * the work is not created either.
   */
  attachmentFileIds: attachmentFileIds(),
  links: contentLinks(10),
});
export type V1CreateAssignmentRequest = z.infer<
  typeof V1CreateAssignmentRequest
>;

export const V1SubmitAssignmentRequest = z.strictObject({
  answerText: z.string().trim().min(1).max(100_000),
  /**
   * The child this hand-in is for.
   *
   * Omitted when a student submits their own work. A guardian names the child
   * they are acting for, and the server authorises it on the verified
   * guardian link - so this field cannot be used to submit for a child the
   * caller is not linked to.
   */
  studentId: Id.optional(),
  /**
   * Uploads of purpose `assignment_submission`, owned by the student.
   *
   * Bound to the attempt this request creates, so a resubmission carries its
   * own files and the previous attempt keeps the ones it was handed in with.
   */
  attachmentFileIds: attachmentFileIds(),
});
export type V1SubmitAssignmentRequest = z.infer<
  typeof V1SubmitAssignmentRequest
>;

export const V1Submission = z.strictObject({
  id: Id,
  assignmentId: Id,
  studentId: Id,
  status: z.enum(["open", "submitted", "excused", "withdrawn"]),
  version: Version,
  answerText: z.string().nullable(),
  submittedAt: Timestamp.nullable(),
  attachments: z.array(V1FileAttachment).max(5),
  /**
   * Set when a verified guardian handed this attempt in for the child, which
   * young children without a device of their own rely on. Null when the
   * student submitted it themselves - the ordinary case, and one that stays
   * distinguishable from a guardian hand-in for as long as the record exists.
   */
  submittedByGuardianId: Id.nullable(),
  /** Handed in after the due time, within an extension or late window. */
  late: z.boolean().optional(),
});
export type V1Submission = z.infer<typeof V1Submission>;

export const V1SubmissionPage = z.strictObject({
  items: z.array(V1Submission),
  nextCursor: z.string().nullable(),
});
export type V1SubmissionPage = z.infer<typeof V1SubmissionPage>;

/**
 * One hand-in of a piece of work. Every resubmission is a new attempt, and
 * the earlier ones are kept exactly as they were handed in.
 */
export const V1SubmissionAttempt = z.strictObject({
  id: Id,
  submittedAt: Timestamp,
  answerText: z.string().nullable(),
  /** True for the attempt that is marked: the latest one. */
  current: z.boolean(),
  /** The guardian who handed this attempt in for the child, if one did. */
  submittedByGuardianId: Id.nullable(),
  submittedByGuardianName: z.string().nullable(),
  attachments: z.array(V1FileAttachment).max(5),
});
export type V1SubmissionAttempt = z.infer<typeof V1SubmissionAttempt>;

/**
 * Every attempt one student made at one assignment, newest first.
 *
 * Readable by that student, a verified guardian of theirs, and the class's
 * staff. A student leaves `studentId` out and gets their own; anyone else
 * names the student.
 */
export const V1SubmissionHistory = z.strictObject({
  items: z.array(V1SubmissionAttempt),
  nextCursor: z.string().nullable(),
});
export type V1SubmissionHistory = z.infer<typeof V1SubmissionHistory>;

/// What a question asks for. Choice, true/false and short answers with
/// accepted answers are marked automatically; essays, and short answers
/// without any, by the teacher.
export const V1QuestionKind = z.enum([
  "single_choice",
  "multiple_choice",
  "true_false",
  "short_answer",
  "essay",
]);
export type V1QuestionKind = z.infer<typeof V1QuestionKind>;

export const V1QuestionOption = z.strictObject({
  id: z.string().min(1).max(40),
  text: z.string().min(1).max(1000),
});
export type V1QuestionOption = z.infer<typeof V1QuestionOption>;

/// A question as a student sees it: no key, no model answer, no guidance.
export const V1AssessmentQuestion = z.strictObject({
  id: Id,
  position: z.number().int().positive(),
  prompt: z.string().min(1),
  maximumScore: z.number().positive(),
  kind: V1QuestionKind.optional(),
  required: z.boolean().optional(),
  options: z.array(V1QuestionOption).max(10).optional(),
  attachments: z.array(V1FileAttachment).max(5).optional(),
  links: z.array(V1ContentLink).max(5).optional(),
});
export type V1AssessmentQuestion = z.infer<typeof V1AssessmentQuestion>;

/// A question as its teacher writes it, or as a released review shows it.
/// The correct answer is in the one field its kind uses: the right option
/// ids, true or false, or the short answers accepted. None of these, the
/// model answer or the guidance is ever sent to a student before release.
export const V1AssessmentAuthoringQuestion = V1AssessmentQuestion.extend({
  preferredAnswer: z.string().nullable(),
  correctOptionIds: z.array(z.string()).nullable().optional(),
  correctChoice: z.boolean().nullable().optional(),
  acceptedAnswers: z.array(z.string()).nullable().optional(),
  markingGuidance: z.string().nullable().optional(),
});
export type V1AssessmentAuthoringQuestion = z.infer<
  typeof V1AssessmentAuthoringQuestion
>;

export const V1AssessmentQuestionDraft = z.strictObject({
  /// Set when editing a question that already exists; it keeps its files.
  id: Id.optional(),
  position: z.number().int().positive(),
  prompt: z.string().trim().min(1).max(10_000),
  preferredAnswer: z.string().max(30_000).nullable(),
  maximumScore: z.number().positive().max(1000),
  kind: V1QuestionKind.optional(),
  required: z.boolean().optional(),
  options: z.array(V1QuestionOption).max(10).optional(),
  /// Choice questions: the right option ids (exactly one for single choice).
  correctOptionIds: z.array(z.string().min(1).max(40)).max(10).nullable()
    .optional(),
  /// True/false questions.
  correctChoice: z.boolean().nullable().optional(),
  /// Short answers accepted for automatic marking; none means the teacher
  /// marks it.
  acceptedAnswers: z.array(z.string().trim().min(1).max(500)).max(20).nullable()
    .optional(),
  markingGuidance: z.string().max(10_000).nullable().optional(),
  /// Uploads of purpose `assignment_material` for this class.
  attachmentFileIds: z.array(Id).max(5).optional(),
  detachFileIds: removedIds(5),
  links: contentLinks(5),
  removeLinkIds: removedIds(5),
});
export type V1AssessmentQuestionDraft = z.infer<
  typeof V1AssessmentQuestionDraft
>;

/// When answers are shown to students and families. Never while anyone can
/// still attempt: after_close (the default), after_grading (also every
/// attempt marked and grades published), or manual.
export const V1AnswerRelease = z.enum([
  "after_close",
  "after_grading",
  "manual",
]);
export type V1AnswerRelease = z.infer<typeof V1AnswerRelease>;

export const V1AttemptPolicy = z.enum(["best", "latest"]);
export type V1AttemptPolicy = z.infer<typeof V1AttemptPolicy>;

export const V1Assessment = z.strictObject({
  id: Id,
  classroomId: Id,
  title: z.string().min(1),
  category: z.string().min(1),
  maximumScore: z.number().positive(),
  scheduledAt: Timestamp.nullable(),
  delivery: z.enum(["paper", "online", "practice"]),
  state: z.enum(["draft", "published", "withdrawn"]),
  version: Version,
  /** The assignment this is the mark for, when it is graded coursework. */
  assignmentId: Id.nullable().optional(),
  /**
   * Files the teacher attached when setting the work. Optional only because
   * an idempotent replay of work created before material existed carries
   * none; every current read includes it.
   */
  attachments: z.array(V1FileAttachment).max(5).optional(),
  links: z.array(V1ContentLink).max(10).optional(),
  /** How much this category counts, when the school weighs categories. */
  weight: GradeWeight.nullable().optional(),
  /** When the exam was published to the class; null while it is a draft. */
  publishedAt: Timestamp.nullable().optional(),
  /** Online only: when students may start, and when it closes. */
  opensAt: Timestamp.nullable().optional(),
  closesAt: Timestamp.nullable().optional(),
  maxAttempts: z.number().int().min(1).max(20).optional(),
  attemptPolicy: V1AttemptPolicy.optional(),
  answerRelease: V1AnswerRelease.optional(),
  answersReleasedAt: Timestamp.nullable().optional(),
  questionCount: z.number().int().min(0).optional(),
});
export type V1Assessment = z.infer<typeof V1Assessment>;

export const V1AssessmentPage = z.strictObject({
  items: z.array(V1Assessment),
  nextCursor: z.string().nullable(),
});
export type V1AssessmentPage = z.infer<typeof V1AssessmentPage>;

export const V1CreateAssessmentRequest = z.strictObject({
  classroomId: Id,
  title: z.string().trim().min(1).max(200),
  category: z.string().trim().min(1).max(80),
  maximumScore: z.number().positive(),
  scheduledAt: Timestamp.nullable(),
  delivery: z.enum(["paper", "online"]),
  questions: z.array(V1AssessmentQuestionDraft).max(100),
  /**
   * Makes this the mark for an existing assignment in the same class: the
   * student hands the assignment in, and the grade is recorded here.
   */
  assignmentId: Id.optional(),
  /** How much this category counts, when the school weighs categories. */
  weight: GradeWeight.nullable().optional(),
  /**
   * Uploads of purpose `assignment_material`, started for this class. Bound
   * when the work is created, in the same transaction: a refused file means
   * the work is not created either.
   */
  attachmentFileIds: attachmentFileIds(),
  links: contentLinks(10),
  opensAt: Timestamp.nullable().optional(),
  closesAt: Timestamp.nullable().optional(),
  maxAttempts: z.number().int().min(1).max(20).optional(),
  attemptPolicy: V1AttemptPolicy.optional(),
  answerRelease: V1AnswerRelease.optional(),
});
export type V1CreateAssessmentRequest = z.infer<
  typeof V1CreateAssessmentRequest
>;

/// The questions and settings of an online assessment. The questions only
/// while nobody has attempted it; the window, attempts and release at any
/// time. releaseAnswersNow releases by hand, and only once it has closed
/// for everyone.
export const V1UpdateAssessmentDesignRequest = z.strictObject({
  expectedVersion: Version,
  title: z.string().trim().min(1).max(200).optional(),
  questions: z.array(V1AssessmentQuestionDraft).max(100).optional(),
  opensAt: Timestamp.nullable().optional(),
  closesAt: Timestamp.nullable().optional(),
  maxAttempts: z.number().int().min(1).max(20).optional(),
  attemptPolicy: V1AttemptPolicy.optional(),
  answerRelease: V1AnswerRelease.optional(),
  releaseAnswersNow: z.boolean().optional(),
  attachmentFileIds: attachmentFileIds(),
  detachFileIds: removedIds(5),
  links: contentLinks(10),
  removeLinkIds: removedIds(10),
});
export type V1UpdateAssessmentDesignRequest = z.infer<
  typeof V1UpdateAssessmentDesignRequest
>;

/// More time, more attempts, or both, for one student.
export const V1GrantAssessmentAccessRequest = z.strictObject({
  studentId: Id,
  closesAt: Timestamp.nullable(),
  extraAttempts: z.number().int().min(0).max(20),
  reason: z.string().trim().max(500).nullable().optional(),
});
export type V1GrantAssessmentAccessRequest = z.infer<
  typeof V1GrantAssessmentAccessRequest
>;

export const V1AssessmentAccessGrant = z.strictObject({
  studentId: Id,
  closesAt: Timestamp.nullable(),
  extraAttempts: z.number().int().min(0).max(20),
});
export type V1AssessmentAccessGrant = z.infer<typeof V1AssessmentAccessGrant>;

export const V1AssessmentQuestionsResponse = z.strictObject({
  items: z.array(V1AssessmentQuestion),
  nextCursor: z.string().nullable(),
});
export type V1AssessmentQuestionsResponse = z.infer<
  typeof V1AssessmentQuestionsResponse
>;

export const V1AssessmentAuthoringQuestionsResponse = z.strictObject({
  items: z.array(V1AssessmentAuthoringQuestion),
  nextCursor: z.string().nullable(),
});
export type V1AssessmentAuthoringQuestionsResponse = z.infer<
  typeof V1AssessmentAuthoringQuestionsResponse
>;

/// One answer: text for short answers and essays, the chosen option ids for
/// choice questions, or true/false.
export const V1AssessmentAnswer = z.strictObject({
  questionId: Id,
  answerText: z.string().max(30_000).optional(),
  selectedOptionIds: z.array(z.string().min(1).max(40)).max(10).optional(),
  choice: z.boolean().optional(),
});
export type V1AssessmentAnswer = z.infer<typeof V1AssessmentAnswer>;

export const V1SubmitAssessmentRequest = z.strictObject({
  answers: z.array(V1AssessmentAnswer).min(1).max(100),
});
export type V1SubmitAssessmentRequest = z.infer<
  typeof V1SubmitAssessmentRequest
>;

/// The confirmation of an attempt. Never a mark.
export const V1AssessmentAttempt = z.strictObject({
  id: Id,
  assessmentId: Id,
  studentId: Id,
  submittedAt: Timestamp,
  version: Version,
  attemptNumber: z.number().int().positive().nullable().optional(),
  attemptsRemaining: z.number().int().min(0).optional(),
});
export type V1AssessmentAttempt = z.infer<typeof V1AssessmentAttempt>;

/// One attempt in the teacher's marking list.
/// The state of the student's grade for the work, for the class's
/// teachers: null before any mark exists.
const V1AttemptGradeState = z.enum([
  "draft",
  "reviewed",
  "published",
  "withdrawn",
])
  .nullable();

export const V1AssessmentAttemptSummary = V1AssessmentAttempt.extend({
  studentName: z.string(),
  needsMarking: z.boolean(),
  awardedScore: z.number().nullable(),
  gradeState: V1AttemptGradeState.optional(),
  /// Answers a person still has to mark, and how many need a person at all.
  pendingAnswers: z.number().int().min(0).optional(),
  manualAnswers: z.number().int().min(0).optional(),
});
export type V1AssessmentAttemptSummary = z.infer<
  typeof V1AssessmentAttemptSummary
>;

export const V1AssessmentAttemptPage = z.strictObject({
  items: z.array(V1AssessmentAttemptSummary),
  nextCursor: z.string().nullable(),
});
export type V1AssessmentAttemptPage = z.infer<typeof V1AssessmentAttemptPage>;

/// One answer of an attempt, with its question and marks. For a student or
/// parent, only ever sent once answers are released.
export const V1AttemptAnswer = z.strictObject({
  question: V1AssessmentAuthoringQuestion,
  answerText: z.string().nullable(),
  selectedOptionIds: z.array(z.string()).nullable(),
  choice: z.boolean().nullable(),
  autoScore: z.number().nullable(),
  awardedScore: z.number().nullable(),
  feedback: z.string().nullable(),
});
export type V1AttemptAnswer = z.infer<typeof V1AttemptAnswer>;

/// An attempt in full. The marks and answers are present for the class's
/// teachers, and for the student or a parent only once released.
export const V1AssessmentAttemptDetail = V1AssessmentAttempt.extend({
  needsMarking: z.boolean().optional(),
  awardedScore: z.number().nullable().optional(),
  feedback: z.string().nullable().optional(),
  answers: z.array(V1AttemptAnswer).optional(),
  /// For the class's teachers only: the student's name, and the state and
  /// mark of their grade - so a published absence is told from a score.
  studentName: z.string().optional(),
  gradeState: V1AttemptGradeState.optional(),
  gradeMark: z.enum(["scored", "absent", "not_graded"]).nullable().optional(),
});
export type V1AssessmentAttemptDetail = z.infer<
  typeof V1AssessmentAttemptDetail
>;

/// A teacher's mark for one answer.
export const V1AnswerMark = z.strictObject({
  questionId: Id,
  score: z.number().min(0).max(1000),
  feedback: z.string().trim().max(5000).nullable().optional(),
});
export type V1AnswerMark = z.infer<typeof V1AnswerMark>;

export const V1MarkAssessmentAttemptRequest = z.strictObject({
  marks: z.array(V1AnswerMark).max(100),
  /// Feedback on the attempt as a whole.
  feedback: z.string().trim().max(5000).nullable().optional(),
  /// Required when the student's grade is already published and the change
  /// moves its mark or score: that is a correction. A change to the
  /// feedback alone needs none.
  correctionReason: z.string().trim().min(3).max(500).optional(),
});
export type V1MarkAssessmentAttemptRequest = z.infer<
  typeof V1MarkAssessmentAttemptRequest
>;

export const V1GradeResult = z.strictObject({
  id: Id,
  assessmentId: Id,
  studentId: Id,
  /// What the work was called, so a student's grades list names each piece
  /// rather than repeating "Grade".
  assessmentTitle: z.string().min(1),
  /// exam, quiz, assignment and so on: how the gradebook groups it.
  category: z.string().min(1),
  score: z.number().nullable(),
  maximumScore: z.number().positive(),
  feedback: z.string().nullable(),
  state: z.enum(["draft", "reviewed", "published", "withdrawn"]),
  version: Version,
  reviewedAt: Timestamp.nullable(),
  publishedAt: Timestamp.nullable(),
  /// paper, online or practice: paper marks are shown as such, and kept
  /// apart from marks for work handed in online.
  delivery: z.enum(["paper", "online", "practice"]).optional(),
  /// scored, absent or not_graded. Absent and not graded carry no score and
  /// are never a zero. Null only for a mark not entered yet.
  mark: V1GradeMark.nullable().optional(),
  weight: GradeWeight.nullable().optional(),
  /// Set when the mark is for handed-in work.
  assignmentId: Id.nullable().optional(),
  /// This student's own files and links - a marked answer sheet, personal
  /// feedback - and the class's shared ones (the question paper). Present
  /// only once the grade is published, or for the class's staff.
  attachments: z.array(V1FileAttachment).max(10).optional(),
  links: z.array(V1ContentLink).max(10).optional(),
  sharedAttachments: z.array(V1FileAttachment).max(10).optional(),
  sharedLinks: z.array(V1ContentLink).max(10).optional(),
});
export type V1GradeResult = z.infer<typeof V1GradeResult>;

/// A student's own view of an online assessment, or a linked parent's view
/// of their child's. Four separate things: each attempt's confirmation, the
/// published grade, the teacher's feedback on it, and - once released - the
/// answers.
export const V1AssessmentResults = z.strictObject({
  assessment: V1Assessment,
  studentId: Id,
  opensAt: Timestamp.nullable(),
  /// The close time for this student, with any extension.
  closesAt: Timestamp.nullable(),
  attemptsAllowed: z.number().int().min(1),
  attemptsUsed: z.number().int().min(0),
  /// Whether the caller - the student themself - can submit now.
  canAttempt: z.boolean(),
  answersReleased: z.boolean(),
  attempts: z.array(V1AssessmentAttemptDetail),
  grade: V1GradeResult.nullable(),
});
export type V1AssessmentResults = z.infer<typeof V1AssessmentResults>;

/// A paper grade's attachments: the class's shared ones (no studentId) or
/// one student's own. Private until that student's grade is published.
export const V1UpdateGradeAttachmentsRequest = z.strictObject({
  studentId: Id.optional(),
  /// Uploads of purpose `paper_scan` for this class.
  attachmentFileIds: z.array(Id).max(10).optional(),
  detachFileIds: removedIds(10),
  links: contentLinks(10),
  removeLinkIds: removedIds(10),
});
export type V1UpdateGradeAttachmentsRequest = z.infer<
  typeof V1UpdateGradeAttachmentsRequest
>;

export const V1GradeAttachments = z.strictObject({
  gradeResultId: Id.optional(),
  attachments: z.array(V1FileAttachment).max(10),
  links: z.array(V1ContentLink).max(10),
});
export type V1GradeAttachments = z.infer<typeof V1GradeAttachments>;

export const V1GradeResultPage = z.strictObject({
  items: z.array(V1GradeResult),
  nextCursor: z.string().nullable(),
});
export type V1GradeResultPage = z.infer<typeof V1GradeResultPage>;

export const V1ReviewGradeRequest = z.strictObject({
  expectedVersion: Version,
  score: z.number().min(0),
  feedback: z.string().max(10_000).nullable(),
});
export type V1ReviewGradeRequest = z.infer<typeof V1ReviewGradeRequest>;

export const V1CorrectGradeRequest = V1ReviewGradeRequest.extend({
  reason: z.string().trim().min(3).max(500),
});
export type V1CorrectGradeRequest = z.infer<typeof V1CorrectGradeRequest>;

export const V1AttendanceEntry = z.strictObject({
  studentId: Id,
  state: z.enum(["present", "absent", "late", "excused"]),
  reason: z.string().max(500).nullable(),
});
export type V1AttendanceEntry = z.infer<typeof V1AttendanceEntry>;

export const V1AttendanceRecord = z.strictObject({
  id: Id,
  sessionId: Id,
  studentId: Id,
  state: z.enum(["present", "absent", "late", "excused"]),
  reason: z.string().nullable(),
  recordedAt: Timestamp,
  /**
   * The lesson the mark is for - its class and when it met - so a list of
   * marks says which day each one was. Present on every list read; a
   * register already names its lesson, so its rows leave these out.
   */
  classroomId: Id.optional(),
  startsAt: Timestamp.optional(),
  endsAt: Timestamp.optional(),
});
export type V1AttendanceRecord = z.infer<typeof V1AttendanceRecord>;

export const V1AttendancePage = z.strictObject({
  items: z.array(V1AttendanceRecord),
  nextCursor: z.string().nullable(),
});
export type V1AttendancePage = z.infer<typeof V1AttendancePage>;

export const V1AttendanceRosterItem = z.strictObject({
  student: V1StudentSummary,
  record: V1AttendanceRecord.nullable(),
  /**
   * False for a student who has left the class but was marked for this
   * lesson: listed after the class so the mark can still be corrected.
   */
  enrolled: z.boolean().optional(),
});
export type V1AttendanceRosterItem = z.infer<typeof V1AttendanceRosterItem>;
/// The session a register was read from, absent when the lesson has not been
/// recorded yet. Its version is what recordAttendance expects back: zero for
/// a session that does not exist, the current version for one that does.
export const V1AttendanceRosterSession = z.strictObject({
  id: Id,
  version: Version,
});
export type V1AttendanceRosterSession = z.infer<
  typeof V1AttendanceRosterSession
>;

export const V1AttendanceEditRule = z.enum([
  "open",
  "reason_required",
  "locked",
  "locked_override",
]);
export type V1AttendanceEditRule = z.infer<typeof V1AttendanceEditRule>;

export const V1AttendanceRosterPage = z.strictObject({
  items: z.array(V1AttendanceRosterItem),
  session: V1AttendanceRosterSession.nullable(),
  nextCursor: z.string().nullable(),
  /**
   * What the caller may do to this register under the school's lock rule:
   * open (change freely), reason_required (a changed mark needs a reason),
   * locked, or locked_override (locked, but this caller - the class's lead
   * teacher - may override it).
   */
  editRule: V1AttendanceEditRule.optional(),
});
export type V1AttendanceRosterPage = z.infer<typeof V1AttendanceRosterPage>;

export const V1RecordAttendanceRequest = z.strictObject({
  classroomId: Id,
  startsAt: Timestamp,
  endsAt: Timestamp,
  expectedVersion: z.number().int().min(0),
  entries: z.array(V1AttendanceEntry).min(1).max(200),
  /** Why a mark on a past lesson changed. Required by the school's policy. */
  correctionReason: z.string().trim().min(3).max(500).optional(),
  /** Override a locked register; only a lead teacher or school admin may. */
  override: z.boolean().optional(),
});
export type V1RecordAttendanceRequest = z.infer<
  typeof V1RecordAttendanceRequest
>;

export const V1RecordAttendanceResponse = z.strictObject({
  sessionId: Id,
  version: Version,
  recorded: z.number().int().min(1),
});
export type V1RecordAttendanceResponse = z.infer<
  typeof V1RecordAttendanceResponse
>;

export const V1WellbeingEvent = z.strictObject({
  id: Id,
  studentId: Id,
  classroomId: Id.nullable(),
  kind: z.enum(["strength", "concern", "note"]),
  title: z.string().min(1),
  context: z.string().nullable(),
  followUp: z.string().nullable(),
  visibility: z.enum([
    "class_staff",
    "guardian_shared",
    "student_guardian_shared",
  ]),
  severity: z.string().nullable(),
  createdAt: Timestamp,
});
export type V1WellbeingEvent = z.infer<typeof V1WellbeingEvent>;

export const V1WellbeingPage = z.strictObject({
  items: z.array(V1WellbeingEvent),
  nextCursor: z.string().nullable(),
});
export type V1WellbeingPage = z.infer<typeof V1WellbeingPage>;

export const V1CreateWellbeingRequest = z.strictObject({
  studentId: Id,
  classroomId: Id,
  kind: z.enum(["strength", "concern", "note"]),
  title: z.string().trim().min(1).max(200),
  context: z.string().max(10_000).nullable(),
  followUp: z.string().max(10_000).nullable(),
  visibility: z.enum([
    "class_staff",
    "guardian_shared",
    "student_guardian_shared",
  ]),
  severity: z.enum(["low", "moderate", "high"]).nullable(),
});
export type V1CreateWellbeingRequest = z.infer<typeof V1CreateWellbeingRequest>;

// ---------------------------------------------------------------------------
// Paper gradebook, corrections, attendance history and deadlines
// (2026-09-30). Marks for paper work are entered for a whole class, kept as
// drafts until published, and corrected with a reason and the value they
// replaced.
// ---------------------------------------------------------------------------

const Reason = z.string().trim().min(3).max(500);
const Feedback = z.string().max(2_000);

export const V1Actor = z.strictObject({
  id: Id,
  displayName: z.string(),
});
export type V1Actor = z.infer<typeof V1Actor>;

export const V1GradebookGrade = z.strictObject({
  id: Id,
  mark: V1GradeMark.nullable(),
  score: z.number().nullable(),
  feedback: z.string().nullable(),
  /// draft: not marked yet; reviewed: marked, not published; published.
  state: z.enum(["draft", "reviewed", "published", "withdrawn"]),
  version: Version,
  reviewedAt: Timestamp.nullable(),
  publishedAt: Timestamp.nullable(),
  updatedAt: Timestamp,
  /// How many times the published mark has been corrected.
  corrections: z.number().int().min(0),
  /// This student's own attachments on the grade.
  attachments: z.array(V1FileAttachment).max(10).optional(),
  links: z.array(V1ContentLink).max(10).optional(),
});
export type V1GradebookGrade = z.infer<typeof V1GradebookGrade>;

export const V1GradebookRow = z.strictObject({
  student: V1StudentSummary,
  /// False for a student who has left the class but already has a mark.
  enrolled: z.boolean(),
  grade: V1GradebookGrade.nullable(),
});
export type V1GradebookRow = z.infer<typeof V1GradebookRow>;

export const V1GradebookItem = V1Assessment.extend({
  /// Sent back when publishing, so exactly the sheet the teacher saw is
  /// published.
  gradebookVersion: z.number().int().min(0),
  counts: z.strictObject({
    unmarked: z.number().int().min(0),
    ready: z.number().int().min(0),
    published: z.number().int().min(0),
    withdrawn: z.number().int().min(0),
  }),
  /// The class's shared attachments: the question paper, general feedback.
  sharedAttachments: z.array(V1FileAttachment).max(10).optional(),
  sharedLinks: z.array(V1ContentLink).max(10).optional(),
});
export type V1GradebookItem = z.infer<typeof V1GradebookItem>;

export const V1Gradebook = z.strictObject({
  item: V1GradebookItem,
  items: z.array(V1GradebookRow),
  nextCursor: z.string().nullable(),
});
export type V1Gradebook = z.infer<typeof V1Gradebook>;

export const V1GradeDraftEntry = z.strictObject({
  studentId: Id,
  /// 0 for a student with no mark yet, else the row's current version.
  expectedVersion: z.number().int().min(0),
  /// null clears the mark back to "not marked yet".
  mark: V1GradeMark.nullable(),
  score: z.number().min(0).nullable().optional(),
  feedback: Feedback.nullable().optional(),
});
export type V1GradeDraftEntry = z.infer<typeof V1GradeDraftEntry>;

export const V1SaveGradeDraftsRequest = z.strictObject({
  expectedGradebookVersion: z.number().int().min(0).optional(),
  entries: z.array(V1GradeDraftEntry).min(1).max(100),
});
export type V1SaveGradeDraftsRequest = z.infer<typeof V1SaveGradeDraftsRequest>;

export const V1SavedGrade = z.strictObject({
  id: Id,
  studentId: Id,
  state: z.enum(["draft", "reviewed", "published", "withdrawn"]),
  version: Version,
});
export type V1SavedGrade = z.infer<typeof V1SavedGrade>;

export const V1SaveGradeDraftsResponse = z.strictObject({
  gradebookVersion: z.number().int().min(0),
  saved: z.number().int().min(0),
  grades: z.array(V1SavedGrade),
});
export type V1SaveGradeDraftsResponse = z.infer<
  typeof V1SaveGradeDraftsResponse
>;

export const V1PublishGradesRequest = z.strictObject({
  expectedGradebookVersion: z.number().int().min(0),
});
export type V1PublishGradesRequest = z.infer<typeof V1PublishGradesRequest>;

export const V1PublishGradesResponse = z.strictObject({
  gradebookVersion: z.number().int().min(0),
  published: z.number().int().min(1),
  /// Students left unmarked: still drafts, never published as zero.
  unmarked: z.number().int().min(0),
});
export type V1PublishGradesResponse = z.infer<typeof V1PublishGradesResponse>;

export const V1GradeCorrectionEntry = z.strictObject({
  gradeResultId: Id,
  expectedVersion: Version,
  mark: V1GradeMark,
  score: z.number().min(0).nullable().optional(),
  feedback: Feedback.nullable().optional(),
});
export type V1GradeCorrectionEntry = z.infer<typeof V1GradeCorrectionEntry>;

export const V1CorrectGradesRequest = z.strictObject({
  reason: Reason,
  entries: z.array(V1GradeCorrectionEntry).min(1).max(100),
});
export type V1CorrectGradesRequest = z.infer<typeof V1CorrectGradesRequest>;

export const V1CorrectGradesResponse = z.strictObject({
  gradebookVersion: z.number().int().min(0),
  corrected: z.number().int().min(0),
  /// Corrections that changed the mark, which the families were told about.
  notified: z.number().int().min(0),
  grades: z.array(V1SavedGrade),
});
export type V1CorrectGradesResponse = z.infer<typeof V1CorrectGradesResponse>;

export const V1GradeHistoryEntry = z.strictObject({
  id: z.string().min(1),
  change: z.enum([
    "proposed",
    "reviewed",
    "published",
    "corrected",
    "withdrawn",
  ]),
  previousState: z.string().nullable(),
  nextState: z.string(),
  previousMark: V1GradeMark.nullable(),
  previousScore: z.number().nullable(),
  previousFeedback: z.string().nullable(),
  nextMark: V1GradeMark.nullable(),
  nextScore: z.number().nullable(),
  nextFeedback: z.string().nullable(),
  reason: z.string().nullable(),
  actor: V1Actor.nullable(),
  createdAt: Timestamp,
});
export type V1GradeHistoryEntry = z.infer<typeof V1GradeHistoryEntry>;

export const V1GradeHistoryPage = z.strictObject({
  items: z.array(V1GradeHistoryEntry),
  nextCursor: z.string().nullable(),
});
export type V1GradeHistoryPage = z.infer<typeof V1GradeHistoryPage>;

export const V1UpdateGradebookItemRequest = z.strictObject({
  expectedVersion: Version,
  title: z.string().trim().min(1).max(200),
  category: z.string().trim().min(1).max(80),
  maximumScore: z.number().positive().max(100_000),
  weight: GradeWeight.nullable(),
  scheduledAt: Timestamp.nullable(),
});
export type V1UpdateGradebookItemRequest = z.infer<
  typeof V1UpdateGradebookItemRequest
>;

export const V1CorrectAttendanceRequest = z.strictObject({
  expectedVersion: Version,
  /// Required once the lesson's day has passed, and for any override.
  reason: z.string().trim().max(500).nullable().optional(),
  override: z.boolean().optional(),
  entries: z.array(V1AttendanceEntry).min(1).max(200),
});
export type V1CorrectAttendanceRequest = z.infer<
  typeof V1CorrectAttendanceRequest
>;

export const V1AttendanceHistoryEntry = z.strictObject({
  id: z.string().min(1),
  studentId: Id,
  studentName: z.string(),
  previousState: z.enum(["present", "absent", "late", "excused"]),
  previousReason: z.string().nullable(),
  nextState: z.enum(["present", "absent", "late", "excused"]),
  nextReason: z.string().nullable(),
  reason: z.string().nullable(),
  override: z.boolean(),
  actor: V1Actor.nullable(),
  createdAt: Timestamp,
});
export type V1AttendanceHistoryEntry = z.infer<typeof V1AttendanceHistoryEntry>;

export const V1AttendanceHistoryPage = z.strictObject({
  items: z.array(V1AttendanceHistoryEntry),
  nextCursor: z.string().nullable(),
});
export type V1AttendanceHistoryPage = z.infer<typeof V1AttendanceHistoryPage>;

export const V1AssignmentExtension = z.strictObject({
  id: Id,
  assignmentId: Id,
  studentId: Id,
  extendedUntil: Timestamp,
  extendedUntilLocal: LocalDateTime,
  reason: z.string().min(1),
  grantedBy: Id.nullable(),
  createdAt: Timestamp,
  revokedAt: Timestamp.nullable(),
});
export type V1AssignmentExtension = z.infer<typeof V1AssignmentExtension>;

export const V1AssignmentExtensionPage = z.strictObject({
  items: z.array(V1AssignmentExtension),
  nextCursor: z.string().nullable(),
});
export type V1AssignmentExtensionPage = z.infer<
  typeof V1AssignmentExtensionPage
>;

export const V1GrantExtensionRequest = z.strictObject({
  studentId: Id,
  /// On the school's clock.
  extendedUntilLocal: LocalDateTime,
  reason: Reason,
});
export type V1GrantExtensionRequest = z.infer<typeof V1GrantExtensionRequest>;

export const V1RevokeExtensionRequest = z.strictObject({
  studentId: Id,
});
export type V1RevokeExtensionRequest = z.infer<typeof V1RevokeExtensionRequest>;

export const V1ReopenAssignmentRequest = z.strictObject({
  expectedVersion: Version,
  /// The new closing time for the whole class, on the school's clock.
  closesAtLocal: LocalDateTime,
  reason: Reason,
});
export type V1ReopenAssignmentRequest = z.infer<
  typeof V1ReopenAssignmentRequest
>;

export const V1EditResourceRequest = z.strictObject({
  expectedVersion: Version,
  title: z.string().trim().min(1).max(200).optional(),
  body: z.string().max(30_000).nullable().optional(),
  /// A clean `lesson_resource` upload for the lesson's class. The file it
  /// replaces is kept for the school; students see only the new one.
  replaceFileId: Id.optional(),
  /// More `lesson_resource` uploads for the lesson's class, and files and
  /// links to take off it. What is not named carries on to the new version.
  attachmentFileIds: z.array(Id).max(10).optional(),
  detachFileIds: removedIds(10),
  links: contentLinks(10),
  removeLinkIds: removedIds(10),
});
export type V1EditResourceRequest = z.infer<typeof V1EditResourceRequest>;

export const V1UpdateWorkMaterialsRequest = z.strictObject({
  expectedVersion: Version,
  /// Taken off the work: hidden from the class, kept for the school.
  detachFileIds: z.array(Id).max(5),
  attachmentFileIds: attachmentFileIds(),
  links: contentLinks(10),
  removeLinkIds: removedIds(10),
});
export type V1UpdateWorkMaterialsRequest = z.infer<
  typeof V1UpdateWorkMaterialsRequest
>;
