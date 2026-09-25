import 'package:flutter/material.dart';

import '../core/studafy_design.dart';
import '../core/studafy_localizations.dart';
import '../features/classes/domain/classroom.dart';
import '../features/classes/presentation/classes_page.dart';
import '../features/academic/presentation/academic_overview_page.dart';
import '../l10n/generated/app_l10n.dart';
import '../features/academic/presentation/attendance_page.dart';
import '../features/academic/presentation/class_roster_page.dart';
import '../features/academic/presentation/create_assignment_page.dart';
import '../features/academic/presentation/create_exam_page.dart';
import '../features/academic/presentation/class_sections_page.dart';
import '../features/academic/presentation/class_schedule_page.dart';
import '../features/academic/presentation/submissions_page.dart';
import '../features/academic/presentation/gradebook_page.dart';
import '../features/messaging/presentation/create_announcement_page.dart';
import '../features/messaging/presentation/messaging_scope.dart';
import '../core/studafy_domain.dart';
import '../features/academic/domain/academic_repository.dart';
import '../features/messaging/presentation/conversations_page.dart';
import '../features/school_operations/presentation/classroom_management_page.dart';
import '../features/school_operations/domain/school_operations_repository.dart';
import '../teacher_features.dart';
import 'teacher_today_page.dart';
import 'app_dependencies.dart';

class TeacherShell extends StatefulWidget {
  const TeacherShell({super.key, required this.dependencies});
  final AppDependencies dependencies;
  @override
  State<TeacherShell> createState() => _TeacherShellState();
}

class _TeacherShellState extends State<TeacherShell> {
  int index = 0;

  // API-041 classes open only the typed authoritative/preview academic port.
  /// Opens a conversation with a child's guardian.
  ///
  /// Contact runs through Studafy's own messaging rather than by handing the
  /// teacher a family's phone number: those threads are moderated, logged,
  /// and can be reported or blocked by either side.
  Future<void> _messageGuardian(
    BuildContext context,
    StudentGuardian guardian,
  ) async {
    final schoolId = ActiveContextController.instance.membership?.schoolId;
    if (schoolId == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final result = await MessagingScope.of(
      context,
    ).startConversation(schoolId: schoolId, participantIds: [guardian.userId]);
    result.fold(
      onSuccess: (_) => navigator.push(
        MaterialPageRoute<void>(builder: (_) => const ConversationsPage()),
      ),
      onFailure: (failure) =>
          messenger.showSnackBar(SnackBar(content: Text(failure.message))),
    );
  }

  /// Supplies the class filter its options, so every feed a teacher reads
  /// can be narrowed to one of their classes.
  Future<List<ClassChoice>> _classChoices() async {
    final result = await widget.dependencies.classes.loadClasses();
    return result.fold(
      onSuccess: (items) => [
        for (final item in items)
          ClassChoice(id: item.id.value, name: item.name),
      ],
      onFailure: (_) => const [],
    );
  }

  /// Opens the announcement composer for one of this teacher's classes.
  Future<void> _newAnnouncement(BuildContext context) async {
    final schoolId = ActiveContextController.instance.membership?.schoolId;
    if (schoolId == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final classes = await widget.dependencies.classes.loadClasses();
    if (!context.mounted) return;
    final targets = classes.fold<List<AnnouncementTarget>>(
      onSuccess: (list) => [
        for (final classroom in list)
          AnnouncementTarget(id: classroom.id.value, name: classroom.name),
      ],
      onFailure: (_) => const <AnnouncementTarget>[],
    );
    if (targets.isEmpty) return;
    final posted = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => CreateAnnouncementPage(
          messaging: MessagingScope.of(context),
          schoolId: schoolId,
          classes: targets,
        ),
      ),
    );
    if (posted != null) {
      messenger.showSnackBar(SnackBar(content: Text(posted)));
    }
  }

