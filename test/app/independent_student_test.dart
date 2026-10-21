import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/app/account_hub_page.dart';
import 'package:studafy/app/studafy_theme.dart';
import 'package:studafy/app/student_shell.dart';
import 'package:studafy/app/student_study_actions.dart';
import 'package:studafy/core/device_settings.dart';
import 'package:studafy/core/inline_photo.dart';
import 'package:studafy/core/studafy_design.dart';
import 'package:studafy/core/studafy_domain.dart';
import 'package:studafy/core/telemetry.dart';
import 'package:studafy/features/academic/data/preview_academic_repository.dart';
import 'package:studafy/features/classes/application/class_list_interactor.dart';
import 'package:studafy/features/classes/data/preview_classroom_repository.dart';
import 'package:studafy/features/study/domain/study.dart';
import 'package:studafy/features/study/presentation/practice_page.dart';
import 'package:studafy/features/study_assistant/application/study_assistant_interactor.dart';
import 'package:studafy/features/study_assistant/domain/study_assistant_repository.dart';

import '../support/accessibility.dart';
import '../support/localized_app.dart';

/// A student who signs up and joins no class (ADR-0045): the join step is
/// optional and shown once, the app is the AI Tutor, the Notebook,
/// flashcards and quizzes, and joining a class later adds to it.
class _Tutor implements StudyAssistantRepository {
  @override
  Future<StudyAnswer> ask(
    String question, {
    List<ChatTurn> history = const [],
    List<ChatReference> references = const [],
    List<String> photoFileIds = const [],
    List<InlinePhoto> inlinePhotos = const [],
    String? requestId,
    String? language,
    bool skipUnavailable = false,
  }) async => const StudyAnswer(answer: 'Answer');
}

/// The server, as far as a student with no class goes.
class _Study implements StudyRepository {
  StudyPlanTier tier = StudyPlanTier.free;
  final notes = <NotebookEntry>[];
  int photoNotes = 0;

  @override
  Future<StudyPlan> plan() async => StudyPlan(
    tier: tier,
    allowance: AiAllowance(
      weekly: tier == StudyPlanTier.free,
      total: 40000,
      used: 0,
      remaining: 40000,
      resetsAt: DateTime(2026, 10, 26),
    ),
    available: const {'ask', 'whiteboard', 'notes', 'quiz', 'flashcards'},
    aiEnabled: true,
    aiAccess: 'ok',
  );

  @override
  Future<List<NotebookEntry>> personalNotebook() async => List.of(notes);

  @override
  Future<List<NotebookGroup>> myNotebooks() async => const [];

  @override
  Future<NotebookEntry> addPersonalNote({
    required String title,
    required String body,
  }) async {
    final entry = NotebookEntry(
      id: 'n${notes.length + 1}',
      classroomId: null,
      title: title,
      body: body,
      fromWhiteboard: false,
      createdAt: DateTime(2026, 10, 21, 9),
      updatedAt: DateTime(2026, 10, 21, 9),
    );
    notes.insert(0, entry);
    return entry;
  }

