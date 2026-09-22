import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/features/academic/domain/academic_repository.dart';
import 'package:studafy/features/academic/presentation/class_sections_page.dart';

import 'support/academic_repository_fake.dart';
import 'support/localized_app.dart';

LessonSession _session({required bool filed, String id = 's1'}) =>
    LessonSession(
      id: id,
      startsAt: DateTime(2026, 9, 21, 8),
      endsAt: DateTime(2026, 9, 21, 9),
      filed: filed,
    );

Widget _page(SectionsFake fake, {Locale? locale}) => localizedApp(
  locale: locale,
  home: ClassSectionsPage(
    repository: fake,
    classroomId: 'c1',
    classroomName: 'Grade 7 Science',
  ),
);

void main() {
  testWidgets('a section still owing content is flagged and actionable', (
    tester,
  ) async {
    final fake = SectionsFake(sessions: [_session(filed: false)]);
    await tester.pumpWidget(_page(fake));
    await tester.pumpAndSettle();

    expect(find.text('Content outstanding'), findsOneWidget);
    expect(find.text('File content'), findsOneWidget);
    expect(find.text('Close section'), findsOneWidget);
  });

  testWidgets('a closed section offers nothing further', (tester) async {
    final fake = SectionsFake(sessions: [_session(filed: true)]);
    await tester.pumpWidget(_page(fake));
    await tester.pumpAndSettle();

    expect(find.text('Closed'), findsOneWidget);
    expect(find.text('File content'), findsNothing);
    expect(find.text('Close section'), findsNothing);
  });

  testWidgets('closing an unfiled section says what is missing', (
    tester,
  ) async {
    // The surface refuses it; the teacher is told why rather than shown a
    // generic failure.
    final fake = SectionsFake(
      sessions: [_session(filed: false)],
      closeFails: true,
    );
    await tester.pumpWidget(_page(fake));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Close section'));
    await tester.pumpAndSettle();

    expect(
      find.text('File the content taught in this section before closing it.'),
      findsOneWidget,
    );
  });

  testWidgets('filed content is attached to that section', (tester) async {
    final fake = SectionsFake(sessions: [_session(filed: false)]);
    await tester.pumpWidget(_page(fake));
    await tester.pumpAndSettle();

    await tester.tap(find.text('File content'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Covered waves');
    await tester.tap(find.text('File it'));
    await tester.pumpAndSettle();

    expect(fake.filed, hasLength(1));
    // Not merely attached to the class: to the meeting it was taught in.
    expect(fake.filed.single.lessonSessionId, 's1');
    expect(fake.filed.single.body, 'Covered waves');
  });

  testWidgets('sections read in Arabic', (tester) async {
    final fake = SectionsFake(sessions: [_session(filed: false)]);
    await tester.pumpWidget(_page(fake, locale: const Locale('ar')));
    await tester.pumpAndSettle();

    expect(find.text('المحتوى غير مرفوع'), findsOneWidget);
  });
}
