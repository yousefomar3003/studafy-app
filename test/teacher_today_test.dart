import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/app/teacher_today_page.dart';
import 'package:studafy/core/ids.dart';
import 'package:studafy/core/studafy_domain.dart';
import 'package:studafy/core/studafy_localizations.dart';
import 'package:studafy/core/telemetry.dart';
import 'package:studafy/features/classes/application/class_list_interactor.dart';
import 'package:studafy/features/classes/domain/classroom.dart';
import 'package:studafy/features/classes/domain/classroom_repository.dart';
import 'package:studafy/features/notifications/application/notifications_interactor.dart';
import 'package:studafy/features/notifications/domain/notification.dart';
import 'package:studafy/features/notifications/domain/notifications_repository.dart';
import 'package:studafy/features/notifications/presentation/notifications_scope.dart';

/// The teacher home in real builds must show the signed-in teacher's own
/// classes, never the demo greeting, lessons or student names.
class _Classes implements ClassroomRepository {
  @override
  Future<List<ClassroomSummary>> listClasses() async => const [
    ClassroomSummary(
      id: ClassroomId('class-1'),
      name: 'Physics 11A',
      grade: '11',
      section: 'A',
      studentCount: 24,
    ),
  ];
  @override
  Future<void> createClass(NewClassDraft draft) async {}
  @override
  Future<String> inviteLinkFor(ClassroomId id) async => '';
}

class _Notifications implements NotificationsRepository {
  @override
  Future<NotificationPage> list({String? cursor, int pageSize = 20}) async =>
      const NotificationPage(items: [], nextCursor: null, isFromCache: false);
  @override
  Future<int> unreadCount() async => 3;
  @override
  Future<void> markRead({required List<String> ids, required bool all}) async {}
  @override
  Future<void> syncPending() async {}
}

void main() {
  tearDown(() => ActiveContextController.instance.profile = null);

  test('every teacher home string exists in English and Arabic', () {
    final keys = teacherTodayStringKeys();
    expect(keys['ar'], keys['en']);
  });

  testWidgets('shows the real teacher and classes, never the demo content', (
    tester,
  ) async {
    ActiveContextController.instance.profile = const UserProfile(
      id: 'teacher-1',
      displayName: 'Khaled Mansour',
      email: 'k@example.test',
      memberships: [],
    );
    await tester.pumpWidget(
      MaterialApp(
        supportedLocales: StudafyLocalizations.supportedLocales,
        localizationsDelegates: const [
          StudafyLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) => NotificationsScope(
          interactor: NotificationsInteractor(
            repository: _Notifications(),
            telemetry: const NoopTelemetry(),
          ),
          child: child!,
        ),
        home: TeacherTodayPage(
          classes: ClassListInteractor(
            repository: _Classes(),
            telemetry: const NoopTelemetry(),
          ),
          onOpenClassroom: (_) async {},
          onOpenMessages: () {},
          onOpenNotifications: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Hello, Khaled'), findsOneWidget);
    expect(find.text('Physics 11A'), findsOneWidget);
    expect(find.text('24 students'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    for (final sample in [
      'Rana',
      'Layla Hassan',
      'Photosynthesis lab report',
    ]) {
      expect(find.textContaining(sample), findsNothing);
    }
  });
}
