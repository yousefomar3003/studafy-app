import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/app/oauth_callback_guard.dart';

/// Delivers route information the way the engine does when iOS hands the app
/// a deep link, so the observer chain runs exactly as it does in production.
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
  group('OAuthCallbackGuard.isCallback', () {
    test('claims the PKCE code the provider returns', () {
      expect(
        OAuthCallbackGuard.isCallback(Uri.parse('/?code=91a4fd41-d631')),
        isTrue,
      );
    });

    test('claims an implicit-flow token in the fragment', () {
      expect(
        OAuthCallbackGuard.isCallback(
          Uri.parse('io.studafy.app://login-callback#access_token=abc'),
        ),
        isTrue,
      );
    });

    test('claims a refused or cancelled sign-in', () {
      expect(
        OAuthCallbackGuard.isCallback(Uri.parse('/?error=access_denied')),
        isTrue,
      );
    });

    test('leaves ordinary destinations to the navigator', () {
      expect(OAuthCallbackGuard.isCallback(Uri.parse('/teacher')), isFalse);
      expect(OAuthCallbackGuard.isCallback(Uri.parse('/roles')), isFalse);
    });
  });

  group('the provider callback never reaches route handling', () {
    // The app's real shape: named routes plus a home, and no onUnknownRoute.
    // Before the guard this threw "Could not find a generator for route" on
    // every sign-in, because the callback was pushed as a named route.
    Widget app() => MaterialApp(
      routes: <String, WidgetBuilder>{'/roles': (_) => const Text('roles')},
      home: const Text('splash'),
    );

    testWidgets('a pushed OAuth callback throws nothing', (tester) async {
      final guard = OAuthCallbackGuard();
      WidgetsBinding.instance.addObserver(guard);
      addTearDown(() => WidgetsBinding.instance.removeObserver(guard));

      await tester.pumpWidget(app());
      await _pushRouteInformation(
        tester,
        '/?code=91a4fd41-d631-421f-bbf4-e387267c9e0d',
      );

      expect(tester.takeException(), isNull);
      expect(find.text('splash'), findsOneWidget);
    });

    testWidgets('without the guard the same push still throws', (tester) async {
      // Pins the reason the guard exists: remove it and the crash returns.
      await tester.pumpWidget(app());
      await _pushRouteInformation(tester, '/?code=91a4fd41-d631');

      expect(tester.takeException(), isNotNull);
    });
  });
}
