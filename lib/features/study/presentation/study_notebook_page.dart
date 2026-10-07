import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/ai_tokens.dart';
import '../../../core/feedback.dart';
import '../../../core/material_selection.dart';
import '../../../core/material_unavailable_dialog.dart';
import '../../../core/navigation.dart';
import '../../../core/studafy_components.dart';
import '../../../core/studafy_design.dart';
import '../../../core/user_content_text.dart';
import '../../../l10n/generated/app_l10n.dart';
import '../domain/study.dart';
import '../domain/study_notebook.dart';
import 'notebook_cover.dart';
import 'study_set_pages.dart';
import 'upgrade_prompt.dart';

/// One study notebook, read like a paper one: a cover, a contents page,
/// then numbered pages - the AI's parts, the student's own sections, and a
/// page to practise from. A long press on any line marks it in a colour or
/// adds a note to it; notes, highlights, bookmarks and sections are the
/// student's and are saved as they are made.
class StudyNotebookPage extends StatefulWidget {
  const StudyNotebookPage({
    super.key,
    required this.study,
    required this.notebookId,
    required this.plan,
    required this.onOpenPlans,
    this.onChanged,
    this.onDeleted,
    this.poll = const Duration(seconds: 3),
  });

  final StudyRepository study;
  final String notebookId;
  final StudyPlan? plan;
  final VoidCallback onOpenPlans;

  /// The notebook's summary changed: the class page shows the new state.
  final ValueChanged<StudyNotebookSummary>? onChanged;
  final ValueChanged<String>? onDeleted;

  /// How often to look again while it is being written.
  final Duration poll;

  @override
  State<StudyNotebookPage> createState() => _StudyNotebookPageState();
}

enum _Saving { idle, saving, saved, failed }

/// A page of the notebook.
class _Page {
  const _Page(this.key, this.title, this.build, {this.markable = true});

  /// A part's or section's key: what notes, highlights and bookmarks are
  /// kept against.
  final String key;
  final String title;
  final WidgetBuilder build;

  /// Can be bookmarked.
  final bool markable;
}

class _StudyNotebookPageState extends State<StudyNotebookPage> {
  StudyNotebook? _notebook;
  bool _failed = false;
  Timer? _timer;
  final _pages = PageController();
  int _page = 0;

