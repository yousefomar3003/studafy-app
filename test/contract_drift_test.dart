import 'dart:convert';
import 'dart:io' show File;

import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/data/contracts/v1_dto.dart';

/// ARC-011 contract drift test: the Dart DTOs must parse the shared fixture
/// that the TypeScript contracts package (packages/contracts/src/v1) also
/// validates. If either side changes a field name or type without updating
/// the other, this test fails.
void main() {
  // The fixture is a Dart asset; in CI it resolves from the package root.
  final fixturePath = 'lib/data/contracts/v1_fixture.json';
  late Map<String, dynamic> fixture;

  setUpAll(() {
    final file = File(fixturePath);
    if (!file.existsSync()) {
      fail('Contract fixture not found at $fixturePath');
    }
    fixture = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  });

  group('V1MeResponseDto contract drift', () {
    test('parses the shared /v1/me fixture', () {
      final dto = V1MeResponseDto.fromJson(
        fixture['me'] as Map<String, dynamic>,
      );

      expect(dto.id, '00000000-0000-4000-8000-000000000001');
      expect(dto.displayName, 'Rana Haddad');
      expect(dto.memberships, hasLength(1));
      expect(dto.memberships.first.role, 'teacher');
      expect(dto.memberships.first.schoolName, 'Al-Noor International');
      expect(dto.activeTermId, '00000000-0000-4000-8000-0000000000cc');
    });

    test('round-trips the fixture without field loss', () {
      final original = fixture['me'] as Map<String, dynamic>;
      final dto = V1MeResponseDto.fromJson(original);
      final serialized = dto.toJson();

      expect(serialized['id'], original['id']);
      expect(serialized['displayName'], original['displayName']);
      expect(
        (serialized['memberships'] as List).first,
        (original['memberships'] as List).first,
      );
      expect(serialized['activeTermId'], original['activeTermId']);
    });
  });

  group('V1ClassroomListResponseDto contract drift', () {
    test('parses the shared /v1/classrooms fixture', () {
      final dto = V1ClassroomListResponseDto.fromJson(
        fixture['classrooms'] as Map<String, dynamic>,
      );

      expect(dto.classrooms, hasLength(2));
      expect(dto.classrooms.first.name, 'Biology');
      expect(dto.classrooms.first.grade, '10');
      expect(dto.classrooms.first.room, 'Lab 2');
      expect(dto.classrooms.first.studentCount, 6);
      expect(dto.classrooms[1].room, isNull);
      expect(dto.classrooms[1].weeklySessions, isNull);
    });

    test('round-trips nullable fields correctly', () {
      final original = fixture['classrooms'] as Map<String, dynamic>;
      final dto = V1ClassroomListResponseDto.fromJson(original);
      final serialized = dto.toJson();

      final first =
          (serialized['classrooms'] as List).first as Map<String, Object?>;
      final second =
          (serialized['classrooms'] as List).last as Map<String, Object?>;
      expect(first['room'], 'Lab 2');
      expect(second['room'], isNull);
      expect(second['weeklySessions'], isNull);
      expect(second['termName'], isNull);
    });
  });

  test('generated client uses the declared /v1 operation paths', () async {
    final transport = _FixtureTransport(fixture);
    final client = V1ApiClient(transport);

    final me = await client.getMe();
    expect(me.memberships.first.role, 'teacher');
    expect(transport.paths, ['/v1/me']);
  });
}

class _FixtureTransport implements V1JsonTransport {
  _FixtureTransport(this.fixture);

  final Map<String, dynamic> fixture;
  final List<String> paths = [];

  @override
  Future<Map<String, dynamic>> get(String path) async {
    paths.add(path);
    return switch (path) {
      '/v1/me' => fixture['me'] as Map<String, dynamic>,
      '/v1/classrooms' => fixture['classrooms'] as Map<String, dynamic>,
      _ => throw StateError('Unexpected generated-client path'),
    };
  }

  @override
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, Object?> body, {
    String? idempotencyKey,
    bool requiresIdempotency = false,
  }) async {
    // The drift fixture covers reads only; a write reaching here means the
    // spec grew an operation the fixture has not been extended for.
    throw StateError('Unexpected generated-client write to $path');
  }
}
