import 'package:flutter/material.dart';
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
/// That is a product judgement, not a technical one. It lives in this file
/// and in `studafy_material_localizations.dart` (the built-in date and time
/// pickers), and is recorded as revisitable in the decision log: switching to
/// Eastern Arabic-Indic numerals means deleting [studafyWesternDigits] and its
/// call sites, and nothing else.
String _localeOf(BuildContext context) =>
    Localizations.localeOf(context).languageCode;

/// Arabic-Indic (٠-٩) and Extended Arabic-Indic (۰-۹) digits, rewritten as
/// 0-9.
///
/// `intl` picks the numbering system from the locale's own data, and for `ar`
/// that is Arabic-Indic — so this is an explicit override, not a no-op.
/// `test/core/formatting_test.dart` fails if it stops being applied.
///
/// Screens never call this themselves: they use the `studafy*` formatters
/// below, and the Material pickers get it through
/// `StudafyArabicMaterialLocalizations`.
String studafyWesternDigits(String value) {
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
    studafyWesternDigits(DateFormat.yMMMMd(_localeOf(context)).format(when));

/// A short date as "17 Sep 2026".
String studafyShortDate(BuildContext context, DateTime when) =>
    studafyWesternDigits(DateFormat.yMMMd(_localeOf(context)).format(when));

/// A clock time in the reader's convention.
String studafyTime(BuildContext context, DateTime when) =>
    studafyWesternDigits(DateFormat.jm(_localeOf(context)).format(when));

/// The Material date and time formats ("Mon, Oct 5", "Monday, October 5,
/// 2026", "Oct 5", "11:59 PM"), with 0-9 digits under `ar`.
///
/// Screens call these instead of `MaterialLocalizations.formatMediumDate`
/// and friends, which give Arabic-Indic day numbers under `ar` - so a
/// deadline read "٥ أكتوبر 11:59 م", two digit systems in one line. The
/// rtl_source_test keeps screens from calling those directly.
String studafyMediumDate(BuildContext context, DateTime when) =>
    studafyWesternDigits(
      MaterialLocalizations.of(context).formatMediumDate(when),
    );

/// See [studafyMediumDate].
String studafyFullDate(BuildContext context, DateTime when) =>
    studafyWesternDigits(
      MaterialLocalizations.of(context).formatFullDate(when),
    );

/// See [studafyMediumDate].
String studafyShortMonthDay(BuildContext context, DateTime when) =>
    studafyWesternDigits(
      MaterialLocalizations.of(context).formatShortMonthDay(when),
    );

/// See [studafyMediumDate].
String studafyTimeOfDay(BuildContext context, TimeOfDay time) =>
    studafyWesternDigits(
      MaterialLocalizations.of(context).formatTimeOfDay(time),
    );

/// A numeric month and day ("10/5" in English), for chart axis labels.
String studafyNumericMonthDay(BuildContext context, DateTime when) =>
    studafyWesternDigits(DateFormat.Md(_localeOf(context)).format(when));

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

/// The plans' names. They are Latin in every language (the Arabic copy
/// keeps "Family+", "Studafy Plus" and "Studafy Max" as they are).
const studafyPlanNames = [
  'Studafy Free',
  'Studafy Plus',
  'Studafy Max',
  'Family+',
];

/// A plan name ready to sit inside a sentence or beside other text.
///
/// Inside right-to-left text a Latin name is laid out by the bidirectional
/// algorithm, and a neutral character at its edge takes the sentence's
/// direction: "Family+" in an Arabic line showed as "+Family". A
/// left-to-right isolate (U+2066 \u2026 U+2069) keeps the name one left-to-right
/// run whatever surrounds it. The Arabic strings carry the isolates
/// themselves; this is for names put together in code.
String studafyPlanName(String name) => '\u2066$name\u2069';

/// [text] with every plan name in it isolated left to right, as
/// [studafyPlanName] does. For text whose words are fixed elsewhere and must
/// not change - the terms and privacy text, whose SHA-256 is what a consent
/// records - so the isolates are added only as it is shown.
String studafyIsolatePlanNames(String text) {
  var result = text;
  for (final name in studafyPlanNames) {
    result = result.replaceAll(
      RegExp('(?<!\u2066)${RegExp.escape(name)}'),
      studafyPlanName(name),
    );
  }
  return result;
}

/// A plain number — a grade, a count, a percentage.
String studafyNumber(BuildContext context, num value) => studafyWesternDigits(
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
      studafyWesternDigits(
        format.format(DateTime(2024, 1, 1).add(Duration(days: day))),
      ),
  ];
}
