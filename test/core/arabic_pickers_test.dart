import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/core/studafy_material_localizations.dart';

import '../support/localized_app.dart';

/// ADR-0028: the built-in Material pickers show 0-9 in Arabic, like every
/// date the app formats itself, and read the dates and times people type.
///
/// Each test opens a real picker under the app's localization delegates
/// (`localizedApp`, which mirrors lib/main.dart) and reads back everything it
/// drew: visible text, text field contents and screen-reader labels.
void main() {
  final arabicIndic = RegExp('[٠-٩۰-۹]');
  const arabic = Locale('ar');
  final initial = DateTime(2026, 10, 16);
  final first = DateTime(2020);
  final last = DateTime(2030, 12, 31);

  /// Every string the picker currently puts on screen or in semantics.
  List<String> drawnStrings(WidgetTester tester) => [
    for (final text in tester.widgetList<RichText>(find.byType(RichText)))
      text.text.toPlainText(),
    for (final field in tester.widgetList<EditableText>(
      find.byType(EditableText),
    ))
      field.controller.text,
    for (final node in tester.widgetList<Semantics>(find.byType(Semantics)))
      ?node.properties.label,
  ];

  void expectWesternDigitsOnly(WidgetTester tester) {
    final strings = drawnStrings(tester);
    final offending = strings.where(arabicIndic.hasMatch).toList();
    expect(strings, isNotEmpty);
    expect(
      offending,
      isEmpty,
      reason: 'Arabic-Indic digits drawn by the picker: $offending',
    );
  }

  /// Pumps a page with one button that runs [open], and taps it.
  Future<BuildContext> openFrom(
    WidgetTester tester,
    Future<void> Function(BuildContext context) open, {
    Locale locale = arabic,
    bool alwaysUse24HourFormat = false,
  }) async {
    late BuildContext pageContext;
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(alwaysUse24HourFormat: alwaysUse24HourFormat),
        child: localizedApp(
          locale: locale,
          home: Scaffold(
            body: Builder(
              builder: (context) {
                pageContext = context;
                return Center(
                  child: TextButton(
                    onPressed: () => open(context),
                    child: const Text('open'),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return pageContext;
  }

  MaterialLocalizations l10n(BuildContext context) =>
      MaterialLocalizations.of(context);

  group('date picker', () {
    testWidgets('the calendar draws 0-9 with Arabic month names', (
      tester,
    ) async {
      final context = await openFrom(
        tester,
        (context) => showDatePicker(
          context: context,
          initialDate: initial,
          firstDate: first,
          lastDate: last,
        ),
      );

      expect(l10n(context), isA<StudafyArabicMaterialLocalizations>());
      expect(find.byType(DatePickerDialog), findsOneWidget);
      expectWesternDigitsOnly(tester);
      // The month header is Arabic words around a Western year.
      expect(find.textContaining('أكتوبر'), findsWidgets);
      expect(find.textContaining('2026'), findsWidgets);
      expect(
        Directionality.of(tester.element(find.byType(DatePickerDialog))),
        TextDirection.rtl,
      );
    });

    testWidgets('the year list draws 0-9', (tester) async {
      await openFrom(
        tester,
        (context) => showDatePicker(
          context: context,
          initialDate: initial,
          firstDate: first,
          lastDate: last,
          initialDatePickerMode: DatePickerMode.year,
        ),
      );

      expect(find.byType(YearPicker), findsOneWidget);
      expect(find.text('2026'), findsOneWidget);
      expectWesternDigitsOnly(tester);
    });

    testWidgets('a typed date with 0-9 is accepted', (tester) async {
      DateTime? picked;
      final context = await openFrom(
        tester,
        (context) async => picked = await showDatePicker(
          context: context,
          initialDate: initial,
          firstDate: first,
          lastDate: last,
          initialEntryMode: DatePickerEntryMode.input,
        ),
      );

      // The field opens on the current date in the same digits.
      expect(find.widgetWithText(TextField, '16/10/2026'), findsOneWidget);
      expectWesternDigitsOnly(tester);

      await tester.enterText(find.byType(TextField), '20/11/2026');
      await tester.tap(find.text(l10n(context).okButtonLabel));
      await tester.pumpAndSettle();

      expect(find.byType(DatePickerDialog), findsNothing);
      expect(picked, DateTime(2026, 11, 20));
    });

    testWidgets('a typed date from an Arabic keyboard is accepted', (
      tester,
    ) async {
      DateTime? picked;
      final context = await openFrom(
        tester,
        (context) async => picked = await showDatePicker(
          context: context,
          initialDate: initial,
          firstDate: first,
          lastDate: last,
          initialEntryMode: DatePickerEntryMode.input,
        ),
      );

      await tester.enterText(find.byType(TextField), '٢٠/١١/٢٠٢٦');
      await tester.tap(find.text(l10n(context).okButtonLabel));
      await tester.pumpAndSettle();

      expect(picked, DateTime(2026, 11, 20));
    });

    testWidgets('an impossible typed date is still refused', (tester) async {
      final context = await openFrom(
        tester,
        (context) => showDatePicker(
          context: context,
          initialDate: initial,
          firstDate: first,
          lastDate: last,
          initialEntryMode: DatePickerEntryMode.input,
        ),
      );

      await tester.enterText(find.byType(TextField), '31/02/2026');
      await tester.tap(find.text(l10n(context).okButtonLabel));
      await tester.pumpAndSettle();

      expect(find.byType(DatePickerDialog), findsOneWidget);
      expect(find.text(l10n(context).invalidDateFormatLabel), findsOneWidget);
    });
  });

  group('date range picker', () {
    final range = DateTimeRange(
      start: DateTime(2026, 10, 5),
      end: DateTime(2026, 10, 16),
    );

    testWidgets('the calendar draws 0-9', (tester) async {
      await openFrom(
        tester,
        (context) => showDateRangePicker(
          context: context,
          initialDateRange: range,
          firstDate: first,
          lastDate: last,
        ),
      );

      expect(find.byType(DateRangePickerDialog), findsOneWidget);
      expect(find.textContaining('أكتوبر'), findsWidgets);
      expectWesternDigitsOnly(tester);
    });

    testWidgets('typed start and end dates are accepted', (tester) async {
      DateTimeRange? picked;
      final context = await openFrom(
        tester,
        (context) async => picked = await showDateRangePicker(
          context: context,
          initialDateRange: range,
          firstDate: first,
          lastDate: last,
          initialEntryMode: DatePickerEntryMode.input,
        ),
      );

      expect(find.widgetWithText(TextField, '5/10/2026'), findsOneWidget);
      expect(find.widgetWithText(TextField, '16/10/2026'), findsOneWidget);
      expectWesternDigitsOnly(tester);

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), '1/12/2026');
      await tester.enterText(fields.at(1), '٢٤/١٢/٢٠٢٦');
      await tester.tap(find.text(l10n(context).okButtonLabel));
      await tester.pumpAndSettle();

      expect(
        picked,
        DateTimeRange(
          start: DateTime(2026, 12, 1),
          end: DateTime(2026, 12, 24),
        ),
      );
    });
  });

  group('time picker', () {
    const morning = TimeOfDay(hour: 9, minute: 5);

    testWidgets('the dial draws 0-9', (tester) async {
      await openFrom(
        tester,
        (context) => showTimePicker(context: context, initialTime: morning),
      );

      expect(find.byType(TimePickerDialog), findsOneWidget);
      expect(find.text('05'), findsOneWidget);
      expectWesternDigitsOnly(tester);
    });

    testWidgets('the 24-hour dial draws 0-9', (tester) async {
      await openFrom(
        tester,
        (context) => showTimePicker(
          context: context,
          initialTime: const TimeOfDay(hour: 21, minute: 45),
        ),
        alwaysUse24HourFormat: true,
      );

      expect(find.text('21'), findsOneWidget);
      expectWesternDigitsOnly(tester);
    });

    testWidgets('a typed time is accepted', (tester) async {
      TimeOfDay? picked;
      final context = await openFrom(
        tester,
        (context) async => picked = await showTimePicker(
          context: context,
          initialTime: morning,
          initialEntryMode: TimePickerEntryMode.input,
        ),
      );
      expectWesternDigitsOnly(tester);

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), '7');
      await tester.enterText(fields.at(1), '45');
      await tester.tap(find.text(l10n(context).okButtonLabel));
      await tester.pumpAndSettle();

      expect(picked, const TimeOfDay(hour: 7, minute: 45));
    });
  });

  group('embedded pickers', () {
    Future<void> pumpEmbedded(WidgetTester tester, Widget picker) async {
      await tester.pumpWidget(
        localizedApp(
          locale: arabic,
          home: Scaffold(body: SingleChildScrollView(child: picker)),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('CalendarDatePicker draws 0-9', (tester) async {
      await pumpEmbedded(
        tester,
        CalendarDatePicker(
          initialDate: initial,
          firstDate: first,
          lastDate: last,
          onDateChanged: (_) {},
        ),
      );

      expect(find.text('16'), findsOneWidget);
      expectWesternDigitsOnly(tester);
    });

    testWidgets('CalendarDatePicker in year mode draws 0-9', (tester) async {
      await pumpEmbedded(
        tester,
        CalendarDatePicker(
          initialDate: initial,
          firstDate: first,
          lastDate: last,
          initialCalendarMode: DatePickerMode.year,
          onDateChanged: (_) {},
        ),
      );

      expect(find.text('2026'), findsOneWidget);
      expectWesternDigitsOnly(tester);
    });

    testWidgets('InputDatePickerFormField shows and reads 0-9', (tester) async {
      DateTime? submitted;
      await pumpEmbedded(
        tester,
        InputDatePickerFormField(
          initialDate: initial,
          firstDate: first,
          lastDate: last,
          onDateSubmitted: (date) => submitted = date,
        ),
      );

      expect(find.widgetWithText(TextField, '16/10/2026'), findsOneWidget);
      expect(find.text('dd/mm/yyyy'), findsOneWidget);
      expectWesternDigitsOnly(tester);

      await tester.enterText(find.byType(TextField), '3/1/2027');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(submitted, DateTime(2027, 1, 3));
    });
  });

  group('English is unchanged', () {
    testWidgets('Flutter\'s own English localizations are used', (
      tester,
    ) async {
      DateTime? picked;
      final context = await openFrom(
        tester,
        (context) async => picked = await showDatePicker(
          context: context,
          initialDate: initial,
          firstDate: first,
          lastDate: last,
          initialEntryMode: DatePickerEntryMode.input,
        ),
        locale: const Locale('en'),
      );

      expect(l10n(context), isNot(isA<StudafyArabicMaterialLocalizations>()));
      expect(l10n(context), isA<MaterialLocalizationEn>());
      expect(find.widgetWithText(TextField, '10/16/2026'), findsOneWidget);
      expect(find.text('mm/dd/yyyy'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '11/20/2026');
      await tester.tap(find.text(l10n(context).okButtonLabel));
      await tester.pumpAndSettle();

      expect(picked, DateTime(2026, 11, 20));
    });
  });
}
