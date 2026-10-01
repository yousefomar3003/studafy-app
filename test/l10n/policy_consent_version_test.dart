import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/core/account_lifecycle.dart';

/// A consent record says which words a person accepted. The published policy
/// row for [termsPolicyVersion] carries the SHA-256 of the exact in-app text
/// in each language, so editing that text without publishing a new consent
/// version would leave every new consent pointing at words nobody saw.
void main() {
  test('the in-app terms and privacy text match the published consent '
      'version', () {
    final migration = Directory('supabase/migrations')
        .listSync()
        .whereType<File>()
        .map((file) => file.readAsStringSync())
        .lastWhere(
          (sql) => sql.contains("'terms_and_privacy', '$termsPolicyVersion'"),
          orElse: () => '',
        );
    expect(
      migration,
      isNotEmpty,
      reason: 'no migration publishes consent version $termsPolicyVersion',
    );
    for (final locale in ['en', 'ar']) {
      final arb = jsonDecode(
        File('lib/l10n/app_$locale.arb').readAsStringSync(),
      ) as Map<String, Object?>;
      final text = '${arb['policyTermsBody']}\n\n${arb['policyPrivacyBody']}';
      final digest = sha256.convert(utf8.encode(text)).toString();
      expect(
        migration,
        contains(digest),
        reason:
            'the $locale policy text changed: publish a new consent version '
            'and bump termsPolicyVersion',
      );
    }
  });
}
