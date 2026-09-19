import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/widgets.dart';

import 'device_settings.dart';

/// The languages Studafy ships. Must stay in step with `lib/l10n/*.arb`,
/// `CFBundleLocalizations` in `ios/Runner/Info.plist`, and
/// `android/app/src/main/res/xml/locales_config.xml`.
const kSupportedLocales = <Locale>[Locale('en'), Locale('ar')];

/// The locale used when nothing else resolves.
const kFallbackLocale = Locale('en');

/// The first candidate Studafy ships, or null when it ships none of them.
///
/// Matched on language code alone, so `ar_SA`, `ar_EG` and bare `ar` all
/// resolve to Arabic. Shared by [LocaleController] and the app root's
/// `localeResolutionCallback`, so the language the app renders and the
/// language it reports to the server are decided by the same rule.
Locale? matchSupportedLocale(Iterable<Locale>? candidates) {
  for (final candidate in candidates ?? const <Locale>[]) {
    for (final supported in kSupportedLocales) {
      if (candidate.languageCode == supported.languageCode) return supported;
    }
  }
  return null;
}

/// Owns the interface language: what it is, where it came from, and where it
/// is persisted (MOB-070).
///
/// Resolution order, applied by [restore]:
///
/// 1. the language the user explicitly chose on this device,
/// 2. otherwise the device's own language, if Studafy ships it,
/// 3. otherwise English.
///
/// An explicit choice is stored as a *preference*, and its absence means
/// "follow the device" rather than "English" — so an Arabic phone opens in
/// Arabic on first launch without the user finding a setting.
///
/// Deliberately not a singleton: the composition root builds it, so tests can
/// supply a fake [DeviceSettingsStore] and a fake device locale.
class LocaleController extends ChangeNotifier with WidgetsBindingObserver {
  LocaleController({
    required this.settings,
    this.publishToServer,
    List<Locale> Function()? readDeviceLocales,
  }) : _readDeviceLocales =
           readDeviceLocales ?? (() => PlatformDispatcher.instance.locales);

  final DeviceSettingsStore settings;

  /// Sends the chosen locale to the user's profile, so server-sent email and
  /// push copy match the app. Null in synthetic builds, which have no server.
  final Future<void> Function(String locale)? publishToServer;

  final List<Locale> Function() _readDeviceLocales;

  Locale? _preference;
  Locale _resolved = kFallbackLocale;
  bool _observing = false;

  /// The user's explicit choice, or null when following the device.
  Locale? get preference => _preference;

  /// The locale the app actually renders in. Never null.
  Locale get resolvedLocale => _resolved;

  /// True when no explicit choice has been made and the device decides.
  bool get followsDevice => _preference == null;

  /// Loads the stored preference and resolves the starting locale.
  ///
  /// Called from the composition root before the first frame, so the app never
  /// paints English and then flips to Arabic.
  Future<void> restore() async {
    if (!_observing) {
      WidgetsBinding.instance.addObserver(this);
      _observing = true;
    }
    final stored = await settings.read(DeviceSettingKeys.locale);
    _preference = _parse(stored);
    _resolved = _resolve();
    notifyListeners();
    await _republishIfPending();
  }

  /// The operating system's language changed while the app was running.
  @override
  void didChangeLocales(List<Locale>? locales) => deviceLocalesChanged();

  @override
  void dispose() {
    if (_observing) WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Changes the language. Pass null to go back to following the device.
  ///
  /// The interface changes immediately; persisting and telling the server are
  /// best-effort and never block the switch.
  Future<void> setLocale(Locale? value) async {
    final normalized = value == null ? null : _match([value]);
    if (value != null && normalized == null) return;
    if (normalized == _preference) return;

    _preference = normalized;
    _resolved = _resolve();
    notifyListeners();

    if (normalized == null) {
      await settings.remove(DeviceSettingKeys.locale);
    } else {
      await settings.write(DeviceSettingKeys.locale, normalized.languageCode);
    }
    await _publish(_resolved.languageCode);
  }

  /// Re-resolves after the operating system's language changed underneath us.
  ///
  /// Only moves the app when it is following the device; an explicit choice
  /// outranks the system.
  void deviceLocalesChanged() {
    if (!followsDevice) return;
    final next = _resolve();
    if (next == _resolved) return;
    _resolved = next;
    notifyListeners();
  }

  /// Adopts the locale stored on the user's profile, if this device has no
  /// explicit choice of its own.
  ///
  /// The device preference deliberately wins: otherwise switching language on
  /// one phone would silently flip another phone mid-session. The server value
  /// only seeds a device that has never been told what to use.
  Future<void> adoptServerLocale(String? code) async {
    if (!followsDevice) return;
    final locale = _parse(code);
    if (locale == null || locale == _resolved) return;
    await setLocale(locale);
  }

  Locale _resolve() =>
      _preference ?? _match(_readDeviceLocales()) ?? kFallbackLocale;

  Locale? _match(List<Locale> candidates) => matchSupportedLocale(candidates);

  Locale? _parse(String? code) {
    if (code == null || code.isEmpty) return null;
    return _match([Locale(code)]);
  }

  /// Retries a publish that failed while the app was last running, so a locale
  /// chosen offline still reaches the profile.
  Future<void> _republishIfPending() async {
    if (publishToServer == null) return;
    final published = await settings.read(DeviceSettingKeys.publishedLocale);
    if (published == _resolved.languageCode) return;
    await _publish(_resolved.languageCode);
  }

  Future<void> _publish(String code) async {
    final publish = publishToServer;
    if (publish == null) return;
    try {
      await publish(code);
      await settings.write(DeviceSettingKeys.publishedLocale, code);
    } on Exception {
      // Signed out, offline, or the server refused. The interface has already
      // changed; restore() retries on the next launch.
    }
  }
}

/// Exposes the [LocaleController] to the widget tree and rebuilds dependents
/// when the language changes.
///
/// Lives in `core` rather than `app` because feature presentation opens the
/// language picker, and features may not import composition-root wiring.
class LocaleScope extends InheritedNotifier<LocaleController> {
  const LocaleScope({
    super.key,
    required LocaleController controller,
    required super.child,
  }) : super(notifier: controller);

  static LocaleController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<LocaleScope>();
    final controller = scope?.notifier;
    if (controller == null) {
      throw StateError(
        'LocaleScope is missing. The app root must compose it so the '
        'interface language is owned in one place.',
      );
    }
    return controller;
  }
}
