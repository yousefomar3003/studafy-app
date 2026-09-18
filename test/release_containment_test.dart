import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

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
    expect(
      source('lib/teacher_features.dart'),
      isNot(contains('uploadBinary')),
    );
    final studentPresentation = <String>[
      source('lib/student_features.dart'),
      ...Directory('lib/legacy/student/presentation')
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .map((file) => file.readAsStringSync()),
    ].join('\n');
    expect(studentPresentation, isNot(contains('uploadBinary')));
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

  test('native release guards cover known prototype release risks', () {
    final android = source('android/app/build.gradle.kts');
    expect(android, contains('SEC-001: Android release builds are blocked'));
    expect(android, contains('com.example.studafy'));
    expect(android, contains('signingConfigs.getByName("debug")'));

    final ios = source('ios/Runner.xcodeproj/project.pbxproj');
    expect(ios, contains('SEC-001 Release Block'));
    expect(
      ios,
      contains('SEC-001: iOS archives and release builds are blocked'),
    );
    expect(ios, contains('PRODUCT_BUNDLE_IDENTIFIER = com.example.studafy'));
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
