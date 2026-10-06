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
  });

  /// Shortcuts to the things a teacher does most, built by the shell.
  final List<TodayQuickAction> quickActions;

  /// Opens the full class list (the Classes tab).
  final VoidCallback? onSeeAllClasses;

  final ClassListInteractor classes;

  /// Today aggregates from other pages, not only the class list: work that
  /// has been set, and sections still owing their content.
  final AcademicRepository academic;
  final Future<void> Function(ClassroomSummary classroom) onOpenClassroom;

  /// Null hides the messages button - the teacher shell has an Inbox tab.
  final VoidCallback? onOpenMessages;
  final VoidCallback onOpenNotifications;

  @override
  State<TeacherTodayPage> createState() => _TeacherTodayPageState();
}

class _TeacherTodayPageState extends State<TeacherTodayPage> {
  List<ClassroomSummary> _classes = const [];
  int _unread = 0;
  bool _loading = true;
  List<_TodayWork> _work = const [];
  List<_TodaySection> _outstanding = const [];
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  /// Once the page has been shown, a reload (pull, or the bell) keeps it on
  /// screen and swaps in the new figures together when they are all in.
  bool _loaded = false;

  Future<void> _load() async {
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
    final perClass = await Future.wait([
      for (final classroom in list) _loadClass(classroom),
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
      _work = [for (final (work, _) in perClass) ...work];
      _outstanding = [for (final (_, sections) in perClass) ...sections]
        ..sort((a, b) => b.startsAt.compareTo(a.startsAt));
    });
  }

  /// One class's work and unfiled lessons. Each class is asked separately,
  /// and a class that fails is skipped rather than emptying the whole page:
  /// a teacher with four classes and one bad response should still see the
  /// other three.
  Future<(List<_TodayWork>, List<_TodaySection>)> _loadClass(
    ClassroomSummary classroom,
  ) async {
    final id = classroom.id.value;
    Future<T?> skipped<T>(Future<T> read) =>
        read.then<T?>((value) => value, onError: (Object _) => null);
    final (assignments, sessions) = await (
      skipped(widget.academic.load(AcademicFeed.assignments, classroomId: id)),
      skipped(widget.academic.lessonSessions(id)),
    ).wait;
    return (
      [
        for (final record in assignments ?? const <AcademicRecord>[])
          _TodayWork(title: record.title, className: classroom.name),
      ],
      [
        for (final session in sessions ?? const <LessonSession>[])
          if (!session.filed)
            _TodaySection(
              startsAt: session.startsAt,
              className: classroom.name,
            ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final profile = ActiveContextController.instance.profile;
    final firstName = (profile?.displayName ?? '').trim().split(' ').first;
    final today = MaterialLocalizations.of(context)
        .formatFullDate(DateTime.now());
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
                      onTap: action.onTap,
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
                    onTap: () => widget.onOpenClassroom(classroom),
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
                                l10n.todayStudents('${classroom.studentCount}'),
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
            if (!_loading && !_failed) ...[
              SectionHeader(l10n.todaySections),
              if (_outstanding.isEmpty)
                _AllClear(text: l10n.todaySectionsEmpty)
              else
                for (final section in _outstanding.take(5))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: FeatureCard(
                      child: Row(
                        children: [
                          const IconBadge(
                            icon: Icons.pending_actions_rounded,
                            color: studafyCyan,
                            size: 40,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                UserContentText(
                                  section.className,
                                  style: const TextStyle(
                                    color: studafyInk,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  '${l10n.todaySectionsOutstanding} · '
                                  '${MaterialLocalizations.of(context).formatMediumDate(section.startsAt)}',
                                  style: const TextStyle(
                                    color: studafyMuted,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              SectionHeader(l10n.todayWork),
              if (_work.isEmpty)
                _AllClear(
                  text: l10n.todayWorkEmpty,
                  icon: Icons.assignment_outlined,
                )
              else
                for (final item in _work.take(5))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: FeatureCard(
                      child: Row(
                        children: [
                          const IconBadge(
                            icon: Icons.assignment_rounded,
                            size: 40,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                UserContentText(
                                  item.title,
                                  style: const TextStyle(
                                    color: studafyInk,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                UserContentText(
                                  item.className,
                                  style: const TextStyle(
                                    color: studafyMuted,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A shortcut on the teacher's home, wired by the shell.
@immutable
class TodayQuickAction {
  const TodayQuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
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

/// A quiet line that says nothing is waiting, rather than an empty gap.
class _AllClear extends StatelessWidget {
  const _AllClear({required this.text, this.icon = Icons.check_circle_outline});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: studafyWash,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Row(
      children: [
        Icon(icon, color: studafyMuted, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: const TextStyle(color: studafyMuted)),
        ),
      ],
    ),
  );
}

/// One piece of work a teacher has set, shown on Today.
@immutable
class _TodayWork {
  const _TodayWork({required this.title, required this.className});
  final String title;
  final String className;
}

/// A section taught but still owing its content.
@immutable
class _TodaySection {
  const _TodaySection({required this.startsAt, required this.className});
  final DateTime startsAt;
  final String className;
}
