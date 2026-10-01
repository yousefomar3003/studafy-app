import 'package:flutter/foundation.dart';

/// How much data stands behind a claim about a child.
///
/// `insufficient` is a real answer, not a failure. A statement about somebody's
/// child drawn from two marks is worse than silence, so the screen says "not
/// enough yet" rather than showing a number that looks authoritative.
enum InsightStrength { insufficient, low, medium, high }

/// What an evidence line measures, so it can be said in the reader's
/// language. [unknown] falls back to the server's English label.
enum InsightEvidenceCode {
  classAverage,
  overallAverage,
  recentTypical,
  earlierTypical,
  change,
  onTime,
  late,
  notHandedIn,
  weekdayAbsences,
  absencesTotal,
  dueSoon,
  missedAssessments,
  attendanceRate,
  sessionsCounted,
  pastDue,
  unknown,
}

/// One number a signal rests on, and how many records produced it.
@immutable
class InsightEvidenceItem {
  const InsightEvidenceItem({
    required this.label,
    required this.value,
    required this.recordCount,
    this.code = InsightEvidenceCode.unknown,
    this.weekday,
  });

  final String label;
  final String value;
  final int recordCount;
  final InsightEvidenceCode code;

  /// For [InsightEvidenceCode.weekdayAbsences]: 0 = Sunday ... 6 = Saturday.
  final int? weekday;
}

enum InsightKind {
  subjectFocus,
  gradeTrendUp,
  gradeTrendDown,
  homeworkReliability,
  homeworkSlipping,
  attendancePattern,
  dueSoonUnstarted,
  recovery,
  missingWork,
  missedAssessments,
  attendanceLow,
  strength,
}

/// One thing worth a parent's attention, with the records behind it.
@immutable
class InsightSignal {
  const InsightSignal({
    required this.kind,
    required this.subject,
    required this.strength,
    required this.evidence,
  });

  final InsightKind kind;

  /// A subject of the child's own work, never another child.
  final String? subject;
  final InsightStrength strength;
  final List<InsightEvidenceItem> evidence;
}

@immutable
class SubjectBreakdown {
  const SubjectBreakdown({
    required this.subject,
    required this.averagePercent,
    required this.gradedCount,
  });

  final String subject;
  final double averagePercent;
  final int gradedCount;
}

enum ClassTrend { up, down, steady, insufficient }

enum ClassStanding { strongest, weakest }

/// One class (a class is a subject here), everything in one line.
@immutable
class ClassInsight {
  const ClassInsight({
    required this.classroomId,
    required this.className,
    required this.averagePercent,
    required this.gradedCount,
    required this.latestPercent,
    required this.trend,
    required this.trendPoints,
    required this.missedAssessments,
    required this.attendanceRatePercent,
    required this.absences,
    required this.homeworkDue,
    required this.homeworkMissing,
    required this.homeworkLate,
    required this.homeworkOnTimePercent,
    required this.standing,
  });

  final String classroomId;
  final String className;
  final double? averagePercent;
  final int gradedCount;
  final double? latestPercent;
  final ClassTrend trend;
  final double? trendPoints;
  final int missedAssessments;
  final double? attendanceRatePercent;
  final int absences;
  final int homeworkDue;
  final int homeworkMissing;
  final int homeworkLate;
  final double? homeworkOnTimePercent;
  final ClassStanding? standing;
}

/// The child's average over one week or month, for the chart.
@immutable
class InsightTimelinePoint {
  const InsightTimelinePoint({
    required this.start,
    required this.averagePercent,
    required this.gradedCount,
  });

  final DateTime start;
  final double averagePercent;
  final int gradedCount;
}

@immutable
class RecentMark {
  const RecentMark({
    required this.title,
    required this.className,
    required this.percent,
    required this.paper,
    required this.at,
  });

  final String title;
  final String className;

  /// Null for a test the child missed.
  final double? percent;
  final bool paper;
  final DateTime at;
}

/// Work whose deadline passed and that was never handed in.
@immutable
class MissingWorkItem {
  const MissingWorkItem({
    required this.assignmentId,
    required this.title,
    required this.className,
    required this.dueAt,
  });

  final String assignmentId;
  final String title;
  final String? className;
  final DateTime dueAt;
}

@immutable
class AttendanceSummary {
  const AttendanceSummary({
    required this.present,
    required this.late,
    required this.absent,
    required this.excused,
    required this.ratePercent,
  });

  final int present;
  final int late;
  final int absent;
  final int excused;

  /// Null when nothing has been recorded. Zero would read as "never attends".
  final double? ratePercent;
}

@immutable
class HomeworkSummary {
  const HomeworkSummary({
    required this.due,
    required this.onTime,
    required this.late,
    required this.missing,
    required this.onTimePercent,
  });

  final int due;
  final int onTime;
  final int late;
  final int missing;
  final double? onTimePercent;
}

@immutable
class UpcomingWork {
  const UpcomingWork({
    required this.assignmentId,
    required this.title,
    required this.dueAt,
  });

  final String assignmentId;
  final String title;
  final DateTime dueAt;
}

/// A pastoral note the school chose to share with guardians.
@immutable
class SharedWellbeingNote {
  const SharedWellbeingNote({
    required this.id,
    required this.title,
    required this.createdAt,
  });

  final String id;
  final String title;
  final DateTime createdAt;
}

@immutable
class FamilyInsights {
  const FamilyInsights({
    required this.studentName,
    required this.gradedCount,
    required this.averagePercent,
    required this.subjects,
    required this.attendance,
    required this.homework,
    required this.upcoming,
    required this.wellbeing,
    required this.signals,
    this.averageChange,
    this.missedAssessments = 0,
    this.classes = const [],
    this.timeline = const [],
    this.recentMarks = const [],
    this.missingWork = const [],
  });

  final String studentName;
  final int gradedCount;
  final double? averagePercent;
  final List<SubjectBreakdown> subjects;
  final AttendanceSummary attendance;
  final HomeworkSummary homework;
  final List<UpcomingWork> upcoming;
  final List<SharedWellbeingNote> wellbeing;
  final List<InsightSignal> signals;

  /// Typical recent mark minus typical earlier mark; null until there are
  /// enough marks to say.
  final double? averageChange;
  final int missedAssessments;
  final List<ClassInsight> classes;
  final List<InsightTimelinePoint> timeline;
  final List<RecentMark> recentMarks;
  final List<MissingWorkItem> missingWork;
}

/// Reads Family+ insights for one linked child.
///
/// The server refuses without a live subscription and a verified link, so a
/// failure here is the paywall, not a bug.
abstract interface class FamilyInsightsRepository {
  Future<FamilyInsights> forStudent(String studentId);
}
