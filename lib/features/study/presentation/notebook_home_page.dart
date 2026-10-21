import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/attachment_field.dart';
import '../../../core/attachment_policy.dart';
import '../../../core/feedback.dart';
import '../../../core/inline_photo.dart';
import '../../../core/navigation.dart';
import '../../../core/studafy_components.dart';
import '../../../core/studafy_design.dart';
import '../../../core/user_content_text.dart';
import '../../../l10n/generated/app_l10n.dart';
import '../domain/study.dart';
import 'note_page.dart';
import 'notebook_paper.dart';
import 'practice_page.dart';
import 'upgrade_prompt.dart';

/// Above this width the Notebook shows the page list and the open page side
/// by side, like an open notebook.
const _twoPane = 840.0;

/// One notebook: the student's personal one, or a class's.
class _Book {
  const _Book({
    required this.classroomId,
    required this.name,
    required this.entries,
    this.gone = false,
  });

  /// Null for the personal notebook.
  final String? classroomId;
  final String name;
  final List<NotebookEntry> entries;
  final bool gone;

  bool get personal => classroomId == null;
}

/// The Notebook (ADR-0045): every notebook the student has - their personal
/// one, which belongs to no class, and one for each class they write in -
/// as a list of pages, each opening on ruled paper.
///
/// Typed notes are free for everyone. Notes from a photo or screenshot are
/// Studafy Plus: the action is shown to every student, marked Plus, and
/// explains the plan before anything is picked rather than failing after.
class NotebookHomePage extends StatefulWidget {
  const NotebookHomePage({
    super.key,
    required this.study,
    this.pickPhoto,
    this.onOpenPlans,
    this.onBack,
    this.inClass = false,
  });

  final StudyRepository study;

  /// The photo picker; null hides notes from a photo.
  final AttachmentSource? pickPhoto;
  final Future<void> Function()? onOpenPlans;

  /// Set where the Notebook is opened over another page.
  final VoidCallback? onBack;

  /// The student is in a class (for the practice page's footnote).
  final bool inClass;

  @override
  State<NotebookHomePage> createState() => _NotebookHomePageState();
}

