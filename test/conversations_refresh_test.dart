import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/core/studafy_domain.dart';
import 'package:studafy/core/telemetry.dart';
import 'package:studafy/features/messaging/application/messaging_interactor.dart';
import 'package:studafy/features/messaging/domain/messaging.dart';
import 'package:studafy/features/messaging/presentation/conversations_page.dart';
import 'package:studafy/features/messaging/presentation/messaging_scope.dart';

import 'support/localized_app.dart';

/// The shells keep every tab alive in an IndexedStack, so a page that only
/// loads in initState shows whatever was true when the app started. For
/// messaging that meant a school switching the feature on stayed invisible
/// until the app was killed - which is exactly how it was found.
void main() {
  setUp(() {
    ActiveContextController.instance.hydrate(
      authenticatedProfile: const UserProfile(
        id: 'user-1',
        displayName: 'Student',
        email: 'student@studafy.test',
        memberships: [],
      ),
      activeMembership: const SchoolMembership(
        id: 'membership-1',
        schoolId: 'school-1',
        schoolName: 'School',
        role: StudafyRole.student,
        active: true,
      ),
    );
  });
  tearDown(() => ActiveContextController.instance.signOut());

  Widget host(_CountingRepository repository, {required bool visible}) =>
      localizedApp(
        home: MessagingScope(
          interactor: MessagingInteractor(
            messaging: repository,
            safety: _UnusedSafety(),
            telemetry: const NoopTelemetry(),
          ),
          child: ConversationsPage(visible: visible),
        ),
      );

  testWidgets('a hidden tab does not load, and loads when it is shown', (
    tester,
  ) async {
    final repository = _CountingRepository(enabled: false);

    await tester.pumpWidget(host(repository, visible: false));
    await tester.pumpAndSettle();
    expect(repository.enabledChecks, 0);

    // The school turns messaging on while the tab is off screen.
    repository.enabled = true;
    await tester.pumpWidget(host(repository, visible: true));
    await tester.pumpAndSettle();

    expect(repository.enabledChecks, 1);
    expect(
      find.text('Your school has not turned on messaging yet.'),
      findsNothing,
    );
  });

  testWidgets('staying visible does not reload on every rebuild', (
    tester,
  ) async {
    final repository = _CountingRepository(enabled: true);

    await tester.pumpWidget(host(repository, visible: true));
    await tester.pumpAndSettle();
    await tester.pumpWidget(host(repository, visible: true));
    await tester.pumpAndSettle();

    // Reloading on each rebuild would re-request while someone is typing
    // elsewhere in the shell.
    expect(repository.enabledChecks, 1);
  });
}

class _CountingRepository implements MessagingRepository {
  _CountingRepository({required this.enabled});

  bool enabled;
  int enabledChecks = 0;

  @override
  Future<bool> messagingEnabled(String schoolId) async {
    enabledChecks++;
    return enabled;
  }

  @override
  Future<List<Conversation>> conversations() async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _UnusedSafety implements SafetyRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
