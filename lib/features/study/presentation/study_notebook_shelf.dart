import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/feedback.dart';
import '../../../core/navigation.dart';
import '../../../core/studafy_components.dart';
import '../../../core/studafy_design.dart';
import '../../../core/user_content_text.dart';
import '../../../l10n/generated/app_l10n.dart';
import '../domain/study.dart';
import '../domain/study_notebook.dart';
import 'notebook_cover.dart';
import 'study_notebook_page.dart';
import 'upgrade_prompt.dart';

/// A class's study notebooks, shared by the lesson buttons and the shelf so
/// both show the same state. While one is being written it asks again every
/// few seconds, and stops when none is.
class NotebookTracker extends ChangeNotifier {
  NotebookTracker({
    required this.repository,
    required this.classroomId,
    this.poll = const Duration(seconds: 3),
  });

  final StudyNotebookRepository repository;
  final String classroomId;
  final Duration poll;

  List<StudyNotebookSummary>? _items;
  bool _failed = false;
  Timer? _timer;
  bool _disposed = false;

  /// Null until the first load.
  List<StudyNotebookSummary>? get items => _items;
  bool get failed => _failed;

  Future<void> load() async {
    _timer?.cancel();
    try {
      final items = await repository.notebooks(classroomId);
      if (_disposed) return;
      _items = items;
      _failed = false;
    } on Object {
      if (_disposed) return;
      _failed = _items == null;
    }
    notifyListeners();
    _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    if (_disposed) return;
    if (_items?.any((n) => n.status == NotebookStatus.creating) ?? false) {
      _timer = Timer(poll, load);
    }
  }

  /// The lesson's newest notebook, or null.
  StudyNotebookSummary? latestFor(String resourceId) {
    StudyNotebookSummary? latest;
    for (final item in _items ?? const <StudyNotebookSummary>[]) {
      if (item.resourceId != resourceId) continue;
      if (latest == null || item.updatedAt.isAfter(latest.updatedAt)) {
        latest = item;
      }
    }
    return latest;
  }

  /// A notebook as the server last described it.
  void put(StudyNotebookSummary summary) {
    _items = [
      summary,
      for (final item in _items ?? const <StudyNotebookSummary>[])
        if (item.id != summary.id) item,
    ];
    notifyListeners();
    _schedule();
  }

  void remove(String id) {
    _items = [
      for (final item in _items ?? const <StudyNotebookSummary>[])
        if (item.id != id) item,
    ];
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}

/// What making and opening notebooks needs from the class page.
class NotebookHost {
  const NotebookHost({
    required this.study,
    required this.tracker,
    required this.className,
    required this.plan,
    required this.onOpenPlans,
    required this.loadSources,
  });

  final StudyRepository study;
  final NotebookTracker tracker;

  /// The class, as the create sheet names it.
  final String className;

  /// The caller's plan, when known.
  final StudyPlan? Function() plan;
  final VoidCallback onOpenPlans;

  /// A lesson's files and links and how far each has been read.
  final Future<List<NotebookSourceChoice>> Function(String resourceId)
  loadSources;

  bool get _locked => !(plan()?.canSnapWhiteboard ?? true);

  Future<void> _upgrade(BuildContext context, UpgradeReason reason) =>
      showUpgradePrompt(
        context,
        reason: reason,
        plan: plan(),
        needs: StudyPlanTier.plus,
        onUpgrade: onOpenPlans,
      );

