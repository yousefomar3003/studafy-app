import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/core/device_settings.dart';
import 'package:studafy/core/locale_controller.dart';
import 'package:studafy/core/studafy_localizations.dart';
import 'package:studafy/l10n/generated/app_l10n.dart';

/// The localization scaffold every widget test needs, in one place (MOB-070).
///
/// Before this, each test file hand-copied the `MaterialApp` plus its four
/// delegates, which made "render this screen in Arabic and check the
/// direction" expensive enough to skip.
///
/// Pass [locale] to pin a language, or leave it null to exercise the
/// controller's own resolution from [deviceLocales].
Widget localizedApp({
  required Widget home,
  Locale? locale,
  LocaleController? controller,
  List<Locale> deviceLocales = const [Locale('en')],
  Widget Function(Widget child)? scopes,
  Map<String, WidgetBuilder> routes = const {},
}) {
  final resolved =
      controller ??
      LocaleController(
        settings: InMemoryDeviceSettings(),
        readDeviceLocales: () => deviceLocales,
      );
  return LocaleScope(
    controller: resolved,
    child: MaterialApp(
      locale: locale ?? resolved.resolvedLocale,
      supportedLocales: kSupportedLocales,
      localeResolutionCallback: (device, _) =>
          matchSupportedLocale(device == null ? null : [device]) ??
          kFallbackLocale,
      localizationsDelegates: const <LocalizationsDelegate<Object>>[
        AppL10n.delegate,
        StudafyLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routes: routes,
      home: scopes == null ? home : scopes(home),
    ),
  );
}

/// The text direction the widget under [finder] actually renders with.
///
/// Asserting this rather than eyeballing a screenshot is what makes an RTL
/// regression visible in CI.
TextDirection directionOf(WidgetTester tester, Finder finder) =>
    Directionality.of(tester.element(finder));
