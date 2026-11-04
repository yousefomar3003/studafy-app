import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studafy/app/app_dependencies.dart';
import 'package:studafy/app/parent_shell.dart';
import 'package:studafy/app/studafy_theme.dart';
import 'package:studafy/app/student_shell.dart';
import 'package:studafy/app/teacher_shell.dart';
import 'package:studafy/core/runtime_environment.dart';
import 'package:studafy/core/studafy_design.dart';
import 'package:studafy/core/studafy_domain.dart';
import 'package:studafy/core/telemetry.dart';
import 'package:studafy/features/academic/data/preview_academic_repository.dart';
import 'package:studafy/features/academic/domain/academic_repository.dart';
import 'package:studafy/features/academic/presentation/academic_overview_page.dart';
import 'package:studafy/features/academic/presentation/submit_work_page.dart';
import 'package:studafy/features/family/application/family_interactor.dart';
import 'package:studafy/features/family/domain/family.dart';
import 'package:studafy/features/family/presentation/family_scope.dart';
import 'package:studafy/features/messaging/application/messaging_interactor.dart';
import 'package:studafy/features/messaging/data/preview_messaging_repository.dart';
import 'package:studafy/features/messaging/presentation/conversation_page.dart';
import 'package:studafy/features/messaging/presentation/messaging_scope.dart';
import 'package:studafy/features/notifications/application/notifications_interactor.dart';
import 'package:studafy/features/notifications/domain/notification.dart';
import 'package:studafy/features/notifications/domain/notification_taps.dart';
import 'package:studafy/features/notifications/domain/notifications_repository.dart';
import 'package:studafy/features/notifications/presentation/notifications_page.dart';
import 'package:studafy/features/notifications/presentation/notifications_scope.dart';
import 'package:studafy/features/study/data/preview_study_repository.dart';
import 'package:studafy/l10n/generated/app_l10n.dart';

import '../support/app_scopes.dart';

