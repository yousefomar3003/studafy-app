import { z } from "zod";

const Id = z.string().uuid();
const Timestamp = z.string().datetime({ offset: true });

/// How far back an insight looks.
export const V1InsightPeriod = z.enum(["last30", "term", "year"]);
export type V1InsightPeriod = z.infer<typeof V1InsightPeriod>;

export const V1FamilyInsightsQuery = z.strictObject({
  studentId: Id,
  period: V1InsightPeriod.default("term"),
});
export type V1FamilyInsightsQuery = z.infer<typeof V1FamilyInsightsQuery>;

/// How much data stands behind a signal.
///
/// `insufficient` is a first-class outcome, not a failure. A claim about a
/// child drawn from two marks is worse than no claim, so the client renders
/// this as "not enough yet" rather than inventing a number.
export const V1InsightConfidence = z.enum([
  "insufficient",
  "low",
  "medium",
  "high",
]);
export type V1InsightConfidence = z.infer<typeof V1InsightConfidence>;

/// What an evidence line measures, so a client can say it in the parent's
/// own language. `label` stays as the English wording for a client that does
/// not know the code.
export const V1InsightEvidenceCode = z.enum([
  "class_average",
  "overall_average",
  "recent_typical",
  "earlier_typical",
  "change",
  "on_time",
  "late",
  "not_handed_in",
  "weekday_absences",
  "absences_total",
  "due_soon",
  "missed_assessments",
  "attendance_rate",
  "sessions_counted",
  "past_due",
]);
export type V1InsightEvidenceCode = z.infer<typeof V1InsightEvidenceCode>;

/// One number a signal rests on, with how many records produced it.
export const V1InsightEvidence = z.strictObject({
  label: z.string().min(1).max(120),
  value: z.string().min(1).max(60),
  recordCount: z.number().int().nonnegative(),
  code: V1InsightEvidenceCode.optional(),
  /// For `weekday_absences`: 0 = Sunday ... 6 = Saturday, school-local.
  weekday: z.number().int().min(0).max(6).optional(),
});
export type V1InsightEvidence = z.infer<typeof V1InsightEvidence>;

export const V1InsightSignalKind = z.enum([
  "subject_focus",
  "grade_trend_up",
  "grade_trend_down",
  "homework_reliability",
  "homework_slipping",
  "attendance_pattern",
  "due_soon_unstarted",
  "recovery",
  "missing_work",
  "missed_assessments",
  "attendance_low",
  "strength",
]);
export type V1InsightSignalKind = z.infer<typeof V1InsightSignalKind>;

/// One thing worth a parent's attention.
///
/// `subject` names one of the child's own classes, never another child.
/// Nothing here predicts an outcome or describes a state of mind: a signal
/// reports what the records show and how many of them there were.
export const V1InsightSignal = z.strictObject({
  kind: V1InsightSignalKind,
  subject: z.string().max(120).nullable(),
  confidence: V1InsightConfidence,
  evidence: z.array(V1InsightEvidence).max(6),
});
export type V1InsightSignal = z.infer<typeof V1InsightSignal>;

export const V1SubjectBreakdown = z.strictObject({
  subject: z.string().min(1).max(120),
  averagePercent: z.number(),
  gradedCount: z.number().int().nonnegative(),
});
export type V1SubjectBreakdown = z.infer<typeof V1SubjectBreakdown>;

/// Where a class sits against the child's OTHER classes - never against
/// other children.
export const V1ClassStanding = z.enum(["strongest", "weakest"]);
export type V1ClassStanding = z.infer<typeof V1ClassStanding>;

export const V1ClassTrend = z.enum(["up", "down", "steady", "insufficient"]);
export type V1ClassTrend = z.infer<typeof V1ClassTrend>;

/// Everything about one class (a class is a subject here) in one line.
export const V1ClassInsight = z.strictObject({
  classroomId: Id,
  className: z.string().min(1).max(120),
  /// Marked work only. A missed test is counted in `missedAssessments`,
  /// never averaged in as a zero.
  averagePercent: z.number().nullable(),
  gradedCount: z.number().int().nonnegative(),
  latestPercent: z.number().nullable(),
  trend: V1ClassTrend,
  /// Typical recent mark minus typical earlier mark, when `trend` is known.
  trendPoints: z.number().nullable(),
  missedAssessments: z.number().int().nonnegative(),
  attendanceRatePercent: z.number().nullable(),
  absences: z.number().int().nonnegative(),
  homeworkDue: z.number().int().nonnegative(),
  homeworkMissing: z.number().int().nonnegative(),
  homeworkLate: z.number().int().nonnegative(),
  homeworkOnTimePercent: z.number().nullable(),
  standing: V1ClassStanding.nullable(),
});
export type V1ClassInsight = z.infer<typeof V1ClassInsight>;

