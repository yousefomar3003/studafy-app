import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/core/studafy_domain.dart';
import 'package:studafy/data/contracts/v1_client.generated.dart';
import 'package:studafy/features/school_operations/data/api_school_operations_repository.dart';

void main() {
  const schoolId = '11111111-1111-4111-8111-111111111111';
  const classroomId = '22222222-2222-4222-8222-222222222222';

  setUp(() {
    const membership = SchoolMembership(
      id: 'membership',
      schoolId: schoolId,
      schoolName: 'School',
      role: StudafyRole.schoolAdmin,
      active: true,
    );
    ActiveContextController.instance.hydrate(
      authenticatedProfile: const UserProfile(
        id: 'admin',
        displayName: 'Admin',
        email: 'admin@example.test',
        memberships: [membership],
      ),
      activeMembership: membership,
    );
  });

  tearDown(ActiveContextController.instance.signOut);

  test('term reads are scoped to the authenticated school', () async {
    final transport = _Transport();
    final repository = ApiSchoolOperationsRepository(V1ApiClient(transport));

    final terms = await repository.listTerms();

    expect(terms.single.name, 'Term 1');
    expect(transport.getPaths.single, contains('/schools/$schoolId/terms'));
  });

  test('a retried term creation keeps one idempotency key', () async {
    final transport = _Transport()..failFirstPost = true;
    final repository = ApiSchoolOperationsRepository(V1ApiClient(transport));
    final starts = DateTime(2026, 9, 1);
    final ends = DateTime(2026, 12, 20);

    await expectLater(
      repository.createTerm(name: 'Term 1', startsOn: starts, endsOn: ends),
      throwsStateError,
    );
    await repository.createTerm(name: 'Term 1', startsOn: starts, endsOn: ends);

    expect(transport.keys, hasLength(2));
    expect(transport.keys.first, transport.keys.last);
  });

  test('invalid meeting times are rejected before network access', () async {
    final transport = _Transport();
    final repository = ApiSchoolOperationsRepository(V1ApiClient(transport));
    final starts = DateTime(2026, 9, 21, 10);

    await expectLater(
      repository.requestMeeting(
        classroomId: classroomId,
        title: 'Parent meeting',
        startsAt: starts,
        endsAt: starts,
        audience: 'guardians',
      ),
      throwsFormatException,
    );
    expect(transport.postPaths, isEmpty);
  });

  test('transfer sends only record IDs and the target classroom', () async {
    final transport = _Transport();
    final repository = ApiSchoolOperationsRepository(V1ApiClient(transport));

    await repository.transferStudent(
      classroomId: classroomId,
      studentId: '33333333-3333-4333-8333-333333333333',
      targetClassroomId: '44444444-4444-4444-8444-444444444444',
    );

    expect(transport.postBodies.single, {
      'studentId': '33333333-3333-4333-8333-333333333333',
      'targetClassroomId': '44444444-4444-4444-8444-444444444444',
    });
    expect(transport.keys.single, isNotEmpty);
  });
}

class _Transport implements V1JsonTransport {
  final getPaths = <String>[];
  final postPaths = <String>[];
  final postBodies = <Map<String, Object?>>[];
  final keys = <String?>[];
  bool failFirstPost = false;

  @override
  Future<Map<String, dynamic>> get(String path) async {
    getPaths.add(path);
    return {
      'items': [
        {
          'id': '55555555-5555-4555-8555-555555555555',
          'schoolId': '11111111-1111-4111-8111-111111111111',
          'name': 'Term 1',
          'startsOn': '2026-09-01',
          'endsOn': '2026-12-20',
          'status': 'active',
        },
      ],
      'nextCursor': null,
    };
  }

  @override
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, Object?> body, {
    String? idempotencyKey,
    bool requiresIdempotency = false,
  }) async {
    postPaths.add(path);
    postBodies.add(body);
    keys.add(idempotencyKey);
    if (failFirstPost) {
      failFirstPost = false;
      throw StateError('response lost');
    }
    if (path.contains('/terms')) {
      return {
        'id': '55555555-5555-4555-8555-555555555555',
        'schoolId': '11111111-1111-4111-8111-111111111111',
        'name': body['name'],
        'startsOn': body['startsOn'],
        'endsOn': body['endsOn'],
        'status': 'active',
      };
    }
    return {
      'classroomId': '22222222-2222-4222-8222-222222222222',
      'studentId': body['studentId'],
      'status': 'active',
    };
  }
}