  /// Asks which of the lesson's material to use, then starts the notebook.
  Future<void> create(
    BuildContext context, {
    required String resourceId,
    required String lessonTitle,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppL10n.of(context);
    if (!(plan()?.notebooksOn ?? true)) {
      messenger.showMessage(l10n.studySetSwitchedOff);
      return;
    }
    if (_locked) {
      await _upgrade(context, UpgradeReason.feature);
      return;
    }
    final request = await showCreateNotebookSheet(
      context,
      className: className,
      lessonTitle: lessonTitle,
      sources: loadSources(resourceId),
    );
    if (request == null || !context.mounted) return;
    try {
      final summary = await study.createNotebook(
        tracker.classroomId,
        resourceId: resourceId,
        sourceIds: request.sourceIds,
        title: request.title,
      );
      tracker.put(summary);
      messenger.showMessage(l10n.nbStarted);
    } on StudyException catch (error) {
      if (!context.mounted) return;
      final reason = upgradeReasonFor(error.refusal);
      if (reason != null) {
        await _upgrade(context, reason);
        return;
      }
      messenger.showMessage(notebookRefusalText(l10n, error.refusal));
    }
  }

  Future<void> open(BuildContext context, StudyNotebookSummary summary) async {
    await Navigator.of(context).pushOnce(
      MaterialPageRoute<void>(
        builder: (_) => StudyNotebookPage(
          study: study,
          notebookId: summary.id,
          plan: plan(),
          onOpenPlans: onOpenPlans,
          onChanged: tracker.put,
          onDeleted: tracker.remove,
        ),
      ),
    );
  }

  /// Writes the AI part again from the lesson as it is now.
  Future<void> update(
    BuildContext context,
    StudyNotebookSummary summary,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppL10n.of(context);
    final sure = await confirmNotebookUpdate(context);
    if (!sure || !context.mounted) return;
    try {
      tracker.put(await study.updateNotebook(summary.id));
      messenger.showMessage(l10n.nbStarted);
    } on StudyException catch (error) {
      if (!context.mounted) return;
      final reason = upgradeReasonFor(error.refusal);
      if (reason != null) {
        await _upgrade(context, reason);
        return;
      }
      messenger.showMessage(notebookRefusalText(l10n, error.refusal));
    }
  }
}

/// "Update this notebook?": the student's own part is kept.
Future<bool> confirmNotebookUpdate(BuildContext context) async {
  final l10n = AppL10n.of(context);
  final sure = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.nbUpdateConfirmTitle),
      content: Text(l10n.nbUpdateConfirmBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(
            MaterialLocalizations.of(dialogContext).cancelButtonLabel,
          ),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(l10n.nbUpdate),
        ),
      ],
    ),
  );
  return sure ?? false;
}

String notebookRefusalText(AppL10n l10n, StudyRefusal refusal) =>
    switch (refusal) {
      StudyRefusal.planRequired => l10n.nbFailPlan,
      StudyRefusal.allowanceUsed => l10n.nbFailTokens,
      StudyRefusal.materialProcessing => l10n.nbSheetWaitReading,
      StudyRefusal.lessonHasNoText => l10n.nbFailNoMaterial,
      StudyRefusal.unavailable => l10n.studySetSwitchedOff,
      _ => l10n.studySetThatDidNotWorkPlease,
    };

/// The notebook button under a lesson: "Create notebook", "Creating…",
/// "Open notebook" - with "Update available" when the lesson has changed -
/// and, once there is one, a menu to update it or make another version.
class LessonNotebookButton extends StatelessWidget {
  const LessonNotebookButton({
    super.key,
    required this.host,
    required this.resourceId,
    required this.lessonTitle,
  });

  final NotebookHost host;
  final String resourceId;
  final String lessonTitle;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: host.tracker,
    builder: (context, _) {
      final l10n = AppL10n.of(context);
      final latest = host.tracker.latestFor(resourceId);
      final locked = host._locked;
      void create() => host.create(
        context,
        resourceId: resourceId,
        lessonTitle: lessonTitle,
      );

      if (latest == null ||
          (latest.status == NotebookStatus.failed && !latest.hasContent)) {
        return Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilledButton.tonalIcon(
              onPressed: create,
              icon: Icon(
                locked
                    ? Icons.lock_outline_rounded
                    : Icons.auto_stories_rounded,
                size: 18,
              ),
              label: Text(l10n.nbCreate),
            ),
            if (latest != null)
              StatusPill(
                label: l10n.nbFailedShort,
                icon: Icons.error_outline_rounded,
                color: studafyDanger,
              ),
          ],
        );
      }
      if (latest.status == NotebookStatus.creating) {
        return FilledButton.tonalIcon(
          onPressed: () => host.open(context, latest),
          icon: const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          label: Text(l10n.nbCreating),
        );
      }
      return Wrap(
        spacing: 6,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          FilledButton.tonalIcon(
            onPressed: () => host.open(context, latest),
            icon: const Icon(Icons.auto_stories_rounded, size: 18),
            label: Text(l10n.nbOpen),
          ),
          if (latest.updateAvailable)
            ActionChip(
              avatar: const Icon(Icons.update_rounded, size: 16),
              label: Text(l10n.nbUpdateAvailable),
              onPressed: () => host.update(context, latest),
              visualDensity: VisualDensity.compact,
            ),
          PopupMenuButton<String>(
            tooltip: l10n.nbMore,
            icon: const Icon(Icons.more_horiz_rounded),
            onSelected: (choice) =>
                choice == 'update' ? host.update(context, latest) : create(),
            itemBuilder: (_) => [
              PopupMenuItem(value: 'update', child: Text(l10n.nbUpdate)),
              PopupMenuItem(value: 'new', child: Text(l10n.nbNewVersion)),
            ],
          ),
        ],
      );
    },
  );
}

