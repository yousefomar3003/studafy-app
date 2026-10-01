import 'package:flutter/material.dart';

import '../core/feedback.dart';
import '../core/navigation.dart';
import '../core/studafy_components.dart';
import '../core/studafy_design.dart';
import '../core/studafy_domain.dart';
import '../features/academic/domain/academic_repository.dart';
import '../features/academic/presentation/attendance_page.dart';
import '../features/academic/presentation/create_assignment_page.dart';
import '../features/academic/presentation/create_exam_page.dart';
import '../features/academic/presentation/create_lesson_page.dart';
import '../features/academic/presentation/create_wellbeing_page.dart';
import '../features/academic/presentation/gradebook_page.dart';
import '../features/messaging/presentation/create_announcement_page.dart';
import '../features/messaging/presentation/messaging_scope.dart';
import '../l10n/generated/app_l10n.dart';
import 'app_dependencies.dart';

/// Everything a teacher creates - lessons, assignments, exams, announcements
/// and attendance - from the shell's one "Create" button, or from inside a
/// class. Composed here, in the app layer, because it reaches the academic
/// and messaging features, which may not import each other.
class TeacherCreateActions {
  const TeacherCreateActions(this.dependencies);

  final AppDependencies dependencies;

  /// Opens the announcement composer for one of this teacher's classes.
  Future<void> newAnnouncement(BuildContext context) async {
    final schoolId = ActiveContextController.instance.membership?.schoolId;
    if (schoolId == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final classes = await dependencies.classes.loadClasses();
    if (!context.mounted) return;
    final targets = classes.fold<List<AnnouncementTarget>>(
      onSuccess: (list) => [
        for (final classroom in list)
          AnnouncementTarget(id: classroom.id.value, name: classroom.name),
      ],
      onFailure: (_) => const <AnnouncementTarget>[],
    );
    if (targets.isEmpty) return;
    final posted = await Navigator.of(context).pushOnce<String>(
      MaterialPageRoute<String>(
        builder: (_) => CreateAnnouncementPage(
          messaging: MessagingScope.of(context),
          schoolId: schoolId,
          classes: targets,
        ),
      ),
    );
    if (posted != null) {
      messenger.showMessage(posted);
    }
  }

  /// This teacher's classes, for a form that asks which one. With none it
  /// says so, rather than a button that does nothing.
  Future<List<ClassOption>?> _classOptions(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppL10n.of(context);
    final classes = await dependencies.classes.loadClasses();
    final options = classes.fold<List<ClassOption>>(
      onSuccess: (list) => [
        for (final classroom in list)
          ClassOption(id: classroom.id.value, name: classroom.name),
      ],
      onFailure: (_) => const <ClassOption>[],
    );
    if (options.isEmpty) {
      messenger.showMessage(l10n.teacherNoClassesYet);
      return null;
    }
    return options;
  }

  /// Opens a create form and shows what it reports on the way back.
  Future<void> _openForm(
    BuildContext context,
    Widget Function(List<ClassOption> classes) form,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final options = await _classOptions(context);
    if (options == null || !context.mounted) return;
    final created = await Navigator.of(context).pushOnce<String>(
      MaterialPageRoute<String>(builder: (_) => form(options)),
    );
    if (created != null) messenger.showMessage(created);
  }

  String? get _schoolId =>
      ActiveContextController.instance.membership?.schoolId;

  /// A lesson: notes and files for a class, which students see by date.
  Future<void> newLesson(BuildContext context, {String? classroomId}) =>
      _openForm(
        context,
        (classes) => CreateLessonPage(
          repository: dependencies.academic,
          classes: classes,
          initialClassroomId: classroomId,
          schoolId: _schoolId,
          uploads: dependencies.fileUploads,
        ),
      );

  /// An exam or other assessment, marked in the gradebook, with its paper.
  Future<void> newExam(BuildContext context, {String? classroomId}) =>
      _openForm(
        context,
        (classes) => CreateExamPage(
          repository: dependencies.academic,
          classes: classes,
          initialClassroomId: classroomId,
          schoolId: _schoolId,
          uploads: dependencies.fileUploads,
        ),
      );

  /// Work students hand in. [classroomId] is preselected inside a class;
  /// elsewhere the teacher picks the class in the form.
  Future<void> newAssignment(BuildContext context, {String? classroomId}) =>
      _openForm(
        context,
        (classes) => CreateAssignmentPage(
          repository: dependencies.academic,
          classes: classes,
          initialClassroomId: classroomId,
          schoolId: _schoolId,
          uploads: dependencies.fileUploads,
        ),
      );

  /// Today's register. A teacher with one class goes straight to it.
  Future<void> takeAttendance(BuildContext context) async {
    final options = await _classOptions(context);
    if (options == null || !context.mounted) return;
    final chosen = options.length == 1
        ? options.single
        : await showDialog<ClassOption>(
            context: context,
            builder: (dialogContext) => SimpleDialog(
              title: Text(AppL10n.of(dialogContext).teacherPickClass),
              children: [
                for (final option in options)
                  SimpleDialogOption(
                    onPressed: () => Navigator.pop(dialogContext, option),
                    child: Text(option.name),
                  ),
              ],
            ),
          );
    if (chosen == null || !context.mounted) return;
    await Navigator.of(context).pushOnce(
      MaterialPageRoute<void>(
        builder: (_) => AttendancePage(
          repository: dependencies.academic,
          classroomId: chosen.id,
          classroomName: chosen.name,
        ),
      ),
    );
  }

  /// Marks for paper work: a class's gradebook, where a paper exam, quiz or
  /// homework is set up and marked for the whole class in one sheet. A
  /// teacher with one class goes straight to it.
  Future<void> paperGrades(BuildContext context) async {
    final options = await _classOptions(context);
    if (options == null || !context.mounted) return;
    final chosen = options.length == 1
        ? options.single
        : await showDialog<ClassOption>(
            context: context,
            builder: (dialogContext) => SimpleDialog(
              title: Text(AppL10n.of(dialogContext).teacherPickClass),
              children: [
                for (final option in options)
                  SimpleDialogOption(
                    onPressed: () => Navigator.pop(dialogContext, option),
                    child: Text(option.name),
                  ),
              ],
            ),
          );
    if (chosen == null || !context.mounted) return;
    await Navigator.of(context).pushOnce(
      MaterialPageRoute<void>(
        builder: (_) => ClassGradebookPage(
          repository: dependencies.academic,
          classroomId: chosen.id,
          classroomName: chosen.name,
        ),
      ),
    );
  }

  /// A wellbeing note about one student in one of this teacher's classes.
  Future<void> newWellbeing(BuildContext context) => _openForm(
    context,
    (classes) => CreateWellbeingPage(
      repository: dependencies.academic,
      classes: classes,
    ),
  );

  /// Everything a teacher makes, in one place: the sheet the "+" opens.
  Future<void> openCreateMenu(BuildContext context) async {
    final l10n = AppL10n.of(context);
    final canAnnounce =
        MessagingScope.isAvailable(context) && _schoolId != null;
    final action = await showModalBottomSheet<Future<void> Function()>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        Widget item(
          IconData icon,
          String title,
          String detail,
          Future<void> Function() run,
        ) => SettingsRow(
          icon: icon,
          title: title,
          subtitle: detail,
          onTap: () => Navigator.pop(sheetContext, run),
        );
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(sheetContext).height * .85,
            ),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 16),
              children: [
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(4, 0, 4, 4),
                  child: Text(
                    l10n.teacherCreateTitle,
                    style: const TextStyle(
                      color: studafyInk,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                SettingsGroup(
                  title: l10n.teacherCreateGroupTeaching,
                  children: [
                    item(
                      Icons.menu_book_rounded,
                      l10n.teacherCreateLesson,
                      l10n.teacherCreateLessonDetail,
                      () => newLesson(context),
                    ),
                    item(
                      Icons.assignment_add,
                      l10n.teacherCreateAssignment,
                      l10n.teacherCreateAssignmentDetail,
                      () => newAssignment(context),
                    ),
                    item(
                      Icons.quiz_rounded,
                      l10n.teacherCreateExam,
                      l10n.teacherCreateExamDetail,
                      () => newExam(context),
                    ),
                  ],
                ),
                SettingsGroup(
                  title: l10n.teacherCreateGroupClass,
                  children: [
                    item(
                      Icons.grading_rounded,
                      l10n.teacherCreatePaperGrades,
                      l10n.teacherCreatePaperGradesDetail,
                      () => paperGrades(context),
                    ),
                    item(
                      Icons.fact_check_rounded,
                      l10n.teacherCreateAttendance,
                      l10n.teacherCreateAttendanceDetail,
                      () => takeAttendance(context),
                    ),
                    item(
                      Icons.favorite_rounded,
                      l10n.wellbeingNewTitle,
                      l10n.teacherCreateWellbeingDetail,
                      () => newWellbeing(context),
                    ),
                  ],
                ),
                if (canAnnounce)
                  SettingsGroup(
                    title: l10n.teacherCreateGroupFamilies,
                    children: [
                      item(
                        Icons.campaign_rounded,
                        l10n.teacherCreateAnnouncement,
                        l10n.teacherCreateAnnouncementDetail,
                        () => newAnnouncement(context),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
    if (action != null && context.mounted) await action();
  }
}
