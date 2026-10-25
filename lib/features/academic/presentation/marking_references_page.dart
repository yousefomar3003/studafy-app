import 'package:flutter/material.dart';

import '../../../core/studafy_components.dart';
import '../../../core/studafy_design.dart';
import '../../../core/unsaved_changes.dart';
import '../../../l10n/generated/app_l10n.dart';
import '../domain/marking.dart';
import 'marking_plan_page.dart';
import 'marking_reference_editor.dart';
import 'marking_scope.dart';

/// What the teacher says a good answer is, for suggested marks (ADR-0046):
/// per written question of an online assessment, or one reference for a
/// graded assignment's hand-in, and how strictly to compare with it.
///
/// References can be changed at any time, after work is in too. A change
/// never re-marks anything by itself: the page says how many suggestions
/// were made with an older reference, and the teacher may ask again.
class MarkingReferencesPage extends StatefulWidget {
  const MarkingReferencesPage({
    super.key,
    required this.assessmentId,
    this.services,
  });

  final String assessmentId;

  /// Defaults to the app's [MarkingScope].
  final MarkingServices? services;

  @override
  State<MarkingReferencesPage> createState() => _MarkingReferencesPageState();
}

class _MarkingReferencesPageState extends State<MarkingReferencesPage> {
  MarkingReferences? _references;
  final Map<int, EditableReference> _editors = {};
  MarkingStrictness _strictness = MarkingStrictness.balanced;
  MarkingPlan? _plan;
  bool _failed = false;
  bool _saving = false;
  String? _error;
  String? _notice;

  /// Suggestions made with an older reference, after the last save.
  int _stale = 0;

