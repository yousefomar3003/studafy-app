part of '../../../teacher_features.dart';

class ParentWorkspacePage extends StatelessWidget {
  const ParentWorkspacePage({super.key, required this.children});
  final List<Map<String, Object?>> children;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _canvasColor,
    appBar: AppBar(
      backgroundColor: Colors.white,
      title: const Text('My Family'),
      actions: [
        TextButton.icon(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.swap_horiz_rounded),
          label: const Text('Teacher'),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_navy, Color(0xFF4037A0)]),
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.family_restroom_rounded, color: _cyanAccent, size: 34),
              SizedBox(height: 12),
              Text(
                'Parent workspace',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                'Open a linked child’s school view without using their login.',
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        for (final child in children)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: FeatureCard(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => StudentNotebookPage(student: child),
                ),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: _navy,
                    child: Icon(Icons.person_rounded, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${child['student_name']}',
                      style: const TextStyle(
                        color: _ink,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const Icon(Icons.open_in_new_rounded, color: _navy),
                ],
              ),
            ),
          ),
        if (children.isEmpty)
          FilledButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ConnectionsPage()),
            ),
            icon: const Icon(Icons.add_link_rounded),
            label: const Text('Connect a child'),
          ),
      ],
    ),
  );
}

class StudentNotebookPage extends StatefulWidget {
  const StudentNotebookPage({super.key, required this.student});
  final Map<String, Object?> student;
  @override
  State<StudentNotebookPage> createState() => _StudentNotebookPageState();
}

class _StudentNotebookPageState extends State<StudentNotebookPage> {
  int tab = 0;
  late Future<List<Map<String, Object?>>> notes;
  @override
  void initState() {
    super.initState();
    notes = StudafyDatabase.instance.studentNotebooks(
      widget.student['student_id'] as int,
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _canvasColor,
    appBar: AppBar(
      backgroundColor: Colors.white,
      title: Text('${widget.student['student_name']}'),
    ),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Segments(
            labels: const ['Overview', 'Notebook'],
            index: tab,
            onTap: (v) => setState(() => tab = v),
          ),
        ),
        Expanded(
          child: tab == 0
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.verified_user_rounded,
                        color: _navy,
                        size: 64,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Secure linked access',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      Text(
                        '${widget.student['studafy_id']}',
                        style: const TextStyle(color: _muted),
                      ),
                    ],
                  ),
                )
              : FutureBuilder<List<Map<String, Object?>>>(
                  future: notes,
                  builder: (context, snapshot) {
                    final rows = snapshot.data ?? [];
                    return ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        const Text(
                          'Class notebook',
                          style: TextStyle(
                            color: _ink,
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Text(
                          'Published lesson notes from teachers.',
                          style: TextStyle(color: _muted),
                        ),
                        const SizedBox(height: 14),
                        if (rows.isEmpty)
                          const Text('No notes have been published yet.'),
                        for (final note in rows)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: FeatureCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${note['class_name']} · G${note['grade']} ${note['section']}',
                                    style: const TextStyle(
                                      color: _navy,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  Text(
                                    '${note['day']} · Class ${note['session_number']}',
                                    style: const TextStyle(
                                      color: _muted,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    '${note['lesson']}',
                                    style: const TextStyle(color: _ink),
                                  ),
                                  if ('${note['homework']}'.isNotEmpty) ...[
                                    const Divider(),
                                    Text(
                                      'Practice: ${note['homework']}',
                                      style: const TextStyle(color: _muted),
                                    ),
                                  ],
                                  if ((note['attachment_count'] as int? ?? 0) >
                                      0) ...[
                                    const SizedBox(height: 9),
                                    _attachmentCount(
                                      note['attachment_count'],
                                      onTap: () => _showAttachments(
                                        context,
                                        'notebook',
                                        note['id'] as int,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
        ),
      ],
    ),
  );
}
