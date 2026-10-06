import 'package:flutter/material.dart';

import '../core/file_upload_repository.dart';
import '../core/navigation.dart';
import '../core/studafy_domain.dart';
import '../features/academic/domain/academic_repository.dart';
import '../features/academic/presentation/assessment_marking_page.dart';
import '../features/academic/presentation/assessment_page.dart';

/// Where an online assessment opens from each role's lists (ADR-0036), kept
/// out of the shells so each stays a list of tabs.

/// A student's own assessment, or - with [studentId] - a parent's read-only
/// view of their child's.
Future<void> openAssessmentForLearner(
  BuildContext context,
  OnlineAssessmentRepository repository,
  String assessmentId,
  String title, {
  String? studentId,
  String? childName,
}) => Navigator.of(context).pushOnce<void>(
  MaterialPageRoute<void>(
    builder: (_) => AssessmentPage(
      repository: repository,
      assessmentId: assessmentId,
      title: title,
      studentId: studentId,
      childName: childName,
    ),
  ),
);

/// A teacher's submissions and marking for one assessment.
Future<void> openAssessmentForTeacher(
  BuildContext context,
  AcademicRepository repository,
  String assessmentId,
  String title, {
  String? classroomId,
  FileUploadRepository? uploads,
}) => Navigator.of(context).pushOnce<void>(
  MaterialPageRoute<void>(
    builder: (_) => AssessmentMarkingPage(
      repository: repository,
      assessmentId: assessmentId,
      title: title,
      classroomId: classroomId,
      schoolId: ActiveContextController.instance.membership?.schoolId,
      uploads: uploads,
    ),
  ),
);
