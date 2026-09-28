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

  test('a retried student creation keeps one idempotency key', () async {
    final transport = _Transport()..failFirstPost = true;
    final repository = ApiSchoolOperationsRepository(
      V1ApiClient(transport),
      context: ActiveContextController.instance,
    );

    await expectLater(
      repository.createStudent(displayName: 'Sara Ali'),
      throwsStateError,
    );
    final student = await repository.createStudent(displayName: 'Sara Ali');

    expect(student.displayName, 'Sara Ali');
    expect(transport.postPaths.first, contains('/schools/$schoolId/students'));
    // The lost response is replayed, not repeated: both attempts share a key.
    expect(transport.keys, hasLength(2));
    expect(transport.keys.first, transport.keys.last);
  });

  test('invalid meeting times are rejected before network access', () async {
    final transport = _Transport();
    final repository = ApiSchoolOperationsRepository(
      V1ApiClient(transport),
      context: ActiveContextController.instance,
    );
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
    final repository = ApiSchoolOperationsRepository(
      V1ApiClient(transport),
      context: ActiveContextController.instance,
    );

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
  final postPaths = <String>[];
  final postBodies = <Map<String, Object?>>[];
  final keys = <String?>[];
  bool failFirstPost = false;

  @override
  Future<Map<String, dynamic>> get(String path) async =>
      throw UnimplementedError('no reads in these tests');

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
    if (path.endsWith('/students')) {
      return {
        'id': '55555555-5555-4555-8555-555555555555',
        'schoolId': '11111111-1111-4111-8111-111111111111',
        'userId': null,
        'studafyId': 'STU-0001',
        'displayName': body['displayName'],
        'provisional': true,
      };
    }
    return {
      'classroomId': '22222222-2222-4222-8222-222222222222',
      'studentId': body['studentId'],
      'status': 'active',
    };
  }
}
