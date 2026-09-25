import 'package:flutter/foundation.dart';

/// How much data stands behind a claim about a child.
///
/// `insufficient` is a real answer, not a failure. A statement about somebody's
/// child drawn from two marks is worse than silence, so the screen says "not
/// enough yet" rather than showing a number that looks authoritative.
enum InsightStrength { insufficient, low, medium, high }

/// One number a signal rests on, and how many records produced it.
@immutable
class InsightEvidenceItem {
  const InsightEvidenceItem({
    required this.label,
    required this.value,
    required this.recordCount,
  });

  final String label;
  final String value;
  final int recordCount;
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
}

/// Reads Family+ insights for one linked child.
///
/// The server refuses without a live subscription and a verified link, so a
/// failure here is the paywall, not a bug.
abstract interface class FamilyInsightsRepository {
  Future<FamilyInsights> forStudent(String studentId);
}
