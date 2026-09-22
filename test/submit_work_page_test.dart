import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/features/academic/presentation/submit_work_page.dart';

import 'support/academic_repository_fake.dart';
import 'support/localized_app.dart';

Widget _page(SubmitFake fake, {bool canSubmit = true, Locale? locale}) =>
    localizedApp(
      locale: locale,
      home: SubmitWorkPage(
        repository: fake,
        assignmentId: 'a1',
        assignmentTitle: 'Read chapter 3',
        canSubmit: canSubmit,
      ),
    );

void main() {
  testWidgets('a student hands work in against the assignment', (tester) async {
    final fake = SubmitFake();
    await tester.pumpWidget(_page(fake));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'My answer');
    await tester.tap(find.text('Hand in'));
    await tester.pumpAndSettle();

    expect(fake.submitted, hasLength(1));
    expect(fake.submitted.single.assignmentId, 'a1');
    expect(fake.submitted.single.answer, 'My answer');
  });

  testWidgets('empty work is refused rather than sent', (tester) async {
    final fake = SubmitFake();
    await tester.pumpWidget(_page(fake));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Hand in'));
    await tester.pumpAndSettle();

    expect(
      find.text('Write your answer before handing it in.'),
      findsOneWidget,
    );
    expect(fake.submitted, isEmpty);
  });

  testWidgets('work that is not open says so before anything is typed', (
    tester,
  ) async {
    final fake = SubmitFake();
    await tester.pumpWidget(_page(fake, canSubmit: false));
    await tester.pumpAndSettle();

    expect(find.text('This assignment is not open for work.'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('attachments are named as unavailable, not offered', (
    tester,
  ) async {
    // Offering a button that cannot work is worse than saying so.
    final fake = SubmitFake();
    await tester.pumpWidget(_page(fake));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Attaching files is not available yet; paste a link if you need to '
        'share one.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('a failure keeps the work on screen', (tester) async {
    final fake = SubmitFake(fail: true);
    await tester.pumpWidget(_page(fake));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'My answer');
    await tester.tap(find.text('Hand in'));
    await tester.pumpAndSettle();

    expect(
      find.text('Could not hand in your work. Please try again.'),
      findsOneWidget,
    );
    expect(find.text('My answer'), findsOneWidget);
  });

  testWidgets('hand-in reads in Arabic', (tester) async {
    final fake = SubmitFake();
    await tester.pumpWidget(_page(fake, locale: const Locale('ar')));
    await tester.pumpAndSettle();

    expect(find.text('تسليم'), findsOneWidget);
  });
}
