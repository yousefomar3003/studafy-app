import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/core/production_contract.dart';

/// A production build that passes, as the Flutter tool would pass it.
Map<String, List<String>> good({Map<String, String> change = const {}}) {
  final defines = <String, String>{
    'APP_ENV': 'production',
    'STUDAFY_API_URL': 'https://api.studafy.com',
    'SUPABASE_URL': 'https://cyrngoqnhqflzovlybbr.supabase.co',
    'SUPABASE_PUBLISHABLE_KEY': 'sb_publishable_xxxxxxxxxxxxxxxx',
    'STUDAFY_PRIVACY_URL': 'https://legal.studafy.com/privacy',
    'STUDAFY_TERMS_URL': 'https://legal.studafy.com/terms',
    'TURNSTILE_ENABLED': 'true',
    'APPLE_SIGN_IN_ENABLED': 'true',
    'SENTRY_DSN': 'https://abc123@o1.ingest.de.sentry.io/42',
    'FLUTTER_BUILD_NAME': '1.0.0',
    'FLUTTER_BUILD_NUMBER': '1042',
    'FLUTTER_VERSION': '3.47.1',
    ...change,
  };
  return {
    for (final entry in defines.entries) entry.key: [entry.value],
  };
}

List<String> check(Map<String, List<String>> defines, {String? platform}) =>
    ProductionContract.problems(defines, platform: platform);

void main() {
  test('a complete production build passes on both platforms', () {
    expect(check(good(), platform: 'android'), isEmpty);
    expect(check(good(), platform: 'ios'), isEmpty);
    expect(check(good()), isEmpty);
  });

  test('each pinned value must match exactly', () {
    for (final (name, value) in [
      ('APP_ENV', 'development'),
      ('STUDAFY_API_URL', 'https://studafy-api-test.fly.dev'),
      ('STUDAFY_API_URL', 'https://api.studafy.com/'),
      ('SUPABASE_URL', 'https://zqbbsnqutrvlqcmtdlcx.supabase.co'),
      ('TURNSTILE_ENABLED', 'false'),
      ('STUDAFY_PRIVACY_URL', 'http://legal.studafy.com/privacy'),
      ('STUDAFY_TERMS_URL', 'https://legal.studafy.com.evil.example/terms'),
      ('STUDAFY_TERMS_URL', 'https://legal.studafy.com/terms?x=1'),
      ('STUDAFY_ANDROID_PACKAGE', 'com.example.studafy'),
    ]) {
      expect(
        check(good(change: {name: value}), platform: 'android'),
        isNotEmpty,
        reason: '$name=$value',
      );
    }
  });

  test('missing required values are refused', () {
    for (final name in [
      'APP_ENV',
      'STUDAFY_API_URL',
      'SUPABASE_URL',
      'SUPABASE_PUBLISHABLE_KEY',
      'STUDAFY_PRIVACY_URL',
      'STUDAFY_TERMS_URL',
      'TURNSTILE_ENABLED',
    ]) {
      expect(
        check(good()..remove(name), platform: 'android'),
        isNotEmpty,
        reason: name,
      );
    }
  });

  test('only a publishable Supabase key is accepted', () {
    for (final key in [
      '',
      'REPLACE_WITH_sb_publishable_KEY_FROM_SUPABASE_DASHBOARD',
      'sb_secret_abcdefgh12345678',
      'eyJhbGciOiJIUzI1NiJ9.eyJyb2xlIjoic2VydmljZV9yb2xlIn0.x',
      'sb_publishable_short',
    ]) {
      expect(
        check(good(change: {'SUPABASE_PUBLISHABLE_KEY': key})),
        isNotEmpty,
        reason: key,
      );
    }
  });

  test('unknown, repeated and secret-looking defines are refused', () {
    expect(
      check({
        ...good(),
        'DEMO_MODE': ['true'],
      }),
      contains('DEMO_MODE is not allowed in a production build'),
    );
    expect(
      check({
        ...good(),
        'APP_ENV': ['production', 'production'],
      }),
      contains('APP_ENV is given 2 times'),
    );
    expect(
      check(good(change: {'SENTRY_DSN': 'service_role'})),
      contains('SENTRY_DSN looks like a server secret'),
    );
  });

  test('Sentry DSN may be empty but not a placeholder', () {
    expect(check(good(change: {'SENTRY_DSN': ''})), isEmpty);
    expect(
      check(good(change: {'SENTRY_DSN': 'REPLACE_WITH_THE_APP_SENTRY_DSN'})),
      contains('SENTRY_DSN must be empty or an https Sentry DSN'),
    );
  });

  test('platform rules: Apple sign-in on iOS, a real build number', () {
    final noApple = good(change: {'APPLE_SIGN_IN_ENABLED': 'false'});
    expect(check(noApple, platform: 'android'), isEmpty);
    expect(
      check(noApple, platform: 'ios'),
      contains('APPLE_SIGN_IN_ENABLED must be true for an iOS build'),
    );
    for (final number in ['1', '0', 'x']) {
      expect(
        check(
          good(change: {'FLUTTER_BUILD_NUMBER': number}),
          platform: 'android',
        ),
        isNotEmpty,
        reason: number,
      );
    }
    // The app at run time does not know the build number.
    expect(check(good(change: {'FLUTTER_BUILD_NUMBER': '1'})), isEmpty);
  });

  test('decodes the dart-defines as the Flutter tool encodes them', () {
    String encode(String define) => base64.encode(utf8.encode(define));
    final encoded = [
      'APP_ENV=production',
      'SENTRY_DSN=',
      'APP_ENV=development',
      'URL=https://a.example/?x=1',
    ].map(encode).join(',');
    expect(decodeFlutterDartDefines(encoded), {
      'APP_ENV': ['production', 'development'],
      'SENTRY_DSN': [''],
      'URL': ['https://a.example/?x=1'],
    });
    expect(decodeFlutterDartDefines(''), isEmpty);
    expect(() => decodeFlutterDartDefines('%%%'), throwsFormatException);
  });
}
