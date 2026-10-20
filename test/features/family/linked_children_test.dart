import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/core/studafy_domain.dart';
import 'package:studafy/core/telemetry.dart';
import 'package:studafy/features/family/application/family_interactor.dart';
import 'package:studafy/features/family/domain/family.dart';
import 'package:studafy/features/family/presentation/family_scope.dart';
import 'package:studafy/features/family/presentation/linked_child_switcher.dart';
import 'package:studafy/features/messaging/application/messaging_interactor.dart';
import 'package:studafy/features/messaging/domain/messaging.dart';
import 'package:studafy/features/messaging/presentation/conversations_page.dart';
import 'package:studafy/features/messaging/presentation/messaging_scope.dart';

import '../../support/localized_app.dart';

/// A parent with more than one child chooses which one the tabs show; one
/// account that is a teacher at one school and a parent at another sees each
/// role's conversations only in that role's interface.
void main() {
  tearDown(ActiveContextController.instance.signOut);

  GuardianChild child(String id, String name, String school) => GuardianChild(
    linkId: 'link-$id',
    studentId: id,
    studentName: name,
    schoolId: 'school-$school',
    schoolName: school,
    status: GuardianLinkStatus.verified,
  );

  Widget switcher(List<GuardianChild> children, List<GuardianChild> chosen) =>
      localizedApp(
        home: FamilyScope(
          interactor: FamilyInteractor(
            family: _Family(children),
            telemetry: const NoopTelemetry(),
          ),
          child: Scaffold(
            appBar: AppBar(
              actions: [
                LinkedChildSwitcher(
                  onSelect: (c) {
                    chosen.add(c);
                    ActiveContextController.instance.selectStudent(
                      StudentSummary(
                        id: c.studentId,
                        studafyId: '',
                        displayName: c.studentName,
                        verified: true,
                        schoolId: c.schoolId,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      );

  testWidgets('the first child is chosen when none is', (tester) async {
    final chosen = <GuardianChild>[];
    await tester.pumpWidget(
      switcher([
        child('a', 'Sara', 'North'),
        child('b', 'Omar', 'North'),
      ], chosen),
    );
    await tester.pumpAndSettle();
    expect(chosen.single.studentId, 'a');
    expect(find.text('Sara'), findsOne);
  });

  testWidgets('a parent switches to another child', (tester) async {
    final chosen = <GuardianChild>[];
    await tester.pumpWidget(
      switcher([
        child('a', 'Sara', 'North'),
        child('b', 'Omar', 'North'),
      ], chosen),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sara'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Omar').last);
    await tester.pumpAndSettle();

    expect(chosen.last.studentId, 'b');
    expect(ActiveContextController.instance.selectedStudent?.id, 'b');
  });

  testWidgets('one child at two schools is told apart by school', (
    tester,
  ) async {
    await tester.pumpWidget(
      switcher([child('a', 'Sara', 'North'), child('b', 'Sara', 'South')], []),
    );
    await tester.pumpAndSettle();
    expect(find.text('Sara · North'), findsOne);
  });

  testWidgets('no linked child shows nothing', (tester) async {
    await tester.pumpWidget(switcher(const [], []));
    await tester.pumpAndSettle();
    expect(find.byType(PopupMenuButton<GuardianChild>), findsNothing);
  });

  group('an inbox shows only its own role', () {
    Conversation convo(String id, MessagingRole myRole) => Conversation(
      id: id,
      schoolId: 'school-1',
      subject: 'Chat $id',
      updatedAt: DateTime(2026, 9, 27),
      participants: [
        ConversationParticipant(userId: 'me', displayName: 'Me', role: myRole),
        const ConversationParticipant(
          userId: 'other',
          displayName: 'Other',
          role: MessagingRole.staff,
        ),
      ],
    );

    Future<void> inbox(WidgetTester tester, MessagingRole role) async {
      ActiveContextController.instance.hydrate(
        authenticatedProfile: const UserProfile(
          id: 'me',
          displayName: 'Me',
          email: 'me@example.test',
          memberships: [],
        ),
      );
      final fake = _Inbox([
        convo('as-parent', MessagingRole.guardian),
        convo('as-teacher', MessagingRole.staff),
      ]);
      await tester.pumpWidget(
        localizedApp(
          home: MessagingScope(
            interactor: MessagingInteractor(
              messaging: fake,
              safety: fake,
              telemetry: const NoopTelemetry(),
            ),
            child: ConversationsPage(asRole: role),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('the parent interface', (tester) async {
      await inbox(tester, MessagingRole.guardian);
      expect(find.textContaining('Chat as-parent'), findsOne);
      expect(find.textContaining('Chat as-teacher'), findsNothing);
    });

    testWidgets('the teacher interface', (tester) async {
      await inbox(tester, MessagingRole.staff);
      expect(find.textContaining('Chat as-teacher'), findsOne);
      expect(find.textContaining('Chat as-parent'), findsNothing);
    });
  });
}

class _Family implements FamilyRepository {
  _Family(this.items);
  final List<GuardianChild> items;

  @override
  Future<List<GuardianChild>> children() async => items;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _Inbox implements MessagingRepository, SafetyRepository {
  _Inbox(this.items);
  final List<Conversation> items;

  @override
  Future<List<Conversation>> conversations() async => items;

  @override
  Future<bool> messagingEnabled(String schoolId) async => true;

  @override
  Future<void> acknowledgeDelivery() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
