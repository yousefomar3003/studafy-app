import 'dart:async';

import 'package:flutter/material.dart';

import '../core/navigation.dart';
import '../core/studafy_components.dart';
import '../core/studafy_design.dart';
import '../core/studafy_domain.dart';
import '../core/studafy_formatting.dart';
import '../core/user_content_text.dart';
import '../features/academic/domain/academic_repository.dart';
import '../features/classes/application/class_list_interactor.dart';
import '../features/classes/domain/classroom.dart';
import '../features/family/presentation/student_family_page.dart';
import '../features/meetings/presentation/upcoming_meetings_section.dart';
import '../features/notifications/domain/notification.dart';
import '../features/notifications/presentation/notifications_page.dart';
import '../features/notifications/presentation/notifications_scope.dart';
import '../l10n/generated/app_l10n.dart';
import 'account_hub_page.dart';

/// The student's home: the brand, their notifications and profile, then
/// what matters today in labelled groups - shortcuts, classes, and work.
class StudentTodayPage extends StatefulWidget {
  const StudentTodayPage({
    super.key,
    required this.academic,
    required this.onWork,
    required this.onNotebook,
    this.classes,
    this.onJoinClass,
    this.subscription,
    this.onOpenNotification,
  });

  /// Opens what a tapped notification is about; true when it was handled.
  final bool Function(NotificationItem item)? onOpenNotification;
  final AcademicContentRepository academic;
  final VoidCallback onWork;
  final VoidCallback onNotebook;

  /// Lists the classes this student is in. Optional so the preview shell,
  /// which has no class service behind it, still builds.
  final ClassListInteractor? classes;

  /// Joins another class from a link or code. Null where joining is not
  /// possible, and the action is then absent.
  final Future<void> Function()? onJoinClass;

  /// The Subscription row on the profile this page opens.
  final SubscriptionEntry? subscription;

  @override
  State<StudentTodayPage> createState() => _StudentTodayPageState();
}

class _StudentTodayPageState extends State<StudentTodayPage> {
  // Read once and kept: a future made in build is made again on every
  // rebuild, which re-requested the work and flashed the page on each tap.
  late Future<List<AcademicRecord>> _work = _loadWork();
  final _classesKey = GlobalKey<_StudentClassesState>();
  int _unread = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadUnread());
  }

  Future<List<AcademicRecord>> _loadWork() =>
      widget.academic.load(AcademicFeed.assignments);

  /// The bell's count. Absent in shells with no notifications behind them,
  /// and a failure only leaves the badge off.
  Future<void> _loadUnread() async {
    if (!mounted) return;
    final notifications = NotificationsScope.maybeOf(context);
    if (notifications == null) return;
    final result = await notifications.unreadCount();
    if (!mounted) return;
    setState(
      () => _unread = result.fold(onSuccess: (n) => n, onFailure: (_) => 0),
    );
  }

  /// Pulls so far, so the meetings section reads again with the page.
  int _refreshes = 0;

  Future<void> _refresh() async {
    final work = _loadWork();
    setState(() {
      _work = work;
      _refreshes++;
    });
    await Future.wait<void>([
      work.then((_) {}, onError: (_) {}),
      _loadUnread(),
      if (_classesKey.currentState case final classes?) classes.reload(),
    ]);
  }

  Future<void> _joinClass() async {
    await widget.onJoinClass?.call();
    if (mounted) await _classesKey.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final classes = widget.classes;
    final name = (ActiveContextController.instance.profile?.displayName ?? '')
        .trim()
        .split(RegExp(r'\s+'))
        .first;
    final today = MaterialLocalizations.of(context)
        .formatFullDate(DateTime.now());
    return Scaffold(
      appBar: AppBar(
        // The brand, not the page's name, heads the home screen.
        title: const StudafyLogo(size: 26),
        titleSpacing: 20,
        actions: [
          NotificationBellButton(
            unread: _unread,
            label: studafyNumber(context, _unread),
            onPressed: () async {
              await Navigator.of(context).pushOnce(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      NotificationsPage(onOpen: widget.onOpenNotification),
                ),
              );
              unawaited(_loadUnread());
            },
          ),
          AccountButton(subscription: widget.subscription),
        ],
      ),
      body: StudafyRefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 8, 20, 32),
          children: [
            StudafyHero(
              eyebrow: today,
              title: name.isEmpty
                  ? l10n.studentTodayMakeTodayYours
                  : l10n.studentTodayMakeTodayYoursName(name),
              subtitle: l10n.studentTodayYourClassesYourIdeasYour,
              icon: Icons.wb_sunny_outlined,
            ),
            // A class meeting the teacher set up in Google Meet.
            UpcomingMeetingsSection(refreshToken: _refreshes),
            SectionHeader(l10n.todayQuickActions),
            _Shortcut(
              icon: Icons.assignment_rounded,
              title: l10n.studentTodayMyWork,
              detail: l10n.studentTodayWorkShortcutDetail,
              onTap: widget.onWork,
            ),
            _Shortcut(
              icon: Icons.auto_stories_rounded,
              color: studafyTeal,
              title: l10n.studentTodayLessonsShortcut,
              detail: l10n.studentTodayLessonsShortcutDetail,
              onTap: widget.onNotebook,
            ),
            _Shortcut(
              icon: Icons.family_restroom_rounded,
              color: studafySteel,
              title: l10n.studentTodayMyIdFamily,
              detail: l10n.studentTodayFamilyShortcutDetail,
              onTap: () => Navigator.of(context).pushOnce(
                MaterialPageRoute<void>(
                  builder: (_) => const StudentFamilyPage(),
                ),
              ),
            ),
            // A student's first question on opening the app is which classes
            // they are in - it is how they know the link they pasted worked
            // at all. The work below answers "what do I have to do", which
            // reads as empty until a teacher sets some.
            if (classes != null) ...[
              SectionHeader(
                l10n.studentTodayYourClasses,
                action: widget.onJoinClass == null
                    ? null
                    : TextButton.icon(
                        onPressed: _joinClass,
                        icon: const Icon(Icons.group_add_rounded, size: 19),
                        label: Text(l10n.joinClassAction),
                      ),
              ),
              _StudentClasses(
                key: _classesKey,
                classes: classes,
                onOpen: widget.onNotebook,
              ),
            ],
            SectionHeader(
              l10n.studentTodayWorkSection,
              action: TextButton(
                onPressed: widget.onWork,
                child: Text(l10n.todaySeeAll),
              ),
            ),
            FutureBuilder<List<AcademicRecord>>(
              future: _work,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done &&
                    !snapshot.hasData) {
                  return const _Loading();
                }
                if (snapshot.hasError) {
                  return StudafyEmptyState(
                    icon: Icons.wifi_off_rounded,
                    title: l10n.studentTodayYourWorkCouldNotLoad,
                    actionLabel: l10n.todayRetry,
                    onAction: _refresh,
                  );
                }
                final records = snapshot.data ?? const <AcademicRecord>[];
                if (records.isEmpty) {
                  return _AllClear(
                    title: l10n.studentTodayALittleBreathingRoom,
                    text: l10n.studentTodayNewAssignmentsWillAppearHere,
                  );
                }
                return Column(
                  children: [
                    for (final record in records.take(4))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: FeatureCard(
                          onTap: widget.onWork,
                          padding: const EdgeInsetsDirectional.fromSTEB(
                            14,
                            12,
                            10,
                            12,
                          ),
                          child: Row(
                            children: [
                              const IconBadge(
                                icon: Icons.assignment_rounded,
                                size: 40,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: UserContentText(
                                  record.title,
                                  style: const TextStyle(
                                    color: studafyInk,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Icon(
                                forwardChevron(context),
                                color: studafyMuted,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// One labelled shortcut: what it is, what it holds, and where it goes.
class _Shortcut extends StatelessWidget {
  const _Shortcut({
    required this.icon,
    required this.title,
    required this.detail,
    required this.onTap,
    this.color = studafyNavy,
  });

  final IconData icon;
  final String title;
  final String detail;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: FeatureCard(
      onTap: onTap,
      padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 10, 12),
      child: Row(
        children: [
          IconBadge(icon: icon, color: color, size: 42),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: studafyInk,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: const TextStyle(color: studafyMuted, fontSize: 13),
                ),
              ],
            ),
          ),
          Icon(forwardChevron(context), color: studafyMuted),
        ],
      ),
    ),
  );
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(20),
    child: Center(child: CircularProgressIndicator()),
  );
}

/// A quiet card that says nothing is waiting, rather than an empty gap.
class _AllClear extends StatelessWidget {
  const _AllClear({required this.title, required this.text});

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: studafyWash,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      children: [
        const Icon(Icons.wb_sunny_outlined, color: studafySteel),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: studafyInk,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(text, style: const TextStyle(color: studafyMuted)),
            ],
          ),
        ),
      ],
    ),
  );
}

