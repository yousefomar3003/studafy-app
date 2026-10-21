import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/app/material_picker.dart';
import 'package:studafy/core/ids.dart';
import 'package:studafy/core/material_selection.dart';
import 'package:studafy/core/telemetry.dart';
import 'package:studafy/features/academic/domain/academic_repository.dart';
import 'package:studafy/features/classes/application/class_list_interactor.dart';
import 'package:studafy/features/classes/domain/classroom.dart';
import 'package:studafy/features/classes/domain/classroom_repository.dart';
import 'package:studafy/features/study/domain/study.dart';

import '../support/localized_app.dart';

/// The one material picker every AI feature uses (ADR-0039): what is
/// chosen is always visible, nothing is chosen for the student, and a
/// whole class only after asking.
void main() {
  void tall(WidgetTester tester) {
    tester.view.physicalSize = const Size(1000, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  late _Academic academic;
  setUp(() => academic = _Academic());

  Future<MaterialSelection?> open(
    WidgetTester tester,
    MaterialPickRequest request,
  ) async {
    MaterialSelection? picked;
    await tester.pumpWidget(
      localizedApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () async => picked = await pickMaterials(
                  context,
                  request,
                  classes: ClassListInteractor(
                    repository: _Classes(),
                    telemetry: const NoopTelemetry(),
                  ),
                  academic: academic,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return picked;
  }

  testWidgets('opened from a lesson, it starts with that lesson, shown whole', (
    tester,
  ) async {
    tall(tester);
    await open(
      tester,
      const MaterialPickRequest(
        action: MaterialAction.quiz,
        preselectLessonId: 'cells',
      ),
    );
    // The lesson is open to show what it includes; the file still being
    // read is shown, not chosen, and the one that cannot be read is out.
    expect(find.text('Leaf.pdf'), findsOne);
    expect(find.text('Board.png'), findsOne);
    expect(find.text('Still being read'), findsOne);
    expect(find.text('Biology · 8A · Lesson: Cells · 1 attachment'), findsOne);
    expect(find.text('Create quiz from selection'), findsOne);
    expect(find.text('Selected'), findsOne);
  });

  testWidgets('from a general screen nothing is chosen, and nothing can be '
      'made until something is', (tester) async {
    tall(tester);
    await open(
      tester,
      const MaterialPickRequest(action: MaterialAction.summary),
    );
    expect(find.text('Nothing chosen yet'), findsOne);
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Summarise selected materials'),
    );
    expect(button.onPressed, isNull);
    expect(find.text('Selected'), findsNothing);
  });

  testWidgets('leaving out a file changes exactly what is sent', (
    tester,
  ) async {
    tall(tester);
    MaterialSelection? picked;
    await tester.pumpWidget(
      localizedApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () async => picked = await pickMaterials(
                context,
                const MaterialPickRequest(
                  action: MaterialAction.flashcards,
                  preselectLessonId: 'cells',
                ),
                classes: ClassListInteractor(
                  repository: _Classes(),
                  telemetry: const NoopTelemetry(),
                ),
                academic: academic,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Leaf.pdf'));
    await tester.pumpAndSettle();
    expect(
      find.text('Biology · 8A · Lesson: Cells · lesson text only'),
      findsOne,
    );
    await tester.tap(find.text('Create flashcards from selection'));
    await tester.pumpAndSettle();
    expect(picked!.toJson(), [
      {'kind': 'text', 'id': 'cells'},
    ]);
  });

  testWidgets('a whole class is chosen only after asking, and can be '
      'reviewed and trimmed', (tester) async {
    tall(tester);
    await open(tester, const MaterialPickRequest(action: MaterialAction.quiz));
    await tester.tap(find.text('Select entire class').first);
    await tester.pumpAndSettle();
    expect(find.text('Select all of Biology · 8A?'), findsOne);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Nothing chosen yet'), findsOne);

    await tester.tap(find.text('Select entire class').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Select all'));
    await tester.pumpAndSettle();
    expect(find.text('Biology · 8A · 2 lessons · 1 attachment'), findsOne);

    await tester.tap(find.text('Review'));
    await tester.pumpAndSettle();
    expect(find.text('What will be used'), findsOne);
    await tester.tap(find.byTooltip('Remove').first);
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.textContaining('Lesson: Respiration'), findsOne);
  });

  testWidgets('search finds lessons by title and by their files', (
    tester,
  ) async {
    tall(tester);
    await open(tester, const MaterialPickRequest(action: MaterialAction.quiz));
    await tester.enterText(find.byType(TextField), 'resp');
    await tester.pumpAndSettle();
    expect(find.text('Respiration'), findsOne);
    expect(find.text('Cells'), findsNothing);
  });

  testWidgets('a notebook takes one lesson: choosing another replaces it', (
    tester,
  ) async {
    tall(tester);
    await open(
      tester,
      const MaterialPickRequest(
        action: MaterialAction.notebook,
        preselectLessonId: 'cells',
        singleLesson: true,
      ),
    );
    expect(find.text('Select entire class'), findsNothing);
    await tester.tap(
      find.byWidgetPredicate(
        (w) => w is Checkbox && w.semanticLabel == 'Respiration',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Lesson: Respiration'), findsOne);
    expect(find.textContaining('Lesson: Cells'), findsNothing);
  });

  testWidgets('a file that can never be read cannot be chosen', (tester) async {
    tall(tester);
    await open(
      tester,
      const MaterialPickRequest(
        action: MaterialAction.quiz,
        preselectLessonId: 'cells',
      ),
    );
    final tile = tester.widget<CheckboxListTile>(
      find.widgetWithText(CheckboxListTile, 'Video'),
    );
    expect(tile.onChanged, isNull);
    expect(tile.value, isFalse);
  });

  testWidgets('in no class, the personal notebook is offered, not an error', (
    tester,
  ) async {
    // ADR-0045: a student who skipped joining a class asks the AI Tutor to
    // answer from their own notes; the class list is refused for them.
    tall(tester);
    MaterialSelection? picked;
    await tester.pumpWidget(
      localizedApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () async => picked = await pickMaterials(
                  context,
                  const MaterialPickRequest(
                    action: MaterialAction.helper,
                    allowNotes: true,
                  ),
                  classes: ClassListInteractor(
                    repository: _NoClasses(),
                    telemetry: const NoopTelemetry(),
                  ),
                  academic: academic,
                  study: _PersonalNotes(),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Your lessons could not be loaded.'), findsNothing);
    expect(find.text('My notebook'), findsOne);
    await tester.tap(find.text('Photosynthesis'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use selection in the AI Tutor'));
    await tester.pumpAndSettle();
    expect(picked!.notes.single.id, 'n1');
  });

  testWidgets('reads right to left in Arabic', (tester) async {
    tall(tester);
    await tester.pumpWidget(
      localizedApp(
        locale: const Locale('ar'),
        home: MaterialPickerPage(
          request: const MaterialPickRequest(
            action: MaterialAction.quiz,
            preselectLessonId: 'cells',
          ),
          classes: ClassListInteractor(
            repository: _Classes(),
            telemetry: const NoopTelemetry(),
          ),
          academic: academic,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('أنشئ اختبارًا من المختار'), findsOne);
    expect(
      Directionality.of(tester.element(find.byType(ListView).first)),
      TextDirection.rtl,
    );
    expect(tester.takeException(), isNull);
  });
}

class _Classes implements ClassroomRepository {
  @override
  Future<List<ClassroomSummary>> listClasses() async => const [
    ClassroomSummary(
      id: ClassroomId('bio'),
      name: 'Biology',
      grade: '8',
      section: 'A',
      studentCount: 20,
    ),
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _Academic implements AcademicRepository {
  @override
  Future<List<AcademicRecord>> load(
    AcademicFeed feed, {
    String? classroomId,
    String? studentId,
  }) async => const [
    AcademicRecord(
      id: 'cells',
      title: 'Cells',
      detail: 'Cells are the unit of life.',
      state: 'published',
      version: 1,
    ),
    AcademicRecord(
      id: 'resp',
      title: 'Respiration',
      detail: 'Energy from glucose.',
      state: 'published',
      version: 1,
    ),
  ];

  @override
  Future<List<LessonReadingSource>> lessonReading(String resourceId) async =>
      resourceId == 'cells'
      ? const [
          LessonReadingSource(
            id: 'leaf',
            isLink: false,
            name: 'Leaf.pdf',
            state: ReadingState.ready,
          ),
          LessonReadingSource(
            id: 'board',
            isLink: false,
            name: 'Board.png',
            state: ReadingState.processing,
          ),
          LessonReadingSource(
            id: 'video',
            isLink: true,
            name: 'Video',
            state: ReadingState.unsupported,
            reason: 'link_video',
          ),
        ]
      : const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// The class list as a student in no class gets it: refused.
class _NoClasses implements ClassroomRepository {
  @override
  Future<List<ClassroomSummary>> listClasses() async =>
      throw StateError('no membership');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// One note in the personal notebook.
class _PersonalNotes implements StudyRepository {
  @override
  Future<List<NotebookEntry>> personalNotebook() async => [
    NotebookEntry(
      id: 'n1',
      classroomId: null,
      title: 'Photosynthesis',
      body: 'Light, water and carbon dioxide.',
      fromWhiteboard: false,
      createdAt: DateTime(2026, 10, 21),
    ),
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
