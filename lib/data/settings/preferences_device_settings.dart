import 'package:shared_preferences/shared_preferences.dart';

import '../../core/device_settings.dart';

/// [DeviceSettingsStore] backed by the platform preference store (MOB-070).
///
/// Every call is wrapped: a preference read that throws — a corrupted store, a
/// platform channel that is not ready — must degrade to "no preference saved"
/// and let the caller fall back to the device locale. Failing to read a
/// language choice is never a reason to fail a launch.
class PreferencesDeviceSettings implements DeviceSettingsStore {
  const PreferencesDeviceSettings();

  @override
  Future<String?> read(String key) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      return preferences.getString(key);
    } on Exception {
      return null;
    }
  }

  @override
  Future<void> write(String key, String value) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(key, value);
    } on Exception {
      // A preference that cannot be written is a lost choice, not a crash.
      // The UI has already switched; the next launch falls back to the device.
    }
  }

  @override
  Future<void> remove(String key) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.remove(key);
    } on Exception {
      // As above: best effort.
    }
  }
}
