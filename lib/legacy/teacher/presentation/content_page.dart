part of '../../../teacher_features.dart';

class ContentPage extends StatefulWidget {
  const ContentPage({super.key});
  @override
  State<ContentPage> createState() => _ContentPageState();
}

class _ContentPageState extends State<ContentPage> {
  int tab = 0;
  int? classId;

  @override
  Widget build(BuildContext c) => Column(
    children: [
      const FeatureHeader('Content'),
      Expanded(
        child: FutureBuilder<List<List<Map<String, Object?>>>>(
          future: Future.wait([
            StudafyDatabase.instance.classes(),
            if (tab == 0 && classId != null)
              StudafyDatabase.instance.notebooksForClass(classId!)
            else if (tab == 1)
              StudafyDatabase.instance.assignments()
            else if (tab == 2)
              StudafyDatabase.instance.assessments()
            else
              Future.value(<Map<String, Object?>>[]),
          ]),
          builder: (c, s) {
            final classes = s.data?[0] ?? [];
            final allRows = s.data?[1] ?? [];
            final rows = classId == null || tab == 0
                ? allRows
                : allRows.where((r) => r['class_id'] == classId).toList();
            return Stack(
              children: [
                ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Segments(
                      labels: const ['Notebook', 'Assignments', 'Exams'],
                      index: tab,
                      onTap: (value) => setState(() => tab = value),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<int?>(
                      initialValue: classId,
                      decoration: const InputDecoration(
                        labelText: 'Class',
                        prefixIcon: Icon(Icons.school_outlined),
                      ),
                      items: [
                        if (tab != 0)
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('All classes'),
                          ),
                        ...classes.map(
                          (r) => DropdownMenuItem<int?>(
                            value: r['id'] as int,
                            child: Text(
                              '${r['name']} · G${r['grade']} ${r['section']}',
                            ),
                          ),
                        ),
                      ],
                      onChanged: (value) => setState(() => classId = value),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            _coral.withValues(alpha: .13),
                            _sun.withValues(alpha: .12),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: _coral,
                            foregroundColor: Colors.white,
                            child: Icon(Icons.assignment_rounded),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Choose a class, then publish lesson notebook content for a specific session, assign work, or create an online exam.',
                              style: TextStyle(
                                color: _ink,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (tab == 0 && classId == null)
                      const FeatureCard(
                        tint: _cyan,
                        child: Text(
                          'Select a class to view its sessions and notebook entries.',
                        ),
                      ),
                    if (s.connectionState == ConnectionState.waiting)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(28),
                          child: CircularProgressIndicator(),
                        ),
                      ),
                    for (final r in rows)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: FeatureCard(
                          tint: Color((r['color'] as int?) ?? 0xFF241D73),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 9,
                                    height: 9,
                                    color: Color(
                                      (r['color'] as int?) ?? 0xFF241D73,
                                    ),
                                  ),
                                  const SizedBox(width: 9),
                                  Expanded(
                                    child: Text(
                                      tab == 0
                                          ? '${r['day']} · Session ${r['session_number']}'
                                          : 'Grade ${r['grade']} ${r['section']}',
                                      style: const TextStyle(
                                        color: _muted,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  _attachmentCount(
                                    r['attachment_count'],
                                    onTap: () => _showAttachments(
                                      c,
                                      'assignment',
                                      r['id'] as int,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                tab == 0 ? '${r['lesson']}' : '${r['title']}',
                                style: const TextStyle(
                                  color: _ink,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                tab == 0
                                    ? ((r['homework'] as String?)?.isNotEmpty ==
                                              true
                                          ? 'Practice: ${r['homework']}'
                                          : 'No practice assigned')
                                    : tab == 1
                                    ? 'Due ${('${r['due_at']}').substring(0, 10)} · ${r['submitted']} submitted'
                                    : '${r['status']} · ${r['max_score']} marks · ${r['delivery']}',
                                style: const TextStyle(color: _muted),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                Positioned(
                  right: 20,
                  bottom: 22,
                  child: FloatingActionButton(
                    heroTag: 'teacher-teaching-create',
                    backgroundColor: _coral,
                    foregroundColor: Colors.white,
                    onPressed: () {
                      if (tab == 0) {
                        _showContentNotebookForm(c);
                      } else if (tab == 1) {
                        showAssignmentForm(c, () => setState(() {}));
                      } else {
                        showAssessmentForm(c, () => setState(() {}));
                      }
                    },
                    child: const Icon(Icons.add_rounded),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    ],
  );

  Future<void> _showContentNotebookForm(BuildContext context) async {
    if (classId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Choose a class before adding lesson content.'),
        ),
      );
      return;
    }
    var date = DateTime.now();
    var session = 1;
    final lesson = TextEditingController();
    final practice = TextEditingController();
    final attachments = <_AttachmentDraft>[];
    final schedule = await StudafyDatabase.instance.classSchedule(classId!);
    List<Map<String, Object?>> slots() =>
        schedule.where((slot) => slot['weekday'] == date.weekday).toList();
    if (slots().isNotEmpty) session = slots().first['session_number'] as int;
    if (!context.mounted) return;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, update) => AlertDialog(
          title: const Text('Publish lesson notebook'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_month_rounded),
                  title: const Text('Lesson date'),
                  subtitle: Text(date.toIso8601String().substring(0, 10)),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: dialogContext,
                      initialDate: date,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      update(() {
                        date = picked;
                        if (slots().isNotEmpty) {
                          session = slots().first['session_number'] as int;
                        }
                      });
                    }
                  },
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  initialValue:
                      slots().any((x) => x['session_number'] == session)
                      ? session
                      : null,
                  decoration: const InputDecoration(
                    labelText: 'Class session',
                    prefixIcon: Icon(Icons.schedule_rounded),
                  ),
                  items: slots()
                      .map(
                        (slot) => DropdownMenuItem<int>(
                          value: slot['session_number'] as int,
                          child: Text(
                            'Session ${slot['session_number']} · ${slot['start_time']}–${slot['end_time']}',
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => update(() => session = value ?? 1),
                ),
                if (slots().isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'No scheduled session on this date. Choose another lesson date.',
                      style: TextStyle(color: _coral),
                    ),
                  ),
                const SizedBox(height: 12),
                TextField(
                  controller: lesson,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'Lesson content',
                    hintText: 'Summary, concepts, examples and board notes',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: practice,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Practice or follow-up',
                  ),
                ),
                const SizedBox(height: 12),
                _AttachmentComposer(
                  items: attachments,
                  onChanged: () => update(() {}),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: lesson.text.trim().isEmpty || slots().isEmpty
                  ? null
                  : () async {
                      final id = await StudafyDatabase.instance.saveNotebook(
                        classId!,
                        lesson.text.trim(),
                        practice.text.trim(),
                        date,
                        session,
                      );
                      await StudafyDatabase.instance.addAttachments(
                        'notebook',
                        id,
                        attachments.map((item) => item.toMap()),
                      );
                      if (dialogContext.mounted) {
                        Navigator.pop(dialogContext, true);
                      }
                    },
              icon: const Icon(Icons.publish_rounded),
              label: const Text('Publish to students'),
            ),
          ],
        ),
      ),
    );
    if (saved == true) setState(() {});
  }
}
