import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:studafy/app/app_bootstrap.dart';
import 'package:studafy/core/device_settings.dart';
import 'package:studafy/core/runtime_environment.dart';
import 'package:studafy/core/studafy_design.dart';
import 'package:studafy/core/studafy_domain.dart';
import 'package:studafy/data/backend.dart';
import 'package:studafy/features/session/presentation/role_page.dart';
import 'package:studafy/main.dart';

/// Store screenshots (launch plan A4): the real app, signed in as each role
/// of the synthetic school that `scripts/store/seed-store-school.ts` seeds,
/// against a local API on a throwaway Supabase stack.
///
/// The app only walks to each screen. The pictures are taken from outside by
/// `scripts/store/capture-ios.sh`, with `xcrun simctl io screenshot`, so they
/// include the (overridden) status bar: when a screen is ready the test
/// prints `STORE_SHOT <name>` and waits until the script answers by creating
/// `<STORE_SHOT_DIR>/<name>.done`, or a few seconds if it cannot see that
/// directory. Run it through the script, not by hand.
const _locale = String.fromEnvironment('STORE_LOCALE', defaultValue: 'en');
const _password = String.fromEnvironment('STORE_PASSWORD');
const _prefix = String.fromEnvironment('STORE_PREFIX', defaultValue: 'store');
const _shotDir = String.fromEnvironment('STORE_SHOT_DIR');
const _only = String.fromEnvironment('STORE_ONLY');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('store screenshots ($_locale)', (tester) async {
    final policy = RuntimePolicy.fromEnvironment();
    StudafyRuntime.initialize(policy);
    final dependencies = await AppBootstrap.initialize(policy);
    await dependencies.locale.setLocale(const Locale(_locale));
    final shots = _Shots(tester);

    for (final role in [UserRole.teacher, UserRole.student, UserRole.parent]) {
      if (_only.isNotEmpty && _only != role.name) continue;
      await tester.pumpWidget(const SizedBox.shrink());
      ActiveContextController.instance.signOut();
      if (StudafyBackend.client.auth.currentSession != null) {
        await StudafyBackend.client.auth.signOut();
      }
      final who = switch (role) {
        UserRole.teacher => 'teacher',
        UserRole.student => 'student',
        UserRole.parent => 'parent',
      };
      await StudafyBackend.client.auth.signInWithPassword(
        email: '$_prefix.$_locale.$who@synthetic.studafy.test',
        password: _password,
      );
      // As if this device had opened the role before: straight back in.
      await dependencies.deviceSettings.write(DeviceSettingKeys.introSeen, '1');
      await dependencies.deviceSettings.write(
        DeviceSettingKeys.lastRole,
        role.name,
      );
      await tester.pumpWidget(
        StudafyApp(runtimePolicy: policy, dependencies: dependencies),
      );
      await shots.waitFor(find.byType(StudafyNavigationBar));
      await shots.settle();
      switch (role) {
        case UserRole.teacher:
          await _teacher(shots);
        case UserRole.student:
          await _student(shots);
        case UserRole.parent:
          await _parent(shots);
      }
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

/// What the seed wrote (scripts/store/store-content.ts) and the app's own
/// labels, in each language, so the walk can tap them.
final _words = {
  'en': {
    'maths': 'Mathematics',
    'paperTest': 'Unit 2 test: fractions and decimals',
    'exam': 'Unit 3 quiz: linear equations',
    'teacher': 'Hannah Clarke',
    'parent': 'Rania Haddad',
    'grades': 'Grades',
    'assessments': 'Assessments',
    'start': 'Start',
    'notebook': 'Notebook',
    'student': 'Omar Haddad',
  },
  'ar': {
    'maths': 'الرياضيات',
    'paperTest': 'اختبار الوحدة الثانية: الكسور والأعداد العشرية',
    'exam': 'اختبار الوحدة الثالثة: المعادلات الخطية',
    'teacher': 'هبة الخطيب',
    'parent': 'رنا حداد',
    'grades': 'الدرجات',
    'assessments': 'التقييمات',
    'start': 'ابدأ',
    'notebook': 'الدفتر',
    'student': 'عمر حداد',
  },
}[_locale]!;

/// Content a person typed is wrapped (direction isolates) by
/// `UserContentText`, so it is matched inside rich text, not exactly.
Finder _find(String key) =>
    find.textContaining(_words[key]!, findRichText: true);

Future<void> _teacher(_Shots shots) async {
  await shots.take('teacher-1-today');
  await shots.tab(1);
  await shots.take('teacher-2-classes');
  await shots.tab(2);
  await shots.take('teacher-3-lessons');
  await shots.tab(3);
  await shots.tap(_find('maths'));
  await shots.tap(_find('paperTest'));
  await shots.take('teacher-4-grade-sheet');
  await shots.back();
  await shots.tap(_find('exam'));
  await shots.take('teacher-5-online-exam');
  await shots.back();
  await shots.tab(4);
  await shots.tap(_find('parent'));
  await shots.take('teacher-6-messages');
  await shots.back();
}

Future<void> _student(_Shots shots) async {
  await shots.take('student-1-today');
  await shots.tab(1);
  await shots.tap(_find('maths'));
  // The class's own notebook, free; its Lessons side carries the AI study
  // tools, which may be off at launch (B1).
  await shots.tap(find.text(_words['notebook']!));
  await shots.take('student-2-notebook');
  await shots.back();
  await shots.tab(2);
  await shots.take('student-3-homework');
  await shots.tap(find.text(_words['grades']!));
  await shots.take('student-4-grades');
  await shots.tap(find.text(_words['assessments']!));
  await shots.tap(_find('exam'));
  // Starting opens the questions (and uses the one attempt: re-seed before
  // the next run).
  await shots.tap(find.text(_words['start']!));
  await shots.take('student-5-exam');
}

Future<void> _parent(_Shots shots) async {
  await shots.take('parent-1-today');
  await shots.tap(_find('student'));
  await shots.take('parent-2-progress');
  await shots.back();
  await shots.tab(shots.tabCount - 2);
  await shots.take('parent-3-announcements');
  await shots.tab(shots.tabCount - 1);
  await shots.tap(_find('teacher'));
  await shots.take('parent-4-messages');
  await shots.back();
}

class _Shots {
  _Shots(this.tester);

  final WidgetTester tester;

  int get tabCount => find.byType(StudafyNavDestination).evaluate().length;

  Future<void> tab(int index) async {
    await tester.tap(find.byType(StudafyNavDestination).at(index));
    await settle();
  }

  /// Closes the screen on top, whatever its back button looks like.
  Future<void> back() async {
    // The app pushes its screens on the root navigator.
    final navigator = tester.state<NavigatorState>(
      find.byType(Navigator).first,
    );
    await navigator.maybePop();
    await settle();
  }

  Future<void> tap(Finder finder) async {
    await waitFor(finder);
    await tester.ensureVisible(finder.first);
    // The scroll lands on the next frame; tap after it.
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(finder.first);
    await settle();
  }

  /// Real requests take real time: pump until [finder] shows, or give up.
  Future<void> waitFor(Finder finder, {int seconds = 20}) async {
    final clock = Stopwatch()..start();
    while (finder.evaluate().isEmpty && clock.elapsed.inSeconds < seconds) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    // A picture of what was on screen instead, to see why.
    if (finder.evaluate().isEmpty) await take('missing');
    expect(finder, findsWidgets);
  }

  /// Lets requests finish and animations end, without failing on a spinner
  /// that never stops.
  Future<void> settle() async {
    for (var i = 0; i < 15; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    try {
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 5),
      );
    } on FlutterError {
      // Something animates for ever; the frame is still ready.
    }
  }

  Future<void> take(String name) async {
    await settle();
    final shot = '$name-$_locale';
    final done = File('$_shotDir/$shot.done');
    // ignore: avoid_print
    print('STORE_SHOT $shot');
    // When the app cannot see the directory, the script has had plenty of
    // time after a few seconds.
    final visible = _shotDir.isNotEmpty && Directory(_shotDir).existsSync();
    final clock = Stopwatch()..start();
    while (clock.elapsed.inSeconds < (visible ? 30 : 5)) {
      await tester.pump(const Duration(milliseconds: 250));
      if (visible && done.existsSync()) return;
    }
  }
}
