import 'package:flutter/foundation.dart';

enum AcademicFeed {
  content,
  assignments,
  assessments,
  grades,
  attendance,
  wellbeing,
}

@immutable
class AcademicRecord {
  const AcademicRecord({
    required this.id,
    required this.title,
    required this.detail,
    required this.state,
    required this.version,
  });
  final String id;
  final String title;
  final String detail;
  final String state;
  final int version;
}

@immutable
class TextResourceDraft {
  const TextResourceDraft({
    required this.classroomId,
    required this.title,
    required this.body,
  });
  final String classroomId;
  final String title;
  final String body;
}

@immutable
class AssignmentDraft {
  const AssignmentDraft({
    required this.classroomId,
    required this.title,
    required this.instructions,
    required this.dueAt,
    this.closesAt,
  });
  final String classroomId;
  final String title;
  final String instructions;
  final DateTime dueAt;
  final DateTime? closesAt;
}

@immutable
class AssessmentDraft {
  const AssessmentDraft({
    required this.classroomId,
    required this.title,
    required this.maximumScore,
    required this.questions,
  });
  final String classroomId;
  final String title;
  final double maximumScore;
  final List<AssessmentQuestionDraft> questions;
}

@immutable
class AssessmentQuestionDraft {
  const AssessmentQuestionDraft({
    required this.prompt,
    required this.maximumScore,
    this.preferredAnswer,
  });
  final String prompt;
  final double maximumScore;
  final String? preferredAnswer;
}

@immutable
class AttendanceDraft {
  const AttendanceDraft({
    required this.studentId,
    required this.state,
    this.reason,
  });
  final String studentId;
  final String state;
  final String? reason;
}

@immutable
class WellbeingDraft {
  const WellbeingDraft({
    required this.classroomId,
    required this.studentId,
    required this.kind,
    required this.title,
    this.context,
  });
  final String classroomId;
  final String studentId;
  final String kind;
  final String title;
  final String? context;
}

/// Typed mobile boundary for every API-041 slice. Remote implementations must
/// fail closed; preview implementations are the only adapters allowed to use
/// SQLite.
abstract interface class AcademicRepository {
  Future<List<AcademicRecord>> load(
    AcademicFeed feed, {
    String? classroomId,
    String? studentId,
  });
  Future<void> createResource(TextResourceDraft draft);
  Future<void> reviseResource(
    String resourceId,
    int expectedVersion,
    String title,
    String body,
  );
  Future<void> publishResource(String resourceId, int expectedVersion);
  Future<void> withdrawResource(String resourceId, int expectedVersion);
  Future<void> createAssignment(AssignmentDraft draft);
  Future<void> publishAssignment(String assignmentId, int expectedVersion);
  Future<void> withdrawAssignment(String assignmentId, int expectedVersion);
  Future<void> createAssessment(AssessmentDraft draft);
  Future<void> publishAssessment(String assessmentId, int expectedVersion);
  Future<void> withdrawAssessment(String assessmentId, int expectedVersion);
  Future<void> submitAssignment(String assignmentId, String answer);
  Future<void> submitAssessment(
    String assessmentId,
    Map<String, String> answers,
  );
  Future<void> recordAttendance(
    String classroomId,
    DateTime startsAt,
    DateTime endsAt,
    int expectedVersion,
    List<AttendanceDraft> entries,
  );
  Future<void> reviewGrade(
    String gradeId,
    int expectedVersion,
    double score, {
    String? feedback,
  });
  Future<void> publishGrade(String gradeId, int expectedVersion);
  Future<void> correctGrade(
    String gradeId,
    int expectedVersion,
    double score,
    String reason, {
    String? feedback,
  });
  Future<void> withdrawGrade(String gradeId, int expectedVersion);
  Future<void> createWellbeing(WellbeingDraft draft);
}
