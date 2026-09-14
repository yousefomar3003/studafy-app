import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/features/session/domain/auth_callback.dart';

/// AUTH-030 callback hijack suite.
///
/// The guard is wired into the Supabase SDK as its
/// `detectSessionInUriPredicate`, so everything refused here never reaches a
/// code exchange. `state` and PKCE enforcement belong to the SDK and GoTrue
/// and are proven end to end by scripts/verify-auth030-lifecycle.ts; this file
/// covers the part the SDK's default does not do at all — checking that the
/// link points at a target this app actually claims.
void main() {
  const guard = AuthCallbackGuard.standard;

  AuthCallbackOutcome inspect(String url) => guard.inspect(Uri.parse(url));

  AuthCallbackRejection? rejectionOf(AuthCallbackOutcome outcome) =>
      outcome is AuthCallbackRejected ? outcome.reason : null;

  group('a legitimate callback', () {
    test('the HTTPS App Link is accepted', () {
      final outcome = inspect(
        'https://app.studafy.io/auth/callback?code=auth-code-1&state=state-abc123',
      );
      expect(outcome, isA<AuthCallbackAccepted>());
      expect((outcome as AuthCallbackAccepted).code, 'auth-code-1');
    });

    test('the custom-scheme fallback is accepted', () {
      final outcome = inspect(
        'io.studafy.app://login-callback?code=auth-code-1&state=state-abc123',
      );
      expect(outcome, isA<AuthCallbackAccepted>());
    });

    test('fragment-delivered parameters are accepted', () {
      final outcome = inspect(
        'io.studafy.app://login-callback#code=auth-code-1&state=state-abc123',
      );
      expect(outcome, isA<AuthCallbackAccepted>());
    });
  });

  group('target allowlist', () {
    for (final hostile in <String>[
      // A lookalike scheme another app could register.
      'io.studafy.app.evil://login-callback?code=c1&state=state-abc123',
      'iostudafyapp://login-callback?code=c1&state=state-abc123',
      // The right scheme, the wrong path.
      'io.studafy.app://login-callback-evil?code=c1&state=state-abc123',
      'io.studafy.app://logincallback?code=c1&state=state-abc123',
      // The right host, an attacker-chosen path.
      'https://app.studafy.io/auth/callback-evil?code=c1&state=state-abc123',
      'https://app.studafy.io/evil?code=c1&state=state-abc123',
      // A lookalike domain.
      'https://app-studafy.io/auth/callback?code=c1&state=state-abc123',
      'https://app.studafy.io.evil.test/auth/callback?code=c1&state=state-abc123',
      // Downgrade to plaintext.
      'http://app.studafy.io/auth/callback?code=c1&state=state-abc123',
      // Credentials in the authority, an old parser-confusion trick.
      'https://app.studafy.io@evil.test/auth/callback?code=c1&state=state-abc123',
      // A non-default port on the right host.
      'https://app.studafy.io:8443/auth/callback?code=c1&state=state-abc123',
    ]) {
      test('refuses $hostile', () {
        expect(
          rejectionOf(inspect(hostile)),
          AuthCallbackRejection.unknownTarget,
          reason: 'hostile callback target was accepted',
        );
      });
    }

    test('host comparison is case-insensitive for a genuine target', () {
      final outcome = inspect(
        'https://APP.STUDAFY.IO/auth/callback?code=c1&state=state-abc123',
      );
      expect(outcome, isA<AuthCallbackAccepted>());
    });
  });

  group('malformed and hostile payloads', () {
    test('a callback with no code is refused', () {
      expect(
        rejectionOf(
          inspect('io.studafy.app://login-callback?state=state-abc123'),
        ),
        AuthCallbackRejection.noAuthorizationCode,
      );
    });

    test('an empty code is refused', () {
      expect(
        rejectionOf(
          inspect('io.studafy.app://login-callback?code=&state=state-abc123'),
        ),
        AuthCallbackRejection.noAuthorizationCode,
      );
    });

    test('a provider error is surfaced, not exchanged', () {
      expect(
        rejectionOf(
          inspect(
            'io.studafy.app://login-callback?error=access_denied&state=state-abc123',
          ),
        ),
        AuthCallbackRejection.providerError,
      );
    });

    test('an error alongside a code is still treated as a failure', () {
      // Refusing on `error` before reading `code` stops a callback that smuggles
      // both from being exchanged.
      expect(
        rejectionOf(
          inspect(
            'io.studafy.app://login-callback?error=access_denied&code=c1&state=state-abc123',
          ),
        ),
        AuthCallbackRejection.providerError,
      );
    });

    test('an unparsable fragment does not crash the guard', () {
      final outcome = inspect(
        'io.studafy.app://login-callback?code=c1&state=state-abc123#%%%',
      );
      expect(outcome, isA<AuthCallbackAccepted>());
    });
  });
}
