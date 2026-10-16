import 'package:flutter/material.dart';

import '../core/ai_tokens.dart';
import '../core/feedback.dart';
import '../core/material_selection.dart';
import '../core/navigation.dart';
import '../core/studafy_components.dart';
import '../core/studafy_design.dart';
import '../core/studafy_formatting.dart';
import '../core/user_content_text.dart';
import '../features/academic/domain/academic_repository.dart';
import '../features/classes/application/class_list_interactor.dart';
import '../features/classes/domain/classroom.dart';
import '../features/study/domain/study.dart';
import '../l10n/generated/app_l10n.dart';

/// The one place class material is chosen for AI (2026-10-07, ADR-0039):
/// summaries, quizzes, flashcards, notebooks and the study helper.
///
/// Classes, each with its lessons; each lesson with its own text and its
/// files and links, every one a visible checkbox. What is chosen is always
/// shown in a line at the foot, beside the action it is for, and can be
/// reviewed and trimmed before anything is made. Nothing is chosen for the
/// student: a whole class only through "Select entire class" and a
/// confirmation of what that is.
///
/// Composed in the app layer: it draws on the classes, academic and study
/// features, which may not import each other.
Future<MaterialSelection?> pickMaterials(
  BuildContext context,
  MaterialPickRequest request, {
  required ClassListInteractor classes,
  required AcademicRepository academic,
  StudyRepository? study,
}) => Navigator.of(context).pushOnce<MaterialSelection>(
  MaterialPageRoute<MaterialSelection>(
    builder: (_) => MaterialPickerPage(
      request: request,
      classes: classes,
      academic: academic,
      study: study,
    ),
  ),
);

/// The most lessons one request may use; the server holds the same line.
const maxPickedLessons = 10;

/// The label of [action]'s button.
String materialActionLabel(AppL10n l10n, MaterialAction action) =>
    switch (action) {
      MaterialAction.summary => l10n.pickActionSummary,
      MaterialAction.quiz => l10n.pickActionQuiz,
      MaterialAction.flashcards => l10n.pickActionFlashcards,
      MaterialAction.notebook => l10n.pickActionNotebook,
      MaterialAction.helper => l10n.pickActionHelper,
    };

/// "Biology · 8A".
String classLabelOf(ClassroomSummary classroom) {
  final label = '${classroom.grade}${classroom.section}'.trim();
  return label.isEmpty ? classroom.name : '${classroom.name} · $label';
}

/// What is chosen of one lesson.
class _Pick {
  _Pick({required this.includeText, Set<String>? sources})
    : sources = sources ?? <String>{};

  bool includeText;
  final Set<String> sources;
}

class MaterialPickerPage extends StatefulWidget {
  const MaterialPickerPage({
    super.key,
    required this.request,
    required this.classes,
    required this.academic,
    this.study,
  });

  final MaterialPickRequest request;
  final ClassListInteractor classes;
  final AcademicRepository academic;
  final StudyRepository? study;

  @override
  State<MaterialPickerPage> createState() => _MaterialPickerPageState();
}

class _MaterialPickerPageState extends State<MaterialPickerPage> {
  List<ClassroomSummary>? _classes;
  bool _failed = false;
  final _lessons = <String, List<AcademicRecord>>{};
  final _notes = <String, List<NotebookEntry>>{};
  final _sources = <String, List<MaterialSource>>{};
  final _loadingSources = <String>{};
  final _picks = <String, _Pick>{};
  final _pickedNotes = <String>{};
  final _expanded = <String>{};
  final _search = TextEditingController();
  String? _classFilter;

  MaterialPickRequest get _request => widget.request;

