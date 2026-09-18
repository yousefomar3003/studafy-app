import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/core/runtime_environment.dart';
import 'package:studafy/core/studafy_localizations.dart';
import 'package:studafy/features/academic/data/preview_academic_repository.dart';
import 'package:studafy/student_features.dart';

/// AI-072 (ADR-0026): the AI capability was removed because no signed DPA
/// and no extended DPIA exist. A reviewer must find no AI route, screen,
/// credential, or dead AI control anywhere in the shipped app.
void main() {
  Iterable<File> dartAndTs(String root) => Directory(root)
      .listSync(recursive: true)
      .whereType<File>()
      .where(
        (file) => file.path.endsWith('.dart') || file.path.endsWith('.ts'),
      );

  test('both AI Edge Functions, the AI screens and the slice are gone', () {
    for (final path in [
      'supabase/functions/study-coach',
      'supabase/functions/propose-paper-grade',
      'lib/features/study_coach',
    ]) {
      expect(Directory(path).existsSync(), isFalse, reason: path);
    }
    for (final page in [
      'student_ai_page',
      'student_ai_ask_page',
      'student_ai_practice',
      'student_ai_insights',
    ]) {
      final path = 'lib/legacy/student/presentation/$page.dart';
      expect(File(path).existsSync(), isFalse, reason: path);
    }
    expect(
      File('lib/features/academic/data/api_paper_grading_repository.dart')
          .existsSync(),
      isFalse,
    );
  });

  test('no shipped source names an AI route, credential or AI control', () {
    final forbidden = <Pattern>[
      'STUDY_COACH',
      'AI_GRADING',
      'AI_PROVIDER',
      'study-coach',
      'propose-paper-grade',
      'StudyCoach',
      'StudentAi',
      // `allowsAiGrading` is the retained guard; only the removed types match.
      'AiGradingDraft',
      'AiGradingContainment',
      'ai-grading-',
      'Study Coach',
      'coachAttachment',
      RegExp(r'\bAI\b'),
    ];
    final files = [
      ...dartAndTs('lib'),
      ...dartAndTs('supabase/functions'),
    ].where((file) => !file.path.endsWith('.generated.dart'));
    expect(files, isNotEmpty);
    final offenders = <String>[];
    for (final file in files) {
      final source = file.readAsStringSync();
      for (final pattern in forbidden) {
        if (pattern.allMatches(source).isNotEmpty) {
          offenders.add('${file.path}: $pattern');
        }
      }
    }
    expect(offenders, isEmpty);
  });

  test('no env example declares an AI or Study Coach credential', () {
    for (final path in ['.env.example', 'supabase/functions/.env.example']) {
      final declared = File(path)
          .readAsLinesSync()
          .where(
            (line) =>
                RegExp(r'^\s*#?\s*(STUDY_COACH|AI_GRADING|AI_PROVIDER)[A-Z_]*=')
                    .hasMatch(line),
          )
          .toList();
      expect(declared, isEmpty, reason: path);
    }
  });

  test('the SEC-001 AI guard is deliberately retained and fails closed', () {
    // ADR-0026 keeps allowsAiGrading as a hard-false tripwire. Removing it is
    // a separate reviewed change with its own ADR and decision-log entry.
    for (final environment in StudafyEnvironment.values) {
      expect(RuntimePolicy(environment).allowsAiGrading, isFalse);
    }
  });

  testWidgets('the student shell has four tabs and no Study Coach', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        supportedLocales: StudafyLocalizations.supportedLocales,
        localizationsDelegates: const [
          StudafyLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: StudentShell(academic: PreviewAcademicRepository()),
      ),
    );
    await tester.pump();

    expect(find.byType(NavigationDestination), findsNWidgets(4));
    expect(find.text('Study Coach'), findsNothing);
    expect(find.byIcon(Icons.auto_awesome_outlined), findsNothing);
  });
}
