import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/app/class_join_link_guard.dart';
import 'package:studafy/core/class_join_link.dart';

Future<void> _pushRouteInformation(WidgetTester tester, String location) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/navigation',
    const JSONMethodCodec().encodeMethodCall(
      MethodCall('pushRouteInformation', <String, dynamic>{
        'location': location,
      }),
    ),
    (_) {},
  );
  await tester.pump();
}

void main() {
  group('the link a teacher shares round-trips', () {
    test('a built link parses back to the same token', () {
      const token = 'joinlink0000000000000000000000000000';
      final url = classJoinLinkUrl(token);
      expect(url, startsWith('$classJoinLinkScheme://$classJoinLinkHost'));
      expect(classJoinTokenFrom(url), token);
      expect(isClassJoinLink(Uri.parse(url)), isTrue);
    });

    test('a token pasted on its own is accepted', () {
      // People paste the bare token out of the middle of a message; working
      // out which half of a link to copy is not the student's job.
      const token = 'joinlink0000000000000000000000000000';
      expect(classJoinTokenFrom('  $token  '), token);
    });

    test('a token with url-safe characters survives the round trip', () {
      // Deliberately low entropy, per .gitleaksignore: the generic-api-key
      // rule fires on entropy alone and cannot tell a fixture from a key.
      const token = '__--0000000000000000000000000000--__';
      expect(classJoinTokenFrom(classJoinLinkUrl(token)), token);
    });

    test('nonsense is refused rather than sent to the server', () {
      expect(classJoinTokenFrom(''), isNull);
      expect(classJoinTokenFrom('hello there'), isNull);
      expect(classJoinTokenFrom('https://example.com/nothing'), isNull);
      expect(classJoinTokenFrom('short'), isNull);
    });

    test('an OAuth callback is not mistaken for a join link', () {
      expect(
        isClassJoinLink(Uri.parse('io.studafy.app://login-callback?code=abc')),
        isFalse,
      );
    });
  });

  group('a tapped join link reaches the app instead of the navigator', () {
    Widget app() => MaterialApp(
      routes: <String, WidgetBuilder>{'/roles': (_) => const Text('roles')},
      home: const Text('splash'),
    );

    testWidgets('the token is captured and nothing throws', (tester) async {
      final guard = ClassJoinLinkGuard();
      WidgetsBinding.instance.addObserver(guard);
      addTearDown(() => WidgetsBinding.instance.removeObserver(guard));

      await tester.pumpWidget(app());
      await _pushRouteInformation(
        tester,
        'io.studafy.app://join?t=joinlink0000000000000000000000000000',
      );

      expect(tester.takeException(), isNull);
      expect(guard.pendingToken.value, 'joinlink0000000000000000000000000000');
      expect(find.text('splash'), findsOneWidget);
    });

    testWidgets('consuming the token clears it, so one tap opens one screen', (
      tester,
    ) async {
      final guard = ClassJoinLinkGuard();
      WidgetsBinding.instance.addObserver(guard);
      addTearDown(() => WidgetsBinding.instance.removeObserver(guard));

      await tester.pumpWidget(app());
      await _pushRouteInformation(
        tester,
        'io.studafy.app://join?t=${'a' * 40}',
      );

      expect(guard.consume(), 'a' * 40);
      expect(guard.consume(), isNull);
    });

    testWidgets('an ordinary destination is left to the navigator', (
      tester,
    ) async {
      // Without the guard this push throws, which is precisely why the guard
      // exists; the point here is that it claims only its own links.
      final guard = ClassJoinLinkGuard();
      WidgetsBinding.instance.addObserver(guard);
      addTearDown(() => WidgetsBinding.instance.removeObserver(guard));

      await tester.pumpWidget(app());
      await _pushRouteInformation(tester, '/not-a-join-link');

      expect(guard.pendingToken.value, isNull);
      expect(tester.takeException(), isNotNull);
    });
  });
}
