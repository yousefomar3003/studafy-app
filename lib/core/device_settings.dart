/// Port for settings that belong to the device rather than to a session
/// (MOB-070).
///
/// Deliberately separate from [SecureStore]. That port holds session material
/// and its `deleteAll()` runs on sign-out and account switch, which is correct
/// for refresh tokens and wrong for a language preference: a user who signs out
/// on a shared tablet should still find the app in the language they chose.
///
/// Nothing stored here may be sensitive. It is plain, unencrypted,
/// device-readable preference data — a chosen locale, and nothing that
/// identifies a person.
abstract interface class DeviceSettingsStore {
  /// Reads a value, or null when absent or unreadable.
  Future<String?> read(String key);

  /// Writes a value, replacing any existing one.
  Future<void> write(String key, String value);

  /// Removes a single value.
  Future<void> remove(String key);
}

/// Keys used by [DeviceSettingsStore], kept together so one file shows
/// everything the app persists at device scope.
abstract final class DeviceSettingKeys {
  /// The language the user explicitly chose. Absent means "follow the device",
  /// which is the first-launch default — not a synonym for English.
  static const locale = 'settings.locale';

  /// The locale last accepted by the server, so a failed publish can be
  /// retried on the next launch instead of being lost.
  static const publishedLocale = 'settings.locale.published';
}

/// In-memory store for tests and synthetic builds.
class InMemoryDeviceSettings implements DeviceSettingsStore {
  InMemoryDeviceSettings([Map<String, String>? initial])
    : _values = {...?initial};

  final Map<String, String> _values;

  /// Test-only view of what has been stored.
  Map<String, String> get snapshot => Map.unmodifiable(_values);

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;

  @override
  Future<void> remove(String key) async => _values.remove(key);
}
