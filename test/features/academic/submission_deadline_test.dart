import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/core/file_upload_repository.dart';
import 'package:studafy/features/academic/domain/academic_repository.dart';
import 'package:studafy/features/academic/presentation/submit_work_page.dart';

import '../../support/academic_repository_fake.dart';
import '../../support/localized_app.dart';

/// The deadline as the student sees it. The server enforces it on every
/// hand-in (supabase/tests/submission_deadlines.sql); the screen says so
/// before the student types, on the school's clock.
Widget _handIn(SubmitFake fake, SubmissionDeadline deadline) => localizedApp(
  home: SubmitWorkPage(
    repository: fake,
    assignmentId: 'a1',
    assignmentTitle: 'Essay',
    deadline: deadline,
  ),
);

void _tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('an open piece of work shows its deadline in school time', (
    tester,
  ) async {
    _tall(tester);
    await tester.pumpWidget(
      _handIn(
        SubmitFake(),
        const SubmissionDeadline(
          state: SubmissionWindow.open,
          deadlineLocal: '2026-10-01T23:59',
          timeZone: 'Asia/Riyadh',
          extendedUntilLocal: '2026-10-01T23:59',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('(\u2066Asia/\u2060Riyadh\u2069)'),
      findsOneWidget,
    );
    expect(find.textContaining('11:59'), findsWidgets);
    expect(find.textContaining('You have extra time until'), findsOneWidget);
    expect(find.text('Hand in'), findsOneWidget);
  });

  testWidgets('in Arabic the deadline date and time both use 0-9', (
    tester,
  ) async {
    _tall(tester);
    await tester.pumpWidget(
      localizedApp(
        locale: const Locale('ar'),
        home: SubmitWorkPage(
          repository: SubmitFake(),
          assignmentId: 'a1',
          assignmentTitle: 'Essay',
          deadline: const SubmissionDeadline(
            state: SubmissionWindow.open,
            deadlineLocal: '2026-10-05T23:59',
            timeZone: 'Asia/Amman',
            extendedUntilLocal: '2026-10-07T08:30',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final due = tester.widget<Text>(find.textContaining('Amman')).data!;
    final extended = tester
        .widget<Text>(find.textContaining('لديك وقت إضافي'))
        .data!;
    for (final line in [due, extended]) {
      expect(RegExp('[٠-٩۰-۹]').hasMatch(line), isFalse, reason: line);
    }
    expect(due, contains('5'));
    expect(due, contains('11:59'));
    expect(extended, contains('7'));
    expect(extended, contains('8:30'));
  });

  testWidgets('after the deadline there is nothing to type into', (
    tester,
  ) async {
    _tall(tester);
    await tester.pumpWidget(
      _handIn(
        SubmitFake(),
        const SubmissionDeadline(
          state: SubmissionWindow.closed,
          deadlineLocal: '2026-09-01T23:59',
          timeZone: 'Asia/Riyadh',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('The deadline has passed.'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('marked work cannot be replaced, and says why', (tester) async {
    _tall(tester);
    await tester.pumpWidget(
      _handIn(
        SubmitFake(),
        const SubmissionDeadline(
          state: SubmissionWindow.gradedLocked,
          deadlineLocal: '2026-10-01T23:59',
          timeZone: 'Asia/Riyadh',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Marked - it can no longer be replaced.'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('replacing work keeps the earlier files unless unticked', (
    tester,
  ) async {
    _tall(tester);
    final fake = SubmitFake()
      ..history = [
        SubmissionAttempt(
          id: 'at1',
          submittedAt: DateTime(2026, 9, 22),
          current: true,
          answerText: 'First go',
          attachments: const [
            StoredAttachment(
              id: 'f1',
              displayName: 'essay.pdf',
              sizeBytes: 10,
              scanState: 'clean',
              mediaType: 'application/pdf',
            ),
          ],
        ),
      ];
    await tester.pumpWidget(
      _handIn(
        fake,
        const SubmissionDeadline(
          state: SubmissionWindow.open,
          deadlineLocal: '2026-10-01T23:59',
          timeZone: 'Asia/Riyadh',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Second go');
    // Work already handed in is replaced, and the button says so.
    await tester.ensureVisible(find.text('Hand in again'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hand in again'));
    await tester.pumpAndSettle();
    expect(fake.submitted.single.attachments, ['f1']);
  });
}
