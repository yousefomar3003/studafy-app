import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/core/studafy_domain.dart';
import 'package:studafy/core/telemetry.dart';
import 'package:studafy/features/messaging/application/messaging_interactor.dart';
import 'package:studafy/features/messaging/domain/messaging.dart';
import 'package:studafy/features/messaging/presentation/conversations_page.dart';
import 'package:studafy/features/messaging/presentation/messaging_scope.dart';

import '../../support/localized_app.dart';

/// Each teacher's workspace is a school of its own, so a student in two
/// teachers' classes is in two schools. Their announcements come from both,
/// and either teacher can be messaged - in that teacher's school.
void main() {
  const schoolA = 'school-a';
  const schoolB = 'school-b';

  setUp(() {
    const a = SchoolMembership(
      id: 'membership-a',
      schoolId: schoolA,
      schoolName: 'Ms Rana',
      role: StudafyRole.student,
      active: true,
    );
    const b = SchoolMembership(
      id: 'membership-b',
      schoolId: schoolB,
      schoolName: 'Mr Omar',
      role: StudafyRole.student,
      active: true,
    );
    ActiveContextController.instance.hydrate(
      authenticatedProfile: const UserProfile(
        id: 'student-1',
        displayName: 'Layla',
        email: 'layla@example.test',
        memberships: [a, b],
      ),
      activeMembership: a,
    );
  });

  tearDown(ActiveContextController.instance.signOut);

  Widget host(_Repository repository, Widget child) => localizedApp(
    home: MessagingScope(
      interactor: MessagingInteractor(
        messaging: repository,
        safety: _UnusedSafety(),
        telemetry: const NoopTelemetry(),
      ),
      child: child,
    ),
  );

  testWidgets('announcements come from every teacher\'s school', (
    tester,
  ) async {
    final repository = _Repository();
    await tester.pumpWidget(
      host(repository, const ConversationsPage(asRole: MessagingRole.student)),
    );
    await tester.pumpAndSettle();

    // Messaging is off in one school and on in the other: a new message
    // can still be started, to the school that allows it.
    expect(repository.enabledSchools, unorderedEquals([schoolA, schoolB]));
    expect(find.text('New message'), findsOneWidget);

    await tester.tap(find.text('Announcements'));
    await tester.pumpAndSettle();
    expect(repository.announcementSchools, [schoolA, schoolB]);
    expect(find.text('Field trip'), findsOneWidget);
    expect(find.text('Essay deadline'), findsOneWidget);
  });

  testWidgets('one school\'s announcements failing leaves the other\'s', (
    tester,
  ) async {
    final repository = _Repository()..failing.add(schoolB);
    await tester.pumpWidget(
      host(repository, const ConversationsPage(asRole: MessagingRole.student)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Announcements'));
    await tester.pumpAndSettle();

    expect(find.text('Field trip'), findsOneWidget);
    expect(find.text('Essay deadline'), findsNothing);
  });

  testWidgets('either teacher can be messaged, in their own school', (
    tester,
  ) async {
    final repository = _Repository();
    await tester.pumpWidget(
      host(
        repository,
        const NewConversationPage(
          schoolId: schoolA,
          schoolIds: [schoolA, schoolB],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Rana Haddad'), findsOneWidget);
    expect(find.text('Omar Saleh'), findsOneWidget);

    // A conversation is in one school: choosing someone from the other
    // starts the choice again there.
    await tester.tap(find.text('Rana Haddad'));
    await tester.tap(find.text('Omar Saleh'));
    await tester.pump();
    await tester.tap(find.text('Start conversation'));
    await tester.pumpAndSettle();

    expect(repository.started.single.school, schoolB);
    expect(repository.started.single.people, ['teacher-b']);
  });
}

class _Repository implements MessagingRepository {
  final enabledSchools = <String>[];
  final announcementSchools = <String?>[];
  final failing = <String>{};
  final started = <({String school, List<String> people})>[];

  @override
  Future<bool> messagingEnabled(String schoolId) async {
    enabledSchools.add(schoolId);
    return schoolId == 'school-b';
  }

  @override
  Future<List<Conversation>> conversations() async => const [];

  @override
  Future<void> acknowledgeDelivery() async {}

  @override
  Future<List<Announcement>> announcements({
    String? schoolId,
    String? classroomId,
  }) async {
    announcementSchools.add(schoolId);
    if (failing.contains(schoolId)) throw StateError('unreachable');
    return [
      Announcement(
        id: 'announcement-$schoolId',
        title: schoolId == 'school-a' ? 'Field trip' : 'Essay deadline',
        body: '',
        important: false,
        createdAt: DateTime(2026, 11, schoolId == 'school-a' ? 1 : 2),
      ),
    ];
  }

  @override
  Future<List<MessagingContact>> contacts(String schoolId) async => [
    MessagingContact(
      userId: schoolId == 'school-a' ? 'teacher-a' : 'teacher-b',
      displayName: schoolId == 'school-a' ? 'Rana Haddad' : 'Omar Saleh',
      role: MessagingRole.staff,
    ),
  ];

  @override
  Future<Conversation> startConversation({
    required String schoolId,
    required List<String> participantIds,
    String? subject,
  }) async {
    started.add((school: schoolId, people: participantIds));
    return Conversation(
      id: 'conversation-1',
      schoolId: schoolId,
      participants: const [],
      updatedAt: DateTime(2026, 11, 4),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _UnusedSafety implements SafetyRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
