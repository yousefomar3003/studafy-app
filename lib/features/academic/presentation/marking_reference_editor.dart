import 'package:flutter/material.dart';

import '../../../core/studafy_design.dart';
import '../../../core/user_content_text.dart';
import '../../../l10n/generated/app_l10n.dart';
import '../domain/marking.dart';
import '../domain/online_assessment.dart';

/// One key point while the teacher writes it.
class _EditableKeyPoint {
  _EditableKeyPoint({String text = '', double? marks})
    : text = TextEditingController(text: text),
      marks = TextEditingController(text: marks == null ? '' : _number(marks));

  final TextEditingController text;
  final TextEditingController marks;
  final key = UniqueKey();

  void dispose() {
    text.dispose();
    marks.dispose();
  }
}

String _number(double value) =>
    value == value.roundToDouble() ? value.toInt().toString() : '$value';

/// One written reference while the teacher edits it. Reads back only what
/// changed, so saving never rewrites a field nobody touched.
class EditableReference {
  EditableReference(this.initial)
    : model = TextEditingController(text: initial.preferredAnswer ?? ''),
      guidance = TextEditingController(text: initial.markingGuidance ?? ''),
      methods = TextEditingController(text: initial.acceptedMethods ?? ''),
      partial = TextEditingController(text: initial.partialCredit ?? ''),
      _points = [
        for (final point in initial.keyPoints)
          _EditableKeyPoint(text: point.text, marks: point.marks),
      ];

  MarkingReference initial;
  final TextEditingController model;
  final TextEditingController guidance;
  final TextEditingController methods;
  final TextEditingController partial;
  final List<_EditableKeyPoint> _points;

  /// Short answers are marked by their accepted answers; the reference adds
  /// alternatives. Essays and hand-ins have the full reference.
  bool get full => initial.kind != QuestionKind.shortAnswer;

  bool get canAddPoint => _points.length < maxMarkingKeyPoints;

  void addPoint() => _points.add(_EditableKeyPoint());

  void removePoint(int index) => _points.removeAt(index).dispose();

  List<MarkingKeyPoint> get keyPoints => [
    for (final point in _points)
      if (point.text.text.trim().isNotEmpty ||
          point.marks.text.trim().isNotEmpty)
        MarkingKeyPoint(
          text: point.text.text.trim(),
          marks: double.tryParse(point.marks.text.trim().replaceAll(',', '.')),
        ),
  ];

  /// What the key points with marks add up to, as typed.
  double get pointsTotal => keyPointMarks(keyPoints);

  /// Why the key points cannot be saved as typed, or null.
  String? problem(AppL10n l10n) {
    for (final point in _points) {
      final marks = point.marks.text.trim();
      final empty = point.text.text.trim().isEmpty;
      if (empty && marks.isNotEmpty) return l10n.markingRefsKeyPointEmpty;
      final value = double.tryParse(marks.replaceAll(',', '.'));
      if (marks.isNotEmpty && (value == null || value < 0)) {
        return l10n.markingRefsKeyPointMarksInvalid;
      }
    }
    if (pointsTotal > initial.maximumScore) {
      return l10n.markingRefsKeyPointsTooMany(
        _number(pointsTotal),
        _number(initial.maximumScore),
      );
    }
    return null;
  }

  static String? _changed(TextEditingController field, String? old) {
    final now = field.text.trim();
    return now == (old ?? '').trim() ? null : now;
  }

  /// The change to send, or null when nothing changed.
  MarkingReferenceUpdate? get update {
    final points = keyPoints;
    final update = MarkingReferenceUpdate(
      questionId: initial.questionId,
      preferredAnswer: _changed(model, initial.preferredAnswer),
      markingGuidance: _changed(guidance, initial.markingGuidance),
      acceptedMethods: _changed(methods, initial.acceptedMethods),
      partialCredit: _changed(partial, initial.partialCredit),
      keyPoints:
          points.length == initial.keyPoints.length &&
              [
                for (var i = 0; i < points.length; i++)
                  points[i] == initial.keyPoints[i],
              ].every((same) => same)
          ? null
          : points,
    );
    return update.isEmpty ? null : update;
  }

  void dispose() {
    for (final c in [model, guidance, methods, partial]) {
      c.dispose();
    }
    for (final point in _points) {
      point.dispose();
    }
  }
}

