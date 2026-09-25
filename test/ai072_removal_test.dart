import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/core/runtime_environment.dart';
import 'package:studafy/core/studafy_localizations.dart';
import 'package:studafy/features/academic/data/preview_academic_repository.dart';
import 'package:studafy/student_features.dart';
import 'package:studafy/l10n/generated/app_l10n.dart';

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

  // SCOPE CHANGE, recorded rather than quietly made.
  //
  // This test used to ban the bare word "AI" anywhere in shipped source, as
  // the belt-and-braces half of ADR-0026's "leave nothing a reviewer could
  // find". A study assistant has since been added on the repository owner's
  // explicit instruction, so that blanket ban no longer holds and only it
  // has been lifted.
  //
  // Everything naming the REMOVED implementation stays forbidden, because
  // that implementation was the SEC-001 critical vulnerability: it signed
  // caller-selected storage paths with service-role credentials, and it
  // forwarded lesson-material bodies to an unpinned URL. The new assistant
  // shares none of it - it sends only the sentence a student typed, to one
  // pinned origin, behind a daily cap.
  //
  // ADR-0026's other precondition is still outstanding: no DPA and no DPIA
  // covering minors' data existed when this was written.
  test('no shipped source names the removed AI route, credential or control', () {
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

  testWidgets('the student shell has no Study Coach tab', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        supportedLocales: StudafyLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppL10n.delegate,
          StudafyLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: StudentShell(academic: PreviewAcademicRepository()),
      ),
    );
    await tester.pump();

    // Today, Notebook and Work. Grades merged into Work - one screen over the
    // same feeds - and Messages (DL-049) appears only when the app provides
    // messaging. The count is only a proxy; what this test actually guards is
    // that nothing has taken the Study Coach's place, which the two
    // assertions below check directly. Re-adding an AI tab needs a DPA, a
    // DPIA covering minors' data, and an ADR superseding ADR-0026 - not an
    // edit to this number.
    expect(find.byType(NavigationDestination), findsNWidgets(3));
    expect(find.text('Study Coach'), findsNothing);
    expect(find.byIcon(Icons.auto_awesome_outlined), findsNothing);
  });
}
