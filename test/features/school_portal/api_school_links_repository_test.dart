import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/core/failures.dart';
import 'package:studafy/data/contracts/v1_client.generated.dart';
import 'package:studafy/data/contracts/v1_http_transport.dart';
import 'package:studafy/features/school_portal/data/api_school_links_repository.dart';
import 'package:studafy/features/school_portal/domain/school_links.dart';

const _link = '22222222-2222-4222-8222-222222222222';

/// Answers each path with a canned body or a refusal, and records posts.
class _Transport implements V1JsonTransport {
  final answers = <String, Object>{};
  final posts = <({String path, Map<String, Object?> body})>[];

  Object _answer(String path) {
    for (final entry in answers.entries) {
      if (path.startsWith(entry.key)) return entry.value;
    }
    throw StateError('no answer for $path');
  }

  @override
  Future<Map<String, dynamic>> get(String path) async {
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
    posts.add((path: path, body: body));
    final answer = _answer(path);
    if (answer is Exception) throw answer;
    return answer as Map<String, dynamic>;
  }
}

void main() {
  late _Transport transport;
  late ApiSchoolLinksRepository repository;

  setUp(() {
    transport = _Transport();
    repository = ApiSchoolLinksRepository(V1ApiClient(transport));
  });

  test('reads requests and links, skipping a shape it cannot read', () async {
    transport.answers['/v1/me/school-links'] = {
      'links': [
        {
          'id': _link,
          'status': 'pending',
          'requestedAt': '2026-11-05T09:00:00Z',
          'decidedAt': null,
          'endedAt': null,
          'org': {
            'id': '33333333-3333-4333-8333-333333333333',
            'name': 'Cedar Grove',
            'city': 'Amman',
            'country': 'Jordan',
            'kind': 'private',
            'status': 'active',
          },
          'requestedBy': {
            'id': '44444444-4444-4444-8444-444444444444',
            'name': 'Huda Saleh',
            'email': 'head@cedar.example',
            'jobTitle': 'Principal',
          },
        },
        {'id': 'x', 'status': 'from-the-future'},
      ],
    };
    final links = await repository.list();
    expect(links, hasLength(1));
    expect(links.single.status, SchoolLinkStatus.pending);
    expect(links.single.org.name, 'Cedar Grove');
    expect(links.single.org.kind, SchoolKind.private);
    expect(links.single.requestedBy?.jobTitle, 'Principal');
  });

  test('accepting sends replaceCurrent only when the teacher agreed', () async {
    transport.answers['/v1/me/school-links/$_link/decision'] = {
      'linkId': _link,
      'status': 'linked',
    };
    await repository.decide(_link, accept: true);
    await repository.decide(_link, accept: true, replaceCurrent: true);
    await repository.decide(_link, accept: false, replaceCurrent: true);
    expect(transport.posts.map((post) => post.body).toList(), [
      {'decision': 'accept'},
      {'decision': 'accept', 'replaceCurrent': true},
      {'decision': 'decline'},
    ]);
  });

  test('a refusal keeps its code for the screen to explain', () async {
    transport.answers['/v1/me/school-links/$_link/decision'] =
        const V1ApiException(
          status: 409,
          code: 'LINKED_ELSEWHERE',
          message: 'LINKED_ELSEWHERE',
        );
    await expectLater(
      repository.decide(_link, accept: true),
      throwsA(isA<Failure>().having((f) => f.code, 'code', 'LINKED_ELSEWHERE')),
    );
  });

  test('a report sends the reason and leaves out empty words', () async {
    transport.answers['/v1/me/school-links/$_link/report'] = {
      'reportId': '55555555-5555-4555-8555-555555555555',
    };
    await repository.report(
      _link,
      reason: SchoolReportReason.fakeSchool,
      details: '  ',
    );
    expect(transport.posts.single.body, {'reason': 'fake_school'});
  });
}
