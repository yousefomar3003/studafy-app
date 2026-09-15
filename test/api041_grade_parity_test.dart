import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/core/studafy_domain.dart';
import 'package:studafy/data/contracts/v1_client.generated.dart';
import 'package:studafy/data/studafy_repository.dart';
import 'package:studafy/features/academic/data/api_paper_grading_repository.dart';

/// API-041 parity proof for removing the `approve-paper-grade` and
/// `publish-grade-result` Edge Functions. The fixture mirrors the exact
/// scenario the SQL suite grades end to end: a teacher reviewing a linked
/// draft with one overridden question score, then publishing. The adapter
/// must emit the identical authoritative payloads through /v1.
void main() {
  final fixture = jsonDecode(
    File('test/fixtures/api041_grade_parity.json').readAsStringSync(),
  ) as Map<String, dynamic>;

  final gradeResultId = fixture['gradeResultId']! as String;
  final draftId = fixture['draftId']! as String;
  final expectedVersion = fixture['expectedVersion']! as int;
  final expectedScore = fixture['score']! as num;
  final questionScores = (fixture['questionScores']! as List<dynamic>)
      .map((e) => e! as Map<String, dynamic>)
      .toList();

  final suggestions = [
    for (final score in questionScores)
      QuestionSuggestion(
        questionId: score['questionId']! as String,
        proposedScore: (score['score']! as num).toDouble(),
        maximumScore: 6,
        confidence: 0.9,
        rationale: (score['reason'] as String?) ?? '',
      ),
  ];

  late _GradeTransport transport;
  late ApiPaperGradingRepository repository;

  setUp(() {
    transport = _GradeTransport();
    repository = ApiPaperGradingRepository(V1ApiClient(transport));
  });

  test('review emits the exact approve-paper-grade parity payload', () async {
    await repository.reviewDraft(
      gradeResultId: gradeResultId,
      expectedVersion: expectedVersion,
      draftId: draftId,
      finalScores: suggestions,
    );

    expect(transport.posts, hasLength(1));
    final post = transport.posts.single;
    expect(post.path, '/v1/grade-results/$gradeResultId/review');
    expect(post.key, isNotNull);
    expect(post.body, {
      'expectedVersion': expectedVersion,
      'score': expectedScore,
      'feedback': null,
      'draftId': draftId,
      'questionScores': [
        for (final score in questionScores)
          {
            'questionId': score['questionId'],
            'score': score['score'],
            'reason': score['reason'],
          },
      ],
    });
  });

  test(
    'a lost review response retries with the same idempotency key',
    () async {
      transport.failNextPost = true;
      await expectLater(
        repository.reviewDraft(
          gradeResultId: gradeResultId,
          expectedVersion: expectedVersion,
          draftId: draftId,
          finalScores: suggestions,
        ),
        throwsStateError,
      );
      await repository.reviewDraft(
        gradeResultId: gradeResultId,
        expectedVersion: expectedVersion,
        draftId: draftId,
        finalScores: suggestions,
      );
      expect(transport.posts, hasLength(2));
      expect(transport.posts[0].key, transport.posts[1].key);
    },
  );

  test('publish emits the publish-grade-result parity payload', () async {
    await repository.publishGradeResult(
      gradeResultId: gradeResultId,
      expectedVersion: expectedVersion + 1,
    );
    final post = transport.posts.single;
    expect(post.path, '/v1/grade-results/$gradeResultId/publish');
    expect(post.body, {'expectedVersion': expectedVersion + 1});
    expect(post.key, isNotNull);

    transport.failNextPost = true;
    await expectLater(
      repository.publishGradeResult(
        gradeResultId: gradeResultId,
        expectedVersion: expectedVersion + 1,
      ),
      throwsStateError,
    );
    await repository.publishGradeResult(
      gradeResultId: gradeResultId,
      expectedVersion: expectedVersion + 1,
    );
    expect(transport.posts, hasLength(3));
    expect(transport.posts[1].key, transport.posts[2].key);
  });

  test('AI proposal remains contained until AI-072', () async {
    await expectLater(
      repository.proposeGrade(
        submissionId: 'submission',
        privateScan: Uri.parse('papers/another-user/private.pdf'),
        strictness: GradingStrictness.balanced,
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          'AI grading is temporarily unavailable.',
        ),
      ),
    );
    expect(transport.posts, isEmpty);
  });
}

class _GradeTransport implements V1JsonTransport {
  final posts = <({String path, Map<String, Object?> body, String? key})>[];
  bool failNextPost = false;

  @override
  Future<Map<String, dynamic>> get(String path) async {
    throw StateError('paper grading never reads');
  }

  @override
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, Object?> body, {
    String? idempotencyKey,
    bool requiresIdempotency = false,
  }) async {
    posts.add((path: path, body: body, key: idempotencyKey));
    if (failNextPost) {
      failNextPost = false;
      throw StateError('response lost');
    }
    return {
      'id': 'a0410000-0000-4000-8000-000000000051',
      'assessmentId': 'a0410000-0000-4000-8000-000000000050',
      'studentId': 'abcf0000-0000-4000-8000-000000000008',
      'score': 8,
      'maximumScore': 10,
      'feedback': null,
      'state': path.endsWith('/review') ? 'reviewed' : 'published',
      'version': path.endsWith('/review') ? 2 : 3,
      'reviewedAt': '2026-09-15T08:00:00Z',
      'publishedAt': path.endsWith('/publish') ? '2026-09-15T09:00:00Z' : null,
    };
  }
}
