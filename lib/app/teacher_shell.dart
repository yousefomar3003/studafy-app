import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;

import '../core/feedback.dart';
import '../core/lazy_indexed_stack.dart';
import '../core/navigation.dart';
import '../core/studafy_components.dart';
import '../core/studafy_design.dart';
import '../core/studafy_domain.dart';
import '../features/academic/domain/academic_repository.dart';
import '../features/academic/presentation/academic_overview_page.dart';
import '../features/academic/presentation/gradebook_home_page.dart';
import '../features/academic/presentation/submissions_page.dart';
import '../features/classes/domain/classroom.dart';
import '../features/classes/presentation/classes_page.dart';
import '../features/messaging/domain/messaging.dart';
import '../features/messaging/presentation/conversations_page.dart';
import '../features/messaging/presentation/messaging_scope.dart';
import '../features/notifications/presentation/notifications_page.dart';
import '../l10n/generated/app_l10n.dart';
import 'app_dependencies.dart';
import 'assessment_navigation.dart';
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
          // Marks are kept in the Gradebook tab.
          availableFeeds: const [
            AcademicFeed.content,
            AcademicFeed.assignments,
            AcademicFeed.assessments,
            AcademicFeed.attendance,
            AcademicFeed.wellbeing,
          ],
          uploads: widget.dependencies.fileUploads,
          schoolId: ActiveContextController.instance.membership?.schoolId,
          onOpenAssessment: (id, title, _) => openAssessmentForTeacher(
            context,
            academic,
            id,
            title,
            classroomId: classroom.id.value,
            uploads: widget.dependencies.fileUploads,
          ),
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
          // No row of tools across the class: attendance and marks are in
          // the "+" menu and the Gradebook tab, as everything else is. The
          // one thing only a class can do - deleting it - is in its menu.
          appBarActions: [
            Builder(
              builder: (pageContext) => PopupMenuButton<VoidCallback>(
                tooltip: AppL10n.of(pageContext).msgOptions,
                icon: const Icon(Icons.more_horiz_rounded),
                onSelected: (action) => action(),
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: () => _deleteClass(pageContext, classroom),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.delete_outline_rounded,
                          size: 20,
                          color: studafyDanger,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          AppL10n.of(pageContext).classDeleteAction,
                          style: const TextStyle(color: studafyDanger),
                        ),
                      ],
                    ),
                  ),
                ],
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
  final _navCompact = ValueNotifier<bool>(false);

  @override
  void dispose() {
    _navCompact.dispose();
    super.dispose();
  }

  bool _onScroll(UserScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;
    final compact = switch (notification.direction) {
      ScrollDirection.reverse => true,
      ScrollDirection.forward => false,
      ScrollDirection.idle => _navCompact.value,
    };
    _navCompact.value = compact;
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
        onOpenAssessment: (id, title, _) => openAssessmentForTeacher(
          context,
          widget.dependencies.academic,
          id,
          title,
          uploads: widget.dependencies.fileUploads,
        ),
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
        child: LazyIndexedStack(
          index: index,
          // The inbox acknowledges delivery while out of sight.
          builtAhead: const {4},
          children: pages,
        ),
      ),
      // One "+" everywhere a teacher works: lessons, assignments, exams,
      // paper grades, attendance, wellbeing notes and announcements.
      floatingActionButton: Builder(
        builder: (tabContext) => StudafyCreateButton(
          label: l10n.teacherCreateAction,
          onPressed: () => _create.openCreateMenu(tabContext),
        ),
      ),
      bottomNavigationBar: ValueListenableBuilder<bool>(
        // Only the bar follows scrolling; the tabs are not rebuilt.
        valueListenable: _navCompact,
        builder: (context, compact, _) => StudafyNavigationBar(
          selectedIndex: index,
          compact: compact,
          onInteract: () {
            _navCompact.value = false;
          },
          onSelected: (value) => setState(() {
            index = value;
            _navCompact.value = false;
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
      ),
    );
  }
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
