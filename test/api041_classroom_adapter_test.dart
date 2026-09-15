import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/core/studafy_domain.dart';
import 'package:studafy/data/contracts/v1_client.generated.dart';
import 'package:studafy/features/classes/data/api_classroom_repository.dart';
import 'package:studafy/features/classes/domain/classroom.dart';

void main() {
  const schoolId = '11111111-1111-4111-8111-111111111111';

  setUp(() {
    ActiveContextController.instance.hydrate(
      authenticatedProfile: const UserProfile(
        id: 'actor',
        displayName: 'Teacher',
        email: 'teacher@example.test',
        memberships: [
          SchoolMembership(
            id: 'membership',
            schoolId: schoolId,
            schoolName: 'School',
            role: StudafyRole.teacher,
            active: true,
          ),
        ],
      ),
      activeMembership: const SchoolMembership(
        id: 'membership',
        schoolId: schoolId,
        schoolName: 'School',
        role: StudafyRole.teacher,
        active: true,
      ),
    );
  });

  tearDown(ActiveContextController.instance.signOut);

  test(
    'remote list maps typed authoritative DTOs and sends school context',
    () async {
      final transport = _AcademicTransport();
      final repository = ApiClassroomRepository(V1ApiClient(transport));
      final classes = await repository.listClasses();
      expect(classes.single.name, 'Biology');
      expect(classes.single.id.value, '22222222-2222-4222-8222-222222222222');
      expect(transport.getPaths.single, contains('schoolId=$schoolId'));
    },
  );

  test('explicit retry preserves one idempotency key until success', () async {
    final transport = _AcademicTransport()..failFirstPost = true;
    final repository = ApiClassroomRepository(V1ApiClient(transport));
    const draft = NewClassDraft(
      name: 'Biology',
      grade: 10,
      section: 'A',
      room: 'Lab',
      firstSessionStart: '08:00',
      firstSessionEnd: '09:00',
      weeklySessions: 1,
      sessions: [
        ClassSessionDraft(weekday: 1, startTime: '08:00', endTime: '09:00'),
      ],
    );
    await expectLater(repository.createClass(draft), throwsStateError);
    await repository.createClass(draft);
    expect(transport.keys, hasLength(2));
    expect(transport.keys[0], transport.keys[1]);
  });
}

class _AcademicTransport implements V1JsonTransport {
  final getPaths = <String>[];
  final keys = <String?>[];
  bool failFirstPost = false;

  @override
  Future<Map<String, dynamic>> get(String path) async {
    getPaths.add(path);
    return {
      'items': [
        {
          'id': '22222222-2222-4222-8222-222222222222',
          'schoolId': '11111111-1111-4111-8111-111111111111',
          'termId': '33333333-3333-4333-8333-333333333333',
          'name': 'Biology',
          'grade': '10',
          'section': 'A',
          'room': 'Lab',
          'status': 'active',
          'version': 1,
          'studentCount': 12,
          'weeklySessions': 2,
          'termName': 'Term 1',
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
    keys.add(idempotencyKey);
    if (failFirstPost) {
      failFirstPost = false;
      throw StateError('response lost');
    }
    return {
      'id': '22222222-2222-4222-8222-222222222222',
      'schoolId': '11111111-1111-4111-8111-111111111111',
      'termId': '33333333-3333-4333-8333-333333333333',
      'name': body['name'],
      'grade': body['grade'],
      'section': body['section'],
      'room': body['room'],
      'status': 'active',
      'version': 1,
      'studentCount': 0,
      'weeklySessions': 1,
      'termName': 'Term 1',
    };
  }
}
