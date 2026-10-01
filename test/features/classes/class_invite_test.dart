import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/core/ids.dart';
import 'package:studafy/core/telemetry.dart';
import 'package:studafy/features/classes/application/class_list_interactor.dart';
import 'package:studafy/features/classes/domain/classroom.dart';
import 'package:studafy/features/classes/domain/classroom_repository.dart';
import 'package:studafy/features/classes/presentation/classes_page.dart';

import '../../support/localized_app.dart';

/// A class code is shared once. Opening the invite again shows the same
/// code; only the teacher asking for a new one replaces it. That the server
/// re-derives the same code is proven in apps/api/test/class-join.
void main() {
  Widget page(_Invites fake) => localizedApp(
    home: ClassesPage(
      classes: ClassListInteractor(
        repository: fake,
        telemetry: const NoopTelemetry(),
      ),
      onOpenClassroom: (_) async {},
    ),
  );

  Future<void> openInvite(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Invite students'));
    await tester.pumpAndSettle();
  }

  testWidgets('opening the invite shows the code already shared', (
    tester,
  ) async {
    final fake = _Invites(existing: 'K7QM-4XTR');
    await tester.pumpWidget(page(fake));
    await tester.pumpAndSettle();

    await openInvite(tester);
    expect(find.text('K7QM-4XTR'), findsOne);
    // The code is the invite: the long link is not shown to read out.
    expect(find.textContaining('://'), findsNothing);
    await tester.tap(find.text('Copy code'));
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.text('K7QM-4XTR'))).pop();
    await tester.pumpAndSettle();

    await openInvite(tester);
    expect(find.text('K7QM-4XTR'), findsOne);
    // Looked at twice, replaced never.
    expect(fake.minted, 0);
  });

  testWidgets('a class with no code yet gets one', (tester) async {
    final fake = _Invites(existing: null);
    await tester.pumpWidget(page(fake));
    await tester.pumpAndSettle();

    await openInvite(tester);
    expect(fake.minted, 1);
    expect(find.text('NEW1-CODE'), findsOne);
  });

  testWidgets('New code replaces it only after the teacher confirms', (
    tester,
  ) async {
    final fake = _Invites(existing: 'K7QM-4XTR');
    await tester.pumpWidget(page(fake));
    await tester.pumpAndSettle();
    await openInvite(tester);

    await tester.tap(find.text('New code'));
    await tester.pumpAndSettle();
    expect(find.textContaining('will stop working'), findsOne);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(fake.minted, 0);

    await tester.tap(find.text('New code'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Make new code'));
    await tester.pumpAndSettle();
    expect(fake.minted, 1);
    expect(find.text('NEW1-CODE'), findsOne);
  });
}

class _Invites implements ClassroomRepository {
  _Invites({required this.existing});

  final String? existing;
  int minted = 0;

  @override
  Future<List<ClassroomSummary>> listClasses() async => const [
    ClassroomSummary(
      id: ClassroomId('class-1'),
      name: 'Physics 11A',
      grade: '11',
      section: 'A',
      studentCount: 3,
    ),
  ];

  @override
  Future<ClassJoinLinkInfo?> activeJoinLink(String classroomId) async {
    final code = existing;
    if (code == null || minted > 0) return null;
    return ClassJoinLinkInfo(
      id: 'link-1',
      useCount: 2,
      expiresAt: DateTime(2027),
      invite: ClassInvite(
        link: 'io.studafy.app://join?t=${'a' * 43}',
        code: code,
      ),
    );
  }

  @override
  Future<ClassInvite> inviteLinkFor(ClassroomId id) async {
    minted++;
    return ClassInvite(
      link: 'io.studafy.app://join?t=${'b' * 43}',
      code: 'NEW$minted-CODE',
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
