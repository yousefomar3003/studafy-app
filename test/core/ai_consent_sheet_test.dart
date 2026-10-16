import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/core/ai_consent.dart';
import 'package:studafy/core/ai_consent_sheet.dart';

import '../support/localized_app.dart';

/// The AI study tools switch and the notice behind it (ADR-0043).
void main() {
  Future<void> pumpSwitch(
    WidgetTester tester,
    _FakeConsent repository, {
    Locale locale = const Locale('en'),
    String? childId,
    String? childName,
  }) async {
    await tester.pumpWidget(
      localizedApp(
        locale: locale,
        home: Scaffold(
          body: ListView(
            children: [
              AiConsentSwitch(
                repository: repository,
                childId: childId,
                childName: childName,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder switchFor(String? childId) =>
      find.byKey(ValueKey('ai-consent-switch-${childId ?? 'self'}'));

  testWidgets('a parent, teacher or classless account sees no switch', (
    tester,
  ) async {
    for (final access in [AiAccess.notStudent, AiAccess.noClass]) {
      await pumpSwitch(tester, _FakeConsent(access));
      expect(switchFor(null), findsNothing);
    }
  });

  testWidgets('a server with no AI tools shows no switch, nor its group', (
    tester,
  ) async {
    for (final locale in const [Locale('en'), Locale('ar')]) {
      final repository = _FakeConsent(AiAccess.ok)..toolsEnabled = false;
      // A fresh switch each time: it reads the state once, when built.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        localizedApp(
          locale: locale,
          home: Scaffold(
            body: ListView(
              children: [
                AiConsentSwitch(
                  repository: repository,
                  wrap: (row) => Column(
                    children: [const Text('AI study tools group'), row],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(switchFor(null), findsNothing, reason: locale.languageCode);
      expect(find.text('AI study tools group'), findsNothing);

      repository.toolsEnabled = true;
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        localizedApp(
          locale: locale,
          home: Scaffold(
            body: ListView(
              children: [
                AiConsentSwitch(
                  repository: repository,
                  wrap: (row) => Column(
                    children: [const Text('AI study tools group'), row],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(switchFor(null), findsOneWidget, reason: locale.languageCode);
      expect(find.text('AI study tools group'), findsOneWidget);
    }
  });

  testWidgets('turning it on shows the notice; agreeing records it', (
    tester,
  ) async {
    final repository = _FakeConsent(AiAccess.consentRequired);
    await pumpSwitch(tester, repository);
    expect(tester.widget<Switch>(switchFor(null)).value, isFalse);

    await tester.tap(switchFor(null));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('ai-consent-notice')), findsOneWidget);
    expect(find.textContaining('[student]'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('ai-consent-agree')));
    await tester.pumpAndSettle();
    expect(repository.given, [('en', null)]);
    expect(tester.widget<Switch>(switchFor(null)).value, isTrue);
  });

  testWidgets('"Not now" records nothing', (tester) async {
    final repository = _FakeConsent(AiAccess.consentRequired);
    await pumpSwitch(tester, repository);
    await tester.tap(switchFor(null));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('ai-consent-not-now')));
    await tester.pumpAndSettle();
    expect(repository.given, isEmpty);
    expect(tester.widget<Switch>(switchFor(null)).value, isFalse);
  });

  testWidgets('turning it off asks first, then withdraws', (tester) async {
    final repository = _FakeConsent(AiAccess.ok);
    await pumpSwitch(tester, repository);
    await tester.tap(switchFor(null));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('ai-consent-withdraw')));
    await tester.pumpAndSettle();
    expect(repository.withdrawn, [null]);
    expect(tester.widget<Switch>(switchFor(null)).value, isFalse);
  });

  testWidgets('a child account cannot turn it on: a parent does', (
    tester,
  ) async {
    await pumpSwitch(tester, _FakeConsent(AiAccess.guardianConsentRequired));
    expect(tester.widget<Switch>(switchFor(null)).onChanged, isNull);
  });

  testWidgets('a parent agrees for a child, in Arabic, by the child id', (
    tester,
  ) async {
    final repository = _FakeConsent(AiAccess.guardianConsentRequired);
    await pumpSwitch(
      tester,
      repository,
      locale: const Locale('ar'),
      childId: 'child-1',
      childName: 'ليلى',
    );
    await tester.tap(switchFor('child-1'));
    await tester.pumpAndSettle();
    expect(find.textContaining('ليلى'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('ai-consent-agree')));
    await tester.pumpAndSettle();
    expect(repository.given, [('ar', 'child-1')]);
  });
}

class _FakeConsent implements AiConsentRepository {
  _FakeConsent(this.access);

  AiAccess access;
  bool toolsEnabled = true;
  final List<(String, String?)> given = [];
  final List<String?> withdrawn = [];

  AiConsentState get _state => AiConsentState(
    access: access,
    version: aiConsentVersion,
    givenAt: access == AiAccess.ok ? DateTime(2026, 10, 15) : null,
    toolsEnabled: toolsEnabled,
  );

  @override
  Future<AiConsentState> state({String? childId}) async => _state;

  @override
  Future<AiConsentState> give({required String locale, String? childId}) async {
    given.add((locale, childId));
    access = AiAccess.ok;
    return _state;
  }

  @override
  Future<AiConsentState> withdraw({String? childId}) async {
    withdrawn.add(childId);
    access = childId == null
        ? AiAccess.consentRequired
        : AiAccess.guardianConsentRequired;
    return _state;
  }
}
