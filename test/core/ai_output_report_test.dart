import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/core/ai_output_report.dart';

import '../support/localized_app.dart';

/// Reporting an AI answer (DL-076): the store policies ask for a way to flag
/// offensive AI output from inside the app. The sheet asks why, sends the
/// report with the AI's text, and says whether it went.
void main() {
  Widget host(
    AiOutputReporter? reporter, {
    Locale? locale,
    String excerpt = 'The AI said this.',
  }) => localizedApp(
    locale: locale,
    scopes: reporter == null
        ? null
        : (child) => AiOutputReportScope(reporter: reporter, child: child),
    home: Scaffold(
      appBar: AppBar(
        actions: [
          AiOutputReportButton(
            feature: AiOutputFeature.quiz,
            excerpt: () => excerpt,
          ),
        ],
      ),
      body: const SizedBox.shrink(),
    ),
  );

  Future<void> openSheet(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Report this AI answer'));
    await tester.pumpAndSettle();
  }

  Finder send() => find.widgetWithText(FilledButton, 'Send');

  testWidgets('a reason is chosen before anything can be sent', (tester) async {
    final reports = _Reports();
    await tester.pumpWidget(host(reports));
    await openSheet(tester);

    expect(find.text('Report this AI answer'), findsOne);
    for (final reason in [
      'Offensive or inappropriate',
      'Harmful or unsafe',
      'Wrong or misleading',
      'Something else',
    ]) {
      expect(find.text(reason), findsOne);
    }
    expect(tester.widget<FilledButton>(send()).onPressed, isNull);
    await tester.tap(send());
    await tester.pumpAndSettle();
    expect(reports.sent, isEmpty);
  });

  testWidgets('sends the reason, details and the AI text, then thanks', (
    tester,
  ) async {
    final reports = _Reports();
    await tester.pumpWidget(host(reports));
    await openSheet(tester);

    await tester.tap(find.text('Offensive or inappropriate'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), '  It was rude.  ');
    await tester.tap(send());
    await tester.pumpAndSettle();

    final report = reports.sent.single;
    expect(report.feature, AiOutputFeature.quiz);
    expect(report.reason, AiOutputReportReason.offensive);
    expect(report.details, 'It was rude.');
    expect(report.excerpt, 'The AI said this.');
    expect(find.text('Report this AI answer'), findsNothing);
    expect(find.text('Thanks - we will review it.'), findsOne);
  });

  testWidgets('no details is sent as none', (tester) async {
    final reports = _Reports();
    await tester.pumpWidget(host(reports));
    await openSheet(tester);
    await tester.tap(find.text('Something else'));
    await tester.pump();
    await tester.tap(send());
    await tester.pumpAndSettle();
    expect(reports.sent.single.reason, AiOutputReportReason.other);
    expect(reports.sent.single.details, isNull);
  });

  testWidgets('a failed send says so and Try again sends the same report', (
    tester,
  ) async {
    final reports = _Reports(failures: 1);
    await tester.pumpWidget(host(reports));
    await openSheet(tester);
    await tester.tap(find.text('Harmful or unsafe'));
    await tester.pump();
    await tester.tap(send());
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Your report was not sent. Check your connection and try again.',
      ),
      findsOne,
    );
    expect(reports.sent, isEmpty);

    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(reports.sent.single.reason, AiOutputReportReason.harmful);
    expect(find.text('Thanks - we will review it.'), findsOne);
    // The same key both times: a report that did arrive is not filed twice.
    expect(reports.keys, hasLength(2));
    expect(reports.keys.toSet(), hasLength(1));
  });

  testWidgets('without a reporter there is no Report action', (tester) async {
    await tester.pumpWidget(host(null));
    expect(find.byTooltip('Report this AI answer'), findsNothing);
    expect(find.byIcon(Icons.outlined_flag_rounded), findsNothing);
  });

  testWidgets('the sheet is in Arabic, right to left', (tester) async {
    await tester.pumpWidget(host(_Reports(), locale: const Locale('ar')));
    await tester.tap(find.byIcon(Icons.outlined_flag_rounded));
    await tester.pumpAndSettle();
    final title = find.text('الإبلاغ عن إجابة الذكاء الاصطناعي هذه');
    expect(title, findsOne);
    expect(directionOf(tester, title), TextDirection.rtl);
    expect(find.text('مسيء أو غير لائق'), findsOne);
  });

  test('a long answer is cut to 4,000 characters, never mid-character', () {
    expect(aiOutputExcerpt('  short  '), 'short');
    expect(aiOutputExcerpt('a' * 5000), hasLength(4000));
    // An emoji (two UTF-16 units) straddling the limit is left out whole.
    final straddling = '${'a' * 3999}😀tail';
    expect(aiOutputExcerpt(straddling), 'a' * 3999);
  });
}

class _Reports implements AiOutputReporter {
  _Reports({this.failures = 0});

  int failures;
  final List<AiOutputReport> sent = [];
  final List<String> keys = [];

  @override
  Future<void> report(
    AiOutputReport report, {
    required String idempotencyKey,
  }) async {
    keys.add(idempotencyKey);
    if (failures > 0) {
      failures--;
      throw StateError('offline');
    }
    sent.add(report);
  }
}
