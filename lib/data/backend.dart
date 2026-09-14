import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/secure_storage.dart';
import '../features/session/domain/auth_callback.dart';
import 'secure/keychain_secure_store.dart';
import 'secure/secure_session_storage.dart';

class BackendConfig {
  const BackendConfig({
    required this.url,
    required this.publishableKey,
    required this.apiUrl,
  });

  final String url;
  final String publishableKey;

  /// Base URL of the `/v1` API. Authority questions go here, not to PostgREST.
  final String apiUrl;

  bool get isConfigured => url.isNotEmpty && publishableKey.isNotEmpty;

  /// The API is required alongside the backend: without it there is nothing
  /// verifying tokens or resolving roles, and the client must not fall back to
  /// deciding authority for itself.
  bool get hasApi => apiUrl.isNotEmpty;

  static const fromEnvironment = BackendConfig(
    url: String.fromEnvironment('SUPABASE_URL'),
    publishableKey: String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY'),
    apiUrl: String.fromEnvironment('STUDAFY_API_URL'),
  );
}

class StudafyBackend {
  StudafyBackend._();

  static bool _initialized = false;
  static bool get isRemote => _initialized;

  static SecureStore? _secureStore;

  /// The secure store holding the session, once the backend is initialized.
  ///
  /// Sign-out uses it to erase session material rather than relying on the
  /// SDK to have removed everything.
  static SecureStore? get secureStore => _secureStore;

  /// Initializes the remote backend.
  ///
  /// [secureStore] is injectable so tests can prove the session never leaves
  /// the secure store; production passes the Keychain/Keystore adapter.
  static Future<void> initialize({SecureStore? secureStore}) async {
    final config = BackendConfig.fromEnvironment;
    if (!config.isConfigured) return;
    final store = secureStore ?? KeychainSecureStore();
    _secureStore = store;
    await Supabase.initialize(
      url: config.url,
      publishableKey: config.publishableKey,
      // AUTH-030: PKCE, and the session is persisted through the platform
      // keystore instead of the SDK default (shared preferences), because the
      // refresh token is a long-lived credential.
      authOptions: FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
        localStorage: SecureSessionStorage(store),
        pkceAsyncStorage: SecurePkceStorage(store),
        // The SDK default treats any deep link carrying a `code` as an auth
        // callback wherever it points. Narrow it to the targets this app
        // actually claims, so a lookalike link never reaches the exchange.
        detectSessionInUriPredicate: AuthCallbackGuard.standard.shouldExchange,
      ),
    );
    _initialized = true;
  }

  static SupabaseClient get client {
    if (!_initialized) {
      throw StateError(
        'Supabase is not configured. Provide SUPABASE_URL and '
        'SUPABASE_PUBLISHABLE_KEY with --dart-define.',
      );
    }
    return Supabase.instance.client;
  }
}
