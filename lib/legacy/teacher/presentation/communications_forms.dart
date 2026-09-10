part of '../../../teacher_features.dart';

class CommsForm extends StatefulWidget {
  const CommsForm({super.key, required this.tab, required this.onTab});
  final int tab;
  final ValueChanged<int> onTab;
  @override
  State<CommsForm> createState() => _CommsFormState();
}

class _CommsFormState extends State<CommsForm> {
  int? studentId;
  String choice = 'Excellent work', category = 'Behaviour', severity = 'Minor';
  final note = TextEditingController();
  final attachments = <_AttachmentDraft>[];
  @override
  Widget build(BuildContext c) => FutureBuilder(
    future: StudafyDatabase.instance.students(),
    builder: (c, s) => ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Segments(
          labels: const ['Announcements', 'Behaviour', 'Incident'],
          index: widget.tab,
          onTap: widget.onTab,
        ),
        const SizedBox(height: 20),
        DropdownButtonFormField<int>(
          initialValue: studentId,
          decoration: const InputDecoration(labelText: 'Student'),
          items: (s.data ?? [])
              .map(
                (x) => DropdownMenuItem(
                  value: x['id'] as int,
                  child: Text('${x['name']}'),
                ),
              )
              .toList(),
          onChanged: (v) => setState(() => studentId = v),
        ),
        const SizedBox(height: 18),
        if (widget.tab == 1) ...[
          const Text(
            'Positive behaviour',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 9),
          Wrap(
            spacing: 8,
            children:
                [
                      'Helped a peer',
                      'Excellent work',
                      'Leadership',
                      'Great participation',
                    ]
                    .map(
                      (x) => ChoiceChip(
                        label: Text(x),
                        selected: choice == x,
                        onSelected: (_) => setState(() => choice = x),
                      ),
                    )
                    .toList(),
          ),
        ] else ...[
          const Text('Category', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 9),
          Wrap(
            spacing: 8,
            children: ['Behaviour', 'Attendance', 'Academic', 'Safety']
                .map(
                  (x) => ChoiceChip(
                    label: Text(x),
                    selected: category == x,
                    onSelected: (_) => setState(() => category = x),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 15),
          Wrap(
            spacing: 8,
            children: ['Minor', 'Moderate', 'Serious']
                .map(
                  (x) => ChoiceChip(
                    label: Text(x),
                    selected: severity == x,
                    onSelected: (_) => setState(() => severity = x),
                  ),
                )
                .toList(),
          ),
        ],
        const SizedBox(height: 18),
        TextField(
          controller: note,
          maxLines: 4,
          decoration: InputDecoration(
            labelText: widget.tab == 1 ? 'What happened' : 'Description',
          ),
        ),
        const SizedBox(height: 14),
        _AttachmentComposer(
          items: attachments,
          onChanged: () => setState(() {}),
        ),
        const SizedBox(height: 22),
        FilledButton(
          onPressed: studentId == null || note.text.trim().isEmpty
              ? null
              : () async {
                  late final int id;
                  late final String ownerType;
                  if (widget.tab == 1) {
                    ownerType = 'behaviour';
                    id = await StudafyDatabase.instance.addBehaviour({
                      'student_id': studentId,
                      'kind': 'positive',
                      'tag': choice,
                      'note': note.text.trim(),
                      'created_at': DateTime.now().toIso8601String(),
                    });
                  } else {
                    ownerType = 'incident';
                    id = await StudafyDatabase.instance.addIncident({
                      'student_id': studentId,
                      'category': category,
                      'severity': severity,
                      'description': note.text.trim(),
                      'created_at': DateTime.now().toIso8601String(),
                    });
                  }
                  await StudafyDatabase.instance.addAttachments(
                    ownerType,
                    id,
                    attachments.map((item) => item.toMap()),
                  );
                  if (c.mounted) {
                    ScaffoldMessenger.of(c).showSnackBar(
                      const SnackBar(content: Text('Saved successfully.')),
                    );
                    note.clear();
                    setState(attachments.clear);
                  }
                },
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
          child: Text(
            widget.tab == 1 ? 'Save & notify guardians' : 'Submit report',
          ),
        ),
      ],
    ),
  );
}

Future<int?> chooseClass(BuildContext c) async {
  final rows = await StudafyDatabase.instance.classes();
  if (!c.mounted) return null;
  return showDialog<int>(
    context: c,
    builder: (c) => SimpleDialog(
      title: const Text('Choose class'),
      children: rows
          .map(
            (r) => SimpleDialogOption(
              onPressed: () => Navigator.pop(c, r['id']),
              child: Text('${r['name']} · Grade ${r['grade']} ${r['section']}'),
            ),
          )
          .toList(),
    ),
  );
}

