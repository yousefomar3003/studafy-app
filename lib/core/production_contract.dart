/// The production defines contract (REL-002, ADR-0044).
///
/// A production build is only as safe as the values compiled into it, and
/// Flutter compiles every `--dart-define` into the binary. This file is the
/// one place that says what a production build must carry. Three things use
/// it, so the rules cannot drift between them:
///
/// - the Android Gradle release check and the Xcode release build phase,
///   through `tools/check_release_defines.dart`, before anything compiles;
/// - `scripts/release/build-store.sh`, before it starts a store build;
/// - the app itself at start-up ([RuntimePolicy.blocksApplicationStartup]),
///   which refuses to run in production with values that do not match.
///
/// Pure Dart on purpose: the build checks run it on the Dart VM, without
/// Flutter.
library;

import 'dart:convert';

/// Values a production build must carry exactly.
abstract final class ProductionContract {
  /// The production `/v1` API (DL-067).
  static const apiUrl = 'https://api.studafy.com';

  /// The production Supabase project: Frankfurt, `cyrngoqnhqflzovlybbr`
  /// (DL-064).
  static const supabaseUrl = 'https://cyrngoqnhqflzovlybbr.supabase.co';

  /// Host of the privacy policy and terms (DL-067).
  static const legalHost = 'legal.studafy.com';

  /// Supabase publishable keys look like this; secret keys start
  /// `sb_secret_` and legacy keys are JWTs. Requiring the publishable prefix
  /// means a secret or service-role key can never be compiled in by mistake.
  static final publishableKeyPattern = RegExp(
    r'^sb_publishable_[A-Za-z0-9_-]{8,}$',
  );

  /// The only defines a production build may carry. An unknown name is
  /// refused rather than ignored: a demo, debug or seed switch added later
  /// must be reviewed into this list before it can reach a store build.
  static const allowedNames = <String>{
    'APP_ENV',
    'SUPABASE_URL',
    'SUPABASE_PUBLISHABLE_KEY',
    'STUDAFY_API_URL',
    'STUDAFY_PRIVACY_URL',
    'STUDAFY_TERMS_URL',
    'TURNSTILE_ENABLED',
    'APPLE_SIGN_IN_ENABLED',
    'SENTRY_DSN',
    'PUSH_ENABLED',
    'STUDAFY_ANDROID_PACKAGE',
    'FIREBASE_PROJECT_ID',
    'FIREBASE_MESSAGING_SENDER_ID',
    'FIREBASE_IOS_BUNDLE_ID',
    'FIREBASE_IOS_API_KEY',
    'FIREBASE_IOS_APP_ID',
    'FIREBASE_ANDROID_API_KEY',
    'FIREBASE_ANDROID_APP_ID',
  };

  /// Defines the Flutter tool adds itself (version, build name and number,
  /// flavor, feature flags). It refuses to let a build set them, so they are
  /// allowed by prefix.
  static const flutterToolPrefix = 'FLUTTER_';

  static const _booleanNames = {
    'TURNSTILE_ENABLED',
    'APPLE_SIGN_IN_ENABLED',
    'PUSH_ENABLED',
  };

