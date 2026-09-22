import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:studafy/features/family/presentation/family_challenge_page.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native challenge bridge returns a token to the calling screen', (
    tester,
  ) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      request.response.headers.contentType = ContentType.html;
      request.response.write('''<!doctype html><html><body>
        <p>Synthetic bridge check</p>
        <script>setTimeout(() => StudafyChallenge.postMessage('synthetic-single-use-token'), 1000);</script>
        </body></html>''');
      await request.response.close();
    });
    addTearDown(() => server.close(force: true));
    String? received;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () async {
                  received = await Navigator.of(context).push<String>(
                    MaterialPageRoute(
                      builder: (_) => FamilyChallengePage(
                        url: Uri.parse(
                          'http://127.0.0.1:${server.port}/auth/bot-check',
                        ),
                      ),
                    ),
                  );
                },
                child: const Text('Open check'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open check'));
    await tester.pumpAndSettle();
    final deadline = Stopwatch()..start();
    while (received == null && deadline.elapsed < const Duration(seconds: 15)) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    expect(received, 'synthetic-single-use-token');
    await tester.pumpAndSettle();
    expect(find.text('Open check'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