  /// Opens the exam authoring screen.
  Future<void> _newExam(BuildContext context, {String? classroomId}) async {
    final messenger = ScaffoldMessenger.of(context);
    final classes = await widget.dependencies.classes.loadClasses();
    if (!context.mounted) return;
    final options = classes.fold<List<ClassOption>>(
      onSuccess: (list) => [
        for (final classroom in list)
          ClassOption(id: classroom.id.value, name: classroom.name),
      ],
      onFailure: (_) => const <ClassOption>[],
    );
    if (options.isEmpty) return;
    final created = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => CreateExamPage(
          repository: widget.dependencies.academic,
          classes: options,
          initialClassroomId: classroomId,
        ),
      ),
    );
    if (created != null) {
      messenger.showSnackBar(SnackBar(content: Text(created)));
    }
  }

  /// Opens the "new assignment" form.
  ///
  /// [classroomId] is preselected when the teacher is already inside a class;
  /// from the Teaching tab they pick the class in the form, because that tab
  /// is not scoped to one.
  Future<void> _newAssignment(
    BuildContext context, {
    String? classroomId,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final classes = await widget.dependencies.classes.loadClasses();
    if (!context.mounted) return;
    final options = classes.fold<List<ClassOption>>(
      onSuccess: (list) => [
        for (final classroom in list)
          ClassOption(id: classroom.id.value, name: classroom.name),
      ],
      onFailure: (_) => const <ClassOption>[],
    );
    if (options.isEmpty) return;
    final created = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => CreateAssignmentPage(
          repository: widget.dependencies.academic,
          classes: options,
          initialClassroomId: classroomId,
        ),
      ),
    );
    if (created != null) {
      messenger.showSnackBar(SnackBar(content: Text(created)));
    }
  }

  Future<void> _openClassroom(ClassroomSummary classroom) async {
    final academic = widget.dependencies.academic;
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => AcademicOverviewPage(
          repository: academic,
          classroomId: classroom.id.value,
          teacherTools: true,
          uploads: widget.dependencies.fileUploads,
          schoolId: ActiveContextController.instance.membership?.schoolId,
          // Tapping a piece of work shows who has handed it in. Students
          // can submit now, so without this the loop has no other end.
          onOpenRecord: (record) => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => SubmissionsPage(
                repository: academic,
                assignmentId: record.id,
                assignmentTitle: record.title,
                classroomId: classroom.id.value,
              ),
            ),
          ),
          actions: [
            if (widget.dependencies.schoolOperations != null)
              Builder(
                builder: (pageContext) => _ClassToolButton(
                  tooltip:
                      Localizations.localeOf(pageContext).languageCode == 'ar'
                      ? 'إدارة الطلاب والمعلمين والاجتماعات'
                      : 'Manage roster, staff and meetings',
                  icon: const Icon(Icons.tune_rounded),
                  onPressed: () async {
                    final result = await widget.dependencies.classes
                        .loadClasses();
                    if (!pageContext.mounted) return;
                    final classrooms = result.fold(
                      onSuccess: (value) => value,
                      onFailure: (_) => <ClassroomSummary>[classroom],
                    );
                    await Navigator.of(pageContext).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ClassroomManagementPage(
                          repository: widget.dependencies.schoolOperations!,
                          classroom: ManagedClassroom(
                            id: classroom.id.value,
                            name: classroom.name,
                          ),
                          classrooms: [
                            for (final item in classrooms)
                              ManagedClassroom(
                                id: item.id.value,
                                name: item.name,
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            Builder(
              builder: (pageContext) => _ClassToolButton(
                tooltip: AppL10n.of(pageContext).rosterAction,
                icon: const Icon(Icons.groups_outlined),
                onPressed: () => Navigator.of(pageContext).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ClassRosterPage(
                      repository: academic,
                      classroomId: classroom.id.value,
                      classroomName: classroom.name,
                      onMessageGuardian: MessagingScope.isAvailable(pageContext)
                          ? (guardian) =>
                                _messageGuardian(pageContext, guardian)
                          : null,
                    ),
                  ),
                ),
              ),
            ),
            Builder(
              builder: (pageContext) => _ClassToolButton(
                tooltip: AppL10n.of(pageContext).scheduleAction,
                icon: const Icon(Icons.calendar_month_outlined),
                onPressed: () async {
                  final slots = await academic.classroomSchedule(
                    classroom.id.value,
                  );
                  if (!pageContext.mounted) return;
                  await Navigator.of(pageContext).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ClassSchedulePage(
                        repository: academic,
                        classroomId: classroom.id.value,
                        classroomName: classroom.name,
                        expectedVersion: classroom.version,
                        initialSlots: slots,
                      ),
                    ),
                  );
                },
              ),
            ),
            Builder(
              builder: (pageContext) => _ClassToolButton(
                tooltip: AppL10n.of(pageContext).sectionsAction,
                icon: const Icon(Icons.menu_book_outlined),
                onPressed: () => Navigator.of(pageContext).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ClassSectionsPage(
                      repository: academic,
                      classroomId: classroom.id.value,
                      classroomName: classroom.name,
                    ),
                  ),
                ),
              ),
            ),
            Builder(
              builder: (pageContext) => _ClassToolButton(
                tooltip: AppL10n.of(pageContext).gradebookAction,
                icon: const Icon(Icons.grade_outlined),
                onPressed: () => Navigator.of(pageContext).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ClassGradebookPage(
                      repository: academic,
                      classroomId: classroom.id.value,
                      classroomName: classroom.name,
                    ),
                  ),
                ),
              ),
            ),
            Builder(
              builder: (pageContext) => _ClassToolButton(
                tooltip: AppL10n.of(pageContext).examAction,
                icon: const Icon(Icons.quiz_outlined),
                onPressed: () =>
                    _newExam(pageContext, classroomId: classroom.id.value),
              ),
            ),
            Builder(
              builder: (pageContext) => _ClassToolButton(
                tooltip: AppL10n.of(pageContext).assignmentAction,
                icon: const Icon(Icons.assignment_add),
                onPressed: () => _newAssignment(
                  pageContext,
                  classroomId: classroom.id.value,
                ),
              ),
            ),
            Builder(
              builder: (pageContext) => _ClassToolButton(
                tooltip: AppL10n.of(pageContext).attendanceAction,
                icon: const Icon(Icons.fact_check_outlined),
                onPressed: () => Navigator.of(pageContext).push(
                  MaterialPageRoute<void>(
                    builder: (_) => AttendancePage(
                      repository: academic,
                      classroomId: classroom.id.value,
                      classroomName: classroom.name,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext c) {
    void open(Widget page) {
      Navigator.of(c).push(MaterialPageRoute<void>(builder: (_) => page));
    }

    final pages = [
      TeacherTodayPage(
        classes: widget.dependencies.classes,
        academic: widget.dependencies.academic,
        onOpenClassroom: _openClassroom,
        onOpenMessages: () => open(const ConversationsPage()),
        onOpenNotifications: () => open(const NotificationsPage()),
      ),
      ClassesPage(
        classes: widget.dependencies.classes,
        onOpenClassroom: _openClassroom,
        header: const FeatureHeader('Classes'),
      ),
      AcademicOverviewPage(
        repository: widget.dependencies.academic,
        teacherTools: true,
        initialFeed: AcademicFeed.content,
        loadClassChoices: _classChoices,
        uploads: widget.dependencies.fileUploads,
        schoolId: ActiveContextController.instance.membership?.schoolId,
      ),
      AcademicOverviewPage(
        repository: widget.dependencies.academic,
        teacherTools: true,
        initialFeed: AcademicFeed.grades,
        loadClassChoices: _classChoices,
      ),
      // Real builds message through /v1 with report and block controls.
      // The legacy inbox stays only for the synthetic demo, where its
      // announcement and meeting forms have no replacement yet.
      ConversationsPage(visible: index == 4),
    ];
    return Scaffold(
      body: IndexedStack(index: index, children: pages),
      // Teaching is where a teacher sets work, but that tab is not scoped to
      // a class, so the form asks which one. Index 2 is Teaching; the other
      // tabs have their own actions.
      floatingActionButton: switch (index) {
        // Teaching sets work; the Inbox is where a teacher announces.
        2 => Builder(
          builder: (tabContext) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              FloatingActionButton.extended(
                heroTag: 'newExam',
                onPressed: () => _newExam(tabContext),
                icon: const Icon(Icons.quiz_outlined),
                label: Text(AppL10n.of(tabContext).examAction),
              ),
              const SizedBox(height: 8),
              FloatingActionButton.extended(
                heroTag: 'newAssignment',
                onPressed: () => _newAssignment(tabContext),
                icon: const Icon(Icons.assignment_add),
                label: Text(AppL10n.of(tabContext).assignmentAction),
              ),
            ],
          ),
        ),
        4 when MessagingScope.isAvailable(c) => Builder(
          builder: (tabContext) => FloatingActionButton.extended(
            onPressed: () => _newAnnouncement(tabContext),
            icon: const Icon(Icons.campaign_outlined),
            label: Text(AppL10n.of(tabContext).announcementAction),
          ),
        ),
        _ => null,
      },
      bottomNavigationBar: StudafyNavigationBar(
        selectedIndex: index,
        onSelected: (value) => setState(() => index = value),
        items: [
          StudafyNavItem(
            StudafyLocalizations.of(c).text('today'),
            Icons.home_outlined,
            Icons.home_rounded,
          ),
          StudafyNavItem(
            StudafyLocalizations.of(c).text('classes'),
            Icons.diversity_3_outlined,
            Icons.diversity_3_rounded,
          ),
          StudafyNavItem(
            StudafyLocalizations.of(c).text('teaching'),
            Icons.auto_stories_outlined,
            Icons.auto_stories_rounded,
          ),
          StudafyNavItem(
            StudafyLocalizations.of(c).text('gradebook'),
            Icons.fact_check_outlined,
            Icons.fact_check_rounded,
          ),
          StudafyNavItem(
            StudafyLocalizations.of(c).text('inbox'),
            Icons.forum_outlined,
            Icons.forum_rounded,
          ),
        ],
        accent: studafyNavy,
      ),
    );
  }
}

class _ClassToolButton extends StatelessWidget {
  const _ClassToolButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });
  final String tooltip;
  final Widget icon;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(end: 8),
    child: OutlinedButton.icon(
      onPressed: onPressed,
      icon: icon,
      label: Text(tooltip),
    ),
  );
}
