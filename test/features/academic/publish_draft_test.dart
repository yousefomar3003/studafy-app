import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/features/academic/domain/academic_repository.dart';
import 'package:studafy/features/academic/presentation/academic_overview_page.dart';

import '../../support/localized_app.dart';

/// A draft is invisible to the class. A teacher looking at their list needs
/// to see which work has not gone out, and be able to send it.
void main() {
  const draft = AcademicRecord(
    id: 'a1',
    title: 'Worksheet',
    detail: '',
    state: 'draft',
    version: 1,
  );
  const live = AcademicRecord(
    id: 'a2',
    title: 'Reading',
    detail: '',
    state: 'published',
    version: 2,
  );

  Widget page(_Publishing fake, {required bool teacherTools}) => localizedApp(
    home: AcademicOverviewPage(
      repository: fake,
      teacherTools: teacherTools,
      initialFeed: AcademicFeed.assignments,
    ),
  );

  testWidgets('a teacher publishes a draft from the list', (tester) async {
    final fake = _Publishing([draft, live]);
    await tester.pumpWidget(page(fake, teacherTools: true));
    await tester.pumpAndSettle();

    // Only the draft offers it.
    expect(find.text('Publish'), findsOne);
    await tester.tap(find.text('Publish'));
    await tester.pumpAndSettle();

    expect(fake.published, [('a1', 1)]);
    expect(find.textContaining('The class can see it now'), findsOne);
  });

  testWidgets('nobody else is offered it', (tester) async {
    await tester.pumpWidget(page(_Publishing([draft]), teacherTools: false));
    await tester.pumpAndSettle();
    expect(find.text('Publish'), findsNothing);
  });
}

class _Publishing implements AcademicRepository {
  _Publishing(this.records);

  final List<AcademicRecord> records;
  final published = <(String, int)>[];

  @override
  Future<List<AcademicRecord>> load(
    AcademicFeed feed, {
    String? classroomId,
    String? studentId,
  }) async => records;

  @override
  Future<void> publishAssignment(String assignmentId, int version) async =>
      published.add((assignmentId, version));

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
