import 'dart:async';

import 'package:flutter/material.dart';

import '../core/studafy_design.dart';
import '../core/studafy_domain.dart';
import '../features/classes/application/class_list_interactor.dart';
import '../core/user_content_text.dart';
import '../features/academic/domain/academic_repository.dart';
import '../features/classes/domain/classroom.dart';
import '../features/notifications/presentation/notifications_scope.dart';
import 'account_hub_page.dart';
import '../core/studafy_formatting.dart';
import '../l10n/generated/app_l10n.dart';

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
    required this.onOpenMessages,
    required this.onOpenNotifications,
  });

  final ClassListInteractor classes;

  /// Today aggregates from other pages, not only the class list: work that
  /// has been set, and sections still owing their content.
  final AcademicRepository academic;
  final Future<void> Function(ClassroomSummary classroom) onOpenClassroom;
  final VoidCallback onOpenMessages;
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

  Future<void> _load() async {
    setState(() => _loading = true);
    final notifications = NotificationsScope.of(context);
    final classes = await widget.classes.loadClasses();
    final unread = await notifications.unreadCount();
    if (!mounted) return;
    final list = classes.fold(
      onSuccess: (items) => items,
      onFailure: (_) => const <ClassroomSummary>[],
    );
    setState(() {
      _loading = false;
      _unread = unread.fold(onSuccess: (n) => n, onFailure: (_) => 0);
      classes.fold(
        onSuccess: (items) {
          _classes = items;
          _failed = false;
        },
        onFailure: (_) => _failed = true,
      );
    });
    // Each class is asked separately, and a class that fails is skipped
    // rather than emptying the whole page: a teacher with four classes and
    // one bad response should still see the other three.
    final work = <_TodayWork>[];
    final outstanding = <_TodaySection>[];
    for (final classroom in list) {
      try {
        final assignments = await widget.academic.load(
          AcademicFeed.assignments,
          classroomId: classroom.id.value,
        );
        for (final record in assignments) {
          work.add(_TodayWork(title: record.title, className: classroom.name));
        }
      } on Object {
        // Skipped on purpose; see above.
      }
      try {
        final sessions = await widget.academic.lessonSessions(
          classroom.id.value,
        );
        for (final session in sessions.where((item) => !item.filed)) {
          outstanding.add(
            _TodaySection(
              startsAt: session.startsAt,
              className: classroom.name,
            ),
          );
        }
      } on Object {
        // Skipped on purpose; see above.
      }
    }
    if (!mounted) return;
    setState(() {
      _work = work;
      _outstanding = outstanding
        ..sort((a, b) => b.startsAt.compareTo(a.startsAt));
    });
  }

  @override
  Widget build(BuildContext context) {
    final profile = ActiveContextController.instance.profile;
    final school = ActiveContextController.instance.membership?.schoolName;
    final firstName = (profile?.displayName ?? '').trim().split(' ').first;
    final today = MaterialLocalizations.of(context)
        .formatFullDate(DateTime.now());
    return Scaffold(
      backgroundColor: studafyCanvas,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(school ?? AppL10n.of(context).todayTitle),
        actions: [
          IconButton(
            tooltip: AppL10n.of(context).todayMessages,
            onPressed: widget.onOpenMessages,
            icon: const Icon(Icons.chat_bubble_outline),
          ),
          IconButton(
            tooltip: AppL10n.of(context).todayNotifications,
            onPressed: () {
              widget.onOpenNotifications();
              unawaited(_load());
            },
            icon: Badge(
              isLabelVisible: _unread > 0,
              label: Text(studafyNumber(context, _unread)),
              child: const Icon(Icons.notifications_none),
            ),
          ),
          const AccountButton(),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 18, 20, 48),
          children: [
            StudafyHero(
              eyebrow: today,
              title: firstName.isEmpty
                  ? AppL10n.of(context).todayHello
                  : AppL10n.of(context).todayHelloName(firstName),
              subtitle: AppL10n.of(context).teacherTodaySpaceToInspireADay,
              icon: Icons.wb_sunny_outlined,
            ),
            const SizedBox(height: 24),
            Semantics(
              header: true,
              child: Text(
                AppL10n.of(context).todayClasses,
                style: const TextStyle(
                  color: studafyInk,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_failed)
              StudafyStatusCard(
                icon: Icons.error_outline_rounded,
                title: AppL10n.of(context).todayError,
                message: AppL10n.of(context).todayErrorDetail,
                actionLabel: AppL10n.of(context).todayRetry,
                onAction: _load,
              )
            else if (_classes.isEmpty)
              StudafyStatusCard(
                icon: Icons.class_outlined,
                title: AppL10n.of(context).todayEmpty,
                message: AppL10n.of(context).todayEmptyDetail,
              )
            else
              for (final classroom in _classes)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: FeatureCard(
                    onTap: () => widget.onOpenClassroom(classroom),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.diversity_3_rounded,
                          color: studafyNavy,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                classroom.name,
                                style: const TextStyle(
                                  color: studafyInk,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                AppL10n.of(context)
                                    .todayStudents('${classroom.studentCount}'),
                                style: const TextStyle(
                                  color: studafyMuted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(forwardChevron(context)),
                      ],
                    ),
                  ),
                ),
            // Today draws from the other pages, so an empty Today means
            // nothing is outstanding rather than nothing is wired up.
            if (!_loading && !_failed) ...[
              const SizedBox(height: 24),
              Semantics(
                header: true,
                child: Text(
                  AppL10n.of(context).todaySections,
                  style: const TextStyle(
                    color: studafyInk,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (_outstanding.isEmpty)
                Text(
                  AppL10n.of(context).todaySectionsEmpty,
                  style: const TextStyle(color: studafyMuted),
                )
              else
                for (final section in _outstanding.take(5))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: FeatureCard(
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            color: studafyNavy,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                UserContentText(
                                  section.className,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  '${AppL10n.of(context).todaySectionsOutstanding} · '
                                  '${section.startsAt.year}-'
                                  '${section.startsAt.month.toString().padLeft(2, '0')}-'
                                  '${section.startsAt.day.toString().padLeft(2, '0')}',
                                  style: const TextStyle(
                                    color: studafyMuted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              const SizedBox(height: 24),
              Semantics(
                header: true,
                child: Text(
                  AppL10n.of(context).todayWork,
                  style: const TextStyle(
                    color: studafyInk,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (_work.isEmpty)
                Text(
                  AppL10n.of(context).todayWorkEmpty,
                  style: const TextStyle(color: studafyMuted),
                )
              else
                for (final item in _work.take(5))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: FeatureCard(
                      child: Row(
                        children: [
                          const Icon(
                            Icons.assignment_outlined,
                            color: studafyNavy,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                UserContentText(
                                  item.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                UserContentText(
                                  item.className,
                                  style: const TextStyle(
                                    color: studafyMuted,
                                    fontSize: 12,
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
