import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/core/runtime_environment.dart';
import 'package:studafy/data/studafy_repository.dart';
import 'package:studafy/data/study_coach_repository.dart';
import 'package:studafy/data/supabase_repository.dart';
import 'package:studafy/main.dart';
import 'package:studafy/student_features.dart';
import 'package:studafy/teacher_features.dart';

void main() {
  group('SEC-001 runtime policy', () {
    test('accepts every named environment', () {
      expect(
        RuntimePolicy.parse('synthetic').environment,
        StudafyEnvironment.synthetic,
      );
      expect(
        RuntimePolicy.parse('development').environment,
        StudafyEnvironment.development,
      );
      expect(
        RuntimePolicy.parse('staging').environment,
        StudafyEnvironment.staging,
      );
      expect(
        RuntimePolicy.parse('production').environment,
        StudafyEnvironment.production,
      );
    });

    test('rejects unknown environments', () {
      expect(() => RuntimePolicy.parse('prod'), throwsFormatException);
      expect(() => RuntimePolicy.parse(''), throwsFormatException);
    });

    test('capabilities fail closed in every environment', () {
      for (final environment in StudafyEnvironment.values) {
        final policy = RuntimePolicy(environment);
        expect(policy.allowsAiGrading, isFalse);
        expect(policy.allowsRemoteFileUploads, isFalse);
      }
    });

    test('only production blocks application startup', () {
      for (final environment in StudafyEnvironment.values) {
        expect(
          RuntimePolicy(environment).blocksApplicationStartup,
          environment == StudafyEnvironment.production,
        );
      }
    });

    test('synthetic mode cannot initialize a remote backend', () {
      expect(
        const RuntimePolicy(StudafyEnvironment.synthetic).requiresRemoteBackend,
        isFalse,
      );
      expect(
        const RuntimePolicy(StudafyEnvironment.development)
            .requiresRemoteBackend,
        isTrue,
      );
      expect(
        const RuntimePolicy(StudafyEnvironment.staging).requiresRemoteBackend,
        isTrue,
      );
      expect(
        const RuntimePolicy(StudafyEnvironment.production)
            .requiresRemoteBackend,
        isFalse,
      );
    });
  });

  testWidgets('production renders only the readiness block', (tester) async {
    await tester.pumpWidget(
      const StudafyApp(
        runtimePolicy: RuntimePolicy(StudafyEnvironment.production),
      ),
    );
    await tester.pump();

    expect(find.text('Studafy is not production-ready'), findsOneWidget);
    expect(find.text('Reference: SEC-001'), findsOneWidget);
    expect(find.byType(SplashPage), findsNothing);
    expect(find.byType(RolePage), findsNothing);
  });

  testWidgets('synthetic mode displays the real-data warning', (tester) async {
    await tester.pumpWidget(const StudafyApp());
    await tester.pump();
    expect(
      find.text('SYNTHETIC DATA — NOT FOR REAL SCHOOL USE'),
      findsOneWidget,
    );
  });

  testWidgets('AI grading upload and generation controls are disabled', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: AiGradingContainmentControls())),
    );

    final upload = tester.widget<OutlinedButton>(
      find.byKey(const Key('ai-grading-upload-control')),
    );
    final generate = tester.widget<FilledButton>(
      find.byKey(const Key('ai-grading-generate-control')),
    );
    expect(upload.onPressed, isNull);
    expect(generate.onPressed, isNull);
    expect(find.textContaining('secure file ownership'), findsOneWidget);
  });

  testWidgets('Study Coach attachment control is disabled', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AskAiPage()));
    final attach = tester.widget<IconButton>(
      find.byKey(const Key('study-coach-attachment-control')),
    );
    expect(attach.onPressed, isNull);
    expect(
      find.textContaining('New file attachments are temporarily unavailable'),
      findsOneWidget,
    );
  });

  test(
    'repositories reject grading and attachments before network use',
    () async {
      await expectLater(
        SupabaseStudafyRepository().proposeGrade(
          submissionId: 'submission',
          privateScan: Uri.parse('papers/another-user/private.pdf'),
          strictness: GradingStrictness.balanced,
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'AI grading is temporarily unavailable.',
          ),
        ),
      );
      await expectLater(
        StudyCoachRepository().ask(
          question: 'Read this',
          attachmentPath: 'coach/another-user/private.pdf',
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'File attachments are temporarily unavailable.',
          ),
        ),
      );
    },
  );
}