/// The classes this student belongs to.
///
/// Failure is shown with a retry rather than swallowed: an empty list and a
/// failed request look identical to a student otherwise, and the first means
/// "you are in no class yet" while the second means "try again".
class _StudentClasses extends StatefulWidget {
  const _StudentClasses({super.key, required this.classes, this.onOpen});

  final ClassListInteractor classes;

  /// Opens the class's lessons (the Lessons tab).
  final VoidCallback? onOpen;

  @override
  State<_StudentClasses> createState() => _StudentClassesState();
}

class _StudentClassesState extends State<_StudentClasses> {
  late Future<List<ClassroomSummary>> _classes = _load();

  Future<List<ClassroomSummary>> _load() => widget.classes.loadClasses().then(
    (result) => result.fold(
      onSuccess: (items) => items,
      onFailure: (failure) => throw failure,
    ),
  );

  Future<void> reload() async {
    final next = _load();
    setState(() => _classes = next);
    await next.then((_) {}, onError: (_) {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return FutureBuilder<List<ClassroomSummary>>(
      future: _classes,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done &&
            !snapshot.hasData) {
          return const _Loading();
        }
        if (snapshot.hasError) {
          return StudafyEmptyState(
            icon: Icons.wifi_off_rounded,
            title: l10n.studentTodayClassesCouldNotLoad,
            actionLabel: l10n.todayRetry,
            onAction: reload,
          );
        }
        final items = snapshot.data ?? const <ClassroomSummary>[];
        if (items.isEmpty) {
          return StudafyEmptyState(
            icon: Icons.group_add_outlined,
            title: l10n.studentTodayNoClassesYet,
            message: l10n.studentTodayPasteClassLink,
          );
        }
        return Column(
          children: [
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: FeatureCard(
                  onTap: widget.onOpen,
                  padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 10, 12),
                  child: Row(
                    children: [
                      IconBadge(icon: subjectIcon(item.name), size: 42),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            UserContentText(
                              item.name,
                              style: const TextStyle(
                                color: studafyInk,
                                fontSize: 15.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              l10n.studentTodayGradeSection(
                                item.grade,
                                item.section,
                              ),
                              style: const TextStyle(
                                color: studafyMuted,
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (widget.onOpen != null)
                        Icon(forwardChevron(context), color: studafyMuted),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
