/// Why an inbound deep link was not treated as an authentication callback.
enum AuthCallbackRejection {
  /// Not a callback target this app claims.
  unknownTarget,

  /// Carries no authorization code — nothing to exchange.
  noAuthorizationCode,

  /// The provider reported a failure.
  providerError,
}

/// The outcome of inspecting an inbound deep link.
sealed class AuthCallbackOutcome {
  const AuthCallbackOutcome();
}

/// The link is a callback for this app and may go to the code exchange.
final class AuthCallbackAccepted extends AuthCallbackOutcome {
  const AuthCallbackAccepted(this.code);
  final String code;
}

/// The link must not reach the code exchange.
final class AuthCallbackRejected extends AuthCallbackOutcome {
  const AuthCallbackRejected(this.reason);
  final AuthCallbackRejection reason;
}

/// Decides whether an inbound deep link is an authentication callback for this
/// app (AUTH-030).
///
/// This is wired into the Supabase SDK as its `detectSessionInUriPredicate`,
/// so it runs before any code exchange is attempted. The SDK's own default
/// treats *any* link carrying a `code`, `access_token`, or `error` parameter
/// as an auth callback regardless of where it points; this narrows that to the
/// exact targets the app claims.
///
/// What it defends against is an unsolicited or lookalike callback being fed
/// into the exchange — `io.studafy.app.evil://login-callback?code=…`, a
/// lookalike domain, a plaintext downgrade, or credentials smuggled into the
/// authority.
///
/// What it deliberately does not attempt is re-implementing `state` and PKCE
/// verification. The SDK holds the generated `state` and the code verifier and
/// checks both during the exchange; a second copy here could not see either,
/// so it would prove nothing. That enforcement is verified end to end against
/// a real GoTrue by `scripts/verify-auth030-lifecycle.ts`.
///
/// Nor can it stop another app registering the same custom scheme and
/// receiving the callback first. Nothing in-process can. The mitigations there
/// are the owned HTTPS App Link/Universal Link, which only a verified domain
/// owner can claim, and PKCE, which makes an intercepted code useless without
/// the verifier. The custom scheme stays only as a fallback while domain
/// verification is outstanding.
class AuthCallbackGuard {
  const AuthCallbackGuard({required this.allowedTargets});

  /// Callback targets this app claims, most-preferred first.
  static const defaultTargets = <String>[
    'https://app.studafy.io/auth/callback',
    'io.studafy.app://login-callback',
  ];

  static const standard = AuthCallbackGuard(allowedTargets: defaultTargets);

  final List<String> allowedTargets;

  /// The predicate handed to the Supabase SDK.
  bool shouldExchange(Uri uri) => inspect(uri) is AuthCallbackAccepted;

  /// Full inspection, so a rejection reason is available for logging.
  AuthCallbackOutcome inspect(Uri uri) {
    if (!claimsTarget(uri)) {
      return const AuthCallbackRejected(AuthCallbackRejection.unknownTarget);
    }

    final parameters = {...uri.queryParameters, ..._fragmentParameters(uri)};

    // Checked before `code` so a callback smuggling both is not exchanged.
    if (parameters.containsKey('error') ||
        parameters.containsKey('error_code') ||
        parameters.containsKey('error_description')) {
      return const AuthCallbackRejected(AuthCallbackRejection.providerError);
    }

    final code = parameters['code'];
    if (code == null || code.isEmpty) {
      return const AuthCallbackRejected(
        AuthCallbackRejection.noAuthorizationCode,
      );
    }
    return AuthCallbackAccepted(code);
  }

  /// Whether [uri] is one of this app's claimed callback targets.
  bool claimsTarget(Uri uri) {
    for (final target in allowedTargets) {
      final allowed = Uri.parse(target);
      if (uri.scheme != allowed.scheme) continue;
      // Host is compared case-insensitively; path must match exactly, so a
      // lookalike such as /auth/callback-evil does not pass.
      if (uri.host.toLowerCase() != allowed.host.toLowerCase()) continue;
      if (_normalizePath(uri) != _normalizePath(allowed)) continue;
      if (uri.port != allowed.port) continue;
      // Credentials in the authority are a parser-confusion trick, never
      // something a legitimate provider redirect contains.
      if (uri.userInfo.isNotEmpty) continue;
      return true;
    }
    return false;
  }

  static String _normalizePath(Uri uri) {
    final path = uri.path;
    if (path.length > 1 && path.endsWith('/')) {
      return path.substring(0, path.length - 1);
    }
    return path;
  }

  /// Implicit-flow providers return parameters in the fragment.
  static Map<String, String> _fragmentParameters(Uri uri) {
    if (uri.fragment.isEmpty) return const {};
    try {
      return Uri.splitQueryString(uri.fragment);
    } catch (_) {
      return const {};
    }
  }
}
