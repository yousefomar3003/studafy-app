import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tools/check_dart_bounds.dart' as bounds;

void main() {
  late Directory fixture;

  setUp(() async {
    fixture = await Directory.systemTemp.createTemp('studafy-bounds-');
  });

  tearDown(() async {
    if (fixture.existsSync()) await fixture.delete(recursive: true);
  });

  test('allows presentation to depend on its application and domain', () async {
    await _write(
      fixture,
      'lib/features/classes/presentation/page.dart',
      "import '../application/load_classes.dart';\n"
          "import '../domain/classroom.dart';\n",
    );
    await _write(
      fixture,
      'lib/features/classes/application/load_classes.dart',
      "import '../domain/classroom.dart';\n",
    );
    await _write(
      fixture,
      'lib/features/classes/domain/classroom.dart',
      'class Classroom {}\n',
    );

    final result = bounds.checkDartBoundaries(fixture.path);
    expect(result.violations, isEmpty);
  });

  test('rejects provider packages imported by presentation', () async {
    await _write(
      fixture,
      'lib/features/classes/presentation/page.dart',
      "import 'package:supabase_flutter/supabase_flutter.dart';\n",
    );

    final result = bounds.checkDartBoundaries(fixture.path);
    expect(result.violations, hasLength(1));
    expect(
      result.violations.single,
      contains('provider packages are data-zone only'),
    );
  });

  test('rejects relative presentation to data imports', () async {
    await _write(
      fixture,
      'lib/features/classes/presentation/page.dart',
      "import '../data/repository.dart';\n",
    );
    await _write(
      fixture,
      'lib/features/classes/data/repository.dart',
      'class Repository {}\n',
    );

    final result = bounds.checkDartBoundaries(fixture.path);
    expect(result.violations, hasLength(1));
    expect(result.violations.single, contains('presentation imports data'));
  });

  test(
    'rejects hidden persistence calls inside presentation part files',
    () async {
      await _write(
        fixture,
        'lib/features/parent/presentation/parent_home.dart',
        "part of '../../../parent_features.dart';\n"
            'void load() => StudafyDatabase.instance.linkedChildren();\n',
      );

      final result = bounds.checkDartBoundaries(fixture.path);
      expect(result.violations, hasLength(1));
      expect(result.violations.single, contains('data-layer symbol'));
    },
  );
}

Future<void> _write(Directory root, String relative, String content) async {
  final file = File('${root.path}/$relative');
  await file.parent.create(recursive: true);
  await file.writeAsString(content);
}
