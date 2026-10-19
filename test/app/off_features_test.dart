import 'package:flutter/material.dart';
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
import 'package:studafy/features/classes/application/class_list_interactor.dart';
import 'package:studafy/features/classes/data/preview_classroom_repository.dart';
import 'package:studafy/features/family/application/family_interactor.dart';
import 'package:studafy/features/family/domain/family.dart';
import 'package:studafy/features/family/presentation/family_scope.dart';
import 'package:studafy/features/messaging/application/messaging_interactor.dart';
import 'package:studafy/features/messaging/domain/messaging.dart';
import 'package:studafy/features/messaging/presentation/messaging_scope.dart';
import 'package:studafy/features/study/data/preview_study_repository.dart';
import 'package:studafy/features/study/domain/study.dart';
import 'package:studafy/features/study_assistant/application/study_assistant_interactor.dart';
import 'package:studafy/features/study_assistant/domain/study_assistant_repository.dart';
import 'package:studafy/l10n/generated/app_l10n.dart';

import '../support/app_scopes.dart';
import '../support/localized_app.dart';

/// What the server has switched off is not offered at all (2026-10-16), so
/// the app and its store pictures show the same thing:
///
/// - no Helper tab, plans or other AI study tools when the server says the
///   AI is not available to this account (`/v1/me/study-plan` `available`),
///   except that with AI on server-wide (`aiEnabled`) a student in no class
///   keeps the Helper tab, which says to join a class (2026-10-17);
/// - no Messages, Inbox or "Message a teacher" where the school has
///   messaging switched off (its content controls; a guardian's links).
///
/// In English and Arabic.
void main() {
  const locales = [Locale('en'), Locale('ar')];

  Finder navLabel(String label) => find.descendant(
    of: find.byType(StudafyNavigationBar),
    matching: find.text(label),
  );

  MessagingScope inbox({required bool enabled, required Widget child}) =>
      MessagingScope(
        interactor: MessagingInteractor(
          messaging: _Inbox(enabled: enabled),
          safety: _NoSafety(),
          telemetry: const NoopTelemetry(),
        ),
        child: child,
      );

  group('student', () {
    const membership = SchoolMembership(
      id: 'membership-1',
      schoolId: 'school-1',
      schoolName: 'Al-Noor International',
      role: StudafyRole.student,
      active: true,
    );
    setUp(() {
      ActiveContextController.instance
        ..profile = const UserProfile(
          id: 'user-1',
          displayName: 'Sara Al-Amin',
          email: 'sara@example.test',
          memberships: [membership],
        )
        ..membership = membership;
    });
    tearDown(() {
      ActiveContextController.instance
        ..profile = null
        ..membership = null;
    });

    Future<void> pump(
      WidgetTester tester, {
      required Locale locale,
      required Set<String> available,
      required bool messaging,
      bool? aiEnabled,
      String? aiAccess,
    }) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        localizedApp(
          locale: locale,
          theme: studafyTheme(),
          scopes: (child) => inbox(enabled: messaging, child: child),
          home: StudentShell(
            academic: PreviewAcademicRepository(),
            classes: ClassListInteractor(
              repository: const PreviewClassroomRepository(),
              telemetry: const NoopTelemetry(),
            ),
            study: _Study(available, aiEnabled: aiEnabled, aiAccess: aiAccess),
            studyAssistant: StudyAssistantInteractor(
              repository: _Helper(),
              telemetry: const NoopTelemetry(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    for (final locale in locales) {
      final l10n = lookupAppL10n(locale);

      testWidgets('AI and messaging off: no Helper, no plans, no Messages '
          '(${locale.languageCode})', (tester) async {
        await pump(tester, locale: locale, available: {}, messaging: false);
        // Today, Lessons, Work and the school's announcements.
        expect(find.byType(StudafyNavDestination), findsNWidgets(4));
        expect(navLabel(l10n.studyAssistantTab), findsNothing);
        expect(navLabel(l10n.navMessages), findsNothing);
        expect(navLabel(l10n.navAnnouncementsTab), findsOneWidget);

        await tester.tap(find.byType(StudafyNavDestination).at(1));
        await tester.pumpAndSettle();
        expect(find.text(l10n.studentLessonsPlans), findsNothing);
        expect(find.text(l10n.upgradeButton), findsNothing);
        expect(find.text(l10n.accountSectionSubscription), findsNothing);

        // The last tab is the announcements, with no way to start a chat.
        await tester.tap(find.byType(StudafyNavDestination).at(3));
        await tester.pumpAndSettle();
        expect(find.text(l10n.msgNew), findsNothing);
        expect(tester.takeException(), isNull);
      });

      testWidgets('AI on, no class yet: the Helper tab stays and says to '
          'join a class (${locale.languageCode})', (tester) async {
        // The owner's five tabs (2026-10-17): with AI on server-wide a
        // student always has the Helper tab. The server still refuses the
        // tools to a student in no class; the tab explains instead.
        await pump(
          tester,
          locale: locale,
          available: {},
          aiEnabled: true,
          aiAccess: 'no_class',
          messaging: true,
        );
        expect(find.byType(StudafyNavDestination), findsNWidgets(5));
        expect(navLabel(l10n.studyAssistantTab), findsOneWidget);
        expect(navLabel(l10n.navMessages), findsOneWidget);

        await tester.tap(find.byType(StudafyNavDestination).at(3));
        await tester.pumpAndSettle();
        expect(find.text(l10n.studyHelperNeedsClassTitle), findsOneWidget);
        expect(find.text(l10n.studyHelperNeedsClassBody), findsOneWidget);
        expect(find.text(l10n.joinClassAction), findsOneWidget);
        // Not the chat: the bar stays, so the student can go elsewhere.
        expect(find.byType(StudafyNavigationBar), findsOneWidget);
        // No plans are sold for tools this student cannot use yet.
        await tester.tap(find.byType(StudafyNavDestination).at(1));
        await tester.pumpAndSettle();
        expect(find.text(l10n.studentLessonsPlans), findsNothing);

        // Messages is still the last tab.
        await tester.tap(find.byType(StudafyNavDestination).at(4));
        await tester.pumpAndSettle();
        expect(find.text(l10n.studyHelperNeedsClassTitle), findsNothing);
        expect(tester.takeException(), isNull);
      });

      testWidgets('AI off server-wide: no Helper tab even with no class '
          '(${locale.languageCode})', (tester) async {
        await pump(
          tester,
          locale: locale,
          available: {},
          aiEnabled: false,
          aiAccess: 'no_class',
          messaging: true,
        );
        expect(find.byType(StudafyNavDestination), findsNWidgets(4));
        expect(navLabel(l10n.studyAssistantTab), findsNothing);
        expect(navLabel(l10n.navMessages), findsOneWidget);
        expect(find.text(l10n.studyHelperNeedsClassTitle), findsNothing);
        expect(tester.takeException(), isNull);
      });

      testWidgets('AI and messaging on: Helper, plans and Messages '
          '(${locale.languageCode})', (tester) async {
        await pump(
          tester,
          locale: locale,
          available: {'ask', 'whiteboard', 'notes', 'quiz', 'flashcards'},
          aiEnabled: true,
          aiAccess: 'ok',
          messaging: true,
        );
        expect(find.byType(StudafyNavDestination), findsNWidgets(5));
        expect(navLabel(l10n.studyAssistantTab), findsOneWidget);
        expect(navLabel(l10n.navMessages), findsOneWidget);

        await tester.tap(find.byType(StudafyNavDestination).at(1));
        await tester.pumpAndSettle();
        expect(
          find.text(l10n.upgradeButton).evaluate().isNotEmpty ||
              find.text(l10n.studentLessonsPlans).evaluate().isNotEmpty,
          isTrue,
        );
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('teacher', () {
    const membership = SchoolMembership(
      id: 'membership-1',
      schoolId: 'school-1',
      schoolName: 'Al-Noor International',
      role: StudafyRole.teacher,
      active: true,
    );
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      ActiveContextController.instance
        ..profile = const UserProfile(
          id: 'teacher-1',
          displayName: 'Omar Haddad',
          email: 'omar@example.test',
          memberships: [membership],
        )
        ..membership = membership;
    });
    tearDown(() {
      ActiveContextController.instance
        ..profile = null
        ..membership = null;
    });

    for (final locale in locales) {
      final l10n = lookupAppL10n(locale);
      for (final messaging in [false, true]) {
        testWidgets(
          'messaging ${messaging ? 'on: the Inbox' : 'off: '
                    'announcements only'} (${locale.languageCode})',
          (tester) async {
            const policy = RuntimePolicy(StudafyEnvironment.synthetic);
            StudafyRuntime.initialize(policy);
            tester.view.physicalSize = const Size(390, 844);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);
            final deps = AppDependencies.forPolicy(policy);
            await tester.pumpWidget(
              localizedApp(
                locale: locale,
                theme: studafyTheme(),
                // The school's switch, nearer than the preview build's.
                scopes: (child) =>
                    appScopes(deps, inbox(enabled: messaging, child: child)),
                home: TeacherShell(dependencies: deps),
              ),
            );
            await tester.pumpAndSettle();
            expect(find.byType(StudafyNavDestination), findsNWidgets(5));
            expect(
              navLabel(l10n.navInbox),
              messaging ? findsOneWidget : findsNothing,
            );
            expect(
              navLabel(l10n.navAnnouncementsTab),
              messaging ? findsNothing : findsOneWidget,
            );
            await tester.tap(find.byType(StudafyNavDestination).at(4));
            await tester.pumpAndSettle();
            expect(
              find.text(l10n.msgNew),
              messaging ? findsOneWidget : findsNothing,
            );
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  });

  group('parent', () {
    tearDown(() => ActiveContextController.instance.signOut());

    for (final locale in locales) {
      final l10n = lookupAppL10n(locale);
      for (final messaging in [false, true]) {
        testWidgets('a child\'s school with messaging '
            '${messaging ? 'on' : 'off'} (${locale.languageCode})', (
          tester,
        ) async {
          StudafyRuntime.initialize(
            const RuntimePolicy(StudafyEnvironment.synthetic),
          );
          tester.view.physicalSize = const Size(390, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          ActiveContextController.instance.hydrate(
            authenticatedProfile: const UserProfile(
              id: 'parent-1',
              displayName: 'Nadia Hassan',
              email: 'nadia@example.test',
              memberships: [],
              accountKind: AccountKind.adult,
            ),
            signedInAs: StudafyRole.parent,
          );
          final family = _OneChild(messagingEnabled: messaging);
          await tester.pumpWidget(
            localizedApp(
              locale: locale,
              theme: studafyTheme(),
              scopes: (child) => inbox(
                // Content controls are not the guardian's to read: the
                // link is what says it.
                enabled: true,
                child: FamilyScope(
                  interactor: FamilyInteractor(
                    family: family,
                    approvals: family,
                    confirmRecentAuth: () async {},
                    telemetry: const NoopTelemetry(),
                  ),
                  child: child,
                ),
              ),
              home: ParentShell(academic: PreviewAcademicRepository()),
            ),
          );
          await tester.pumpAndSettle();
          // Today, Learning, Announcements, and Messages only where on.
          expect(
            find.byType(StudafyNavDestination),
            findsNWidgets(messaging ? 4 : 3),
          );
          expect(navLabel(l10n.navAnnouncementsTab), findsOneWidget);
          expect(
            navLabel(l10n.navMessages),
            messaging ? findsOneWidget : findsNothing,
          );
          expect(
            find.text(l10n.parentQuickMessages),
            messaging ? findsOneWidget : findsNothing,
          );
          expect(tester.takeException(), isNull);
        });
      }
    }
  });
}

class _Study extends PreviewStudyRepository {
  _Study(this.available, {this.aiEnabled, this.aiAccess});

  final Set<String> available;
  final bool? aiEnabled;
  final String? aiAccess;

  @override
  Future<StudyPlan> plan() async => StudyPlan(
    tier: StudyPlanTier.free,
    allowance: StudyPlan.free.allowance,
    available: available,
    aiEnabled: aiEnabled,
    aiAccess: aiAccess,
  );
}

class _Helper implements StudyAssistantRepository {
  @override
  Future<StudyAnswer> ask(
    String question, {
    List<ChatTurn> history = const [],
    List<ChatReference> references = const [],
    List<String> photoFileIds = const [],
    String? requestId,
    String? language,
    bool skipUnavailable = false,
  }) async => const StudyAnswer(answer: 'Answer');
}

class _OneChild implements FamilyRepository, PurchaseApprovalRepository {
  _OneChild({required this.messagingEnabled});

  final bool messagingEnabled;

  @override
  Future<List<GuardianChild>> children() async => [
    GuardianChild(
      linkId: 'l1',
      studentId: 'layla',
      studentName: 'Layla Hassan',
      schoolId: 'noor',
      schoolName: 'Al-Noor International School',
      status: GuardianLinkStatus.verified,
      messagingEnabled: messagingEnabled,
    ),
  ];
  @override
  Future<LocatedStudent?> locate(
    String studafyId, {
    String? captchaToken,
  }) async => null;
  @override
  Future<GuardianChild> requestLink(String studentId, {String? relationship}) =>
      throw UnimplementedError();
  @override
  Future<ChildProgress> progress(String studentId) =>
      throw UnimplementedError();
  @override
  Future<List<PurchaseApprovalRequest>> pending() async => const [];
  @override
  Future<void> decide(String approvalId, {required bool approve}) async {}
}

class _Inbox implements MessagingRepository {
  _Inbox({required this.enabled});

  final bool enabled;

  @override
  Future<bool> messagingEnabled(String schoolId) async => enabled;
  @override
  Future<List<Conversation>> conversations() async => const [];
  @override
  Future<void> acknowledgeDelivery() async {}
  @override
  Future<List<Announcement>> announcements({
    String? schoolId,
    String? classroomId,
  }) async => const [];
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _NoSafety implements SafetyRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
