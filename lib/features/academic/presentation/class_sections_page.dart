import 'package:flutter/material.dart';

import '../../../l10n/generated/app_l10n.dart';
import '../domain/academic_repository.dart';

/// The sections of a class that have been taught, and what was taught in them.
///
/// The school's rule is enforced here in the shape of the screen: a section
/// cannot be closed until content has been filed against it. The surface
/// refuses it too, so this is a clearer path to the same answer rather than
/// the only thing standing in the way.
///
/// Attendance is deliberately not gated on filing. A teacher in front of a
/// class must always be able to mark a register; the obligation lands at the
/// end of the lesson.
class ClassSectionsPage extends StatefulWidget {
  const ClassSectionsPage({
    super.key,
    required this.repository,
    required this.classroomId,
    required this.classroomName,
  });

  final AcademicRepository repository;
  final String classroomId;
  final String classroomName;

  @override
  State<ClassSectionsPage> createState() => _ClassSectionsPageState();
}

class _ClassSectionsPageState extends State<ClassSectionsPage> {
  List<LessonSession> _sessions = const [];
  bool _loading = true;
  bool _busy = false;
  String? _error;
  String? _notice;
  late String _loadFailed;
  late String _saveFailed;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final l10n = AppL10n.of(context);
    _loadFailed = l10n.sectionsLoadFailed;
    _saveFailed = l10n.sectionsSaveFailed;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final sessions = await widget.repository.lessonSessions(
        widget.classroomId,
      );
      if (!mounted) return;
      setState(() {
        _sessions = sessions;
        _loading = false;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _loadFailed;
      });
    }
  }

  Future<void> _fileContent(LessonSession session) async {
    final l10n = AppL10n.of(context);
    final title = TextEditingController(
      text: session.title ?? l10n.sectionsContentTitle,
    );
    final body = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.sectionsContentTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: title,
              decoration: InputDecoration(
                labelText: l10n.sectionsContentTitleLabel,
              ),
            ),
            TextField(
              controller: body,
              minLines: 3,
              maxLines: 6,
              decoration: InputDecoration(
                labelText: l10n.sectionsContentBodyLabel,
              ),
            ),
          ],
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
            child: Text(l10n.sectionsContentSave),
          ),
        ],
      ),
    );
    if (saved != true || !mounted) return;
    if (body.text.trim().isEmpty) {
      setState(() => _error = l10n.sectionsContentRequired);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final filed = l10n.sectionsContentSaved;
    try {
      await widget.repository.createResource(
        TextResourceDraft(
          classroomId: widget.classroomId,
          title: title.text.trim().isEmpty
              ? l10n.sectionsContentTitle
              : title.text.trim(),
          body: body.text.trim(),
          lessonSessionId: session.id,
        ),
      );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _notice = filed;
      });
      await _load();
    } on Object {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = _saveFailed;
      });
    }
  }

  Future<void> _close(LessonSession session) async {
    final l10n = AppL10n.of(context);
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    final closed = l10n.sectionsClosed;
    final blocked = l10n.sectionsCloseBlocked;
    try {
      await widget.repository.closeLessonSession(session.id);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _notice = closed;
      });
      await _load();
    } on Object {
      if (!mounted) return;
      // The surface refuses an unfiled section, which is the common reason
      // to land here, so it is named rather than reported as a failure.
      setState(() {
        _busy = false;
        _error = blocked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.sectionsTitle(widget.classroomName))),
      body: SafeArea(
        child: Column(
          children: [
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (_notice != null)
              Padding(padding: const EdgeInsets.all(12), child: Text(_notice!)),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _sessions.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          l10n.sectionsNone,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: _sessions.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, i) => _SectionTile(
                        session: _sessions[i],
                        busy: _busy,
                        onFile: () => _fileContent(_sessions[i]),
                        onClose: () => _close(_sessions[i]),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTile extends StatelessWidget {
  const _SectionTile({
    required this.session,
    required this.busy,
    required this.onFile,
    required this.onClose,
  });

  final LessonSession session;
  final bool busy;
  final VoidCallback onFile;
  final VoidCallback onClose;

  static String _when(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')} '
      '${value.hour.toString().padLeft(2, '0')}:'
      '${value.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_when(session.startsAt), style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                session.filed
                    ? Icons.check_circle_outline
                    : Icons.error_outline,
                size: 18,
                color: session.filed
                    ? theme.colorScheme.primary
                    : theme.colorScheme.error,
              ),
              const SizedBox(width: 6),
              Text(
                session.filed ? l10n.sectionsFiled : l10n.sectionsOutstanding,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
          if (!session.filed) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: busy ? null : onFile,
                  icon: const Icon(Icons.note_add_outlined, size: 18),
                  label: Text(l10n.sectionsFileContent),
                ),
                FilledButton.tonal(
                  onPressed: busy ? null : onClose,
                  child: Text(l10n.sectionsClose),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
