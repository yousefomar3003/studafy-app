import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;

import '../core/feedback.dart';
import '../core/navigation.dart';
import '../core/studafy_components.dart';
import '../core/studafy_design.dart';
import '../core/studafy_domain.dart';
import '../features/academic/domain/academic_repository.dart';
import '../features/academic/presentation/academic_overview_page.dart';
import '../features/academic/presentation/attendance_page.dart';
import '../features/academic/presentation/class_roster_page.dart';
import '../features/academic/presentation/class_schedule_page.dart';
import '../features/academic/presentation/class_sections_page.dart';
import '../features/academic/presentation/gradebook_home_page.dart';
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
      onSuccess: (_) => navigator.pushOnce(
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
    await Navigator.of(context).pushOnce(
      MaterialPageRoute<void>(
        builder: (_) => AcademicOverviewPage(
          repository: academic,
          classroomId: classroom.id.value,
          title: classroom.name,
          teacherTools: true,
          initialFeed: AcademicFeed.content,
          // Marks are kept in the Gradebook, one tap away in the tools.
          availableFeeds: const [
            AcademicFeed.content,
            AcademicFeed.assignments,
            AcademicFeed.assessments,
            AcademicFeed.attendance,
            AcademicFeed.wellbeing,
          ],
          uploads: widget.dependencies.fileUploads,
          schoolId: ActiveContextController.instance.membership?.schoolId,
          // Tapping a piece of work shows who has handed it in. Students
          // can submit now, so without this the loop has no other end.
          onOpenRecord: (record) => Navigator.of(context).pushOnce(
            MaterialPageRoute<void>(
              builder: (_) => SubmissionsPage(
                repository: academic,
                assignmentId: record.id,
                assignmentTitle: record.title,
                classroomId: classroom.id.value,
                graded: record.maximumScore != null,
                assignmentVersion: record.version,
                timeZone: record.timeZone,
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
                    await Navigator.of(pageContext).pushOnce(
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
                onPressed: () => Navigator.of(pageContext).pushOnce(
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
                  await Navigator.of(pageContext).pushOnce(
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
                onPressed: () => Navigator.of(pageContext).pushOnce(
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
                onPressed: () => Navigator.of(pageContext).pushOnce(
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
                onPressed: () => Navigator.of(pageContext).pushOnce(
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
    Navigator.of(context).pushOnce(
      MaterialPageRoute<void>(
        builder: (_) => SubmissionsPage(
          repository: widget.dependencies.academic,
          assignmentId: record.id,
          assignmentTitle: record.title,
          classroomId: classroomId,
          graded: record.maximumScore != null,
          assignmentVersion: record.version,
          timeZone: record.timeZone,
        ),
      ),
    );
  }

  /// The bar is compact while the person scrolls down a page, and full
  /// again as soon as they scroll back up or touch it.
  bool _navCompact = false;

  bool _onScroll(UserScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;
    final compact = switch (notification.direction) {
      ScrollDirection.reverse => true,
      ScrollDirection.forward => false,
      ScrollDirection.idle => _navCompact,
    };
    if (compact != _navCompact) setState(() => _navCompact = compact);
    return false;
  }

  @override
  Widget build(BuildContext c) {
    final l10n = AppL10n.of(c);
    void open(Widget page) {
      Navigator.of(c).pushOnce(MaterialPageRoute<void>(builder: (_) => page));
    }

    final canAnnounce = MessagingScope.isAvailable(c);
    final pages = [
      Builder(
        builder: (tabContext) => TeacherTodayPage(
          key: ValueKey(('today', _classesKey)),
          classes: widget.dependencies.classes,
          academic: widget.dependencies.academic,
          onOpenClassroom: _openClassroom,
          // No messages button here: the Inbox tab is the one way in.
          onOpenNotifications: () => open(const NotificationsPage()),
          onSeeAllClasses: () => setState(() => index = 1),
          quickActions: [
            TodayQuickAction(
              icon: Icons.fact_check_rounded,
              label: l10n.teacherCreateAttendance,
              onTap: () => _create.takeAttendance(tabContext),
            ),
            TodayQuickAction(
              icon: Icons.menu_book_rounded,
              label: l10n.teacherCreateLesson,
              onTap: () => _create.newLesson(tabContext),
            ),
            TodayQuickAction(
              icon: Icons.grading_rounded,
              label: l10n.teacherCreatePaperGrades,
              onTap: () => _create.paperGrades(tabContext),
            ),
            if (canAnnounce)
              TodayQuickAction(
                icon: Icons.campaign_rounded,
                label: l10n.teacherCreateAnnouncement,
                onTap: () => _create.newAnnouncement(tabContext),
              )
            else
              TodayQuickAction(
                icon: Icons.assignment_add,
                label: l10n.teacherCreateAssignment,
                onTap: () => _create.newAssignment(tabContext),
              ),
          ],
        ),
      ),
      // No account or notification buttons here: the Classes tab is about
      // the classes alone.
      ClassesPage(
        key: ValueKey(('classes', _classesKey)),
        classes: widget.dependencies.classes,
        onOpenClassroom: _openClassroom,
        header: _TabHeader(title: l10n.teacherShellClasses),
      ),
      // Teaching content lives here; every mark lives in the Gradebook.
      AcademicOverviewPage(
        title: l10n.navTeaching,
        repository: widget.dependencies.academic,
        teacherTools: true,
        initialFeed: AcademicFeed.content,
        availableFeeds: const [
          AcademicFeed.content,
          AcademicFeed.assignments,
          AcademicFeed.assessments,
          AcademicFeed.wellbeing,
        ],
        loadClassChoices: _classChoices,
        uploads: widget.dependencies.fileUploads,
        schoolId: ActiveContextController.instance.membership?.schoolId,
        // Tapping a piece of work opens what the class handed in. Without
        // this the Teaching tab listed assignments that led nowhere.
        onOpenRecord: _openSubmissions,
      ),
      GradebookHomePage(
        repository: widget.dependencies.academic,
        loadClassChoices: _classChoices,
        onOpenAssignment: _openSubmissions,
      ),
      // Real builds message through /v1 with report and block controls.
      Builder(
        builder: (tabContext) => ConversationsPage(
          visible: index == 4,
          asRole: MessagingRole.staff,
          onNewAnnouncement: canAnnounce
              ? () => _create.newAnnouncement(tabContext)
              : null,
        ),
      ),
    ];
    return Scaffold(
      body: NotificationListener<UserScrollNotification>(
        onNotification: _onScroll,
        child: IndexedStack(index: index, children: pages),
      ),
      // One "+" everywhere a teacher works: lessons, assignments, exams,
      // paper grades, attendance, wellbeing notes and announcements.
      floatingActionButton: Builder(
        builder: (tabContext) => StudafyCreateButton(
          label: l10n.teacherCreateAction,
          onPressed: () => _create.openCreateMenu(tabContext),
        ),
      ),
      bottomNavigationBar: StudafyNavigationBar(
        selectedIndex: index,
        compact: _navCompact,
        onInteract: () {
          if (_navCompact) setState(() => _navCompact = false);
        },
        onSelected: (value) => setState(() {
          index = value;
          _navCompact = false;
        }),
        items: [
          StudafyNavItem(
            l10n.navToday,
            Icons.home_outlined,
            Icons.home_rounded,
          ),
          StudafyNavItem(
            l10n.navClasses,
            Icons.class_outlined,
            Icons.class_rounded,
          ),
          StudafyNavItem(
            l10n.navTeaching,
            Icons.auto_stories_outlined,
            Icons.auto_stories_rounded,
          ),
          StudafyNavItem(
            l10n.navGradebook,
            Icons.grading_outlined,
            Icons.grading_rounded,
          ),
          StudafyNavItem(
            l10n.navInbox,
            Icons.send_outlined,
            Icons.send_rounded,
          ),
        ],
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
    child: FilledButton.tonalIcon(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: studafyNavy,
        side: const BorderSide(color: studafyHairline),
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 14),
      ),
      icon: icon,
      label: Text(tooltip),
    ),
  );
}

/// A large page title, as in iOS, with nothing competing with it.
class _TabHeader extends StatelessWidget {
  const _TabHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => SafeArea(
    bottom: false,
    child: Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 14, 20, 4),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Semantics(
          header: true,
          child: Text(
            title,
            style: const TextStyle(
              color: studafyInk,
              fontSize: 30,
              fontWeight: FontWeight.w800,
              letterSpacing: -.8,
            ),
          ),
        ),
      ),
    ),
  );
}
