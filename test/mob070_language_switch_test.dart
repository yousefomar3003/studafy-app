import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/core/device_settings.dart';
import 'package:studafy/core/language_picker.dart';
import 'package:studafy/core/locale_controller.dart';

import 'support/localized_app.dart';

/// MOB-070 (ADR-0028): switching the app to Arabic, end to end through the
/// real picker — the copy, the persistence and the right-to-left flip.
void main() {
  Widget harness(LocaleController controller) => localizedApp(
    controller: controller,
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => showStudafyLanguagePicker(context),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );

  Future<void> openPicker(WidgetTester tester) async {
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('the picker offers both languages and the device default', (
    tester,
  ) async {
    final controller = LocaleController(settings: InMemoryDeviceSettings());
    await controller.restore();
    await tester.pumpWidget(harness(controller));
    await tester.pumpAndSettle();

    await openPicker(tester);

    expect(find.text('App language'), findsOneWidget);
    // Each language is named in its own language, so a reader who cannot read
    // the current interface can still find theirs.
    expect(find.text('English'), findsOneWidget);
    expect(find.text('العربية'), findsOneWidget);
    expect(find.text('System default'), findsOneWidget);
  });

  testWidgets('choosing Arabic switches the interface and flips it to RTL', (
    tester,
  ) async {
    final controller = LocaleController(settings: InMemoryDeviceSettings());
    await controller.restore();
    await tester.pumpWidget(harness(controller));
    await tester.pumpAndSettle();
    expect(
      directionOf(tester, find.byType(Scaffold)),
      TextDirection.ltr,
      reason: 'starts left-to-right on an English device',
    );

    await openPicker(tester);
    await tester.tap(find.text('العربية'));
    await tester.pumpAndSettle();
    // The app root rebuilds from the controller, which this harness models by
    // rebuilding with the same controller.
    await tester.pumpWidget(harness(controller));
    await tester.pumpAndSettle();

    expect(controller.resolvedLocale, const Locale('ar'));
    expect(
      directionOf(tester, find.byType(Scaffold)),
      TextDirection.rtl,
      reason: 'Arabic must lay the interface out right-to-left',
    );
  });

  testWidgets('the picker itself is in Arabic once Arabic is chosen', (
    tester,
  ) async {
    // The bug this covers: the sheet for choosing a language was hardcoded
    // English, so an Arabic user opening it saw English.
    final controller = LocaleController(settings: InMemoryDeviceSettings());
    await controller.restore();
    await controller.setLocale(const Locale('ar'));
    await tester.pumpWidget(harness(controller));
    await tester.pumpAndSettle();

    await openPicker(tester);

    expect(find.text('لغة التطبيق'), findsOneWidget);
    expect(find.text('لغة النظام'), findsOneWidget);
    expect(find.text('App language'), findsNothing);
  });

  testWidgets('an Arabic phone opens in Arabic without touching a setting', (
    tester,
  ) async {
    final controller = LocaleController(
      settings: InMemoryDeviceSettings(),
      readDeviceLocales: () => const [Locale('ar', 'SA')],
    );
    await controller.restore();

    await tester.pumpWidget(harness(controller));
    await tester.pumpAndSettle();

    expect(
      directionOf(tester, find.byType(Scaffold)),
      TextDirection.rtl,
      reason: 'first launch follows the phone',
    );
  });

  testWidgets('going back to the system default re-reads the phone', (
    tester,
  ) async {
    final controller = LocaleController(
      settings: InMemoryDeviceSettings(),
      readDeviceLocales: () => const [Locale('ar')],
    );
    await controller.restore();
    await controller.setLocale(const Locale('en'));
    await tester.pumpWidget(harness(controller));
    await tester.pumpAndSettle();

    await openPicker(tester);
    await tester.tap(find.text('System default'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(harness(controller));
    await tester.pumpAndSettle();

    expect(controller.followsDevice, isTrue);
    expect(directionOf(tester, find.byType(Scaffold)), TextDirection.rtl);
  });
}
