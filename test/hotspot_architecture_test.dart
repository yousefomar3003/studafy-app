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

  test('legacy presentation stays deleted', () {
    // The legacy teacher/student/parent libraries were removed once every
    // role shell ran on /v1 features. Nothing may bring them back, and no
    // screen may be split with `part` again: parts hide cross-feature
    // imports from tools/check_dart_bounds.dart.
    expect(Directory('lib/legacy').existsSync(), isFalse);
    for (final barrel in const [
      'lib/teacher_features.dart',
      'lib/student_features.dart',
      'lib/parent_features.dart',
    ]) {
      expect(File(barrel).existsSync(), isFalse, reason: barrel);
    }
    final parts = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .where((file) => !file.path.contains('/generated/'))
        .where((file) => !file.path.startsWith('lib/data/local/'))
        .where((file) => file.path != 'lib/studafy_database.dart')
        .where(
          (file) => file.readAsStringSync().contains(
            RegExp(r'^part ', multiLine: true),
          ),
        )
        .map((file) => file.path)
        .toList();
    expect(parts, isEmpty);
  });

  test('every public class name is defined once', () {
    // Two NotificationsPage classes once let the teacher shell open the
    // legacy offline page instead of the real one, silently, through an
    // import that happened to win. A name means one thing in this app.
    final definitions = <String, List<String>>{};
    final pattern = RegExp(
      r'^(?:abstract |sealed |final |base |interface )*(?:class|mixin|enum|extension type) ([A-Z]\w*)',
      multiLine: true,
    );
    for (final file
        in Directory('lib')
            .listSync(recursive: true)
            .whereType<File>()
            .where((file) => file.path.endsWith('.dart'))) {
      for (final match in pattern.allMatches(file.readAsStringSync())) {
        definitions.putIfAbsent(match.group(1)!, () => []).add(file.path);
      }
    }
    final duplicated = {
      for (final entry in definitions.entries)
        if (entry.value.length > 1) entry.key: entry.value,
    };
    expect(duplicated, isEmpty);
  });

  test('interface copy lives in the ARB files', () {
    // Screens used to carry their own English/Arabic pairs behind a
    // `languageCode == 'ar'` check, which skipped the translation parity
    // test and could not express Arabic plurals. All copy is AppL10n now.
    final offenders = <String>[];
    for (final file
        in Directory('lib')
            .listSync(recursive: true)
            .whereType<File>()
            .where((file) => file.path.endsWith('.dart'))
            .where((file) => !file.path.contains('/generated/'))) {
      final source = file.readAsStringSync();
      if (source.contains("languageCode == 'ar'") ||
          RegExp(r'String \w+\(String en, String ar').hasMatch(source)) {
        offenders.add(file.path);
      }
    }
    expect(offenders, isEmpty);
  });

  test('role shells never touch the preview database', () {
    for (final path in const [
      'lib/app/teacher_shell.dart',
      'lib/app/student_shell.dart',
      'lib/app/parent_shell.dart',
    ]) {
      final source = _source(path);
      expect(_lines(path), lessThan(600), reason: path);
      expect(source, isNot(contains('StudafyDatabase')), reason: path);
      expect(source, isNot(contains('StudafyBackend')), reason: path);
    }
  });

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

  test(
    'API-041 production academic boundary has no local or Supabase data calls',
    () {
      final productionAcademic = [
        'lib/app/app_dependencies.dart',
        'lib/app/teacher_shell.dart',
        'lib/features/academic/data/api_academic_repository.dart',
        'lib/features/classes/data/api_classroom_repository.dart',
        'lib/features/academic/presentation/academic_overview_page.dart',
      ];
      for (final path in productionAcademic) {
        final source = _source(path);
        expect(source, isNot(contains('StudafyDatabase')), reason: path);
        expect(source, isNot(contains(".from('")), reason: path);
        expect(source, isNot(contains('.rpc(')), reason: path);
        expect(source, isNot(contains('.functions.invoke')), reason: path);
      }
      expect(
        File('lib/features/classes/data/supabase_classroom_repository.dart')
            .existsSync(),
        isFalse,
      );
      expect(
        File('supabase/functions/approve-paper-grade/index.ts').existsSync(),
        isFalse,
      );
      expect(
        File('supabase/functions/publish-grade-result/index.ts').existsSync(),
        isFalse,
      );
      expect(
        _source('lib/studafy_database.dart'),
        contains('SQLite is a synthetic preview adapter only'),
      );
      expect(
        _source('lib/features/classes/domain/classroom.dart'),
        isNot(contains('toLegacyMap')),
      );
      expect(
        _source('lib/app/teacher_shell.dart'),
        isNot(contains('ClassWorkspacePage')),
      );
    },
  );
}
