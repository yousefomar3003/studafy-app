import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:studafy/core/crash_reports.dart';

void main() {
  test('emails, tokens and long numbers are masked', () {
    expect(
      CrashReports.scrubText(
        'no row for sara.k@school.jo, phone 0791234567, '
        'Bearer abc.def and eyJhbGciOi.eyJzdWIiOi.c2lnbmF0dXJl',
      ),
      'no row for [email], phone [number], Bearer [token] and [token]',
    );
  });

  test('an event keeps the error, not the person in it', () {
    final event = CrashReports.scrubEvent(
      SentryEvent(
        user: SentryUser(id: 'u1', email: 'a@b.co'),
        message: SentryMessage('failed for a@b.co'),
        exceptions: [
          SentryException(type: 'StateError', value: 'student 12345678'),
        ],
      ),
    );
    expect(event.message?.formatted, 'failed for [email]');
    expect(event.exceptions?.single.value, 'student [number]');
    expect(event.exceptions?.single.type, 'StateError');
    expect(event.user, isNull);
  });

  test('a device context from the native SDK loses its installation id', () {
    // Android's LoadContextsIntegration copies the native device context,
    // whose `id` is Sentry's per-install id, into every Dart event.
    final native = SentryDevice.fromJson({
      'id': '3f0c2b9e5d6a4e1f8a7b6c5d4e3f2a1b',
      'device_unique_identifier': 'ABCD-1234',
      'model': 'Pixel 8',
      'simulator': false,
    });
    // The protocol keeps the unknown `id` key, so it would be sent.
    expect(native.toJson()['id'], '3f0c2b9e5d6a4e1f8a7b6c5d4e3f2a1b');
    final event = CrashReports.scrubEvent(
      SentryEvent(contexts: Contexts(device: native)),
    );
    final device = event.contexts.device!.toJson();
    expect(device, isNot(contains('id')));
    expect(device, isNot(contains('device_unique_identifier')));
    expect(device['model'], 'Pixel 8');
    expect(device['simulator'], isFalse);
  });

  test('every report carries the same constant user', () async {
    final scope = Scope(SentryOptions());
    await CrashReports.anonymise(scope);
    expect(scope.user?.id, CrashReports.anonymousUserId);
    expect(scope.user?.toJson(), {'id': 'anonymous'});
  });

  test('both native apps give every install the same Sentry id', () {
    // sentry-android 8.56.0 and sentry-cocoa 8.58.4 (sentry_flutter 9.30.1)
    // read their installation id from a file named INSTALLATION, in the app's
    // files directory and Caches directory. If this fails after a Sentry
    // upgrade, check that the SDKs still read that file before changing it.
    final lock = File('pubspec.lock').readAsStringSync();
    expect(
      RegExp(r'sentry_flutter:\n(?:    .*\n)*?    version: "([^"]+)"')
          .firstMatch(lock)
          ?.group(1),
      '9.30.1',
    );
    final android = File(
      'android/app/src/main/kotlin/com/studafy/light/MainActivity.kt',
    ).readAsStringSync();
    expect(android, contains('File(filesDir, "INSTALLATION")'));
    expect(
      android.indexOf('pinCrashReportInstallationId('),
      lessThan(android.indexOf('super.onCreate(')),
    );
    final ios = File('ios/Runner/AppDelegate.swift').readAsStringSync();
    expect(ios, contains('.cachesDirectory'));
    expect(ios, contains('"INSTALLATION"'));
    expect(
      ios.indexOf('CrashReportPrivacy.pinInstallationId()'),
      lessThan(ios.indexOf('super.application(')),
    );
  });

  test('a breadcrumb loses its data and keeps its kind', () {
    final crumb = CrashReports.scrubBreadcrumb(
      Breadcrumb(
        message: 'opened chat with a@b.co',
        category: 'navigation',
        data: {'to': '/conversation/123', 'name': 'Sara'},
      ),
    );
    expect(crumb?.message, 'opened chat with [email]');
    expect(crumb?.category, 'navigation');
    expect(crumb?.data, isNull);
  });

  test('the options switch off everything that could identify someone', () {
    final options = SentryFlutterOptions();
    CrashReports.configure(options);
    expect(options.sendDefaultPii, isFalse);
    expect(options.enableScopeSync, isTrue);
    expect(options.attachScreenshot, isFalse);
    expect(options.enablePrintBreadcrumbs, isFalse);
    expect(options.enableUserInteractionBreadcrumbs, isFalse);
    expect(options.maxRequestBodySize, MaxRequestBodySize.never);
    expect(options.tracesSampleRate, isNull);
    expect(options.beforeSend, isNotNull);
    expect(options.beforeBreadcrumb, isNotNull);
  });

  test('without a DSN, reporting is off and the app just runs', () async {
    expect(CrashReports.enabled, isFalse);
    var ran = false;
    await CrashReports.run(() async => ran = true);
    expect(ran, isTrue);
  });
}
