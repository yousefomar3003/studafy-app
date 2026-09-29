import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/core/failures.dart';
import 'package:studafy/core/ids.dart';
import 'package:studafy/core/telemetry.dart';
import 'package:studafy/features/classes/application/class_list_interactor.dart';
import 'package:studafy/features/classes/domain/classroom.dart';
import 'package:studafy/features/classes/domain/classroom_repository.dart';
import 'package:studafy/features/classes/presentation/join_class_page.dart';

import '../../support/localized_app.dart';

/// The student's way into a class: a link pasted or tapped, or since JOIN-053
/// a short code typed off a board. Redeeming refuses with FORBIDDEN for
/// exactly one reason - the account already staffs that school - so that
/// message is pinned to its cause here too.
void main() {
  Widget page(ClassroomRepository repository) => localizedApp(
    home: JoinClassPage(
      classes: ClassListInteractor(
        repository: repository,
        telemetry: const NoopTelemetry(),
      ),
    ),
  );

  Future<void> submit(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.tap(find.text('Join class'));
    await tester.pumpAndSettle();
  }

  /// Stands in for the platform clipboard, which a widget test does not have.
  void clipboardHolds(WidgetTester tester, String? text) {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async => call.method == 'Clipboard.getData'
          ? (text == null ? null : <String, dynamic>{'text': text})
          : null,
    );
  }

  tearDown(() {
    TestWidgetsFlutterBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  testWidgets(
    'a teacher opening their own link is told why, not refused flatly',
    (tester) async {
      await tester.pumpWidget(page(_Recording(fail: Failure.forbidden)));
      await tester.pumpAndSettle();

      await submit(tester, 'io.studafy.app://join?t=${'a' * 43}');

      expect(find.textContaining('You already teach at this school'), findsOne);
      // The wording it replaces explained nothing about the cause.
      expect(find.textContaining('does not have access'), findsNothing);
    },
  );

  testWidgets('any other refusal still shows what the server said', (
    tester,
  ) async {
    await tester.pumpWidget(
      page(_Recording(fail: Failure.validation('That link has expired.'))),
    );
    await tester.pumpAndSettle();

    await submit(tester, 'io.studafy.app://join?t=${'a' * 43}');

    expect(find.text('That link has expired.'), findsOne);
    expect(find.textContaining('You already teach'), findsNothing);
  });

  testWidgets('text that is neither a code nor a link is refused unsent', (
    tester,
  ) async {
    final repository = _Recording();
    await tester.pumpWidget(page(repository));
    await tester.pumpAndSettle();

    await submit(tester, 'hello');

    expect(find.textContaining('not a class code or link'), findsOne);
    expect(repository.tokens, isEmpty);
    expect(repository.codes, isEmpty);
  });

  testWidgets('a pasted link redeems by token', (tester) async {
    final repository = _Recording();
    await tester.pumpWidget(page(repository));
    await tester.pumpAndSettle();

    await submit(tester, 'io.studafy.app://join?t=${'a' * 43}');

    expect(repository.tokens, ['a' * 43]);
    expect(repository.codes, isEmpty);
    expect(find.textContaining('Grade 7 Science'), findsOne);
  });

  testWidgets('a code typed loosely is sent canonical', (tester) async {
    final repository = _Recording();
    await tester.pumpWidget(page(repository));
    await tester.pumpAndSettle();

    // Lower case, spaces for the dash: how a child copies it off a board.
    await submit(tester, 'k7qm 4xtr');

    expect(repository.codes, ['K7QM4XTR']);
    expect(repository.tokens, isEmpty);
    expect(find.textContaining('Grade 7 Science'), findsOne);
  });

  testWidgets('a code with a misreadable character is refused unsent', (
    tester,
  ) async {
    final repository = _Recording();
    await tester.pumpWidget(page(repository));
    await tester.pumpAndSettle();

    // O and 0 are not in the alphabet; neither is sent to be refused.
    await submit(tester, 'K7QM-4XT0');

    expect(repository.codes, isEmpty);
    expect(find.textContaining('not a class code or link'), findsOne);
  });

  testWidgets('Paste with nothing copied says what to do instead', (
    tester,
  ) async {
    clipboardHolds(tester, null);
    await tester.pumpWidget(page(_Recording()));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Paste'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Nothing has been copied'), findsOne);
  });

  testWidgets('Paste fills the field from the clipboard', (tester) async {
    clipboardHolds(tester, '  K7QM-4XTR  ');
    final repository = _Recording();
    await tester.pumpWidget(page(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Paste'));
    await tester.pumpAndSettle();
    // Read from the field itself: the hint shows the same example code.
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, 'K7QM-4XTR');

    await tester.tap(find.text('Join class'));
    await tester.pumpAndSettle();
    expect(repository.codes, ['K7QM4XTR']);
  });
}

class _Recording implements ClassroomRepository {
  _Recording({this.fail});

  final Failure? fail;
  final List<String> tokens = [];
  final List<String> codes = [];

  static const _joined = JoinedClass(
    schoolId: 'school-1',
    classroomId: ClassroomId('class-1'),
    classroomName: 'Grade 7 Science',
  );

  @override
  Future<JoinedClass> joinWithLink(String token) async {
    tokens.add(token);
    if (fail case final failure?) throw failure;
    return _joined;
  }

  @override
  Future<JoinedClass> joinWithCode(String code) async {
    codes.add(code);
    if (fail case final failure?) throw failure;
    return _joined;
  }

  @override
  Future<void> createClass(NewClassDraft draft) async =>
      throw UnimplementedError();

  @override
  Future<List<ClassroomSummary>> listClasses() async =>
      throw UnimplementedError();

  @override
  Future<ClassInvite> inviteLinkFor(ClassroomId id) async =>
      throw UnimplementedError();

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
