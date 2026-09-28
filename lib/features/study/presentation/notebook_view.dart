import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/attachment_field.dart';
import '../../../core/attachment_opener.dart';
import '../../../core/attachment_policy.dart';
import '../../../core/file_upload_repository.dart';
import '../../../core/user_content_text.dart';
import '../domain/study.dart';
import '../../../l10n/generated/app_l10n.dart';

/// A student's own notebook for one class, newest first, grouped by day.
///
/// Typing a note is free. "Snap the whiteboard" is Studafy Plus: the photo is
/// uploaded through the normal file pipeline, and once it has been checked
/// the server turns it into notes and files them here.
class NotebookView extends StatefulWidget {
  const NotebookView({
    super.key,
    required this.study,
    required this.classroomId,
    required this.onOpenPlans,
    this.schoolId,
    this.uploads,
    this.source,
    this.readyTimeout = const Duration(seconds: 40),
    this.readyPoll = const Duration(seconds: 2),
  });

  final StudyRepository study;
  final String classroomId;

  /// Opens the Plans screen, from a locked feature.
  final VoidCallback onOpenPlans;

  /// Where a whiteboard photo is uploaded. Without both, only typed notes are
  /// offered.
  final String? schoolId;
  final FileUploadRepository? uploads;

  /// The photo picker. Tests supply their own.
  final AttachmentSource? source;

  /// How long to wait for a new photo to clear the scan, and how often to ask.
  final Duration readyTimeout;
  final Duration readyPoll;

  @override
  State<NotebookView> createState() => _NotebookViewState();
}

