import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/features/meetings/domain/meetings.dart';
import 'package:studafy/features/meetings/presentation/upcoming_meetings_section.dart';
import 'package:studafy/features/school_operations/data/preview_school_operations_repository.dart';
import 'package:studafy/features/school_operations/domain/school_operations_repository.dart';
import 'package:studafy/features/school_operations/presentation/classroom_management_page.dart';

import 'support/localized_app.dart';

/// Meetings hosted on Google Meet: the teacher pastes the link, and the
/// people invited see the meeting and join from it. Who is invited, and the
/// link allowlist, are enforced by the server and proven in
/// apps/api/test/meetings; this is what the screens do.
void main() {
  final now = DateTime(2026, 10, 1, 9);
  final meet = Uri.parse('https://meet.google.com/abc-defg-hij');

  UpcomingMeeting meeting({
    String state = 'scheduled',
    Uri? url,
    DateTime? ends,
  }) => UpcomingMeeting(
    id: 'm1',
    classroomName: 'Grade 7 Science',
    title: "Parents' evening",
    startsAt: now.add(const Duration(hours: 2)),
    endsAt: ends ?? now.add(const Duration(hours: 3)),
    state: state,
    meetUrl: url,
  );

  Widget section(List<UpcomingMeeting> items, List<Uri> launched) =>
      localizedApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: UpcomingMeetingsSection(
              repository: _Meetings(items),
              now: () => now,
              launch: (url) async {
                launched.add(url);
                return true;
              },
            ),
          ),
        ),
      );

  group('upcoming meetings', () {
    testWidgets('a scheduled meeting opens Google Meet on Join', (
      tester,
    ) async {
      final launched = <Uri>[];
      await tester.pumpWidget(section([meeting(url: meet)], launched));
      await tester.pumpAndSettle();

      expect(find.text('Upcoming meetings'), findsOne);
      expect(find.text("Parents' evening"), findsOne);
      expect(find.text('Grade 7 Science'), findsOne);

      await tester.tap(find.text('Join'));
      await tester.pumpAndSettle();
      expect(launched, [meet]);
    });

    testWidgets('a cancelled meeting says so and cannot be joined', (
      tester,
    ) async {
      await tester.pumpWidget(
        section([meeting(state: 'cancelled', url: meet)], []),
      );
      await tester.pumpAndSettle();
      expect(find.text('Cancelled'), findsOne);
      expect(find.text('Join'), findsNothing);
    });

    testWidgets('a meeting that has ended cannot be joined', (tester) async {
      await tester.pumpWidget(
        section([
          meeting(url: meet, ends: now.subtract(const Duration(minutes: 5))),
        ], []),
      );
      await tester.pumpAndSettle();
      expect(find.text('Join'), findsNothing);
    });

    testWidgets('with no meetings the section is not shown', (tester) async {
      await tester.pumpWidget(section(const [], []));
      await tester.pumpAndSettle();
      expect(find.text('Upcoming meetings'), findsNothing);
    });
  });

  group("the teacher's meetings tab", () {
    Future<PreviewSchoolOperationsRepository> openTab(
      WidgetTester tester, {
      List<Uri>? launched,
    }) async {
      tester.view.physicalSize = const Size(1200, 2600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repository = PreviewSchoolOperationsRepository();
      await tester.pumpWidget(
        localizedApp(
          home: ClassroomManagementPage(
            repository: repository,
            classroom: const ManagedClassroom(id: 'c1', name: 'Grade 7'),
            classrooms: const [ManagedClassroom(id: 'c1', name: 'Grade 7')],
            openLink: (url) async {
              launched?.add(url);
              return true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Meetings'));
      await tester.pumpAndSettle();
      return repository;
    }

    Future<void> fillForm(WidgetTester tester, String link) async {
      await tester.tap(find.text('Schedule meeting'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Title'),
        "Parents' evening",
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Google Meet link'),
        link,
      );
      await tester.tap(find.text('Schedule'));
      await tester.pumpAndSettle();
    }

    testWidgets('a link that is not Google Meet is refused in the form', (
      tester,
    ) async {
      final repository = await openTab(tester);
      await fillForm(tester, 'https://example.com/call');

      expect(find.textContaining('https://meet.google.com/'), findsWidgets);
      // Still in the form; nothing was scheduled.
      expect(find.widgetWithText(TextField, 'Google Meet link'), findsOne);
      expect(await repository.listMeetings('c1'), isEmpty);
    });

    testWidgets('a meeting with a Meet link is scheduled and listed', (
      tester,
    ) async {
      final launched = <Uri>[];
      final repository = await openTab(tester, launched: launched);
      await fillForm(tester, meet.toString());

      final scheduled = await repository.listMeetings('c1');
      expect(scheduled.single.meetUrl, meet);
      expect(scheduled.single.state, 'scheduled');
      expect(find.text("Parents' evening"), findsOne);

      await tester.tap(find.text('Join'));
      await tester.pumpAndSettle();
      expect(launched, [meet]);
    });
  });
}

class _Meetings implements MeetingsRepository {
  const _Meetings(this.items);
  final List<UpcomingMeeting> items;

  @override
  Future<List<UpcomingMeeting>> upcoming() async => items;
}
