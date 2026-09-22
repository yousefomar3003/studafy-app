import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/core/failures.dart';
import 'package:studafy/core/studafy_domain.dart';
import 'package:studafy/data/contracts/v1_client.generated.dart';
import 'package:studafy/features/academic/data/api_academic_repository.dart';
import 'package:studafy/features/academic/data/preview_academic_repository.dart';
import 'package:studafy/features/academic/domain/academic_repository.dart';

const schoolId = '11111111-1111-4111-8111-111111111111';
const classroomId = '22222222-2222-4222-8222-222222222222';
const studentId = '33333333-3333-4333-8333-333333333333';

void main() {
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
    'every feed calls its authoritative list route with school context',
    () async {
      final transport = _RecordingTransport();
      final repository = ApiAcademicRepository(V1ApiClient(transport));

      for (final feed in AcademicFeed.values) {
        final records = await repository.load(
          feed,
          classroomId: classroomId,
          studentId: studentId,
        );
        expect(records, isNotEmpty, reason: feed.name);
      }

      expect(transport.getPaths, hasLength(6));
      expect(transport.getPaths[0], startsWith('/v1/resources?'));
      expect(transport.getPaths[0], contains('schoolId=$schoolId'));
      expect(transport.getPaths[0], contains('classroomId=$classroomId'));
      expect(transport.getPaths[1], startsWith('/v1/assignments?'));
      expect(transport.getPaths[1], contains('studentId=$studentId'));
      expect(transport.getPaths[2], startsWith('/v1/assessments?'));
      expect(transport.getPaths[3], startsWith('/v1/grade-results?'));
      expect(transport.getPaths[4], startsWith('/v1/attendance?'));
      expect(transport.getPaths[5], startsWith('/v1/wellbeing?'));
    },
  );

  test('records are mapped from typed DTOs without local fallbacks', () async {
    final transport = _RecordingTransport();
    final repository = ApiAcademicRepository(V1ApiClient(transport));
    final records = await repository.load(AcademicFeed.assignments);
    expect(records.single.id, '44444444-4444-4444-8444-444444444444');
    expect(records.single.title, 'Atomic models');
    expect(records.single.state, 'published');
    expect(records.single.version, 2);
  });

  test('createAssignment sends the authoritative body once per key', () async {
    final transport = _RecordingTransport();
    final repository = ApiAcademicRepository(V1ApiClient(transport));
    final draft = AssignmentDraft(
      classroomId: classroomId,
      title: 'Atomic models',
      instructions: 'Draw and label.',
      dueAt: DateTime.parse('2026-10-01T10:00:00Z'),
      closesAt: DateTime.parse('2026-10-02T10:00:00Z'),
    );
    await repository.createAssignment(draft);

    expect(transport.posts, hasLength(1));
    final post = transport.posts.single;
    expect(post.path, '/v1/assignments');
    expect(post.key, isNotNull);
    expect(post.body, containsPair('dueAt', '2026-10-01T10:00:00.000Z'));
    expect(post.body, containsPair('closesAt', '2026-10-02T10:00:00.000Z'));
    expect(post.body, containsPair('classroomId', classroomId));
  });

  test(
    'an explicit retry preserves one idempotency key until success',
    () async {
      final transport = _RecordingTransport()..failNextPost = true;
      final repository = ApiAcademicRepository(V1ApiClient(transport));
      final draft = AssignmentDraft(
        classroomId: classroomId,
        title: 'Retry essay',
        instructions: '',
        dueAt: DateTime.parse('2026-10-01T10:00:00Z'),
      );
      await expectLater(repository.createAssignment(draft), throwsStateError);
      await repository.createAssignment(draft);
      expect(transport.posts, hasLength(2));
      expect(transport.posts[0].key, transport.posts[1].key);
    },
  );

  test('attendance and grade commands map their domain drafts', () async {
    final transport = _RecordingTransport();
    final repository = ApiAcademicRepository(V1ApiClient(transport));

    await repository.recordAttendance(
      classroomId,
      DateTime.parse('2026-09-21T05:00:00Z'),
      DateTime.parse('2026-09-21T06:00:00Z'),
      0,
      [
        const AttendanceDraft(studentId: studentId, state: 'present'),
        const AttendanceDraft(
          studentId: studentId,
          state: 'late',
          reason: 'bus',
        ),
      ],
    );
    final attendance = transport.posts[0];
    expect(attendance.path, '/v1/attendance/record');
    expect(attendance.body, containsPair('expectedVersion', 0));
    expect(
      (attendance.body['entries']! as List<Object?>).map(
        (e) => (e! as Map<String, Object?>)['state'],
      ),
      ['present', 'late'],
    );

    await repository.reviewGrade(
      '55555555-5555-4555-8555-555555555555',
      3,
      7.5,
    );
    final review = transport.posts[1];
    expect(
      review.path,
      '/v1/grade-results/55555555-5555-4555-8555-555555555555/review',
    );
    expect(review.body, containsPair('expectedVersion', 3));
    expect(review.body, containsPair('score', 7.5));
    // Optional nulls are omitted, which the strict server schema accepts.
    expect(review.body, isNot(contains('draftId')));
    expect(review.body, isNot(contains('questionScores')));

    await repository.publishGrade('55555555-5555-4555-8555-555555555555', 4);
    final publish = transport.posts[2];
    expect(
      publish.path,
      '/v1/grade-results/55555555-5555-4555-8555-555555555555/publish',
    );
    expect(publish.body, containsPair('expectedVersion', 4));
  });

  test('no active membership fails closed before any request', () async {
    ActiveContextController.instance.signOut();
    final transport = _RecordingTransport();
    final repository = ApiAcademicRepository(V1ApiClient(transport));
    await expectLater(
      repository.load(AcademicFeed.assignments),
      throwsA(isA<Failure>()),
    );
    expect(transport.getPaths, isEmpty);
  });

  test(
    'synthetic preview adapter follows the typed state/version contract',
    () async {
      final repository = PreviewAcademicRepository();
      const draft = TextResourceDraft(
        classroomId: classroomId,
        title: 'Preview lesson',
        body: 'Synthetic text only.',
      );
      await repository.createResource(draft);
      final created = (await repository.load(AcademicFeed.content)).single;
      expect(created.state, 'draft');
      expect(created.version, 1);

      await repository.publishResource(created.id, created.version);
      final published = (await repository.load(AcademicFeed.content)).single;
      expect(published.state, 'published');
      expect(published.version, 2);
    },
  );
}

