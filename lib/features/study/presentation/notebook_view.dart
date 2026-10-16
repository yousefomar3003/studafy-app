import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/attachment_field.dart';
import '../../../core/attachment_opener.dart';
import '../../../core/attachment_policy.dart';
import '../../../core/feedback.dart';
import '../../../core/file_upload_repository.dart';
import '../../../core/material_selection.dart';
import '../../../core/material_unavailable_dialog.dart';
import '../../../core/studafy_design.dart';
import '../../../core/studafy_formatting.dart';
import '../../../core/user_content_text.dart';
import '../../../l10n/generated/app_l10n.dart';
import '../domain/study.dart';
import 'notes_text.dart';
import 'upgrade_prompt.dart';

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
    this.pickLesson,
    this.header,
    this.pick,
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

  /// Lets the student choose one of this class's lessons to turn into notes.
  /// Lessons live in another feature, so the host supplies the picker; null
  /// hides "From a lesson".
  final Future<LessonChoice?> Function(BuildContext context)? pickLesson;

  /// Shown above the notes: the class's study notebooks.
  final Widget? header;

  /// Chooses exactly what study notes are made from (ADR-0039). Null makes
  /// them from a whole lesson.
  final MaterialPicker? pick;

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

  /// Once the notebook has been shown, a reload (after adding a note or a
  /// photo) keeps it on screen and swaps in the new entries when they come.
  bool _loaded = false;

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = !_loaded;
      _failed = false;
    });
    try {
      // Both at once: the plan only decides whether photos are offered.
      final planRead = widget.study.plan().then<StudyPlan?>(
        (plan) => plan,
        onError: (Object _) => null,
      );
      final entries = await widget.study.notebook(widget.classroomId);
      final plan = await planRead;
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _plan = plan;
        _loading = false;
        _loaded = true;
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
      ScaffoldMessenger.of(context).showMessage(message);

  /// A refusal because of the plan explains itself and offers the upgrade;
  /// anything else is a short message.
  Future<void> _refused(StudyRefusal refusal) async {
    final reason = upgradeReasonFor(refusal);
    if (reason == null) {
      _say(_refusalText(refusal));
      return;
    }
    StudyPlan? plan;
    try {
      plan = await widget.study.plan();
    } on Object {
      plan = null;
    }
    if (!mounted) return;
    await showUpgradePrompt(
      context,
      reason: reason,
      plan: plan,
      // Whiteboard and lesson notes are Studafy Plus.
      needs: StudyPlanTier.plus,
      onUpgrade: widget.onOpenPlans,
    );
  }

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
    StudyRefusal.lessonHasNoText => AppL10n.of(
      context,
    ).studySetThisLessonHasNoText,
    StudyRefusal.materialProcessing => AppL10n.of(
      context,
    ).studySetMaterialProcessing,
    StudyRefusal.aiConsent => AppL10n.of(context).aiConsentNeeded,
    _ => AppL10n.of(context).studySetThatDidNotWorkPlease,
  };

  /// A lesson, chosen by the student, into their notebook: as the teacher
  /// wrote it (free), or turned into study notes (Studafy Plus).
  Future<void> _fromLesson() async {
    final pick = widget.pickLesson;
    if (pick == null) return;
    final lesson = await pick(context);
    if (lesson == null || !mounted) return;
    final l10n = AppL10n.of(context);
    final canCopy = lesson.text.trim().isNotEmpty;
    final canMakeNotes = _plan?.canSnapWhiteboard ?? false;
    // Study notes are written by the AI: not offered where it is off.
    final notesOn = _plan?.notebooksOn ?? false;
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: UserContentText(
                lesson.title,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.content_copy_rounded),
              title: Text(l10n.notebookCopyLesson),
              subtitle: Text(l10n.notebookCopyLessonDetail),
              enabled: canCopy,
              onTap: () => Navigator.pop(sheetContext, 'copy'),
            ),
            if (notesOn)
              ListTile(
                leading: Icon(
                  canMakeNotes
                      ? Icons.auto_awesome_rounded
                      : Icons.lock_outline_rounded,
                ),
                title: Text(l10n.notebookLessonNotes),
                subtitle: Text(l10n.notebookLessonNotesDetail),
                onTap: () => Navigator.pop(sheetContext, 'notes'),
              ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    if (choice == 'notes' && !canMakeNotes) {
      widget.onOpenPlans();
      return;
    }
    setState(() => _working = AppL10n.of(context).scheduleSaving);
    try {
      if (choice == 'copy') {
        await widget.study.addNote(
          widget.classroomId,
          title: lesson.title,
          body: lesson.text,
        );
      } else if (widget.pick != null) {
        setState(() => _working = null);
        await _summarise(preselect: lesson.id);
        return;
      } else {
        await widget.study.lessonNotes(lesson.id);
      }
      _say(l10n.notebookLessonCopied);
      await _load();
    } on StudyException catch (error) {
      await _refused(error.refusal);
    } finally {
      if (mounted) setState(() => _working = null);
    }
  }

  /// Study notes from exactly the material the student chooses, filed
  /// here, ending with what they were made from.
  Future<void> _summarise({String? preselect}) async {
    final pick = widget.pick;
    if (pick == null) return;
    final l10n = AppL10n.of(context);
    if (!(_plan?.canSnapWhiteboard ?? false)) {
      await _refused(StudyRefusal.planRequired);
      return;
    }
    final selection = await pick(
      context,
      MaterialPickRequest(
        action: MaterialAction.summary,
        preselectLessonId: preselect,
        onlyClassroomId: widget.classroomId,
      ),
    );
    if (selection == null || selection.isEmpty || !mounted) return;
    final language = Localizations.localeOf(context).languageCode;
    setState(() => _working = l10n.notebookMakingNotes);
    var skip = false;
    try {
      while (true) {
        try {
          await widget.study.summarise(
            widget.classroomId,
            selection,
            skipUnavailable: skip,
            language: language,
          );
          break;
        } on MaterialUnavailableException catch (error) {
          if (!mounted || skip) return;
          skip = await confirmContinueWithout(
            context,
            error,
            selection: selection,
          );
          if (!skip) return;
        }
      }
      _say(l10n.notebookLessonCopied);
      await _load();
    } on StudyException catch (error) {
      await _refused(error.refusal);
    } finally {
      if (mounted) setState(() => _working = null);
    }
  }

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
      await _refused(error.refusal);
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
    return studafyFullDate(context, day);
  }

  Widget _actions() {
    final locked = !(_plan?.canSnapWhiteboard ?? false);
    // The AI's buttons only where the server offers the AI: notes from
    // chosen material, and from a photo of the whiteboard. Not before the
    // plan has said.
    final notesOn = _plan?.notebooksOn ?? false;
    final whiteboardOn = _plan?.whiteboardOn ?? false;
    final canUpload =
        whiteboardOn && widget.uploads != null && widget.schoolId != null;
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
          if (widget.pickLesson != null)
            FilledButton.tonalIcon(
              onPressed: _working != null ? null : _fromLesson,
              icon: const Icon(Icons.menu_book_rounded),
              label: Text(AppL10n.of(context).notebookFromLesson),
            ),
          if (notesOn && widget.pick != null)
            FilledButton.tonalIcon(
              onPressed: _working != null ? null : () => _summarise(),
              icon: Icon(
                locked
                    ? Icons.lock_outline_rounded
                    : Icons.auto_awesome_rounded,
              ),
              label: Text(AppL10n.of(context).pickActionSummary),
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
          if (locked && canUpload)
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
    final children = <Widget>[?widget.header, _actions()];
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
                    if (entry.fromLesson)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(end: 6),
                        child: Tooltip(
                          message: AppL10n.of(context).notebookFromLessonBadge,
                          child: const Icon(Icons.menu_book_rounded, size: 18),
                        ),
                      ),
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
                      studafyTimeOfDay(
                        context,
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
                  child: NotesText(entry.body),
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
    return StudafyRefreshIndicator(
      onRefresh: _load,
      child: ListView(children: children),
    );
  }
}
