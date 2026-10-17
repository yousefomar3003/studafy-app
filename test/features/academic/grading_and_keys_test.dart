import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/data/contracts/v1_http_transport.dart';
import 'package:studafy/features/academic/domain/academic_repository.dart';
import 'package:studafy/features/academic/presentation/academic_overview_page.dart';
import 'package:studafy/features/academic/presentation/submissions_page.dart';

import '../../support/localized_app.dart';

/// Faults found by using the app end to end: graded work that could not be
/// marked, screens that would not open, and a request key the server refused
/// one time in 32.
void main() {
  test('every generated request key is one the server accepts', () {
    // The server's own pattern (apps/api/src/platform/idempotency.ts).
    final accepted = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._:-]{15,127}$');
    for (var i = 0; i < 5000; i++) {
      final key = V1HttpTransport.newIdempotencyKey();
      expect(accepted.hasMatch(key), isTrue, reason: key);
    }
  });

  test('no floating button keeps the default hero tag', () {
    // Every tab stays alive in its shell's IndexedStack. Two buttons with the
    // default tag broke the transition of every screen pushed from any tab,
    // so a tapped assignment - for student and teacher - never opened.
    final offences = <String>[];
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      if (file.path.contains('/legacy/teacher/')) continue;
      final source = file.readAsStringSync();
      final starts = RegExp(
        r'FloatingActionButton(\.extended|\.small|\.large)?\(',
      ).allMatches(source);
      for (final match in starts) {
        final window = source.substring(
          match.end,
          (match.end + 400).clamp(0, source.length),
        );
        if (!window.contains('heroTag')) {
          offences.add('${file.path}:${match.start}');
        }
      }
    }
    expect(offences, isEmpty);
  });

  testWidgets('graded work opens the gradebook on its own mark', (
    tester,
  ) async {
    final fake = _Grades();
    await tester.pumpWidget(
      localizedApp(
        home: SubmissionsPage(
          repository: fake,
          assignmentId: 'asg-1',
          assignmentTitle: 'Lab report',
          classroomId: 'c1',
          graded: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Grade'));
    await tester.pumpAndSettle();
    // The mark for this assignment is chosen, not the first test listed.
    expect(find.text('Lab report (mark)'), findsWidgets);
  });

  testWidgets('ungraded work offers no Grade button', (tester) async {
    await tester.pumpWidget(
      localizedApp(
        home: SubmissionsPage(
          repository: _Grades(),
          assignmentId: 'asg-1',
          assignmentTitle: 'Reading',
          classroomId: 'c1',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Grade'), findsNothing);
  });

  testWidgets('a mark for an assignment is not listed among the tests', (
    tester,
  ) async {
    await tester.pumpWidget(
      localizedApp(
        home: AcademicOverviewPage(
          repository: _Grades(),
          initialFeed: AcademicFeed.assessments,
          availableFeeds: const [AcademicFeed.assessments],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Unit test'), findsOne);
    expect(find.text('Lab report (mark)'), findsNothing);
  });
}

class _Grades implements AcademicRepository {
  @override
  Future<List<AcademicRecord>> load(
    AcademicFeed feed, {
    String? classroomId,
    String? studentId,
  }) async => feed == AcademicFeed.assessments
      ? const [
          AcademicRecord(
            id: 'test-1',
            title: 'Unit test',
            detail: '',
            outOf: 20,
            state: 'published',
            version: 1,
            classroomId: 'c1',
          ),
          AcademicRecord(
            id: 'mark-1',
            title: 'Lab report (mark)',
            detail: '',
            outOf: 25,
            state: 'published',
            version: 2,
            classroomId: 'c1',
            markedAssignmentId: 'asg-1',
          ),
        ]
      : const [];

  @override
  Future<List<ClassStudent>> classStudents(String classroomId) async => const [
    ClassStudent(id: 's1', displayName: 'Amal', studafyId: 'SJ-1'),
  ];

  @override
  Future<List<SubmittedWork>> submissionsFor(String assignmentId) async =>
      const [];

  @override
  Future<List<GradeEntry>> gradeEntries(String classroomId) async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
