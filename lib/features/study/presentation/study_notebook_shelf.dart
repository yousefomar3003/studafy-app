import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/feedback.dart';
import '../../../core/material_selection.dart';
import '../../../core/material_unavailable_dialog.dart';
import '../../../core/navigation.dart';
import '../../../core/studafy_components.dart';
import '../../../core/studafy_design.dart';
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
    required this.pick,
  });

  final StudyRepository study;
  final NotebookTracker tracker;

  /// The class, as the create sheet names it.
  final String className;

  /// The caller's plan, when known.
  final StudyPlan? Function() plan;
  final VoidCallback onOpenPlans;

  /// Chooses exactly what a notebook is made from (ADR-0039).
  final MaterialPicker pick;

  bool get _locked => !(plan()?.canSnapWhiteboard ?? true);

  Future<void> _upgrade(BuildContext context, UpgradeReason reason) =>
      showUpgradePrompt(
        context,
        reason: reason,
        plan: plan(),
        needs: StudyPlanTier.plus,
        onUpgrade: onOpenPlans,
      );

  /// Shows the lesson and what of it will be used - its text and each file
  /// and link, to keep or leave out - then starts the notebook.
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
    final selection = await pick(
      context,
      MaterialPickRequest(
        action: MaterialAction.notebook,
        preselectLessonId: resourceId,
        onlyClassroomId: tracker.classroomId,
        singleLesson: true,
      ),
    );
    if (selection == null || selection.lessons.isEmpty || !context.mounted) {
      return;
    }
    var skip = false;
    while (true) {
      try {
        final summary = await study.createNotebook(
          tracker.classroomId,
          resourceId: selection.lessons.first.lessonId,
          sourceIds: const [],
          selection: selection,
          skipUnavailable: skip,
        );
        tracker.put(summary);
        messenger.showMessage(l10n.nbStarted);
        return;
      } on MaterialUnavailableException catch (error) {
        if (!context.mounted || skip) return;
        skip = await confirmContinueWithout(
          context,
          error,
          selection: selection,
        );
        if (!skip) return;
      } on StudyException catch (error) {
        if (!context.mounted) return;
        final reason = upgradeReasonFor(error.refusal);
        if (reason != null) {
          await _upgrade(context, reason);
          return;
        }
        messenger.showMessage(notebookRefusalText(l10n, error.refusal));
        return;
      }
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
    var skip = false;
    while (true) {
      try {
        tracker.put(
          await study.updateNotebook(summary.id, skipUnavailable: skip),
        );
        messenger.showMessage(l10n.nbStarted);
        return;
      } on MaterialUnavailableException catch (error) {
        if (!context.mounted || skip) return;
        skip = await confirmContinueWithout(context, error);
        if (!skip) return;
      } on StudyException catch (error) {
        if (!context.mounted) return;
        final reason = upgradeReasonFor(error.refusal);
        if (reason != null) {
          await _upgrade(context, reason);
          return;
        }
        messenger.showMessage(notebookRefusalText(l10n, error.refusal));
        return;
      }
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
