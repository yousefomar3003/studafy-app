import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/core/material_selection.dart';
import 'package:studafy/features/study/domain/study.dart';
import 'package:studafy/features/study/domain/study_notebook.dart';
import 'package:studafy/features/study/presentation/notes_text.dart';
import 'package:studafy/features/study/presentation/study_notebook_page.dart';
import 'package:studafy/features/study/presentation/study_notebook_shelf.dart';

import '../../support/accessibility.dart';
import '../../support/localized_app.dart';

void main() {
  void tall(WidgetTester tester) {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  StudyPlan planOf(StudyPlanTier tier) => StudyPlan(
    tier: tier,
    allowance: AiAllowance(
      weekly: false,
      total: 3000000,
      used: 0,
      remaining: 3000000,
      resetsAt: DateTime(2026, 11),
    ),
  );

  group('a lesson\'s notebook button', () {
    // The picker as the student leaves it: the lesson's text and one file,
    // the one still being read left out.
    const chosen = MaterialSelection(
      lessons: [
        LessonSelection(
          lessonId: 'l1',
          title: 'Photosynthesis',
          classroomId: 'c1',
          classLabel: 'Biology · 8A',
          includeText: true,
          sourceIds: {'f1'},
          sourceNames: {'f1': 'Leaf.pdf'},
        ),
      ],
    );
    final requests = <MaterialPickRequest>[];

    Widget button(_Notebooks study, NotebookTracker tracker, StudyPlan plan) =>
        localizedApp(
          home: Scaffold(
            body: Center(
              child: LessonNotebookButton(
                host: NotebookHost(
                  study: study,
                  tracker: tracker,
                  className: 'Biology 8A',
                  plan: () => plan,
                  onOpenPlans: () {},
                  pick: (context, request) async {
                    requests.add(request);
                    return chosen;
                  },
                ),
                resourceId: 'l1',
                lessonTitle: 'Photosynthesis',
              ),
            ),
          ),
        );

    testWidgets('goes Create notebook, Creating…, Open notebook', (
      tester,
    ) async {
      tall(tester);
      final study = _Notebooks();
      final tracker = NotebookTracker(
        repository: study,
        classroomId: 'c1',
        poll: const Duration(milliseconds: 50),
      );
      addTearDown(tracker.dispose);
      await tracker.load();
      await tester.pumpWidget(
        button(study, tracker, planOf(StudyPlanTier.plus)),
      );
      expect(find.text('Create notebook'), findsOne);

      await tester.tap(find.text('Create notebook'));
      // A spinner turns while it is written, so the frames never settle.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      // The picker opened on this lesson, for one lesson of this class.
      expect(requests.single.action, MaterialAction.notebook);
      expect(requests.single.preselectLessonId, 'l1');
      expect(requests.single.onlyClassroomId, 'c1');
      expect(requests.single.singleLesson, isTrue);
      // Exactly what was chosen is sent: the text and one file.
      expect(study.created.single.$1, 'l1');
      expect(study.selections.single!.toJson(), [
        {'kind': 'text', 'id': 'l1'},
        {'kind': 'file', 'id': 'f1', 'lessonId': 'l1'},
      ]);
      expect(find.text('Creating…'), findsOne);

      // Written in the background; the button follows on the next look.
      study.finishAll();
      await tester.pump(const Duration(milliseconds: 60));
      await tester.pump(const Duration(milliseconds: 60));
      expect(find.text('Open notebook'), findsOne);

      study.lessonChanged();
      await tracker.load();
      await tester.pump();
      expect(find.text('Update available'), findsOne);
    });

    testWidgets('on the free plan, it offers the plan instead', (tester) async {
      tall(tester);
      final study = _Notebooks();
      final tracker = NotebookTracker(repository: study, classroomId: 'c1');
      addTearDown(tracker.dispose);
      await tracker.load();
      await tester.pumpWidget(
        button(study, tracker, planOf(StudyPlanTier.free)),
      );
      await tester.tap(find.text('Create notebook'));
      await tester.pumpAndSettle();
      expect(find.text('New study notebook'), findsNothing);
      expect(study.created, isEmpty);
    });
  });

  group('the notebook', () {
    Widget page(
      _Notebooks study, {
      StudyPlanTier tier = StudyPlanTier.max,
      Locale? locale,
    }) => localizedApp(
      locale: locale,
      home: StudyNotebookPage(
        study: study,
        notebookId: 'n1',
        plan: planOf(tier),
        onOpenPlans: () {},
        poll: const Duration(milliseconds: 50),
      ),
    );

    // Launch plan 7.1: an open notebook passes the accessibility checks in
    // both languages.
    for (final locale in const [Locale('en'), Locale('ar')]) {
      testWidgets('an open notebook is accessible: ${locale.languageCode}', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        tall(tester);
        final study = _Notebooks()..seedReady();
        await tester.pumpWidget(page(study, locale: locale));
        await tester.pumpAndSettle();
        await expectAccessible(tester);
        semantics.dispose();
      });
    }

    testWidgets('has a cover, contents and numbered pages, only for parts '
        'that have something in them', (tester) async {
      tall(tester);
      final study = _Notebooks()..seedReady();
      await tester.pumpWidget(page(study));
      await tester.pumpAndSettle();

      expect(find.text('Leaves and light'), findsWidgets);
      expect(find.text('Page 1 of 8'), findsWidgets);

      await tester.tap(find.byTooltip('Contents'));
      await tester.pumpAndSettle();
      for (final title in [
        'Overview',
        'Key terms',
        'Chloroplasts',
        'Common mistakes',
        'Practice',
      ]) {
        expect(find.text(title), findsWidgets, reason: title);
      }
      // No worked examples, facts or objectives in the material: no pages.
      expect(find.text('Worked examples'), findsNothing);
      expect(find.text('Learning objectives'), findsNothing);

      await tester.tap(find.text('Chloroplasts').last);
      await tester.pumpAndSettle();
      expect(find.text('Page 6 of 8'), findsWidgets);
      expect(find.text('Leaf.pdf, page 2'), findsOne);
    });

    testWidgets('notes, highlights and bookmarks are saved; a save made '
        'elsewhere is merged, not lost', (tester) async {
      tall(tester);
      final study = _Notebooks()..seedReady();
      await tester.pumpWidget(page(study));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Contents'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Overview').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Bookmark this page'));
      await tester.pumpAndSettle();
      expect(study.saved.last.bookmarks, ['overview']);

      // Another device saved a note meanwhile.
      study.conflictWith(
        const NotebookPersonal(
          notes: [NotebookNote(id: 'x', sectionKey: 'terms', text: 'Phone')],
        ),
      );
      await tester.longPress(find.text('Plants make food from light.'));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Yellow'));
      await tester.pumpAndSettle();
      final merged = study.saved.last;
      expect(merged.highlightOf('overview', 0), HighlightColor.yellow);
      expect(merged.notes.single.text, 'Phone');
      expect(merged.bookmarks, ['overview']);

      await tester.tap(find.text('Add a note'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Ask about stomata');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Ask about stomata'), findsOne);
      expect(
        study.saved.last.notesFor('overview').single.text,
        'Ask about stomata',
      );
      expect(find.text('Saved'), findsOne);
    });

    testWidgets('while it is written it says so, then opens', (tester) async {
      tall(tester);
      final study = _Notebooks()..seedCreating();
      await tester.pumpWidget(page(study));
      await tester.pump();
      await tester.pump();
      expect(find.text('Writing your notebook…'), findsOne);
      study.finishAll();
      await tester.pump(const Duration(milliseconds: 80));
      await tester.pumpAndSettle();
      expect(find.text('Writing your notebook…'), findsNothing);
      expect(find.text('Page 1 of 8'), findsWidgets);
    });

    testWidgets('a notebook that could not be written explains and retries', (
      tester,
    ) async {
      tall(tester);
      final study = _Notebooks()..seedFailed('no_readable_material');
      await tester.pumpWidget(page(study));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'The lesson has nothing that can be read to make a notebook from.',
        ),
        findsOne,
      );
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Update notebook'));
      // Being written again: a progress bar that never settles.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      expect(study.updates, 1);
      expect(find.text('Writing your notebook…'), findsOne);
    });

    testWidgets('reads right to left in Arabic', (tester) async {
      tall(tester);
      final study = _Notebooks()..seedReady();
      await tester.pumpWidget(
        localizedApp(
          locale: const Locale('ar'),
          home: StudyNotebookPage(
            study: study,
            notebookId: 'n1',
            plan: planOf(StudyPlanTier.max),
            onOpenPlans: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('صفحة 1 من 8'), findsWidgets);
      final direction = Directionality.of(
        tester.element(find.byType(PageView)),
      );
      expect(direction, TextDirection.rtl);
      expect(tester.takeException(), isNull);
    });
  });

  group('notes written in Markdown', () {
    test('are read as headings, lists and bold text', () {
      final blocks = parseNotes(
        '## Photosynthesis\n\n- **Light** is absorbed\n1. Water splits\nPlain',
      );
      expect(blocks.map((b) => b.kind), [
        NotesBlockKind.heading,
        NotesBlockKind.bullet,
        NotesBlockKind.numbered,
        NotesBlockKind.paragraph,
      ]);
      expect(blocks.first.text, 'Photosynthesis');
      final spans = inlineSpans(blocks[1].text);
      expect(
        spans.map((s) => (s as TextSpan).text).join(),
        'Light is absorbed',
      );
    });

    testWidgets('show no Markdown marks', (tester) async {
      await tester.pumpWidget(
        localizedApp(
          home: const Scaffold(
            body: NotesText('## Cells\n**Nucleus** holds DNA'),
          ),
        ),
      );
      expect(find.textContaining('#'), findsNothing);
      expect(find.textContaining('**'), findsNothing);
      expect(find.text('Cells'), findsOne);
    });
  });
}

