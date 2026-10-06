import 'package:flutter/material.dart';

import '../../../core/attachment_field.dart';
import '../../../core/coursework_attachments.dart';
import '../../../core/file_upload_repository.dart';
import '../../../core/navigation.dart';
import '../../../core/platform_attachment_source.dart';
import '../../../core/studafy_components.dart';
import '../../../core/studafy_design.dart';
import '../../../core/uploads_scope.dart';
import '../../../l10n/generated/app_l10n.dart';
import '../domain/academic_repository.dart';
import 'question_editor.dart';
import 'take_assessment_page.dart';

/// Builds an online exam or assessment (ADR-0036): mixed question kinds,
/// each with its points, key, model answer, guidance and attachments; the
/// window, attempts and when answers are released; material for the whole
/// thing; a student preview; and checks that everything is complete before
/// it can be published.
///
/// Editing an existing one ([existing]): the questions can change only
/// while nobody has submitted; the settings always can.
class AssessmentBuilderPage extends StatefulWidget {
  const AssessmentBuilderPage({
    super.key,
    required this.repository,
    required this.classes,
    this.initialClassroomId,
    this.schoolId,
    this.uploads,
    this.attachmentSource,
    this.existing,
  });

  final AcademicRepository repository;
  final List<ClassOption> classes;
  final String? initialClassroomId;
  final String? schoolId;
  final FileUploadRepository? uploads;
  final AttachmentSource? attachmentSource;
  final OnlineAssessment? existing;

  @override
  State<AssessmentBuilderPage> createState() => _AssessmentBuilderPageState();
}

class _AssessmentBuilderPageState extends State<AssessmentBuilderPage> {
  late final _title = TextEditingController(text: widget.existing?.title ?? '');
  String? _classroomId;
  late String _category = widget.existing?.category ?? 'quiz';
  late AssessmentSettings _settings =
      widget.existing?.settings ??
      AssessmentSettings(
        opensAt: DateTime.now(),
        closesAt: DateTime.now().add(const Duration(days: 7)),
      );
  final List<EditableQuestion> _questions = [];
  AttachmentsEditorValue _material = const AttachmentsEditorValue();