  @override
  void initState() {
    super.initState();
    for (final lesson in _request.initial.lessons) {
      _picks[lesson.lessonId] = _Pick(
        includeText: lesson.includeText || lesson.wholeLesson,
        sources: {...lesson.sourceIds},
      );
      // A whole lesson's files are filled in once they are known.
      if (lesson.wholeLesson) _wantWhole.add(lesson.lessonId);
    }
    _pickedNotes.addAll(_request.initial.notes.map((n) => n.id));
    _search.addListener(() => setState(() {}));
    _load();
  }

  /// Lessons chosen whole before their files were known.
  final _wantWhole = <String>{};

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _failed = false);
    try {
      final all = (await widget.classes.loadClasses()).fold(
        onSuccess: (list) => list,
        onFailure: (failure) => throw failure,
      );
      final classes = [
        for (final c in all)
          if (_request.onlyClassroomId == null ||
              c.id.value == _request.onlyClassroomId)
            c,
      ];
      await Future.wait([
        for (final classroom in classes) _loadClass(classroom.id.value),
      ]);
      if (!mounted) return;
      setState(() => _classes = classes);
      final preselect = _request.preselectLessonId;
      if (preselect != null) {
        _expanded.add(preselect);
        if (!_picks.containsKey(preselect)) await _chooseLesson(preselect);
      }
      for (final id in [..._wantWhole, ..._picks.keys]) {
        await _loadSources(id);
      }
    } on Object {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _loadClass(String classroomId) async {
    _lessons[classroomId] = await widget.academic.load(
      AcademicFeed.content,
      classroomId: classroomId,
    );
    if (_request.allowNotes && widget.study != null) {
      try {
        _notes[classroomId] = await widget.study!.notebook(classroomId);
      } on Object {
        _notes[classroomId] = const [];
      }
    }
  }

  Future<List<MaterialSource>> _loadSources(String lessonId) async {
    if (_sources[lessonId] case final known?) return known;
    if (!_loadingSources.add(lessonId)) {
      while (_loadingSources.contains(lessonId)) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      return _sources[lessonId] ?? const [];
    }
    if (mounted) setState(() {});
    try {
      final list = [
        for (final s in await widget.academic.lessonReading(lessonId))
          MaterialSource(
            id: s.id,
            isLink: s.isLink,
            name: s.name,
            state: s.state.name,
            reason: s.reason,
          ),
      ];
      _sources[lessonId] = list;
      if (_wantWhole.remove(lessonId)) {
        _picks[lessonId]?.sources.addAll([
          for (final s in list)
            if (s.ready) s.id,
        ]);
      }
      return list;
    } on Object {
      _sources[lessonId] = const [];
      return const [];
    } finally {
      _loadingSources.remove(lessonId);
      if (mounted) setState(() {});
    }
  }

  AcademicRecord? _record(String lessonId) {
    for (final list in _lessons.values) {
      for (final lesson in list) {
        if (lesson.id == lessonId) return lesson;
      }
    }
    return null;
  }

  String? _classOf(String lessonId) {
    for (final entry in _lessons.entries) {
      if (entry.value.any((l) => l.id == lessonId)) return entry.key;
    }
    return null;
  }

  bool _hasText(String lessonId) =>
      _record(lessonId)?.detail.trim().isNotEmpty ?? false;

  int _sourceCount(AcademicRecord lesson) =>
      _sources[lesson.id]?.length ??
      lesson.attachments.length + lesson.links.length;

  int get _pickedLessons =>
      _picks.values.where((p) => p.includeText || p.sources.isNotEmpty).length;

  void _say(String text) => ScaffoldMessenger.of(context).showMessage(text);

  /// A lesson chosen whole: its text and every file and link that can be
  /// read. Files still being read are shown, not chosen.
  Future<void> _chooseLesson(String lessonId) async {
    final l10n = AppL10n.of(context);
    if (_request.singleLesson) {
      _picks.removeWhere((id, _) => id != lessonId);
    } else if (!_picks.containsKey(lessonId) &&
        _pickedLessons >= maxPickedLessons) {
      _say(l10n.pickTooManyLessons(maxPickedLessons));
      return;
    }
    setState(() => _picks[lessonId] = _Pick(includeText: _hasText(lessonId)));
    final sources = await _loadSources(lessonId);
    if (!mounted) return;
    setState(() {
      _picks[lessonId]?.sources.addAll([
        for (final s in sources)
          if (s.ready) s.id,
      ]);
      _expanded.add(lessonId);
    });
  }

  void _clearLesson(String lessonId) => setState(() => _picks.remove(lessonId));

  /// Every item of the lesson that can be chosen is chosen.
  bool? _lessonValue(AcademicRecord lesson) {
    final pick = _picks[lesson.id];
    if (pick == null || (!pick.includeText && pick.sources.isEmpty)) {
      return false;
    }
    final sources = _sources[lesson.id];
    if (sources == null) return null;
    final all =
        (!_hasText(lesson.id) || pick.includeText) &&
        sources.where((s) => s.ready).every((s) => pick.sources.contains(s.id));
    return all ? true : null;
  }

  void _toggleText(String lessonId, bool on) {
    if (on && !_picks.containsKey(lessonId)) {
      if (_request.singleLesson) {
        _picks.clear();
      } else if (_pickedLessons >= maxPickedLessons) {
        _say(AppL10n.of(context).pickTooManyLessons(maxPickedLessons));
        return;
      }
    }
    setState(() {
      final pick = _picks.putIfAbsent(
        lessonId,
        () => _Pick(includeText: false),
      );
      pick.includeText = on;
      if (!pick.includeText && pick.sources.isEmpty) _picks.remove(lessonId);
    });
  }

  void _toggleSource(String lessonId, String sourceId, bool on) {
    if (on && !_picks.containsKey(lessonId)) {
      if (_request.singleLesson) {
        _picks.clear();
      } else if (_pickedLessons >= maxPickedLessons) {
        _say(AppL10n.of(context).pickTooManyLessons(maxPickedLessons));
        return;
      }
    }
    setState(() {
      final pick = _picks.putIfAbsent(
        lessonId,
        () => _Pick(includeText: false),
      );
      on ? pick.sources.add(sourceId) : pick.sources.remove(sourceId);
      if (!pick.includeText && pick.sources.isEmpty) _picks.remove(lessonId);
    });
  }

  /// A whole class, only when asked for and confirmed.
  Future<void> _selectClass(ClassroomSummary classroom) async {
    final l10n = AppL10n.of(context);
    final lessons = _lessons[classroom.id.value] ?? const [];
    if (lessons.isEmpty) return;
    final others = _picks.keys
        .where((id) => _classOf(id) != classroom.id.value)
        .length;
    if (lessons.length + others > maxPickedLessons) {
      _say(l10n.pickTooManyLessons(maxPickedLessons));
      return;
    }
    final files = lessons.fold(0, (n, l) => n + _sourceCount(l));
    final sure = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.pickSelectClassTitle(classLabelOf(classroom))),
        content: Text(l10n.pickSelectClassBody(lessons.length, files)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(
              MaterialLocalizations.of(dialogContext).cancelButtonLabel,
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.pickSelectClassConfirm),
          ),
        ],
      ),
    );
    if (sure != true || !mounted) return;
    await Future.wait([for (final lesson in lessons) _chooseLesson(lesson.id)]);
  }

  MaterialSelection _selection() {
    final lessons = <LessonSelection>[];
    for (final entry in _picks.entries) {
      final pick = entry.value;
      if (!pick.includeText && pick.sources.isEmpty) continue;
      final record = _record(entry.key);
      final classroomId = _classOf(entry.key);
      final classroom = _classes?.where((c) => c.id.value == classroomId);
      final sources = _sources[entry.key] ?? const <MaterialSource>[];
      final value = record == null ? false : _lessonValue(record);
      lessons.add(
        LessonSelection(
          lessonId: entry.key,
          title: record?.title ?? '',
          classroomId: classroomId ?? '',
          classLabel: classroom == null || classroom.isEmpty
              ? ''
              : classLabelOf(classroom.first),
          includeText: pick.includeText,
          sourceIds: {...pick.sources},
          sourceNames: {for (final s in sources) s.id: s.name},
          // Whole only when nothing on it is left out: every file can be
          // read and is chosen, and so is its text.
          wholeLesson:
              value == true &&
              sources.every((s) => s.ready) &&
              (pick.includeText || !_hasText(entry.key)),
          totalSources: sources.length,
        ),
      );
    }
    final notes = <NoteSelection>[];
    for (final entry in _notes.entries) {
      for (final note in entry.value) {
        if (!_pickedNotes.contains(note.id)) continue;
        final classroom = _classes?.where((c) => c.id.value == entry.key);
        notes.add(
          NoteSelection(
            id: note.id,
            title: note.title,
            classLabel: classroom == null || classroom.isEmpty
                ? ''
                : classLabelOf(classroom.first),
          ),
        );
      }
    }
    return MaterialSelection(lessons: lessons, notes: notes);
  }

  Future<void> _review() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheet) {
          final l10n = AppL10n.of(sheetContext);
          final selection = _selection();
          void change(VoidCallback edit) {
            edit();
            setSheet(() {});
          }

          return SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(sheetContext).height * .75,
              ),
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 16),
                children: [
                  Text(
                    l10n.pickReviewTitle,
                    style: Theme.of(sheetContext).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    materialSummary(l10n, selection),
                    style: const TextStyle(color: studafyMuted),
                  ),
                  const SizedBox(height: 8),
                  if (selection.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(l10n.pickNothing),
                    ),
                  for (final lesson in selection.lessons) ...[
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.menu_book_rounded),
                      title: UserContentText(
                        lesson.title,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        lesson.wholeLesson
                            ? '${lesson.classLabel} · ${l10n.pickWholeLessonDetail}'
                            : lesson.classLabel,
                      ),
                      trailing: IconButton(
                        tooltip: l10n.pickRemove,
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () =>
                            change(() => _clearLesson(lesson.lessonId)),
                      ),
                    ),
                    if (lesson.includeText)
                      _ReviewItem(
                        icon: Icons.notes_rounded,
                        label: l10n.pickLessonText,
                        onRemove: () =>
                            change(() => _toggleText(lesson.lessonId, false)),
                      ),
                    for (final id in lesson.sourceIds)
                      _ReviewItem(
                        icon: Icons.insert_drive_file_outlined,
                        label: lesson.sourceNames[id] ?? '',
                        onRemove: () => change(
                          () => _toggleSource(lesson.lessonId, id, false),
                        ),
                      ),
                  ],
                  for (final note in selection.notes)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.sticky_note_2_outlined),
                      title: UserContentText(note.title),
                      trailing: IconButton(
                        tooltip: l10n.pickRemove,
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => change(
                          () => setState(() => _pickedNotes.remove(note.id)),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  bool _matches(String text) {
    final query = _search.text.trim().toLowerCase();
    return query.isEmpty || text.toLowerCase().contains(query);
  }

  bool _lessonMatches(AcademicRecord lesson) =>
      _matches(lesson.title) ||
      (_sources[lesson.id] ?? const []).any((s) => _matches(s.name)) ||
      lesson.attachments.any((a) => _matches(a.displayName));

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final classes = _classes;
    final selection = _selection();
    final Widget body;
    if (classes == null) {
      body = Center(
        child: _failed
            ? StudafyEmptyState(
                icon: Icons.cloud_off_rounded,
                title: l10n.pickLoadFailed,
                actionLabel: l10n.nbRetry,
                onAction: _load,
              )
            : const CircularProgressIndicator(),
      );
    } else if (classes.isEmpty) {
      body = Center(
        child: StudafyEmptyState(
          icon: Icons.class_outlined,
          title: l10n.helperNoClasses,
        ),
      );
    } else {
      final shown = [
        for (final c in classes)
          if (_classFilter == null || c.id.value == _classFilter) c,
      ];
      body = ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 12, 24),
        children: [
          TextField(
            controller: _search,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded),
              hintText: l10n.pickSearch,
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: MaterialLocalizations.of(context)
                          .deleteButtonTooltip,
                      icon: const Icon(Icons.clear_rounded),
                      onPressed: _search.clear,
                    ),
            ),
          ),
          if (classes.length > 1) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                ChoiceChip(
                  label: Text(l10n.pickAllClasses),
                  selected: _classFilter == null,
                  onSelected: (_) => setState(() => _classFilter = null),
                ),
                for (final c in classes)
                  ChoiceChip(
                    label: Text(classLabelOf(c)),
                    selected: _classFilter == c.id.value,
                    onSelected: (_) =>
                        setState(() => _classFilter = c.id.value),
                  ),
              ],
            ),
          ],
          if (_request.singleLesson)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                l10n.pickSingleLesson,
                style: const TextStyle(color: studafyMuted, fontSize: 13),
              ),
            ),
          for (final classroom in shown) ..._classSection(l10n, classroom),
        ],
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(l10n.pickTitle)),
      body: body,
      bottomNavigationBar: _bottomBar(l10n, selection),
    );
  }

  List<Widget> _classSection(AppL10n l10n, ClassroomSummary classroom) {
    final lessons = [
      for (final lesson
          in _lessons[classroom.id.value] ?? const <AcademicRecord>[])
        if (_lessonMatches(lesson)) lesson,
    ];
    final notes = [
      for (final note in _notes[classroom.id.value] ?? const <NotebookEntry>[])
        if (_matches(note.title)) note,
    ];
    return [
      SectionHeader(
        classLabelOf(classroom),
        padding: const EdgeInsetsDirectional.fromSTEB(4, 18, 0, 6),
        action: _request.singleLesson || lessons.isEmpty
            ? null
            : TextButton(
                onPressed: () => _selectClass(classroom),
                child: Text(l10n.pickSelectClass),
              ),
      ),
      if (lessons.isEmpty && notes.isEmpty)
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            _search.text.isEmpty ? l10n.notebookNoLessons : l10n.pickNoMatch,
            style: const TextStyle(color: studafyMuted),
          ),
        ),
      for (final lesson in lessons) _lessonCard(l10n, lesson),
      if (notes.isNotEmpty) ...[
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(4, 10, 0, 4),
          child: Text(
            l10n.helperMyNotes,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        for (final note in notes)
          CheckboxListTile(
            value: _pickedNotes.contains(note.id),
            controlAffinity: ListTileControlAffinity.leading,
            secondary: const Icon(Icons.sticky_note_2_outlined),
            title: UserContentText(note.title),
            onChanged: (on) => setState(
              () => on == true
                  ? _pickedNotes.add(note.id)
                  : _pickedNotes.remove(note.id),
            ),
          ),
      ],
    ];
  }

  Widget _lessonCard(AppL10n l10n, AcademicRecord lesson) {
    final value = _lessonValue(lesson);
    final picked = value != false;
    final open = _expanded.contains(lesson.id);
    final sources = _sources[lesson.id];
    final pick = _picks[lesson.id];
    final count = _sourceCount(lesson);
    final waiting = sources?.where((s) => s.processing).length ?? 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: picked
            ? Color.alphaBlend(studafyNavy.withValues(alpha: .06), Colors.white)
            : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: picked ? studafyNavy : studafyHairline,
            width: picked ? 1.6 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: () {
                setState(
                  () => open
                      ? _expanded.remove(lesson.id)
                      : _expanded.add(lesson.id),
                );
                if (!open) _loadSources(lesson.id);
              },
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(4, 6, 8, 6),
                child: Row(
                  children: [
                    Checkbox(
                      tristate: true,
                      value: value,
                      semanticLabel: lesson.title,
                      onChanged: (_) => value == false
                          ? _chooseLesson(lesson.id)
                          : _clearLesson(lesson.id),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          UserContentText(
                            lesson.title,
                            style: const TextStyle(
                              color: studafyInk,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            [
                              if (lesson.date case final date?)
                                studafyMediumDate(context, date),
                              l10n.pickAttachments(count),
                              if (value == true)
                                l10n.pickWholeLessonDetail
                              else if (value == null && pick != null)
                                l10n.pickPartOfLesson,
                            ].join(' · '),
                            style: const TextStyle(
                              color: studafyMuted,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (picked)
                      StatusPill(
                        label: l10n.pickSelected,
                        icon: Icons.check_rounded,
                        color: studafyNavy,
                      ),
                    Icon(
                      open
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      semanticLabel: open ? null : l10n.pickShowFiles,
                    ),
                  ],
                ),
              ),
            ),
            if (open) ...[
              const Divider(height: 1),
              if (_hasText(lesson.id))
                CheckboxListTile(
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: pick?.includeText ?? false,
                  secondary: const Icon(Icons.notes_rounded, size: 20),
                  title: Text(l10n.pickLessonText),
                  onChanged: (on) => _toggleText(lesson.id, on == true),
                ),
              if (sources == null)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              else
                for (final source in sources)
                  CheckboxListTile(
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: pick?.sources.contains(source.id) ?? false,
                    secondary: Icon(
                      source.isLink
                          ? Icons.link_rounded
                          : Icons.insert_drive_file_outlined,
                      size: 20,
                    ),
                    title: UserContentText(source.name),
                    subtitle: source.ready
                        ? null
                        : Text(
                            source.processing
                                ? l10n.pickStillReading
                                : readingReasonText(l10n, source.reason),
                            style: TextStyle(
                              color: source.processing
                                  ? studafyMuted
                                  : studafyDanger,
                              fontSize: 12,
                            ),
                          ),
                    // One that can never be read cannot be chosen; one
                    // still being read can, and is named if it is not
                    // ready in time.
                    onChanged: source.unusable
                        ? null
                        : (on) =>
                              _toggleSource(lesson.id, source.id, on == true),
                  ),
              if (waiting > 0 && picked)
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 10),
                  child: Text(
                    l10n.pickWaitingNotIncluded(waiting),
                    style: const TextStyle(color: studafyMuted, fontSize: 12),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _bottomBar(AppL10n l10n, MaterialSelection selection) => Material(
    elevation: 8,
    color: Colors.white,
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 10, 16, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  selection.isEmpty
                      ? Icons.radio_button_unchecked_rounded
                      : Icons.check_circle_rounded,
                  size: 18,
                  color: selection.isEmpty ? studafyMuted : studafyNavy,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      materialSummary(l10n, selection),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selection.isEmpty ? studafyMuted : studafyInk,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: selection.isEmpty ? null : _review,
                  child: Text(l10n.pickReview),
                ),
              ],
            ),
            const SizedBox(height: 6),
            FilledButton.icon(
              onPressed: selection.isEmpty
                  ? null
                  : () => Navigator.pop(context, selection),
              icon: const Icon(Icons.auto_awesome_rounded),
              label: Text(materialActionLabel(l10n, _request.action)),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ReviewItem extends StatelessWidget {
  const _ReviewItem({
    required this.icon,
    required this.label,
    required this.onRemove,
  });

  final IconData icon;
  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(start: 40),
    child: Row(
      children: [
        Icon(icon, size: 18, color: studafyMuted),
        const SizedBox(width: 8),
        Expanded(child: UserContentText(label)),
        IconButton(
          tooltip: AppL10n.of(context).pickRemove,
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.remove_circle_outline_rounded, size: 20),
          onPressed: onRemove,
        ),
      ],
    ),
  );
}