  /// What a production build of [defines] gets wrong; empty means it passes.
  ///
  /// [defines] maps each name to every value given for it, because a second
  /// `--dart-define` of the same name silently wins at compile time.
  /// [platform] is `android` or `ios` for a build, which adds that
  /// platform's rules and the build number (`FLUTTER_BUILD_NUMBER`, which
  /// the Flutter tool adds from `--build-number`). It is null at run time:
  /// the build already checked those, and the app does not know them.
  static List<String> problems(
    Map<String, List<String>> defines, {
    String? platform,
  }) {
    final problems = <String>[];
    String value(String name) {
      final values = defines[name];
      return values == null || values.isEmpty ? '' : values.single;
    }

    for (final entry in defines.entries) {
      final name = entry.key;
      if (!allowedNames.contains(name) && !name.startsWith(flutterToolPrefix)) {
        problems.add('$name is not allowed in a production build');
      }
      if (entry.value.length > 1) {
        problems.add('$name is given ${entry.value.length} times');
      }
    }
    if (problems.isNotEmpty) return problems;

    for (final entry in defines.entries) {
      final lower = entry.value.single.toLowerCase();
      if (lower.contains('service_role') || lower.contains('sb_secret_')) {
        problems.add('${entry.key} looks like a server secret');
      }
    }

    if (value('APP_ENV') != 'production') {
      problems.add('APP_ENV must be production');
    }
    if (value('STUDAFY_API_URL') != apiUrl) {
      problems.add('STUDAFY_API_URL must be $apiUrl');
    }
    if (value('SUPABASE_URL') != supabaseUrl) {
      problems.add('SUPABASE_URL must be $supabaseUrl');
    }
    final key = value('SUPABASE_PUBLISHABLE_KEY');
    if (!publishableKeyPattern.hasMatch(key)) {
      problems.add(
        'SUPABASE_PUBLISHABLE_KEY must be the project\'s publishable key '
        '(sb_publishable_..., Supabase dashboard > Project Settings > '
        'API Keys)',
      );
    }
    for (final name in ['STUDAFY_PRIVACY_URL', 'STUDAFY_TERMS_URL']) {
      if (!_isLegalUrl(value(name))) {
        problems.add('$name must be an https URL on $legalHost');
      }
    }
    for (final name in _booleanNames) {
      final given = value(name);
      if (given.isNotEmpty && given != 'true' && given != 'false') {
        problems.add('$name must be true or false');
      }
    }
    if (value('TURNSTILE_ENABLED') != 'true') {
      problems.add('TURNSTILE_ENABLED must be true');
    }
    final dsn = value('SENTRY_DSN');
    if (dsn.isNotEmpty && !_isSentryDsn(dsn)) {
      problems.add('SENTRY_DSN must be empty or an https Sentry DSN');
    }
    final package = value('STUDAFY_ANDROID_PACKAGE');
    if (package.isNotEmpty && package != 'com.studafy.light') {
      problems.add('STUDAFY_ANDROID_PACKAGE must be com.studafy.light');
    }

    if (platform == 'ios' && value('APPLE_SIGN_IN_ENABLED') != 'true') {
      // App Store guideline 4.8 (DL-033): the app offers Google and
      // Microsoft sign-in, so Sign in with Apple must ship on iOS.
      problems.add('APPLE_SIGN_IN_ENABLED must be true for an iOS build');
    }
    if (platform != null) {
      final number = int.tryParse(value('FLUTTER_BUILD_NUMBER'));
      if (number == null || number <= 1) {
        // 1 is the pubspec.yaml baseline; both stores need every upload's
        // number to be higher than the last.
        problems.add(
          'the build number must be given with --build-number and be above 1 '
          '(CI: .github/scripts/build-number.sh)',
        );
      }
    }
    return problems;
  }

  /// The same check for single values, as the app has them at run time.
  static List<String> problemsIn(Map<String, String> defines) => problems({
    for (final entry in defines.entries)
      if (entry.value.isNotEmpty) entry.key: [entry.value],
  });

  static bool _isLegalUrl(String value) {
    final uri = Uri.tryParse(value);
    return uri != null &&
        uri.scheme == 'https' &&
        uri.host == legalHost &&
        uri.userInfo.isEmpty &&
        !uri.hasPort &&
        !uri.hasQuery &&
        !uri.hasFragment;
  }

  static bool _isSentryDsn(String value) {
    final uri = Uri.tryParse(value);
    return uri != null &&
        uri.scheme == 'https' &&
        uri.userInfo.isNotEmpty &&
        (uri.host == 'sentry.io' || uri.host.endsWith('.sentry.io'));
  }
}

/// The contract's defines as this binary was compiled with them. Missing
/// ones are empty.
const compiledReleaseDefines = <String, String>{
  'APP_ENV': String.fromEnvironment('APP_ENV'),
  'SUPABASE_URL': String.fromEnvironment('SUPABASE_URL'),
  'SUPABASE_PUBLISHABLE_KEY': String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  ),
  'STUDAFY_API_URL': String.fromEnvironment('STUDAFY_API_URL'),
  'STUDAFY_PRIVACY_URL': String.fromEnvironment('STUDAFY_PRIVACY_URL'),
  'STUDAFY_TERMS_URL': String.fromEnvironment('STUDAFY_TERMS_URL'),
  'TURNSTILE_ENABLED': String.fromEnvironment('TURNSTILE_ENABLED'),
  'APPLE_SIGN_IN_ENABLED': String.fromEnvironment('APPLE_SIGN_IN_ENABLED'),
  'SENTRY_DSN': String.fromEnvironment('SENTRY_DSN'),
  'PUSH_ENABLED': String.fromEnvironment('PUSH_ENABLED'),
  'STUDAFY_ANDROID_PACKAGE': String.fromEnvironment('STUDAFY_ANDROID_PACKAGE'),
};

/// Decodes the dart-defines the Flutter tool hands to Gradle
/// (`-Pdart-defines`) and to Xcode (`DART_DEFINES`): base64 of `NAME=value`,
/// joined by commas.
Map<String, List<String>> decodeFlutterDartDefines(String encoded) {
  final defines = <String, List<String>>{};
  for (final entry in encoded.split(',')) {
    if (entry.trim().isEmpty) continue;
    final define = utf8.decode(base64.decode(entry.trim()));
    final separator = define.indexOf('=');
    if (separator <= 0) continue;
    defines
        .putIfAbsent(define.substring(0, separator), () => [])
        .add(define.substring(separator + 1));
  }
  return defines;
}
