import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/features/academic/domain/academic_repository.dart';
import 'package:studafy/features/academic/presentation/attendance_page.dart';

import '../../support/academic_repository_fake.dart';
import '../../support/localized_app.dart';

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

    // Unmarked until the teacher says otherwise, and every state is one
    // tap away on the student's card.
    expect(find.text('Not marked'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.expand_more_rounded));
    await tester.pumpAndSettle();
    for (final label in ['Present', 'Absent', 'Tardy', 'Excused absence']) {
      expect(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text(label),
        ),
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
    await _mark(tester, 'Excused absence');
    expect(find.text('Reason (optional)'), findsOneWidget);

    // Marking present again retracts the reason: it no longer means anything.
    await _mark(tester, 'Present');
    expect(find.text('Reason (optional)'), findsNothing);
  });

  testWidgets('mark all present, then change one student', (tester) async {
    final fake = AttendanceFake(
      schedule: _twiceOnMonday,
      roster: const [
        AttendanceRosterEntry(studentId: 's1', displayName: 'Amal'),
        AttendanceRosterEntry(studentId: 's2', displayName: 'Bilal'),
        AttendanceRosterEntry(studentId: 's3', displayName: 'Carim'),
      ],
    );
    await tester.pumpWidget(_page(fake, on: _nextWeekday(DateTime.monday)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mark all present'));
    await tester.pumpAndSettle();
    // Nothing is sent until the teacher saves, and the screen says so.
    expect(find.text('Unsaved changes'), findsOneWidget);
    expect(fake.recorded, isEmpty);
    await _mark(tester, 'Absent', student: 1);
    await tester.tap(find.text('Save attendance'));
    await tester.pumpAndSettle();

    final entries = {
      for (final entry in fake.recorded.single.entries)
        entry.studentId: entry.state,
    };
    expect(entries, {'s1': 'present', 's2': 'absent', 's3': 'present'});
    // Confirmed on screen, and nothing is left unsaved.
    expect(find.text('Register saved for 3 students.'), findsWidgets);
    expect(find.text('Unsaved changes'), findsNothing);
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

    await _mark(tester, 'Absent');
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
    await _mark(tester, 'Present');
    await tester.tap(find.text('Save attendance'));
    await tester.pumpAndSettle();

    final call = fake.recorded.single;
    expect(call.startsAt!.hour, 13);
    expect(call.endsAt!.hour, 14);
    expect(call.startsAt!.day, monday.day);
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

    await _mark(tester, 'Present');
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

    expect(find.text('حفظ الحضور'), findsOneWidget);
    expect(find.text('أي حصة؟'), findsOneWidget);
    expect(find.text('تحديد الجميع حاضرين'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.expand_more_rounded));
    await tester.pumpAndSettle();
    expect(find.text('حاضر'), findsOneWidget);
    expect(find.text('غائب'), findsOneWidget);
    expect(find.text('متأخر'), findsOneWidget);
    expect(
      Directionality.of(tester.element(find.text('حاضر'))),
      TextDirection.rtl,
    );
  });

  group('choosing the lesson', () {
    // A class that meets once a week, on the day after today - so today is
    // never a lesson day, which is exactly when the register used to open on
    // "no lesson" with Save disabled.
    final tomorrow = DateTime.now().add(const Duration(days: 1)).weekday;
    final weekly = [
      ClassSessionSlot(weekday: tomorrow, startsAt: '08:00', endsAt: '08:50'),
    ];
    const roster = [
      AttendanceRosterEntry(studentId: 's1', displayName: 'Amal'),
    ];

    testWidgets('opened on a day without a lesson, it goes to the last one', (
      tester,
    ) async {
      final fake = AttendanceFake(schedule: weekly, roster: roster);
      await tester.pumpWidget(_page(fake));
      await tester.pumpAndSettle();

      final opened = fake.rosterCalls.last;
      expect(opened, isNotNull);
      expect(opened!.weekday, tomorrow);
      expect(opened.isBefore(DateTime.now()), isTrue);
      expect(find.text('Amal'), findsOne);
    });

    testWidgets('the arrows step from lesson to lesson', (tester) async {
      final fake = AttendanceFake(schedule: weekly, roster: roster);
      final start = _nextWeekday(tomorrow);
      await tester.pumpWidget(_page(fake, on: start));
      await tester.pumpAndSettle();
      final first = fake.rosterCalls.last!;

      await tester.tap(find.byTooltip('Next lesson'));
      await tester.pumpAndSettle();
      expect(fake.rosterCalls.last!.difference(first).inDays, 7);

      await tester.tap(find.byTooltip('Previous lesson'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Previous lesson'));
      await tester.pumpAndSettle();
      expect(first.difference(fake.rosterCalls.last!).inDays, 7);
    });
  });

  group('the school\'s attendance policy', () {
    const roster = [
      AttendanceRosterEntry(
        studentId: 's1',
        displayName: 'Amal',
        state: AttendanceState.present,
      ),
    ];

    testWidgets('a locked register cannot be changed or saved', (tester) async {
      final fake = AttendanceFake(
        schedule: _twiceOnMonday,
        roster: roster,
        version: 3,
        sessionId: 'session-1',
        editRule: AttendanceEditRule.locked,
      );
      await tester.pumpWidget(_page(fake, on: _nextWeekday(DateTime.monday)));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'This register is locked by your school\'s attendance policy.',
        ),
        findsOneWidget,
      );
      final save = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Save attendance'),
      );
      expect(save.onPressed, isNull);
    });

    testWidgets('a past lesson is corrected by the lesson, with its reason', (
      tester,
    ) async {
      final fake = AttendanceFake(
        schedule: _twiceOnMonday,
        roster: roster,
        version: 3,
        sessionId: 'session-1',
        editRule: AttendanceEditRule.reasonRequired,
      );
      await tester.pumpWidget(_page(fake, on: _nextWeekday(DateTime.monday)));
      await tester.pumpAndSettle();

      await _mark(tester, 'Absent');
      await tester.enterText(
        find.widgetWithText(TextField, 'Reason for the change'),
        'Parent called',
      );
      await tester.tap(find.text('Save attendance'));
      await tester.pumpAndSettle();

      final call = fake.recorded.single;
      expect(call.sessionId, 'session-1');
      expect(call.reason, 'Parent called');
      expect(fake.recordedVersions.single, 3);
    });

    testWidgets('a lead teacher overrides a lock only by choosing to', (
      tester,
    ) async {
      final fake = AttendanceFake(
        schedule: _twiceOnMonday,
        roster: roster,
        version: 3,
        sessionId: 'session-1',
        editRule: AttendanceEditRule.lockedOverride,
      );
      await tester.pumpWidget(_page(fake, on: _nextWeekday(DateTime.monday)));
      await tester.pumpAndSettle();

      final locked = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Save attendance'),
      );
      expect(locked.onPressed, isNull);

      await tester.tap(find.text('Override the lock'));
      await tester.pumpAndSettle();
      await _mark(tester, 'Tardy');
      await tester.enterText(
        find.widgetWithText(TextField, 'Reason for the change'),
        'Register was misread',
      );
      await tester.tap(find.text('Save attendance'));
      await tester.pumpAndSettle();

      expect(fake.recorded.single.override, isTrue);
      expect(fake.recorded.single.reason, 'Register was misread');
    });

    testWidgets('a refusal says why', (tester) async {
      final fake = AttendanceFake(
        schedule: _twiceOnMonday,
        roster: roster,
        version: 3,
        sessionId: 'session-1',
        editRule: AttendanceEditRule.reasonRequired,
        refusal: const CourseworkRefusal(CourseworkProblem.reasonRequired),
      );
      await tester.pumpWidget(_page(fake, on: _nextWeekday(DateTime.monday)));
      await tester.pumpAndSettle();

      await _mark(tester, 'Absent');
      await tester.tap(find.text('Save attendance'));
      await tester.pumpAndSettle();

      expect(
        find.text('Please give a reason. It is kept with the change.'),
        findsOneWidget,
      );
    });
  });

  testWidgets('a student who left but was marked still shows, labelled', (
    tester,
  ) async {
    final fake = AttendanceFake(
      schedule: _twiceOnMonday,
      roster: const [
        AttendanceRosterEntry(studentId: 's1', displayName: 'Amal'),
        AttendanceRosterEntry(
          studentId: 's2',
          displayName: 'Bilal',
          state: AttendanceState.present,
          enrolled: false,
        ),
      ],
    );
    await tester.pumpWidget(_page(fake, on: _nextWeekday(DateTime.monday)));
    await tester.pumpAndSettle();

    expect(find.text('Bilal'), findsOneWidget);
    expect(find.text('Left the class'), findsOneWidget);
  });
}

/// Opens a student's attendance choices and picks [label]. The mark is a
/// button on the student's card; the choices open in a sheet.
Future<void> _mark(WidgetTester tester, String label, {int student = 0}) async {
  await tester.tap(find.byIcon(Icons.expand_more_rounded).at(student));
  await tester.pumpAndSettle();
  await tester.tap(
    find.descendant(of: find.byType(BottomSheet), matching: find.text(label)),
  );
  await tester.pumpAndSettle();
}
