import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/features/academic/domain/academic_repository.dart';
import 'package:studafy/features/academic/presentation/academic_overview_page.dart';

import 'support/localized_app.dart';

/// Narrowing a feed to one class is done by the server, so the only thing
/// that can go wrong on the client is failing to send the id. These tests
/// watch what actually reaches the repository.
void main() {
  const choices = [
    ClassChoice(id: 'class-1', name: 'Maths'),
    ClassChoice(id: 'class-2', name: 'Physics'),
  ];

  Widget page(
    _RecordingRepository repository, {
    String? fixedClassroomId,
    Future<List<ClassChoice>> Function()? load,
    List<AcademicFeed> feeds = const [
      AcademicFeed.assignments,
      AcademicFeed.grades,
    ],
  }) => localizedApp(
    home: AcademicOverviewPage(
      repository: repository,
      classroomId: fixedClassroomId,
      loadClassChoices: load ?? () async => choices,
      availableFeeds: feeds,
    ),
  );

  testWidgets('opens across every class, then narrows to the one tapped', (
    tester,
  ) async {
    final repository = _RecordingRepository();
    await tester.pumpWidget(page(repository));
    await tester.pumpAndSettle();

    expect(repository.classroomIds, [null]);

    await tester.tap(find.text('Physics'));
    await tester.pumpAndSettle();

    expect(repository.classroomIds.last, 'class-2');
  });

  testWidgets('the chosen class survives switching feed', (tester) async {
    final repository = _RecordingRepository();
    await tester.pumpWidget(page(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Maths'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Grades'));
    await tester.pumpAndSettle();

    // Changing what you are looking at must not silently widen the scope
    // back to every class - that would show another class's marks.
    expect(repository.feeds.last, AcademicFeed.grades);
    expect(repository.classroomIds.last, 'class-1');
  });

  testWidgets('All classes clears the filter again', (tester) async {
    final repository = _RecordingRepository();
    await tester.pumpWidget(page(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Maths'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('All classes'));
    await tester.pumpAndSettle();

    expect(repository.classroomIds.last, isNull);
  });

  testWidgets('a host that already fixed the class offers no chooser', (
    tester,
  ) async {
    final repository = _RecordingRepository();
    await tester.pumpWidget(page(repository, fixedClassroomId: 'class-9'));
    await tester.pumpAndSettle();

    expect(find.text('All classes'), findsNothing);
    expect(find.text('Maths'), findsNothing);
    expect(repository.classroomIds, ['class-9']);
  });

  testWidgets('a chooser that fails to load leaves the feeds working', (
    tester,
  ) async {
    final repository = _RecordingRepository();
    await tester.pumpWidget(
      page(repository, load: () async => throw StateError('offline')),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('All classes'), findsNothing);
    expect(repository.classroomIds, [null]);
  });

  testWidgets('across classes, every row says which class it came from', (
    tester,
  ) async {
    final repository = _RecordingRepository(
      records: const [
        AcademicRecord(
          id: 'r1',
          title: 'Trigonometry notes',
          detail: 'Sine rule',
          state: 'published',
          version: 1,
          classroomId: 'class-1',
        ),
        AcademicRecord(
          id: 'r2',
          title: 'Optics notes',
          detail: 'Refraction',
          state: 'published',
          version: 1,
          classroomId: 'class-2',
        ),
      ],
    );
    await tester.pumpWidget(
      page(repository, feeds: const [AcademicFeed.content]),
    );
    await tester.pumpAndSettle();

    // The chips above are one each; the labels on the rows are the second.
    expect(find.text('Maths'), findsNWidgets(2));
    expect(find.text('Physics'), findsNWidgets(2));
  });

  testWidgets('once narrowed, rows stop repeating the class name', (
    tester,
  ) async {
    final repository = _RecordingRepository(
      records: const [
        AcademicRecord(
          id: 'r1',
          title: 'Trigonometry notes',
          detail: 'Sine rule',
          state: 'published',
          version: 1,
          classroomId: 'class-1',
        ),
      ],
    );
    await tester.pumpWidget(
      page(repository, feeds: const [AcademicFeed.content]),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Maths').first);
    await tester.pumpAndSettle();

    // Only the chip is left.
    expect(find.text('Maths'), findsOneWidget);
  });
}

class _RecordingRepository implements AcademicRepository {
  _RecordingRepository({this.records = const []});

  final List<String?> classroomIds = [];
  final List<AcademicFeed> feeds = [];

  /// Returned whatever the filter is, so a test can watch how a row spanning
  /// several classes renders.
  final List<AcademicRecord> records;

  @override
  Future<List<AcademicRecord>> load(
    AcademicFeed feed, {
    String? classroomId,
    String? studentId,
  }) async {
    feeds.add(feed);
    classroomIds.add(classroomId);
    return records;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