/// The child's average mark over one stretch of time, for the chart.
export const V1InsightTimelinePoint = z.strictObject({
  start: Timestamp,
  averagePercent: z.number(),
  gradedCount: z.number().int().positive(),
});
export type V1InsightTimelinePoint = z.infer<typeof V1InsightTimelinePoint>;

export const V1RecentMark = z.strictObject({
  title: z.string().min(1).max(200),
  className: z.string().min(1).max(120),
  /// Null for a test the child missed.
  percent: z.number().nullable(),
  mark: z.enum(["scored", "absent"]),
  paper: z.boolean(),
  at: Timestamp,
});
export type V1RecentMark = z.infer<typeof V1RecentMark>;

/// Work whose due time has passed and that was never handed in.
export const V1MissingWork = z.strictObject({
  assignmentId: Id,
  title: z.string().min(1).max(200),
  className: z.string().max(120).nullable(),
  dueAt: Timestamp,
});
export type V1MissingWork = z.infer<typeof V1MissingWork>;

export const V1AttendanceSummary = z.strictObject({
  present: z.number().int().nonnegative(),
  late: z.number().int().nonnegative(),
  absent: z.number().int().nonnegative(),
  excused: z.number().int().nonnegative(),
  /// Present or late over sessions that were not excused; null with none.
  ratePercent: z.number().nullable(),
});
export type V1AttendanceSummary = z.infer<typeof V1AttendanceSummary>;

export const V1HomeworkSummary = z.strictObject({
  due: z.number().int().nonnegative(),
  onTime: z.number().int().nonnegative(),
  late: z.number().int().nonnegative(),
  missing: z.number().int().nonnegative(),
  onTimePercent: z.number().nullable(),
});
export type V1HomeworkSummary = z.infer<typeof V1HomeworkSummary>;

export const V1UpcomingWork = z.strictObject({
  assignmentId: Id,
  title: z.string().min(1).max(200),
  dueAt: Timestamp,
  submitted: z.boolean(),
});
export type V1UpcomingWork = z.infer<typeof V1UpcomingWork>;

/// A pastoral note the school chose to share with guardians.
///
/// Notes the school restricted to safeguarding staff are never returned by
/// this endpoint, at any subscription level.
export const V1SharedWellbeingNote = z.strictObject({
  id: Id,
  kind: z.string().min(1).max(60),
  title: z.string().min(1).max(200),
  createdAt: Timestamp,
});
export type V1SharedWellbeingNote = z.infer<typeof V1SharedWellbeingNote>;

export const V1FamilyInsightsResponse = z.strictObject({
  studentId: Id,
  studentName: z.string().min(1).max(160),
  period: V1InsightPeriod,
  from: Timestamp,
  to: Timestamp,
  gradedCount: z.number().int().nonnegative(),
  averagePercent: z.number().nullable(),
  subjects: z.array(V1SubjectBreakdown).max(50),
  attendance: V1AttendanceSummary,
  homework: V1HomeworkSummary,
  upcoming: z.array(V1UpcomingWork).max(20),
  wellbeing: z.array(V1SharedWellbeingNote).max(20),
  signals: z.array(V1InsightSignal).max(10),
  /// Typical recent mark minus typical earlier mark across all classes;
  /// null until there are enough marks to say.
  averageChange: z.number().nullable().optional(),
  missedAssessments: z.number().int().nonnegative().optional(),
  classes: z.array(V1ClassInsight).max(50).optional(),
  timeline: z.array(V1InsightTimelinePoint).max(26).optional(),
  recentMarks: z.array(V1RecentMark).max(10).optional(),
  missingWork: z.array(V1MissingWork).max(20).optional(),
});
export type V1FamilyInsightsResponse = z.infer<
  typeof V1FamilyInsightsResponse
>;
