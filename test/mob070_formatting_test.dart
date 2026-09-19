import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/core/studafy_formatting.dart';
import 'package:studafy/core/user_content_text.dart';

import 'support/localized_app.dart';

/// MOB-070 (ADR-0028): how numbers, dates and user-written text behave in
/// each language.
void main() {
  /// Renders [build] under [locale] and hands back what it produced.
  Future<T> underLocale<T>(
    WidgetTester tester,
    Locale locale,
    T Function(BuildContext context) build,
  ) async {
    late T value;
    await tester.pumpWidget(
      localizedApp(
        locale: locale,
        home: Builder(
          builder: (context) {
            value = build(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    return value;
  }

  group('numbers keep Western digits in Arabic', () {
    // A product decision (ADR-0028), not a technical limit: identifiers and
    // grades must stay copy-pasteable and match the ASCII copy the server
    // sends by email and push. If a future intl switches Arabic to Eastern
    // Arabic-Indic numerals by default, this fails rather than the app
    // silently changing.
    testWidgets('a count', (tester) async {
      final arabic = await underLocale(
        tester,
        const Locale('ar'),
        (context) => studafyNumber(context, 1234),
      );

      expect(arabic, contains('1'));
      expect(arabic, isNot(contains('١')));
    });

    testWidgets('and the English rendering agrees', (tester) async {
      final english = await underLocale(
        tester,
        const Locale('en'),
        (context) => studafyNumber(context, 1234),
      );
      final arabic = await underLocale(
        tester,
        const Locale('ar'),
        (context) => studafyNumber(context, 1234),
      );

      expect(arabic, english);
    });
  });

  group('dates carry Arabic month and day names', () {
    testWidgets('a full date', (tester) async {
      final arabic = await underLocale(
        tester,
        const Locale('ar'),
        (context) => studafyDate(context, DateTime(2026, 9, 17)),
      );

      // Digits stay Western while the month name is Arabic.
      expect(arabic, contains('2026'));
      expect(arabic, contains('17'));
      expect(RegExp(r'[؀-ۿ]').hasMatch(arabic), isTrue);
    });

    testWidgets('weekday names are not left in English', (tester) async {
      final arabic = await underLocale(
        tester,
        const Locale('ar'),
        studafyWeekdayNames,
      );

      expect(arabic, hasLength(7));
      expect(arabic.first, isNot('Mon'));
      expect(RegExp(r'[؀-ۿ]').hasMatch(arabic.first), isTrue);
    });
  });

  group('user content is never translated and keeps its own direction', () {
    testWidgets('an Arabic message inside an English screen reads RTL', (
      tester,
    ) async {
      const body = 'السلام عليكم، هل الواجب مطلوب غدًا؟';
      await tester.pumpWidget(
        localizedApp(
          locale: const Locale('en'),
          home: const Scaffold(body: UserContentText(body)),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        directionOf(tester, find.byType(Scaffold)),
        TextDirection.ltr,
        reason: 'the interface is still English',
      );
      expect(
        Directionality.of(tester.element(find.text(body))),
        TextDirection.rtl,
        reason: 'but the message the parent wrote is Arabic',
      );
    });

    testWidgets('an English message inside an Arabic screen reads LTR', (
      tester,
    ) async {
      const body = 'Homework is due tomorrow.';
      await tester.pumpWidget(
        localizedApp(
          locale: const Locale('ar'),
          home: const Scaffold(body: UserContentText(body)),
        ),
      );
      await tester.pumpAndSettle();

      expect(directionOf(tester, find.byType(Scaffold)), TextDirection.rtl);
      expect(
        Directionality.of(tester.element(find.text(body))),
        TextDirection.ltr,
      );
    });

    testWidgets('the text itself is shown exactly as written', (tester) async {
      const body = 'الرياضيات 101';
      await tester.pumpWidget(
        localizedApp(
          locale: const Locale('en'),
          home: const Scaffold(body: UserContentText(body)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(body), findsOneWidget);
    });

    test('direction-neutral text defers to the interface', () {
      // An ID or a bare number carries no signal, so it must not force a
      // direction of its own.
      expect(UserContentText.directionOf('STU-42'), TextDirection.ltr);
      expect(UserContentText.directionOf('42'), isNull);
      expect(UserContentText.directionOf('   '), isNull);
    });
  });
}
