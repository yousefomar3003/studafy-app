import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/core/failures.dart';
import 'package:studafy/data/contracts/response_cache.dart';
import 'package:studafy/data/contracts/v1_http_transport.dart';

class MemoryCache implements ResponseCache {
  final entries = <String, Map<String, dynamic>>{};
  @override
  Future<Map<String, dynamic>?> read(String key) async => entries[key];
  @override
  Future<void> write(String key, Map<String, dynamic> body) async =>
      entries[key] = body;
}

/// A local server whose answer each test sets; `null` status drops the
/// connection as an unreachable server would.
class Server {
  late HttpServer _server;
  int? status = 200;
  Map<String, dynamic> body = {'items': []};
  int requests = 0;

  Future<Uri> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server.listen((request) async {
      requests += 1;
      await utf8.decoder.bind(request).join();
      final code = status;
      if (code == null) {
        await request.response.detachSocket().then((s) => s.destroy());
        return;
      }
      request.response
        ..statusCode = code
        ..headers.contentType = ContentType.json
        ..write(jsonEncode(body));
      await request.response.close();
    });
    return Uri.parse('http://127.0.0.1:${_server.port}');
  }

  Future<void> stop() => _server.close(force: true);
}

void main() {
  late Server server;
  late MemoryCache cache;
  late V1HttpTransport transport;

  setUp(() async {
    server = Server();
    cache = MemoryCache();
    transport = V1HttpTransport(
      baseUri: await server.start(),
      accessToken: () async => 'token',
      refreshSession: () async => false,
      onSessionLost: () {},
      // What is kept on the device, not the few seconds remembered in
      // memory, is what these tests are about.
      recentFor: Duration.zero,
    )..responseCache = cache;
  });

  tearDown(() async {
    transport.close();
    await server.stop();
  });

  test('a read is kept, and shown when the server cannot be reached', () async {
    server.body = {
      'items': ['Cells'],
    };
    expect(await transport.get('/v1/resources'), {
      'items': ['Cells'],
    });

    server.status = null;
    expect(await transport.get('/v1/resources'), {
      'items': ['Cells'],
    });

    server.status = 503;
    expect(await transport.get('/v1/resources'), {
      'items': ['Cells'],
    });
  });

  test('the server always wins while it answers', () async {
    await transport.get('/v1/resources');
    server.body = {
      'items': ['Newer'],
    };
    expect(await transport.get('/v1/resources'), {
      'items': ['Newer'],
    });
  });

  test('a refusal is never covered up by a kept copy', () async {
    await transport.get('/v1/resources');
    server
      ..status = 403
      ..body = {'code': 'FORBIDDEN', 'detail': 'No.'};
    await expectLater(
      transport.get('/v1/resources'),
      throwsA(isA<V1ApiException>()),
    );
  });

  test('offline with nothing kept still reports the connection', () async {
    server.status = null;
    await expectLater(
      transport.get('/v1/grade-results'),
      throwsA(
        predicate<Object>(
          (e) => Failure.fromError(e).code == Failure.networkCode,
        ),
      ),
    );
  });

  test('a lesson quiz, made once on the server, is kept like a read', () async {
    server.body = {'kind': 'quiz', 'questions': []};
    await transport.post('/v1/resources/r1/study-set', {
      'kind': 'quiz',
    }, requiresIdempotency: true);
    server.status = null;
    expect(
      await transport.post('/v1/resources/r1/study-set', {
        'kind': 'quiz',
      }, requiresIdempotency: true),
      {'kind': 'quiz', 'questions': []},
    );
  });

  test('what is never kept', () {
    for (final path in [
      '/v1/me',
      '/v1/auth/context',
      '/v1/billing/entitlements',
      '/v1/files/f1',
      '/v1/uploads/u1',
      '/v1/account/export-download',
      '/v1/classrooms/c1/join-link',
      '/v1/wellbeing',
      '/v1/reports?cursor=x',
      '/v1/control-panel/content-controls/s1',
      // A safety report under review, and the operator's queue (DL-063).
      '/internal/safety-review/reports',
      '/internal/safety-review/reports?pageSize=100',
      '/internal/safety-review/reports/r1',
      '/internal/moderation/access?schoolId=s1',
    ]) {
      expect(V1HttpTransport.keeps('GET', path), isFalse, reason: path);
    }
    for (final path in [
      '/v1/me/study-plan',
      '/v1/me/notebooks',
      '/v1/classrooms',
      '/v1/resources?classroomId=c1',
      '/v1/conversations/c1/messages',
      '/v1/notifications',
      '/v1/grade-results',
    ]) {
      expect(V1HttpTransport.keeps('GET', path), isTrue, reason: path);
    }
    // Other commands are never replayed from the device.
    expect(V1HttpTransport.keeps('POST', '/v1/study-assistant/ask'), isFalse);
    expect(
      V1HttpTransport.keeps('POST', '/v1/classrooms/c1/notebook'),
      isFalse,
    );
  });
}
