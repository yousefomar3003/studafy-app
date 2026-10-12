import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:studafy/app/app_bootstrap.dart';
import 'package:studafy/core/runtime_environment.dart';
import 'package:studafy/core/studafy_design.dart';
import 'package:studafy/core/studafy_domain.dart';
import 'package:studafy/features/session/presentation/login_page.dart';
import 'package:studafy/features/session/presentation/provider_marks.dart';
import 'package:studafy/features/session/presentation/role_page.dart';
import 'package:studafy/main.dart';

// Exercises native SQLite, startup, consent, and every role's navigation on
// an iOS simulator or Android emulator (CI: .github/workflows/device-tests.yml).
// Synthetic data only; OAuth is verified separately.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('all role tabs render in English and Arabic', (tester) async {
    // Android screenshots need the surface turned into an image first.
    if (Platform.isAndroid) await binding.convertFlutterSurfaceToImage();
    const policy = RuntimePolicy(StudafyEnvironment.synthetic);
    StudafyRuntime.initialize(policy);
    final dependencies = await AppBootstrap.initialize(policy);

    for (final language in ['en', 'ar']) {
      await dependencies.locale.setLocale(Locale(language));
      for (final role in UserRole.values) {
        await tester.pumpWidget(const SizedBox.shrink());
        ActiveContextController.instance.signOut();
        await tester.pumpWidget(
          StudafyApp(runtimePolicy: policy, dependencies: dependencies),
        );
        final startup = Stopwatch()..start();
        while (find.byType(RolePage).evaluate().isEmpty &&
            startup.elapsed < const Duration(seconds: 10)) {
          await tester.pump(const Duration(milliseconds: 200));
        }
        await tester.pumpAndSettle();
        expect(find.byType(RolePage), findsOneWidget);
        // The welcome slides show once per device; skip them if they are up.
        final skip = find.text(language == 'ar' ? 'تخطي' : 'Skip');
        if (skip.evaluate().isNotEmpty) {
          await tester.tap(skip);
          await tester.pumpAndSettle();
        }
        final tile = find.byWidgetPredicate(
          (w) => w is RoleTile && w.role == role,
        );
        await tester.ensureVisible(tile);
        await tester.tap(tile);
        await tester.pumpAndSettle();
        final next = find.byType(FilledButton);
        await tester.ensureVisible(next);
        await tester.tap(next);
        await tester.pumpAndSettle();
        expect(find.byType(LoginPage), findsOneWidget);
        final consent = find.byType(Checkbox);
        await tester.ensureVisible(consent);
        await tester.tap(consent);
        await tester.pump();
        final google = find.byWidgetPredicate(
          (w) => w is SocialButton && w.logo is GoogleMark,
        );
        await tester.ensureVisible(google);
        await tester.tap(google);
        await tester.pumpAndSettle();
        expect(find.byType(LoginPage), findsNothing);

        // Teachers have five tabs; students and parents four.
        final tabs = role == UserRole.teacher ? 5 : 4;
        final destinations = find.byType(StudafyNavDestination);
        expect(destinations, findsNWidgets(tabs));
        for (var tab = 0; tab < tabs; tab++) {
          await tester.tap(destinations.at(tab));
          await tester.pump(const Duration(milliseconds: 300));
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<StudafyNavigationBar>(find.byType(StudafyNavigationBar))
                .selectedIndex,
            tab,
          );
          expect(
            tester.takeException(),
            isNull,
            reason: '${role.name}/$language/tab-$tab',
          );
          await binding.takeScreenshot('${role.name}-$language-$tab');
        }
      }
    }
    await tester.pumpWidget(const SizedBox.shrink());
    ActiveContextController.instance.signOut();
    await dependencies.cacheBinder.settled;
    dependencies.cacheBinder.dispose();
    dependencies.locale.dispose();
    await dependencies.session.dispose();
  });
}