  /// Somebody has submitted: the questions are fixed.
  bool _locked = false;
  bool _loading = false;
  bool _saving = false;
  String? _error;

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _classroomId =
        widget.existing?.classroomId ??
        widget.initialClassroomId ??
        (widget.classes.length == 1 ? widget.classes.single.id : null);
    if (_editing) {
      _load();
    } else {
      _questions.add(EditableQuestion());
    }
  }

  @override
  void dispose() {
    _title.dispose();
    for (final q in _questions) {
      q.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final id = widget.existing!.id;
    setState(() => _loading = true);
    try {
      final (questions, attempts) = await (
        widget.repository.authoringQuestions(id),
        widget.repository.attempts(id),
      ).wait;
      if (!mounted) return;
      setState(() {
        _questions.addAll(questions.map(EditableQuestion.from));
        _locked = attempts.isNotEmpty;
        _loading = false;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = AppL10n.of(context).takeLoadFailed;
      });
    }
  }

  double get _total => _questions.fold(0, (sum, q) => sum + q.pointsValue);

  String _points(double value) =>
      value == value.roundToDouble() ? value.toInt().toString() : '$value';

  /// Everything that stops it being saved, in the order the page reads.
  List<String> _problems(AppL10n l10n) => [
    if (_classroomId == null) l10n.builderNeedClass,
    if (_title.text.trim().isEmpty) l10n.builderNeedTitle,
    if (_settings.closesAt == null) l10n.builderNeedClose,
    if (_settings.opensAt case final opens?)
      if (_settings.closesAt case final closes?)
        if (!closes.isAfter(opens)) l10n.builderCloseAfterOpen,
    if (_questions.isEmpty) l10n.builderNeedQuestion,
    if (!_locked)
      for (final (index, q) in _questions.indexed) ?q.problem(l10n, index + 1),
    if (_material.uploading) l10n.attachmentsUploading,
    if (_material.failed) l10n.attachmentsFailed,
  ];

  Future<void> _save({required bool publish}) async {
    final l10n = AppL10n.of(context);
    final problems = _problems(l10n);
    if (problems.isNotEmpty) {
      setState(() => _error = problems.join('\n'));
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final repository = widget.repository;
    final drafts = [for (final q in _questions) q.toDraft()];
    try {
      OnlineAssessment saved;
      final existing = widget.existing;
      if (existing == null) {
        saved = await repository.createOnlineAssessment(
          OnlineAssessmentDraft(
            classroomId: _classroomId!,
            title: _title.text.trim(),
            category: _category,
            questions: drafts,
            settings: _settings,
            attachmentFileIds: _material.changes.attachFileIds,
            links: _material.changes.addLinks,
          ),
        );
      } else {
        saved = await repository.updateAssessmentDesign(
          existing.id,
          existing.version,
          title: _title.text.trim(),
          questions: _locked ? null : drafts,
          settings: _settings,
          attachments: _material.changes,
        );
      }
      if (publish && saved.state == 'draft') {
        await repository.publishAssessment(saved.id, saved.version);
      }
      if (!mounted) return;
      Navigator.of(context)
          .pop(publish ? l10n.builderPublished : l10n.builderSaved);
    } on Object {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = l10n.builderSaveFailed;
      });
    }
  }

  Future<void> _preview() async {
    await Navigator.of(context).pushOnce<void>(
      MaterialPageRoute<void>(
        builder: (_) => TakeAssessmentPage(
          title: _title.text.trim(),
          preview: true,
          questions: [
            for (final (index, q) in _questions.indexed) q.toPreview(index + 1),
          ],
        ),
      ),
    );
  }

  Future<DateTime?> _pickDateTime(DateTime? initial) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: initial ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial ?? now),
    );
    if (!mounted) return null;
    return DateTime(
      date.year,
      date.month,
      date.day,
      time?.hour ?? 9,
      time?.minute ?? 0,
    );
  }

  String _when(BuildContext context, DateTime? value) {
    if (value == null) return AppL10n.of(context).builderNotSet;
    final dates = MaterialLocalizations.of(context);
    return '${dates.formatShortDate(value)} '
        '${dates.formatTimeOfDay(TimeOfDay.fromDateTime(value))}';
  }

  void _setSettings({
    DateTime? opensAt,
    DateTime? closesAt,
    int? maxAttempts,
    AttemptPolicy? policy,
    AnswerRelease? release,
  }) => setState(() {
    _settings = AssessmentSettings(
      opensAt: opensAt ?? _settings.opensAt,
      closesAt: closesAt ?? _settings.closesAt,
      maxAttempts: maxAttempts ?? _settings.maxAttempts,
      attemptPolicy: policy ?? _settings.attemptPolicy,
      answerRelease: release ?? _settings.answerRelease,
    );
    _error = null;
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);
    final uploads = widget.uploads ?? UploadsScope.maybeOf(context);
    final source = widget.attachmentSource ?? pickPlatformAttachment;
    final published = widget.existing?.state == 'published';
    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? l10n.builderEditTitle : l10n.builderNewTitle),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 32),
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _classroomId,
                    decoration: InputDecoration(
                      labelText: l10n.builderClassLabel,
                      border: const OutlineInputBorder(),
                    ),
                    items: [
                      for (final option in widget.classes)
                        DropdownMenuItem(
                          value: option.id,
                          child: Text(option.name),
                        ),
                    ],
                    // Files are uploaded for one class: the class is chosen
                    // first, and not changed once it exists.
                    onChanged: _saving || _editing
                        ? null
                        : (value) => setState(() => _classroomId = value),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _title,
                    enabled: !_saving,
                    maxLength: 200,
                    decoration: InputDecoration(
                      labelText: l10n.builderTitleLabel,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  if (!_editing) ...[
                    Text(
                      l10n.builderCategoryLabel,
                      style: theme.textTheme.labelLarge,
                    ),
                    const SizedBox(height: 6),
                    SegmentedButton<String>(
                      segments: [
                        ButtonSegment(
                          value: 'quiz',
                          label: Text(l10n.builderCategoryQuiz),
                        ),
                        ButtonSegment(
                          value: 'exam',
                          label: Text(l10n.builderCategoryExam),
                        ),
                        ButtonSegment(
                          value: 'assessment',
                          label: Text(l10n.builderCategoryAssessment),
                        ),
                      ],
                      selected: {_category},
                      onSelectionChanged: _saving
                          ? null
                          : (value) => setState(() => _category = value.single),
                    ),
                  ],
                  SectionHeader(l10n.builderSettings),
                  _settingsCard(l10n, theme),
                  const SizedBox(height: 8),
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: Text(l10n.builderMaterial),
                    children: [
                      AttachmentsEditor(
                        purpose: FilePurpose.assignmentMaterial,
                        schoolId: _classroomId == null ? null : widget.schoolId,
                        classroomId: _classroomId,
                        uploads: uploads,
                        source: source,
                        existingAttachments:
                            widget.existing?.attachments ?? const [],
                        existingLinks: widget.existing?.links ?? const [],
                        enabled: !_saving,
                        onChanged: (value) => setState(() => _material = value),
                      ),
                    ],
                  ),
                  SectionHeader(
                    '${l10n.builderQuestions} · '
                    '${l10n.builderTotal(_points(_total))}',
                  ),
                  if (_locked)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        l10n.builderLocked,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  for (final (index, q) in _questions.indexed)
                    Padding(
                      key: q.key,
                      padding: const EdgeInsets.only(bottom: 12),
                      child: QuestionEditorCard(
                        question: q,
                        number: index + 1,
                        enabled: !_saving && !_locked,
                        schoolId: widget.schoolId,
                        classroomId: _classroomId,
                        uploads: uploads,
                        source: source,
                        onChanged: () => setState(() => _error = null),
                        onMoveUp: index == 0
                            ? null
                            : () => setState(() {
                                _questions.insert(
                                  index - 1,
                                  _questions.removeAt(index),
                                );
                              }),
                        onMoveDown: index == _questions.length - 1
                            ? null
                            : () => setState(() {
                                _questions.insert(
                                  index + 1,
                                  _questions.removeAt(index),
                                );
                              }),
                        onDuplicate: () => setState(
                          () => _questions.insert(index + 1, q.duplicate()),
                        ),
                        onDelete: () => setState(() {
                          _questions.removeAt(index).dispose();
                        }),
                      ),
                    ),
                  if (!_locked && _questions.length < 100)
                    OutlinedButton.icon(
                      onPressed: _saving
                          ? null
                          : () => setState(
                              () => _questions.add(EditableQuestion()),
                            ),
                      icon: const Icon(Icons.add_rounded),
                      label: Text(l10n.builderAddQuestion),
                    ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        _error!,
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _saving || _questions.isEmpty ? null : _preview,
                    icon: const Icon(Icons.visibility_outlined),
                    label: Text(l10n.builderPreview),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (!published)
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _saving
                                ? null
                                : () => _save(publish: false),
                            child: Text(l10n.builderSaveDraft),
                          ),
                        ),
                      if (!published) const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton(
                          onPressed: _saving
                              ? null
                              : () => _save(publish: true),
                          child: _saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  published
                                      ? l10n.paperSave
                                      : l10n.builderPublish,
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }

  Widget _settingsCard(AppL10n l10n, ThemeData theme) => FeatureCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.lock_open_rounded),
          title: Text(l10n.builderOpens),
          subtitle: Text(_when(context, _settings.opensAt)),
          onTap: _saving
              ? null
              : () async {
                  final picked = await _pickDateTime(_settings.opensAt);
                  if (picked != null) _setSettings(opensAt: picked);
                },
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.lock_clock_rounded),
          title: Text(l10n.builderCloses),
          subtitle: Text(_when(context, _settings.closesAt)),
          onTap: _saving
              ? null
              : () async {
                  final picked = await _pickDateTime(_settings.closesAt);
                  if (picked != null) _setSettings(closesAt: picked);
                },
        ),
        Row(
          children: [
            Expanded(child: Text(l10n.builderAttempts)),
            IconButton(
              onPressed: _saving || _settings.maxAttempts <= 1
                  ? null
                  : () => _setSettings(maxAttempts: _settings.maxAttempts - 1),
              icon: const Icon(Icons.remove_circle_outline_rounded),
            ),
            Text(
              '${_settings.maxAttempts}',
              style: theme.textTheme.titleMedium,
            ),
            IconButton(
              onPressed: _saving || _settings.maxAttempts >= 20
                  ? null
                  : () => _setSettings(maxAttempts: _settings.maxAttempts + 1),
              icon: const Icon(Icons.add_circle_outline_rounded),
            ),
          ],
        ),
        if (_settings.maxAttempts > 1) ...[
          Text(l10n.builderPolicy, style: theme.textTheme.bodySmall),
          const SizedBox(height: 4),
          SegmentedButton<AttemptPolicy>(
            segments: [
              ButtonSegment(
                value: AttemptPolicy.best,
                label: Text(l10n.builderPolicyBest),
              ),
              ButtonSegment(
                value: AttemptPolicy.latest,
                label: Text(l10n.builderPolicyLatest),
              ),
            ],
            selected: {_settings.attemptPolicy},
            onSelectionChanged: _saving
                ? null
                : (value) => _setSettings(policy: value.single),
          ),
        ],
        const SizedBox(height: 12),
        Text(l10n.builderRelease, style: theme.textTheme.labelLarge),
        RadioGroup<AnswerRelease>(
          groupValue: _settings.answerRelease,
          onChanged: (value) {
            if (!_saving && value != null) _setSettings(release: value);
          },
          child: Column(
            children: [
              for (final (value, label) in [
                (AnswerRelease.afterClose, l10n.builderReleaseAfterClose),
                (AnswerRelease.afterGrading, l10n.builderReleaseAfterGrading),
                (AnswerRelease.manual, l10n.builderReleaseManual),
              ])
                RadioListTile<AnswerRelease>(
                  value: value,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(label),
                ),
            ],
          ),
        ),
        Text(l10n.builderReleaseNote, style: theme.textTheme.bodySmall),
      ],
    ),
  );
}