/// The card for one reference: the question, and what the teacher says a
/// good answer is - or, for a choice or true/false question, that its key
/// already marks it.
class MarkingReferenceCard extends StatefulWidget {
  const MarkingReferenceCard({
    super.key,
    required this.reference,
    this.editor,
    required this.enabled,
    required this.onChanged,
  });

  final MarkingReference reference;

  /// Null for a question its key marks by itself.
  final EditableReference? editor;
  final bool enabled;
  final VoidCallback onChanged;

  @override
  State<MarkingReferenceCard> createState() => _MarkingReferenceCardState();
}

class _MarkingReferenceCardState extends State<MarkingReferenceCard> {
  void _changed([VoidCallback? change]) {
    setState(change ?? () {});
    widget.onChanged();
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    String? helper,
    int maxLength = 5000,
  }) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: TextField(
      controller: controller,
      enabled: widget.enabled,
      minLines: 1,
      maxLines: 6,
      maxLength: maxLength,
      decoration: InputDecoration(
        labelText: label,
        helperText: helper,
        helperMaxLines: 3,
        border: const OutlineInputBorder(),
      ),
      onChanged: (_) => _changed(),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);
    final r = widget.reference;
    final editor = widget.editor;
    final max = _number(r.maximumScore);
    return FeatureCard(
      padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            r.handIn
                ? l10n.markingRefsHandIn(max)
                : l10n.markingRefsQuestion(r.position, max),
            style: theme.textTheme.titleSmall,
          ),
          if ((r.prompt ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            UserContentText(r.prompt!, style: theme.textTheme.bodyMedium),
          ],
          if (r.handIn)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                l10n.markingRefsHandInHint,
                style: theme.textTheme.bodySmall,
              ),
            ),
          if (editor == null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  const Icon(Icons.task_alt_rounded, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(l10n.markingRefsAutomatic)),
                ],
              ),
            )
          else
            ..._fields(l10n, theme, editor),
        ],
      ),
    );
  }

  List<Widget> _fields(
    AppL10n l10n,
    ThemeData theme,
    EditableReference editor,
  ) {
    final accepted = widget.reference.acceptedAnswers ?? const [];
    final problem = editor.problem(l10n);
    return [
      if (!editor.full && accepted.isNotEmpty) ...[
        const SizedBox(height: 8),
        Text(l10n.takeAcceptedAnswers, style: theme.textTheme.labelSmall),
        UserContentText(accepted.join(' / ')),
      ],
      _field(
        editor.model,
        l10n.builderModelAnswer,
        helper: l10n.builderPrivateHint,
        maxLength: 30000,
      ),
      if (editor.full) ...[
        const SizedBox(height: 12),
        Text(l10n.markingRefsKeyPoints, style: theme.textTheme.labelLarge),
        Text(l10n.markingRefsKeyPointsHint, style: theme.textTheme.bodySmall),
        for (final (index, point) in editor._points.indexed)
          Padding(
            key: point.key,
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: point.text,
                    enabled: widget.enabled,
                    minLines: 1,
                    maxLines: 3,
                    maxLength: 500,
                    decoration: InputDecoration(
                      labelText: l10n.markingRefsKeyPoint(index + 1),
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (_) => _changed(),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 84,
                  child: TextField(
                    controller: point.marks,
                    enabled: widget.enabled,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: l10n.markingRefsKeyPointMarks,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (_) => _changed(),
                  ),
                ),
                IconButton(
                  tooltip: l10n.markingRefsRemoveKeyPoint,
                  onPressed: widget.enabled
                      ? () => _changed(() => editor.removePoint(index))
                      : null,
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.markingRefsKeyPointsTotal(
                  _number(editor.pointsTotal),
                  _number(widget.reference.maximumScore),
                ),
                style: theme.textTheme.bodySmall,
              ),
            ),
            if (editor.canAddPoint)
              TextButton.icon(
                onPressed: widget.enabled
                    ? () => _changed(editor.addPoint)
                    : null,
                icon: const Icon(Icons.add_rounded),
                label: Text(l10n.markingRefsAddKeyPoint),
              ),
          ],
        ),
        if (problem != null)
          Text(problem, style: TextStyle(color: theme.colorScheme.error)),
      ],
      _field(
        editor.methods,
        editor.full ? l10n.markingRefsMethods : l10n.markingRefsMethodsShort,
      ),
      if (editor.full)
        _field(
          editor.partial,
          l10n.markingRefsPartial,
          helper: l10n.markingRefsPartialHint,
        ),
      _field(editor.guidance, l10n.builderGuidance, maxLength: 10000),
    ];
  }
}