/// The server, as far as notebooks go.
class _Notebooks implements StudyRepository {
  final created = <(String, List<String>)>[];
  final saved = <NotebookPersonal>[];
  final selections = <MaterialSelection?>[];
  int updates = 0;
  final _summaries = <String, Map<String, Object?>>{};
  NotebookPersonal _personal = const NotebookPersonal();
  int _version = 1;
  NotebookPersonal? _conflict;
  bool _changed = false;

  static Map<String, Object?> _summary(String status, {String? failure}) => {
    'id': 'n1',
    'classroomId': 'c1',
    'resourceId': 'l1',
    'lessonTitle': 'Photosynthesis',
    'title': 'Leaves and light',
    'subtitle': null,
    'color': 'teal',
    'icon': 'science',
    'pageStyle': 'lined',
    'status': status,
    'failure': failure,
    'updateAvailable': false,
    'contentVersion': status == 'ready' ? 1 : 0,
    'sourceCount': 0,
    'createdAt': '2026-10-07T08:00:00Z',
    'updatedAt': '2026-10-07T08:00:00Z',
  };

  void seedReady() => _summaries['n1'] = _summary('ready');
  void seedCreating() => _summaries['n1'] = _summary('creating');
  void seedFailed(String why) =>
      _summaries['n1'] = _summary('failed', failure: why);

