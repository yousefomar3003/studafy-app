import 'dart:async';

import 'package:flutter/material.dart';

import '../core/studafy_components.dart';
import '../core/studafy_design.dart';
import '../core/studafy_domain.dart';
import '../core/studafy_formatting.dart';
import '../core/user_content_text.dart';
import '../features/academic/domain/academic_repository.dart';
import '../features/classes/application/class_list_interactor.dart';
import '../features/classes/domain/classroom.dart';
import '../features/notifications/presentation/notifications_scope.dart';
import '../l10n/generated/app_l10n.dart';
import 'account_hub_page.dart';

/// Teacher home for real builds. Everything on it comes from the signed-in
/// profile and the server: the legacy home was fixed demo content, with a
/// sample greeting, invented lessons and invented student names, and must
/// never appear in front of a real school.
///
/// Today is a tab that stays alive, so it reads everything again whenever
/// it comes back into view - from another tab, or from a screen opened on
/// top of it - rather than showing what was true when the app started.
class TeacherTodayPage extends StatefulWidget {
  const TeacherTodayPage({
    super.key,
    required this.classes,
    required this.academic,
    required this.onOpenClassroom,
    this.onOpenMessages,
    required this.onOpenNotifications,
    this.quickActions = const [],
    this.onSeeAllClasses,
    this.onOpenWork,
    this.onAddLesson,
    this.onOpenLessons,
    this.visible = true,
    this.changes,
  });

  /// Shortcuts to the things a teacher does most, built by the shell.
  final List<TodayQuickAction> quickActions;

  /// Opens the full class list (the Classes tab).
  final VoidCallback? onSeeAllClasses;

  final ClassListInteractor classes;

  /// Today aggregates from other pages, not only the class list: work that
  /// is still to set or open, and sections still owing their lesson.
  final AcademicRepository academic;
  final Future<void> Function(ClassroomSummary classroom) onOpenClassroom;

  /// Opens the screen where a piece of work is published, edited or marked.
  final Future<void> Function(TeacherWorkItem item)? onOpenWork;

  /// Opens the new-lesson form for a class, filed for one section.
  final Future<void> Function(
    ClassroomSummary classroom,
    LessonSession section,
  )?
  onAddLesson;

  /// Opens a class's lessons, where a draft lesson is published.
  final Future<void> Function(ClassroomSummary classroom)? onOpenLessons;

  /// Null hides the messages button - the teacher shell has an Inbox tab.
  final VoidCallback? onOpenMessages;
  final VoidCallback onOpenNotifications;

  /// Whether this tab is the one on screen. Coming back into view reloads.
  final bool visible;

  /// Fires when something was created or changed elsewhere, such as from
  /// the shell's create button. Read now if on screen, else on return.
  final Listenable? changes;

  @override
  State<TeacherTodayPage> createState() => _TeacherTodayPageState();
}

class _TeacherTodayPageState extends State<TeacherTodayPage> {
  List<ClassroomSummary> _classes = const [];
  int _unread = 0;
  bool _loading = true;
  List<TeacherWorkItem> _work = const [];
  List<_TodaySection> _outstanding = const [];
  bool _failed = false;

  /// Classes whose work or sections could not be read this time. The rest
  /// still show; this says the lists may be incomplete.
  int _classesFailed = 0;

  /// Something changed while another tab was on screen.
  bool _stale = false;

  @override
  void initState() {
    super.initState();
    widget.changes?.addListener(_changed);
    unawaited(_load());
  }