/// The app, with [scopes] above the Navigator as `lib/main.dart` puts them,
/// so pages a notification pushes reach them too.
Widget localizedApp({
  required Widget home,
  Locale? locale,
  ThemeData? theme,
  Widget Function(Widget child)? scopes,
}) => MaterialApp(
  theme: theme,
  locale: locale,
  supportedLocales: AppL10n.supportedLocales,
  localizationsDelegates: const [
    AppL10n.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  builder: (_, child) => scopes == null ? child! : scopes(child!),
  home: home,
);

/// A tapped notification - a push, or a row in the in-app list - opens the
/// exact thing it is about, in every role: the conversation, the piece of
/// work, the test. Something gone says so; a kind with nowhere to go says
/// that too, instead of seeming to ignore the tap.
void main() {
  final context = ActiveContextController.instance;

  void signIn(String id, StudafyRole role) {
    final membership = SchoolMembership(
      id: 'membership-$id',
      schoolId: 'school-1',
      schoolName: 'Al-Noor International',
      role: role,
      active: true,
    );
    context
      ..profile = UserProfile(
        id: id,
        displayName: id,
        email: '$id@example.test',
        memberships: [membership],
      )
      ..membership = membership;
  }

  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() {
    context
      ..profile = null
      ..membership = null;
  });

  NotificationItem item(String id, String templateKey, String? route) =>
      NotificationItem(
        id: id,
        templateKey: templateKey,
        title: 'notification.$templateKey.title',
        detail: 'notification.$templateKey.detail',
        createdAt: DateTime(2026, 11, 4),
        route: route,
      );

  int selectedTab(WidgetTester tester) => tester
      .widget<StudafyNavigationBar>(find.byType(StudafyNavigationBar))
      .selectedIndex;

  Future<String> publishedAssignment(PreviewAcademicRepository academic) async {
    await academic.createAssignment(
      AssignmentDraft(
        classroomId: 'class-1',
        title: 'Essay on rivers',
        instructions: 'Two pages.',
        dueAt: DateTime(2030),
      ),
    );
    final created = (await academic.load(AcademicFeed.assignments)).single;
    await academic.publishAssignment(created.id, created.version);
    return created.id;
  }

  Widget Function(Widget) notificationScopes(
    _Feed feed,
    NotificationTaps taps, {
    MessagingInteractor? messaging,
  }) => (child) {
    final scoped = NotificationsScope(
      interactor: NotificationsInteractor(
        repository: feed,
        telemetry: const NoopTelemetry(),
        taps: taps,
      ),
      child: child,
    );
    return messaging == null
        ? scoped
        : MessagingScope(interactor: messaging, child: scoped);
  };

  MessagingInteractor previewMessaging(PreviewMessagingRepository repository) =>
      MessagingInteractor(
        messaging: repository,
        safety: repository,
        telemetry: const NoopTelemetry(),
      );

  group('a student', () {
    testWidgets('a push about a piece of work opens that work to hand in', (
      tester,
    ) async {
      signIn('student-1', StudafyRole.student);
      final academic = PreviewAcademicRepository();
      final id = await publishedAssignment(academic);
      final taps = NotificationTaps();
      final feed = _Feed([
        item('n1', 'academic.assignment_published', 'assignment:$id'),
      ]);
      await tester.pumpWidget(
        localizedApp(
          locale: const Locale('en'),
          theme: studafyTheme(),
          scopes: notificationScopes(feed, taps),
          home: StudentShell(
            academic: academic,
            study: PreviewStudyRepository(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      taps.tapped('n1', recipientId: 'student-1');
      await tester.pumpAndSettle();

      final page = tester.widget<SubmitWorkPage>(find.byType(SubmitWorkPage));
      expect(page.assignmentId, id);
      expect(page.assignmentTitle, 'Essay on rivers');
      expect(feed.markedRead, ['n1']);
    });

    testWidgets('work that was removed opens Work and says it is gone', (
      tester,
    ) async {
      signIn('student-1', StudafyRole.student);
      final taps = NotificationTaps();
      final feed = _Feed([
        item('n1', 'academic.grade_published', 'grade:withdrawn-grade'),
      ]);
      await tester.pumpWidget(
        localizedApp(
          locale: const Locale('en'),
          theme: studafyTheme(),
          scopes: notificationScopes(feed, taps),
          home: StudentShell(
            academic: PreviewAcademicRepository(),
            study: PreviewStudyRepository(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      taps.tapped('n1');
      await tester.pumpAndSettle();

      expect(selectedTab(tester), 2);
      expect(
        tester
            .widget<AcademicOverviewPage>(
              find.byType(AcademicOverviewPage).last,
            )
            .initialFeed,
        AcademicFeed.grades,
      );
      expect(find.text('This is no longer available.'), findsOneWidget);
      expect(find.byType(SubmitWorkPage), findsNothing);
    });

    testWidgets('a message notification opens that conversation', (
      tester,
    ) async {
      signIn('student-1', StudafyRole.student);
      final repository = PreviewMessagingRepository(myUserId: 'student-1');
      final conversation = await repository.startConversation(
        schoolId: 'school-1',
        participantIds: ['demo-teacher'],
        subject: 'Homework help',
      );
      final taps = NotificationTaps();
      final feed = _Feed([
        item(
          'n1',
          'communications.message_sent',
          'conversation:${conversation.id}',
        ),
      ]);
      await tester.pumpWidget(
        localizedApp(
          locale: const Locale('en'),
          theme: studafyTheme(),
          scopes: notificationScopes(
            feed,
            taps,
            messaging: previewMessaging(repository),
          ),
          home: StudentShell(
            academic: PreviewAcademicRepository(),
            study: PreviewStudyRepository(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      taps.tapped('n1');
      await tester.pumpAndSettle();

      final page = tester.widget<ConversationPage>(
        find.byType(ConversationPage),
      );
      expect(page.conversation.id, conversation.id);
    });
  });

  group('a teacher', () {
    Future<(AppDependencies, NotificationTaps)> pumpTeacher(
      WidgetTester tester,
      List<NotificationItem> items,
    ) async {
      signIn('teacher-1', StudafyRole.teacher);
      const policy = RuntimePolicy(StudafyEnvironment.synthetic);
      StudafyRuntime.initialize(policy);
      final deps = AppDependencies.forPolicy(policy);
      final taps = NotificationTaps();
      await tester.pumpWidget(
        localizedApp(
          locale: const Locale('en'),
          theme: studafyTheme(),
          scopes: (child) =>
              appScopes(deps, notificationScopes(_Feed(items), taps)(child)),
          home: TeacherShell(dependencies: deps),
        ),
      );
      await tester.pumpAndSettle();
      return (deps, taps);
    }

    testWidgets('a message opens the conversation, not just the list', (
      tester,
    ) async {
      final repository = PreviewMessagingRepository(myUserId: 'teacher-1');
      final conversation = await repository.startConversation(
        schoolId: 'school-1',
        participantIds: ['demo-teacher'],
      );
      signIn('teacher-1', StudafyRole.teacher);
      const policy = RuntimePolicy(StudafyEnvironment.synthetic);
      StudafyRuntime.initialize(policy);
      final deps = AppDependencies.forPolicy(policy);
      final taps = NotificationTaps();
      final feed = _Feed([
        item(
          'n1',
          'communications.message_sent',
          'conversation:${conversation.id}',
        ),
      ]);
      await tester.pumpWidget(
        localizedApp(
          locale: const Locale('en'),
          theme: studafyTheme(),
          scopes: (child) => appScopes(
            deps,
            notificationScopes(
              feed,
              taps,
              messaging: previewMessaging(repository),
            )(child),
          ),
          home: TeacherShell(dependencies: deps),
        ),
      );
      await tester.pumpAndSettle();

      taps.tapped('n1');
      await tester.pumpAndSettle();

      expect(find.byType(NotificationsPage), findsNothing);
      expect(
        tester
            .widget<ConversationPage>(find.byType(ConversationPage))
            .conversation
            .id,
        conversation.id,
      );
    });

    testWidgets('a test opens Teaching at Assessments, to open that test', (
      tester,
    ) async {
      final (_, taps) = await pumpTeacher(tester, [
        item('n1', 'academic.assessment_published', 'assessment:exam-7'),
      ]);

      taps.tapped('n1');
      await tester.pumpAndSettle();

      expect(find.byType(NotificationsPage), findsNothing);
      expect(selectedTab(tester), 2);
      final teaching = tester.widget<AcademicOverviewPage>(
        find.byType(AcademicOverviewPage).last,
      );
      expect(teaching.initialFeed, AcademicFeed.assessments);
      expect(teaching.openRecordId, 'exam-7');
      // Not in the preview's feed: it says so.
      expect(find.text('This is no longer available.'), findsOneWidget);
    });

    testWidgets('a kind with nowhere to go still opens the list', (
      tester,
    ) async {
      final (_, taps) = await pumpTeacher(tester, [
        item('n1', 'invitations.issued', null),
      ]);

      taps.tapped('n1');
      await tester.pumpAndSettle();

      expect(find.byType(NotificationsPage), findsOneWidget);
    });
  });

  group('a parent', () {
    Future<NotificationTaps> pumpParent(
      WidgetTester tester,
      List<NotificationItem> items, {
      PreviewMessagingRepository? messages,
    }) async {
      StudafyRuntime.initialize(
        const RuntimePolicy(StudafyEnvironment.synthetic),
      );
      context.hydrate(
        authenticatedProfile: const UserProfile(
          id: 'parent-1',
          displayName: 'Nadia Hassan',
          email: 'nadia@example.test',
          memberships: [],
          accountKind: AccountKind.adult,
        ),
        signedInAs: StudafyRole.parent,
      );
      final taps = NotificationTaps();
      final inbox =
          messages ?? PreviewMessagingRepository(myUserId: 'parent-1');
      await tester.pumpWidget(
        localizedApp(
          locale: const Locale('en'),
          theme: studafyTheme(),
          scopes: (child) => FamilyScope(
            interactor: FamilyInteractor(
              family: _TwoChildren(),
              telemetry: const NoopTelemetry(),
            ),
            child: notificationScopes(
              _Feed(items),
              taps,
              messaging: previewMessaging(inbox),
            )(child),
          ),
          home: ParentShell(academic: PreviewAcademicRepository()),
        ),
      );
      await tester.pumpAndSettle();
      return taps;
    }

    testWidgets('a message about a child opens that conversation', (
      tester,
    ) async {
      final repository = PreviewMessagingRepository(myUserId: 'parent-1');
      final conversation = await repository.startConversation(
        schoolId: 'noor',
        participantIds: ['demo-teacher'],
      );
      final taps = await pumpParent(tester, [
        item(
          'n1',
          'communications.message_sent',
          'conversation:${conversation.id}',
        ),
      ], messages: repository);

      taps.tapped('n1');
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<ConversationPage>(find.byType(ConversationPage))
            .conversation
            .id,
        conversation.id,
      );
    });

    testWidgets('a test opens Learning at Assessments, for every child, to '
        'open that test whoever it is for', (tester) async {
      final taps = await pumpParent(tester, [
        item('n1', 'academic.assessment_published', 'assessment:exam-7'),
      ]);

      taps.tapped('n1');
      await tester.pumpAndSettle();

      expect(selectedTab(tester), 1);
      final learning = tester.widget<AcademicOverviewPage>(
        find.byType(AcademicOverviewPage),
      );
      expect(learning.initialFeed, AcademicFeed.assessments);
      expect(learning.openRecordId, 'exam-7');
      expect(learning.studentId, isNull, reason: 'both children, labelled');
      expect(find.text('This is no longer available.'), findsOneWidget);
    });
  });

  group('the in-app list', () {
    testWidgets('a row with nothing more to open says so', (tester) async {
      signIn('teacher-1', StudafyRole.teacher);
      final feed = _Feed([item('n1', 'invitations.issued', null)]);
      await tester.pumpWidget(
        localizedApp(
          locale: const Locale('en'),
          theme: studafyTheme(),
          scopes: notificationScopes(feed, NotificationTaps()),
          home: NotificationsPage(onOpen: (_) => false),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.bySemanticsLabel(RegExp(r'Unread')));
      await tester.pumpAndSettle();

      expect(
        find.text('There is nothing more to open for this notification.'),
        findsOneWidget,
      );
      expect(feed.markedRead, ['n1']);
    });
  });

  group('the feed opens the record a notification names', () {
    Future<List<String>> openIn(
      WidgetTester tester,
      AcademicFeed feed,
      String id,
      PreviewAcademicRepository academic, {
      VoidCallback? missing,
    }) async {
      final opened = <String>[];
      await tester.pumpWidget(
        localizedApp(
          locale: const Locale('en'),
          theme: studafyTheme(),
          home: AcademicOverviewPage(
            repository: academic,
            initialFeed: feed,
            openRecordId: id,
            onRecordMissing: missing,
            onOpenRecord: (record) => opened.add('work ${record.id}'),
            onOpenAssessment: (assessmentId, _, _) =>
                opened.add('test $assessmentId'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return opened;
    }

    testWidgets('a piece of work, as a tap on its row would', (tester) async {
      final academic = PreviewAcademicRepository();
      final id = await publishedAssignment(academic);
      expect(await openIn(tester, AcademicFeed.assignments, id, academic), [
        'work $id',
      ]);
    });

    testWidgets('one that is gone is reported, and nothing opens', (
      tester,
    ) async {
      var missing = 0;
      final opened = await openIn(
        tester,
        AcademicFeed.assignments,
        'deleted-1',
        PreviewAcademicRepository(),
        missing: () => missing++,
      );
      expect(opened, isEmpty);
      expect(missing, 1);
    });
  });
}

class _TwoChildren implements FamilyRepository {
  @override
  Future<List<GuardianChild>> children() async => const [
    GuardianChild(
      linkId: 'l1',
      studentId: 'layla',
      studentName: 'Layla Hassan',
      schoolId: 'noor',
      schoolName: 'Al-Noor International School',
      status: GuardianLinkStatus.verified,
    ),
    GuardianChild(
      linkId: 'l2',
      studentId: 'omar',
      studentName: 'Omar Hassan',
      schoolId: 'river',
      schoolName: 'Riverside Academy',
      status: GuardianLinkStatus.verified,
    ),
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _Feed implements NotificationsRepository {
  _Feed(this.items);

  final List<NotificationItem> items;
  final markedRead = <String>[];

  @override
  Future<NotificationPage> list({String? cursor, int pageSize = 20}) async =>
      NotificationPage(items: items, nextCursor: null, isFromCache: false);

  @override
  Future<void> markRead({required List<String> ids, required bool all}) async =>
      markedRead.addAll(ids);

  @override
  Future<int> unreadCount() async => 0;

  @override
  Future<void> syncPending() async {}

  @override
  Future<List<NotificationPreference>> preferences() async => const [];

  @override
  Future<NotificationPreference> updatePreference(
    NotificationPreference preference,
  ) async => preference;
}