  @override
  Future<NotebookEntry> photoNote(InlinePhoto photo, {String? title}) async {
    photoNotes++;
    throw const StudyException(StudyRefusal.planRequired);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A store that sells the plans, as on a phone.
class _Plans implements StudyPlanSubscriptionRepository {
  int restores = 0;

  @override
  SubscriptionStore? get purchaseStore => SubscriptionStore.playStore;

  @override
  Future<void> restorePurchases() async => restores++;

  @override
  void addEntitlementListener(VoidCallback listener) {}

  @override
  void removeEntitlementListener(VoidCallback listener) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _profile = UserProfile(
  id: 'user-indep',
  displayName: 'Lina Haddad',
  email: 'lina@example.test',
  memberships: [],
);

Widget _shell({
  required _Study study,
  DeviceSettingsStore? settings,
  StudyPlanSubscriptionRepository? plans,
  Locale locale = const Locale('en'),
}) => localizedApp(
  locale: locale,
  theme: studafyTheme(),
  home: StudentShell(
    academic: PreviewAcademicRepository(),
    classes: ClassListInteractor(
      repository: const PreviewClassroomRepository(),
      telemetry: const NoopTelemetry(),
    ),
    study: study,
    studyPlans: plans,
    studyAssistant: StudyAssistantInteractor(
      repository: _Tutor(),
      telemetry: const NoopTelemetry(),
    ),
    settings: settings,
  ),
);

void main() {
  setUp(() {
    ActiveContextController.instance
      ..profile = _profile
      ..membership = null;
  });
  tearDown(() {
    ActiveContextController.instance
      ..profile = null
      ..membership = null;
  });

  testWidgets('a new student can skip joining a class and use the app', (
    tester,
  ) async {
    final settings = InMemoryDeviceSettings();
    await tester.pumpWidget(_shell(study: _Study(), settings: settings));
    await tester.pumpAndSettle();

    // The join step, with joining optional.
    expect(find.text('Join your first class'), findsOne);
    expect(find.textContaining('Joining a class is optional'), findsOne);
    expect(find.byType(StudafyNavDestination), findsNothing);

    await tester.tap(find.text('Skip for now'));
    await tester.pumpAndSettle();

    // Today, the Notebook and the AI Tutor - no empty Lessons or Work.
    expect(find.byType(StudafyNavDestination), findsNWidgets(3));
    expect(find.text('Notebook'), findsWidgets);
    expect(find.text('AI Tutor'), findsWidgets);
    expect(find.text('Lessons'), findsNothing);
    // The study tools, and a quiet way into a teacher's class.
    expect(find.text('Flashcards'), findsOne);
    expect(find.text('Quizzes'), findsOne);
    expect(find.text('Have a class code?'), findsOne);
    // Remembered on this device, under a hash of the account.
    expect(
      settings.snapshot.keys,
      contains(DeviceSettingKeys.studentClassStepDone('user-indep')),
    );
    expect(settings.snapshot.keys.join(), isNot(contains('user-indep')));
  });

  testWidgets('the join step is not shown again once skipped', (tester) async {
    final settings = InMemoryDeviceSettings({
      DeviceSettingKeys.studentClassStepDone('user-indep'): '1',
    });
    await tester.pumpWidget(_shell(study: _Study(), settings: settings));
    await tester.pumpAndSettle();

    expect(find.text('Skip for now'), findsNothing);
    expect(find.byType(StudafyNavDestination), findsNWidgets(3));
  });

  for (final locale in const [Locale('en'), Locale('ar')]) {
    testWidgets('every tab lays out and is accessible: $locale', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final settings = InMemoryDeviceSettings({
        DeviceSettingKeys.studentClassStepDone('user-indep'): '1',
      });
      await tester.pumpWidget(
        _shell(study: _Study(), settings: settings, locale: locale),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await expectAccessible(tester);
      for (var tab = 1; tab < 3; tab++) {
        await tester.tap(find.byType(StudafyNavDestination).at(tab));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'tab $tab');
        await expectAccessible(tester);
        if (tab == 2) {
          // The AI Tutor has the whole screen; back to the bar.
          await tester.tap(find.byType(BackButton));
          await tester.pumpAndSettle();
        }
      }
      semantics.dispose();
    });
  }

  testWidgets('a free student writes notes; photos into notes are Plus', (
    tester,
  ) async {
    final study = _Study();
    final settings = InMemoryDeviceSettings({
      DeviceSettingKeys.studentClassStepDone('user-indep'): '1',
    });
    await tester.pumpWidget(_shell(study: study, settings: settings));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(StudafyNavDestination).at(1));
    await tester.pumpAndSettle();

    // An empty notebook says what it is and how to start.
    expect(find.text('Your notebook is empty'), findsOne);

    await tester.tap(find.text('New note'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Photosynthesis');
    await tester.enterText(
      find.byType(TextField).last,
      '# Inputs\n- **Light**\n- Water',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(study.notes.single.title, 'Photosynthesis');
    expect(find.text('Photosynthesis'), findsOne);
    expect(find.textContaining('1 page'), findsOne);

    // What Plus adds is said once, below the pages.
    await tester.scrollUntilVisible(
      find.text('Photos into notes with Studafy Plus'),
      200,
    );
    expect(find.text('Photos into notes with Studafy Plus'), findsOne);
    await tester.scrollUntilVisible(find.text('Notes from a photo'), -200);

    // The Plus action explains the plan before anything is picked.
    await tester.tap(find.text('Notes from a photo'));
    await tester.pumpAndSettle();
    expect(find.text('This comes with Studafy Plus'), findsOne);
    expect(study.photoNotes, 0);
  });

  testWidgets('a note opens on paper, formatted, and can be renamed', (
    tester,
  ) async {
    final study = _Study();
    await study.addPersonalNote(
      title: 'Cells',
      body: '# Parts\n- **Nucleus** holds DNA',
    );
    final settings = InMemoryDeviceSettings({
      DeviceSettingKeys.studentClassStepDone('user-indep'): '1',
    });
    await tester.pumpWidget(_shell(study: study, settings: settings));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(StudafyNavDestination).at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cells'));
    await tester.pumpAndSettle();

    // The Markdown is laid out, not shown as symbols.
    expect(find.text('Parts'), findsOne);
    expect(find.textContaining('# Parts'), findsNothing);
    expect(find.byTooltip('Edit'), findsOne);
  });

  testWidgets('flashcards and quizzes: explained to everyone, made on Max', (
    tester,
  ) async {
    final study = _Study();
    await study.addPersonalNote(title: 'Cells', body: 'Cells are units.');
    await tester.pumpWidget(
      localizedApp(
        locale: const Locale('en'),
        theme: studafyTheme(),
        home: PracticePage(study: study, onOpenPlans: () async {}),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Example'.toUpperCase()), findsOne);
    expect(find.text('Included with Studafy Max'), findsOne);
    expect(find.byType(CheckboxListTile), findsNothing);

    study.tier = StudyPlanTier.max;
    await tester.pumpWidget(
      localizedApp(
        locale: const Locale('en'),
        theme: studafyTheme(),
        home: PracticePage(
          key: const ValueKey('max'),
          study: study,
          initialKind: StudySetKind.quiz,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Included with Studafy Max'), findsNothing);
    expect(find.byType(CheckboxListTile), findsOne);
    final make = find.widgetWithText(FilledButton, 'Make a quiz');
    expect(tester.widget<FilledButton>(make).onPressed, isNull);
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(make).onPressed, isNotNull);
  });

  testWidgets('joining a class later keeps the notebook and adds classes', (
    tester,
  ) async {
    final study = _Study();
    await study.addPersonalNote(title: 'Cells', body: 'Cells are units.');
    final settings = InMemoryDeviceSettings({
      DeviceSettingKeys.studentClassStepDone('user-indep'): '1',
    });
    await tester.pumpWidget(_shell(study: study, settings: settings));
    await tester.pumpAndSettle();
    expect(find.byType(StudafyNavDestination), findsNWidgets(3));

    // A class link joined anywhere in the app: the membership arrives.
    const membership = SchoolMembership(
      id: 'membership-1',
      schoolId: 'school-1',
      schoolName: 'Cedar Grove',
      role: StudafyRole.student,
      active: true,
    );
    ActiveContextController.instance.hydrate(
      authenticatedProfile: const UserProfile(
        id: 'user-indep',
        displayName: 'Lina Haddad',
        email: 'lina@example.test',
        memberships: [membership],
      ),
      activeMembership: membership,
    );
    await tester.pumpAndSettle();

    expect(find.text('Lessons'), findsWidgets);
    expect(find.text('Work'), findsWidgets);
    // The Notebook is still there, from Today, with the same notes.
    await tester.tap(find.text('Notebook').first);
    await tester.pumpAndSettle();
    expect(find.text('Cells'), findsOne);
  });

  testWidgets(
    'restore purchases is in the profile, for a student in no class',
    (tester) async {
      final plans = _Plans();
      final actions = StudentStudyActions(study: _Study(), studyPlans: plans);
      final entry = actions.subscription();
      expect(entry.restorePurchases, isNotNull);
      await entry.restorePurchases!();
      expect(plans.restores, 1);

      final settings = InMemoryDeviceSettings({
        DeviceSettingKeys.studentClassStepDone('user-indep'): '1',
      });
      await tester.pumpWidget(
        _shell(study: _Study(), settings: settings, plans: plans),
      );
      await tester.pumpAndSettle();
      // The profile button carries the Subscription row, with Restore; the
      // row itself is covered in account_hub_test.dart.
      final button = tester.widget<AccountButton>(
        find.byType(AccountButton).first,
      );
      expect(button.subscription, isNotNull);
      expect(button.subscription!.restorePurchases, isNotNull);
    },
  );
}
