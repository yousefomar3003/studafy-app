import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/core/studafy_domain.dart';
import 'package:studafy/core/telemetry.dart';
import 'package:studafy/features/messaging/application/messaging_interactor.dart';
import 'package:studafy/features/messaging/domain/messaging.dart';
import 'package:studafy/features/messaging/presentation/conversations_page.dart';
import 'package:studafy/features/messaging/presentation/messaging_scope.dart';

import 'support/localized_app.dart';

/// A guardian is linked to a child, never enrolled, so they hold no
/// membership and never will. Messaging used to read its school from the
/// membership alone, so every parent saw "Choose a school to see messages"
/// forever, over conversations the server was perfectly willing to serve:
/// `conversation.list` is self-scoped and spans every school.
void main() {
  final conversation = Conversation(
    id: 'conversation-1',
    schoolId: 'school-1',
    updatedAt: DateTime(2026, 9, 24, 10),
    participants: const [
      ConversationParticipant(
        userId: 'guardian-1',
        displayName: 'Nadia Hassan',
        role: MessagingRole.guardian,
      ),
      ConversationParticipant(
        userId: 'teacher-1',
        displayName: 'Rana Haddad',
        role: MessagingRole.staff,
      ),
    ],
  );

  void signInAsGuardian() {
    ActiveContextController.instance.hydrate(
      // No membership: this is the whole point.
      authenticatedProfile: const UserProfile(
        id: 'guardian-1',
        displayName: 'Nadia Hassan',
        email: 'nadia@studafy.test',
        memberships: [],
      ),
    );
  }

  tearDown(ActiveContextController.instance.signOut);

  Widget host(_Repository repository) => localizedApp(
    home: MessagingScope(
      interactor: MessagingInteractor(
        messaging: repository,
        safety: _UnusedSafety(),
        telemetry: const NoopTelemetry(),
      ),
      child: const ConversationsPage(),
    ),
  );

  testWidgets('a guardian with no school still sees their conversations', (
    tester,
  ) async {
    signInAsGuardian();
    final repository = _Repository(conversationList: [conversation]);

    await tester.pumpWidget(host(repository));
    await tester.pumpAndSettle();

    expect(find.text('Rana Haddad'), findsOneWidget);
    expect(find.text('Choose a school to see messages.'), findsNothing);
    // Asking whether a school has messaging switched on needs a school.
    expect(repository.enabledChecks, 0);
  });

  testWidgets('and is not offered a new message until a child is linked', (
    tester,
  ) async {
    signInAsGuardian();

    await tester.pumpWidget(host(_Repository(conversationList: const [])));
    await tester.pumpAndSettle();

    // Picking recipients is per school, because the contact policy is.
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(
      find.text(
        'Once a child is linked to you, you can message their teachers here.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('selecting a verified child gives them a school to write in', (
    tester,
  ) async {
    signInAsGuardian();
    ActiveContextController.instance.selectStudent(
      const StudentSummary(
        id: 'student-1',
        studafyId: 'SJ-1',
        displayName: 'Layla',
        verified: true,
        schoolId: 'school-1',
      ),
    );
    final repository = _Repository(conversationList: const []);

    await tester.pumpWidget(host(repository));
    await tester.pumpAndSettle();

    expect(find.text('New message'), findsOneWidget);
    expect(repository.enabledChecks, 1);
    expect(repository.lastEnabledSchool, 'school-1');
  });

  testWidgets('a school that has messaging off still blocks a new message', (
    tester,
  ) async {
    signInAsGuardian();
    ActiveContextController.instance.selectStudent(
      const StudentSummary(
        id: 'student-1',
        studafyId: 'SJ-1',
        displayName: 'Layla',
        verified: true,
        schoolId: 'school-1',
      ),
    );

    await tester.pumpWidget(
      host(_Repository(conversationList: const [], enabled: false)),
    );
    await tester.pumpAndSettle();

    expect(find.byType(FloatingActionButton), findsNothing);
    expect(
      find.text('Your school has not turned on messaging yet.'),
      findsOneWidget,
    );
  });
}

class _Repository implements MessagingRepository {
  _Repository({required this.conversationList, this.enabled = true});

  final List<Conversation> conversationList;
  final bool enabled;
  int enabledChecks = 0;
  String? lastEnabledSchool;

  @override
  Future<bool> messagingEnabled(String schoolId) async {
    enabledChecks++;
    lastEnabledSchool = schoolId;
    return enabled;
  }

  @override
  Future<List<Conversation>> conversations() async => conversationList;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _UnusedSafety implements SafetyRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
