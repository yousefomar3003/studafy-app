import 'package:flutter/material.dart';

import '../../../core/attachment_field.dart';
import '../../../core/coursework_attachments.dart';
import '../../../core/file_upload_repository.dart';
import '../../../core/studafy_design.dart';
import '../../../l10n/generated/app_l10n.dart';
import '../domain/academic_repository.dart';

/// One question while the teacher writes it. Mutable on purpose: the
/// builder edits it in place and reads it back as a [QuestionDraft].
class EditableQuestion {
  EditableQuestion({
    this.id,
    this.kind = QuestionKind.singleChoice,
    String prompt = '',
    double points = 1,
    List<QuestionOption> options = const [],
    Set<String> correct = const {},
    this.correctChoice,
    List<String> accepted = const [],
    String? model,
    String? guidance,
    this.required = true,
    this.existingAttachments = const [],
    this.existingLinks = const [],
  }) : prompt = TextEditingController(text: prompt),
       points = TextEditingController(text: _trim(points)),
       accepted = TextEditingController(text: accepted.join('\n')),
       model = TextEditingController(text: model ?? ''),
       guidance = TextEditingController(text: guidance ?? ''),
       correct = {...correct},
       options = [
         for (final option in options)
           (id: option.id, text: TextEditingController(text: option.text)),
       ] {
    if (this.options.isEmpty && kind.hasOptions) {
      addOption();
      addOption();
    }
  }

  factory EditableQuestion.from(AssessmentQuestion q) => EditableQuestion(
    id: q.id,
    kind: q.kind,
    prompt: q.prompt,
    points: q.maximumScore,
    options: q.options,
    correct: {...?q.correctOptionIds},
    correctChoice: q.correctChoice,
    accepted: q.acceptedAnswers ?? const [],
    model: q.preferredAnswer,
    guidance: q.markingGuidance,
    required: q.required,
    existingAttachments: q.attachments,
    existingLinks: q.links,
  );

  /// A copy as a new question. Files are not copied: an upload is bound to
  /// one question only.
  EditableQuestion duplicate() => EditableQuestion(
    kind: kind,
    prompt: prompt.text,
    points: double.tryParse(points.text) ?? 1,
    options: [
      for (final o in options) QuestionOption(id: o.id, text: o.text.text),
    ],
    correct: correct,
    correctChoice: correctChoice,
    accepted: _lines(accepted.text),
    model: model.text,
    guidance: guidance.text,
    required: required,
  );

  final String? id;
  QuestionKind kind;
  final TextEditingController prompt;
  final TextEditingController points;
  final List<({String id, TextEditingController text})> options;
  final Set<String> correct;
  bool? correctChoice;
  final TextEditingController accepted;
  final TextEditingController model;
  final TextEditingController guidance;
  bool required;
  final List<StoredAttachment> existingAttachments;
  final List<ContentLink> existingLinks;
  AttachmentsEditorValue attachments = const AttachmentsEditorValue();

  /// The question's attachments editor, so a file or link the server
  /// refused can be marked on it.
  final attachmentsEditor = GlobalKey<AttachmentsEditorState>();

  /// Keeps the question's editor state when the list is reordered.
  final key = UniqueKey();

  double get pointsValue => double.tryParse(points.text.trim()) ?? 0;

  void addOption() {
    const letters = 'abcdefghij';
    final used = {for (final o in options) o.id};
    final id = letters
        .split('')
        .firstWhere(
          (l) => !used.contains(l),
          orElse: () => 'o${options.length + 1}',
        );
    options.add((id: id, text: TextEditingController()));
  }

  void removeOption(String id) {
    final option = options.firstWhere((o) => o.id == id);
    options.remove(option);
    correct.remove(id);
    option.text.dispose();
  }

  void dispose() {
    prompt.dispose();
    points.dispose();
    accepted.dispose();
    model.dispose();
    guidance.dispose();
    for (final o in options) {
      o.text.dispose();
    }
  }

  /// What is wrong with it, for the teacher to fix; null when complete.
  String? problem(AppL10n l10n, int number) {
    if (prompt.text.trim().isEmpty) return l10n.builderProblemPrompt(number);
    if (pointsValue <= 0 || pointsValue > 1000) {
      return l10n.builderProblemPoints(number);
    }
    if (kind.hasOptions) {
      if (options.length < 2 ||
          options.any((o) => o.text.text.trim().isEmpty)) {
        return l10n.builderProblemOptions(number);
      }
      final valid = correct.where((id) => options.any((o) => o.id == id));
      if (valid.isEmpty ||
          (kind == QuestionKind.singleChoice && valid.length != 1)) {
        return l10n.builderProblemCorrect(number);
      }
    }
    if (kind == QuestionKind.trueFalse && correctChoice == null) {
      return l10n.builderProblemTrueFalse(number);
    }
    if (!attachments.ready) return l10n.builderProblemFiles(number);
    return null;
  }

