import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/core/locale_controller.dart';

/// MOB-070 (ADR-0028): guards for the copy catalogue itself.
///
/// gen-l10n only *warns* about a key missing from a translation and silently
/// falls back to English at runtime, so a half-translated screen would ship
/// green. These assertions fail the build instead.
void main() {
  Map<String, dynamic> arb(String locale) =>
      jsonDecode(File('lib/l10n/app_$locale.arb').readAsStringSync())
          as Map<String, dynamic>;

  /// Message keys only: `@@locale` is metadata and `@key` entries are
  /// descriptions for translators, which the Arabic file does not repeat.
  Set<String> messageKeys(Map<String, dynamic> file) =>
      file.keys.where((key) => !key.startsWith('@')).toSet();

  test('every English message is translated into Arabic', () {
    final english = messageKeys(arb('en'));
    final arabic = messageKeys(arb('ar'));

    expect(
      english.difference(arabic),
      isEmpty,
      reason: 'these keys would silently render in English for Arabic readers',
    );
  });

  test('Arabic carries no message English does not have', () {
    final english = messageKeys(arb('en'));
    final arabic = messageKeys(arb('ar'));

    expect(
      arabic.difference(english),
      isEmpty,
      reason: 'an Arabic-only key is dead copy or a renamed key left behind',
    );
  });

  test('no Arabic string is still its English original', () {
    // The failure mode a key-parity check misses entirely: English pasted into
    // the Arabic file as a placeholder and never translated.
    final english = arb('en');
    final arabic = arb('ar');
    // Written the same in both files on purpose: the language names, so a
    // reader can find their own language in either interface, and the
    // sentence-ending full stop of the consent line.
    const identicalOnPurpose = {
      'languageEnglish',
      'languageArabic',
      'loginConsentSuffix',
    };

    final untranslated = messageKeys(english)
        .where((key) => !identicalOnPurpose.contains(key))
        .where((key) => arabic[key] == english[key])
        .toList();

    expect(untranslated, isEmpty, reason: 'still showing the English copy');
  });

  test('every shipped language is declared to both platforms', () {
    // Flutter's supportedLocales is not what the operating systems read. iOS
    // takes CFBundleLocalizations and Android takes locales_config; if Arabic
    // is missing there, an Arabic phone reports English and first-launch
    // detection silently fails.
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    final localesConfig = File(
      'android/app/src/main/res/xml/locales_config.xml',
    ).readAsStringSync();

    for (final locale in kSupportedLocales) {
      final code = locale.languageCode;
      expect(
        plist,
        contains('<string>$code</string>'),
        reason: '$code is missing from CFBundleLocalizations',
      );
      expect(
        localesConfig,
        contains('android:name="$code"'),
        reason: '$code is missing from the Android locale config',
      );
    }
  });
}