class _NotebookHomePageState extends State<NotebookHomePage> {
  List<_Book>? _books;
  bool _failed = false;
  StudyPlan? _plan;
  int _book = 0;
  String? _open;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() => _failed = false);
    StudyPlan? plan;
    try {
      plan = await widget.study.plan();
    } on Object {
      plan = null;
    }
    List<NotebookEntry> personal;
    try {
      personal = await widget.study.personalNotebook();
    } on Object {
      if (mounted) setState(() => _failed = true);
      return;
    }
    List<NotebookGroup> classes;
    try {
      classes = await widget.study.myNotebooks();
    } on Object {
      // The class notebooks are shown where they can be; the personal one
      // is never held back by them.
      classes = const [];
    }
    if (!mounted) return;
    final l10n = AppL10n.of(context);
    setState(() {
      _plan = plan;
      _books = [
        _Book(classroomId: null, name: l10n.nbPersonal, entries: personal),
        for (final group in classes)
          _Book(
            classroomId: group.classroomId,
            name: group.className,
            entries: group.entries,
            gone: group.classGone,
          ),
      ];
      if (_book >= _books!.length) _book = 0;
    });
  }

  _Book? get _current => _books?[_book];

  bool get _photoOn =>
      widget.pickPhoto != null && (_plan?.whiteboardOn ?? false);

  Future<void> _openPlans() async {
    await widget.onOpenPlans?.call();
    // A plan bought there unlocks what is shown here.
    await _load();
  }

  void _replace(NotebookEntry entry) {
    final books = _books;
    if (books == null) return;
    setState(() {
      _books = [
        for (final book in books)
          _Book(
            classroomId: book.classroomId,
            name: book.name,
            gone: book.gone,
            entries: [
              for (final e in book.entries) e.id == entry.id ? entry : e,
            ],
          ),
      ];
    });
  }

  void _removed(String id) {
    final books = _books;
    if (books == null) return;
    setState(() {
      if (_open == id) _open = null;
      _books = [
        for (final book in books)
          _Book(
            classroomId: book.classroomId,
            name: book.name,
            gone: book.gone,
            entries: [
              for (final e in book.entries)
                if (e.id != id) e,
            ],
          ),
      ];
    });
  }

  void _added(NotebookEntry entry, {required bool wide}) {
    final books = _books;
    if (books == null) return;
    final index = books.indexWhere((b) => b.classroomId == entry.classroomId);
    if (index < 0) return;
    setState(() {
      _book = index;
      _books = [
        for (final (i, book) in books.indexed)
          i == index
              ? _Book(
                  classroomId: book.classroomId,
                  name: book.name,
                  gone: book.gone,
                  entries: [entry, ...book.entries],
                )
              : book,
      ];
      if (wide) _open = entry.id;
    });
  }

  Future<void> _newNote({required bool wide}) async {
    final book = _current;
    if (book == null) return;
    final saved = await Navigator.of(context).pushOnce<NotebookEntry>(
      MaterialPageRoute<NotebookEntry>(
        builder: (_) => NoteEditorPage(
          save: (title, body) => book.personal
              ? widget.study.addPersonalNote(title: title, body: body)
              : widget.study.addNote(
                  book.classroomId!,
                  title: title,
                  body: body,
                ),
        ),
      ),
    );
    if (saved == null || !mounted) return;
    _added(saved, wide: wide);
  }

  Future<void> _fromPhoto({required bool wide}) async {
    final pick = widget.pickPhoto;
    if (pick == null) return;
    final entry = await notesFromPhoto(
      context,
      study: widget.study,
      pickPhoto: pick,
      plan: _plan,
      onOpenPlans: _openPlans,
    );
    if (entry == null || !mounted) return;
    _added(entry, wide: wide);
    if (!wide) await _openEntry(entry);
  }

  void _practise(NotebookEntry entry) {
    Navigator.of(context).pushOnce(
      MaterialPageRoute<void>(
        builder: (_) => PracticePage(
          study: widget.study,
          preselected: [entry.id],
          onOpenPlans: widget.onOpenPlans == null ? null : _openPlans,
          inClass: widget.inClass,
        ),
      ),
    );
  }

  Future<void> _openEntry(NotebookEntry entry) =>
      Navigator.of(context).pushOnce(
        MaterialPageRoute<void>(
          builder: (_) => NotePage(
            study: widget.study,
            entry: entry,
            onChanged: _replace,
            onDeleted: () => _removed(entry.id),
            onPractise: (plan) => _practise(plan),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return Scaffold(
      backgroundColor: studafyCanvas,
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= _twoPane;
            final list = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                StudafyLargeTitle(
                  leading: switch (widget.onBack) {
                    final back? => BackButton(onPressed: back),
                    null => null,
                  },
                  title: l10n.todayToolNotebook,
                  subtitle: l10n.nbHomeSubtitle,
                ),
                Expanded(child: _listBody(l10n, wide: wide)),
              ],
            );
            if (!wide) return list;
            final open = _openEntryIn(_current);
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(width: 380, child: list),
                const VerticalDivider(width: 1, color: studafyHairline),
                Expanded(
                  child: open == null
                      ? Center(
                          child: Text(
                            l10n.nbChoosePage,
                            style: const TextStyle(color: studafyMuted),
                          ),
                        )
                      : NotePage(
                          key: ValueKey(open.id),
                          study: widget.study,
                          entry: open,
                          embedded: true,
                          onChanged: _replace,
                          onDeleted: () => _removed(open.id),
                          onPractise: _practise,
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  NotebookEntry? _openEntryIn(_Book? book) {
    final id = _open;
    if (book == null || id == null) return null;
    for (final entry in book.entries) {
      if (entry.id == id) return entry;
    }
    return null;
  }

  Widget _listBody(AppL10n l10n, {required bool wide}) {
    final books = _books;
    if (_failed) {
      return StudafyEmptyState(
        icon: Icons.wifi_off_rounded,
        title: l10n.noteLoadFailed,
        actionLabel: l10n.todayRetry,
        onAction: _load,
      );
    }
    if (books == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final book = books[_book];
    final plus = _plan?.canSnapWhiteboard ?? false;
    final free = _plan != null && !plus;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 32),
        children: [
          if (books.length > 1)
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final (i, b) in books.indexed)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 8),
                      child: ChoiceChip(
                        avatar: Icon(
                          b.personal
                              ? Icons.edit_note_rounded
                              : Icons.class_outlined,
                          size: 18,
                        ),
                        label: UserContentText(b.name, maxLines: 1),
                        selected: i == _book,
                        onSelected: (_) => setState(() {
                          _book = i;
                          _open = null;
                        }),
                      ),
                    ),
                ],
              ),
            ),
          _Cover(book: book),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (!book.gone)
                FilledButton.icon(
                  onPressed: () => _newNote(wide: wide),
                  icon: const Icon(Icons.edit_outlined),
                  label: Text(l10n.nbNewNote),
                ),
              if (book.personal && _photoOn)
                OutlinedButton.icon(
                  onPressed: () => _fromPhoto(wide: wide),
                  icon: const Icon(Icons.document_scanner_outlined),
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          l10n.nbFromPhoto,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!plus) ...[
                        const SizedBox(width: 6),
                        const PlanBadge(StudyPlanTier.plus),
                      ],
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (book.entries.isEmpty)
            _Empty(
              personal: book.personal,
              onWrite: book.gone ? null : () => _newNote(wide: wide),
            )
          else
            for (final entry in book.entries)
              _PageTile(
                entry: entry,
                selected: wide && entry.id == _open,
                onTap: () =>
                    wide ? setState(() => _open = entry.id) : _openEntry(entry),
              ),
          if (free && book.personal && _photoOn)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: _PlusCard(
                onOpenPlans: widget.onOpenPlans == null ? null : _openPlans,
              ),
            ),
        ],
      ),
    );
  }
}

