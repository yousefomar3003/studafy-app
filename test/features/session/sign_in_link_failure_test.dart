import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/core/secure_storage.dart';
import 'package:studafy/data/contracts/v1_http_transport.dart';
import 'package:studafy/data/secure/secure_session_storage.dart';
import 'package:studafy/features/session/data/api_session_repository.dart';
import 'package:studafy/features/session/domain/session_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Any app or web page can open `io.studafy.app://login-callback?code=...`.
/// A made-up or stale code fails its exchange, and the auth client reports
/// that on the same stream, and in the same way, as a failed refresh. Taken
/// for one, it ended a perfectly good session: the student was shown "Join
/// your first class" under somebody else's Studafy ID until the app was
/// restarted.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('a failed sign-in link', () {
    late SupabaseClient client;
    late ApiSessionRepository repository;

    setUp(() {
      final store = InMemorySecureStore();
      client = SupabaseClient(
        'https://example.supabase.co',
        'public-test-key',
        authOptions: AuthClientOptions(
          authFlowType: AuthFlowType.pkce,
          pkceAsyncStorage: SecurePkceStorage(store),
          autoRefreshToken: false,
        ),
      );
      repository = ApiSessionRepository(
        client: client,
        secureStore: store,
        transport: V1HttpTransport(
          baseUri: Uri.parse('http://127.0.0.1:8080'),
          accessToken: () async => null,
          refreshSession: () async => false,
          onSessionLost: () {},
        ),
      );
    });

    tearDown(() => client.dispose());

    test('is told apart from a failed refresh', () async {
      final events = <SessionLifecycleEvent>[];
      final subscription = repository.lifecycleEvents.listen(events.add);

      // What the SDK does with the link from the review: no sign-in was
      // started here, so there is no code verifier to exchange it with.
      Object? failure;
      try {
        await client.auth.getSessionFromUrl(
          Uri.parse('io.studafy.app://login-callback?code=fakecode123'),
        );
      } on AuthException catch (error) {
        failure = error;
      }
      expect(failure, isA<AuthException>());
      // ...and then reports it on the auth stream, as supabase_flutter does.
      // ignore: invalid_use_of_internal_member
      client.auth.notifyException(failure!);
      await Future<void>.delayed(Duration.zero);
      await subscription.cancel();

      expect(events, [SessionLifecycleEvent.signInLinkFailed]);
    });
  });

  group('what an auth stream error means', () {
    SessionLifecycleEvent meaning(Object error) =>
        ApiSessionRepository.lifecycleForError(error);

    test('a link exchange that failed is a sign-in link failure', () {
      for (final error in <Object>[
        AuthException('Code verifier could not be found in local storage.'),
        AuthPKCEGrantCodeExchangeError('No code detected in query parameters.'),
        // The server's answer to a made-up or used code.
        AuthApiException(
          'invalid flow state, no valid flow state found',
          statusCode: '404',
          code: 'flow_state_not_found',
        ),
        AuthApiException(
          'invalid flow state, flow state has expired',
          statusCode: '422',
          code: 'flow_state_expired',
        ),
        // A provider's error reply carried in the link.
        AuthException('Access denied', code: 'access_denied'),
      ]) {
        expect(
          meaning(error),
          SessionLifecycleEvent.signInLinkFailed,
          reason: '$error',
        );
      }
    });

    test('a refresh that could not complete still needs a new sign-in', () {
      for (final error in <Object>[
        AuthRetryableFetchException(message: 'offline'),
        AuthSessionMissingException(),
        AuthException('Session expired.', code: 'session_expired'),
        AuthException(
          'Initial session is missing data.',
          code: 'session_missing',
        ),
        StateError('unexpected'),
      ]) {
        expect(
          meaning(error),
          SessionLifecycleEvent.refreshFailed,
          reason: '$error',
        );
      }
    });
  });
}
