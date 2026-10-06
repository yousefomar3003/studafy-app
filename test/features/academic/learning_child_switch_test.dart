import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/features/academic/domain/academic_repository.dart';
import 'package:studafy/features/academic/presentation/academic_overview_page.dart';

import '../../support/localized_app.dart';

/// A parent with two children picks one on the family home; the Learning
/// tab follows. It used to start over - back on Assignments, after loading
/// twice - and a parent reading Grades lost their place.
void main() {
  const students = [
    StudentChoice(id: 'layla', name: 'Layla', schoolName: 'Al-Noor'),
    StudentChoice(id: 'omar', name: 'Omar', schoolName: 'Riverside'),
  ];

  Widget page(_Recording repository, String? studentId) => localizedApp(
    home: AcademicOverviewPage(
      repository: repository,
      students: students,
      studentId: studentId,
      availableFeeds: const [AcademicFeed.assignments, AcademicFeed.grades],
    ),
  );

  testWidgets('a child chosen elsewhere keeps the feed that is open', (
    tester,
  ) async {
    final repository = _Recording();
    await tester.pumpWidget(page(repository, 'layla'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Grades'));
    await tester.pumpAndSettle();
    final before = repository.loads.length;

    await tester.pumpWidget(page(repository, 'omar'));
    await tester.pumpAndSettle();

    expect(repository.loads.length, before + 1, reason: 'loaded once');
    expect(repository.loads.last, (AcademicFeed.grades, 'omar'));
  });

  testWidgets('a child chosen here loads once, not again as it is echoed', (
    tester,
  ) async {
    final repository = _Recording();
    String? chosen = 'layla';
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) => localizedApp(
          home: AcademicOverviewPage(
            repository: repository,
            students: students,
            studentId: chosen,
            onStudentChanged: (id) => setState(() => chosen = id),
            availableFeeds: const [
              AcademicFeed.assignments,
              AcademicFeed.grades,
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final before = repository.loads.length;

    await tester.tap(find.text('Omar'));
    await tester.pumpAndSettle();

    expect(repository.loads.length, before + 1);
    expect(repository.loads.last, (AcademicFeed.assignments, 'omar'));
  });
}

class _Recording implements AcademicRepository {
  final loads = <(AcademicFeed, String?)>[];

  @override
  Future<List<AcademicRecord>> load(
    AcademicFeed feed, {
    String? classroomId,
    String? studentId,
  }) async {
    loads.add((feed, studentId));
    return const [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