/// The notebook's cover strip: its name, how many pages, and for the
/// personal one, that it belongs to no class.
class _Cover extends StatelessWidget {
  const _Cover({required this.book});

  final _Book book;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final detail = book.gone
        ? l10n.notebookClassGone
        : book.personal
        ? l10n.nbPersonalDetail
        : null;
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(14, 14, 14, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: book.personal
              ? const [studafyNavy, studafyIndigo]
              : const [studafyTeal, studafySteel],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          // The spine: what makes it read as a notebook at a glance.
          Container(
            width: 8,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .35),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UserContentText(
                  book.name,
                  maxLines: 1,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  [l10n.nbPages(book.entries.length), ?detail].join(' · '),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .85),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.menu_book_rounded, color: Colors.white),
        ],
      ),
    );
  }
}

/// One page in the list: its title, when it changed, the start of it.
class _PageTile extends StatelessWidget {
  const _PageTile({
    required this.entry,
    required this.onTap,
    this.selected = false,
  });

  final NotebookEntry entry;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final snippet = noteSnippet(entry.body);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: selected
            ? Color.alphaBlend(
                studafyNavy.withValues(alpha: .06),
                notebookPaper,
              )
            : notebookPaper,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: selected ? studafyNavy : const Color(0xFFEDE6D6),
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 8, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      UserContentText(
                        entry.title,
                        maxLines: 1,
                        style: const TextStyle(
                          color: studafyInk,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Wrap(
                        spacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            noteDateLine(context, entry),
                            style: const TextStyle(
                              color: studafyMuted,
                              fontSize: 12.5,
                            ),
                          ),
                          NoteSourceBadge(entry),
                        ],
                      ),
                      if (snippet.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        UserContentText(
                          snippet,
                          maxLines: 2,
                          style: const TextStyle(
                            color: studafyInk,
                            fontSize: 13.5,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(forwardChevron(context), color: studafyMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.personal, this.onWrite});

  final bool personal;
  final VoidCallback? onWrite;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return RuledPage(
      child: Column(
        children: [
          const IconBadge(icon: Icons.edit_note_rounded, size: 56),
          const SizedBox(height: 14),
          Text(
            l10n.nbEmptyTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: studafyInk,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            personal ? l10n.nbEmptyBody : l10n.notebookYourNotebookForThisClass,
            textAlign: TextAlign.center,
            style: const TextStyle(color: studafyMuted, height: 1.45),
          ),
          if (onWrite != null) ...[
            const SizedBox(height: 14),
            FilledButton(onPressed: onWrite, child: Text(l10n.nbWriteFirst)),
          ],
        ],
      ),
    );
  }
}

/// What Studafy Plus adds to the Notebook, said once, under the pages.
class _PlusCard extends StatelessWidget {
  const _PlusCard({this.onOpenPlans});

