import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/features/academic/domain/academic_repository.dart';
import 'package:studafy/features/academic/presentation/class_schedule_page.dart';

import 'support/academic_repository_fake.dart';
import 'support/localized_app.dart';

Widget _page(
  ScheduleFake fake, {
  List<ClassSessionSlot> slots = const [],
  Locale? locale,
}) => localizedApp(
  locale: locale,
  home: ClassSchedulePage(
    repository: fake,
    classroomId: 'c1',
    classroomName: 'Grade 7 Science',
    expectedVersion: 3,
    initialSlots: slots,
  ),
);

void main() {
  testWidgets('an existing timetable is shown for editing', (tester) async {
    final fake = ScheduleFake();
    await tester.pumpWidget(
      _page(
        fake,
        slots: const [
          ClassSessionSlot(weekday: 1, startsAt: '08:00', endsAt: '09:00'),
          ClassSessionSlot(weekday: 3, startsAt: '10:00', endsAt: '11:00'),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('08:00–09:00'), findsOneWidget);
    expect(find.text('10:00–11:00'), findsOneWidget);
  });

  testWidgets('a class with no timetable is told why that matters', (
    tester,
  ) async {
    // Attendance is refused for a session that matches no slot, so an empty
    // timetable means the register cannot be taken at all.
    final fake = ScheduleFake();
    await tester.pumpWidget(_page(fake));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'No meetings yet. Add one so the register knows when this class '
        'meets.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('saving sends the whole timetable', (tester) async {
    final fake = ScheduleFake();
    await tester.pumpWidget(
      _page(
        fake,
        slots: const [
          ClassSessionSlot(weekday: 1, startsAt: '08:00', endsAt: '09:00'),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save timetable'));
    await tester.pumpAndSettle();

    expect(fake.saved, hasLength(1));
    expect(fake.saved.single.single.startsAt, '08:00');
    expect(find.text('Timetable saved.'), findsOneWidget);
  });

  testWidgets('a removed meeting is not sent', (tester) async {
    final fake = ScheduleFake();
    await tester.pumpWidget(
      _page(
        fake,
        slots: const [
          ClassSessionSlot(weekday: 1, startsAt: '08:00', endsAt: '09:00'),
          ClassSessionSlot(weekday: 3, startsAt: '10:00', endsAt: '11:00'),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save timetable'));
    await tester.pumpAndSettle();

    expect(fake.saved.single, hasLength(1));
    expect(fake.saved.single.single.startsAt, '10:00');
  });

  testWidgets('a failure is reported and nothing is claimed saved', (
    tester,
  ) async {
    final fake = ScheduleFake(fail: true);
    await tester.pumpWidget(
      _page(
        fake,
        slots: const [
          ClassSessionSlot(weekday: 1, startsAt: '08:00', endsAt: '09:00'),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save timetable'));
    await tester.pumpAndSettle();

    expect(
      find.text('Could not save the timetable. Please try again.'),
      findsOneWidget,
    );
    expect(find.text('Timetable saved.'), findsNothing);
  });

  testWidgets('the timetable reads in Arabic', (tester) async {
    final fake = ScheduleFake();
    await tester.pumpWidget(_page(fake, locale: const Locale('ar')));
    await tester.pumpAndSettle();

    expect(find.text('حفظ الجدول'), findsOneWidget);
  });
}
