import 'package:flutter/material.dart';

import '../core/feedback.dart';
import '../core/studafy_design.dart';
import '../core/studafy_domain.dart';
import '../features/academic/domain/academic_repository.dart';
import '../features/academic/presentation/academic_overview_page.dart';
import '../features/academic/presentation/attendance_page.dart';
import '../features/academic/presentation/class_roster_page.dart';
import '../features/academic/presentation/class_schedule_page.dart';
import '../features/academic/presentation/class_sections_page.dart';
import '../features/academic/presentation/gradebook_page.dart';
import '../features/academic/presentation/submissions_page.dart';
import '../features/classes/domain/classroom.dart';
import '../features/classes/presentation/classes_page.dart';
import '../features/messaging/domain/messaging.dart';
import '../features/messaging/presentation/conversations_page.dart';
import '../features/messaging/presentation/messaging_scope.dart';
import '../features/notifications/presentation/notifications_page.dart';
import '../features/school_operations/domain/school_operations_repository.dart';
import '../features/school_operations/presentation/classroom_management_page.dart';
import '../l10n/generated/app_l10n.dart';
import 'account_hub_page.dart';
import 'app_dependencies.dart';
import 'teacher_create_actions.dart';
import 'teacher_today_page.dart';

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
        MaterialPageRoute<void>(
          builder: (_) => const ConversationsPage(asRole: MessagingRole.staff),
        ),
      ),
      onFailure: (failure) => messenger.showMessage(failure.message),
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

  late final _create = TeacherCreateActions(widget.dependencies);

  Future<void> _openClassroom(ClassroomSummary classroom) async {
    final academic = widget.dependencies.academic;
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => AcademicOverviewPage(
          repository: academic,
          classroomId: classroom.id.value,
          title: classroom.name,
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
                graded: record.maximumScore != null,
              ),
            ),
          ),
          actions: [
            if (widget.dependencies.schoolOperations != null)
              Builder(
                builder: (pageContext) => _ClassToolButton(
                  tooltip: AppL10n.of(pageContext)
                      .teacherShellManageRosterStaffAndMeetings,
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
                tooltip: AppL10n.of(pageContext).academicAddLesson,
                icon: const Icon(Icons.note_add_outlined),
                onPressed: () => _create.newLesson(
                  pageContext,
                  classroomId: classroom.id.value,
                ),
              ),
            ),
            Builder(
              builder: (pageContext) => _ClassToolButton(
                tooltip: AppL10n.of(pageContext).examAction,
                icon: const Icon(Icons.quiz_outlined),
                onPressed: () => _create.newExam(
                  pageContext,
                  classroomId: classroom.id.value,
                ),
              ),
            ),
            Builder(
              builder: (pageContext) => _ClassToolButton(
                tooltip: AppL10n.of(pageContext).assignmentAction,
                icon: const Icon(Icons.assignment_add),
                onPressed: () => _create.newAssignment(
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
            Builder(
              builder: (pageContext) => _ClassToolButton(
                tooltip: AppL10n.of(pageContext).classDeleteAction,
                icon: const Icon(Icons.delete_outline_rounded),
                onPressed: () => _deleteClass(pageContext, classroom),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Bumped after a class is deleted, so the class lists read again.
  Key _classesKey = UniqueKey();

  /// Deletes (archives) a class, after saying what that does - and does not
  /// do: students keep every note they wrote for it.
  Future<void> _deleteClass(
    BuildContext pageContext,
    ClassroomSummary classroom,
  ) async {
    final l10n = AppL10n.of(pageContext);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(pageContext);
    final confirmed = await showDialog<bool>(
      context: pageContext,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.classDeleteTitle(classroom.name)),
        content: Text(l10n.classDeleteBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.classDeleteCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.classDeleteConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.dependencies.academic.archiveClassroom(
        classroom.id.value,
        classroom.version,
      );
    } on Object {
      messenger.showMessage(l10n.classDeleteFailed);
      return;
    }
    navigator.pop();
    messenger.showMessage(l10n.classDeleted);
    if (mounted) setState(() => _classesKey = UniqueKey());
  }

  void _openSubmissions(AcademicRecord record) {
    final classroomId = record.classroomId;
    if (classroomId == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SubmissionsPage(
          repository: widget.dependencies.academic,
          assignmentId: record.id,
          assignmentTitle: record.title,
          classroomId: classroomId,
          graded: record.maximumScore != null,
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
        key: ValueKey(('today', _classesKey)),
        classes: widget.dependencies.classes,
        academic: widget.dependencies.academic,
        onOpenClassroom: _openClassroom,
        // No messages button here: the Inbox tab is the one way in.
        onOpenNotifications: () => open(const NotificationsPage()),
      ),
      ClassesPage(
        key: ValueKey(('classes', _classesKey)),
        classes: widget.dependencies.classes,
        onOpenClassroom: _openClassroom,
        // The real header: this teacher's notifications and account.
        // Messages are the Inbox tab, not a second button up here.
        header: _TabHeader(
          title: AppL10n.of(c).teacherShellClasses,
          onOpenNotifications: () => open(const NotificationsPage()),
        ),
      ),
      AcademicOverviewPage(
        repository: widget.dependencies.academic,
        teacherTools: true,
        initialFeed: AcademicFeed.content,
        loadClassChoices: _classChoices,
        uploads: widget.dependencies.fileUploads,
        schoolId: ActiveContextController.instance.membership?.schoolId,
        // Tapping a piece of work opens what the class handed in. Without
        // this the Teaching tab listed assignments that led nowhere.
        onOpenRecord: _openSubmissions,
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
      ConversationsPage(visible: index == 4, asRole: MessagingRole.staff),
    ];
    return Scaffold(
      body: IndexedStack(index: index, children: pages),
      // Teaching is where a teacher sets work, but that tab is not scoped to
      // a class, so the form asks which one. Index 2 is Teaching; the other
      // tabs have their own actions.
      // One "Create" everywhere a teacher works - lessons, assignments,
      // exams, announcements and attendance - and Announce in the Inbox.
      floatingActionButton: switch (index) {
        0 || 1 || 2 || 3 => Builder(
          builder: (tabContext) => FloatingActionButton.extended(
            // Every tab stays alive in the shell's IndexedStack, so two
            // buttons with the default hero tag coexist and break the
            // transition of every screen pushed from any tab.
            heroTag: null,
            onPressed: () => _create.openCreateMenu(tabContext),
            icon: const Icon(Icons.add_rounded),
            label: Text(AppL10n.of(tabContext).teacherCreateAction),
          ),
        ),
        4 when MessagingScope.isAvailable(c) => Builder(
          builder: (tabContext) => FloatingActionButton.extended(
            heroTag: null,
            onPressed: () => _create.newAnnouncement(tabContext),
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
            AppL10n.of(c).navToday,
            Icons.home_outlined,
            Icons.home_rounded,
          ),
          StudafyNavItem(
            AppL10n.of(c).navClasses,
            Icons.diversity_3_outlined,
            Icons.diversity_3_rounded,
          ),
          StudafyNavItem(
            AppL10n.of(c).navTeaching,
            Icons.auto_stories_outlined,
            Icons.auto_stories_rounded,
          ),
          StudafyNavItem(
            AppL10n.of(c).navGradebook,
            Icons.fact_check_outlined,
            Icons.fact_check_rounded,
          ),
          StudafyNavItem(
            AppL10n.of(c).navInbox,
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

class _TabHeader extends StatelessWidget {
  const _TabHeader({required this.title, required this.onOpenNotifications});

  final String title;
  final VoidCallback onOpenNotifications;

  @override
  Widget build(BuildContext context) => SafeArea(
    bottom: false,
    child: Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 12, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800, color: studafyInk),
            ),
          ),
          IconButton(
            tooltip: AppL10n.of(context).recordNotifications,
            onPressed: onOpenNotifications,
            icon: const Icon(Icons.notifications_none_rounded),
          ),
          const AccountButton(),
        ],
      ),
    ),
  );
}