  final Future<void> Function()? onOpenPlans;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return FeatureCard(
      tint: studafyTeal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const PlanBadge(StudyPlanTier.plus),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.nbPlusTitle,
                  style: const TextStyle(
                    color: studafyInk,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            l10n.nbPlusBody,
            style: const TextStyle(color: studafyMuted, height: 1.4),
          ),
          if (onOpenPlans != null)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                onPressed: () => unawaited(onOpenPlans!()),
                child: Text(l10n.nbSeePlans),
              ),
            ),
        ],
      ),
    );
  }
}

/// Studafy Plus: a photo or screenshot into a note in the personal
/// notebook (ADR-0045). The plan is explained before anything is picked; a
/// photo the server cannot use, one with nothing to read, and a failure
/// are each said plainly. Returns the note, or null.
///
/// The photo is sent with the request and is not kept, so a student with no
/// class can use it too.
Future<NotebookEntry?> notesFromPhoto(
  BuildContext context, {
  required StudyRepository study,
  required AttachmentSource pickPhoto,
  required StudyPlan? plan,
  Future<void> Function()? onOpenPlans,
  AttachmentKind kind = AttachmentKind.photo,
}) async {
  final l10n = AppL10n.of(context);
  final messenger = ScaffoldMessenger.of(context);
  Future<void> upgrade(UpgradeReason reason, StudyPlan? current) =>
      showUpgradePrompt(
        context,
        reason: reason,
        plan: current,
        needs: StudyPlanTier.plus,
        onUpgrade: () {
          if (onOpenPlans != null) unawaited(onOpenPlans());
        },
      );
  if (plan != null && !plan.canSnapWhiteboard) {
    await upgrade(UpgradeReason.feature, plan);
    return null;
  }
  final picked = await pickPhoto(kind, AttachmentPolicy.assistantAttachment);
  if (picked == null || !context.mounted) return null;
  final photo = InlinePhoto(mediaType: picked.mediaType, bytes: picked.bytes);
  if (photo.problem != null) {
    messenger.showMessage(l10n.nbPhotoRejected);
    return null;
  }
  final navigator = Navigator.of(context);
  unawaited(
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              const SizedBox.square(
                dimension: 28,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Semantics(
                  liveRegion: true,
                  child: Text(l10n.notebookMakingNotes),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  NotebookEntry? entry;
  StudyRefusal? refusal;
  try {
    entry = await study.photoNote(photo);
  } on StudyException catch (error) {
    refusal = error.refusal;
  } on Object {
    refusal = StudyRefusal.failed;
  }
  navigator.pop();
  if (!context.mounted) return null;
  if (entry != null) {
    messenger.showMessage(l10n.nbNoteSavedOpen);
    return entry;
  }
  switch (refusal) {
    case StudyRefusal.planRequired || StudyRefusal.allowanceUsed:
      StudyPlan? current;
      try {
        current = await study.plan();
      } on Object {
        current = plan;
      }
      if (!context.mounted) return null;
      await upgrade(upgradeReasonFor(refusal!)!, current);
    case StudyRefusal.photoUnreadable:
      messenger.showMessage(l10n.notebookNoWritingCouldBeRead);
    case StudyRefusal.photoRejected:
      messenger.showMessage(l10n.nbPhotoRejected);
    case StudyRefusal.aiConsent:
      messenger.showMessage(l10n.aiConsentNeeded);
    case StudyRefusal.unavailable:
      messenger.showMessage(l10n.studySetSwitchedOff);
    default:
      messenger.showMessage(l10n.setFailed);
  }
  return null;
}
