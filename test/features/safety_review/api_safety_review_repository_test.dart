import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/data/contracts/v1_client.generated.dart';
import 'package:studafy/data/contracts/v1_http_transport.dart';
import 'package:studafy/features/safety_review/data/api_safety_review_repository.dart';
import 'package:studafy/features/safety_review/domain/safety_review.dart';

const _school = '11111111-1111-4111-8111-111111111111';
const _reportId = '22222222-2222-4222-8222-222222222222';
const _grantId = '33333333-3333-4333-8333-333333333333';
const _operator = '44444444-4444-4444-8444-444444444444';

final _summary = SafetyReviewSummary(
  id: _reportId,
  schoolId: _school,
  kind: SafetyReviewKind.message,
  priority: SafetyReviewPriority.high,
  status: 'submitted',
  filedAt: DateTime.utc(2026, 10, 16, 9, 30),
  grantActive: false,
);

Map<String, dynamic> _report({
  String status = 'submitted',
  int version = 1,
  String? resolution,
}) => {
  'id': _reportId,
  'schoolId': _school,
  'kind': 'message',
  'status': status,
  'resolution': resolution,
  'priority': 'high',
  'assignedTo': null,
  'details': 'He keeps messaging me after I said stop',
  'evidenceSnapshot': {
    'messageBody': 'reported words',
    'senderId': _operator,
    'createdAt': '2026-10-16T09:00:00Z',
  },
  'classifierConfidence': null,
  'aupVersion': null,
  'contactConsent': false,
  'subjectUserId': null,
  'conversationId': null,
  'messageId': null,
  'reporterId': null,
  'createdAt': '2026-10-16T09:30:00Z',
  'updatedAt': '2026-10-16T09:30:00Z',
  'version': version,
  'events': [
    {
      'event': 'submitted',
      'at': '2026-10-16T09:30:00Z',
      'note': null,
      'resolution': null,
    },
  ],
  'evidence': [
    {
      'id': '55555555-5555-4555-8555-555555555555',
      'kind': 'note',
      'messageId': null,
      'attachmentFileId': null,
      'note': 'screenshot shared',
      'addedBy': _operator,
      'createdAt': '2026-10-16T09:40:00Z',
    },
  ],
};

Map<String, dynamic> _grant(String status, int version) => {
  'id': _grantId,
  'schoolId': _school,
  'requestedBy': _operator,
  'approvedBy': status == 'pending' ? null : _operator,
  'reason': 'alert received in the safety chat',
  'ticketRef': _reportId,
  'resourceScope': {
    'reportIds': [_reportId],
  },
  'status': status,
  'requiresSecondApprover': false,
  'expiresAt': '2026-10-16T10:30:00Z',
  'startedAt': status == 'active' ? '2026-10-16T09:31:00Z' : null,
  'endedAt': null,
  'version': version,
};

V1ApiException _problem(int status, String code) =>
    V1ApiException(status: status, code: code, message: code);

/// Answers each path with a canned body or a refusal, and records what was
/// sent.
class _Transport implements V1JsonTransport {
  final answers = <String, Object>{};
  final gets = <String>[];
  final posts = <({String path, Map<String, Object?> body, bool idempotent})>[];

  Object _answer(String path) {
    for (final entry in answers.entries) {
      if (path.startsWith(entry.key)) return entry.value;
    }
    throw StateError('no answer for $path');
  }

  @override
  Future<Map<String, dynamic>> get(String path) async {
    gets.add(path);
    final answer = _answer(path);
    if (answer is Exception) throw answer;
    return answer as Map<String, dynamic>;
  }

  @override
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, Object?> body, {
    String? idempotencyKey,
    bool requiresIdempotency = false,
  }) async {
    posts.add((path: path, body: body, idempotent: requiresIdempotency));
    final answer = _answer(path);
    if (answer is Exception) throw answer;
    return answer as Map<String, dynamic>;
  }
}

