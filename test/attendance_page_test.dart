import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/features/academic/domain/academic_repository.dart';
import 'package:studafy/features/academic/presentation/attendance_page.dart';

import 'support/academic_repository_fake.dart';
import 'support/localized_app.dart';

/// Monday and Wednesday, and twice on Monday: the case the register has to
/// get right, because a date alone cannot say which lesson was marked.
final _twiceOnMonday = <ClassSessionSlot>[
  const ClassSessionSlot(weekday: 1, startsAt: '08:00', endsAt: '09:00'),
  const ClassSessionSlot(weekday: 1, startsAt: '13:00', endsAt: '14:00'),
  const ClassSessionSlot(weekday: 3, startsAt: '10:00', endsAt: '11:00'),
];

DateTime _nextWeekday(int weekday) {
  var date = DateTime.now();
  while (date.weekday != weekday) {
    date = date.add(const Duration(days: 1));
  }
  return date;
}

Widget _page(AttendanceFake fake, {DateTime? on, Locale? locale}) =>
    localizedApp(
      locale: locale,
      home: AttendancePage(
        repository: fake,
        classroomId: 'class-1',
        classroomName: 'Grade 7 Science',
        initialDate: on,
      ),
    );

void main() {
  testWidgets('every state a teacher needs is offered per student', (
    tester,
  ) async {
    final fake = AttendanceFake(
      schedule: _twiceOnMonday,
      roster: const [
        AttendanceRosterEntry(studentId: 's1', displayName: 'Amal'),
      ],
    );
    await tester.pumpWidget(_page(fake, on: _nextWeekday(DateTime.monday)));
    await tester.pumpAndSettle();

    for (final label in ['Present', 'Absent', 'Tardy', 'Excused absence']) {
      expect(
        find.text(label),
        findsOneWidget,
        reason: '$label must be offered',
      );
    }
  });

  testWidgets('a reason is offered for anything other than present', (
    tester,
  ) async {
    final fake = AttendanceFake(
      schedule: _twiceOnMonday,
      roster: const [
        AttendanceRosterEntry(studentId: 's1', displayName: 'Amal'),
      ],
    );
    await tester.pumpWidget(_page(fake, on: _nextWeekday(DateTime.monday)));
    await tester.pumpAndSettle();

    expect(find.text('Reason (optional)'), findsNothing);
    await tester.tap(find.text('Excused absence'));
    await tester.pumpAndSettle();
    expect(find.text('Reason (optional)'), findsOneWidget);

    // Marking present again retracts the reason: it no longer means anything.
    await tester.tap(find.text('Present'));
    await tester.pumpAndSettle();
    expect(find.text('Reason (optional)'), findsNothing);
  });

  testWidgets('a class meeting twice in a day makes the teacher choose', (
    tester,
  ) async {
    final fake = AttendanceFake(
      schedule: _twiceOnMonday,
      roster: const [
        AttendanceRosterEntry(studentId: 's1', displayName: 'Amal'),
      ],
    );
    await tester.pumpWidget(_page(fake, on: _nextWeekday(DateTime.monday)));
    await tester.pumpAndSettle();

    expect(find.text('Which session?'), findsOneWidget);
    expect(find.text('08:00–09:00'), findsOneWidget);
    expect(find.text('13:00–14:00'), findsOneWidget);
  });

  testWidgets('an unmarked student is never sent as present', (tester) async {
    // An unmarked student is not an absent one. Guessing would put an
    // unearned mark on a child's record.
    final fake = AttendanceFake(
      schedule: _twiceOnMonday,
      roster: const [
        AttendanceRosterEntry(studentId: 's1', displayName: 'Amal'),
        AttendanceRosterEntry(studentId: 's2', displayName: 'Bilal'),
      ],
    );
    await tester.pumpWidget(_page(fake, on: _nextWeekday(DateTime.monday)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Absent').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save attendance'));
    await tester.pumpAndSettle();

    expect(fake.recorded, hasLength(1));
    expect(fake.recorded.single.entries.map((e) => e.studentId), ['s1']);
    expect(fake.recorded.single.entries.single.state, 'absent');
  });

  testWidgets(
    'saving nothing is refused rather than sending an empty register',
    (tester) async {
      final fake = AttendanceFake(
        schedule: _twiceOnMonday,
        roster: const [
          AttendanceRosterEntry(studentId: 's1', displayName: 'Amal'),
        ],
      );
      await tester.pumpWidget(_page(fake, on: _nextWeekday(DateTime.monday)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save attendance'));
      await tester.pumpAndSettle();

      expect(fake.recorded, isEmpty);
      expect(find.text('Mark at least one student first.'), findsOneWidget);
    },
  );

  testWidgets('the register is saved against the chosen session times', (
    tester,
  ) async {
    final monday = _nextWeekday(DateTime.monday);
    final fake = AttendanceFake(
      schedule: _twiceOnMonday,
      roster: const [
        AttendanceRosterEntry(studentId: 's1', displayName: 'Amal'),
      ],
    );
    await tester.pumpWidget(_page(fake, on: monday));
    await tester.pumpAndSettle();

    await tester.tap(find.text('13:00–14:00'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Present'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save attendance'));
    await tester.pumpAndSettle();

    final call = fake.recorded.single;
    expect(call.startsAt.hour, 13);
    expect(call.endsAt.hour, 14);
    expect(call.startsAt.day, monday.day);
  });

  testWidgets('marks already recorded come back selected', (tester) async {
    final fake = AttendanceFake(
      schedule: _twiceOnMonday,
      roster: const [
        AttendanceRosterEntry(
          studentId: 's1',
          displayName: 'Amal',
          state: AttendanceState.excused,
          reason: 'Medical appointment',
        ),
      ],
    );
    await tester.pumpWidget(_page(fake, on: _nextWeekday(DateTime.monday)));
    await tester.pumpAndSettle();

    // The existing reason is shown, so a teacher revisiting the register
    // edits what is there instead of retyping it.
    expect(find.text('Medical appointment'), findsOneWidget);
  });

  testWidgets('a day the class does not meet says so', (tester) async {
    final fake = AttendanceFake(
      schedule: const [
        ClassSessionSlot(weekday: 3, startsAt: '10:00', endsAt: '11:00'),
      ],
      roster: const [
        AttendanceRosterEntry(studentId: 's1', displayName: 'Amal'),
      ],
    );
    await tester.pumpWidget(_page(fake, on: _nextWeekday(DateTime.monday)));
    await tester.pumpAndSettle();

    expect(
      find.text('This class does not meet on the day you picked.'),
      findsOneWidget,
    );
  });

  testWidgets('the session version is echoed back, not a hardcoded zero', (
    tester,
  ) async {
    // recordAttendance demands 0 only when creating the session and the
    // current version thereafter, so a hardcoded 0 let a teacher save a
    // register once and never correct it.
    final fake = AttendanceFake(
      schedule: _twiceOnMonday,
      roster: const [
        AttendanceRosterEntry(studentId: 's1', displayName: 'Amal'),
      ],
      version: 7,
    );
    await tester.pumpWidget(_page(fake, on: _nextWeekday(DateTime.monday)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Present'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save attendance'));
    await tester.pumpAndSettle();

    expect(fake.recordedVersions, [7]);
  });

  testWidgets('each meeting reads its own register', (tester) async {
    final monday = _nextWeekday(DateTime.monday);
    final fake = AttendanceFake(
      schedule: _twiceOnMonday,
      roster: const [
        AttendanceRosterEntry(studentId: 's1', displayName: 'Amal'),
      ],
    );
    await tester.pumpWidget(_page(fake, on: monday));
    await tester.pumpAndSettle();

    await tester.tap(find.text('13:00–14:00'));
    await tester.pumpAndSettle();

    // The afternoon lesson is read separately; showing the morning marks
    // against it would merge two registers.
    expect(fake.rosterCalls.last?.hour, 13);
  });

  testWidgets('the register reads in Arabic and lays out right-to-left', (
    tester,
  ) async {
    final fake = AttendanceFake(
      schedule: _twiceOnMonday,
      roster: const [
        AttendanceRosterEntry(studentId: 's1', displayName: 'أمل'),
      ],
    );
    await tester.pumpWidget(
      _page(
        fake,
        on: _nextWeekday(DateTime.monday),
        locale: const Locale('ar'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('حاضر'), findsOneWidget);
    expect(find.text('غائب'), findsOneWidget);
    expect(find.text('متأخر'), findsOneWidget);
    expect(find.text('حفظ الحضور'), findsOneWidget);
    expect(find.text('أي حصة؟'), findsOneWidget);
    expect(
      Directionality.of(tester.element(find.text('حاضر'))),
      TextDirection.rtl,
    );
  });
}
