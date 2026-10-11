import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/core/failures.dart';
import 'package:studafy/data/contracts/v1_http_transport.dart';

/// Opening a file (2026-10-11): the phone sent an expired token to the
/// delivery link and gave up on the 401, unlike every other request.
void main() {
  Future<({HttpServer server, List<String?> tokens})> serve(
    List<int> statuses,
  ) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final tokens = <String?>[];
    var call = 0;
    server.listen((request) async {
      tokens.add(request.headers.value(HttpHeaders.authorizationHeader));
      final status =
          statuses[call < statuses.length ? call : statuses.length - 1];
      call += 1;
      request.response.statusCode = status;
      if (status == 200) request.response.add([1, 2, 3]);
      await request.response.close();
    });
    return (server: server, tokens: tokens);
  }

  V1HttpTransport transportFor(
    HttpServer server, {
    required List<String> tokens,
    required bool refreshes,
    void Function()? onRefresh,
  }) {
    var current = 0;
    return V1HttpTransport(
      baseUri: Uri.parse('http://127.0.0.1:${server.port}'),
      accessToken: () async => tokens[current],
      refreshSession: () async {
        onRefresh?.call();
        if (!refreshes) return false;
        current += 1;
        return true;
      },
      onSessionLost: () {},
    );
  }

  test('an expired token is refreshed and the file fetched once more', () async {
    final s = await serve([401, 200]);
    var refreshed = 0;
    final transport = transportFor(
      s.server,
      tokens: ['expired', 'fresh'],
      refreshes: true,
      onRefresh: () => refreshed += 1,
    );
    try {
      final bytes = await transport.getBytes(
        Uri.parse(
          'http://127.0.0.1:${s.server.port}/delivery/v1/files/x/content?token=t',
        ),
      );
      expect(bytes, [1, 2, 3]);
      expect(refreshed, 1);
      expect(s.tokens, ['Bearer expired', 'Bearer fresh']);
    } finally {
      transport.close();
      await s.server.close(force: true);
    }
  });

  test('a refused refresh still reports the sign-in problem', () async {
    final s = await serve([401]);
    final transport = transportFor(
      s.server,
      tokens: ['expired'],
      refreshes: false,
    );
    try {
      await expectLater(
        transport.getBytes(
          Uri.parse(
            'http://127.0.0.1:${s.server.port}/delivery/v1/files/x/content?token=t',
          ),
        ),
        throwsA(Failure.unauthorized),
      );
      expect(s.tokens, hasLength(1));
    } finally {
      transport.close();
      await s.server.close(force: true);
    }
  });

  test('a spent or withdrawn link is not retried', () async {
    final s = await serve([404, 200]);
    var refreshed = 0;
    final transport = transportFor(
      s.server,
      tokens: ['fresh', 'fresh'],
      refreshes: true,
      onRefresh: () => refreshed += 1,
    );
    try {
      await expectLater(
        transport.getBytes(
          Uri.parse(
            'http://127.0.0.1:${s.server.port}/delivery/v1/files/x/content?token=t',
          ),
        ),
        throwsA(Failure.notFound),
      );
      expect(refreshed, 0);
      expect(s.tokens, hasLength(1));
    } finally {
      transport.close();
      await s.server.close(force: true);
    }
  });
}
