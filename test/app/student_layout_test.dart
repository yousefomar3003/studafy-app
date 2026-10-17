import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/app/studafy_theme.dart';
import 'package:studafy/app/student_shell.dart';
import 'package:studafy/core/studafy_design.dart';
import 'package:studafy/core/studafy_domain.dart';
import 'package:studafy/core/telemetry.dart';
import 'package:studafy/features/academic/data/preview_academic_repository.dart';
import 'package:studafy/features/classes/application/class_list_interactor.dart';
import 'package:studafy/features/classes/data/preview_classroom_repository.dart';
import 'package:studafy/features/study/data/preview_study_repository.dart';
import 'package:studafy/features/study_assistant/application/study_assistant_interactor.dart';
import 'package:studafy/features/study_assistant/domain/study_assistant_repository.dart';

import '../support/accessibility.dart';
import '../support/localized_app.dart';
import '../support/system_back.dart';

/// Every student tab, on a small phone, a large phone and a tablet, with
/// large text and in Arabic: nothing may overflow, and the floating bar must
/// leave every tab reachable.
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

void main() {
  setUp(() {
    const membership = SchoolMembership(
      id: 'membership-1',
      schoolId: 'school-1',
      schoolName: 'Al-Noor International',
      role: StudafyRole.student,
      active: true,
    );
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

  final cases = <(String, Size, double, Locale)>[
    ('small phone', const Size(320, 640), 1, const Locale('en')),
    ('phone, large text', const Size(390, 844), 1.6, const Locale('en')),
    ('phone, Arabic', const Size(390, 844), 1, const Locale('ar')),
    ('tablet', const Size(834, 1112), 1, const Locale('en')),
    // Launch plan 7.1: the largest text size phones offer, in both scripts.
    ('phone, 2x text', const Size(390, 844), 2, const Locale('en')),
    ('phone, Arabic, 2x text', const Size(390, 844), 2, const Locale('ar')),
  ];

  for (final (name, size, scale, locale) in cases) {
    testWidgets('every student tab lays out: $name', (tester) async {
      // Accessibility on every tab (launch plan 7.1): tap targets, labels,
      // contrast.
      final semantics = tester.ensureSemantics();
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await tester.pumpWidget(
        localizedApp(
          locale: locale,
          theme: studafyTheme(),
          home: StudentShell(
            academic: PreviewAcademicRepository(),
            classes: ClassListInteractor(
              repository: const PreviewClassroomRepository(),
              telemetry: const NoopTelemetry(),
            ),
            study: PreviewStudyRepository(),
            studyAssistant: StudyAssistantInteractor(
              repository: _Helper(),
              telemetry: const NoopTelemetry(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Today, Lessons, Work, Helper - by position, so the check holds in
      // either language.
      expect(find.byType(StudafyNavDestination), findsNWidgets(4));
      await expectAccessible(tester);
      for (var tab = 1; tab < 4; tab++) {
        await tester.tap(find.byType(StudafyNavDestination).at(tab));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'tab $tab');
        await expectAccessible(tester);
      }
      semantics.dispose();
    });
  }

  group('the Android back button', () {
    Future<void> pumpShell(WidgetTester tester) async {
      await tester.pumpWidget(
        localizedApp(
          locale: const Locale('en'),
          theme: studafyTheme(),
          home: StudentShell(
            academic: PreviewAcademicRepository(),
            classes: ClassListInteractor(
              repository: const PreviewClassroomRepository(),
              telemetry: const NoopTelemetry(),
            ),
            study: PreviewStudyRepository(),
            studyAssistant: StudyAssistantInteractor(
              repository: _Helper(),
              telemetry: const NoopTelemetry(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    int selectedTab(WidgetTester tester) => tester
        .widget<StudafyNavigationBar>(find.byType(StudafyNavigationBar))
        .selectedIndex;

    Future<void> openTab(WidgetTester tester, int tab) async {
      await tester.tap(find.byType(StudafyNavDestination).at(tab));
      await tester.pumpAndSettle();
    }

    testWidgets('goes from any other tab to Today, then leaves', (
      tester,
    ) async {
      final exits = AppExits(tester);
      await pumpShell(tester);

      for (final tab in [1, 2]) {
        await openTab(tester, tab);
        expect(selectedTab(tester), tab);
        await systemBack(tester);
        expect(selectedTab(tester), 0, reason: 'from tab $tab');
        expect(exits.count, 0, reason: 'from tab $tab');
      }

      await systemBack(tester);
      expect(exits.count, 1);
    });

    testWidgets('from the helper does what its back arrow does', (
      tester,
    ) async {
      final exits = AppExits(tester);
      await pumpShell(tester);
      await openTab(tester, 1);
      await openTab(tester, 3);
      // The helper has the whole screen: no bar while it is open.
      expect(find.byType(StudafyNavigationBar), findsNothing);
      await tester.enterText(find.byType(TextField).last, 'What is a cell?');
      await tester.pump();

      await systemBack(tester);

      // Back on the tab it was opened from, without leaving the app.
      expect(selectedTab(tester), 1);
      expect(exits.count, 0);
      // And the question typed into it is still there.
      await openTab(tester, 3);
      expect(find.text('What is a cell?'), findsOneWidget);
    });

    testWidgets('pops a page opened over a tab, and stays on that tab', (
      tester,
    ) async {
      final exits = AppExits(tester);
      await pumpShell(tester);
      await openTab(tester, 2);

      tester
          .state<NavigatorState>(find.byType(Navigator).first)
          .push(
            MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Text('A pushed page')),
            ),
          );
      await tester.pumpAndSettle();
      await systemBack(tester);

      expect(find.text('A pushed page'), findsNothing);
      expect(selectedTab(tester), 2);
      expect(exits.count, 0);
    });
  });
}
