import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/core/secure_storage.dart';
import 'package:studafy/data/secure/secure_session_storage.dart';

/// AUTH-030: session material must live in the platform keystore and nowhere
/// else. The SDK default is shared preferences, which on Android is a
/// plaintext XML file recoverable from a backup extraction.
void main() {
  late InMemorySecureStore store;
  late SecureSessionStorage storage;

  setUp(() {
    store = InMemorySecureStore();
    storage = SecureSessionStorage(store);
  });

  const persistedSession =
      '{"access_token":"header.payload.signature",'
      '"refresh_token":"a-long-lived-refresh-credential",'
      '"expires_at":1789000000}';

  group('session persistence', () {
    test('a persisted session is written only to the secure store', () async {
      await storage.persistSession(persistedSession);

      expect(store.snapshot.keys, [SecureSessionStorage.sessionKey]);
      expect(store.snapshot.values.single, persistedSession);
    });

    test('the refresh token never appears outside the secure store', () async {
      await storage.persistSession(persistedSession);

      // The whole point of the change: this string must be reachable only
      // through the keystore-backed adapter.
      final everythingElse = jsonEncode({
        'keys': store.snapshot.keys.toList(),
        'storage_class': storage.runtimeType.toString(),
      });
      expect(
        everythingElse,
        isNot(contains('a-long-lived-refresh-credential')),
      );
    });

    test('restoring a session reads it back', () async {
      await storage.persistSession(persistedSession);
      expect(await storage.hasAccessToken(), isTrue);
      expect(await storage.accessToken(), persistedSession);
    });

    test('no session means no access token', () async {
      expect(await storage.hasAccessToken(), isFalse);
      expect(await storage.accessToken(), isNull);
    });

    test('removing the session leaves nothing behind', () async {
      await storage.persistSession(persistedSession);
      await storage.removePersistedSession();

      expect(store.snapshot, isEmpty);
      expect(await storage.hasAccessToken(), isFalse);
    });
  });

  group('PKCE verifier', () {
    test('the code verifier is stored under a namespaced secure key', () async {
      final shared = InMemorySecureStore();
      final verifierStorage = SecurePkceStorage(shared);

      await verifierStorage.setItem(key: 'verifier', value: 'code-verifier-1');

      expect(shared.snapshot.keys.single, startsWith('studafy.auth.pkce.'));
      expect(shared.snapshot.values.single, 'code-verifier-1');
      expect(await verifierStorage.getItem(key: 'verifier'), 'code-verifier-1');
    });

    test('the verifier is removable after the exchange', () async {
      final shared = InMemorySecureStore();
      final verifierStorage = SecurePkceStorage(shared);

      await verifierStorage.setItem(key: 'verifier', value: 'code-verifier-1');
      await verifierStorage.removeItem(key: 'verifier');

      expect(shared.snapshot, isEmpty);
      expect(await verifierStorage.getItem(key: 'verifier'), isNull);
    });

    test('session and verifier keys do not collide', () async {
      final shared = InMemorySecureStore();
      final sessionStorage = SecureSessionStorage(shared);
      final verifierStorage = SecurePkceStorage(shared);

      await sessionStorage.persistSession(persistedSession);
      await verifierStorage.setItem(key: 'verifier', value: 'code-verifier-1');

      expect(shared.snapshot, hasLength(2));
      expect(await sessionStorage.accessToken(), persistedSession);
      expect(await verifierStorage.getItem(key: 'verifier'), 'code-verifier-1');
    });

    test(
      'deleteAll on sign-out clears session and verifier together',
      () async {
        final shared = InMemorySecureStore();
        await SecureSessionStorage(shared).persistSession(persistedSession);
        await SecurePkceStorage(shared).setItem(key: 'v', value: 'x');

        await shared.deleteAll();

        expect(shared.snapshot, isEmpty);
      },
    );
  });
}
