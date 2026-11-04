import 'package:flutter/material.dart';

import '../core/feedback.dart';
import '../core/file_upload_repository.dart';
import '../core/navigation.dart';
import '../core/studafy_domain.dart';
import '../features/academic/domain/academic_repository.dart';
import '../features/academic/presentation/assessment_marking_page.dart';
import '../features/academic/presentation/assessment_page.dart';
import '../features/academic/presentation/submissions_page.dart';
import '../features/academic/presentation/submit_work_page.dart';

/// A student's own piece of work, to hand in while it is open. Only
/// published work can be handed in; a draft is not the student's to see as
/// open. In whichever of the student's schools the class is.
Future<void> openStudentHandIn(
  BuildContext context,
  AcademicRepository repository,
  AcademicRecord record, {
  FileUploadRepository? uploads,
  String? studentId,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final done = await Navigator.of(context).pushOnce<String>(
    MaterialPageRoute<String>(
      builder: (_) => SubmitWorkPage(
        repository: repository,
        assignmentId: record.id,
        assignmentTitle: record.title,
        canSubmit: record.state == 'published',
        deadline: record.deadline,
        instructions: record.detail,
        material: record.attachments,
        links: record.links,
        uploads: uploads,
        schoolId: ActiveContextController.instance.schoolFor(
          record.classroomId,
        ),
        studentId: studentId,
      ),
    ),
  );
  if (done != null) messenger.showMessage(done);
}

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

/// What a class handed in for one piece of work, for its teacher. In the
/// work's own class, or [classroomId] when the list was of one class.
Future<void> openSubmissionsForTeacher(
  BuildContext context,
  AcademicRepository repository,
  AcademicRecord record, {
  String? classroomId,
}) async {
  final classId = classroomId ?? record.classroomId;
  if (classId == null) return;
  await Navigator.of(context).pushOnce(
    MaterialPageRoute<void>(
      builder: (_) => SubmissionsPage(
        repository: repository,
        assignmentId: record.id,
        assignmentTitle: record.title,
        classroomId: classId,
        graded: record.maximumScore != null,
        assignmentVersion: record.version,
        timeZone: record.timeZone,
      ),
    ),
  );
}

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