  QuestionDraft toDraft() => QuestionDraft(
    id: id,
    prompt: prompt.text.trim(),
    maximumScore: pointsValue,
    kind: kind,
    required: required,
    options: [
      if (kind.hasOptions)
        for (final o in options)
          QuestionOption(id: o.id, text: o.text.text.trim()),
    ],
    correctOptionIds: [
      if (kind.hasOptions)
        for (final o in options)
          if (correct.contains(o.id)) o.id,
    ],
    correctChoice: kind == QuestionKind.trueFalse ? correctChoice : null,
    acceptedAnswers: kind == QuestionKind.shortAnswer
        ? _lines(accepted.text)
        : const [],
    preferredAnswer: model.text.trim().isEmpty ? null : model.text.trim(),
    markingGuidance: guidance.text.trim().isEmpty ? null : guidance.text.trim(),
    attachments: attachments.changes,
  );

  /// As a student would see it, for the preview.
  AssessmentQuestion toPreview(int position) => AssessmentQuestion(
    id: id ?? 'preview-$position',
    position: position,
    prompt: prompt.text.trim(),
    maximumScore: pointsValue,
    kind: kind,
    required: required,
    options: [
      if (kind.hasOptions)
        for (final o in options)
          QuestionOption(id: o.id, text: o.text.text.trim()),
    ],
    attachments: existingAttachments,
    links: existingLinks,
  );

  static List<String> _lines(String text) => [
    for (final line in text.split('\n'))
      if (line.trim().isNotEmpty) line.trim(),
  ];

  static String _trim(double value) =>
      value == value.roundToDouble() ? value.toInt().toString() : '$value';
}

String questionKindLabel(AppL10n l10n, QuestionKind kind) => switch (kind) {
  QuestionKind.singleChoice => l10n.questionKindSingle,
  QuestionKind.multipleChoice => l10n.questionKindMultiple,
  QuestionKind.trueFalse => l10n.questionKindTrueFalse,
  QuestionKind.shortAnswer => l10n.questionKindShort,
  QuestionKind.essay => l10n.questionKindEssay,
};

/// The card a teacher writes one question in.
class QuestionEditorCard extends StatefulWidget {
  const QuestionEditorCard({
    super.key,
    required this.question,
    required this.number,
    required this.onChanged,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onDuplicate,
    required this.onDelete,
    this.schoolId,
    this.classroomId,
    this.uploads,
    this.source,
    this.enabled = true,
  });

  final EditableQuestion question;
  final int number;
  final VoidCallback onChanged;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;
  final String? schoolId;
  final String? classroomId;
  final FileUploadRepository? uploads;
  final AttachmentSource? source;
  final bool enabled;

  @override
  State<QuestionEditorCard> createState() => _QuestionEditorCardState();
}

class _QuestionEditorCardState extends State<QuestionEditorCard> {
  EditableQuestion get q => widget.question;

