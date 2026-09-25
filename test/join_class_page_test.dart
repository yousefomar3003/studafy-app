import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/core/failures.dart';
import 'package:studafy/core/ids.dart';
import 'package:studafy/core/telemetry.dart';
import 'package:studafy/features/classes/application/class_list_interactor.dart';
import 'package:studafy/features/classes/domain/classroom.dart';
import 'package:studafy/features/classes/domain/classroom_repository.dart';
import 'package:studafy/features/classes/presentation/join_class_page.dart';

import 'support/localized_app.dart';

/// Redeeming a class link refuses with FORBIDDEN for exactly one reason:
/// the account already staffs that school. The generic wording sent a teacher
/// checking their own link hunting for a permissions fault, so the message is
/// pinned to the cause here.
void main() {
  Widget page(ClassroomRepository repository) => localizedApp(
    home: JoinClassPage(
      classes: ClassListInteractor(
        repository: repository,
        telemetry: const NoopTelemetry(),
      ),
    ),
  );

  Future<void> paste(WidgetTester tester) async {
    await tester.enterText(
      find.byType(TextField),
      'io.studafy.app://join?t=${'a' * 43}',
    );
    await tester.tap(find.text('Join class'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'a teacher opening their own link is told why, not refused flatly',
    (tester) async {
      await tester.pumpWidget(page(_Refusing(Failure.forbidden)));
      await tester.pumpAndSettle();

      await paste(tester);

      expect(find.textContaining('You already teach at this school'), findsOne);
      // The wording it replaces explained nothing about the cause.
      expect(find.textContaining('does not have access'), findsNothing);
    },
  );

  testWidgets('any other refusal still shows what the server said', (
    tester,
  ) async {
    await tester.pumpWidget(
      page(_Refusing(Failure.validation('That link has expired.'))),
    );
    await tester.pumpAndSettle();

    await paste(tester);

    expect(find.text('That link has expired.'), findsOne);
    expect(find.textContaining('You already teach'), findsNothing);
  });

  testWidgets('text that is not a link is rejected before any request', (
    tester,
  ) async {
    final repository = _Refusing(Failure.forbidden);
    await tester.pumpWidget(page(repository));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'hello');
    await tester.tap(find.text('Join class'));
    await tester.pumpAndSettle();

    expect(find.textContaining('does not look like a class link'), findsOne);
    expect(repository.attempts, 0);
  });
}

class _Refusing implements ClassroomRepository {
  _Refusing(this.failure);

  final Failure failure;
  int attempts = 0;

  @override
  Future<JoinedClass> joinWithLink(String token) async {
    attempts++;
    throw failure;
  }

  @override
  Future<void> createClass(NewClassDraft draft) async =>
      throw UnimplementedError();

  @override
  Future<List<ClassroomSummary>> listClasses() async =>
      throw UnimplementedError();

  @override
  Future<String> inviteLinkFor(ClassroomId id) async =>
      throw UnimplementedError();

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
