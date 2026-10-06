import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/core/failures.dart';
import 'package:studafy/data/contracts/response_cache.dart';
import 'package:studafy/data/contracts/v1_http_transport.dart';

void main() {
  test(
    'a generated idempotency key survives the internal auth retry',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final keys = <String?>[];
      var calls = 0;
      final serving = server.listen((request) async {
        keys.add(request.headers.value('Idempotency-Key'));
        await utf8.decoder.bind(request).join();
        calls += 1;
        request.response.headers.contentType = ContentType.json;
        if (calls == 1) {
          request.response.statusCode = 401;
          request.response.write(
            jsonEncode({
              'type': 'https://api.studafy.io/problems/unauthenticated',
              'title': 'Authentication required',
              'status': 401,
              'code': 'UNAUTHENTICATED',
              'detail': 'Authentication required.',
              'requestId': 'request-one',
            }),
          );
        } else {
          request.response.write(jsonEncode({'ok': true}));
        }
        await request.response.close();
      });
      var refreshes = 0;
      final transport = V1HttpTransport(
        baseUri: Uri.parse('http://127.0.0.1:${server.port}'),
        accessToken: () async => 'synthetic-token',
        refreshSession: () async {
          refreshes += 1;
          return true;
        },
        onSessionLost: () {},
      );

      try {
        expect(
          await transport.post('/command', const {
            'value': 1,
          }, requiresIdempotency: true),
          {'ok': true},
        );
        expect(refreshes, 1);
        expect(keys, hasLength(2));
        expect(keys.first, isNotNull);
        // The format the server accepts (API-040).
        expect(
          keys.first,
          matches(RegExp(r'^[A-Za-z0-9][A-Za-z0-9._:-]{15,127}$')),
        );
        expect(keys.last, keys.first);
      } finally {
        transport.close();
        await server.close(force: true);
        await serving.cancel();
      }
    },
  );

  test('caller keys are forwarded and top-level problem details are parsed', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    String? receivedKey;
    final serving = server.listen((request) async {
      receivedKey = request.headers.value('Idempotency-Key');
      await utf8.decoder.bind(request).join();
      request.response
        ..statusCode = 409
        ..headers.contentType = ContentType.json
        ..write(
          jsonEncode({
            'type': 'https://api.studafy.io/problems/idempotency-key-reused',
            'title': 'Idempotency key reused',
            'status': 409,
            'code': 'IDEMPOTENCY_KEY_REUSED',
            'detail':
                'The idempotency key was already used for a different request.',
            'requestId': 'request-two',
          }),
        );
      await request.response.close();
    });
    final transport = V1HttpTransport(
      baseUri: Uri.parse('http://127.0.0.1:${server.port}'),
      accessToken: () async => 'synthetic-token',
      refreshSession: () async => false,
      onSessionLost: () {},
    );

    try {
      await expectLater(
        transport.post(
          '/command',
          const {'value': 1},
          idempotencyKey: 'caller-key-00000001',
          requiresIdempotency: true,
        ),
        throwsA(
          isA<V1ApiException>()
              .having((error) => error.code, 'code', 'IDEMPOTENCY_KEY_REUSED')
              .having((error) => error.requestId, 'requestId', 'request-two'),
        ),
      );
      expect(receivedKey, 'caller-key-00000001');
    } finally {
      transport.close();
      await server.close(force: true);
      await serving.cancel();
    }
  });

  test('a read already in flight is shared, not sent twice', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    var calls = 0;
    final serving = server.listen((request) async {
      calls += 1;
      await Future<void>.delayed(const Duration(milliseconds: 50));
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({'n': calls}));
      await request.response.close();
    });
    var token = 'first-account';
    final transport = V1HttpTransport(
      baseUri: Uri.parse('http://127.0.0.1:${server.port}'),
      accessToken: () async => token,
      refreshSession: () async => false,
      onSessionLost: () {},
      // Only reads in flight here; remembered answers are tested below.
      recentFor: Duration.zero,
    );
    try {
      final both = await Future.wait([
        transport.get('/v1/classrooms'),
        transport.get('/v1/classrooms'),
      ]);
      expect(
        calls,
        1,
        reason: 'two identical reads in flight make one request',
      );
      expect(both[0], both[1]);

      // Once it has completed, the next read goes to the server again.
      await transport.get('/v1/classrooms');
      expect(calls, 2);

      // Another account never shares the first account's read.
      final first = transport.get('/v1/classrooms');
      token = 'second-account';
      final second = transport.get('/v1/classrooms');
      await Future.wait([first, second]);
      expect(calls, 4);
    } finally {
      await serving.cancel();
      await server.close(force: true);
    }
  });

  group('reads answered moments ago', () {
    late HttpServer server;
    late StreamSubscription<HttpRequest> serving;
    late V1HttpTransport transport;
    var calls = 0;
    var now = DateTime(2026, 10, 4, 9);

    setUp(() async {
      calls = 0;
      now = DateTime(2026, 10, 4, 9);
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      serving = server.listen((request) async {
        await utf8.decoder.bind(request).join();
        calls += 1;
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode({'n': calls}));
        await request.response.close();
      });
      transport = V1HttpTransport(
        baseUri: Uri.parse('http://127.0.0.1:${server.port}'),
        accessToken: () async => 'token',
        refreshSession: () async => false,
        onSessionLost: () {},
        now: () => now,
      );
    });

    tearDown(() async {
      transport.close();
      await serving.cancel();
      await server.close(force: true);
    });

    test('are reused for a few seconds, then read again', () async {
      expect(await transport.get('/v1/classrooms'), {'n': 1});
      now = now.add(const Duration(seconds: 5));
      expect(await transport.get('/v1/classrooms'), {'n': 1});
      expect(calls, 1);

      now = now.add(const Duration(seconds: 30));
      expect(await transport.get('/v1/classrooms'), {'n': 2});
    });

    test('are forgotten by any change sent, so it is read back', () async {
      await transport.get('/v1/classrooms');
      await transport.post('/v1/classrooms', {'name': '7B'});
      expect(await transport.get('/v1/classrooms'), {'n': 3});
    });

    test('are forgotten when the person asks for fresh', () async {
      await transport.get('/v1/classrooms');
      transport.forgetRecentReads();
      expect(await transport.get('/v1/classrooms'), {'n': 2});
    });

    test('a read on its way while a change is sent is not remembered', () async {
      final before = transport.get('/v1/classrooms');
      final change = transport.post('/v1/classrooms', {'name': '7B'});
      await Future.wait([before, change]);
      await transport.get('/v1/classrooms');
      expect(calls, 3);
    });

    test('a chat polled for new messages always asks the server', () async {
      await transport.get('/v1/conversations/c1/messages');
      await transport.get('/v1/conversations/c1/messages');
      await transport.get('/v1/notifications?limit=20');
      await transport.get('/v1/notifications?limit=20');
      expect(calls, 4);
    });

    test('reads that are never kept are never remembered', () async {
      await transport.get('/v1/me');
      await transport.get('/v1/me');
      expect(calls, 2);
    });
  });

  test('a response that stalls part-way fails instead of spinning', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final serving = server.listen((request) async {
      request.response
        ..headers.contentType = ContentType.json
        ..contentLength = 100
        ..write('{"items": [');
      await request.response.flush();
      // ...and never finishes.
    });
    final transport = V1HttpTransport(
      baseUri: Uri.parse('http://127.0.0.1:${server.port}'),
      accessToken: () async => 'token',
      refreshSession: () async => false,
      onSessionLost: () {},
      timeout: const Duration(milliseconds: 200),
    );
    try {
      await expectLater(
        transport.get('/v1/classrooms'),
        throwsA(
          predicate<Object>(
            (e) => Failure.fromError(e).code == Failure.networkCode,
          ),
        ),
      );
    } finally {
      transport.close();
      await serving.cancel();
      await server.close(force: true);
    }
  });

  test('keeping a copy on the device never holds up the answer', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final serving = server.listen((request) async {
      request.response
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({'items': []}));
      await request.response.close();
    });
    final cache = _StuckCache();
    final transport = V1HttpTransport(
      baseUri: Uri.parse('http://127.0.0.1:${server.port}'),
      accessToken: () async => 'token',
      refreshSession: () async => false,
      onSessionLost: () {},
    )..responseCache = cache;
    try {
      expect(await transport.get('/v1/classrooms'), {'items': []});
      expect(cache.writes, 1);
    } finally {
      cache.release.complete();
      transport.close();
      await serving.cancel();
      await server.close(force: true);
    }
  });
}

/// A device cache whose writes never finish until released.
class _StuckCache implements ResponseCache {
  final release = Completer<void>();
  var writes = 0;

  @override
  Future<Map<String, dynamic>?> read(String key) async => null;

  @override
  Future<void> write(String key, Map<String, dynamic> body) {
    writes += 1;
    return release.future;
  }
}