void main() {
  late _Transport transport;
  late List<String> codes;
  late ApiSafetyReviewRepository repository;

  setUp(() {
    transport = _Transport();
    codes = [];
    repository = ApiSafetyReviewRepository(
      V1ApiClient(transport),
      verify: (code) async => codes.add(code),
    );
  });

  Future<SafetyReviewError> failure(Future<Object?> call) async {
    try {
      await call;
    } on SafetyReviewException catch (error) {
      return error.error;
    }
    fail('expected a SafetyReviewException');
  }

  group('the queue', () {
    test('maps the metadata and single-reviewer mode', () async {
      transport.answers['/internal/safety-review/reports'] = {
        'items': [
          {
            'id': _reportId,
            'schoolId': _school,
            'kind': 'conversation',
            'priority': 'critical',
            'status': 'queued',
            'createdAt': '2026-10-16T09:30:00Z',
            'grantActive': true,
          },
        ],
        'nextCursor': null,
        'singleReviewer': true,
      };
      final queue = await repository.openReports();
      expect(queue.singleReviewer, isTrue);
      final report = queue.reports.single;
      expect(report.kind, SafetyReviewKind.conversation);
      expect(report.priority, SafetyReviewPriority.critical);
      expect(report.grantActive, isTrue);
      expect(report.shortId, '22222222');
      expect(report.filedAt.toUtc(), DateTime.utc(2026, 10, 16, 9, 30));
      expect(transport.gets.single, contains('pageSize=100'));
    });

    test('a refusal means the account is no operator', () async {
      transport.answers['/internal/safety-review/reports'] = _problem(
        403,
        'FORBIDDEN',
      );
      expect(
        await failure(repository.openReports()),
        SafetyReviewError.notOperator,
      );
    });

    test('anything unreadable is unavailable', () async {
      transport.answers['/internal/safety-review/reports'] = StateError('x');
      expect(
        await failure(repository.openReports()),
        SafetyReviewError.unavailable,
      );
    });
  });

  test('enrolment is the server\'s word', () async {
    transport.answers['/v1/auth/context'] = {
      'userId': _operator,
      'displayName': 'Operator',
      'locale': 'en',
      'memberships': <Object>[],
      'membershipVersion': 'none',
      'assuranceLevel': 'aal1',
      'mfaEnrolled': true,
      'mfaRequired': false,
      'pendingDeletion': false,
    };
    expect(await repository.secondFactorEnrolled(), isTrue);
  });

  group('the second factor', () {
    test('passes the code to the verifier', () async {
      await repository.presentSecondFactor('123456');
      expect(codes, ['123456']);
    });

    test('keeps the verifier\'s own answer', () async {
      repository = ApiSafetyReviewRepository(
        V1ApiClient(transport),
        verify: (_) async =>
            throw const SafetyReviewException(SafetyReviewError.wrongCode),
      );
      expect(
        await failure(repository.presentSecondFactor('000000')),
        SafetyReviewError.wrongCode,
      );
    });

    test('any other failure is unavailable', () async {
      repository = ApiSafetyReviewRepository(
        V1ApiClient(transport),
        verify: (_) async => throw StateError('offline'),
      );
      expect(
        await failure(repository.presentSecondFactor('000000')),
        SafetyReviewError.unavailable,
      );
    });
  });

  group('getting access', () {
    test('requests a one-report grant without a second approver, approves '
        'and starts it', () async {
      transport.answers['/internal/moderation/access/$_grantId/approve'] =
          _grant('approved', 2);
      transport.answers['/internal/moderation/access/$_grantId/start'] = _grant(
        'active',
        3,
      );
      transport.answers['/internal/moderation/access'] = _grant('pending', 1);

      await repository.obtainGrant(
        report: _summary,
        reason: 'alert received in the safety chat',
      );

      expect(transport.posts.map((post) => post.path), [
        '/internal/moderation/access',
        '/internal/moderation/access/$_grantId/approve',
        '/internal/moderation/access/$_grantId/start',
      ]);
      expect(transport.posts.every((post) => post.idempotent), isTrue);
      expect(transport.posts[0].body, {
        'schoolId': _school,
        'reason': 'alert received in the safety chat',
        'ticketRef': _reportId,
        'resourceScope': {
          'reportIds': [_reportId],
        },
        'requiresSecondApprover': false,
        'durationMinutes': 60,
      });
      expect(transport.posts[1].body, {'expectedVersion': 1});
      expect(transport.posts[2].body, {'expectedVersion': 2});
    });

    test('a refused approval means a second reviewer is needed', () async {
      transport.answers['/internal/moderation/access/$_grantId/approve'] =
          _problem(404, 'NOT_FOUND');
      transport.answers['/internal/moderation/access'] = _grant('pending', 1);
      expect(
        await failure(
          repository.obtainGrant(report: _summary, reason: 'a good reason'),
        ),
        SafetyReviewError.secondApproverRequired,
      );
      // Nothing is started.
      expect(transport.posts, hasLength(2));
    });

    test('a session without a second factor is asked for one', () async {
      transport.answers['/internal/moderation/access'] = _problem(
        403,
        'MFA_REQUIRED',
      );
      expect(
        await failure(
          repository.obtainGrant(report: _summary, reason: 'a good reason'),
        ),
        SafetyReviewError.stepUpRequired,
      );
    });
  });

  group('the report', () {
    test('maps the content, evidence and history', () async {
      transport.answers['/internal/safety-review/reports/$_reportId'] =
          _report();
      final report = await repository.openReport(_reportId);
      expect(report.details, 'He keeps messaging me after I said stop');
      expect(report.snapshot['messageBody'], 'reported words');
      expect(report.evidence.single.note, 'screenshot shared');
      expect(report.events.single.event, 'submitted');
      expect(report.reporterId, isNull);
      expect(report.decidable, isTrue);
    });

    test('a refusal means no grant covers it', () async {
      transport.answers['/internal/safety-review/reports/$_reportId'] =
          _problem(403, 'FORBIDDEN');
      expect(
        await failure(repository.openReport(_reportId)),
        SafetyReviewError.noGrant,
      );
    });

    test('MFA_REQUIRED asks for a code', () async {
      transport.answers['/internal/safety-review/reports/$_reportId'] =
          _problem(403, 'MFA_REQUIRED');
      expect(
        await failure(repository.openReport(_reportId)),
        SafetyReviewError.stepUpRequired,
      );
    });
  });

  group('the decision', () {
    final opened = SafetyReviewReport(
      id: _reportId,
      schoolId: _school,
      kind: SafetyReviewKind.message,
      priority: SafetyReviewPriority.high,
      status: 'submitted',
      details: 'details',
      snapshot: const {},
      evidence: const [],
      events: const [],
      filedAt: DateTime.utc(2026, 10, 16),
      version: 4,
    );

    test('a waiting report is triaged first, then resolved', () async {
      transport.answers['/internal/moderation/reports/$_reportId/triage'] =
          _report(status: 'under_review', version: 5);
      transport.answers['/internal/moderation/reports/$_reportId/resolve'] =
          _report(status: 'resolved', version: 6, resolution: 'not_upheld');

      final resolved = await repository.resolve(
        report: opened,
        outcome: SafetyReviewOutcome.notUpheld,
        note: 'Not a breach of the rules.',
      );

      expect(resolved.resolved, isTrue);
      expect(transport.posts[0].body['expectedVersion'], 4);
      expect(transport.posts[1].body, {
        'expectedVersion': 5,
        'resolution': 'not_upheld',
        'note': 'Not a breach of the rules.',
      });
    });

    test('a report under review is resolved directly', () async {
      transport.answers['/internal/moderation/reports/$_reportId/resolve'] =
          _report(status: 'resolved', version: 5, resolution: 'upheld');
      final underReview = SafetyReviewReport(
        id: _reportId,
        schoolId: _school,
        kind: SafetyReviewKind.message,
        priority: SafetyReviewPriority.high,
        status: 'under_review',
        details: 'details',
        snapshot: const {},
        evidence: const [],
        events: const [],
        filedAt: DateTime.utc(2026, 10, 16),
        version: 4,
      );
      await repository.resolve(
        report: underReview,
        outcome: SafetyReviewOutcome.upheld,
        note: 'Sender warned.',
      );
      expect(transport.posts.single.path, endsWith('/resolve'));
      expect(transport.posts.single.body['expectedVersion'], 4);
    });

    test('a hidden report means the grant has ended', () async {
      transport.answers['/internal/moderation/reports/$_reportId/triage'] =
          _problem(404, 'NOT_FOUND');
      expect(
        await failure(
          repository.resolve(
            report: opened,
            outcome: SafetyReviewOutcome.upheld,
            note: 'Sender warned.',
          ),
        ),
        SafetyReviewError.noGrant,
      );
    });

    test('a conflict means it changed', () async {
      transport.answers['/internal/moderation/reports/$_reportId/triage'] =
          _problem(409, 'VERSION_CONFLICT');
      expect(
        await failure(
          repository.resolve(
            report: opened,
            outcome: SafetyReviewOutcome.upheld,
            note: 'Sender warned.',
          ),
        ),
        SafetyReviewError.changed,
      );
    });
  });
}
