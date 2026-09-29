import 'package:flutter/material.dart';

import '../../../core/user_content_text.dart';
import '../../../l10n/generated/app_l10n.dart';
import '../domain/study.dart';

/// Every notebook the student has, one per class. A class the teacher has
/// deleted is still here, marked as gone: the notes were always the
/// student's, and deleting the class takes none of them away.
class MyNotebooksPage extends StatefulWidget {
  const MyNotebooksPage({super.key, required this.study});

  final StudyRepository study;

  @override
  State<MyNotebooksPage> createState() => _MyNotebooksPageState();
}

class _MyNotebooksPageState extends State<MyNotebooksPage> {
  late Future<List<NotebookGroup>> _groups = widget.study.myNotebooks();

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.notebookMyNotebooks)),
      body: FutureBuilder<List<NotebookGroup>>(
        future: _groups,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: TextButton(
                onPressed: () =>
                    setState(() => _groups = widget.study.myNotebooks()),
                child: Text(l10n.studySetTryAgain),
              ),
            );
          }
          final groups = snapshot.data ?? const <NotebookGroup>[];
          if (groups.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  l10n.notebookNoNotebooks,
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              for (final group in groups)
                Card(
                  child: ExpansionTile(
                    leading: Icon(
                      group.classGone
                          ? Icons.inventory_2_outlined
                          : Icons.menu_book_rounded,
                    ),
                    title: UserContentText(
                      group.className,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      group.classGone
                          ? l10n.notebookClassGone
                          : l10n.notebookNoteCount(group.entries.length),
                    ),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    children: [
                      for (final entry in group.entries)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: UserContentText(entry.title),
                          subtitle: Text(
                            MaterialLocalizations.of(context)
                                .formatMediumDate(entry.createdAt),
                          ),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => _NoteView(entry: entry),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _NoteView extends StatelessWidget {
  const _NoteView({required this.entry});

  final NotebookEntry entry;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: UserContentText(entry.title)),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          MaterialLocalizations.of(context).formatFullDate(entry.createdAt),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        UserContentText(entry.body),
      ],
    ),
  );
}
