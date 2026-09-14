import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
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
        expect(keys.first, hasLength(32));
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
}
