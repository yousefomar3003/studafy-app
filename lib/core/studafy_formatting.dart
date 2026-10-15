import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

/// Dates, times and numbers in the reader's language (MOB-070, ADR-0028).
///
/// **Arabic interface, Western digits.** Studafy renders 0-9 in both
/// languages while using Arabic month and day names under `ar`. Three
/// reasons: identifiers like `STU-42` appear inside body copy and must stay
/// readable and copy-pasteable; grades and counts must match the email and
/// push copy the server sends, which is ASCII; and Gulf school software
/// overwhelmingly uses Western digits.
///
/// That is a product judgement, not a technical one. It lives in this one
/// file and is recorded as revisitable in the decision log: switching to
/// Eastern Arabic-Indic numerals means deleting [_toWesternDigits] and its
/// call sites, and nothing else.
String _localeOf(BuildContext context) =>
    Localizations.localeOf(context).languageCode;

/// Arabic-Indic (٠-٩) and Extended Arabic-Indic (۰-۹) digits, rewritten as
/// 0-9.
///
/// `intl` picks the numbering system from the locale's own data, and for `ar`
/// that is Arabic-Indic — so this is an explicit override, not a no-op.
/// `mob070_formatting_test.dart` fails if it stops being applied.
String _toWesternDigits(String value) {
  const arabicIndic = 0x0660;
  const extendedArabicIndic = 0x06F0;
  return String.fromCharCodes([
    for (final code in value.runes)
      if (code >= arabicIndic && code <= arabicIndic + 9)
        code - arabicIndic + 0x30
      else if (code >= extendedArabicIndic && code <= extendedArabicIndic + 9)
        code - extendedArabicIndic + 0x30
      else
        code,
  ]);
}

/// A date as "17 September 2026", with Arabic month names under `ar`.
String studafyDate(BuildContext context, DateTime when) =>
    _toWesternDigits(DateFormat.yMMMMd(_localeOf(context)).format(when));

/// A short date as "17 Sep 2026".
String studafyShortDate(BuildContext context, DateTime when) =>
    _toWesternDigits(DateFormat.yMMMd(_localeOf(context)).format(when));

/// A clock time in the reader's convention.
String studafyTime(BuildContext context, DateTime when) =>
    _toWesternDigits(DateFormat.jm(_localeOf(context)).format(when));

/// A moment as "17 Sep 2026 · 2:30 PM": when work was handed in, when a
/// meeting starts.
String studafyDateTime(BuildContext context, DateTime when) =>
    '${studafyShortDate(context, when)} · ${studafyTime(context, when)}';

/// An IANA time zone id ("Asia/Amman") ready to sit inside a sentence.
///
/// The id is Latin with a slash, so inside Arabic copy such as
/// "موعد التسليم … (Asia/Amman)" it was laid out as part of the right-to-left
/// sentence: the line could break after the slash and the brackets paired
/// with the wrong ends, showing "(Asia/ Amman)". A left-to-right isolate
/// (U+2066 … U+2069) keeps the id one left-to-right run that the
/// surrounding text treats as a single neutral character, so the brackets
/// in the translation stay around it in either language, and a word joiner
/// (U+2060) after each slash keeps the id on one line.
String studafyTimeZone(String zone) =>
    '\u2066${zone.replaceAll('/', '/\u2060')}\u2069';

/// A plain number — a grade, a count, a percentage.
String studafyNumber(BuildContext context, num value) => _toWesternDigits(
  NumberFormat.decimalPattern(_localeOf(context)).format(value),
);

/// Short weekday names, Monday first, in the reader's language.
///
/// Built from `intl` rather than a hardcoded English list, so Arabic gets
/// الاثنين rather than "Mon".
List<String> studafyWeekdayNames(BuildContext context) {
  final format = DateFormat.E(_localeOf(context));
  // 2024-01-01 was a Monday; seven days from it covers the week in order.
  return [
    for (var day = 0; day < 7; day++)
      _toWesternDigits(
        format.format(DateTime(2024, 1, 1).add(Duration(days: day))),
      ),
  ];
}
