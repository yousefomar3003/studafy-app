import 'package:flutter/material.dart';

import '../../../core/feedback.dart';
import '../../../core/navigation.dart';
import '../../../core/studafy_design.dart';
import '../../../core/study_markdown.dart';
import '../../../core/unsaved_changes.dart';
import '../../../core/user_content_text.dart';
import '../../../l10n/generated/app_l10n.dart';
import '../domain/study.dart';
import 'notebook_paper.dart';

/// One page of the Notebook: the note on ruled paper, its Markdown laid out
/// as headings, bullet points and bold terms, with Edit, Rename and Delete.
///
/// [embedded] is the page beside the list on a wide screen: no app bar of
/// its own, its actions in a row above the paper.
class NotePage extends StatefulWidget {
  const NotePage({
    super.key,
    required this.study,
    required this.entry,
    this.embedded = false,
    this.onChanged,
    this.onDeleted,
    this.onPractise,
  });

  final StudyRepository study;
  final NotebookEntry entry;
  final bool embedded;

  /// The note after an edit or a rename.
  final ValueChanged<NotebookEntry>? onChanged;
  final VoidCallback? onDeleted;

  /// A quiz or flashcards from this note. Null hides the action.
  final ValueChanged<NotebookEntry>? onPractise;

  @override
  State<NotePage> createState() => _NotePageState();
}

class _NotePageState extends State<NotePage> {
  late NotebookEntry _entry = widget.entry;

  @override
  void didUpdateWidget(NotePage old) {
    super.didUpdateWidget(old);
    if (old.entry.id != widget.entry.id ||
        old.entry.changedAt != widget.entry.changedAt) {
      _entry = widget.entry;
    }
  }

  void _changed(NotebookEntry next) {
    setState(() => _entry = next);
    widget.onChanged?.call(next);
  }

  Future<void> _edit() async {
    final edited = await Navigator.of(context).pushOnce<NotebookEntry>(
      MaterialPageRoute<NotebookEntry>(
        builder: (_) => NoteEditorPage(
          initial: _entry,
          save: (title, body) => widget.study.editNote(
            _entry.id,
            title: title == _entry.title ? null : title,
            body: body == _entry.body ? null : body,
          ),
        ),
      ),
    );
    if (edited != null && mounted) _changed(edited);
  }

  Future<void> _rename() async {
    final l10n = AppL10n.of(context);
    final title = await showDialog<String>(
      context: context,
      builder: (_) => _RenameDialog(initial: _entry.title),
    );
    if (title == null || title == _entry.title || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      _changed(await widget.study.editNote(_entry.id, title: title));
      messenger.showMessage(l10n.noteSaved);
    } on Object {
      messenger.showMessage(l10n.noteSaveFailed);
    }
  }

  Future<void> _delete() async {
    final l10n = AppL10n.of(context);
    final sure = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(l10n.notebookDeleteThisNote),
        content: Text(l10n.noteDeleteBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: Text(l10n.upgradeNotNow),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: studafyDanger),
            onPressed: () => Navigator.pop(dialog, true),
            child: Text(l10n.notebookDelete),
          ),
        ],
      ),
    );
    if (sure != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await widget.study.deleteNote(_entry.id);
      widget.onDeleted?.call();
      if (!widget.embedded && navigator.canPop()) navigator.pop();
    } on Object {
      messenger.showMessage(l10n.noteSaveFailed);
    }
  }

  List<Widget> _actions(AppL10n l10n) => [
    IconButton(
      tooltip: l10n.nbEdit,
      onPressed: _edit,
      icon: const Icon(Icons.edit_outlined),
    ),
    PopupMenuButton<String>(
      onSelected: (value) => switch (value) {
        'rename' => _rename(),
        'practise' => widget.onPractise?.call(_entry),
        _ => _delete(),
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'rename',
          child: ListTile(
            leading: const Icon(Icons.drive_file_rename_outline_rounded),
            title: Text(l10n.nbRename),
          ),
        ),
        if (widget.onPractise != null)
          PopupMenuItem(
            value: 'practise',
            child: ListTile(
              leading: const Icon(Icons.style_outlined),
              title: Text(l10n.nbPractise),
            ),
          ),
        PopupMenuItem(
          value: 'delete',
          child: ListTile(
            leading: const Icon(
              Icons.delete_outline_rounded,
              color: studafyDanger,
            ),
            title: Text(l10n.notebookDelete),
          ),
        ),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final paper = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: RuledPage(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: UserContentText(
                  _entry.title,
                  style: const TextStyle(
                    color: studafyInk,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    noteDateLine(context, _entry),
                    style: const TextStyle(color: studafyMuted, fontSize: 13),
                  ),
                  NoteSourceBadge(_entry),
                ],
              ),
              const SizedBox(height: 18),
              StudyMarkdown(_entry.body, fontSize: 16, lineHeight: 1.7),
            ],
          ),
        ),
      ),
    );
    if (widget.embedded) {
      return ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 32),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: _actions(l10n),
          ),
          paper,
        ],
      );
    }
    return Scaffold(
      backgroundColor: studafyCanvas,
      appBar: AppBar(
        backgroundColor: studafyCanvas,
        title: UserContentText(_entry.title, maxLines: 1),
        actions: _actions(l10n),
      ),
      body: ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 40),
        children: [paper],
      ),
    );
  }
}

