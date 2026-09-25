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

/// One number a signal rests on, with how many records produced it.
export const V1InsightEvidence = z.strictObject({
  label: z.string().min(1).max(120),
  value: z.string().min(1).max(60),
  recordCount: z.number().int().nonnegative(),
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
]);
export type V1InsightSignalKind = z.infer<typeof V1InsightSignalKind>;

/// One thing worth a parent's attention.
///
/// `subject` names a category of the child's own work, never another child.
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
});
export type V1FamilyInsightsResponse = z.infer<
  typeof V1FamilyInsightsResponse
>;