  @override
  void didUpdateWidget(TeacherTodayPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.changes != widget.changes) {
      oldWidget.changes?.removeListener(_changed);
      widget.changes?.addListener(_changed);
    }
    if (widget.visible && !oldWidget.visible) {
      unawaited(_load());
    } else if (widget.visible && _stale) {
      unawaited(_load());
    }
  }

  @override
  void dispose() {
    widget.changes?.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (!mounted) return;
    if (widget.visible) {
      unawaited(_load());
    } else {
      _stale = true;
    }
  }

  /// Once the page has been shown, a reload (pull, or the bell) keeps it on
  /// screen and swaps in the new figures together when they are all in.
  bool _loaded = false;

  /// A reload asked for while one is running runs again after it, so the
  /// last change is never lost to a read that started before it.
  Future<void>? _running;
  bool _again = false;

  Future<void> _load() async {
    _stale = false;
    if (_running != null) {
      _again = true;
      return _running;
    }
    final run = _read();
    _running = run;
    try {
      await run;
    } finally {
      _running = null;
    }
    if (_again && mounted) {
      _again = false;
      await _load();
    }
  }

  Future<void> _read() async {
    if (!_loaded) setState(() => _loading = true);
    final notifications = NotificationsScope.of(context);
    // Both at once, then every class at once: one after another, a teacher
    // with six classes waited on fourteen round trips in a row.
    final unreadRead = notifications.unreadCount();
    final classes = await widget.classes.loadClasses();
    final list = classes.fold(
      onSuccess: (items) => items,
      onFailure: (_) => const <ClassroomSummary>[],
    );
    final now = DateTime.now();
    final perClass = await Future.wait([
      for (final classroom in list) _loadClass(classroom, now),
    ]);
    final unread = await unreadRead;
    if (!mounted) return;
    // All in one go, so the page never says "nothing outstanding" while the
    // classes' work is still on its way.
    setState(() {
      _loading = false;
      _loaded = true;
      _unread = unread.fold(onSuccess: (n) => n, onFailure: (_) => 0);
      classes.fold(
        onSuccess: (items) {
          _classes = items;
          _failed = false;
        },
        onFailure: (_) => _failed = true,
      );
      _classesFailed = perClass.where((c) => c.failed).length;
      _work = sortTeacherWork([for (final c in perClass) ...c.work]);
      _outstanding = [for (final c in perClass) ...c.sections]
        ..sort((a, b) => b.session.startsAt.compareTo(a.session.startsAt));
    });
  }

  /// One class's work and sections. Each class is asked separately, and a
  /// class that fails is counted rather than emptying the whole page: a
  /// teacher with four classes and one bad response still sees the other
  /// three, and is told the lists may be missing something.
  Future<_ClassToday> _loadClass(
    ClassroomSummary classroom,
    DateTime now,
  ) async {
    final id = classroom.id.value;
    var failed = false;
    Future<T?> guarded<T>(Future<T> read) => read.then<T?>(
      (value) => value,
      onError: (Object _) {
        failed = true;
        return null;
      },
    );
    final (assignments, assessments, sessions) = await (
      guarded(widget.academic.load(AcademicFeed.assignments, classroomId: id)),
      guarded(widget.academic.load(AcademicFeed.assessments, classroomId: id)),
      guarded(widget.academic.lessonSessions(id)),
    ).wait;
    return _ClassToday(
      failed: failed,
      work: teacherWorkFor(
        classroom,
        assignments: assignments ?? const [],
        assessments: assessments ?? const [],
        now: now,
      ),
      sections: [
        for (final session in sessions ?? const <LessonSession>[])
          if (session.needsContent)
            _TodaySection(classroom: classroom, session: session),
      ],
    );
  }

  /// Runs something opened from Today, then reads Today again: whatever it
  /// opened may have created, published or removed what Today lists.
  Future<void> _through(FutureOr<void> Function() open) async {
    await open();
    if (mounted) await _load();
  }

  String _date(DateTime value) => studafyMediumDate(context, value);

  String _workStatus(AppL10n l10n, TeacherWorkItem item) {
    final date = item.date;
    return switch (item.status) {
      TeacherWorkStatus.draft => l10n.todayWorkDraft,
      TeacherWorkStatus.scheduled when date != null =>
        item.kind == TeacherWorkKind.paperExam
            ? l10n.todayWorkExamOn(_date(date))
            : l10n.todayWorkOpens(_date(date)),
      TeacherWorkStatus.scheduled => l10n.todayWorkScheduled,
      TeacherWorkStatus.open when date != null =>
        item.kind == TeacherWorkKind.assignment
            ? l10n.todayWorkDue(_date(date))
            : l10n.todayWorkCloses(_date(date)),
      TeacherWorkStatus.open => l10n.todayWorkOpen,
    };
  }

  String _workKind(AppL10n l10n, TeacherWorkKind kind) => switch (kind) {
    TeacherWorkKind.assignment => l10n.todayWorkKindAssignment,
    TeacherWorkKind.onlineExam => l10n.todayWorkKindOnlineExam,
    TeacherWorkKind.paperExam => l10n.todayWorkKindPaperExam,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final profile = ActiveContextController.instance.profile;
    final firstName = (profile?.displayName ?? '').trim().split(' ').first;
    final today = studafyFullDate(context, DateTime.now());
    final students = _classes.fold<int>(0, (sum, c) => sum + c.studentCount);
    return Scaffold(
      appBar: AppBar(
        // The brand, not the school's name, heads the home screen.
        title: const StudafyLogo(size: 28),
        titleSpacing: 20,
        actions: [
          if (widget.onOpenMessages case final openMessages?)
            IconButton(
              tooltip: l10n.todayMessages,
              onPressed: openMessages,
              icon: const Icon(Icons.send_rounded),
            ),
          NotificationBellButton(
            unread: _unread,
            label: studafyNumber(context, _unread),
            onPressed: () {
              widget.onOpenNotifications();
              unawaited(_load());
            },
          ),
          const AccountButton(),
        ],
      ),
      body: StudafyRefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 8, 20, 32),
          children: [
            StudafyHero(
              eyebrow: today,
              title: firstName.isEmpty
                  ? l10n.todayHello
                  : l10n.todayHelloName(firstName),
              subtitle: l10n.teacherTodaySpaceToInspireADay,
              icon: Icons.wb_sunny_outlined,
              child: _loading || _failed
                  ? null
                  : Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _HeroStat(
                          icon: Icons.class_rounded,
                          label: l10n.todayStatClasses(_classes.length),
                        ),
                        _HeroStat(
                          icon: Icons.groups_rounded,
                          label: l10n.classesStudentCount(students),
                        ),
                      ],
                    ),
            ),
            if (widget.quickActions.isNotEmpty) ...[
              SectionHeader(l10n.todayQuickActions),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 2.3,
                children: [
                  for (final action in widget.quickActions)
                    FeatureCard(
                      onTap: () => _through(action.onTap),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          IconBadge(icon: action.icon, size: 38),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              action.label,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: studafyInk,
                                fontWeight: FontWeight.w700,
                                fontSize: 13.5,
                                height: 1.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
            SectionHeader(
              l10n.todayClasses,
              action: widget.onSeeAllClasses == null || _classes.length <= 3
                  ? null
                  : TextButton(
                      onPressed: widget.onSeeAllClasses,
                      child: Text(l10n.todaySeeAll),
                    ),
            ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_failed)
              StudafyEmptyState(
                icon: Icons.wifi_off_rounded,
                title: l10n.todayError,
                message: l10n.todayErrorDetail,
                actionLabel: l10n.todayRetry,
                onAction: _load,
              )
            else if (_classes.isEmpty)
              StudafyEmptyState(
                icon: Icons.class_outlined,
                title: l10n.todayEmpty,
                message: l10n.todayEmptyDetail,
              )
            else
              for (final classroom in _classes.take(3))
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: FeatureCard(
                    onTap: () =>
                        _through(() => widget.onOpenClassroom(classroom)),
                    child: Row(
                      children: [
                        IconBadge(icon: subjectIcon(classroom.name)),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              UserContentText(
                                classroom.name,
                                style: const TextStyle(
                                  color: studafyInk,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                l10n.todayStudents(classroom.studentCount),
                                style: const TextStyle(
                                  color: studafyMuted,
                                  fontSize: 12.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(forwardChevron(context), color: studafyMuted),
                      ],
                    ),
                  ),
                ),
            // Today draws from the other pages, so an empty Today means
            // nothing is outstanding rather than nothing is wired up.
            if (!_loading && !_failed && _classes.isNotEmpty) ...[
              if (_classesFailed > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: _Notice(
                    text: l10n.todayPartlyLoaded,
                    icon: Icons.sync_problem_rounded,
                    color: studafyDanger,
                    actionLabel: l10n.todayRetry,
                    onAction: _load,
                  ),
                ),
              SectionHeader(l10n.todaySections),
              if (_outstanding.isEmpty)
                _Notice(
                  text: _classesFailed > 0
                      ? l10n.todaySectionsUnknown
                      : l10n.todaySectionsEmpty,
                )
              else ...[
                for (final section in _outstanding.take(5))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _TodayRow(
                      icon: section.session.content == SectionContent.draft
                          ? Icons.edit_note_rounded
                          : Icons.pending_actions_rounded,
                      color: studafyCyan,
                      title: section.classroom.name,
                      lines: [
                        studafyDateTime(context, section.session.startsAt),
                        section.session.content == SectionContent.draft
                            ? l10n.todaySectionDraft
                            : l10n.todaySectionsOutstanding,
                      ],
                      action: section.session.content == SectionContent.draft
                          ? l10n.todaySectionPublish
                          : l10n.todaySectionAdd,
                      onTap: _sectionAction(section),
                    ),
                  ),
                if (_outstanding.length > 5)
                  Text(
                    l10n.todayMore(_outstanding.length - 5),
                    style: const TextStyle(color: studafyMuted),
                  ),
              ],
              SectionHeader(l10n.todayWork),
              if (_work.isEmpty)
                _Notice(
                  text: _classesFailed > 0
                      ? l10n.todayWorkUnknown
                      : l10n.todayWorkEmpty,
                  icon: Icons.assignment_outlined,
                )
              else ...[
                for (final item in _work.take(5))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _TodayRow(
                      icon: switch (item.kind) {
                        TeacherWorkKind.assignment => Icons.assignment_rounded,
                        TeacherWorkKind.onlineExam => Icons.quiz_rounded,
                        TeacherWorkKind.paperExam => Icons.description_rounded,
                      },
                      color: item.status == TeacherWorkStatus.draft
                          ? studafyMuted
                          : studafyNavy,
                      title: item.record.title,
                      lines: [
                        '${item.classroom.name} · ${_workKind(l10n, item.kind)}',
                        _workStatus(l10n, item),
                      ],
                      action: item.status == TeacherWorkStatus.draft
                          ? l10n.todayWorkFinish
                          : null,
                      onTap: widget.onOpenWork == null
                          ? null
                          : () => _through(() => widget.onOpenWork!(item)),
                    ),
                  ),
                if (_work.length > 5)
                  Text(
                    l10n.todayMore(_work.length - 5),
                    style: const TextStyle(color: studafyMuted),
                  ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  VoidCallback? _sectionAction(_TodaySection section) {
    if (section.session.content == SectionContent.draft) {
      final open = widget.onOpenLessons;
      return open == null
          ? null
          : () => _through(() => open(section.classroom));
    }
    final add = widget.onAddLesson;
    return add == null
        ? null
        : () => _through(() => add(section.classroom, section.session));
  }
}

/// What a piece of work on Today is.
enum TeacherWorkKind { assignment, onlineExam, paperExam }

/// Where a piece of work stands for the teacher who set it.
enum TeacherWorkStatus {
  /// Written but not published: the class cannot see it yet.
  draft,

  /// Published, opening later - or a paper exam's day still to come.
  scheduled,

  /// Published and open: hand-ins or answers are still being taken.
  open,
}

/// One piece of work on Today, from the class's own records.
@immutable
class TeacherWorkItem {
  const TeacherWorkItem({
    required this.classroom,
    required this.record,
    required this.kind,
    required this.status,
    this.date,
  });

  final ClassroomSummary classroom;
  final AcademicRecord record;
  final TeacherWorkKind kind;
  final TeacherWorkStatus status;

  /// When it is due, opens, closes or is sat, as [status] says.
  final DateTime? date;
}

/// The work of one class Today lists: drafts still to publish, and work
/// that is published and not yet over. Nothing is made up - a class with no
/// such work adds nothing - and work that has closed, or a withdrawn piece,
/// is the gradebook's business, not Today's.
@visibleForTesting
List<TeacherWorkItem> teacherWorkFor(
  ClassroomSummary classroom, {
  required List<AcademicRecord> assignments,
  required List<AcademicRecord> assessments,
  required DateTime now,
}) {
  final items = <TeacherWorkItem>[];
  TeacherWorkItem item(
    AcademicRecord record,
    TeacherWorkKind kind,
    TeacherWorkStatus status,
    DateTime? date,
  ) => TeacherWorkItem(
    classroom: classroom,
    record: record,
    kind: kind,
    status: status,
    date: date,
  );
  for (final work in assignments) {
    final ends = work.closesAt ?? work.dueAt;
    if (work.state == 'draft') {
      items.add(
        item(
          work,
          TeacherWorkKind.assignment,
          TeacherWorkStatus.draft,
          work.dueAt,
        ),
      );
    } else if (work.state == 'published' && ends != null && ends.isAfter(now)) {
      items.add(
        item(
          work,
          TeacherWorkKind.assignment,
          TeacherWorkStatus.open,
          work.dueAt,
        ),
      );
    }
  }
  for (final exam in assessments) {
    // The mark for an assignment is listed with its assignment.
    if (exam.markedAssignmentId != null) continue;
    if (exam.delivery == 'paper') {
      // A paper exam stays a draft until its marks are published, so its
      // state says nothing about whether it is set; its day does.
      final day = exam.scheduledAt;
      if (exam.state != 'withdrawn' && day != null && day.isAfter(now)) {
        items.add(
          item(
            exam,
            TeacherWorkKind.paperExam,
            TeacherWorkStatus.scheduled,
            day,
          ),
        );
      }
      continue;
    }
    final settings = exam.online?.settings;
    final opens = settings?.opensAt;
    final closes = settings?.closesAt;
    if (exam.state == 'draft') {
      items.add(
        item(
          exam,
          TeacherWorkKind.onlineExam,
          TeacherWorkStatus.draft,
          opens ?? closes,
        ),
      );
    } else if (exam.state == 'published') {
      if (opens != null && opens.isAfter(now)) {
        items.add(
          item(
            exam,
            TeacherWorkKind.onlineExam,
            TeacherWorkStatus.scheduled,
            opens,
          ),
        );
      } else if (closes == null || closes.isAfter(now)) {
        items.add(
          item(
            exam,
            TeacherWorkKind.onlineExam,
            TeacherWorkStatus.open,
            closes,
          ),
        );
      }
    }
  }
  return items;
}

/// Drafts first - they are what is still to set - then the soonest date.
@visibleForTesting
List<TeacherWorkItem> sortTeacherWork(List<TeacherWorkItem> items) {
  int rank(TeacherWorkItem item) =>
      item.status == TeacherWorkStatus.draft ? 0 : 1;
  return [...items]..sort((a, b) {
    final byRank = rank(a).compareTo(rank(b));
    if (byRank != 0) return byRank;
    final x = a.date;
    final y = b.date;
    if (x == null && y == null) return a.record.title.compareTo(b.record.title);
    if (x == null) return 1;
    if (y == null) return -1;
    return x.compareTo(y);
  });
}

/// A shortcut on the teacher's home, wired by the shell. Today reads its
/// lists again once the shortcut's screen is done.
@immutable
class TodayQuickAction {
  const TodayQuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final FutureOr<void> Function() onTap;
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .14),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.white),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

/// One row on Today: what it is, where it stands, and - when it leads
/// somewhere - what a tap does.
class _TodayRow extends StatelessWidget {
  const _TodayRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.lines,
    this.action,
    this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final List<String> lines;
  final String? action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => FeatureCard(
    onTap: onTap,
    child: Row(
      children: [
        IconBadge(icon: icon, color: color, size: 40),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              UserContentText(
                title,
                style: const TextStyle(
                  color: studafyInk,
                  fontWeight: FontWeight.w800,
                ),
              ),
              for (final line in lines)
                UserContentText(
                  line,
                  style: const TextStyle(color: studafyMuted, fontSize: 12.5),
                ),
            ],
          ),
        ),
        if (onTap != null) ...[
          const SizedBox(width: 8),
          if (action case final label?)
            Text(
              label,
              style: const TextStyle(
                color: studafyNavy,
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
              ),
            )
          else
            Icon(forwardChevron(context), color: studafyMuted),
        ],
      ],
    ),
  );
}

/// A quiet line that says nothing is waiting, rather than an empty gap - or,
/// with an action, that something could not be read.
class _Notice extends StatelessWidget {
  const _Notice({
    required this.text,
    this.icon = Icons.check_circle_outline,
    this.color = studafyMuted,
    this.actionLabel,
    this.onAction,
  });

  final String text;
  final IconData icon;
  final Color color;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: studafyWash,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: TextStyle(color: color)),
        ),
        if (actionLabel != null && onAction != null)
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ],
    ),
  );
}

/// One class's contribution to Today.
@immutable
class _ClassToday {
  const _ClassToday({
    required this.failed,
    required this.work,
    required this.sections,
  });

  final bool failed;
  final List<TeacherWorkItem> work;
  final List<_TodaySection> sections;
}

/// A section taught and still without a lesson its class can see.
@immutable
class _TodaySection {
  const _TodaySection({required this.classroom, required this.session});
  final ClassroomSummary classroom;
  final LessonSession session;
}
