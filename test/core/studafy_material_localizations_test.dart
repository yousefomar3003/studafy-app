import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/core/studafy_material_localizations.dart';

/// ADR-0028: the Arabic Material localizations keep Arabic words and 0-9
/// digits, and the typed date entry reads what a person types.
void main() {
  final arabicIndic = RegExp('[٠-٩۰-۹]');
  final arabicLetters = RegExp('[ء-ي]');
  const delegate = StudafyArabicMaterialLocalizations.delegate;
  final friday = DateTime(2026, 10, 16);

  Future<MaterialLocalizations> arabic() => delegate.load(const Locale('ar'));
  Future<MaterialLocalizations> flutterArabic() =>
      GlobalMaterialLocalizations.delegate.load(const Locale('ar'));

  group('the delegate', () {
    test('supports Arabic only, so English stays with Flutter', () {
      expect(delegate.isSupported(const Locale('ar')), isTrue);
      expect(delegate.isSupported(const Locale('ar', 'JO')), isTrue);
      expect(delegate.isSupported(const Locale('en')), isFalse);
      expect(delegate.shouldReload(delegate), isFalse);
    });

    test('loads synchronously and caches the bundle', () async {
      final first = await arabic();
      final second = await arabic();

      expect(
        delegate.load(const Locale('ar')),
        isA<SynchronousFuture<MaterialLocalizations>>(),
      );
      expect(first, isA<StudafyArabicMaterialLocalizations>());
      expect(first, isA<MaterialLocalizationAr>());
      expect(identical(first, second), isTrue);
    });

    test('an Arabic region variant loads too', () async {
      final jordan = await delegate.load(const Locale('ar', 'JO'));

      expect(jordan.formatYear(friday), '2026');
      expect(jordan.formatMediumDate(friday), isNot(contains(arabicIndic)));
    });
  });

  group('every digit-producing format uses 0-9', () {
    test('dates', () async {
      final l = await arabic();
      final formats = <String, String>{
        'formatYear': l.formatYear(friday),
        'formatCompactDate': l.formatCompactDate(friday),
        'formatShortDate': l.formatShortDate(friday),
        'formatMediumDate': l.formatMediumDate(friday),
        'formatFullDate': l.formatFullDate(friday),
        'formatMonthYear': l.formatMonthYear(friday),
        'formatShortMonthDay': l.formatShortMonthDay(friday),
      };

      for (final entry in formats.entries) {
        expect(
          entry.value,
          isNot(contains(arabicIndic)),
          reason: '${entry.key} gave "${entry.value}"',
        );
      }
      expect(l.formatYear(friday), '2026');
      expect(l.formatCompactDate(friday), '16/10/2026');
      expect(l.formatFullDate(friday), contains('16'));
      expect(l.formatFullDate(friday), contains('2026'));
    });

    test('numbers and times', () async {
      final l = await arabic();
      const morning = TimeOfDay(hour: 9, minute: 5);
      const evening = TimeOfDay(hour: 21, minute: 45);

      expect(l.formatDecimal(1234567), isNot(contains(arabicIndic)));
      expect(l.formatDecimal(7), '7');
      expect(l.formatHour(morning), '9');
      expect(l.formatHour(evening, alwaysUse24HourFormat: true), '21');
      expect(l.formatMinute(morning), '05');
      expect(l.formatTimeOfDay(morning), contains('9:05'));
      expect(
        l.formatTimeOfDay(evening, alwaysUse24HourFormat: true),
        contains('21:45'),
      );
      // Counts Flutter writes into sentences go through formatDecimal.
      expect(l.tabLabel(tabIndex: 3, tabCount: 12), contains('12'));
      expect(l.pageRowsInfoTitle(11, 20, 95, true), contains('95'));
    });
  });

  group('the Arabic words are Flutter\'s', () {
    test('month and day names stay Arabic', () async {
      final ours = await arabic();
      final flutter = await flutterArabic();

      expect(ours.formatMediumDate(friday), contains(arabicLetters));
      expect(ours.formatFullDate(friday), contains(arabicLetters));
      expect(ours.formatMonthYear(friday), contains(arabicLetters));
      // Same text as Flutter once its digits are rewritten.
      expect(
        ours.formatFullDate(friday),
        _western(flutter.formatFullDate(friday)),
      );
      expect(
        ours.formatMonthYear(friday),
        _western(flutter.formatMonthYear(friday)),
      );
    });

    test('labels, weekdays and the week start are unchanged', () async {
      final ours = await arabic();
      final flutter = await flutterArabic();

      expect(ours.okButtonLabel, flutter.okButtonLabel);
      expect(ours.cancelButtonLabel, flutter.cancelButtonLabel);
      expect(ours.datePickerHelpText, flutter.datePickerHelpText);
      expect(ours.narrowWeekdays, flutter.narrowWeekdays);
      expect(ours.firstDayOfWeekIndex, flutter.firstDayOfWeekIndex);
      expect(ours.timeOfDayFormat(), flutter.timeOfDayFormat());
      expect(ours.anteMeridiemAbbreviation, flutter.anteMeridiemAbbreviation);
    });
  });

  group('typed dates parse', () {
    test('Western digits, in the order the field shows', () async {
      final l = await arabic();

      expect(l.parseCompactDate('16/10/2026'), friday);
      expect(l.parseCompactDate('1/2/2027'), DateTime(2027, 2, 1));
      expect(l.parseCompactDate(' 01/02/2027 '), DateTime(2027, 2, 1));
    });

    test('Arabic-Indic digits from an Arabic keyboard', () async {
      final l = await arabic();

      expect(l.parseCompactDate('١٦/١٠/٢٠٢٦'), friday);
      expect(l.parseCompactDate('۱۶/۱۰/۲۰۲۶'), friday);
    });

    test('a pasted date with direction marks', () async {
      final l = await arabic();

      expect(l.parseCompactDate('16\u200F/10\u200F/2026'), friday);
      expect(l.parseCompactDate('\u206616/10/2026\u2069'), friday);
    });

    test('what the field shows reads back as the same day', () async {
      final l = await arabic();

      for (final day in [
        friday,
        DateTime(2027, 1, 1),
        DateTime(2026, 12, 31),
      ]) {
        expect(l.parseCompactDate(l.formatCompactDate(day)), day);
      }
    });

    test('nonsense is still rejected', () async {
      final l = await arabic();

      expect(l.parseCompactDate(null), isNull);
      expect(l.parseCompactDate(''), isNull);
      expect(l.parseCompactDate('32/10/2026'), isNull);
      expect(l.parseCompactDate('16/13/2026'), isNull);
      expect(l.parseCompactDate('next week'), isNull);
    });

    test('the hint describes the order', () async {
      final l = await arabic();

      expect(l.dateHelpText, 'dd/mm/yyyy');
    });
  });
}

String _western(String value) => String.fromCharCodes([
  for (final code in value.runes)
    if (code >= 0x0660 && code <= 0x0669) code - 0x0660 + 0x30 else code,
]);