void showAssessmentForm(BuildContext c, VoidCallback done) async {
  final classId = await chooseClass(c);
  if (classId == null || !c.mounted) return;
  final title = TextEditingController(),
      max = TextEditingController(text: '20');
  final questions = <TextEditingController>[TextEditingController()];
  final attachments = <_AttachmentDraft>[];
  var delivery = 'paper';
  showDialog(
    context: c,
    builder: (c) => StatefulBuilder(
      builder: (c, setDialog) => AlertDialog(
        title: const Text('Create exam'),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: title,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: max,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Maximum score'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: delivery,
                  decoration: const InputDecoration(
                    labelText: 'How students take this exam',
                    prefixIcon: Icon(Icons.description_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'paper',
                      child: Text('Paper / in-class exam'),
                    ),
                    DropdownMenuItem(
                      value: 'online',
                      child: Text('Online exam in Studafy'),
                    ),
                  ],
                  onChanged: (value) =>
                      setDialog(() => delivery = value ?? 'paper'),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _cyan.withValues(alpha: .09),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        delivery == 'online'
                            ? Icons.language_rounded
                            : Icons.edit_document,
                        color: _cyan,
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          delivery == 'online'
                              ? 'Students complete this exam in the app.'
                              : 'Create the exam record now, then enter each student’s paper score. Published marks appear for students and parents.',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (delivery == 'online')
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Questions',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                if (delivery == 'online') const SizedBox(height: 8),
                if (delivery == 'online')
                  for (var i = 0; i < questions.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: TextField(
                        controller: questions[i],
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: 'Question ${i + 1}',
                        ),
                      ),
                    ),
                if (delivery == 'online')
                  OutlinedButton.icon(
                    onPressed: () =>
                        setDialog(() => questions.add(TextEditingController())),
                    icon: const Icon(Icons.add),
                    label: const Text('Add question'),
                  ),
                const SizedBox(height: 14),
                _AttachmentComposer(
                  items: attachments,
                  onChanged: () => setDialog(() {}),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (title.text.trim().isEmpty) return;
              final assessmentId = await StudafyDatabase.instance.addAssessment(
                {
                  'class_id': classId,
                  'type': 'Exam',
                  'title': title.text.trim(),
                  'max_score': int.tryParse(max.text) ?? 20,
                  'status': 'Published',
                  'delivery': delivery,
                  'scheduled_at': DateTime.now()
                      .add(const Duration(days: 7))
                      .toIso8601String(),
                },
              );
              await StudafyDatabase.instance.prepareAssessmentRoster(
                assessmentId,
                classId,
              );
              final valid = questions
                  .where((q) => q.text.trim().isNotEmpty)
                  .toList();
              final total = int.tryParse(max.text) ?? 20;
              for (final q in valid) {
                await StudafyDatabase.instance.addQuestion({
                  'assessment_id': assessmentId,
                  'prompt': q.text.trim(),
                  'type': 'long_answer',
                  'points': valid.isEmpty
                      ? total
                      : (total / valid.length).round(),
                  'options': null,
                  'answer': null,
                });
              }
              await StudafyDatabase.instance.addAttachments(
                'exam',
                assessmentId,
                attachments.map((item) => item.toMap()),
              );
              if (c.mounted) Navigator.pop(c);
              done();
            },
            child: const Text('Create exam'),
          ),
        ],
      ),
    ),
  );
}

void showAssignmentForm(BuildContext c, VoidCallback done) async {
  final classId = await chooseClass(c);
  if (classId == null || !c.mounted) return;
  final missing = await StudafyDatabase.instance
      .missingNotebookSessionsThisWeek(classId);
  if (missing.isNotEmpty) {
    if (!c.mounted) return;
    await showDialog<void>(
      context: c,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.menu_book_rounded, color: _coral, size: 36),
        title: const Text('Lesson notes required'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Publish the notebook notes for every class held this week before creating an assignment.',
            ),
            const SizedBox(height: 12),
            for (final slot in missing)
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text(
                  '• ${slot['day']} · class ${slot['session_number']} · ${slot['start_time']}–${slot['end_time']}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Understood'),
          ),
        ],
      ),
    );
    return;
  }
  final title = TextEditingController();
  final attachments = <_AttachmentDraft>[];
  if (!c.mounted) return;
  showDialog(
    context: c,
    builder: (c) => StatefulBuilder(
      builder: (c, setDialog) => AlertDialog(
        title: const Text('New assignment'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: title,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              const SizedBox(height: 14),
              _AttachmentComposer(
                items: attachments,
                onChanged: () => setDialog(() {}),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (title.text.trim().isEmpty) return;
              final id = await StudafyDatabase.instance.addAssignment({
                'class_id': classId,
                'title': title.text.trim(),
                'due_at': DateTime.now()
                    .add(const Duration(days: 7))
                    .toIso8601String(),
                'kind': 'assignment',
              });
              await StudafyDatabase.instance.addAttachments(
                'assignment',
                id,
                attachments.map((item) => item.toMap()),
              );
              if (c.mounted) Navigator.pop(c);
              done();
            },
            child: const Text('Create'),
          ),
        ],
      ),
    ),
  );
}

void showNoticeForm(BuildContext c, VoidCallback done) async {
  final classId = await chooseClass(c);
  if (classId == null || !c.mounted) return;
  final message = TextEditingController();
  final attachments = <_AttachmentDraft>[];
  showDialog(
    context: c,
    builder: (c) => StatefulBuilder(
      builder: (c, setDialog) => AlertDialog(
        title: const Text('New announcement'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: message,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Message'),
              ),
              const SizedBox(height: 14),
              _AttachmentComposer(
                items: attachments,
                onChanged: () => setDialog(() {}),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (message.text.trim().isEmpty) return;
              final id = await StudafyDatabase.instance.addNotice({
                'class_id': classId,
                'message': message.text.trim(),
                'mandatory': 0,
                'created_at': DateTime.now().toIso8601String(),
              });
              await StudafyDatabase.instance.addAttachments(
                'announcement',
                id,
                attachments.map((item) => item.toMap()),
              );
              if (c.mounted) Navigator.pop(c);
              done();
            },
            child: const Text('Publish'),
          ),
        ],
      ),
    ),
  );
}
