import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/secure_storage.dart';

/// Persists the Supabase session in platform secure storage (AUTH-030).
///
/// This replaces the SDK's default, which keeps the session — including the
/// refresh token — in shared preferences. On Android that is a plaintext XML
/// file readable after a backup extraction or on a rooted device; on iOS it is
/// a plist inside the app container. A refresh token is a long-lived credential
/// that mints new access tokens, so it belongs in the Keychain/Keystore.
///
/// [SecureStore] is the port, so tests exercise this class without a platform
/// channel and can assert that nothing else ever holds the token.
class SecureSessionStorage extends LocalStorage {
  const SecureSessionStorage(this._store);

  /// Namespaced so `deleteAll` on sign-out cannot be confused with unrelated
  /// keys, and so the value is greppable in an audit.
  static const sessionKey = 'studafy.auth.session.v1';

  final SecureStore _store;

  @override
  Future<void> initialize() async {}

  @override
  Future<String?> accessToken() => _store.read(sessionKey);

  @override
  Future<bool> hasAccessToken() async =>
      (await _store.read(sessionKey)) != null;

  @override
  Future<void> persistSession(String persistSessionString) =>
      _store.write(sessionKey, persistSessionString);

  @override
  Future<void> removePersistedSession() => _store.delete(sessionKey);
}

/// Holds the PKCE code verifier in secure storage (AUTH-030).
///
/// The SDK default is shared preferences. The verifier is the secret that
/// binds an authorization code to this client: an attacker who can read it and
/// intercept the callback can complete the exchange, which is precisely the
/// deep-link hijack PKCE exists to prevent. It is short-lived and single-use,
/// but that is a reason to store it correctly, not a reason to store it in the
/// clear.
class SecurePkceStorage extends GotrueAsyncStorage {
  const SecurePkceStorage(this._store);

  static const keyPrefix = 'studafy.auth.pkce.';

  final SecureStore _store;

  @override
  Future<String?> getItem({required String key}) =>
      _store.read('$keyPrefix$key');

  @override
  Future<void> setItem({required String key, required String value}) =>
      _store.write('$keyPrefix$key', value);

  @override
  Future<void> removeItem({required String key}) =>
      _store.delete('$keyPrefix$key');
}
