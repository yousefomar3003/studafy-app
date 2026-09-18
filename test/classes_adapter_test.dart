import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:studafy/core/ids.dart';
import 'package:studafy/features/classes/data/preview_classroom_repository.dart';
import 'package:studafy/features/classes/domain/classroom.dart';

/// ARC-011 repository contract tests: the REAL preview adapter (SQLite via
/// StudafyDatabase) exercised against an ffi database. This proves the
/// adapter maps the seeded fixture rows onto typed entities correctly — the
/// same rows the legacy DatabaseClassesPage read as raw maps.
void main() {
  // The ffi factory stores databases under .dart_tool/sqflite_common_ffi/.
  // Clean up any leftover of this file's own database from a previous run
  // so the seed count is exact. Scoped to this one file rather than the
  // whole shared directory: other test files use the same ffi storage
  // directory for their own, differently-named databases, and a
  // directory-wide wipe would race their concurrently-running setup/teardown.
  const dbPath = '.dart_tool/sqflite_common_ffi/databases/studafy_preview.db';
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final leftover = File(dbPath);
    if (leftover.existsSync()) {
      leftover.deleteSync();
    }
  });

  tearDownAll(() {
    final leftover = File(dbPath);
    if (leftover.existsSync()) {
      leftover.deleteSync();
    }
  });

  group('PreviewClassroomRepository.listClasses', () {
    test('returns the four seeded classes as typed entities', () async {
      final repository = const PreviewClassroomRepository();
      final classes = await repository.listClasses();

      // The preview fixture seeds exactly 4 classes.
      expect(classes, hasLength(4));

      // Every class is typed — no Map<String, Object?> anywhere.
      for (final classroom in classes) {
        expect(classroom.id, isA<ClassroomId>());
        expect(classroom.name, isA<String>());
        expect(
          classroom.grade,
          isA<String>(),
          reason:
              'grade must be normalized to String for parity with '
              'the remote schema',
        );
        expect(classroom.section, isA<String>());
        expect(classroom.studentCount, isA<int>());
      }

      // Spot-check the first seeded class: Biology, Grade 10, Section B.
      final biology = classes.firstWhere(
        (c) => c.name == 'Biology' && c.section == 'B',
      );
      expect(biology.grade, '10');
      expect(biology.room, 'Lab 2');
      expect(biology.weeklySessions, greaterThan(0));
      expect(
        biology.studentCount,
        greaterThan(0),
        reason: 'the preview seeds 6 students enrolled in every class',
      );
    });

    test('typed entities expose no legacy map bridge', () {
      expect(
        File('lib/features/classes/domain/classroom.dart').readAsStringSync(),
        isNot(contains('toLegacyMap')),
      );
    });
  });

  group('PreviewClassroomRepository.createClass', () {
    test('creates a class and it appears in the next list', () async {
      final repository = const PreviewClassroomRepository();
      final before = await repository.listClasses();

      final draft = NewClassDraft(
        name: 'Physics',
        grade: 11,
        section: 'C',
        room: 'Lab 3',
        firstSessionStart: '10:00',
        firstSessionEnd: '10:50',
        weeklySessions: 1,
        sessions: const [
          ClassSessionDraft(weekday: 1, startTime: '10:00', endTime: '10:50'),
        ],
      );

      await repository.createClass(draft);

      final after = await repository.listClasses();
      expect(after.length, before.length + 1);

      final physics = after.firstWhere((c) => c.name == 'Physics');
      expect(physics.grade, '11');
      expect(physics.section, 'C');
      expect(physics.room, 'Lab 3');
      expect(
        physics.studentCount,
        0,
        reason: 'a new class has no enrollments yet',
      );
    });
  });

  group('PreviewClassroomRepository.inviteLinkFor', () {
    test('returns a non-empty link string for a seeded class', () async {
      final repository = const PreviewClassroomRepository();
      final classes = await repository.listClasses();
      final first = classes.first;

      final link = await repository.inviteLinkFor(first.id);
      expect(link, isNotEmpty);
    });
  });
}
