import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'studafy_formatting.dart';

/// Flutter's Arabic Material localizations, with Western digits (ADR-0028).
///
/// The app shows 0-9 in both languages (see `studafy_formatting.dart`). The
/// screens' own dates go through the `studafy*` formatters, but the built-in
/// pickers — `showDatePicker`, `showDateRangePicker`, `showTimePicker`,
/// `CalendarDatePicker`, `InputDatePickerFormField`, `YearPicker` — format
/// with [MaterialLocalizations] directly, and Flutter's Arabic bundle builds
/// its date formats from `intl`, which uses Arabic-Indic digits for `ar`. The
/// calendar header read "الجمعة، ١٦ أكتوبر" and the year list "٢٠٢٦" while
/// the screen behind the picker said "16 أكتوبر 2026".
///
/// This keeps every Arabic string Flutter ships (month and day names, button
/// labels, the right-to-left layout) and changes only what produces digits:
///
/// - every `format*` method returns 0-9;
/// - the compact date used by the typed date entry is `d/M/y` without the
///   invisible right-to-left marks the Arabic pattern carries, so the date a
///   person types ("16/10/2026") looks like the one the field shows, and
///   [dateHelpText] describes that order;
/// - [parseCompactDate] reads 0-9 — and ٠-٩ from an Arabic keyboard — and
///   ignores direction marks pasted along with a date. Flutter's own Arabic
///   parser accepted only Arabic-Indic digits with the marks in place, so a
///   date typed as "16/10/2026" was rejected as invalid.
///
/// Registered ahead of [GlobalMaterialLocalizations.delegate] in the app's
/// `localizationsDelegates`; [Localizations] uses the first delegate that
/// supports a locale, so English still comes from Flutter unchanged.
class StudafyArabicMaterialLocalizations extends MaterialLocalizationAr {
  StudafyArabicMaterialLocalizations._({
    required super.localeName,
    required super.fullYearFormat,
    required super.compactDateFormat,
    required super.shortDateFormat,
    required super.mediumDateFormat,
    required super.longDateFormat,
    required super.yearMonthFormat,
    required super.shortMonthDayFormat,
    required super.decimalFormat,
    required super.twoDigitZeroPaddedFormat,
    required String compactDatePattern,
  }) : _dateHelpText = compactDatePattern
           .replaceAll(RegExp('d+'), 'dd')
           .replaceAll(RegExp('M+'), 'mm')
           .replaceAll(RegExp('y+'), 'yyyy');

  /// Builds the localizations for an Arabic [locale].
  factory StudafyArabicMaterialLocalizations.forLocale(Locale locale) {
    assert(locale.languageCode == _arabic, 'only Arabic is overridden');
    // Flutter ships the date symbols for its locales and registers them with
    // intl the first time its own delegate loads; loading it here guarantees
    // they are in place before the formats below are created. It is cached
    // and synchronous.
    GlobalMaterialLocalizations.delegate.load(locale);

    final localeName = intl.Intl.canonicalizedLocale(locale.toString());
    final dateLocale = intl.DateFormat.localeExists(localeName)
        ? localeName
        : locale.languageCode;
    final numberLocale = intl.NumberFormat.localeExists(localeName)
        ? localeName
        : locale.languageCode;

    intl.DateFormat western(intl.DateFormat format) =>
        format..useNativeDigits = false;
    final compactDatePattern = _withoutDirectionMarks(
      intl.DateFormat.yMd(dateLocale).pattern!,
    );

    return StudafyArabicMaterialLocalizations._(
      localeName: localeName,
      fullYearFormat: western(intl.DateFormat.y(dateLocale)),
      compactDateFormat: western(
        intl.DateFormat(compactDatePattern, dateLocale),
      ),
      shortDateFormat: western(intl.DateFormat.yMMMd(dateLocale)),
      mediumDateFormat: western(intl.DateFormat.MMMEd(dateLocale)),
      longDateFormat: western(intl.DateFormat.yMMMMEEEEd(dateLocale)),
      yearMonthFormat: western(intl.DateFormat.yMMMM(dateLocale)),
      shortMonthDayFormat: western(intl.DateFormat.MMMd(dateLocale)),
      decimalFormat: intl.NumberFormat.decimalPattern(numberLocale),
      twoDigitZeroPaddedFormat: intl.NumberFormat('00', numberLocale),
      compactDatePattern: compactDatePattern,
    );
  }

