import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/features/academic/domain/academic_repository.dart';
import 'package:studafy/features/academic/presentation/class_roster_page.dart';

import 'support/academic_repository_fake.dart';
import 'support/localized_app.dart';

Widget _page(
  RosterFake fake, {
  void Function(StudentGuardian)? onMessage,
  Locale? locale,
}) => localizedApp(
  locale: locale,
  home: ClassRosterPage(
    repository: fake,
    classroomId: 'class-1',
    classroomName: 'Grade 7 Science',
    onMessageGuardian: onMessage,
  ),
);

void main() {
  testWidgets('each child is listed with their Studafy id', (tester) async {
    final fake = RosterFake(
      students: const [
        ClassStudent(id: 's1', displayName: 'Amal', studafyId: 'SJ-0001'),
      ],
    );
    await tester.pumpWidget(_page(fake));
    await tester.pumpAndSettle();

    expect(find.text('Amal'), findsOneWidget);
    expect(find.text('SJ-0001'), findsOneWidget);
  });

  testWidgets('a child with no linked parent says so', (tester) async {
    // Left blank, a teacher cannot tell "nobody linked" from "still loading".
    final fake = RosterFake(
      students: const [
        ClassStudent(id: 's1', displayName: 'Amal', studafyId: 'SJ-0001'),
      ],
    );
    await tester.pumpWidget(_page(fake));
    await tester.pumpAndSettle();

    expect(find.text('No parent linked yet'), findsOneWidget);
  });

  testWidgets('guardians appear against the right child', (tester) async {
    final fake = RosterFake(
      students: const [
        ClassStudent(
          id: 's1',
          displayName: 'Amal',
          studafyId: 'SJ-0001',
          guardians: [StudentGuardian(userId: 'g1', displayName: 'Huda')],
        ),
        ClassStudent(
          id: 's2',
          displayName: 'Bilal',
          studafyId: 'SJ-0002',
          guardians: [StudentGuardian(userId: 'g2', displayName: 'Omar')],
        ),
      ],
    );
    await tester.pumpWidget(_page(fake));
    await tester.pumpAndSettle();

    expect(find.text('Huda'), findsOneWidget);
    expect(find.text('Omar'), findsOneWidget);
  });

  testWidgets('contacting a guardian is offered only when messaging is on', (
    tester,
  ) async {
    final fake = RosterFake(
      students: const [
        ClassStudent(
          id: 's1',
          displayName: 'Amal',
          studafyId: 'SJ-0001',
          guardians: [StudentGuardian(userId: 'g1', displayName: 'Huda')],
        ),
      ],
    );

    // Messaging unavailable: the guardian is named but not actionable,
    // rather than offering a button that would only fail.
    await tester.pumpWidget(_page(fake));
    await tester.pumpAndSettle();
    expect(find.byType(ActionChip), findsNothing);
    expect(find.byType(Chip), findsOneWidget);

    final tapped = <String>[];
    await tester.pumpWidget(
      _page(fake, onMessage: (guardian) => tapped.add(guardian.userId)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ActionChip));
    await tester.pumpAndSettle();
    expect(tapped, ['g1']);
  });

  testWidgets('an empty class says so instead of showing nothing', (
    tester,
  ) async {
    await tester.pumpWidget(_page(RosterFake(students: const [])));
    await tester.pumpAndSettle();

    expect(
      find.text('No students are enrolled in this class yet.'),
      findsOneWidget,
    );
  });

  testWidgets('a failed load offers a retry', (tester) async {
    final fake = RosterFake(students: const [], fail: true);
    await tester.pumpWidget(_page(fake));
    await tester.pumpAndSettle();

    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('the roster reads in Arabic', (tester) async {
    final fake = RosterFake(
      students: const [
        ClassStudent(id: 's1', displayName: 'أمل', studafyId: 'SJ-0001'),
      ],
    );
    await tester.pumpWidget(_page(fake, locale: const Locale('ar')));
    await tester.pumpAndSettle();

    expect(find.text('لا يوجد وليّ أمر مرتبط بعد'), findsOneWidget);
    expect(
      Directionality.of(tester.element(find.text('أمل'))),
      TextDirection.rtl,
    );
  });
}
