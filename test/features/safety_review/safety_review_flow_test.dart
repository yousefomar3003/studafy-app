import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/features/safety_review/application/safety_review_interactor.dart';
import 'package:studafy/features/safety_review/domain/safety_review.dart';
import 'package:studafy/features/safety_review/presentation/safety_reports_page.dart';

import '../../support/accessibility.dart';
import '../../support/localized_app.dart';
import '../../support/safety_review_fake.dart';

/// The platform operator's safety review (DL-063), against an in-memory
/// server: the metadata queue, getting access (reason, then authenticator
/// code), reading the report and recording a decision, and every refusal on
/// the way.
void main() {
  late FakeSafetyReviewRepository server;
  late int securityOpened;

  setUp(() {
    server = FakeSafetyReviewRepository();
    securityOpened = 0;
  });

  Future<void> pumpQueue(WidgetTester tester, {Locale? locale}) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      localizedApp(
        locale: locale ?? const Locale('en'),
        home: SafetyReportsPage(
          review: SafetyReviewInteractor(server),
          now: () => DateTime(2026, 10, 16, 12),
          onOpenSecurity: (_) async {
            securityOpened++;
            // Set up in Account -> Security, then back.
            server.enrolled = true;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Scrolls the report (its text fields scroll too) until [finder] shows.
  Future<void> scrollTo(WidgetTester tester, Finder finder) =>
      tester.scrollUntilVisible(
        finder,
        200,
        scrollable: find.byType(Scrollable).first,
      );

  /// The confirming button in the decision's dialog.
  final confirmButton = find.descendant(
    of: find.byType(AlertDialog),
    matching: find.byType(FilledButton),
  );

  /// Brings [finder] on screen (above the keyboard's place), then taps it.
  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> openFirst(WidgetTester tester) async {
    await tester.tap(find.text('Message report'));
    await tester.pumpAndSettle();
  }

  Future<void> giveReason(WidgetTester tester, String reason) async {
    await tester.enterText(find.byType(TextField), reason);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
  }

  Future<void> giveCode(WidgetTester tester, String code) async {
    await tester.enterText(find.byType(TextField), code);
    await tester.tap(find.text('Open report'));
    await tester.pumpAndSettle();
  }

  group('the queue', () {
    testWidgets('lists open reports as metadata only', (tester) async {
      server.reports = [
        sampleSummary(priority: SafetyReviewPriority.critical),
        sampleSummary(
          id: '33333333-3333-4333-8333-333333333333',
          kind: SafetyReviewKind.user,
          priority: SafetyReviewPriority.low,
          grantActive: true,
          filedAt: DateTime(2026, 10, 14, 12),
        ),
      ];
      await pumpQueue(tester);

      expect(find.text('Safety reports'), findsOneWidget);
      expect(find.text('Message report'), findsOneWidget);
      expect(find.text('Report about a person'), findsOneWidget);
      expect(find.text('Critical'), findsOneWidget);
      expect(find.text('Low'), findsOneWidget);
      expect(
        find.text('Report 22222222 · Filed 3 hours ago · Waiting'),
        findsOneWidget,
      );
      expect(
        find.text('Report 33333333 · Filed 2 days ago · Waiting'),
        findsOneWidget,
      );
      expect(find.text('Access open'), findsOneWidget);
      // No content reaches the queue.
      expect(find.textContaining('He keeps messaging'), findsNothing);
      expect(server.calls, ['queue']);
    });

    testWidgets('says when nothing is open', (tester) async {
      server.reports = [];
      await pumpQueue(tester);
      expect(find.text('No open reports'), findsOneWidget);
    });

    testWidgets('a failed read offers a retry', (tester) async {
      server.queueError = SafetyReviewError.unavailable;
      await pumpQueue(tester);
      expect(find.text('Could not load the reports.'), findsOneWidget);
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('Message report'), findsOneWidget);
    });

    testWidgets('an account the server does not take as an operator is told '
        'so', (tester) async {
      server.queueError = SafetyReviewError.notOperator;
      await pumpQueue(tester);
      expect(
        find.text('This account is not a platform operator.'),
        findsOneWidget,
      );
    });

    testWidgets('with two reviewers it says a second one approves', (
      tester,
    ) async {
      server.singleReviewer = false;
      await pumpQueue(tester);
      expect(
        find.textContaining('A second reviewer now has to approve'),
        findsOneWidget,
      );
    });
  });

  group('getting access and deciding', () {
    testWidgets('reason, code, report, decision', (tester) async {
      await pumpQueue(tester);
      await openFirst(tester);

      expect(find.text('Why are you opening this report?'), findsOneWidget);
      await giveReason(tester, 'short');
      expect(find.text('Write at least 8 characters.'), findsOneWidget);
      expect(server.calls, ['queue']);

      await giveReason(tester, 'Alert received in the safety chat');
      expect(find.text('Confirm it is you'), findsOneWidget);

      await giveCode(tester, '12');
      expect(find.text('Enter the 6 digits.'), findsOneWidget);

      await giveCode(tester, '000000');
      expect(find.textContaining('That code did not match'), findsOneWidget);
      expect(server.granted, isEmpty);

      await giveCode(tester, '123456');
      expect(server.calls, [
        'queue',
        'enrolled?',
        'code:000000',
        'code:123456',
        'grant:$sampleReportId:Alert received in the safety chat',
        'open:$sampleReportId',
      ]);

      // The report, as written, with what was captured and the evidence.
      expect(
        find.text('He keeps messaging me after I asked him to stop'),
        findsOneWidget,
      );
      expect(find.text('the reported message text'), findsOneWidget);
      expect(find.text('screenshot shared by the reporter'), findsOneWidget);
      expect(
        find.text(
          "The reporter's identity stays hidden unless the report is "
          'escalated.',
        ),
        findsOneWidget,
      );

      await scrollTo(tester, find.text('Record decision'));
      final record = find.widgetWithText(FilledButton, 'Record decision');
      expect(tester.widget<FilledButton>(record).onPressed, isNull);
      await tapVisible(tester, find.text('Not upheld'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Note'),
        'Not a breach of the rules.',
      );
      await scrollTo(tester, record);
      await tapVisible(tester, record);
      await tester.pumpAndSettle();
      expect(find.text('Record this decision?'), findsOneWidget);
      await tester.tap(confirmButton);
      await tester.pumpAndSettle();

      expect(
        server.calls,
        contains('resolve:not_upheld:Not a breach of the rules.'),
      );
      // Back on the queue, read again, with the decision confirmed.
      expect(find.text('Decision recorded.'), findsOneWidget);
      expect(find.text('No open reports'), findsOneWidget);
    });

    testWidgets('a short note is refused before anything is sent', (
      tester,
    ) async {
      server
        ..aal2 = true
        ..reports = [sampleSummary(grantActive: true)];
      await pumpQueue(tester);
      await openFirst(tester);
      await scrollTo(tester, find.text('Record decision'));
      await tapVisible(tester, find.text('Upheld'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Note'), 'ok');
      await tapVisible(
        tester,
        find.widgetWithText(FilledButton, 'Record decision'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Write at least 8 characters.'), findsOneWidget);
      expect(server.calls.where((call) => call.startsWith('resolve')), isEmpty);
    });

    testWidgets('without an authenticator it points to Account security', (
      tester,
    ) async {
      server.enrolled = false;
      await pumpQueue(tester);
      await openFirst(tester);
      await giveReason(tester, 'Alert received in the safety chat');

      expect(find.text('Set up two-factor sign-in first'), findsOneWidget);
      await tester.tap(find.text('Open account security'));
      await tester.pumpAndSettle();
      expect(securityOpened, 1);
      // Set up there: the code step follows.
      expect(find.text('Confirm it is you'), findsOneWidget);
    });

    testWidgets('a live grant opens straight away on a stepped-up session', (
      tester,
    ) async {
      server
        ..aal2 = true
        ..reports = [sampleSummary(grantActive: true)];
      await pumpQueue(tester);
      await openFirst(tester);
      expect(
        find.text('He keeps messaging me after I asked him to stop'),
        findsOneWidget,
      );
      expect(server.calls, ['queue', 'open:$sampleReportId']);
    });

    testWidgets('a live grant on a session without a second factor asks for '
        'the code only', (tester) async {
      server.reports = [sampleSummary(grantActive: true)];
      await pumpQueue(tester);
      await openFirst(tester);
      expect(find.text('Confirm it is you'), findsOneWidget);
      await giveCode(tester, '123456');
      expect(server.calls, [
        'queue',
        'open:$sampleReportId',
        'code:123456',
        'open:$sampleReportId',
      ]);
      expect(
        find.text('He keeps messaging me after I asked him to stop'),
        findsOneWidget,
      );
    });

    testWidgets('with two reviewers it does not ask for a reason it cannot '
        'use', (tester) async {
      server.singleReviewer = false;
      await pumpQueue(tester);
      await openFirst(tester);
      expect(find.text('A second reviewer has to approve'), findsOneWidget);
      expect(find.text('Why are you opening this report?'), findsNothing);
    });

    testWidgets('a second reviewer added meanwhile stops the approval', (
      tester,
    ) async {
      server.grantError = SafetyReviewError.secondApproverRequired;
      await pumpQueue(tester);
      await openFirst(tester);
      await giveReason(tester, 'Alert received in the safety chat');
      await giveCode(tester, '123456');
      expect(find.text('A second reviewer has to approve'), findsOneWidget);
    });

    testWidgets('an access that ended before the decision is asked for '
        'again', (tester) async {
      server
        ..aal2 = true
        ..reports = [sampleSummary(grantActive: true)]
        ..resolveError = SafetyReviewError.noGrant;
      await pumpQueue(tester);
      await openFirst(tester);
      await scrollTo(tester, find.text('Record decision'));
      await tapVisible(tester, find.text('No action'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Note'),
        'Nothing to act on here.',
      );
      await tapVisible(
        tester,
        find.widgetWithText(FilledButton, 'Record decision'),
      );
      await tester.pumpAndSettle();
      await tester.tap(confirmButton);
      await tester.pumpAndSettle();

      expect(find.text('Your access has ended'), findsOneWidget);
      await tester.tap(find.text('Ask for access again'));
      await tester.pumpAndSettle();
      expect(find.text('Why are you opening this report?'), findsOneWidget);
    });

    testWidgets('a report that changed offers a reload', (tester) async {
      server
        ..aal2 = true
        ..reports = [sampleSummary(grantActive: true)]
        ..openErrors.add(SafetyReviewError.changed);
      await pumpQueue(tester);
      await openFirst(tester);
      expect(find.text('This report changed'), findsOneWidget);
      await tester.tap(find.text('Reload'));
      await tester.pumpAndSettle();
      expect(
        find.text('He keeps messaging me after I asked him to stop'),
        findsOneWidget,
      );
    });

    testWidgets('an escalated report is not decided here', (tester) async {
      server
        ..aal2 = true
        ..reports = [sampleSummary(grantActive: true)]
        ..content = sampleReport(status: 'escalated');
      await pumpQueue(tester);
      await openFirst(tester);
      await scrollTo(tester, find.textContaining('cannot be decided here'));
      expect(find.text('Record decision'), findsNothing);
    });
  });

  group('Arabic and accessibility', () {
    testWidgets('the queue reads right to left in Arabic', (tester) async {
      await pumpQueue(tester, locale: const Locale('ar'));
      expect(find.text('بلاغات السلامة'), findsOneWidget);
      expect(find.text('بلاغ عن رسالة'), findsOneWidget);
      expect(
        directionOf(tester, find.text('بلاغ عن رسالة')),
        TextDirection.rtl,
      );
    });

    testWidgets('the code step reads right to left, its digits left to '
        'right', (tester) async {
      await pumpQueue(tester, locale: const Locale('ar'));
      await tester.tap(find.text('بلاغ عن رسالة'));
      await tester.pumpAndSettle();
      expect(find.text('لماذا تفتح هذا البلاغ؟'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'وصل تنبيه في المحادثة');
      await tester.tap(find.text('متابعة'));
      await tester.pumpAndSettle();
      expect(find.text('أكّد أنه أنت'), findsOneWidget);
      expect(directionOf(tester, find.text('أكّد أنه أنت')), TextDirection.rtl);
      expect(directionOf(tester, find.byType(TextField)), TextDirection.ltr);
    });

    for (final locale in const [Locale('en'), Locale('ar')]) {
      testWidgets('the queue and the report are accessible: '
          '${locale.languageCode}', (tester) async {
        final semantics = tester.ensureSemantics();
        server
          ..aal2 = true
          ..reports = [sampleSummary(grantActive: true)];
        await pumpQueue(tester, locale: locale);
        await expectAccessible(tester);
        await tester.tap(find.byType(InkWell).first);
        await tester.pumpAndSettle();
        await expectAccessible(tester);
        semantics.dispose();
      });
    }

    testWidgets('a report row is one labelled button', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpQueue(tester);
      final row = tester
          .getSemantics(find.text('Message report'))
          .getSemanticsData();
      expect(
        row.label,
        'Message report\nReport 22222222 · Filed 3 hours ago · '
        'Waiting\nHigh',
      );
      expect(row.hasAction(SemanticsAction.tap), isTrue);
      semantics.dispose();
    });
  });
}
