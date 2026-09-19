import 'dart:async';

import 'package:flutter/material.dart';

import '../core/studafy_design.dart';
import '../core/studafy_domain.dart';
import '../core/studafy_localizations.dart';
import '../features/classes/application/class_list_interactor.dart';
import '../features/classes/domain/classroom.dart';
import '../features/notifications/presentation/notifications_scope.dart';
import 'account_hub_page.dart';
import '../core/studafy_formatting.dart';

/// Teacher home for real builds. Everything on it comes from the signed-in
/// profile and the server: the legacy home was fixed demo content, with a
/// sample greeting, invented lessons and invented student names, and must
/// never appear in front of a real school.
class TeacherTodayPage extends StatefulWidget {
  const TeacherTodayPage({
    super.key,
    required this.classes,
    required this.onOpenClassroom,
    required this.onOpenMessages,
    required this.onOpenNotifications,
  });

  final ClassListInteractor classes;
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
    setState(() {
      _loading = false;
      _unread = unread.fold(onSuccess: (n) => n, onFailure: (_) => 0);
      classes.fold(
        onSuccess: (list) {
          _classes = list;
          _failed = false;
        },
        onFailure: (_) => _failed = true,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    String t(String key) => _todayText(context, key);
    final profile = ActiveContextController.instance.profile;
    final school = ActiveContextController.instance.membership?.schoolName;
    final firstName = (profile?.displayName ?? '').trim().split(' ').first;
    final locale = StudafyLocalizations.of(context).locale;
    final today = MaterialLocalizations.of(context)
        .formatFullDate(DateTime.now());
    return Scaffold(
      backgroundColor: studafyCanvas,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(school ?? t('title')),
        actions: [
          IconButton(
            tooltip: t('messages'),
            onPressed: widget.onOpenMessages,
            icon: const Icon(Icons.chat_bubble_outline),
          ),
          IconButton(
            tooltip: t('notifications'),
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
            Text(
              firstName.isEmpty
                  ? t('hello')
                  : t('helloName').replaceAll('{name}', firstName),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Text(
              today,
              locale: locale,
              style: const TextStyle(color: studafyMuted),
            ),
            const SizedBox(height: 24),
            Semantics(
              header: true,
              child: Text(
                t('classes'),
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
                title: t('error'),
                message: t('errorDetail'),
                actionLabel: t('retry'),
                onAction: _load,
              )
            else if (_classes.isEmpty)
              StudafyStatusCard(
                icon: Icons.class_outlined,
                title: t('empty'),
                message: t('emptyDetail'),
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
                                t('students').replaceAll(
                                  '{count}',
                                  '${classroom.studentCount}',
                                ),
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
          ],
        ),
      ),
    );
  }
}

String _todayText(BuildContext context, String key) {
  final code = StudafyLocalizations.of(context).locale.languageCode;
  return _strings[code]?[key] ?? _strings['en']![key] ?? key;
}

Map<String, Set<String>> teacherTodayStringKeys() => {
  for (final entry in _strings.entries) entry.key: entry.value.keys.toSet(),
};

const _strings = <String, Map<String, String>>{
  'en': {
    'title': 'Today',
    'hello': 'Hello',
    'helloName': 'Hello, {name}',
    'classes': 'My classes',
    'students': '{count} students',
    'empty': 'No classes yet',
    'emptyDetail':
        'Your school assigns classes. Ask your school administrator.',
    'error': 'Classes could not load',
    'errorDetail': 'Check your connection and try again.',
    'retry': 'Try again',
    'messages': 'Messages',
    'notifications': 'Notifications',
  },
  'ar': {
    'title': 'اليوم',
    'hello': 'مرحباً',
    'helloName': 'مرحباً، {name}',
    'classes': 'فصولي',
    'students': '{count} طلاب',
    'empty': 'لا توجد فصول بعد',
    'emptyDetail': 'تقوم مدرستك بتعيين الفصول. تواصل مع إدارة المدرسة.',
    'error': 'تعذر تحميل الفصول',
    'errorDetail': 'تحقق من اتصالك وحاول مرة أخرى.',
    'retry': 'حاول مرة أخرى',
    'messages': 'الرسائل',
    'notifications': 'الإشعارات',
  },
};