  void _changed(VoidCallback change) {
    setState(change);
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);
    final enabled = widget.enabled;
    return FeatureCard(
      padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 8, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.builderQuestionNumber(widget.number),
                  style: theme.textTheme.titleSmall,
                ),
              ),
              IconButton(
                tooltip: l10n.builderMoveUp,
                onPressed: enabled ? widget.onMoveUp : null,
                icon: const Icon(Icons.arrow_upward_rounded),
              ),
              IconButton(
                tooltip: l10n.builderMoveDown,
                onPressed: enabled ? widget.onMoveDown : null,
                icon: const Icon(Icons.arrow_downward_rounded),
              ),
              PopupMenuButton<String>(
                enabled: enabled,
                onSelected: (value) => value == 'duplicate'
                    ? widget.onDuplicate()
                    : widget.onDelete(),
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'duplicate',
                    child: Text(l10n.builderDuplicate),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text(l10n.builderDelete),
                  ),
                ],
              ),
            ],
          ),
          DropdownButtonFormField<QuestionKind>(
            initialValue: q.kind,
            decoration: InputDecoration(
              labelText: l10n.builderCategoryLabel,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            items: [
              for (final kind in QuestionKind.values)
                DropdownMenuItem(
                  value: kind,
                  child: Text(questionKindLabel(l10n, kind)),
                ),
            ],
            onChanged: enabled
                ? (kind) => _changed(() {
                    if (kind == null) return;
                    q.kind = kind;
                    if (kind.hasOptions && q.options.length < 2) {
                      while (q.options.length < 2) {
                        q.addOption();
                      }
                    }
                    if (kind == QuestionKind.singleChoice &&
                        q.correct.length > 1) {
                      final first = q.correct.first;
                      q.correct
                        ..clear()
                        ..add(first);
                    }
                  })
                : null,
          ),
          const SizedBox(height: 10),
          TextField(
            controller: q.prompt,
            enabled: enabled,
            minLines: 1,
            maxLines: 6,
            maxLength: 10000,
            decoration: InputDecoration(
              labelText: l10n.builderPrompt,
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) => widget.onChanged(),
          ),
          Row(
            children: [
              SizedBox(
                width: 120,
                child: TextField(
                  controller: q.points,
                  enabled: enabled,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: l10n.builderPoints,
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (_) => widget.onChanged(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(l10n.builderRequired),
                  value: q.required,
                  onChanged: enabled
                      ? (value) => _changed(() => q.required = value)
                      : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ..._answerSection(l10n, theme, enabled),
          const SizedBox(height: 4),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text(l10n.attachmentsTitle),
            children: [
              AttachmentsEditor(
                key: q.attachmentsEditor,
                purpose: FilePurpose.assignmentMaterial,
                schoolId: widget.classroomId == null ? null : widget.schoolId,
                classroomId: widget.classroomId,
                uploads: widget.uploads,
                source: widget.source,
                existingAttachments: q.existingAttachments,
                existingLinks: q.existingLinks,
                maxFiles: 5,
                maxLinks: 5,
                enabled: enabled,
                onChanged: (value) => _changed(() => q.attachments = value),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _answerSection(AppL10n l10n, ThemeData theme, bool enabled) {
    switch (q.kind) {
      case QuestionKind.singleChoice || QuestionKind.multipleChoice:
        final single = q.kind == QuestionKind.singleChoice;
        return [
          Text(
            single ? l10n.builderMarkCorrectOne : l10n.builderMarkCorrectAll,
            style: theme.textTheme.bodySmall,
          ),
          RadioGroup<String>(
            groupValue: q.correct.isEmpty ? null : q.correct.first,
            onChanged: (id) {
              if (!enabled || id == null) return;
              _changed(() {
                q.correct
                  ..clear()
                  ..add(id);
              });
            },
            child: Column(
              children: [
                for (final (index, option) in q.options.indexed)
                  Row(
                    children: [
                      if (single)
                        Radio<String>(value: option.id, enabled: enabled)
                      else
                        Checkbox(
                          value: q.correct.contains(option.id),
                          onChanged: enabled
                              ? (on) => _changed(() {
                                  if (on ?? false) {
                                    q.correct.add(option.id);
                                  } else {
                                    q.correct.remove(option.id);
                                  }
                                })
                              : null,
                        ),
                      Expanded(
                        child: TextField(
                          controller: option.text,
                          enabled: enabled,
                          maxLength: 1000,
                          decoration: InputDecoration(
                            hintText: l10n.builderOption(index + 1),
                            counterText: '',
                            isDense: true,
                          ),
                          onChanged: (_) => widget.onChanged(),
                        ),
                      ),
                      IconButton(
                        tooltip: l10n.builderRemoveOption,
                        onPressed: enabled && q.options.length > 2
                            ? () => _changed(() => q.removeOption(option.id))
                            : null,
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          if (q.options.length < 10)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: enabled ? () => _changed(q.addOption) : null,
                icon: const Icon(Icons.add_rounded),
                label: Text(l10n.builderAddOption),
              ),
            ),
          ..._writtenExtras(l10n, enabled, model: false),
        ];
      case QuestionKind.trueFalse:
        return [
          Text(l10n.builderCorrectIs, style: theme.textTheme.bodySmall),
          const SizedBox(height: 4),
          SegmentedButton<bool>(
            emptySelectionAllowed: true,
            segments: [
              ButtonSegment(value: true, label: Text(l10n.builderTrue)),
              ButtonSegment(value: false, label: Text(l10n.builderFalse)),
            ],
            selected: {?q.correctChoice},
            onSelectionChanged: enabled
                ? (value) => _changed(
                    () => q.correctChoice = value.isEmpty ? null : value.single,
                  )
                : null,
          ),
          ..._writtenExtras(l10n, enabled, model: false),
        ];
      case QuestionKind.shortAnswer:
        return [
          TextField(
            controller: q.accepted,
            enabled: enabled,
            minLines: 1,
            maxLines: 5,
            decoration: InputDecoration(
              labelText: l10n.builderAccepted,
              helperText: l10n.builderAcceptedHint,
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) => widget.onChanged(),
          ),
          ..._writtenExtras(l10n, enabled, model: true),
        ];
      case QuestionKind.essay:
        return _writtenExtras(l10n, enabled, model: true);
    }
  }

  /// The model answer and marking guidance - private until release.
  List<Widget> _writtenExtras(
    AppL10n l10n,
    bool enabled, {
    required bool model,
  }) => [
    const SizedBox(height: 8),
    if (model)
      TextField(
        controller: q.model,
        enabled: enabled,
        minLines: 1,
        maxLines: 6,
        decoration: InputDecoration(
          labelText: l10n.builderModelAnswer,
          helperText: l10n.builderPrivateHint,
          border: const OutlineInputBorder(),
        ),
        onChanged: (_) => widget.onChanged(),
      ),
    const SizedBox(height: 8),
    TextField(
      controller: q.guidance,
      enabled: enabled,
      minLines: 1,
      maxLines: 6,
      decoration: InputDecoration(
        labelText: l10n.builderGuidance,
        helperText: model ? null : l10n.builderPrivateHint,
        border: const OutlineInputBorder(),
      ),
      onChanged: (_) => widget.onChanged(),
    ),
  ];
}
