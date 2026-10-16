import 'package:sentry_flutter/sentry_flutter.dart';

/// Crash and error reports from the app to Sentry (OPS-090).
///
/// On only when the build carries a `SENTRY_DSN` dart-define. Most people
/// using Studafy are children, so a report says what broke and where in the
/// code - never who: no user, no screenshots or view hierarchy, no request
/// bodies, no printed lines or tapped-widget breadcrumbs (they can hold
/// names and message text), no breadcrumb data, and emails, long numbers
/// and tokens are masked in any text that is sent.
///
/// No per-install identifier either. The native SDKs fill one in where the
/// Dart [scrubEvent] never runs: on native (iOS, NDK, Java) crashes, ANRs and
/// sessions they use an "installation id" as `user.id` when no user is set,
/// and Android also puts it in `device.id` and every session's `did`.
/// Three layers keep it out: [anonymise] sets one constant user for everyone,
/// which the SDK syncs to the native scope so native crashes carry it instead;
/// [scrubEvent] drops any device id from Dart events; and the native apps
/// (MainActivity.kt, AppDelegate.swift) give every install the same
/// installation id before Sentry starts.
abstract final class CrashReports {
  static const dsn = String.fromEnvironment('SENTRY_DSN');
  static const environment = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'development',
  );

  static bool get enabled => dsn.isNotEmpty;

  /// The one user every report carries, so the native SDKs never fall back
  /// to their per-install id.
  static const anonymousUserId = 'anonymous';

  /// Starts reporting, then runs [app]. Without a DSN it only runs [app].
  static Future<void> run(Future<void> Function() app) async {
    if (!enabled) return app();
    await SentryFlutter.init(
      configure,
      appRunner: () async {
        await Sentry.configureScope(anonymise);
        await app();
      },
    );
  }

  /// Sets the constant user. Scope sync copies it to the native SDKs, whose
  /// crash and ANR reports then use it instead of the installation id.
  static Future<void> anonymise(Scope scope) =>
      scope.setUser(SentryUser(id: anonymousUserId));

  static void configure(SentryFlutterOptions options) {
    options
      ..dsn = dsn
      ..environment = environment
      ..sendDefaultPii = false
      // Carries the constant user from [anonymise] to the native SDKs. On by
      // default; set here so it cannot be switched off unnoticed.
      ..enableScopeSync = true
      // Errors and crashes only: no performance tracing.
      ..tracesSampleRate = null
      // The view hierarchy is off by default and stays off.
      ..attachScreenshot = false
      ..maxRequestBodySize = MaxRequestBodySize.never
      ..enablePrintBreadcrumbs = false
      ..enableUserInteractionBreadcrumbs = false
      ..enableUserInteractionTracing = false
      ..beforeBreadcrumb = ((breadcrumb, hint) => scrubBreadcrumb(breadcrumb))
      ..beforeSend = ((event, hint) => scrubEvent(event));
  }

  static final _jwt = RegExp(
    r'eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+',
  );
  static final _bearer = RegExp(
    r'Bearer\s+[A-Za-z0-9._~+/-]+=*',
    caseSensitive: false,
  );
  static final _email = RegExp(
    r'[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}',
  );
  static final _longNumber = RegExp(r'\d{7,}');

  /// Masks anything in free text that could identify a person or grant access.
  static String scrubText(String text) => text
      .replaceAll(_jwt, '[token]')
      .replaceAll(_bearer, 'Bearer [token]')
      .replaceAll(_email, '[email]')
      .replaceAll(_longNumber, '[number]');

  static SentryEvent scrubEvent(SentryEvent event) {
    event
      ..user = null
      ..request = null;
    // On Android the device context comes from the native SDK, with the
    // installation id as its `id`.
    if (event.contexts.device case final device?) {
      event.contexts.device = SentryDevice.fromJson(
        device.toJson()
          ..remove('id')
          ..remove('device_unique_identifier'),
      );
    }
    if (event.message case final message?) {
      event.message = SentryMessage(scrubText(message.formatted));
    }
    for (final exception in event.exceptions ?? const <SentryException>[]) {
      if (exception.value case final value?) {
        exception.value = scrubText(value);
      }
    }
    return event;
  }

  /// The breadcrumb's kind and masked message, without its data.
  static Breadcrumb? scrubBreadcrumb(Breadcrumb? breadcrumb) {
    if (breadcrumb == null) return null;
    return Breadcrumb(
      message: switch (breadcrumb.message) {
        final message? => scrubText(message),
        null => null,
      },
      category: breadcrumb.category,
      type: breadcrumb.type,
      level: breadcrumb.level,
      timestamp: breadcrumb.timestamp,
    );
  }
}
