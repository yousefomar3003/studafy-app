import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/core/failures.dart';
import 'package:studafy/core/telemetry.dart';
import 'package:studafy/features/study_assistant/application/study_assistant_interactor.dart';
import 'package:studafy/features/study_assistant/domain/study_assistant_repository.dart';
import 'package:studafy/features/study_assistant/presentation/study_assistant_page.dart';

import 'support/localized_app.dart';

/// The study helper sends a child's words to a third party, so what this
/// screen does and does not do matters more than how it looks.
void main() {
  Widget page(StudyAssistantRepository repository, {Locale? locale}) =>
      localizedApp(
        locale: locale,
        home: StudyAssistantPage(
          assistant: StudyAssistantInteractor(
            repository: repository,
            telemetry: const NoopTelemetry(),
          ),
        ),
      );

  testWidgets('says questions leave the app before any are typed', (
    tester,
  ) async {
    await tester.pumpWidget(page(_Recording()));
    await tester.pumpAndSettle();

    // A student should know their question is sent somewhere before they
    // send it, not afterwards in a policy document.
    expect(find.textContaining('sent to an AI service'), findsOneWidget);
  });

  testWidgets('will not ask twice while an answer is still coming', (
    tester,
  ) async {
    // The first call is held open, which is the real situation: the provider
    // takes seconds, the student taps again, and without the guard both taps
    // spend one of the day's questions and the provider bills for both.
    final repository = _Held();
    await tester.pumpWidget(page(repository));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Explain photosynthesis');
    await tester.pump();
    await tester.tap(find.text('Ask'));
    await tester.pump();

    expect(repository.questions, hasLength(1));
    await tester.tap(find.text('Thinking…'), warnIfMissed: false);
    await tester.pump();
    expect(repository.questions, hasLength(1));

    repository.release();
    await tester.pumpAndSettle();
    expect(repository.questions, ['Explain photosynthesis']);
  });

  testWidgets('shows the answer with a warning that it can be wrong', (
    tester,
  ) async {
    await tester.pumpWidget(page(_Recording(answer: 'Plants use sunlight.')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'What is photosynthesis?');
    await tester.tap(find.text('Ask'));
    await tester.pumpAndSettle();

    expect(find.text('Plants use sunlight.'), findsOneWidget);
    expect(find.textContaining('can be wrong'), findsOneWidget);
    expect(find.textContaining('questions left today'), findsOneWidget);
  });

  testWidgets('a refusal is shown rather than a spinner that never ends', (
    tester,
  ) async {
    await tester.pumpWidget(page(_Failing()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Anything at all');
    await tester.tap(find.text('Ask'));
    await tester.pumpAndSettle();

    expect(find.text('the helper is unavailable'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('reads in Arabic', (tester) async {
    await tester.pumpWidget(page(_Recording(), locale: const Locale('ar')));
    await tester.pumpAndSettle();

    expect(
      directionOf(tester, find.byType(StudyAssistantPage)),
      TextDirection.rtl,
    );
    expect(find.text('مساعد الدراسة'), findsOneWidget);
  });
}

class _Recording implements StudyAssistantRepository {
  _Recording({this.answer = 'An answer.'});

  final String answer;
  final List<String> questions = [];

  @override
  Future<StudyAnswer> ask(String question) async {
    questions.add(question);
    return StudyAnswer(answer: answer, remainingToday: 29);
  }
}

class _Failing implements StudyAssistantRepository {
  @override
  Future<StudyAnswer> ask(String question) async =>
      throw Failure.validation('the helper is unavailable');
}

/// Holds the first call open so the in-flight guard can be observed.
class _Held implements StudyAssistantRepository {
  final List<String> questions = [];
  final Completer<void> _gate = Completer<void>();

  void release() => _gate.complete();

  @override
  Future<StudyAnswer> ask(String question) async {
    questions.add(question);
    await _gate.future;
    return const StudyAnswer(answer: 'An answer.', remainingToday: 29);
  }
}
