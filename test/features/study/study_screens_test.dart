import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/core/attachment_field.dart';
import 'package:studafy/core/file_upload_repository.dart';
import 'package:studafy/features/academic/domain/academic_repository.dart';
import 'package:studafy/features/academic/presentation/lessons_by_date_view.dart';
import 'package:studafy/features/study/domain/study.dart';
import 'package:studafy/features/study/presentation/notebook_view.dart';
import 'package:studafy/features/study/presentation/study_plans_page.dart';
import 'package:studafy/features/study/presentation/study_set_pages.dart';

import '../../support/localized_app.dart';

/// Lessons, the Notebook, Studafy Plus / Max and the Plans screen. The plan
/// rules, caps and costs are enforced by the server and proven in
/// apps/api/test/study; this is what the screens do.
void main() {
  StudyPlan planOf(StudyPlanTier tier) => StudyPlan(
    tier: tier,
    allowanceUsed: 0.25,
    resetsAt: DateTime(2026, 10, 1),
    askToday: 2,
    askPerDay: 10,
  );

  void tall(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  group('the notebook', () {
    Widget notebook(_Study study, {List<String>? plansOpened}) => localizedApp(
      home: Scaffold(
        body: NotebookView(
          study: study,
          classroomId: 'c1',
          schoolId: 'school-1',
          uploads: study.uploads,
          source: (_, _) async => PickedAttachment(
            displayName: 'board.jpg',
            mediaType: 'image/jpeg',
            bytes: Uint8List(1024),
          ),
          onOpenPlans: () => plansOpened?.add('plans'),
          readyPoll: const Duration(milliseconds: 10),
        ),
      ),
    );

    testWidgets('notes are grouped under their day, newest first', (
      tester,
    ) async {
      tall(tester);
      final today = DateTime.now();
      final study = _Study(
        entries: [
          NotebookEntry(
            id: 'n2',
            classroomId: 'c1',
            title: 'Today note',
            body: 'Body',
            fromWhiteboard: true,
            createdAt: today,
          ),
          NotebookEntry(
            id: 'n1',
            classroomId: 'c1',
            title: 'Older note',
            body: 'Body',
            fromWhiteboard: false,
            createdAt: today.subtract(const Duration(days: 3)),
          ),
        ],
      );
      await tester.pumpWidget(notebook(study));
      await tester.pumpAndSettle();
      expect(find.text('Today'), findsOne);
      expect(
        tester.getTopLeft(find.text('Today note')).dy,
        lessThan(tester.getTopLeft(find.text('Older note')).dy),
      );
      // A whiteboard note is marked as one.
      expect(find.byTooltip('From the whiteboard'), findsOne);
    });

    testWidgets('a typed note is saved to this class', (tester) async {
      tall(tester);
      final study = _Study();
      await tester.pumpWidget(notebook(study));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add note'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Title'), 'Cells');
      await tester.enterText(
        find.widgetWithText(TextField, 'Note'),
        'Cells are the unit of life.',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(study.added, [('c1', 'Cells', 'Cells are the unit of life.')]);
      expect(find.text('Cells'), findsOne);
    });

    testWidgets('on the free plan, the whiteboard button opens the plans', (
      tester,
    ) async {
      tall(tester);
      final opened = <String>[];
      final study = _Study();
      await tester.pumpWidget(notebook(study, plansOpened: opened));
      await tester.pumpAndSettle();

      expect(find.textContaining('come with Studafy Plus'), findsOne);
      await tester.tap(find.text('Snap the whiteboard'));
      await tester.pumpAndSettle();
      expect(opened, ['plans']);
      expect(study.uploads.commands, isEmpty);
    });

    testWidgets('on Plus, a photo is uploaded, waited for, and becomes notes', (
      tester,
    ) async {
      tall(tester);
      final study = _Study(tier: StudyPlanTier.plus, notReadyTimes: 2);
      await tester.pumpWidget(notebook(study));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Snap the whiteboard'));
      await tester.pumpAndSettle();

      final command = study.uploads.commands.single;
      expect(command.purpose, FilePurpose.notebookPhoto);
      expect(command.classroomId, 'c1');
      // Asked again while the photo was still being checked, then filed.
      expect(study.whiteboardCalls, 3);
      expect(find.text('Board notes'), findsOne);
    });
  });

  testWidgets('lessons are shown under their day', (tester) async {
    tall(tester);
    final today = DateTime.now();
    await tester.pumpWidget(
      localizedApp(
        home: Scaffold(
          body: LessonsByDateView(
            repository: _Lessons([
              AcademicRecord(
                id: 'l1',
                title: 'Photosynthesis',
                detail: 'Light into sugar.',
                state: 'published',
                version: 1,
                date: today,
              ),
              AcademicRecord(
                id: 'l2',
                title: 'Cells',
                detail: 'The unit of life.',
                state: 'published',
                version: 1,
                date: today.subtract(const Duration(days: 1)),
              ),
            ]),
            classroomId: 'c1',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Today'), findsOne);
    expect(find.text('Yesterday'), findsOne);
    expect(find.text('Photosynthesis'), findsOne);
  });

  group('quizzes and flashcards', () {
    Widget buttons(_Study study, StudyPlan plan, List<String> opened) =>
        localizedApp(
          home: Scaffold(
            body: StudySetButtons(
              study: study,
              resourceId: 'l1',
              lessonTitle: 'Photosynthesis',
              plan: plan,
              onOpenPlans: () => opened.add('plans'),
            ),
          ),
        );

    testWidgets('without Max they lead to the plans', (tester) async {
      final opened = <String>[];
      final study = _Study();
      await tester.pumpWidget(
        buttons(study, planOf(StudyPlanTier.plus), opened),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Quiz'));
      await tester.pumpAndSettle();
      expect(opened, ['plans']);
      expect(study.setsRequested, isEmpty);
    });

    testWidgets('on Max, a quiz marks each answer', (tester) async {
      tall(tester);
      final study = _Study();
      await tester.pumpWidget(buttons(study, planOf(StudyPlanTier.max), []));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Quiz'));
      await tester.pumpAndSettle();

      expect(study.setsRequested, [('l1', StudySetKind.quiz)]);
      expect(find.text('0 of 1 answered'), findsOne);
      await tester.tap(find.text('Roots'));
      await tester.pumpAndSettle();
      expect(find.text('You scored 0 of 1'), findsOne);
      expect(find.text('In the chloroplasts.'), findsOne);
    });

    testWidgets('on Max, flashcards turn over', (tester) async {
      final study = _Study();
      await tester.pumpWidget(buttons(study, planOf(StudyPlanTier.max), []));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Flashcards'));
      await tester.pumpAndSettle();
      expect(find.text('Chlorophyll'), findsOne);
      await tester.tap(find.text('Chlorophyll'));
      await tester.pumpAndSettle();
      expect(find.text('The green pigment'), findsOne);
    });
  });

  group('the plans screen', () {
    Widget plans(_Study study, _Store store) => localizedApp(
      home: StudyPlansPage(study: study, subscriptions: store),
    );

    testWidgets('names every plan and what it unlocks', (tester) async {
      tall(tester);
      await tester.pumpWidget(plans(_Study(), _Store()));
      await tester.pumpAndSettle();
      for (final name in ['Studafy Free', 'Studafy Plus', 'Studafy Max']) {
        expect(find.text(name), findsOne);
      }
      expect(
        find.text('Snap the whiteboard - get real notebook notes'),
        findsOne,
      );
      expect(find.text('Quizzes made from your lessons'), findsOne);
      // The store's own price, in the student's currency.
      expect(find.text(r'$5.99 / month'), findsOne);
      // On the free plan: today's questions, not a money allowance.
      expect(find.text('Questions today: 0 of 10'), findsOne);
    });

    testWidgets('a paid plan shows how much of the month is used', (
      tester,
    ) async {
      tall(tester);
      await tester.pumpWidget(
        plans(_Study(tier: StudyPlanTier.plus), _Store()),
      );
      await tester.pumpAndSettle();
      expect(find.text('AI used this month: 25%'), findsOne);
      expect(find.text('Your plan'), findsOne);
    });

    testWidgets('a student asks a parent first, then subscribes', (
      tester,
    ) async {
      tall(tester);
      final store = _Store();
      await tester.pumpWidget(plans(_Study(), store));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ask a parent to approve').first);
      await tester.pumpAndSettle();
      expect(store.approvalsRequested, [StudyPlanTier.plus]);

      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(plans(_Study(), _Store()..approved = true));
      await tester.pumpAndSettle();
      expect(find.text('Subscribe to Studafy Max'), findsOne);
    });
  });
}

class _Study implements StudyRepository {
  _Study({
    this.tier = StudyPlanTier.free,
    List<NotebookEntry>? entries,
    this.notReadyTimes = 0,
  }) : entries = entries ?? [];

  final StudyPlanTier tier;
  final List<NotebookEntry> entries;
  int notReadyTimes;
  final uploads = _Uploads();
  final added = <(String, String, String)>[];
  final setsRequested = <(String, StudySetKind)>[];
  int whiteboardCalls = 0;

  @override
  Future<StudyPlan> plan() async => StudyPlan(
    tier: tier,
    allowanceUsed: tier == StudyPlanTier.free ? 0 : 0.25,
    resetsAt: DateTime(2026, 10, 1),
    askToday: 0,
    askPerDay: 10,
  );

  @override
  Future<List<NotebookEntry>> notebook(String classroomId) async =>
      List.of(entries);

  @override
  Future<NotebookEntry> addNote(
    String classroomId, {
    required String title,
    required String body,
  }) async {
    added.add((classroomId, title, body));
    final entry = NotebookEntry(
      id: 'n${entries.length}',
      classroomId: classroomId,
      title: title,
      body: body,
      fromWhiteboard: false,
      createdAt: DateTime.now(),
    );
    entries.insert(0, entry);
    return entry;
  }

  @override
  Future<NotebookEntry> whiteboardNote(
    String classroomId,
    String photoFileId,
  ) async {
    whiteboardCalls++;
    if (notReadyTimes > 0) {
      notReadyTimes--;
      throw const StudyException(StudyRefusal.photoNotReady);
    }
    final entry = NotebookEntry(
      id: 'wb',
      classroomId: classroomId,
      title: 'Board notes',
      body: '- Chloroplasts',
      fromWhiteboard: true,
      createdAt: DateTime.now(),
    );
    entries.insert(0, entry);
    return entry;
  }

  @override
  Future<void> deleteNote(String entryId) async =>
      entries.removeWhere((e) => e.id == entryId);

  @override
  Future<StudySet> studySet(String resourceId, StudySetKind kind) async {
    setsRequested.add((resourceId, kind));
    return kind == StudySetKind.quiz
        ? const StudySet(
            kind: StudySetKind.quiz,
            questions: [
              QuizQuestion(
                question: 'Where does photosynthesis happen?',
                options: ['Chloroplasts', 'Roots', 'Nucleus', 'Stem'],
                answerIndex: 0,
                explanation: 'In the chloroplasts.',
              ),
            ],
          )
        : const StudySet(
            kind: StudySetKind.flashcards,
            cards: [Flashcard(front: 'Chlorophyll', back: 'The green pigment')],
          );
  }
}

class _Uploads implements FileUploadRepository {
  final commands = <FileUploadCommand>[];

  @override
  Future<QuarantinedFile> upload(FileUploadCommand command) async {
    commands.add(command);
    return QuarantinedFile(
      id: 'photo-1',
      uploadId: 'upload-1',
      displayName: command.displayName,
      sizeBytes: command.bytes.length,
      scanState: 'quarantined',
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _Lessons implements AcademicRepository {
  _Lessons(this.records);
  final List<AcademicRecord> records;

  @override
  Future<List<AcademicRecord>> load(
    AcademicFeed feed, {
    String? classroomId,
    String? studentId,
  }) async => records;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _Store implements StudyPlanSubscriptionRepository {
  bool approved = false;
  final approvalsRequested = <StudyPlanTier>[];

  @override
  Future<StudyPlanOffer> offer(StudyPlanTier tier) async => StudyPlanOffer(
    tier: tier,
    price: tier == StudyPlanTier.max ? r'$5.99' : r'$3.99',
    monthly: true,
    storeAvailable: true,
    selfPurchaseEnabled: true,
    approval: approved ? 'approved' : 'none',
  );

  @override
  Future<void> requestApproval(StudyPlanTier tier) async =>
      approvalsRequested.add(tier);

  @override
  Future<void> purchase(StudyPlanTier tier) async {}

  @override
  Future<void> restorePurchases() async {}

  @override
  void addEntitlementListener(VoidCallback listener) {}

  @override
  void removeEntitlementListener(VoidCallback listener) {}
}
