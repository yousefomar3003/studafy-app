import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/core/production_contract.dart';
import 'package:studafy/core/runtime_environment.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test('no Edge Function signs a private object or contacts a provider', () {
    // SEC-001's critical finding was a caller-selected path signed with
    // service-role credentials and sent to a provider. AI-072 deleted both
    // AI functions; every remaining function must stay incapable of that.
    final functions = Directory('supabase/functions')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.ts'))
        .toList();
    expect(functions, isNotEmpty);
    for (final file in functions) {
      final code = file.readAsStringSync();
      for (final forbidden in [
        'createSignedUrl',
        'private_scan_path',
        'attachment_path',
        'SUPABASE_SERVICE_ROLE_KEY',
        'fetch(',
      ]) {
        expect(code, isNot(contains(forbidden)), reason: file.path);
      }
    }
  });

  test('direct mobile storage uploads are absent', () {
    // Every upload goes through the quarantined /v1 intent pipeline.
    final offenders = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .where((file) => file.readAsStringSync().contains('uploadBinary'))
        .map((file) => file.path)
        .toList();
    expect(offenders, isEmpty);
  });

  test('forward migration removes the direct upload policy', () {
    final migration = source(
      'supabase/migrations/202609090003_contain_unsafe_uploads.sql',
    );
    expect(
      migration,
      contains('drop policy if exists "private uploads own namespace"'),
    );
    expect(
      source('supabase/migrations/202609090001_tighten_student_access.sql'),
      contains('create policy "private uploads own namespace"'),
    );
  });

  test('forward migration removes anonymous privileged-function execution', () {
    final migration = source(
      'supabase/migrations/202609090004_lock_down_function_execute.sql',
    );
    for (final function in [
      'is_school_member',
      'is_class_teacher',
      'can_access_student',
      'can_access_classroom',
      'handle_new_auth_user',
      'rls_auto_enable',
    ]) {
      expect(migration, contains(function));
    }
    expect(migration, contains('from public, anon'));
    expect(migration, contains('revoke execute on functions from anon'));
  });

  group('native release checks (REL-002 cutover, ADR-0044)', () {
    final android = source('android/app/build.gradle.kts');
    final ios = source('ios/Runner.xcodeproj/project.pbxproj');
    final iosPhase = source('scripts/release/ios-release-check.sh');

    test('Android release: production under the contract, or development', () {
      // .github/scripts/check-android-release-guard.sh runs these cases in
      // CI; this pins the source so the allowlist cannot quietly widen.
      expect(
        android,
        contains('val releaseAppEnvs = setOf("production", "development")'),
      );
      expect(RegExp(r'releaseAppEnvs = ').allMatches(android), hasLength(1));
      // Every APP_ENV given must be the same allowed value; none is refused.
      expect(
        android,
        contains(
          'appEnvs.isEmpty() || appEnvs.distinct().size != 1 || '
          'appEnvs[0] !in releaseAppEnvs',
        ),
      );
      expect(android, contains('project.findProperty("dart-defines")'));
      // Production runs the shared Dart contract on the exact defines.
      expect(android, contains('checkProductionDefines(repositoryRoot)'));
      expect(android, contains('"tools/check_release_defines.dart"'));
      expect(android, contains('"--platform", "android"'));
      // The check still runs for any release task in the graph.
      expect(
        android,
        contains(
          'allTasks.none { it.name.contains("release", ignoreCase = true) }',
        ),
      );
      for (final widened in ['"staging"', '"synthetic"']) {
        expect(android, isNot(contains(widened)));
      }
      expect(android, isNot(contains('SEC-001: Android release')));
      expect(android, contains('com.studafy.light'));
    });

    test(
      'Android release signing never falls back to the debug key silently',
      () {
        expect(android, contains('STUDAFY_ANDROID_KEY_PROPERTIES'));
        expect(android, contains('Release signing: no upload key'));
        expect(android, contains('is inside the repository; keep it outside'));
        // The debug key is reachable only through the explicit local opt-in,
        // and a production build refuses that opt-in.
        expect(
          android,
          contains(
            'allowDebugSignedRelease -> signingConfigs.getByName("debug")',
          ),
        );
        expect(
          RegExp(r'signingConfigs\.getByName\("debug"\)').allMatches(android),
          hasLength(1),
        );
        expect(
          android,
          contains(
            'System.getenv("STUDAFY_ALLOW_DEBUG_SIGNED_RELEASE") == "true"',
          ),
        );
        expect(
          android,
          contains('STUDAFY_ALLOW_DEBUG_SIGNED_RELEASE is for the development'),
        );
      },
    );

    test('signing material stays out of the repository', () {
      // check-sensitive-files.sh refuses these if they are ever tracked.
      final ignore = source('.gitignore');
      for (final pattern in ['**/key.properties', '*.jks', '*.keystore']) {
        expect(ignore, contains(pattern));
      }
    });

    test('iOS release runs the defines check instead of the SEC-001 block', () {
      // .github/scripts/check-ios-release-guard.sh runs the phase script.
      expect(ios, isNot(contains('SEC-001')));
      expect(ios, contains('name = "Release Defines Check";'));
      expect(
        ios,
        contains(
          r'shellScript = "/bin/sh \"$SRCROOT/../scripts/release/'
          r'ios-release-check.sh\"\n";',
        ),
      );
      // It is the target's first build phase, so it runs before anything
      // compiles.
      expect(
        ios,
        contains(
          'buildPhases = (\n'
          '\t\t\t\t5EC001A12EC001A100000001 /* Release Defines Check */,',
        ),
      );
      expect(iosPhase, contains(r'if [ "${CONFIGURATION:-}" != "Release" ]'));
      expect(iosPhase, contains('tools/check_release_defines.dart'));
      expect(
        iosPhase,
        contains(r'--platform ios --encoded "${DART_DEFINES:-}"'),
      );
      expect(ios, contains('PRODUCT_BUNDLE_IDENTIFIER = com.studafy.light'));
      // Signing stays with the owner's local Xcode settings.
      expect(ios, isNot(contains('DEVELOPMENT_TEAM')));
    });
  });

  group('production defines (REL-002)', () {
    Map<String, Object?> example() =>
        jsonDecode(source('config/dart-defines.production.example.json'))
            as Map<String, Object?>;

    Map<String, List<String>> asBuild(Map<String, Object?> defines) => {
      for (final entry in defines.entries) entry.key: ['${entry.value}'],
      'FLUTTER_BUILD_NUMBER': ['2'],
    };

    Map<String, Object?> filled() => {
      ...example(),
      'SUPABASE_PUBLISHABLE_KEY': 'sb_publishable_xxxxxxxxxxxxxxxx',
      'SENTRY_DSN': '',
    };

    Map<String, String> filledStrings() => {
      for (final entry in filled().entries) entry.key: '${entry.value}',
    };

    test('the example carries the production values; only the key and the '
        'DSN are placeholders', () {
      final defines = example();
      expect(defines['APP_ENV'], 'production');
      expect(defines['STUDAFY_API_URL'], ProductionContract.apiUrl);
      expect(defines['SUPABASE_URL'], ProductionContract.supabaseUrl);
      expect(defines['TURNSTILE_ENABLED'], isTrue);
      expect(
        ProductionContract.problems(asBuild(defines), platform: 'ios'),
        unorderedEquals([
          contains('SUPABASE_PUBLISHABLE_KEY must be'),
          contains('SENTRY_DSN must be'),
        ]),
      );
      final text = source('config/dart-defines.production.example.json');
      expect(text, isNot(contains('sb_secret_')));
      expect(text, isNot(contains('SERVICE_ROLE')));
    });

    test('the filled example passes for both stores', () {
      for (final platform in ['android', 'ios']) {
        expect(
          ProductionContract.problems(asBuild(filled()), platform: platform),
          isEmpty,
          reason: platform,
        );
      }
    });

    test('the real production defines file is ignored', () {
      final ignore = source('.gitignore');
      expect(ignore, contains('\nconfig/dart-defines.production.json\n'));
      expect(ignore, contains('\n!config/dart-defines.*.example.json\n'));
    });

    test('a production app starts with the production defines', () {
      final policy = RuntimePolicy(
        StudafyEnvironment.production,
        releaseDefines: filledStrings(),
      );
      expect(policy.blocksApplicationStartup, isFalse);
      expect(policy.requiresRemoteBackend, isTrue);
      // DL-070: production offers uploads; the server's FILE-050/051
      // switches and the malware scan guard them.
      expect(policy.allowsRemoteFileUploads, isTrue);
    });

    test('a production app refuses incomplete or mismatched defines', () {
      final good = filledStrings();
      for (final bad in <Map<String, String>>[
        {},
        {...good, 'STUDAFY_API_URL': 'https://studafy-api-test.fly.dev'},
        {...good, 'SUPABASE_URL': 'https://zqbbsnqutrvlqcmtdlcx.supabase.co'},
        {...good, 'SUPABASE_PUBLISHABLE_KEY': ''},
        {...good, 'TURNSTILE_ENABLED': 'false'},
        {...good, 'STUDAFY_TERMS_URL': 'https://example.com/terms'},
        {...good, 'APP_ENV': 'development'},
      ]) {
        expect(
          RuntimePolicy(
            StudafyEnvironment.production,
            releaseDefines: bad,
          ).blocksApplicationStartup,
          isTrue,
          reason: '$bad',
        );
      }
      // A test run is not compiled with production's defines.
      expect(
        const RuntimePolicy(StudafyEnvironment.production)
            .blocksApplicationStartup,
        isTrue,
      );
    });
  });

  test('environment files are ignored and examples contain no real values', () {
    final ignore = source('.gitignore');
    expect(ignore, contains('**/.env.*'));
    expect(ignore, contains('!**/.env.example'));

    final mobileExample = source('config/dart-defines.synthetic.example.json');
    expect(mobileExample, contains('SUPABASE_PUBLISHABLE_KEY'));
    expect(mobileExample, isNot(contains('SERVICE_ROLE')));

    final remoteExample = source(
      'config/dart-defines.development.example.json',
    );
    expect(remoteExample, contains('"APP_ENV": "development"'));
    expect(remoteExample, contains('SUPABASE_PUBLISHABLE_KEY'));
    expect(remoteExample, isNot(contains('SERVICE_ROLE')));
  });
}