  /// The student's own part as shown - ahead of the server while a save is
  /// on its way - and the version the server last confirmed.
  NotebookPersonal _local = const NotebookPersonal();
  int _version = 1;
  bool _dirty = false;
  bool _flushing = false;
  _Saving _saving = _Saving.idle;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pages.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    _timer?.cancel();
    try {
      final notebook = await widget.study.openNotebook(widget.notebookId);
      if (!mounted) return;
      setState(() {
        _notebook = notebook;
        _failed = false;
        // Edits not yet saved stay on screen.
        if (!_dirty && !_flushing) {
          _local = notebook.personal;
          _version = notebook.personalVersion;
        }
      });
      widget.onChanged?.call(notebook.summary);
      if (notebook.summary.status == NotebookStatus.creating) {
        _timer = Timer(widget.poll, _load);
      }
    } on Object {
      if (mounted) setState(() => _failed = _notebook == null);
    }
  }

  // ---------------------------------------------------------------------
  // Saving the student's own part.
  // ---------------------------------------------------------------------

  void _edit(NotebookPersonal Function(NotebookPersonal) change) {
    setState(() {
      _local = change(_local);
      _dirty = true;
      _saving = _Saving.saving;
    });
    unawaited(_flush());
  }

  /// Sends what is on screen until the server has it. Edits made while a
  /// save is on its way go in the next one; a copy saved meanwhile on
  /// another device is merged in, not overwritten.
  Future<void> _flush() async {
    if (_flushing) return;
    _flushing = true;
    var conflicts = 0;
    try {
      while (_dirty && mounted) {
        _dirty = false;
        final sending = _local;
        try {
          final saved = await widget.study.saveNotebookPersonal(
            widget.notebookId,
            expectedVersion: _version,
            personal: sending,
          );
          _version = saved.personalVersion;
        } on NotebookConflict {
          if (++conflicts > 3) rethrow;
          final latest = await widget.study.openNotebook(widget.notebookId);
          _version = latest.personalVersion;
          if (mounted) {
            setState(() => _local = _local.mergedOver(latest.personal));
          }
          _dirty = true;
        }
      }
      if (mounted) setState(() => _saving = _Saving.saved);
    } on Object {
      _dirty = true;
      if (mounted) setState(() => _saving = _Saving.failed);
    } finally {
      _flushing = false;
    }
  }

  // ---------------------------------------------------------------------
  // Cover, headings, update, delete.
  // ---------------------------------------------------------------------

  Future<void> _saveSettings(NotebookSettings settings) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppL10n.of(context);
    try {
      final summary = await widget.study.saveNotebookSettings(
        widget.notebookId,
        settings,
      );
      if (!mounted) return;
      setState(
        () => _notebook = _notebook!.copyWith(
          summary: summary,
          headings: settings.headings,
        ),
      );
      widget.onChanged?.call(summary);
    } on Object {
      messenger.showMessage(l10n.nbSaveFailed);
    }
  }

  String _heading(String key, String original) =>
      _notebook?.headings[key] ?? original;

  Future<void> _rename(String key, String original) async {
    final l10n = AppL10n.of(context);
    final text = await _askText(
      title: l10n.nbRenameHeading,
      label: l10n.nbSettingsTitle,
      initial: _heading(key, original),
      maxLength: 160,
      resetLabel: l10n.nbResetHeading,
    );
    if (text == null || !mounted) return;
    final headings = Map.of(_notebook!.headings);
    if (text.isEmpty || text == original) {
      headings.remove(key);
    } else {
      headings[key] = text;
    }
    await _saveSettings(
      NotebookSettings.of(_notebook!).copyWith(headings: headings),
    );
  }

  Future<void> _update() async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppL10n.of(context);
    final sure = await _confirm(
      title: l10n.nbUpdateConfirmTitle,
      body: l10n.nbUpdateConfirmBody,
      action: l10n.nbUpdate,
    );
    if (!sure || !mounted) return;
    try {
      StudyNotebookSummary summary;
      try {
        summary = await widget.study.updateNotebook(widget.notebookId);
      } on MaterialUnavailableException catch (error) {
        // A chosen file cannot be read now: named, and only left out if
        // the student says so.
        if (!mounted) return;
        if (!await confirmContinueWithout(context, error)) return;
        summary = await widget.study.updateNotebook(
          widget.notebookId,
          skipUnavailable: true,
        );
      }
      widget.onChanged?.call(summary);
      await _load();
    } on MaterialUnavailableException {
      messenger.showMessage(l10n.unavailableTitle);
    } on StudyException catch (error) {
      if (!mounted) return;
      final reason = upgradeReasonFor(error.refusal);
      if (reason != null) {
        await showUpgradePrompt(
          context,
          reason: reason,
          plan: widget.plan,
          needs: StudyPlanTier.plus,
          onUpgrade: widget.onOpenPlans,
        );
        return;
      }
      messenger.showMessage(_refusalText(l10n, error.refusal));
    }
  }

  Future<void> _delete() async {
    final l10n = AppL10n.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final sure = await _confirm(
      title: l10n.nbDeleteTitle,
      body: l10n.nbDeleteBody,
      action: l10n.notebookDelete,
      danger: true,
    );
    if (!sure || !mounted) return;
    try {
      await widget.study.deleteNotebook(widget.notebookId);
      widget.onDeleted?.call(widget.notebookId);
      navigator.pop();
    } on Object {
      messenger.showMessage(l10n.studySetThatDidNotWorkPlease);
    }
  }

  // ---------------------------------------------------------------------
  // Small dialogs.
  // ---------------------------------------------------------------------

  Future<bool> _confirm({
    required String title,
    required String body,
    required String action,
    bool danger = false,
  }) async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(
              MaterialLocalizations.of(dialogContext).cancelButtonLabel,
            ),
          ),
          FilledButton(
            style: danger
                ? FilledButton.styleFrom(backgroundColor: studafyDanger)
                : null,
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(action),
          ),
        ],
      ),
    );
    return sure ?? false;
  }

  /// A line of text from the student, or null when they cancel; '' when
  /// they choose [resetLabel].
  Future<String?> _askText({
    required String title,
    required String label,
    String initial = '',
    int maxLength = 4000,
    bool multiline = false,
    String? resetLabel,
  }) async {
    return showDialog<String>(
      context: context,
      builder: (_) => _TextDialog(
        title: title,
        label: label,
        initial: initial,
        maxLength: maxLength,
        multiline: multiline,
        resetLabel: resetLabel,
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Notes, highlights, own sections.
  // ---------------------------------------------------------------------

  static String _id() =>
      DateTime.now().microsecondsSinceEpoch.toRadixString(36);

  Future<void> _addNote(String key) async {
    final l10n = AppL10n.of(context);
    final text = await _askText(
      title: l10n.nbAddNote,
      label: l10n.nbNoteHint,
      multiline: true,
    );
    if (text == null || text.isEmpty) return;
    _edit(
      (p) => p.copyWith(
        notes: [
          ...p.notes,
          NotebookNote(id: _id(), sectionKey: key, text: text),
        ],
      ),
    );
  }

  Future<void> _editNote(NotebookNote note) async {
    final l10n = AppL10n.of(context);
    final text = await _askText(
      title: l10n.nbEditNote,
      label: l10n.nbNoteHint,
      initial: note.text,
      multiline: true,
    );
    if (text == null) return;
    _edit(
      (p) => p.copyWith(
        notes: [
          for (final n in p.notes)
            if (n.id != note.id)
              n
            else if (text.isNotEmpty)
              NotebookNote(id: n.id, sectionKey: n.sectionKey, text: text),
        ],
      ),
    );
  }

  /// A line pressed: mark it in a colour, or write a note about it.
  Future<void> _lineActions(String key, int index) async {
    final l10n = AppL10n.of(context);
    final current = _local.highlightOf(key, index);
    final names = {
      HighlightColor.yellow: l10n.nbColorYellow,
      HighlightColor.green: l10n.nbColorGreen,
      HighlightColor.blue: l10n.nbColorBlue,
      HighlightColor.pink: l10n.nbColorPink,
    };
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.nbHighlight,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                children: [
                  for (final color in HighlightColor.values)
                    Semantics(
                      button: true,
                      selected: current == color,
                      label: names[color],
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => Navigator.pop(sheetContext, color.name),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: highlightColor(color),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: current == color
                                  ? studafyInk
                                  : studafyHairline,
                              width: current == color ? 2.5 : 1,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (current != null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.format_color_reset_outlined),
                  title: Text(l10n.nbRemoveHighlight),
                  onTap: () => Navigator.pop(sheetContext, 'clear'),
                ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.sticky_note_2_outlined),
                title: Text(l10n.nbAddNote),
                onTap: () => Navigator.pop(sheetContext, 'note'),
              ),
            ],
          ),
        ),
      ),
    );
    if (choice == null || !mounted) return;
    if (choice == 'note') return _addNote(key);
    final color = choice == 'clear'
        ? null
        : HighlightColor.values.firstWhere((c) => c.name == choice);
    _edit((p) => p.withHighlight(key, index, color));
  }

  Future<void> _addSection() async {
    final l10n = AppL10n.of(context);
    final title = await _askText(
      title: l10n.nbAddSection,
      label: l10n.nbSectionTitle,
      maxLength: 160,
    );
    if (title == null || title.isEmpty || !mounted) return;
    final id = _id();
    _edit(
      (p) => p.copyWith(
        sections: [
          ...p.sections,
          NotebookOwnSection(id: id, title: title, body: ''),
        ],
      ),
    );
    // Open it, to write in.
    final index = _buildPages().indexWhere((page) => page.key == 'own:$id');
    if (index >= 0) _jump(index);
  }

  Future<void> _editSection(NotebookOwnSection section) async {
    final l10n = AppL10n.of(context);
    final body = await _askText(
      title: section.title,
      label: l10n.nbSectionBody,
      initial: section.body,
      maxLength: 8000,
      multiline: true,
    );
    if (body == null) return;
    _edit(
      (p) => p.copyWith(
        sections: [
          for (final s in p.sections)
            s.id == section.id
                ? NotebookOwnSection(id: s.id, title: s.title, body: body)
                : s,
        ],
      ),
    );
  }

  Future<void> _renameSection(NotebookOwnSection section) async {
    final l10n = AppL10n.of(context);
    final title = await _askText(
      title: l10n.nbRenameHeading,
      label: l10n.nbSectionTitle,
      initial: section.title,
      maxLength: 160,
    );
    if (title == null || title.isEmpty) return;
    _edit(
      (p) => p.copyWith(
        sections: [
          for (final s in p.sections)
            s.id == section.id
                ? NotebookOwnSection(id: s.id, title: title, body: s.body)
                : s,
        ],
      ),
    );
  }

  Future<void> _deleteSection(NotebookOwnSection section) async {
    final l10n = AppL10n.of(context);
    final sure = await _confirm(
      title: l10n.nbDeleteSection,
      body: section.title,
      action: l10n.notebookDelete,
      danger: true,
    );
    if (!sure) return;
    _edit(
      (p) => p.copyWith(
        sections: [
          for (final s in p.sections)
            if (s.id != section.id) s,
        ],
        notes: [
          for (final n in p.notes)
            if (n.sectionKey != 'own:${section.id}') n,
        ],
      ),
    );
  }

  Future<void> _arrangeSections() async {
    final l10n = AppL10n.of(context);
    var order = List.of(_local.sections);
    final arranged = await showModalBottomSheet<List<NotebookOwnSection>>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheet) => SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(sheetContext).height * .7,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 8),
                  child: Text(
                    l10n.nbArrange,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                Flexible(
                  child: ReorderableListView(
                    shrinkWrap: true,
                    onReorderItem: (from, to) =>
                        setSheet(() => order.insert(to, order.removeAt(from))),
                    children: [
                      for (final section in order)
                        ListTile(
                          key: ValueKey(section.id),
                          leading: const Icon(Icons.drag_indicator_rounded),
                          title: UserContentText(section.title),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: FilledButton(
                    onPressed: () => Navigator.pop(sheetContext, order),
                    child: Text(l10n.notebookSave),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (arranged == null) return;
    order = arranged;
    _edit((p) => p.copyWith(sections: order));
  }

  Future<void> _openSettings() async {
    final notebook = _notebook;
    if (notebook == null) return;
    final settings = await showModalBottomSheet<NotebookSettings>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _SettingsSheet(initial: NotebookSettings.of(notebook)),
    );
    if (settings != null) await _saveSettings(settings);
  }

  // ---------------------------------------------------------------------
  // Practice.
  // ---------------------------------------------------------------------

  Future<void> _practise(StudySetKind kind, List<String> keys) async {
    final notebook = _notebook;
    if (notebook == null) return;
    if (!(widget.plan?.studySetsOn ?? true)) {
      ScaffoldMessenger.of(context)
          .showMessage(AppL10n.of(context).studySetSwitchedOff);
      return;
    }
    if (!(widget.plan?.canMakeStudySets ?? false)) {
      await showUpgradePrompt(
        context,
        reason: UpgradeReason.feature,
        plan: widget.plan,
        needs: StudyPlanTier.max,
        onUpgrade: widget.onOpenPlans,
      );
      return;
    }
    await Navigator.of(context).pushOnce(
      MaterialPageRoute<void>(
        builder: (_) => StudySetPage(
          title: notebook.summary.title,
          kind: kind,
          load: (_) =>
              widget.study.notebookStudySet(widget.notebookId, kind, keys),
          plan: widget.plan,
          onOpenPlans: widget.onOpenPlans,
        ),
      ),
    );
    // A new set is listed on the practice page.
    await _load();
  }

  Future<void> _chooseSections(List<_Page> pages) async {
    final l10n = AppL10n.of(context);
    final choices = [
      for (final page in pages)
        if (page.markable && !page.key.startsWith('own:')) page,
    ];
    final chosen = <String>{};
    final kind = await showModalBottomSheet<StudySetKind>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheet) => SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(sheetContext).height * .8,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 4),
                  child: Text(
                    l10n.nbChooseSectionsTitle,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final page in choices)
                        CheckboxListTile(
                          value: chosen.contains(page.key),
                          controlAffinity: ListTileControlAffinity.leading,
                          title: UserContentText(page.title),
                          onChanged: (on) => setSheet(
                            () => on == true
                                ? chosen.add(page.key)
                                : chosen.remove(page.key),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: FilledButton.tonal(
                          onPressed: chosen.isEmpty
                              ? null
                              : () => Navigator.pop(
                                  sheetContext,
                                  StudySetKind.flashcards,
                                ),
                          child: Text(l10n.nbMakeCards),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: chosen.isEmpty
                              ? null
                              : () => Navigator.pop(
                                  sheetContext,
                                  StudySetKind.quiz,
                                ),
                          child: Text(l10n.nbMakeQuiz),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (kind == null || !mounted) return;
    await _practise(kind, chosen.toList()..sort());
  }

  // ---------------------------------------------------------------------
  // Pages.
  // ---------------------------------------------------------------------

  void _jump(int index) {
    if (!_pages.hasClients) return;
    _pages.animateToPage(
      index,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  List<_Page> _buildPages() {
    final notebook = _notebook!;
    final l10n = AppL10n.of(context);
    final content = notebook.content ?? const NotebookContent();
    final pages = <_Page>[
      _Page('cover', l10n.nbCoverPage, (_) => _cover(), markable: false),
      _Page(
        'contents',
        l10n.nbContents,
        (context) => _contents(_buildPages()),
        markable: false,
      ),
    ];
    void part(String key, String title, List<Widget> Function() body) {
      final heading = _heading(key, title);
      pages.add(_Page(key, heading, (_) => _partPage(key, title, body())));
    }

    if (content.overview case final overview?) {
      part(
        NotebookPart.overview,
        l10n.nbOverview,
        () => [_line(NotebookPart.overview, 0, overview)],
      );
    }
    if (content.objectives.isNotEmpty) {
      part(
        NotebookPart.objectives,
        l10n.nbObjectives,
        () => [
          for (var i = 0; i < content.objectives.length; i++)
            _line(
              NotebookPart.objectives,
              i,
              content.objectives[i],
              bullet: '✓',
            ),
        ],
      );
    }
    if (content.keyTerms.isNotEmpty) {
      part(
        NotebookPart.terms,
        l10n.nbKeyTerms,
        () => [
          for (var i = 0; i < content.keyTerms.length; i++)
            _line(
              NotebookPart.terms,
              i,
              content.keyTerms[i].definition,
              term: content.keyTerms[i].term,
              cite: content.keyTerms[i].cite,
            ),
        ],
      );
    }
    for (final section in content.sections) {
      final lines = [...section.paragraphs, ...section.points];
      part(
        section.key,
        section.heading,
        () => [
          if (section.extra) _extraNote(),
          for (var i = 0; i < lines.length; i++)
            _line(
              section.key,
              i,
              lines[i],
              bullet: i >= section.paragraphs.length ? '•' : null,
            ),
          if (section.cites.isNotEmpty) _cites(section.cites),
        ],
      );
    }
    if (content.examples.isNotEmpty) {
      part(NotebookPart.examples, l10n.nbExamples, () {
        final lines = <Widget>[];
        var index = 0;
        for (final example in content.examples) {
          lines.add(
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 4),
              child: UserContentText(
                example.title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: studafyInk,
                ),
              ),
            ),
          );
          for (var s = 0; s < example.steps.length; s++) {
            lines.add(
              _line(
                NotebookPart.examples,
                index++,
                example.steps[s],
                bullet: '${s + 1}.',
              ),
            );
          }
          if (example.cite case final cite?) lines.add(_cites([cite]));
        }
        return lines;
      });
    }
    if (content.facts.isNotEmpty) {
      part(
        NotebookPart.facts,
        l10n.nbFacts,
        () => [
          for (var i = 0; i < content.facts.length; i++)
            _line(
              NotebookPart.facts,
              i,
              content.facts[i].text,
              bullet: '•',
              cite: content.facts[i].cite,
              extra: content.facts[i].extra,
            ),
        ],
      );
    }
    if (content.mistakes.isNotEmpty) {
      part(
        NotebookPart.mistakes,
        l10n.nbMistakes,
        () => [
          for (var i = 0; i < content.mistakes.length; i++)
            _line(
              NotebookPart.mistakes,
              i,
              content.mistakes[i].text,
              bullet: '!',
              cite: content.mistakes[i].cite,
              extra: content.mistakes[i].extra,
            ),
        ],
      );
    }
    if (content.summary.isNotEmpty) {
      part(
        NotebookPart.summary,
        l10n.nbSummary,
        () => [
          for (var i = 0; i < content.summary.length; i++)
            _line(NotebookPart.summary, i, content.summary[i], bullet: '•'),
        ],
      );
    }
    for (final section in _local.sections) {
      pages.add(
        _Page('own:${section.id}', section.title, (_) => _ownPage(section)),
      );
    }
    pages.add(
      _Page(
        'practice',
        l10n.nbPractice,
        (context) => _practicePage(_buildPages()),
        markable: false,
      ),
    );
    return pages;
  }

  String _pageLabel(int index, int count) =>
      AppL10n.of(context).nbPageOf('${index + 1}', '$count');

  Widget _paper(int index, int count, List<Widget> children) => NotebookPaper(
    style: _notebook!.summary.pageStyle,
    pageLabel: _pageLabel(index, count),
    child: ListView(
      padding: const EdgeInsetsDirectional.fromSTEB(48, 20, 20, 20),
      children: children,
    ),
  );

  Widget _title(String text, {VoidCallback? onRename}) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: UserContentText(
              text,
              style: TextStyle(
                color: notebookColor(_notebook!.summary.color),
                fontSize: 22,
                fontWeight: FontWeight.w800,
                height: 1.25,
              ),
            ),
          ),
        ),
        if (onRename != null)
          IconButton(
            tooltip: AppL10n.of(context).nbRenameHeading,
            visualDensity: VisualDensity.compact,
            onPressed: onRename,
            icon: const Icon(Icons.edit_outlined, size: 18),
          ),
      ],
    ),
  );

  Widget _line(
    String key,
    int index,
    String text, {
    String? bullet,
    String? term,
    NotebookCitation? cite,
    bool extra = false,
  }) {
    final mark = _local.highlightOf(key, index);
    final l10n = AppL10n.of(context);
    return Semantics(
      onLongPressHint: l10n.nbHighlight,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onLongPress: () => _lineActions(key, index),
        child: Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            color: mark == null ? null : highlightColor(mark),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (bullet != null)
                SizedBox(
                  width: 24,
                  child: Text(
                    bullet,
                    style: const TextStyle(
                      color: studafyMuted,
                      fontWeight: FontWeight.w700,
                      height: 1.6,
                    ),
                  ),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (term != null)
                      UserContentText(
                        term,
                        style: const TextStyle(
                          color: studafyInk,
                          fontWeight: FontWeight.w800,
                          height: 1.6,
                        ),
                      ),
                    UserContentText(
                      text,
                      style: const TextStyle(
                        color: studafyInk,
                        fontSize: 15.5,
                        height: 1.6,
                      ),
                    ),
                    if (cite != null || extra)
                      Text(
                        [
                          if (cite != null) _citeText(cite),
                          if (extra) l10n.nbExtraShort,
                        ].join(' · '),
                        style: const TextStyle(
                          color: studafyMuted,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _citeText(NotebookCitation cite) {
    final l10n = AppL10n.of(context);
    if (cite.page case final page?) return l10n.nbCitePage(cite.name, '$page');
    if (cite.slide case final slide?) {
      return l10n.nbCiteSlide(cite.name, '$slide');
    }
    return cite.name;
  }

  Widget _cites(List<NotebookCitation> cites) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.source_outlined, size: 15, color: studafyMuted),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            cites.map(_citeText).join(' · '),
            style: const TextStyle(color: studafyMuted, fontSize: 12.5),
          ),
        ),
      ],
    ),
  );

  Widget _extraNote() => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: StatusPill(
      label: AppL10n.of(context).nbExtra,
      icon: Icons.lightbulb_outline_rounded,
      color: studafyTeal,
    ),
  );

  Widget _notes(String key) {
    final l10n = AppL10n.of(context);
    final notes = _local.notesFor(key);
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final note in notes)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 4, 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7D6),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFF0E2A8)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(
                      Icons.sticky_note_2_outlined,
                      size: 16,
                      color: Color(0xFF8A6D1F),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.nbMyNote,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF8A6D1F),
                          ),
                        ),
                        UserContentText(note.text),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.nbEditNote,
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _editNote(note),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                  ),
                ],
              ),
            ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: () => _addNote(key),
              icon: const Icon(Icons.add_comment_outlined, size: 18),
              label: Text(l10n.nbAddNote),
            ),
          ),
        ],
      ),
    );
  }

  Widget _partPage(String key, String original, List<Widget> body) {
    final pages = _buildPages();
    final index = pages.indexWhere((p) => p.key == key);
    return _paper(index, pages.length, [
      _title(_heading(key, original), onRename: () => _rename(key, original)),
      ...body,
      _notes(key),
    ]);
  }

  Widget _ownPage(NotebookOwnSection section) {
    final l10n = AppL10n.of(context);
    final pages = _buildPages();
    final key = 'own:${section.id}';
    final index = pages.indexWhere((p) => p.key == key);
    return _paper(index, pages.length, [
      _title(section.title, onRename: () => _renameSection(section)),
      StatusPill(
        label: l10n.nbMySection,
        icon: Icons.person_outline_rounded,
        color: studafyMuted,
      ),
      const SizedBox(height: 10),
      if (section.body.isEmpty)
        Text(l10n.nbSectionEmpty, style: const TextStyle(color: studafyMuted))
      else
        UserContentText(
          section.body,
          style: const TextStyle(
            color: studafyInk,
            fontSize: 15.5,
            height: 1.6,
          ),
        ),
      const SizedBox(height: 10),
      Wrap(
        spacing: 8,
        children: [
          FilledButton.tonalIcon(
            onPressed: () => _editSection(section),
            icon: const Icon(Icons.edit_note_rounded, size: 18),
            label: Text(l10n.nbEditSection),
          ),
          TextButton.icon(
            onPressed: () => _deleteSection(section),
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
            label: Text(l10n.nbDeleteSection),
          ),
        ],
      ),
    ]);
  }

  Widget _cover() {
    final notebook = _notebook!;
    final l10n = AppL10n.of(context);
    final summary = notebook.summary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
      child: Column(
        children: [
          Expanded(
            child: NotebookCover(
              title: summary.title,
              subtitle: summary.subtitle,
              color: summary.color,
              icon: summary.icon,
              footer: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  UserContentText(notebook.className),
                  Text(l10n.nbCoverFrom(summary.lessonTitle)),
                  if (notebook.generatedAt case final at?)
                    Text(
                      l10n.nbCoverWritten(
                        MaterialLocalizations.of(context).formatMediumDate(at),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () => _jump(1),
            icon: Icon(forwardChevron(context)),
            label: Text(l10n.nbOpenContents),
          ),
        ],
      ),
    );
  }

  Widget _contents(List<_Page> pages) {
    final l10n = AppL10n.of(context);
    final notebook = _notebook!;
    return _paper(1, pages.length, [
      _title(l10n.nbContents),
      _madeFrom(),
      if (notebook.summary.updateAvailable) _updateBanner(),
      if (notebook.unreadable.isNotEmpty) _unreadable(),
      for (var i = 2; i < pages.length; i++)
        ListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          onTap: () => _jump(i),
          leading: SizedBox(
            width: 28,
            child: Text(
              '${i + 1}',
              style: const TextStyle(
                color: studafyMuted,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          title: UserContentText(
            pages[i].title,
            style: const TextStyle(
              color: studafyInk,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
          trailing: _local.bookmarks.contains(pages[i].key)
              ? Icon(
                  Icons.bookmark_rounded,
                  color: notebookColor(notebook.summary.color),
                  semanticLabel: l10n.nbBookmarked,
                )
              : null,
        ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 6,
        children: [
          OutlinedButton.icon(
            onPressed: _addSection,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text(l10n.nbAddSection),
          ),
          if (_local.sections.length > 1)
            TextButton.icon(
              onPressed: _arrangeSections,
              icon: const Icon(Icons.swap_vert_rounded, size: 18),
              label: Text(l10n.nbArrange),
            ),
        ],
      ),
    ]);
  }

  /// The lesson and exactly what of it this notebook was made from.
  Widget _madeFrom() {
    final l10n = AppL10n.of(context);
    final notebook = _notebook!;
    final chosen = [
      for (final source in notebook.sources)
        if (source.chosen) source.name,
    ];
    final parts = notebook.wholeLesson
        ? [l10n.pickWholeLessonDetail]
        : [if (notebook.includeText) l10n.pickLessonText, ...chosen];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        l10n.madeFrom('${notebook.summary.lessonTitle} (${parts.join(', ')})'),
        style: const TextStyle(color: studafyMuted, fontSize: 12.5),
      ),
    );
  }

  Widget _updateBanner() {
    final l10n = AppL10n.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: studafyWash,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.update_rounded, color: studafyNavy),
          const SizedBox(width: 10),
          Expanded(child: Text(l10n.nbUpdateBanner)),
          TextButton(onPressed: _update, child: Text(l10n.nbUpdate)),
        ],
      ),
    );
  }

  Widget _unreadable() {
    final l10n = AppL10n.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1EF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.nbUnreadableTitle,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          for (final file in _notebook!.unreadable)
            Text('• ${file.name} - ${readingReasonText(l10n, file.reason)}'),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(
              onPressed: _update,
              child: Text(l10n.nbReadAgain),
            ),
          ),
        ],
      ),
    );
  }

  Widget _practicePage(List<_Page> pages) {
    final l10n = AppL10n.of(context);
    final notebook = _notebook!;
    final locked = !(widget.plan?.canMakeStudySets ?? false);
    String scope(NotebookSetSummary set) => set.sectionKeys.isEmpty
        ? l10n.nbSetWhole
        : set.sectionKeys
              .map(
                (key) =>
                    pages
                        .where((p) => p.key == key)
                        .map((p) => p.title)
                        .firstOrNull ??
                    key,
              )
              .join(', ');
    return _paper(pages.length - 1, pages.length, [
      _title(l10n.nbPractice),
      Text(l10n.nbPracticeIntro, style: const TextStyle(color: studafyMuted)),
      if (locked)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: StatusPill(
            label: l10n.nbPracticeLocked,
            icon: Icons.workspace_premium_rounded,
            color: studafyDeep,
          ),
        ),
      const SizedBox(height: 12),
      FilledButton.icon(
        onPressed: () => _practise(StudySetKind.quiz, const []),
        icon: Icon(locked ? Icons.lock_outline_rounded : Icons.quiz_outlined),
        label: Text(l10n.nbQuizWhole),
      ),
      const SizedBox(height: 8),
      FilledButton.tonalIcon(
        onPressed: () => _practise(StudySetKind.flashcards, const []),
        icon: Icon(locked ? Icons.lock_outline_rounded : Icons.style_outlined),
        label: Text(l10n.nbCardsWhole),
      ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: () => _chooseSections(pages),
        icon: const Icon(Icons.checklist_rounded),
        label: Text(l10n.nbChooseSections),
      ),
      if (notebook.sets.isNotEmpty) ...[
        const SizedBox(height: 18),
        Text(
          l10n.nbMadeSets,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        for (final set in notebook.sets)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              set.kind == StudySetKind.quiz
                  ? Icons.quiz_outlined
                  : Icons.style_outlined,
            ),
            title: Text(
              set.kind == StudySetKind.quiz
                  ? l10n.studySetQuiz
                  : l10n.studySetFlashcards,
            ),
            subtitle: UserContentText(
              set.outdated
                  ? '${scope(set)} · ${l10n.nbSetOutdated}'
                  : scope(set),
            ),
            trailing: Icon(forwardChevron(context)),
            onTap: () => _practise(set.kind, set.sectionKeys),
          ),
      ],
    ]);
  }

  // ---------------------------------------------------------------------
  // The screen.
  // ---------------------------------------------------------------------

  String _failureText(AppL10n l10n, String? failure) => switch (failure) {
    'no_readable_material' => l10n.nbFailNoMaterial,
    'material_processing' => l10n.nbSheetWaitReading,
    'allowance_exhausted' || 'monthly_cap' => l10n.nbFailTokens,
    'plan_required' => l10n.nbFailPlan,
    _ => l10n.nbFailGeneric,
  };

  String _refusalText(AppL10n l10n, StudyRefusal refusal) => switch (refusal) {
    StudyRefusal.planRequired => l10n.nbFailPlan,
    StudyRefusal.allowanceUsed => l10n.nbFailTokens,
    StudyRefusal.materialProcessing => l10n.nbSheetWaitReading,
    StudyRefusal.unavailable => l10n.studySetSwitchedOff,
    _ => l10n.studySetThatDidNotWorkPlease,
  };

  Widget _waiting(StudyNotebook notebook) {
    final l10n = AppL10n.of(context);
    final failed = notebook.summary.status == NotebookStatus.failed;
    return ListView(
      padding: const EdgeInsets.all(28),
      children: [
        SizedBox(
          height: 260,
          child: NotebookCover(
            title: notebook.summary.title,
            subtitle: notebook.summary.subtitle,
            color: notebook.summary.color,
            icon: notebook.summary.icon,
          ),
        ),
        const SizedBox(height: 24),
        if (!failed) ...[
          Text(
            l10n.nbWriting,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          const LinearProgressIndicator(),
          const SizedBox(height: 12),
          Text(
            l10n.nbWritingDetail,
            textAlign: TextAlign.center,
            style: const TextStyle(color: studafyMuted),
          ),
        ] else
          StudafyStatusCard(
            icon: Icons.error_outline_rounded,
            title: l10n.nbFailedTitle,
            message: _failureText(l10n, notebook.summary.failure),
            actionLabel: l10n.nbRetry,
            onAction: _update,
          ),
      ],
    );
  }

  Widget _saveState() {
    final l10n = AppL10n.of(context);
    return switch (_saving) {
      _Saving.idle => const SizedBox.shrink(),
      _Saving.saving => Text(
        l10n.nbSaving,
        style: const TextStyle(color: studafyMuted, fontSize: 12.5),
      ),
      _Saving.saved => Text(
        l10n.nbSaved,
        style: const TextStyle(color: studafyMuted, fontSize: 12.5),
      ),
      _Saving.failed => TextButton.icon(
        onPressed: () {
          setState(() => _saving = _Saving.saving);
          unawaited(_flush());
        },
        style: TextButton.styleFrom(foregroundColor: studafyDanger),
        icon: const Icon(Icons.cloud_off_rounded, size: 16),
        label: Text(l10n.nbSaveFailed),
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final notebook = _notebook;
    if (notebook == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: _failed
              ? StudafyEmptyState(
                  icon: Icons.cloud_off_rounded,
                  title: l10n.nbLoadFailed,
                  actionLabel: l10n.nbRetry,
                  onAction: () {
                    setState(() => _failed = false);
                    _load();
                  },
                )
              : const CircularProgressIndicator(),
        ),
      );
    }
    final ready = notebook.content != null;
    final pages = ready ? _buildPages() : const <_Page>[];
    final page = _page.clamp(0, pages.isEmpty ? 0 : pages.length - 1);
    final current = pages.isEmpty ? null : pages[page];
    final marked = current != null && _local.bookmarks.contains(current.key);
    return Scaffold(
      backgroundColor: const Color(0xFFF3F0E8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF3F0E8),
        title: UserContentText(notebook.summary.title),
        actions: [
          if (current != null && current.markable)
            IconButton(
              tooltip: marked ? l10n.nbRemoveBookmark : l10n.nbBookmark,
              onPressed: () => _edit((p) => p.toggleBookmark(current.key)),
              icon: Icon(
                marked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
              ),
            ),
          if (ready)
            IconButton(
              tooltip: l10n.nbContents,
              onPressed: () => _jump(1),
              icon: const Icon(Icons.toc_rounded),
            ),
          PopupMenuButton<String>(
            tooltip: l10n.nbMore,
            onSelected: (choice) => switch (choice) {
              'settings' => _openSettings(),
              'update' => _update(),
              _ => _delete(),
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'settings', child: Text(l10n.nbSettings)),
              if (notebook.summary.status != NotebookStatus.creating)
                PopupMenuItem(value: 'update', child: Text(l10n.nbUpdate)),
              PopupMenuItem(value: 'delete', child: Text(l10n.nbDeleteTitle)),
            ],
          ),
        ],
      ),
      body: !ready
          ? _waiting(notebook)
          : Column(
              children: [
                if (notebook.summary.status == NotebookStatus.creating)
                  const LinearProgressIndicator(),
                if (notebook.summary.status == NotebookStatus.failed)
                  MaterialBanner(
                    content: Text(_failureText(l10n, notebook.summary.failure)),
                    actions: [
                      TextButton(onPressed: _update, child: Text(l10n.nbRetry)),
                    ],
                  ),
                Expanded(
                  child: PageView.builder(
                    controller: _pages,
                    itemCount: pages.length,
                    onPageChanged: (index) => setState(() => _page = index),
                    itemBuilder: (context, index) =>
                        pages[index].build(context),
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(4, 0, 4, 4),
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: l10n.cardsPrevious,
                          onPressed: page == 0 ? null : () => _jump(page - 1),
                          icon: Icon(backChevron(context)),
                        ),
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                _pageLabel(page, pages.length),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              _saveState(),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: l10n.cardsNext,
                          onPressed: page >= pages.length - 1
                              ? null
                              : () => _jump(page + 1),
                          icon: Icon(forwardChevron(context)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

/// A line or a few of text. It owns its controller, so the field is never
/// left holding a disposed one while the dialog animates away.
class _TextDialog extends StatefulWidget {
  const _TextDialog({
    required this.title,
    required this.label,
    required this.initial,
    required this.maxLength,
    required this.multiline,
    this.resetLabel,
  });

  final String title;
  final String label;
  final String initial;
  final int maxLength;
  final bool multiline;
  final String? resetLabel;

  @override
  State<_TextDialog> createState() => _TextDialogState();
}

class _TextDialogState extends State<_TextDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: TextField(
      controller: _controller,
      autofocus: true,
      maxLength: widget.maxLength,
      minLines: widget.multiline ? 4 : 1,
      maxLines: widget.multiline ? 12 : 1,
      decoration: InputDecoration(labelText: widget.label),
    ),
    actions: [
      if (widget.resetLabel case final reset?)
        TextButton(
          onPressed: () => Navigator.pop(context, ''),
          child: Text(reset),
        ),
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _controller.text.trim()),
        child: Text(AppL10n.of(context).notebookSave),
      ),
    ],
  );
}

/// The cover and pages: name, subtitle, colour, icon and paper.
class _SettingsSheet extends StatefulWidget {
  const _SettingsSheet({required this.initial});

  final NotebookSettings initial;

  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  late final _title = TextEditingController(text: widget.initial.title);
  late final _subtitle = TextEditingController(
    text: widget.initial.subtitle ?? '',
  );
  late NotebookColor _color = widget.initial.color;
  late NotebookIcon _icon = widget.initial.icon ?? NotebookIcon.book;
  late NotebookPageStyle _style = widget.initial.pageStyle;

  @override
  void dispose() {
    _title.dispose();
    _subtitle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    Widget label(String text) => Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 8),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w800)),
    );
    return SafeArea(
      child: Padding(
        padding: EdgeInsetsDirectional.fromSTEB(
          16,
          0,
          16,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.nbSettings,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 150,
                child: Center(
                  child: SizedBox(
                    width: 120,
                    child: ListenableBuilder(
                      listenable: Listenable.merge([_title, _subtitle]),
                      builder: (context, _) => NotebookCover(
                        title: _title.text.trim().isEmpty
                            ? widget.initial.title
                            : _title.text,
                        subtitle: _subtitle.text,
                        color: _color,
                        icon: _icon,
                        compact: true,
                      ),
                    ),
                  ),
                ),
              ),
              TextField(
                controller: _title,
                maxLength: 120,
                decoration: InputDecoration(labelText: l10n.nbSettingsTitle),
              ),
              TextField(
                controller: _subtitle,
                maxLength: 160,
                decoration: InputDecoration(labelText: l10n.nbSettingsSubtitle),
              ),
              label(l10n.nbColor),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final color in NotebookColor.values)
                    Semantics(
                      button: true,
                      selected: color == _color,
                      label: color.name,
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => setState(() => _color = color),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: notebookColor(color),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: color == _color
                                  ? studafyInk
                                  : Colors.transparent,
                              width: 3,
                            ),
                          ),
                          child: color == _color
                              ? const Icon(
                                  Icons.check_rounded,
                                  color: Colors.white,
                                  size: 18,
                                )
                              : null,
                        ),
                      ),
                    ),
                ],
              ),
              label(l10n.nbIcon),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final icon in NotebookIcon.values)
                    ChoiceChip(
                      selected: icon == _icon,
                      onSelected: (_) => setState(() => _icon = icon),
                      label: Icon(notebookIcon(icon), size: 20),
                      tooltip: icon.name,
                      showCheckmark: false,
                    ),
                ],
              ),
              label(l10n.nbPageStyle),
              SegmentedButton<NotebookPageStyle>(
                segments: [
                  ButtonSegment(
                    value: NotebookPageStyle.lined,
                    label: Text(l10n.nbLined),
                    icon: const Icon(Icons.notes_rounded),
                  ),
                  ButtonSegment(
                    value: NotebookPageStyle.plain,
                    label: Text(l10n.nbPlain),
                    icon: const Icon(Icons.crop_portrait_rounded),
                  ),
                  ButtonSegment(
                    value: NotebookPageStyle.grid,
                    label: Text(l10n.nbGrid),
                    icon: const Icon(Icons.grid_4x4_rounded),
                  ),
                ],
                selected: {_style},
                onSelectionChanged: (s) => setState(() => _style = s.first),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () {
                  final title = _title.text.trim();
                  Navigator.pop(
                    context,
                    widget.initial.copyWith(
                      title: title.isEmpty ? widget.initial.title : title,
                      subtitle: _subtitle.text.trim(),
                      clearSubtitle: _subtitle.text.trim().isEmpty,
                      color: _color,
                      icon: _icon,
                      pageStyle: _style,
                    ),
                  );
                },
                child: Text(l10n.notebookSave),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
