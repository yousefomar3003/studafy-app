import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studafy/app/app_dependencies.dart';
import 'package:studafy/app/studafy_theme.dart';
import 'package:studafy/app/teacher_shell.dart';
import 'package:studafy/core/runtime_environment.dart';
import 'package:studafy/core/studafy_design.dart';
import 'package:studafy/core/studafy_domain.dart';

import '../support/accessibility.dart';
import '../support/app_scopes.dart';
import '../support/localized_app.dart';

/// Every teacher tab, on the synthetic build's preview data: on a small
/// phone, with large and the largest text, in Arabic and on a tablet,
/// nothing may overflow, and every tab must pass the accessibility checks
/// (tap targets, labels, contrast; launch plan 7.1).
void main() {
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

  final cases = <(String, Size, double, Locale)>[
    ('small phone', const Size(320, 640), 1, const Locale('en')),
    ('phone, large text', const Size(390, 844), 1.6, const Locale('en')),
    ('phone, Arabic', const Size(390, 844), 1, const Locale('ar')),
    ('tablet', const Size(834, 1112), 1, const Locale('en')),
    ('phone, 2x text', const Size(390, 844), 2, const Locale('en')),
    ('phone, Arabic, 2x text', const Size(390, 844), 2, const Locale('ar')),
  ];

  for (final (name, size, scale, locale) in cases) {
    testWidgets('every teacher tab lays out: $name', (tester) async {
      final semantics = tester.ensureSemantics();
      const policy = RuntimePolicy(StudafyEnvironment.synthetic);
      StudafyRuntime.initialize(policy);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final deps = AppDependencies.forPolicy(policy);

      await tester.pumpWidget(
        localizedApp(
          locale: locale,
          theme: studafyTheme(),
          scopes: (child) => appScopes(deps, child),
          home: TeacherShell(dependencies: deps),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      final tabs = find.byType(StudafyNavDestination);
      final count = tabs.evaluate().length;
      // Today, Classes, Teaching, Gradebook, Inbox.
      expect(count, 5);
      await expectAccessible(tester);
      for (var tab = 1; tab < count; tab++) {
        await tester.tap(tabs.at(tab));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'tab $tab');
        await expectAccessible(tester);
      }
      semantics.dispose();
    });
  }
}
