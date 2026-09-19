import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/core/device_settings.dart';
import 'package:studafy/app/locale_session_binder.dart';
import 'package:studafy/core/locale_controller.dart';
import 'package:studafy/core/studafy_domain.dart';
import 'package:studafy/features/account/domain/profile_repository.dart';

/// MOB-070 (ADR-0028): the interface language must survive a restart, follow
/// the phone on first launch, and reach the profile so server-sent email and
/// push copy match the app.
void main() {
  // restore() registers a binding observer so a system language change
  // reaches the controller; these are plain tests, so initialize the binding.
  TestWidgetsFlutterBinding.ensureInitialized();

  LocaleController build({
    Map<String, String>? stored,
    List<Locale> device = const [Locale('en', 'US')],
    Future<void> Function(String)? publish,
    DeviceSettingsStore? settings,
  }) => LocaleController(
    settings: settings ?? InMemoryDeviceSettings(stored),
    publishToServer: publish,
    readDeviceLocales: () => device,
  );

  group('first launch', () {
    test('follows an Arabic phone', () async {
      final controller = build(device: const [Locale('ar', 'SA')]);

      await controller.restore();

      expect(controller.resolvedLocale, const Locale('ar'));
      expect(controller.followsDevice, isTrue);
      expect(controller.preference, isNull);
    });

    test(
      'falls back to English for a language Studafy does not ship',
      () async {
        final controller = build(device: const [Locale('fr', 'FR')]);

        await controller.restore();

        expect(controller.resolvedLocale, const Locale('en'));
      },
    );

    test('takes the first supported locale the phone offers', () async {
      final controller = build(
        device: const [Locale('fr', 'FR'), Locale('ar', 'EG')],
      );

      await controller.restore();

      expect(controller.resolvedLocale, const Locale('ar'));
    });
  });

  group('persistence', () {
    test('a chosen language survives a restart', () async {
      final settings = InMemoryDeviceSettings();
      final first = build(settings: settings);
      await first.restore();

      await first.setLocale(const Locale('ar'));

      // A new controller over the same device store is the next app launch.
      final second = build(settings: settings);
      await second.restore();

      expect(second.resolvedLocale, const Locale('ar'));
      expect(second.preference, const Locale('ar'));
      expect(second.followsDevice, isFalse);
    });

    test('an explicit English choice outranks an Arabic phone', () async {
      final settings = InMemoryDeviceSettings();
      final first = build(settings: settings, device: const [Locale('ar')]);
      await first.restore();

      await first.setLocale(const Locale('en'));

      final second = build(settings: settings, device: const [Locale('ar')]);
      await second.restore();

      expect(second.resolvedLocale, const Locale('en'));
    });

    test('clearing the preference goes back to following the phone', () async {
      final controller = build(device: const [Locale('ar')]);
      await controller.restore();
      await controller.setLocale(const Locale('en'));

      await controller.setLocale(null);

      expect(controller.followsDevice, isTrue);
      expect(controller.resolvedLocale, const Locale('ar'));
    });

    test('an unreadable preference store still launches', () async {
      final controller = build(
        settings: _BrokenDeviceSettings(),
        device: const [Locale('ar')],
      );

      await controller.restore();

      expect(controller.resolvedLocale, const Locale('ar'));
    });
  });

  group('notification', () {
    test('notifies once per real change and not for a repeat', () async {
      final controller = build();
      await controller.restore();
      var notifications = 0;
      controller.addListener(() => notifications++);

      await controller.setLocale(const Locale('ar'));
      await controller.setLocale(const Locale('ar'));

      expect(notifications, 1);
    });

    test('ignores a language Studafy does not ship', () async {
      final controller = build();
      await controller.restore();

      await controller.setLocale(const Locale('fr'));

      expect(controller.resolvedLocale, const Locale('en'));
      expect(controller.preference, isNull);
    });
  });

  group('system language changes underneath the app', () {
    test('moves the app when it is following the phone', () async {
      var device = const <Locale>[Locale('en')];
      final controller = LocaleController(
        settings: InMemoryDeviceSettings(),
        readDeviceLocales: () => device,
      );
      await controller.restore();

      device = const [Locale('ar')];
      controller.deviceLocalesChanged();

      expect(controller.resolvedLocale, const Locale('ar'));
    });

    test('leaves an explicit choice alone', () async {
      var device = const <Locale>[Locale('en')];
      final controller = LocaleController(
        settings: InMemoryDeviceSettings(),
        readDeviceLocales: () => device,
      );
      await controller.restore();
      await controller.setLocale(const Locale('en'));

      device = const [Locale('ar')];
      controller.deviceLocalesChanged();

      expect(controller.resolvedLocale, const Locale('en'));
    });
  });

  group('server sync', () {
    test('publishes the chosen locale so email and push match', () async {
      final published = <String>[];
      final controller = build(publish: (code) async => published.add(code));
      await controller.restore();

      await controller.setLocale(const Locale('ar'));

      expect(published, contains('ar'));
    });

    test('a failed publish neither throws nor reverts the interface', () async {
      final controller = build(
        publish: (_) async => throw Exception('offline'),
      );
      await controller.restore();

      await controller.setLocale(const Locale('ar'));

      expect(controller.resolvedLocale, const Locale('ar'));
    });

    test('retries on the next launch after a failed publish', () async {
      final settings = InMemoryDeviceSettings();
      final failing = build(
        settings: settings,
        publish: (_) async => throw Exception('offline'),
      );
      await failing.restore();
      await failing.setLocale(const Locale('ar'));

      final published = <String>[];
      final next = build(
        settings: settings,
        publish: (code) async => published.add(code),
      );
      await next.restore();

      expect(published, ['ar']);
    });

    test('does not republish a locale the server already has', () async {
      final settings = InMemoryDeviceSettings();
      final first = build(settings: settings, publish: (_) async {});
      await first.restore();
      await first.setLocale(const Locale('ar'));

      final published = <String>[];
      final next = build(
        settings: settings,
        publish: (code) async => published.add(code),
      );
      await next.restore();

      expect(published, isEmpty);
    });

    test('a synthetic build with no server does not fail a switch', () async {
      final controller = build();
      await controller.restore();

      await controller.setLocale(const Locale('ar'));

      expect(controller.resolvedLocale, const Locale('ar'));
    });
  });

  group('signing in on a new device', () {
    ActiveContextController signIn() {
      final context = ActiveContextController.instance
        ..profile = const UserProfile(
          id: 'user-1',
          displayName: 'Noura',
          email: 'noura@example.test',
          memberships: [],
        );
      return context;
    }

    tearDown(() => ActiveContextController.instance.profile = null);

    test('adopts the language stored on the profile', () async {
      final controller = build();
      await controller.restore();
      final profiles = _FakeProfiles('ar');
      final binder = LocaleSessionBinder(
        controller: controller,
        profiles: profiles,
      );
      addTearDown(binder.dispose);

      signIn().notifyListeners();
      await Future<void>.delayed(Duration.zero);

      expect(controller.resolvedLocale, const Locale('ar'));
    });

    test('leaves a language already chosen on this device alone', () async {
      final controller = build();
      await controller.restore();
      await controller.setLocale(const Locale('en'));
      final profiles = _FakeProfiles('ar');
      final binder = LocaleSessionBinder(
        controller: controller,
        profiles: profiles,
      );
      addTearDown(binder.dispose);

      signIn().notifyListeners();
      await Future<void>.delayed(Duration.zero);

      expect(controller.resolvedLocale, const Locale('en'));
      expect(profiles.reads, 0, reason: 'no need to ask the server at all');
    });

    test('reads the profile once, not on every context change', () async {
      final controller = build();
      await controller.restore();
      final profiles = _FakeProfiles('ar');
      final binder = LocaleSessionBinder(
        controller: controller,
        profiles: profiles,
      );
      addTearDown(binder.dispose);

      final context = signIn();
      context.notifyListeners();
      await Future<void>.delayed(Duration.zero);
      context.notifyListeners();
      await Future<void>.delayed(Duration.zero);

      expect(profiles.reads, 1);
    });
  });

  group('locale stored on the profile', () {
    test('seeds a device that has never been told what to use', () async {
      final controller = build(device: const [Locale('en')]);
      await controller.restore();

      await controller.adoptServerLocale('ar');

      expect(controller.resolvedLocale, const Locale('ar'));
    });

    test('never overrides this device\'s own choice', () async {
      // Otherwise switching language on one phone silently flips another.
      final controller = build();
      await controller.restore();
      await controller.setLocale(const Locale('en'));

      await controller.adoptServerLocale('ar');

      expect(controller.resolvedLocale, const Locale('en'));
    });

    test('ignores an unsupported or absent profile locale', () async {
      final controller = build();
      await controller.restore();

      await controller.adoptServerLocale('fr');
      await controller.adoptServerLocale(null);

      expect(controller.resolvedLocale, const Locale('en'));
    });
  });
}

/// A preference store that fails every call, standing in for a corrupted store
/// or a platform channel that is not ready.
class _BrokenDeviceSettings implements DeviceSettingsStore {
  @override
  Future<String?> read(String key) async => null;

  @override
  Future<void> write(String key, String value) async =>
      throw Exception('unwritable');

  @override
  Future<void> remove(String key) async => throw Exception('unwritable');
}

/// Seeding the language from the profile when a user signs in.
///
/// Kept with the controller tests because the rule under test belongs to the
/// controller: the profile only ever seeds, and never overrides this device.
class _FakeProfiles implements ProfileRepository {
  _FakeProfiles(this.stored);

  final String? stored;
  final List<String> published = [];
  int reads = 0;

  @override
  Future<String?> readLocale() async {
    reads++;
    return stored;
  }

  @override
  Future<void> updateLocale(String locale) async => published.add(locale);
}