class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.initial});

  final String initial;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final _title = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  void _done() {
    final title = _title.text.trim();
    if (title.isEmpty) return;
    Navigator.pop(context, title);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return AlertDialog(
      title: Text(l10n.nbRenameTitle),
      content: TextField(
        controller: _title,
        autofocus: true,
        maxLength: 200,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _done(),
        decoration: InputDecoration(labelText: l10n.nbTitleLabel),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.upgradeNotNow),
        ),
        FilledButton(onPressed: _done, child: Text(l10n.notebookSave)),
      ],
    );
  }
}

/// Writing a note, or changing one: a title and the page, on paper. The
/// text may use simple Markdown - # for a heading, - for a bullet point,
/// ** for bold - and the page shows it laid out.
///
/// Returns the saved note. Leaving with unsaved text asks first.
class NoteEditorPage extends StatefulWidget {
  const NoteEditorPage({super.key, required this.save, this.initial});

  final Future<NotebookEntry> Function(String title, String body) save;
  final NotebookEntry? initial;

  @override
  State<NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends State<NoteEditorPage> {
  late final _title = TextEditingController(text: widget.initial?.title);
  late final _body = TextEditingController(text: widget.initial?.body);
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _title.addListener(_rebuild);
    _body.addListener(_rebuild);
  }

  void _rebuild() => setState(() {});

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  bool get _dirty =>
      _title.text != (widget.initial?.title ?? '') ||
      _body.text != (widget.initial?.body ?? '');

  Future<void> _save() async {
    final l10n = AppL10n.of(context);
    final title = _title.text.trim();
    final body = _body.text.trim();
    if (title.isEmpty || body.isEmpty) {
      setState(() => _error = l10n.notebookAddATitleAndSome);
      return;
    }
    if (!_dirty && widget.initial != null) {
      Navigator.pop(context, widget.initial);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final saved = await widget.save(title, body);
      if (!mounted) return;
      _saving = false;
      Navigator.pop(context, saved);
    } on StudyException catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error.refusal == StudyRefusal.aiConsent
            ? l10n.aiConsentNeeded
            : l10n.noteSaveFailed;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = l10n.noteSaveFailed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    const plain = InputDecoration(
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      filled: false,
      counterText: '',
    );
    return UnsavedChangesScope(
      unsaved: _dirty && !_saving,
      child: Scaffold(
        backgroundColor: studafyCanvas,
        appBar: AppBar(
          backgroundColor: studafyCanvas,
          title: Text(widget.initial == null ? l10n.nbNewNote : l10n.nbEdit),
          actions: [
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 12),
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.notebookSave),
              ),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 40),
          children: [
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    _error!,
                    style: const TextStyle(color: studafyDanger),
                  ),
                ),
              ),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: RuledPage(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _title,
                        maxLength: 200,
                        textCapitalization: TextCapitalization.sentences,
                        style: const TextStyle(
                          color: studafyInk,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                        decoration: plain.copyWith(
                          hintText: l10n.nbTitleLabel,
                          labelText: null,
                        ),
                      ),
                      TextField(
                        controller: _body,
                        maxLength: 20000,
                        minLines: 12,
                        maxLines: null,
                        keyboardType: TextInputType.multiline,
                        textCapitalization: TextCapitalization.sentences,
                        style: const TextStyle(
                          color: studafyInk,
                          fontSize: 16,
                          height: 1.7,
                        ),
                        decoration: plain.copyWith(hintText: l10n.nbBodyHint),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
