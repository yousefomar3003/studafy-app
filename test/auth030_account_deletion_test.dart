import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/core/account_lifecycle.dart';
import 'package:studafy/features/account/application/account_interactor.dart';
import 'package:studafy/features/account/domain/account_repository.dart';
import 'package:studafy/features/account/presentation/delete_account_page.dart';

import 'support/localized_app.dart';

/// AUTH-030 in-app account deletion (Apple 5.1.1(v), Google Play).
///
/// Two properties are load-bearing for store review: the user is told what the
/// school retains, and the user can stop the deletion without contacting
/// support.
class FakeAccountRepository implements AccountRepository {
  FakeAccountRepository({this.impact, this.failImpact = false});

  DeletionImpact? impact;
  bool failImpact;
  int requests = 0;
  int cancels = 0;
  String? lastReason;
  bool cancelSucceeds = true;

  @override
  Future<DeletionImpact> deletionImpact() async {
    if (failImpact) throw StateError('impact unavailable');
    return impact ?? _impact();
  }

  @override
  Future<DeletionRequest> requestAccountDeletion({
    required String reasonCode,
  }) async {
    requests++;
    lastReason = reasonCode;
    return DeletionRequest(
      id: 'request-1',
      state: 'grace_period',
      executeAfter: DateTime.utc(2026, 9, 27),
    );
  }

  @override
  Future<bool> cancelAccountDeletion() async {
    cancels++;
    return cancelSucceeds;
  }
}

DeletionImpact _impact({int attendance = 12, int grades = 4}) => DeletionImpact(
  schools: const ['Al-Noor International'],
  retainedSchoolRecords: {
    'attendance': attendance,
    'grades': grades,
    'submissions': 9,
    'wellbeing': 0,
  },
  deletedPersonalRecords: const {
    'profile': 1,
    'devices': 2,
    'consents': 1,
    'notifications': 7,
  },
  gracePeriodDays: 14,
);

Future<void> pumpPage(
  WidgetTester tester,
  FakeAccountRepository repository,
) async {
  // The form is a long scrolling list; the default 800x600 surface would leave
  // most of it unbuilt, so the assertions below would pass or fail on layout
  // rather than on content.
  tester.view.physicalSize = const Size(1200, 5000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    localizedApp(
      home: DeleteAccountPage(
        email: 'rana@alnoor.edu',
        account: AccountInteractor(repository),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Walks the form to the point where the destructive action is enabled.
Future<void> completeForm(WidgetTester tester) async {
  for (final checkbox
      in tester
          .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
          .toList()) {
    checkbox.onChanged!(true);
    await tester.pump();
  }
  await tester.tap(find.byType(DropdownButtonFormField<String>));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Privacy concerns').last);
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField), 'DELETE');
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the server-computed impact is shown, not generic copy', (
    tester,
  ) async {
    await pumpPage(tester, FakeAccountRepository());

    expect(find.text('WHAT YOUR SCHOOL KEEPS'), findsOneWidget);
    expect(find.text('Attendance records'), findsOneWidget);
    // The count comes from the server, so the user sees what actually remains.
    expect(find.text('12'), findsOneWidget);
    expect(find.text('Al-Noor International'), findsOneWidget);
  });

  testWidgets('retained school records are explained, not just listed', (
    tester,
  ) async {
    await pumpPage(tester, FakeAccountRepository());
    expect(
      find.textContaining('Schools are required to keep these education'),
      findsOneWidget,
    );
  });

  testWidgets('deletion cannot be scheduled without the typed confirmation', (
    tester,
  ) async {
    final repository = FakeAccountRepository();
    await pumpPage(tester, repository);

    for (final checkbox
        in tester
            .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
            .toList()) {
      checkbox.onChanged!(true);
      await tester.pump();
    }
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Privacy concerns').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'delete');
    await tester.pumpAndSettle();

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Schedule account deletion'),
    );
    expect(button.onPressed, isNull);
    expect(repository.requests, 0);
  });

  testWidgets('a completed form schedules deletion with the reason code', (
    tester,
  ) async {
    final repository = FakeAccountRepository();
    await pumpPage(tester, repository);
    await completeForm(tester);

    await tester.tap(
      find.widgetWithText(FilledButton, 'Schedule account deletion'),
    );
    await tester.pumpAndSettle();

    expect(repository.requests, 1);
    expect(repository.lastReason, 'privacy_concern');
    expect(find.text('Deletion scheduled'), findsOneWidget);
  });

  testWidgets('cancellation is reachable in app, without contacting support', (
    tester,
  ) async {
    final repository = FakeAccountRepository();
    await pumpPage(tester, repository);
    await completeForm(tester);
    await tester.tap(
      find.widgetWithText(FilledButton, 'Schedule account deletion'),
    );
    await tester.pumpAndSettle();

    // The old copy directed the user to support to cancel; both stores
    // require an in-app path. Saying they do *not* need support is fine, so
    // the assertion targets the directive, not the phrase.
    expect(
      find.textContaining('Contact Studafy support during that period'),
      findsNothing,
    );
    expect(
      find.textContaining('you do not need to contact support'),
      findsOneWidget,
    );
    expect(find.text('Keep my account'), findsOneWidget);

    await tester.tap(find.text('Keep my account'));
    await tester.pumpAndSettle();

    expect(repository.cancels, 1);
    expect(find.text('Deletion scheduled'), findsNothing);
  });

  testWidgets('an impact failure is recoverable rather than a dead end', (
    tester,
  ) async {
    final repository = FakeAccountRepository(failImpact: true);
    await pumpPage(tester, repository);

    expect(find.text('Try again'), findsOneWidget);

    repository.failImpact = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.text('WHAT WILL BE DELETED'), findsOneWidget);
  });

  testWidgets('a school with no retained records says so plainly', (
    tester,
  ) async {
    final repository = FakeAccountRepository(
      impact: DeletionImpact(
        schools: const [],
        retainedSchoolRecords: const {
          'attendance': 0,
          'grades': 0,
          'submissions': 0,
          'wellbeing': 0,
        },
        deletedPersonalRecords: const {'profile': 1},
        gracePeriodDays: 14,
      ),
    );
    await pumpPage(tester, repository);

    expect(
      find.text('Your school holds no records for this account.'),
      findsOneWidget,
    );
  });
}
