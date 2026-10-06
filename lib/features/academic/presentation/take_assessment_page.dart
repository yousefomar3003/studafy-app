import 'package:flutter/material.dart';

import '../../../core/coursework_attachments.dart';
import '../../../core/studafy_components.dart';
import '../../../core/studafy_design.dart';
import '../../../l10n/generated/app_l10n.dart';
import '../domain/academic_repository.dart';

/// Sitting an online assessment: every question with the answer control its
/// kind needs, its points and whether it is required, and its files and
/// links. Submitting asks first; the confirmation carries no mark.
///
/// With [preview] it is the teacher's view of what a student will see, and
/// nothing can be submitted. Answers are never on this screen - the server
/// does not send them to a student.
class TakeAssessmentPage extends StatefulWidget {
  const TakeAssessmentPage({
    super.key,
    required this.title,
    this.repository,
    this.assessmentId,
    this.questions,
    this.preview = false,
  });

  final String title;
  final OnlineAssessmentRepository? repository;
  final String? assessmentId;

  /// Given for a preview; otherwise loaded from the server.
  final List<AssessmentQuestion>? questions;
  final bool preview;

  @override
  State<TakeAssessmentPage> createState() => _TakeAssessmentPageState();
}

class _TakeAssessmentPageState extends State<TakeAssessmentPage> {
  List<AssessmentQuestion>? _questions;
  bool _failed = false;
  bool _submitting = false;
  String? _error;
  final Map<String, Set<String>> _chosen = {};
  final Map<String, bool> _choice = {};
  final Map<String, TextEditingController> _text = {};

  @override
  void initState() {
    super.initState();
    _questions = widget.questions;
    if (_questions == null) _load();
  }

