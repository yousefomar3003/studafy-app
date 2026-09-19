import 'package:flutter/material.dart';

import '../domain/academic_repository.dart';

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
      title: const Text('Academic workspace'),
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
                    label: Text(value.name),
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
                return const Center(child: Text('No records yet.'));
              }
              return RefreshIndicator(
                onRefresh: () async => _refresh(),
                child: ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return ListTile(
                      title: Text(item.title),
                      subtitle: Text(item.detail),
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
                label: const Text('File text lesson note'),
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
          title: const Text('Text lesson note'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: title,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              TextField(
                controller: body,
                maxLines: 5,
                decoration: const InputDecoration(labelText: 'Note'),
              ),
              const SizedBox(height: 8),
              const Text('Attachments are unavailable until FILE-050/051.'),
              if (error != null)
                Text(error!, style: const TextStyle(color: Colors.red)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
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
                    () => error =
                        'Not saved. Your text is kept here so you can retry.',
                  );
                }
              },
              child: const Text('Save to school'),
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
        const Text('School data is unavailable. No local copy was saved.'),
        const SizedBox(height: 12),
        OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    ),
  );
}
