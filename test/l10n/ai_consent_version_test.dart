import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/core/ai_consent.dart';

/// An AI consent says which words a student - or a parent for a child
/// account - agreed to (ADR-0043). The published 'ai_features' policy row
/// for [aiConsentVersion] carries the SHA-256 of the exact in-app notice in
/// each language, so editing the notice without publishing a new version
/// would leave every new consent pointing at words nobody saw.
void main() {
  test('the in-app AI notice matches the published AI consent version', () {
    final migration = Directory('supabase/migrations')
        .listSync()
        .whereType<File>()
        .map((file) => file.readAsStringSync())
        .lastWhere(
          (sql) => sql.contains("'ai_features', '$aiConsentVersion'"),
          orElse: () => '',
        );
    expect(
      migration,
      isNotEmpty,
      reason: 'no migration publishes AI consent version $aiConsentVersion',
    );
    for (final locale in ['en', 'ar']) {
      final arb = jsonDecode(
        File('lib/l10n/app_$locale.arb').readAsStringSync(),
      ) as Map<String, Object?>;
      final text = arb['aiConsentNoticeBody'] as String;
      final digest = sha256.convert(utf8.encode(text)).toString();
      expect(
        migration,
        contains(digest),
        reason:
            'the $locale AI notice changed: publish a new AI consent version '
            'and bump aiConsentVersion',
      );
    }
  });

  test('the notice says names are replaced and photos are not', () {
    final en = jsonDecode(
      File('lib/l10n/app_en.arb').readAsStringSync(),
    ) as Map<String, Object?>;
    final text = en['aiConsentNoticeBody'] as String;
    expect(text, contains('[student]'));
    expect(text, contains('A photo is sent as it is'));
    expect(text, contains('turn the AI tools off at any time'));
  });
}
