import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:studafy/app/app_bootstrap.dart';
import 'package:studafy/core/runtime_environment.dart';
import 'package:studafy/core/studafy_domain.dart';
import 'package:studafy/features/session/presentation/login_page.dart';
import 'package:studafy/features/session/presentation/role_page.dart';
import 'package:studafy/main.dart';

// Exercises native SQLite, startup, consent, and every role's navigation on
// an actual simulator. Synthetic data only; OAuth is verified separately.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('all role tabs render in English and Arabic on iPhone', (
    tester,
  ) async {
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
          (w) => w is SocialButton && w.mark == 'G',
        );
        await tester.ensureVisible(google);
        await tester.tap(google);
        await tester.pumpAndSettle();
        expect(find.byType(LoginPage), findsNothing);

        final destinations = find.byType(NavigationDestination);
        expect(destinations, findsNWidgets(role == UserRole.parent ? 4 : 5));
        for (var tab = 0; tab < (role == UserRole.parent ? 4 : 5); tab++) {
          await tester.tap(destinations.at(tab));
          await tester.pump(const Duration(milliseconds: 300));
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<NavigationBar>(find.byType(NavigationBar))
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