  void finishAll() {
    for (final id in _summaries.keys) {
      _summaries[id] = {..._summary('ready'), 'id': id};
    }
  }

  void lessonChanged() {
    _changed = true;
    for (final id in _summaries.keys) {
      _summaries[id] = {..._summaries[id]!, 'updateAvailable': true};
    }
  }

  void conflictWith(NotebookPersonal other) => _conflict = other;

  StudyNotebookSummary _of(String id) =>
      StudyNotebookSummary.fromJson(_summaries[id]!.cast());

  @override
  Future<StudyPlan> plan() async => throw UnimplementedError();

  @override
  Future<List<StudyNotebookSummary>> notebooks(String classroomId) async => [
    for (final id in _summaries.keys) _of(id),
  ];

  @override
  Future<StudyNotebookSummary> createNotebook(
    String classroomId, {
    required String resourceId,
    required List<String> sourceIds,
    String? title,
    MaterialSelection? selection,
    bool skipUnavailable = false,
  }) async {
    created.add((resourceId, sourceIds));
    selections.add(selection);
    final id = 'n${created.length}';
    _summaries[id] = {..._summary('creating'), 'id': id};
    return _of(id);
  }

  @override
  Future<StudyNotebook> openNotebook(String notebookId) async {
    final summary = _summaries[notebookId]!;
    final ready = summary['contentVersion'] != 0;
    return StudyNotebook(
      summary: _of(notebookId),
      className: 'Biology 8A',
      content: ready
          ? const NotebookContent(
              overview: 'Plants make food from light.',
              keyTerms: [
                NotebookTerm(term: 'Chlorophyll', definition: 'Green pigment'),
              ],
              sections: [
                NotebookSection(
                  key: 's-leaf',
                  heading: 'Leaves',
                  paragraphs: ['Leaves are thin and wide.'],
                ),
                NotebookSection(
                  key: 's-chl',
                  heading: 'Chloroplasts',
                  points: ['They hold chlorophyll.'],
                  cites: [NotebookCitation(name: 'Leaf.pdf', page: 2)],
                ),
              ],
              mistakes: [NotebookItem(text: 'Roots do not photosynthesise.')],
            )
          : null,
      personal: _personal,
      personalVersion: _version,
    );
  }

  @override
  Future<StudyNotebookSummary> updateNotebook(
    String notebookId, {
    List<String>? sourceIds,
    bool skipUnavailable = false,
  }) async {
    updates++;
    _summaries[notebookId] = {..._summaries[notebookId]!, 'status': 'creating'};
    return _of(notebookId);
  }

  @override
  Future<StudyNotebookSummary> saveNotebookSettings(
    String notebookId,
    NotebookSettings settings,
  ) async => _of(notebookId);

  @override
  Future<StudyNotebook> saveNotebookPersonal(
    String notebookId, {
    required int expectedVersion,
    required NotebookPersonal personal,
  }) async {
    if (_conflict case final other?) {
      _conflict = null;
      _personal = other;
      _version++;
      throw const NotebookConflict(null);
    }
    if (expectedVersion != _version) throw const NotebookConflict(null);
    _personal = personal;
    _version++;
    saved.add(personal);
    return openNotebook(notebookId);
  }

  @override
  Future<void> deleteNotebook(String notebookId) async =>
      _summaries.remove(notebookId);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  bool get changed => _changed;
}