/// The class's notebooks as covers on a shelf, above the class notebook's
/// own notes.
class StudyNotebookShelf extends StatelessWidget {
  const StudyNotebookShelf({super.key, required this.host});

  final NotebookHost host;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: host.tracker,
    builder: (context, _) {
      final l10n = AppL10n.of(context);
      final items = host.tracker.items;
      final Widget body;
      if (items == null) {
        body = host.tracker.failed
            ? TextButton.icon(
                onPressed: host.tracker.load,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(l10n.nbShelfFailed),
              )
            : const Padding(
                padding: EdgeInsets.all(12),
                child: Center(child: CircularProgressIndicator()),
              );
      } else if (items.isEmpty) {
        body = Text(
          host._locked ? l10n.nbShelfLocked : l10n.nbShelfEmpty,
          style: const TextStyle(color: studafyMuted, fontSize: 13),
        );
      } else {
        body = SizedBox(
          height: 176,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, i) => _ShelfCover(
              summary: items[i],
              onTap: () => host.open(context, items[i]),
            ),
          ),
        );
      }
      return Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader(
              l10n.nbShelfTitle,
              padding: const EdgeInsetsDirectional.fromSTEB(0, 4, 0, 8),
            ),
            body,
          ],
        ),
      );
    },
  );
}

class _ShelfCover extends StatelessWidget {
  const _ShelfCover({required this.summary, required this.onTap});

