import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/core/device_settings.dart';
import 'package:studafy/core/ids.dart';
import 'package:studafy/core/runtime_environment.dart';
import 'package:studafy/core/studafy_domain.dart';
import 'package:studafy/core/telemetry.dart';
import 'package:studafy/features/session/application/session_interactor.dart';
import 'package:studafy/features/session/domain/session_repository.dart';
import 'package:studafy/features/session/presentation/login_page.dart';
import 'package:studafy/features/session/presentation/provider_marks.dart';
import 'package:studafy/features/session/presentation/role_page.dart';

import '../../support/accessibility.dart';
import '../../support/localized_app.dart';
import '../../support/session_repository_fake.dart';
import '../../support/system_back.dart';

/// The screens before sign-in: the welcome slides, the role choice and the
/// sign-in buttons.
void main() {
  tearDown(() => ActiveContextController.instance.signOut());

  void tall(WidgetTester tester) {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  group('welcome slides', () {
    testWidgets('a first launch shows them, and Skip goes to the roles', (
      tester,
    ) async {
      tall(tester);
      final settings = InMemoryDeviceSettings();
      await tester.pumpWidget(
        localizedApp(
          home: RolePage(session: _session(), settings: settings),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Your whole school day in one place'), findsOne);
      expect(find.text('How will you use Studafy?'), findsNothing);
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      expect(find.text('How will you use Studafy?'), findsOne);
      expect(settings.snapshot[DeviceSettingKeys.introSeen], '1');
    });

    testWidgets('there are only three, and the last one gets started', (
      tester,
    ) async {
      tall(tester);
      await tester.pumpWidget(
        localizedApp(
          home: RolePage(
            session: _session(),
            settings: InMemoryDeviceSettings(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Every mark counts, on paper or online'), findsOne);
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Parents see what matters'), findsOne);
      // Skip is there on every slide, never only at the start.
      expect(find.text('Skip'), findsOne);
      await tester.tap(find.text('Get started'));
      await tester.pumpAndSettle();
      expect(find.text('How will you use Studafy?'), findsOne);
    });

    testWidgets('once seen, they are not shown again but can be replayed', (
      tester,
    ) async {
      tall(tester);
      await tester.pumpWidget(
        localizedApp(
          home: RolePage(
            session: _session(),
            settings: InMemoryDeviceSettings({
              DeviceSettingKeys.introSeen: '1',
            }),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('How will you use Studafy?'), findsOne);

      await tester.tap(find.text('What is Studafy?'));
      await tester.pumpAndSettle();
      expect(find.text('Your whole school day in one place'), findsOne);
    });

    testWidgets('back goes to the slide before, and leaves from the first', (
      tester,
    ) async {
      tall(tester);
      final exits = AppExits(tester);
      await tester.pumpWidget(
        localizedApp(
          home: RolePage(
            session: _session(),
            settings: InMemoryDeviceSettings(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Every mark counts, on paper or online'), findsOne);

      await systemBack(tester);
      expect(find.text('Your whole school day in one place'), findsOne);
      expect(exits.count, 0);

      // A first launch has nothing behind the first slide.
      await systemBack(tester);
      expect(exits.count, 1);
    });

    testWidgets('replayed, back from the first slide returns to the roles', (
      tester,
    ) async {
      tall(tester);
      final exits = AppExits(tester);
      await tester.pumpWidget(
        localizedApp(
          home: RolePage(
            session: _session(),
            settings: InMemoryDeviceSettings({
              DeviceSettingKeys.introSeen: '1',
            }),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('What is Studafy?'));
      await tester.pumpAndSettle();

      await systemBack(tester);

      expect(find.text('How will you use Studafy?'), findsOne);
      expect(exits.count, 0);
    });

    testWidgets('read in Arabic, right to left', (tester) async {
      tall(tester);
      await tester.pumpWidget(
        localizedApp(
          locale: const Locale('ar'),
          home: RolePage(
            session: _session(),
            settings: InMemoryDeviceSettings(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('يومك الدراسي كله في مكان واحد'), findsOne);
      expect(find.text('تخطي'), findsOne);
      expect(find.text('Skip'), findsNothing);
    });
  });

  group('sign-in', () {
    testWidgets('each provider shows its real logo', (tester) async {
      tall(tester);
      await tester.pumpWidget(
        localizedApp(
          home: LoginPage(role: UserRole.teacher, session: _session()),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.widgetWithText(SocialButton, 'Continue with Google'),
          matching: find.byType(GoogleMark),
        ),
        findsOne,
      );
      expect(
        find.descendant(
          of: find.widgetWithText(SocialButton, 'Continue with Microsoft'),
          matching: find.byType(MicrosoftMark),
        ),
        findsOne,
      );
      // No letters standing in for the logos any more.
      expect(find.text('G'), findsNothing);
      expect(find.text('M'), findsNothing);
    });

    testWidgets('tapping a provider before agreeing says what is missing', (
      tester,
    ) async {
      tall(tester);
      await tester.pumpWidget(
        localizedApp(
          home: LoginPage(role: UserRole.student, session: _session()),
        ),
      );
      await tester.pumpAndSettle();

      final reminder = find.text('Please accept before signing in.');
      Color? colour() => tester.widget<Text>(reminder).style?.color;
      final before = colour();
      await tester.tap(find.text('Continue with Google'));
      await tester.pump();
      expect(colour(), isNot(before));
      expect(find.byType(LoginPage), findsOne);
    });
  });

  // Launch plan 7.1: the first screens anyone sees pass the accessibility
  // checks (tap targets, labels, contrast), in both languages.
  group('accessibility', () {
    for (final locale in const [Locale('en'), Locale('ar')]) {
      testWidgets('welcome, roles and sign-in: ${locale.languageCode}', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        tall(tester);
        await tester.pumpWidget(
          localizedApp(
            locale: locale,
            home: RolePage(
              session: _session(),
              settings: InMemoryDeviceSettings(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await expectAccessible(tester);

        await tester.pumpWidget(
          localizedApp(
            locale: locale,
            home: RolePage(
              session: _session(),
              settings: InMemoryDeviceSettings({
                DeviceSettingKeys.introSeen: '1',
              }),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await expectAccessible(tester);
        for (final role in UserRole.values) {
          await tester.pumpWidget(
            localizedApp(
              locale: locale,
              home: LoginPage(role: role, session: _session()),
            ),
          );
          await tester.pumpAndSettle();
          await expectAccessible(tester);
        }
        semantics.dispose();
      });
    }
  });
}

SessionInteractor _session() => SessionInteractor(
  repository: _Repository(),
  context: ActiveContextController.instance,
  telemetry: const NoopTelemetry(),
  runtimePolicy: const RuntimePolicy(StudafyEnvironment.synthetic),
);

class _Repository extends FakeSessionRepositoryBase {
  @override
  bool get hasCurrentSession => false;

  @override
  Stream<bool> get sessionChanges => const Stream<bool>.empty();

  @override
  Future<void> signInWithProvider(LoginProvider provider) async {}

  @override
  Future<UserProfile?> currentProfile() async => null;

  @override
  Future<TermInfo?> activeTermForSchool(SchoolId school) async => null;

  @override
  Future<void> recordTermsConsent({required String locale}) async {}
}
