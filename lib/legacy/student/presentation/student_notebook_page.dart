import 'dart:io';

import 'package:flutter/material.dart';

import '../../../studafy_database.dart';
import '../../../features/academic/data/preview_student_identity.dart';
import 'student_account_pages.dart';
import 'student_notebook_components.dart';
import 'student_shared.dart';

class StudentNotebookPage extends StatefulWidget {
  const StudentNotebookPage({super.key});
  @override
  State<StudentNotebookPage> createState() => _StudentNotebookPageState();
}

class _StudentNotebookPageState extends State<StudentNotebookPage> {
  static const studentId = PreviewStudentIdentity.localId;
  int period = 1;
  String query = '';
  final search = TextEditingController();
  final Set<String> expanded = {};
  late Future<List<Map<String, Object?>>> notes;

  @override
  void initState() {
    super.initState();
    notes = StudafyDatabase.instance.studentNotebooks(studentId);
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: studentCanvas,
    body: Column(
      children: [
        const StudentSectionHeader(title: 'My Notebook'),
        StudentNotebookPeriods(
          selected: period,
          onSelected: (value) => setState(() => period = value),
        ),
        Expanded(
          child: FutureBuilder<List<Map<String, Object?>>>(
            future: notes,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final filtered = _filterNotes(snapshot.data!);
              final grouped = <String, List<Map<String, Object?>>>{};
              for (final note in filtered) {
                grouped
                    .putIfAbsent('${note['class_name']}', () => [])
                    .add(note);
              }
              return RefreshIndicator(
                onRefresh: () async {
                  final next = StudafyDatabase.instance.studentNotebooks(
                    studentId,
                  );
                  setState(() => notes = next);
                  await next;
                },
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                  children: [
                    TextField(
                      controller: search,
                      onChanged: (value) =>
                          setState(() => query = value.trim().toLowerCase()),
                      decoration: InputDecoration(
                        hintText: 'Search lessons, subjects, or homework',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: query.isEmpty
                            ? null
                            : IconButton(
                                onPressed: () {
                                  search.clear();
                                  setState(() => query = '');
                                },
                                icon: const Icon(Icons.close_rounded),
                              ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${filtered.length} lesson${filtered.length == 1 ? '' : 's'} captured ${const ['today', 'this week', 'this month'][period]}',
                            style: const TextStyle(
                              color: studentMuted,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        if (grouped.isNotEmpty)
                          TextButton(
                            onPressed: () => setState(() {
                              if (expanded.length == grouped.length) {
                                expanded.clear();
                              } else {
                                expanded.addAll(grouped.keys);
                              }
                            }),
                            child: Text(
                              expanded.length == grouped.length
                                  ? 'Minimise all'
                                  : 'Expand all',
                            ),
                          ),
                      ],
                    ),
                    if (filtered.isEmpty) const StudentNotebookEmpty(),
                    for (final entry in grouped.entries)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: StudentNotebookSubject(
                          subject: entry.key,
                          notes: entry.value,
                          expanded: expanded.contains(entry.key),
                          onToggle: () => setState(() {
                            expanded.contains(entry.key)
                                ? expanded.remove(entry.key)
                                : expanded.add(entry.key);
                          }),
                          onAttachment: _openAttachment,
                        ),
                      ),
                    if (filtered.isNotEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        child: Text(
                          'Notebook entries are filed by your teachers after lessons. Attachments may include photos, PDFs, documents, slides, spreadsheets, files, and links.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: studentMuted,
                            fontSize: 10,
                            height: 1.4,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    ),
  );

  List<Map<String, Object?>> _filterNotes(List<Map<String, Object?>> source) {
    final now = DateTime.now();
    return source.where((note) {
      final date = DateTime.tryParse('${note['day']}');
      final inPeriod =
          date == null ||
          switch (period) {
            0 =>
              date.year == now.year &&
                  date.month == now.month &&
                  date.day == now.day,
            1 => !date.isBefore(
              DateTime(
                now.year,
                now.month,
                now.day,
              ).subtract(const Duration(days: 6)),
            ),
            _ => date.year == now.year && date.month == now.month,
          };
      if (!inPeriod) return false;
      if (query.isEmpty) return true;
      return '${note['class_name']} ${note['lesson']} ${note['homework']}'
          .toLowerCase()
          .contains(query);
    }).toList();
  }

  Future<void> _openAttachment(Map<String, Object?> attachment) async {
    final uri = '${attachment['uri']}',
        kind = '${attachment['kind']}',
        name = '${attachment['name']}';
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 2, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(studentAttachmentIcon(kind, name), color: studentNavy),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(
                        color: studentInk,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (kind == 'image' && File(uri).existsSync())
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.file(
                    File(uri),
                    height: 320,
                    fit: BoxFit.contain,
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0EFFF),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        studentAttachmentIcon(kind, name),
                        size: 48,
                        color: studentNavy,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        kind == 'link'
                            ? uri
                            : 'This ${studentFileType(name)} is attached to the lesson.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: studentMuted),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.download_outlined),
                      label: const Text('Save copy'),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.open_in_new_rounded),
                      label: Text(kind == 'link' ? 'Open link' : 'Open file'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
