import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/app/parent_shell.dart';
import 'package:studafy/app/studafy_theme.dart';
import 'package:studafy/core/runtime_environment.dart';
import 'package:studafy/core/studafy_design.dart';
import 'package:studafy/core/studafy_domain.dart';
import 'package:studafy/core/telemetry.dart';
import 'package:studafy/features/academic/data/preview_academic_repository.dart';
import 'package:studafy/features/family/application/family_interactor.dart';
import 'package:studafy/features/family/domain/family.dart';
import 'package:studafy/features/family/presentation/family_scope.dart';
import 'package:studafy/features/messaging/application/messaging_interactor.dart';
import 'package:studafy/features/messaging/domain/messaging.dart';
import 'package:studafy/features/messaging/presentation/messaging_scope.dart';

import '../support/accessibility.dart';
import '../support/localized_app.dart';
import '../support/system_back.dart';

/// Every parent tab, with two children at two schools, on a small phone, a
/// large phone with large text, in Arabic and on a tablet: nothing may
/// overflow, and every destination stays reachable.
void main() {
  tearDown(() => ActiveContextController.instance.signOut());

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
    testWidgets('every parent tab lays out: $name', (tester) async {
      StudafyRuntime.initialize(
        const RuntimePolicy(StudafyEnvironment.synthetic),
      );
      // Accessibility on every tab (launch plan 7.1): tap targets, labels,
      // contrast.
      final semantics = tester.ensureSemantics();
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
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
      final family = _TwoChildren();

      await tester.pumpWidget(
        localizedApp(
          locale: locale,
          theme: studafyTheme(),
          scopes: (child) => MessagingScope(
            interactor: MessagingInteractor(
              messaging: _Inbox(),
              safety: _NoSafety(),
              telemetry: const NoopTelemetry(),
            ),
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
      expect(tester.takeException(), isNull);

      final tabs = find.byType(StudafyNavDestination);
      final count = tabs.evaluate().length;
      // Today, Learning, Announcements, Messages.
      expect(count, 4);
      await expectAccessible(tester);
      for (var tab = 1; tab < count; tab++) {
        await tester.tap(tabs.at(tab));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'tab $tab');
        await expectAccessible(tester);
      }
      // The inbox is the last tab: it knows who is signed in.
      if (locale.languageCode == 'en') {
        expect(find.text('Choose a school to see messages.'), findsNothing);
      }
      semantics.dispose();
    });
  }

  testWidgets('the Android back button goes to Today, then leaves', (
    tester,
  ) async {
    StudafyRuntime.initialize(
      const RuntimePolicy(StudafyEnvironment.synthetic),
    );
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
    final family = _TwoChildren();
    final exits = AppExits(tester);
    await tester.pumpWidget(
      localizedApp(
        locale: const Locale('en'),
        theme: studafyTheme(),
        scopes: (child) => MessagingScope(
          interactor: MessagingInteractor(
            messaging: _Inbox(),
            safety: _NoSafety(),
            telemetry: const NoopTelemetry(),
          ),
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
    int selected() => tester
        .widget<StudafyNavigationBar>(find.byType(StudafyNavigationBar))
        .selectedIndex;

    // Learning, where the review found back closing the app.
    await tester.tap(find.byType(StudafyNavDestination).at(1));
    await tester.pumpAndSettle();
    expect(selected(), 1);

    await systemBack(tester);
    expect(selected(), 0);
    expect(exits.count, 0);

    await systemBack(tester);
    expect(exits.count, 1);
  });
}

class _TwoChildren implements FamilyRepository, PurchaseApprovalRepository {
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
  @override
  Future<bool> messagingEnabled(String schoolId) async => true;
  @override
  Future<List<Conversation>> conversations() async => const [];
  @override
  Future<void> acknowledgeDelivery() async {}
  @override
  Future<List<Announcement>> announcements({
    String? schoolId,
    String? classroomId,
  }) async => [
    Announcement(
      id: 'a-$schoolId',
      title: 'A long announcement title that wraps across more than one line',
      body: 'Body text for the announcement.',
      important: schoolId == 'noor',
      createdAt: DateTime(2026, 10, 1),
    ),
  ];
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _NoSafety implements SafetyRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
