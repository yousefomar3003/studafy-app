import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/secure_storage.dart';

/// Keychain/Keystore-backed [SecureStore] (AUTH-030).
///
/// Options are chosen deliberately:
///
/// - `first_unlock_this_device` keeps the Keychain item off iCloud Keychain
///   and off device backups, so a restored backup on another device does not
///   carry a live session with it.
/// - Android uses the package default: AES-GCM data encryption under a
///   Keystore-wrapped key. Biometric gating is deliberately off, because a
///   session must survive a device the user has already unlocked.
class KeychainSecureStore implements SecureStore {
  KeychainSecureStore([FlutterSecureStorage? storage])
    : _storage =
          storage ??
          const FlutterSecureStorage(
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock_this_device,
            ),
            aOptions: AndroidOptions(),
          );

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);

  @override
  Future<void> deleteAll() => _storage.deleteAll();
}
