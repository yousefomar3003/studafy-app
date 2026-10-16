import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
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

  group(
    'native release guards (SEC-001, narrowed for Android by ADR-0042)',
    () {
      final android = source('android/app/build.gradle.kts');
      final ios = source('ios/Runner.xcodeproj/project.pbxproj');

      test('Android release is allowed for the development test copy only', () {
        // .github/scripts/check-android-release-guard.sh runs these cases in
        // CI; this pins the source so the allowlist cannot quietly widen.
        expect(
          android,
          contains('SEC-001: Android release builds are blocked'),
        );
        expect(android, contains('val sec001ReleaseAppEnv = "development"'));
        expect(
          RegExp(r'sec001ReleaseAppEnv = ').allMatches(android),
          hasLength(1),
          reason: 'exactly one allowed APP_ENV',
        );
        // Every APP_ENV given must match, and none given is refused.
        expect(
          android,
          contains(
            'appEnvs.isEmpty() || appEnvs.any { it != sec001ReleaseAppEnv }',
          ),
        );
        expect(android, contains('project.findProperty("dart-defines")'));
        // The guard still runs for any release task in the graph.
        expect(
          android,
          contains(
            'allTasks.none { it.name.contains("release", ignoreCase = true) }',
          ),
        );
        for (final widened in ['"production"', '"staging"', '"synthetic"']) {
          expect(android, isNot(contains(widened)));
        }
        expect(android, contains('com.studafy.light'));
      });

      test(
        'Android release signing never falls back to the debug key silently',
        () {
          expect(android, contains('STUDAFY_ANDROID_KEY_PROPERTIES'));
          expect(android, contains('Release signing: no upload key'));
          expect(
            android,
            contains('is inside the repository; keep it outside'),
          );
          // The debug key is reachable only through the explicit local opt-in.
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
        },
      );

      test('signing material stays out of the repository', () {
        // check-sensitive-files.sh refuses these if they are ever tracked.
        final ignore = source('.gitignore');
        for (final pattern in ['**/key.properties', '*.jks', '*.keystore']) {
          expect(ignore, contains(pattern));
        }
      });

      test('the app the Android release carries is the development copy', () {
        // The Gradle guard admits only APP_ENV=development, which starts.
        // Production, refused by Gradle, would also refuse to start.
        expect(
          RuntimePolicy.parse('development').blocksApplicationStartup,
          isFalse,
        );
        expect(
          RuntimePolicy.parse('production').blocksApplicationStartup,
          isTrue,
        );
      });

      test('iOS release stays blocked whatever the environment', () {
        expect(ios, contains('SEC-001 Release Block'));
        expect(
          ios,
          contains('SEC-001: iOS archives and release builds are blocked'),
        );
        // The Xcode phase checks only the configuration; no APP_ENV or other
        // escape exists for iOS.
        expect(
          ios,
          contains(
            r'shellScript = "if [ \"$CONFIGURATION\" = \"Release\" ]; then',
          ),
        );
        expect(ios, isNot(contains('APP_ENV')));
        expect(ios, contains('PRODUCT_BUNDLE_IDENTIFIER = com.studafy.light'));
      });
    },
  );

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
