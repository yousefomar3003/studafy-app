import 'package:flutter/material.dart';

import '../domain/academic_repository.dart';
import '../../../core/user_content_text.dart';
import '../../../l10n/generated/app_l10n.dart';

/// Typed, server-authoritative academic feed used by remote teacher, student,
/// and guardian shells. Draft input remains in memory when a request fails;
/// success is shown only after the API returns its canonical resource.
class AcademicOverviewPage extends StatefulWidget {
  const AcademicOverviewPage({
    super.key,
    required this.repository,
    this.classroomId,
    this.studentId,
    this.teacherTools = false,
    this.initialFeed = AcademicFeed.assignments,
    this.actions = const [],
  });

  final AcademicRepository repository;
  final String? classroomId;
  final String? studentId;
  final bool teacherTools;
  final AcademicFeed initialFeed;

  /// App bar actions supplied by the host shell, such as its account entry.
  final List<Widget> actions;

  @override
  State<AcademicOverviewPage> createState() => _AcademicOverviewPageState();
}

class _AcademicOverviewPageState extends State<AcademicOverviewPage> {
  late AcademicFeed feed;
  late Future<List<AcademicRecord>> future;

  @override
  void initState() {
    super.initState();
    feed = widget.initialFeed;
    future = _load();
  }

  Future<List<AcademicRecord>> _load() => widget.repository.load(
    feed,
    classroomId: widget.classroomId,
    studentId: widget.studentId,
  );

  void _refresh() {
    setState(() {
      future = _load();
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(AppL10n.of(context).academicTitle),
      actions: widget.actions,
    ),
    body: Column(
      children: [
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              for (final value in AcademicFeed.values)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text(_feedLabel(AppL10n.of(context), value)),
                    selected: feed == value,
                    onSelected: (_) => setState(() {
                      feed = value;
                      future = _load();
                    }),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<AcademicRecord>>(
            future: future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return _Unavailable(onRetry: _refresh);
              }
              final items = snapshot.data ?? const <AcademicRecord>[];
              if (items.isEmpty) {
                return Center(
                  child: Text(AppL10n.of(context).academicNoRecords),
                );
              }
              return RefreshIndicator(
                onRefresh: () async => _refresh(),
                child: ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    // Titles and details are school-authored content, so
                    // they render verbatim in their own direction.
                    return ListTile(
                      title: UserContentText(item.title),
                      subtitle: UserContentText(item.detail),
                      trailing: Chip(label: Text(item.state)),
                    );
                  },
                ),
              );
            },
          ),
        ),
        if (widget.teacherTools && feed == AcademicFeed.content)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: FilledButton.icon(
                onPressed: widget.classroomId == null ? null : _fileNote,
                icon: const Icon(Icons.note_add_outlined),
                label: Text(AppL10n.of(context).academicFileNote),
              ),
            ),
          ),
      ],
    ),
  );

  Future<void> _fileNote() async {
    final title = TextEditingController();
    final body = TextEditingController();
    String? error;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(AppL10n.of(context).academicNoteTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: title,
                decoration: InputDecoration(
                  labelText: AppL10n.of(context).academicNoteTitleLabel,
                ),
              ),
              TextField(
                controller: body,
                maxLines: 5,
                decoration: InputDecoration(
                  labelText: AppL10n.of(context).academicNoteBodyLabel,
                ),
              ),
              const SizedBox(height: 8),
              Text(AppL10n.of(context).academicAttachmentsUnavailable),
              if (error != null)
                Text(error!, style: const TextStyle(color: Colors.red)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(AppL10n.of(context).academicCancel),
            ),
            FilledButton(
              onPressed: () async {
                try {
                  await widget.repository.createResource(
                    TextResourceDraft(
                      classroomId: widget.classroomId!,
                      title: title.text,
                      body: body.text,
                    ),
                  );
                  if (!dialogContext.mounted) return;
                  Navigator.pop(dialogContext);
                  _refresh();
                } catch (_) {
                  setDialogState(
                    () => error = AppL10n.of(context).academicNoteNotSaved,
                  );
                }
              },
              child: Text(AppL10n.of(context).academicSaveToSchool),
            ),
          ],
        ),
      ),
    );
  }
}

class _Unavailable extends StatelessWidget {
  const _Unavailable({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(AppL10n.of(context).academicUnavailable),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: onRetry,
          child: Text(AppL10n.of(context).academicRetry),
        ),
      ],
    ),
  );
}

/// The reader's name for a feed tab. The enum names are the app's vocabulary,
/// never the user's.
String _feedLabel(AppL10n l10n, AcademicFeed feed) => switch (feed) {
  AcademicFeed.content => l10n.feedContent,
  AcademicFeed.assignments => l10n.feedAssignments,
  AcademicFeed.assessments => l10n.feedAssessments,
  AcademicFeed.grades => l10n.feedGrades,
  AcademicFeed.attendance => l10n.feedAttendance,
  AcademicFeed.wellbeing => l10n.feedWellbeing,
};
