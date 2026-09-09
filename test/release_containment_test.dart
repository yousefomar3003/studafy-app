import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test('unsafe grading path and provider flow are absent', () {
    final grading = source('supabase/functions/propose-paper-grade/index.ts');
    expect(grading, contains('AI_GRADING_DISABLED'));
    expect(grading, isNot(contains('private_scan_path')));
    expect(grading, isNot(contains('createSignedUrl')));
    expect(grading, isNot(contains('SUPABASE_SERVICE_ROLE_KEY')));
    expect(grading, isNot(contains('AI_GRADING_KEY')));
    expect(grading, isNot(contains('fetch(')));
  });

  test('Study Coach cannot sign or forward attachments', () {
    final coach = source('supabase/functions/study-coach/index.ts');
    final containment = source('supabase/functions/_shared/containment.ts');
    expect(coach, contains('rejectFileAttachment'));
    expect(containment, contains('FILE_UPLOADS_DISABLED'));
    expect(coach, isNot(contains('createSignedUrl')));
    expect(coach, isNot(contains('attachment_url')));
  });

  test('direct mobile storage uploads are absent', () {
    expect(
      source('lib/teacher_features.dart'),
      isNot(contains('uploadBinary')),
    );
    expect(
      source('lib/student_features.dart'),
      isNot(contains('uploadBinary')),
    );
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
  });
}