  @override
  void dispose() {
    for (final controller in _text.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final repository = widget.repository;
    final id = widget.assessmentId;
    if (repository == null || id == null) return;
    setState(() => _failed = false);
    try {
      final questions = await repository.questions(id);
      if (mounted) setState(() => _questions = questions);
    } on Object {
      if (mounted) setState(() => _failed = true);
    }
  }

  TextEditingController _controller(String id) =>
      _text.putIfAbsent(id, TextEditingController.new);

  StudentAnswer _answer(AssessmentQuestion q) => StudentAnswer(
    questionId: q.id,
    text: q.kind == QuestionKind.shortAnswer || q.kind == QuestionKind.essay
        ? _text[q.id]?.text
        : null,
    selectedOptionIds: [...?_chosen[q.id]],
    choice: _choice[q.id],
  );

  bool get _started => (_questions ?? const []).any((q) => !_answer(q).isEmpty);

  Future<void> _submit() async {
    final l10n = AppL10n.of(context);
    final questions = _questions ?? const <AssessmentQuestion>[];
    final missing = questions
        .where((q) => q.required && _answer(q).isEmpty)
        .length;
    if (missing > 0) {
      setState(() => _error = l10n.takeMissing(missing));
      return;
    }
    final go = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.takeSubmitTitle),
        content: Text(l10n.takeSubmitBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.takeStay),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.takeSubmit),
          ),
        ],
      ),
    );
    if (go != true || !mounted) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final confirmation = await widget.repository!.submitAnswers(
        widget.assessmentId!,
        [for (final q in questions) _answer(q)],
      );
      if (mounted) Navigator.of(context).pop(confirmation);
    } on CourseworkRefusal catch (refusal) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = refusal.problem == CourseworkProblem.windowClosed
            ? l10n.takeWindowClosed
            : l10n.takeSubmitFailed;
      });
    } on Object {
      // The answers stay on screen, so trying again loses nothing.
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = l10n.takeSubmitFailed;
      });
    }
  }

  Future<bool> _confirmLeave() async {
    final l10n = AppL10n.of(context);
    final leave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.takeLeaveTitle),
        content: Text(l10n.takeLeaveBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.takeStay),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.takeLeave),
          ),
        ],
      ),
    );
    return leave ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final questions = _questions;
    final guard = !widget.preview && !_submitting && _started;
    return PopScope(
      canPop: !guard,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (await _confirmLeave()) navigator.pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.preview
                ? '${l10n.builderPreview} · ${widget.title}'
                : widget.title,
          ),
        ),
        body: SafeArea(
          child: questions == null
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
                  padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 24),
                  children: [
                    for (final (index, q) in questions.indexed)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _QuestionCard(
                          question: q,
                          number: index + 1,
                          total: questions.length,
                          enabled: !_submitting,
                          chosen: _chosen[q.id] ?? const {},
                          choice: _choice[q.id],
                          text: _controller(q.id),
                          onChoose: (id) => setState(() {
                            final set = _chosen.putIfAbsent(q.id, () => {});
                            if (q.kind == QuestionKind.singleChoice) {
                              set
                                ..clear()
                                ..add(id);
                            } else if (!set.remove(id)) {
                              set.add(id);
                            }
                            _error = null;
                          }),
                          onChoice: (value) => setState(() {
                            _choice[q.id] = value;
                            _error = null;
                          }),
                          onTyped: () => setState(() => _error = null),
                        ),
                      ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    if (!widget.preview)
                      FilledButton.icon(
                        onPressed: _submitting || questions.isEmpty
                            ? null
                            : _submit,
                        icon: _submitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.send_rounded),
                        label: Text(l10n.takeSubmit),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.question,
    required this.number,
    required this.total,
    required this.enabled,
    required this.chosen,
    required this.choice,
    required this.text,
    required this.onChoose,
    required this.onChoice,
    required this.onTyped,
  });

  final AssessmentQuestion question;
  final int number;
  final int total;
  final bool enabled;
  final Set<String> chosen;
  final bool? choice;
  final TextEditingController text;
  final ValueChanged<String> onChoose;
  final ValueChanged<bool> onChoice;
  final VoidCallback onTyped;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);
    final q = question;
    return FeatureCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.builderQuestionNumber(number),
                  style: theme.textTheme.labelLarge,
                ),
              ),
              Text(
                '${l10n.takePoints(q.maximumScore)} · '
                '${q.required ? l10n.takeRequired : l10n.takeOptional}',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(q.prompt, style: theme.textTheme.bodyLarge),
          AttachmentsView(attachments: q.attachments, links: q.links),
          const SizedBox(height: 8),
          switch (q.kind) {
            QuestionKind.singleChoice => RadioGroup<String>(
              groupValue: chosen.isEmpty ? null : chosen.first,
              onChanged: (id) {
                if (enabled && id != null) onChoose(id);
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.takeChooseOne, style: theme.textTheme.bodySmall),
                  for (final option in q.options)
                    RadioListTile<String>(
                      value: option.id,
                      enabled: enabled,
                      contentPadding: EdgeInsets.zero,
                      title: Text(option.text),
                    ),
                ],
              ),
            ),
            QuestionKind.multipleChoice => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.takeChooseAll, style: theme.textTheme.bodySmall),
                for (final option in q.options)
                  CheckboxListTile(
                    value: chosen.contains(option.id),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(option.text),
                    onChanged: enabled ? (_) => onChoose(option.id) : null,
                  ),
              ],
            ),
            QuestionKind.trueFalse => SegmentedButton<bool>(
              emptySelectionAllowed: true,
              segments: [
                ButtonSegment(value: true, label: Text(l10n.builderTrue)),
                ButtonSegment(value: false, label: Text(l10n.builderFalse)),
              ],
              selected: {?choice},
              onSelectionChanged: enabled
                  ? (value) {
                      if (value.isNotEmpty) onChoice(value.single);
                    }
                  : null,
            ),
            QuestionKind.shortAnswer || QuestionKind.essay => TextField(
              controller: text,
              enabled: enabled,
              minLines: q.kind == QuestionKind.essay ? 4 : 1,
              maxLines: q.kind == QuestionKind.essay ? 14 : 2,
              maxLength: q.kind == QuestionKind.essay ? 30000 : 500,
              decoration: InputDecoration(
                labelText: l10n.takeTypeAnswer,
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => onTyped(),
            ),
          },
        ],
      ),
    );
  }
}
