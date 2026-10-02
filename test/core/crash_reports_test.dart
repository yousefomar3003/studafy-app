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