  final StudyNotebookSummary summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final state = switch (summary.status) {
      NotebookStatus.creating => l10n.nbCreating,
      NotebookStatus.failed when !summary.hasContent => l10n.nbFailedShort,
      _ when summary.updateAvailable => l10n.nbUpdateAvailable,
      _ => null,
    };
    return Semantics(
      button: true,
      label: [summary.title, ?state].join('. '),
      child: SizedBox(
        width: 128,
        child: StudafyPressable(
          child: GestureDetector(
            onTap: onTap,
            child: NotebookCover(
              title: summary.title,
              subtitle: summary.subtitle,
              color: summary.color,
              icon: summary.icon,
              compact: true,
              footer: state == null
                  ? null
                  : Row(
                      children: [
                        if (summary.status == NotebookStatus.creating)
                          const Padding(
                            padding: EdgeInsetsDirectional.only(end: 6),
                            child: SizedBox(
                              width: 10,
                              height: 10,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.6,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        Flexible(
                          child: Text(
                            state,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// What the student chose in the create sheet.
@immutable
class NotebookCreateRequest {
  const NotebookCreateRequest({required this.sourceIds, this.title});

  /// Empty for the whole lesson.
  final List<String> sourceIds;
  final String? title;
}

/// Before a notebook is made: the class and lesson it is from, its files
/// and links with how far each has been read, and - unless the whole lesson
/// is used - which of them to make it from.
Future<NotebookCreateRequest?> showCreateNotebookSheet(
  BuildContext context, {
  required String className,
  required String lessonTitle,
  required Future<List<NotebookSourceChoice>> sources,
}) => showModalBottomSheet<NotebookCreateRequest>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => _CreateNotebookSheet(
    className: className,
    lessonTitle: lessonTitle,
    sources: sources,
  ),
);

class _CreateNotebookSheet extends StatefulWidget {
  const _CreateNotebookSheet({
    required this.className,
    required this.lessonTitle,
    required this.sources,
  });

  final String className;
  final String lessonTitle;
  final Future<List<NotebookSourceChoice>> sources;

  @override
  State<_CreateNotebookSheet> createState() => _CreateNotebookSheetState();
}

class _CreateNotebookSheetState extends State<_CreateNotebookSheet> {
  late final _title = TextEditingController(text: widget.lessonTitle);
  List<NotebookSourceChoice>? _sources;
  bool _failed = false;
  bool _whole = true;
  final _chosen = <String>{};

  @override
  void initState() {
    super.initState();
    _load(widget.sources);
  }

  Future<void> _load(Future<List<NotebookSourceChoice>> sources) async {
    try {
      final list = await sources;
      if (!mounted) return;
      setState(() {
        _sources = list;
        _chosen
          ..clear()
          ..addAll([
            for (final s in list)
              if (s.ready) s.id,
          ]);
      });
    } on Object {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  String? get _problem {
    final sources = _sources ?? const <NotebookSourceChoice>[];
    final l10n = AppL10n.of(context);
    if (_whole) {
      return sources.any((s) => s.processing) ? l10n.nbSheetWaitReading : null;
    }
    if (_chosen.isEmpty) return l10n.nbSheetPickOne;
    return null;
  }

  void _submit() {
    if (_problem != null) return;
    final title = _title.text.trim();
    Navigator.pop(
      context,
      NotebookCreateRequest(
        sourceIds: _whole ? const [] : _chosen.toList(),
        title: title.isEmpty || title == widget.lessonTitle ? null : title,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final sources = _sources;
    final problem = sources == null ? null : _problem;
    Widget fact(String label, String value) => Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(label, style: const TextStyle(color: studafyMuted)),
          ),
          Expanded(
            child: UserContentText(
              value,
              style: const TextStyle(
                color: studafyInk,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    return SafeArea(
      child: Padding(
        padding: EdgeInsetsDirectional.fromSTEB(
          16,
          0,
          16,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .85,
          ),
          child: ListView(
            shrinkWrap: true,
            children: [
              Text(
                l10n.nbSheetTitle,
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              fact(l10n.nbSheetClass, widget.className),
              fact(l10n.nbSheetLesson, widget.lessonTitle),
              const SizedBox(height: 8),
              TextField(
                controller: _title,
                maxLength: 120,
                decoration: InputDecoration(labelText: l10n.nbSheetName),
              ),
              Text(
                l10n.nbSheetSources,
                style: const TextStyle(
                  color: studafyInk,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              if (sources == null)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: _failed
                        ? Text(l10n.readingLoadFailed)
                        : const CircularProgressIndicator(),
                  ),
                )
              else ...[
                RadioGroup<bool>(
                  groupValue: _whole,
                  onChanged: (value) => setState(() => _whole = value ?? true),
                  child: Column(
                    children: [
                      RadioListTile<bool>(
                        value: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(l10n.nbSheetWhole),
                        subtitle: Text(
                          sources.isEmpty
                              ? l10n.nbSheetNoFiles
                              : l10n.nbSheetWholeDetail,
                        ),
                      ),
                      if (sources.isNotEmpty)
                        RadioListTile<bool>(
                          value: false,
                          contentPadding: EdgeInsets.zero,
                          title: Text(l10n.nbSheetChoose),
                        ),
                    ],
                  ),
                ),
                for (final source in sources)
                  CheckboxListTile(
                    contentPadding: const EdgeInsetsDirectional.only(start: 8),
                    controlAffinity: ListTileControlAffinity.leading,
                    value: _whole ? source.ready : _chosen.contains(source.id),
                    onChanged: _whole || !source.ready
                        ? null
                        : (on) => setState(
                            () => on == true
                                ? _chosen.add(source.id)
                                : _chosen.remove(source.id),
                          ),
                    secondary: Icon(
                      source.isLink
                          ? Icons.link_rounded
                          : Icons.insert_drive_file_outlined,
                    ),
                    title: UserContentText(source.name),
                    subtitle: source.ready
                        ? null
                        : Text(
                            source.processing
                                ? l10n.nbSourceReading
                                : l10n.nbSourceUnreadable,
                            style: TextStyle(
                              color: source.processing
                                  ? studafyMuted
                                  : studafyDanger,
                            ),
                          ),
                  ),
              ],
              if (problem != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    problem,
                    style: const TextStyle(color: studafyDanger),
                  ),
                ),
              const SizedBox(height: 8),
              Text(
                l10n.nbSheetTokens,
                style: const TextStyle(color: studafyMuted, fontSize: 12.5),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: sources == null || problem != null ? null : _submit,
                icon: const Icon(Icons.auto_stories_rounded),
                label: Text(l10n.nbCreate),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
