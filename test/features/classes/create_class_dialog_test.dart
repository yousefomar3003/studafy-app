import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/core/telemetry.dart';
import 'package:studafy/features/classes/application/class_list_interactor.dart';
import 'package:studafy/features/classes/domain/classroom.dart';
import 'package:studafy/features/classes/domain/classroom_repository.dart';
import 'package:studafy/features/classes/presentation/create_class_dialog.dart';

import '../../support/localized_app.dart';

/// Creating a class with more than one lesson a week. Choosing two lessons
/// used to copy the first onto the same day and time, which the server
/// refused with an error the teacher never understood.
class _Created implements ClassroomRepository {
  final drafts = <NewClassDraft>[];

  @override
  Future<void> createClass(NewClassDraft draft) async => drafts.add(draft);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not faked');
}

void main() {
  Future<void> open(WidgetTester tester, _Created repository) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      localizedApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showCreateClassDialog(
              context,
              ClassListInteractor(
                repository: repository,
                telemetry: const NoopTelemetry(),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Class name'),
      'Science 7B',
    );
  }

  Future<void> chooseLessons(WidgetTester tester, String count) async {
    await tester.tap(find.text('1 class'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(count).last);
    await tester.pumpAndSettle();
  }

  testWidgets('a second lesson starts on the next day', (tester) async {
    final repository = _Created();
    await open(tester, repository);
    await chooseLessons(tester, '2 classes');

    await tester.tap(find.text('Create classroom'));
    await tester.pumpAndSettle();

    final sessions = repository.drafts.single.sessions;
    expect([for (final s in sessions) s.weekday], [1, 2]);
  });

  testWidgets('the same day and time twice is pointed at, not sent', (
    tester,
  ) async {
    final repository = _Created();
    await open(tester, repository);
    await chooseLessons(tester, '2 classes');

    // Move the second lesson back onto the first one's day.
    await tester.tap(find.text('Tue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mon').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create classroom'));
    await tester.pumpAndSettle();

    expect(repository.drafts, isEmpty);
    expect(
      find.text(
        'Two lessons are on the same day and time. Change one of them.',
      ),
      findsOneWidget,
    );
  });
}
