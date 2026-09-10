import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _source(String path) => File(path).readAsStringSync();

int _lines(String path) => _source(path).split('\n').length;

void main() {
  test('main is limited to startup, app configuration, and routing', () {
    const path = 'lib/main.dart';
    expect(_lines(path), lessThan(350));
    expect(_source(path), isNot(contains('StudafyDatabase')));
    expect(_source(path), isNot(contains('StudafyBackend')));
    expect(_source(path), isNot(contains('rawQuery(')));
  });

  test(
    'parent feature is split and presentation has no persistence access',
    () {
      expect(_lines('lib/parent_features.dart'), lessThan(100));
      final modules = Directory('lib/features/parent/presentation')
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .toList();
      expect(modules.length, greaterThanOrEqualTo(12));
      for (final module in modules) {
        final source = module.readAsStringSync();
        expect(_lines(module.path), lessThan(650), reason: module.path);
        expect(source, isNot(contains('StudafyDatabase')), reason: module.path);
        expect(source, isNot(contains('StudafyBackend')), reason: module.path);
        expect(source, isNot(contains('.rawQuery(')), reason: module.path);
      }
    },
  );

  test('preview database facade delegates to bounded modules', () {
    expect(_lines('lib/studafy_database.dart'), lessThan(150));
    final modules = Directory('lib/data/local')
        .listSync()
        .whereType<File>()
        .where(
          (file) => file.path.startsWith('lib/data/local/studafy_database_'),
        )
        .toList();
    expect(modules, hasLength(6));
    for (final module in modules) {
      expect(_lines(module.path), lessThan(500), reason: module.path);
    }
  });

  test('teacher dashboard presentation is bounded and persistence-free', () {
    final modules = Directory('lib/features/teacher_dashboard/presentation')
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));
    for (final module in modules) {
      final source = module.readAsStringSync();
      expect(_lines(module.path), lessThan(500), reason: module.path);
      expect(source, isNot(contains('StudafyDatabase')), reason: module.path);
      expect(source, isNot(contains('StudafyBackend')), reason: module.path);
    }
  });

  test(
    'legacy teacher screens are split into bounded responsibility modules',
    () {
      expect(_lines('lib/teacher_features.dart'), lessThan(75));
      final modules = Directory('lib/legacy/teacher/presentation')
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .toList();
      expect(modules, hasLength(14));

      var previewDatabaseCalls = 0;
      for (final module in modules) {
        final source = module.readAsStringSync();
        expect(_lines(module.path), lessThan(600), reason: module.path);
        previewDatabaseCalls += 'StudafyDatabase.instance'
            .allMatches(source)
            .length;
      }

      // This legacy debt must fall as API-backed vertical slices replace it;
      // decomposition alone must never introduce more widget/database calls.
      expect(previewDatabaseCalls, lessThanOrEqualTo(62));
    },
  );

  test('Study Coach policy, domain, and provider adapter are separated', () {
    expect(File('lib/data/study_coach_repository.dart').existsSync(), isFalse);
    final application = _source(
      'lib/features/study_coach/application/study_coach_interactor.dart',
    );
    final domain = _source(
      'lib/features/study_coach/domain/study_coach_repository.dart',
    );
    final data = _source(
      'lib/features/study_coach/data/supabase_study_coach_repository.dart',
    );
    expect(
      application,
      contains('File attachments are temporarily unavailable'),
    );
    expect(application, isNot(contains('StudafyBackend')));
    expect(domain, isNot(contains('StudafyBackend')));
    expect(data, contains('StudafyBackend.client.functions.invoke'));
  });
}