  MarkingServices? get _services =>
      widget.services ?? MarkingScope.maybeOf(context);

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _load();
  }

  @override
  void dispose() {
    for (final editor in _editors.values) {
      editor.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final services = _services;
    if (services == null) return;
    if (_failed) setState(() => _failed = false);
    try {
      final (references, plan) = await (
        services.repository.references(widget.assessmentId),
        services.repository.plan().then<MarkingPlan?>(
          (plan) => plan,
          onError: (Object _) => null,
        ),
      ).wait;
      if (!mounted) return;
      setState(() {
        _plan = plan;
        _show(references);
      });
    } on Object {
      if (mounted) setState(() => _failed = true);
    }
  }

  void _show(MarkingReferences references) {
    for (final editor in _editors.values) {
      editor.dispose();
    }
    _editors
      ..clear()
      ..addAll({
        for (final (index, r) in references.references.indexed)
          if (r.written) index: EditableReference(r),
      });
    _references = references;
    _strictness = references.strictness;
    _failed = false;
  }

  bool get _dirty =>
      _references != null &&
      (_strictness != _references!.strictness ||
          _editors.values.any((e) => e.update != null));

  Future<void> _save() async {
    final services = _services;
    final current = _references;
    if (services == null || current == null || _saving) return;
    final l10n = AppL10n.of(context);
    if (_editors.values.any((e) => e.problem(l10n) != null)) {
      setState(() => _error = l10n.markingRefsFixFirst);
      return;
    }
    final updates = [for (final e in _editors.values) ?e.update];
    final strictness = _strictness == current.strictness ? null : _strictness;
    if (updates.isEmpty && strictness == null) {
      setState(() {
        _error = null;
        _notice = l10n.markingRefsUnchanged;
      });
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
      _notice = null;
    });
    try {
      final saved = await services.repository.saveReferences(
        widget.assessmentId,
        strictness: strictness,
        updates: updates,
      );
      if (!mounted) return;
      setState(() {
        _saving = false;
        // The delivery is the read's; a save does not change it.
        _show(
          MarkingReferences(
            delivery: current.delivery,
            strictness: saved.references.strictness,
            referenceVersion: saved.references.referenceVersion,
            references: saved.references.references,
          ),
        );
        _stale = saved.staleSuggestions;
        _notice = saved.changed
            ? l10n.markingRefsSaved
            : l10n.markingRefsUnchanged;
      });
    } on MarkingRefusal catch (refusal) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = refusal.problem == MarkingProblem.invalid
            ? l10n.markingRefsInvalid
            : l10n.markingRefsSaveFailed;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = l10n.markingRefsSaveFailed;
      });
    }
  }

  /// Suggestions made with an older reference are asked for again, for the
  /// students they were for.
  Future<void> _suggestAgain() async {
    final services = _services;
    if (services == null) return;
    final l10n = AppL10n.of(context);
    List<String>? students;
    try {
      final list = await services.repository.suggestions(widget.assessmentId);
      students = {
        for (final s in list.items)
          if (s.stale) s.studentId,
      }.toList();
    } on Object {
      students = null;
    }
    if (!mounted) return;
    final run = await askForMarkingSuggestions(
      context,
      services,
      widget.assessmentId,
      all: true,
      studentIds: students,
    );
    if (run == null || !mounted) return;
    setState(() {
      _stale = 0;
      _notice = l10n.markingRunQueued(run.queued);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);
    final references = _references;
    return UnsavedChangesScope(
      unsaved: _dirty && !_saving,
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.markingRefsTitle)),
        body: SafeArea(
          child: references == null
              ? Center(
                  child: _failed
                      ? StudafyEmptyState(
                          icon: Icons.wifi_off_rounded,
                          title: l10n.takeLoadFailed,
                          actionLabel: l10n.takeRetry,
                          onAction: _load,
                        )
                      : const CircularProgressIndicator(),
                )
              : ListView(
                  padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 32),
                  children: [
                    Text(l10n.markingRefsIntro),
                    const SizedBox(height: 4),
                    Text(
                      l10n.markingRefsNeverRemarks,
                      style: theme.textTheme.bodySmall,
                    ),
                    if (_stale > 0) ...[
                      const SizedBox(height: 12),
                      MarkingStaleBanner(
                        count: _stale,
                        onSuggestAgain: (_plan?.available ?? false)
                            ? _suggestAgain
                            : null,
                      ),
                    ],
                    SectionHeader(l10n.markingRefsStrictness),
                    FeatureCard(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: RadioGroup<MarkingStrictness>(
                        groupValue: _strictness,
                        onChanged: (value) {
                          if (_saving || value == null) return;
                          setState(() {
                            _strictness = value;
                            _notice = null;
                          });
                        },
                        child: Column(
                          children: [
                            for (final value in MarkingStrictness.values)
                              RadioListTile<MarkingStrictness>(
                                value: value,
                                title: Text(strictnessLabel(l10n, value)),
                                subtitle: Text(strictnessHint(l10n, value)),
                              ),
                          ],
                        ),
                      ),
                    ),
                    SectionHeader(l10n.markingRefsReferences),
                    for (final (index, r) in references.references.indexed)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: MarkingReferenceCard(
                          key: ValueKey((
                            'reference',
                            r.questionId,
                            references.referenceVersion,
                          )),
                          reference: r,
                          editor: _editors[index],
                          enabled: !_saving,
                          onChanged: () => setState(() {
                            _error = null;
                            _notice = null;
                          }),
                        ),
                      ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          _error!,
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      ),
                    if (_notice != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Semantics(
                          liveRegion: true,
                          child: Text(_notice!),
                        ),
                      ),
                    FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(l10n.markingRefsSave),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

String strictnessLabel(AppL10n l10n, MarkingStrictness value) =>
    switch (value) {
      MarkingStrictness.lenient => l10n.markingStrictLenient,
      MarkingStrictness.balanced => l10n.markingStrictBalanced,
      MarkingStrictness.strict => l10n.markingStrictStrict,
    };

String strictnessHint(AppL10n l10n, MarkingStrictness value) => switch (value) {
  MarkingStrictness.lenient => l10n.markingStrictLenientHint,
  MarkingStrictness.balanced => l10n.markingStrictBalancedHint,
  MarkingStrictness.strict => l10n.markingStrictStrictHint,
};

/// "N suggestions were made with an older reference - Suggest again".
class MarkingStaleBanner extends StatelessWidget {
  const MarkingStaleBanner({
    super.key,
    required this.count,
    this.onSuggestAgain,
  });

  final int count;

  /// Null where suggestions cannot be made now.
  final VoidCallback? onSuggestAgain;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return FeatureCard(
      tint: studafyCyan,
      padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 8, 10),
      child: Row(
        children: [
          const Icon(Icons.history_rounded, color: studafyNavy),
          const SizedBox(width: 10),
          Expanded(child: Text(l10n.markingRefsStale(count))),
          if (onSuggestAgain != null)
            TextButton(
              onPressed: onSuggestAgain,
              child: Text(l10n.markingSuggestAgain),
            ),
        ],
      ),
    );
  }
}