class _NotebookViewState extends State<NotebookView> {
  List<NotebookEntry> _entries = const [];
  StudyPlan? _plan;
  bool _loading = true;
  bool _failed = false;
  String? _working;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final entries = await widget.study.notebook(widget.classroomId);
      StudyPlan? plan;
      try {
        plan = await widget.study.plan();
      } on Object {
        plan = null;
      }
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _plan = plan;
        _loading = false;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  void _say(String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));

  String _refusalText(StudyRefusal refusal) => switch (refusal) {
    StudyRefusal.planRequired => AppL10n.of(
      context,
    ).notebookThisNeedsStudafyPlus,
    StudyRefusal.allowanceUsed => AppL10n.of(
      context,
    ).studySetThisMonthSAiAllowance,
    StudyRefusal.photoUnreadable => AppL10n.of(
      context,
    ).notebookNoWritingCouldBeRead,
    StudyRefusal.photoNotReady => AppL10n.of(
      context,
    ).notebookThePhotoIsTakingLonger,
    StudyRefusal.unavailable => AppL10n.of(
      context,
    ).studySetThisIsNotAvailableYet,
    _ => AppL10n.of(context).studySetThatDidNotWorkPlease,
  };

  Future<void> _addNote() async {
    final title = TextEditingController();
    final body = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppL10n.of(context).notebookNewNote),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: title,
                maxLength: 200,
                decoration: InputDecoration(
                  labelText: AppL10n.of(context).announcementTitleLabel,
                ),
              ),
              TextField(
                controller: body,
                minLines: 4,
                maxLines: 10,
                maxLength: 20000,
                decoration: InputDecoration(
                  labelText: AppL10n.of(context).academicNoteBodyLabel,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(
              MaterialLocalizations.of(dialogContext).cancelButtonLabel,
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(AppL10n.of(context).notebookSave),
          ),
        ],
      ),
    );
    if (saved != true || !mounted) return;
    if (title.text.trim().isEmpty || body.text.trim().isEmpty) {
      _say(AppL10n.of(context).notebookAddATitleAndSome);
      return;
    }
    setState(() => _working = AppL10n.of(context).scheduleSaving);
    try {
      await widget.study.addNote(
        widget.classroomId,
        title: title.text.trim(),
        body: body.text.trim(),
      );
      await _load();
    } on StudyException catch (error) {
      _say(_refusalText(error.refusal));
    } finally {
      if (mounted) setState(() => _working = null);
    }
  }

  Future<void> _snapWhiteboard(AttachmentKind kind) async {
    // Read before the first await: the messages below are shown after one.
    final l10n = AppL10n.of(context);
    final plan = _plan;
    if (plan == null || !plan.canSnapWhiteboard) {
      widget.onOpenPlans();
      return;
    }
    final uploads = widget.uploads;
    final schoolId = widget.schoolId;
    final source = widget.source;
    if (uploads == null || schoolId == null || source == null) return;

    final policy = AttachmentPolicy.of(FilePurpose.notebookPhoto);
    final picked = await source(kind, policy);
    if (picked == null || !mounted) return;
    if (policy.refuse(
          mediaType: picked.mediaType,
          sizeBytes: picked.bytes.length,
        ) !=
        null) {
      _say(l10n.notebookChooseAJpegOrPng);
      return;
    }

    setState(() => _working = l10n.notebookUploadingThePhoto);
    try {
      final stored = await uploads.upload(
        FileUploadCommand(
          attemptId: 'whiteboard-${DateTime.now().microsecondsSinceEpoch}',
          schoolId: schoolId,
          purpose: FilePurpose.notebookPhoto,
          displayName: sanitiseAttachmentName(picked.displayName),
          mediaType: picked.mediaType,
          bytes: picked.bytes,
          classroomId: widget.classroomId,
        ),
      );
      if (!mounted) return;
      setState(() => _working = l10n.notebookReadingTheWhiteboard);
      // A new photo is checked before anything may read it; ask until it is.
      final deadline = DateTime.now().add(widget.readyTimeout);
      while (true) {
        try {
          await widget.study.whiteboardNote(widget.classroomId, stored.id);
          break;
        } on StudyException catch (error) {
          if (error.refusal != StudyRefusal.photoNotReady ||
              DateTime.now().isAfter(deadline)) {
            rethrow;
          }
          await Future<void>.delayed(widget.readyPoll);
          if (!mounted) return;
        }
      }
      _say(l10n.notebookNotesAddedToYourNotebook);
      await _load();
    } on StudyException catch (error) {
      if (error.refusal == StudyRefusal.planRequired) widget.onOpenPlans();
      _say(_refusalText(error.refusal));
    } on Object {
      _say(l10n.notebookThePhotoCouldNotBe);
    } finally {
      if (mounted) setState(() => _working = null);
    }
  }

  Future<void> _delete(NotebookEntry entry) async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppL10n.of(context).notebookDeleteThisNote),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(
              MaterialLocalizations.of(dialogContext).cancelButtonLabel,
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(AppL10n.of(context).notebookDelete),
          ),
        ],
      ),
    );
    if (sure != true || !mounted) return;
    try {
      await widget.study.deleteNote(entry.id);
      await _load();
    } on StudyException catch (error) {
      _say(_refusalText(error.refusal));
    }
  }

  static DateTime _day(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  String _heading(DateTime day) {
    final today = _day(DateTime.now());
    if (day == today) return AppL10n.of(context).notebookToday;
    if (day == today.subtract(const Duration(days: 1))) {
      return AppL10n.of(context).notebookYesterday;
    }
    return MaterialLocalizations.of(context).formatFullDate(day);
  }

  Widget _actions() {
    final locked = !(_plan?.canSnapWhiteboard ?? false);
    final canUpload = widget.uploads != null && widget.schoolId != null;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 12, 12, 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          FilledButton.tonalIcon(
            onPressed: _working != null ? null : _addNote,
            icon: const Icon(Icons.edit_note_rounded),
            label: Text(AppL10n.of(context).notebookAddNote),
          ),
          if (canUpload)
            FilledButton.icon(
              onPressed: _working != null
                  ? null
                  : () => _snapWhiteboard(AttachmentKind.camera),
              icon: Icon(
                locked
                    ? Icons.lock_outline_rounded
                    : Icons.photo_camera_outlined,
              ),
              label: Text(AppL10n.of(context).notebookSnapTheWhiteboard),
            ),
          if (canUpload && !locked)
            OutlinedButton.icon(
              onPressed: _working != null
                  ? null
                  : () => _snapWhiteboard(AttachmentKind.photo),
              icon: const Icon(Icons.photo_library_outlined),
              label: Text(AppL10n.of(context).notebookFromPhotos),
            ),
          if (locked)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                AppL10n.of(context).notebookWhiteboardNotesComeWithStudafy,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_failed) {
      return Center(
        child: TextButton(
          onPressed: _load,
          child: Text(AppL10n.of(context).notebookTheNotebookCouldNotBe),
        ),
      );
    }
    final children = <Widget>[_actions()];
    if (_working != null) {
      children.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_working!),
              const SizedBox(height: 6),
              const LinearProgressIndicator(),
            ],
          ),
        ),
      );
    }
    if (_entries.isEmpty) {
      children.add(
        Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            AppL10n.of(context).notebookYourNotebookForThisClass,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    DateTime? current;
    for (final entry in _entries) {
      final day = _day(entry.createdAt);
      if (day != current) {
        children.add(
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 6),
            child: Semantics(
              header: true,
              child: Text(
                _heading(day),
                style: Theme.of(context).textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        );
        current = day;
      }
      children.add(
        Card(
          margin: const EdgeInsetsDirectional.fromSTEB(12, 0, 12, 10),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(14, 8, 4, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (entry.fromWhiteboard)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(end: 6),
                        child: Tooltip(
                          message: AppL10n.of(context)
                              .notebookFromTheWhiteboard,
                          child: const Icon(
                            Icons.auto_awesome_rounded,
                            size: 18,
                          ),
                        ),
                      ),
                    Expanded(
                      child: UserContentText(
                        entry.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    Text(
                      MaterialLocalizations.of(context).formatTimeOfDay(
                        TimeOfDay.fromDateTime(entry.createdAt),
                      ),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    IconButton(
                      tooltip: AppL10n.of(context).notebookDelete,
                      onPressed: () => _delete(entry),
                      icon: const Icon(Icons.delete_outline_rounded),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 10),
                  child: UserContentText(entry.body),
                ),
                if (entry.photo case final photo?)
                  StoredAttachmentList(
                    attachments: [photo],
                    uploads: widget.uploads,
                    dense: true,
                  ),
              ],
            ),
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(children: children),
    );
  }
}
