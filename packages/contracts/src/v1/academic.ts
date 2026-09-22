import { z } from "zod";

const Id = z.string().uuid();
const Timestamp = z.string().datetime({ offset: true });
const Version = z.number().int().positive();

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
  schedule: z.array(V1ScheduleSlotInput).max(21),
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

export const V1ReplaceScheduleRequest = z.strictObject({
  expectedVersion: Version,
  schedule: z.array(V1ScheduleSlotInput).max(21),
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
});
export type V1CreateAssignmentRequest = z.infer<
  typeof V1CreateAssignmentRequest
>;

export const V1SubmitAssignmentRequest = z.strictObject({
  answerText: z.string().trim().min(1).max(100_000),
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
});
export type V1Submission = z.infer<typeof V1Submission>;

export const V1SubmissionPage = z.strictObject({
  items: z.array(V1Submission),
  nextCursor: z.string().nullable(),
});
export type V1SubmissionPage = z.infer<typeof V1SubmissionPage>;

export const V1AssessmentQuestion = z.strictObject({
  id: Id,
  position: z.number().int().positive(),
  prompt: z.string().min(1),
  maximumScore: z.number().positive(),
});
export type V1AssessmentQuestion = z.infer<typeof V1AssessmentQuestion>;

export const V1AssessmentAuthoringQuestion = V1AssessmentQuestion.extend({
  preferredAnswer: z.string().nullable(),
});
export type V1AssessmentAuthoringQuestion = z.infer<
  typeof V1AssessmentAuthoringQuestion
>;

export const V1AssessmentQuestionDraft = z.strictObject({
  position: z.number().int().positive(),
  prompt: z.string().trim().min(1).max(10_000),
  preferredAnswer: z.string().max(30_000).nullable(),
  maximumScore: z.number().positive(),
});
export type V1AssessmentQuestionDraft = z.infer<
  typeof V1AssessmentQuestionDraft
>;

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
});
export type V1CreateAssessmentRequest = z.infer<
  typeof V1CreateAssessmentRequest
>;

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

export const V1AssessmentAnswer = z.strictObject({
  questionId: Id,
  answerText: z.string().max(30_000),
});
export type V1AssessmentAnswer = z.infer<typeof V1AssessmentAnswer>;

export const V1SubmitAssessmentRequest = z.strictObject({
  answers: z.array(V1AssessmentAnswer).min(1).max(100),
});
export type V1SubmitAssessmentRequest = z.infer<
  typeof V1SubmitAssessmentRequest
>;

export const V1AssessmentAttempt = z.strictObject({
  id: Id,
  assessmentId: Id,
  studentId: Id,
  submittedAt: Timestamp,
  version: Version,
});
export type V1AssessmentAttempt = z.infer<typeof V1AssessmentAttempt>;
export const V1AssessmentAttemptPage = z.strictObject({
  items: z.array(V1AssessmentAttempt),
  nextCursor: z.string().nullable(),
});
export type V1AssessmentAttemptPage = z.infer<typeof V1AssessmentAttemptPage>;

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
});
export type V1GradeResult = z.infer<typeof V1GradeResult>;

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

export const V1AttendanceRosterPage = z.strictObject({
  items: z.array(V1AttendanceRosterItem),
  session: V1AttendanceRosterSession.nullable(),
  nextCursor: z.string().nullable(),
});
export type V1AttendanceRosterPage = z.infer<typeof V1AttendanceRosterPage>;

export const V1RecordAttendanceRequest = z.strictObject({
  classroomId: Id,
  startsAt: Timestamp,
  endsAt: Timestamp,
  expectedVersion: z.number().int().min(0),
  entries: z.array(V1AttendanceEntry).min(1).max(200),
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
