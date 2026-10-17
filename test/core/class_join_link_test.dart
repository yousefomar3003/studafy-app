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

    testWidgets('a join link with no token is claimed, and opens nothing', (
      tester,
    ) async {
      final guard = ClassJoinLinkGuard();
      WidgetsBinding.instance.addObserver(guard);
      addTearDown(() => WidgetsBinding.instance.removeObserver(guard));

      await tester.pumpWidget(app());
      await _pushRouteInformation(tester, 'io.studafy.app://join');

      expect(tester.takeException(), isNull);
      expect(guard.pendingToken.value, isNull);
      expect(find.text('splash'), findsOneWidget);
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

  // JOIN-053: the same link, spelled short enough to type.
  group('class codes', () {
    test('a code is recognised however loosely it is typed', () {
      for (final typed in [
        'K7QM-4XTR',
        'k7qm-4xtr',
        'K7QM 4XTR',
        ' k7qm4xtr ',
      ]) {
        final credential = classJoinCredentialFrom(typed);
        expect(credential, isA<ClassJoinCode>(), reason: typed);
        expect((credential! as ClassJoinCode).code, 'K7QM4XTR');
      }
    });

    test('a link and a bare token still redeem by token', () {
      final token = 'a' * 43;
      expect(
        classJoinCredentialFrom(classJoinLinkUrl(token)),
        isA<ClassJoinToken>(),
      );
      expect(classJoinCredentialFrom(token), isA<ClassJoinToken>());
    });

    test('a code and a token can never be mistaken for each other', () {
      // A token is at least 32 characters; a code is eight, nine with its
      // dash. Nothing is both.
      expect(classJoinCredentialFrom('A' * 32), isA<ClassJoinToken>());
      expect(classJoinCredentialFrom('ABCDEFGH'), isA<ClassJoinCode>());
    });

    test('misreadable and foreign characters are refused', () {
      for (final bad in ['K7QM-4XT0', 'K7QM-4XTO', 'K7QM-4XT1', 'K7QM-4XTI']) {
        expect(classJoinCredentialFrom(bad), isNull, reason: bad);
      }
      expect(classJoinCredentialFrom('K7QM-4XT'), isNull); // short
      expect(classJoinCredentialFrom('K7QM-4XTRR'), isNull); // long
      expect(classJoinCredentialFrom(''), isNull);
    });

    test('the alphabet matches the server, which mints the codes', () {
      expect(classCodeAlphabet, 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789');
      expect(classCodeAlphabet.length, 32);
    });

    test('it is shown as two groups of four', () {
      expect(formatClassCode('K7QM4XTR'), 'K7QM-4XTR');
    });
  });
}