class _RecordedPost {
  const _RecordedPost(this.path, this.body, this.key);
  final String path;
  final Map<String, Object?> body;
  final String? key;
}

class _RecordingTransport implements V1JsonTransport {
  final getPaths = <String>[];
  final posts = <_RecordedPost>[];
  bool failNextPost = false;

  static const _assignment = {
    'id': '44444444-4444-4444-8444-444444444444',
    'classroomId': classroomId,
    'title': 'Atomic models',
    'instructions': 'Draw and label.',
    'dueAt': '2026-10-01T10:00:00Z',
    'closesAt': null,
    'state': 'published',
    'version': 2,
    'submissionId': null,
    'submittedAt': null,
  };

  @override
  Future<Map<String, dynamic>> get(String path) async {
    getPaths.add(path);
    return {
      'items': [
        if (path.startsWith('/v1/resources'))
          {
            'id': '44444444-4444-4444-8444-444444444444',
            'schoolId': schoolId,
            'classroomId': classroomId,
            'title': 'Atomic models',
            'resourceType': 'lesson_note',
            'body': 'Draw and label.',
            'state': 'published',
            'version': 1,
            'publishedAt': '2026-09-15T08:00:00Z',
          }
        else if (path.startsWith('/v1/assignments'))
          _assignment
        else if (path.startsWith('/v1/assessments'))
          {
            'id': '44444444-4444-4444-8444-444444444444',
            'classroomId': classroomId,
            'title': 'Quiz',
            'category': 'quiz',
            'maximumScore': 10,
            'scheduledAt': null,
            'delivery': 'online',
            'state': 'published',
            'version': 1,
          }
        else if (path.startsWith('/v1/grade-results'))
          {
            'id': '44444444-4444-4444-8444-444444444444',
            'assessmentId': '66666666-6666-4666-8666-666666666666',
            'assessmentTitle': 'Unit 1 exam',
            'category': 'exam',
            'studentId': studentId,
            'score': 8,
            'maximumScore': 10,
            'feedback': null,
            'state': 'published',
            'version': 3,
            'reviewedAt': '2026-09-15T08:00:00Z',
            'publishedAt': '2026-09-15T09:00:00Z',
          }
        else if (path.startsWith('/v1/attendance'))
          {
            'id': '44444444-4444-4444-8444-444444444444',
            'sessionId': '77777777-7777-4777-8777-777777777777',
            'studentId': studentId,
            'state': 'present',
            'reason': null,
            'recordedAt': '2026-09-21T06:00:00Z',
          }
        else if (path.startsWith('/v1/wellbeing'))
          {
            'id': '44444444-4444-4444-8444-444444444444',
            'studentId': studentId,
            'classroomId': classroomId,
            'kind': 'note',
            'title': 'Settling in well',
            'context': null,
            'followUp': null,
            'visibility': 'class_staff',
            'severity': 'low',
            'createdAt': '2026-09-15T08:00:00Z',
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
    posts.add(_RecordedPost(path, body, idempotencyKey));
    if (failNextPost) {
      failNextPost = false;
      throw StateError('response lost');
    }
    if (path == '/v1/attendance/record') {
      return {
        'sessionId': '77777777-7777-4777-8777-777777777777',
        'version': 1,
        'recorded': 2,
      };
    }
    if (path.contains('/v1/grade-results/')) {
      return {
        'id': '55555555-5555-4555-8555-555555555555',
        'assessmentId': '66666666-6666-4666-8666-666666666666',
        'assessmentTitle': 'Unit 1 exam',
        'category': 'exam',
        'studentId': studentId,
        'score': 7.5,
        'maximumScore': 10,
        'feedback': null,
        'state': 'reviewed',
        'version': 4,
        'reviewedAt': '2026-09-15T08:00:00Z',
        'publishedAt': null,
      };
    }
    return Map<String, Object?>.from(_assignment);
  }
}
