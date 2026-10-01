import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/features/session/presentation/login_page.dart';

import '../../support/localized_app.dart';

/// The terms and privacy policy are read before signing in. They are long,
/// so on a small phone the sheet must scroll to the end, in both languages.
void main() {
  Future<void> open(
    WidgetTester tester,
    PolicyDocument document, {
    Locale? locale,
  }) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      localizedApp(
        locale: locale,
        home: Builder(
          builder: (c) => TextButton(
            onPressed: () => showPolicy(c, document),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('the whole privacy policy can be read on a small phone', (
    tester,
  ) async {
    await open(tester, PolicyDocument.privacy);
    expect(tester.takeException(), isNull);
    expect(find.textContaining('MARKS AND ATTENDANCE'), findsOneWidget);
    expect(find.textContaining('no school administrator'), findsOneWidget);
    expect(find.textContaining('Together AI'), findsOneWidget);
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -9000),
    );
    await tester.pumpAndSettle();
    expect(find.text('Close'), findsOneWidget);
  });

  testWidgets('the terms can be read, in Arabic too', (tester) async {
    await open(tester, PolicyDocument.terms, locale: const Locale('ar'));
    expect(tester.takeException(), isNull);
    expect(find.textContaining('لا يوجد مسؤول مدرسة'), findsOneWidget);
  });
}
