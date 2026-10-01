import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/app/profile_setup_gate.dart';
import 'package:studafy/core/studafy_domain.dart';
import 'package:studafy/features/account/domain/profile_setup.dart';

import '../support/localized_app.dart';

/// First sign-in: a person names themselves instead of being called by the
/// start of their email address, and answers gender - once.
void main() {
  final context = ActiveContextController.instance;
  tearDown(context.signOut);

  void signIn(String id) => context.hydrate(
    authenticatedProfile: UserProfile(
      id: id,
      displayName: 'yousef.omar002',
      email: 'yousef.omar002@example.test',
      memberships: const [],
    ),
    signedInAs: StudafyRole.student,
  );

  Future<void> pump(WidgetTester tester, _Setup setup) async {
    await tester.pumpWidget(
      localizedApp(
        home: ProfileSetupGate(repository: setup, child: const Text('home')),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a new account names itself and answers gender first', (
    tester,
  ) async {
    signIn('new-user-1');
    final setup = _Setup(complete: false);
    await pump(tester, setup);

    expect(find.text('home'), findsNothing);
    expect(find.text('Tell us about you'), findsOne);
    // The email-derived name is offered to be corrected.
    expect(find.text('yousef.omar002'), findsOne);

    await tester.enterText(find.byType(TextField), '  Yousef Omar ');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    // Gender is required, but "prefer not to say" is an answer.
    expect(setup.saved, isEmpty);
    expect(find.textContaining('Prefer not to answer'), findsWidgets);

    await tester.tap(find.text('Prefer not to answer'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(setup.saved.single, ('Yousef Omar', Gender.preferNotToSay));
    expect(find.text('home'), findsOne);
    expect(context.profile?.displayName, 'Yousef Omar');
    expect(context.signedInAs, StudafyRole.student);
  });

  testWidgets('an account already set up goes straight in', (tester) async {
    signIn('set-up-user');
    await pump(tester, _Setup(complete: true));
    expect(find.text('home'), findsOne);
  });

  testWidgets('a profile that cannot be read never locks anyone out', (
    tester,
  ) async {
    signIn('offline-user');
    await pump(tester, _Setup(complete: false, failRead: true));
    expect(find.text('home'), findsOne);
  });
}

class _Setup implements ProfileSetupRepository {
  _Setup({required this.complete, this.failRead = false});

  final bool complete;
  final bool failRead;
  final saved = <(String, Gender)>[];

  @override
  Future<ProfileSetup> readSetup() async {
    if (failRead) throw StateError('offline');
    return ProfileSetup(displayName: 'yousef.omar002', complete: complete);
  }

  @override
  Future<ProfileSetup> completeSetup({
    required String displayName,
    required Gender gender,
  }) async {
    saved.add((displayName.trim(), gender));
    return ProfileSetup(
      displayName: displayName.trim(),
      gender: gender,
      complete: true,
    );
  }
}