  /// Registers these localizations for Arabic; other languages fall through
  /// to [GlobalMaterialLocalizations.delegate].
  static const LocalizationsDelegate<MaterialLocalizations> delegate =
      _StudafyArabicMaterialLocalizationsDelegate();

  final String _dateHelpText;

  // Each format below already uses 0-9 (`useNativeDigits` is off, and
  // intl's Arabic number symbols are ASCII), but a future intl could change
  // either default for some Arabic region; converting again keeps the rule
  // in one place rather than in intl's data.

  @override
  String formatYear(DateTime date) =>
      studafyWesternDigits(super.formatYear(date));

  @override
  String formatCompactDate(DateTime date) =>
      studafyWesternDigits(super.formatCompactDate(date));

  @override
  String formatShortDate(DateTime date) =>
      studafyWesternDigits(super.formatShortDate(date));

  @override
  String formatMediumDate(DateTime date) =>
      studafyWesternDigits(super.formatMediumDate(date));

  @override
  String formatFullDate(DateTime date) =>
      studafyWesternDigits(super.formatFullDate(date));

  @override
  String formatMonthYear(DateTime date) =>
      studafyWesternDigits(super.formatMonthYear(date));

  @override
  String formatShortMonthDay(DateTime date) =>
      studafyWesternDigits(super.formatShortMonthDay(date));

  /// Also behind every count Flutter writes into a sentence: table pages,
  /// tab labels, selected rows, characters remaining.
  @override
  String formatDecimal(int number) =>
      studafyWesternDigits(super.formatDecimal(number));

  @override
  String formatHour(
    TimeOfDay timeOfDay, {
    bool alwaysUse24HourFormat = false,
  }) => studafyWesternDigits(
    super.formatHour(timeOfDay, alwaysUse24HourFormat: alwaysUse24HourFormat),
  );

  @override
  String formatMinute(TimeOfDay timeOfDay) =>
      studafyWesternDigits(super.formatMinute(timeOfDay));

  @override
  String formatTimeOfDay(
    TimeOfDay timeOfDay, {
    bool alwaysUse24HourFormat = false,
  }) => studafyWesternDigits(
    super.formatTimeOfDay(
      timeOfDay,
      alwaysUse24HourFormat: alwaysUse24HourFormat,
    ),
  );

  @override
  DateTime? parseCompactDate(String? inputString) => super.parseCompactDate(
    inputString == null
        ? null
        : _withoutDirectionMarks(studafyWesternDigits(inputString)).trim(),
  );

  @override
  String get dateHelpText => _dateHelpText;
}

/// The language whose Material localizations are replaced. Not a copy
/// switch: every word still comes from Flutter's Arabic bundle.
const _arabic = 'ar';

/// Removes the invisible bidirectional controls intl puts in Arabic date
/// patterns (and a paste can carry): LRM, RLM, the Arabic letter mark, and
/// the embedding, override and isolate controls.
String _withoutDirectionMarks(String value) => value.replaceAll(
  RegExp('[\u200E\u200F\u061C\u202A-\u202E\u2066-\u2069]'),
  '',
);

class _StudafyArabicMaterialLocalizationsDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const _StudafyArabicMaterialLocalizationsDelegate();

  static final Map<Locale, MaterialLocalizations> _loaded = {};

  @override
  bool isSupported(Locale locale) => locale.languageCode == _arabic;

  @override
  Future<MaterialLocalizations> load(Locale locale) =>
      SynchronousFuture<MaterialLocalizations>(
        _loaded.putIfAbsent(
          locale,
          () => StudafyArabicMaterialLocalizations.forLocale(locale),
        ),
      );

  @override
  bool shouldReload(_StudafyArabicMaterialLocalizationsDelegate old) => false;

  @override
  String toString() => 'StudafyArabicMaterialLocalizations.delegate';
}
