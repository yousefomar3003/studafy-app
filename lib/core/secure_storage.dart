/// Port for platform-backed secure storage (AUTH-030).
///
/// Session material — refresh tokens above all — must live in the iOS Keychain
/// or the Android Keystore-backed store, never in shared preferences, SQLite,
/// logs, analytics, or the clipboard. Presentation and application code never
/// see an implementation; the composition root chooses one.
abstract interface class SecureStore {
  /// Reads a value, or null when absent or unreadable.
  Future<String?> read(String key);

  /// Writes a value, replacing any existing one.
  Future<void> write(String key, String value);

  /// Removes a single value.
  Future<void> delete(String key);

  /// Removes everything this app wrote.
  ///
  /// Called on sign-out and on account switch, so no session material from a
  /// previous user survives on a shared device.
  Future<void> deleteAll();
}

/// In-memory store for tests and synthetic builds.
///
/// Deliberately not used in remote builds: a build that reaches a real
/// backend must persist through the platform keystore or not at all.
class InMemorySecureStore implements SecureStore {
  final Map<String, String> _values = {};

  /// Test-only view of what has been stored.
  Map<String, String> get snapshot => Map.unmodifiable(_values);

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;

  @override
  Future<void> delete(String key) async => _values.remove(key);

  @override
  Future<void> deleteAll() async => _values.clear();
}
