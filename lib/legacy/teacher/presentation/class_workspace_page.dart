part of '../../../teacher_features.dart';

class ClassWorkspacePage extends StatefulWidget {
  const ClassWorkspacePage({super.key, required this.classData});
  final Map<String, Object?> classData;
  @override
  State<ClassWorkspacePage> createState() => _ClassWorkspacePageState();
}

class _ClassWorkspacePageState extends State<ClassWorkspacePage> {
  int tab = 0;
  int get classId => widget.classData['id'] as int;
  late Future<List<Object>> _overviewFuture;
  late Future<List<Map<String, Object?>>> _attendanceFuture;
  late Future<List<Map<String, Object?>>> _notebookFuture;

  @override
  void initState() {
    super.initState();
    _reloadWorkspace();
  }

  void _reloadWorkspace() {
    _overviewFuture = Future.wait<Object>([
      StudafyDatabase.instance.classSchedule(classId),
      StudafyDatabase.instance.students(classId),
    ]);
    _attendanceFuture = StudafyDatabase.instance.attendanceDates(classId);
    _notebookFuture = StudafyDatabase.instance.notebooksForClass(classId);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _canvasColor,
    appBar: AppBar(
      backgroundColor: Colors.white,
      title: Text(
        '${widget.classData['name']} · G${widget.classData['grade']} ${widget.classData['section']}',
      ),
    ),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Segments(
            labels: const ['Class', 'Attendance', 'Notebook'],
            index: tab,
            onTap: (v) => setState(() => tab = v),
          ),
        ),
        Expanded(
          child: switch (tab) {
            0 => _overview(),
            1 => _attendanceHistory(),
            _ => _notebook(),
          },
        ),
      ],
    ),
  );
  Widget _overview() => FutureBuilder<List<Object>>(
    future: _overviewFuture,
    builder: (context, snapshot) {
      final schedule =
              (snapshot.data?[0] as List<Map<String, Object?>>?) ??
              <Map<String, Object?>>[],
          students =
              (snapshot.data?[1] as List<Map<String, Object?>>?) ??
              <Map<String, Object?>>[];
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          FeatureCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${widget.classData['room']}',
                  style: const TextStyle(color: _muted),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    for (final slot in schedule)
                      Chip(
                        label: Text(
                          '${_dayName(slot['weekday'] as int)} ${slot['start_time']}–${slot['end_time']}',
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '${students.length} students',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: _ink,
            ),
          ),
          for (final student in students)
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: _navy,
                child: Icon(Icons.person, color: Colors.white),
              ),
              title: Text('${student['name']}'),
              subtitle: Text('${student['studafy_id'] ?? student['email']}'),
            ),
        ],
      );
    },
  );
  Widget _attendanceHistory() => FutureBuilder<List<Map<String, Object?>>>(
    future: _attendanceFuture,
    builder: (context, snapshot) {
      final dates = snapshot.data ?? [];
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          FilledButton.icon(
            onPressed: () => _editAttendance(DateTime.now()),
            icon: const Icon(Icons.add),
            label: const Text('Record attendance'),
          ),
          const SizedBox(height: 16),
          const Text(
            'Attendance history',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: _ink,
            ),
          ),
          const SizedBox(height: 10),
          if (dates.isEmpty)
            const Text(
              'No attendance has been recorded yet.',
              style: TextStyle(color: _muted),
            ),
          for (final row in dates)
            Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: FeatureCard(
                onTap: () => _editAttendance(DateTime.parse('${row['day']}')),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_month, color: _navy),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${row['day']}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: _ink,
                            ),
                          ),
                          Text(
                            '${row['present']} present · ${(row['total'] as int) - (row['present'] as int)} absent',
                            style: const TextStyle(color: _muted),
                          ),
                        ],
                      ),
                    ),
                    const Text(
                      'Edit',
                      style: TextStyle(
                        color: _navy,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
    },
  );
  Future<void> _editAttendance(DateTime initial) async {
    var date = initial;
    final students = await StudafyDatabase.instance.students(classId);
    var old = await StudafyDatabase.instance.attendanceDetails(classId, date);
    var values = {
      for (final s in students)
        s['id'] as int:
            old[s['id']] ??
            <String, String?>{'status': 'present', 'reason': null},
    };
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OutlinedButton.icon(
                onPressed: () async {
                  final p = await showDatePicker(
                    context: context,
                    initialDate: date,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (p != null) {
                    old = await StudafyDatabase.instance.attendanceDetails(
                      classId,
                      p,
                    );
                    setSheet(() {
                      date = p;
                      values = {
                        for (final s in students)
                          s['id'] as int:
                              old[s['id']] ??
                              <String, String?>{
                                'status': 'present',
                                'reason': null,
                              },
                      };
                    });
                  }
                },
                icon: const Icon(Icons.calendar_month),
                label: Text(date.toIso8601String().substring(0, 10)),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final s in students)
                      Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _canvasColor,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${s['name']}',
                              style: const TextStyle(
                                color: _ink,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              isExpanded: true,
                              initialValue: values[s['id']]!['status'],
                              decoration: const InputDecoration(
                                labelText: 'Attendance status',
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'present',
                                  child: Text('Present'),
                                ),
                                DropdownMenuItem(
                                  value: 'absent',
                                  child: Text('Absent'),
                                ),
                                DropdownMenuItem(
                                  value: 'tardy',
                                  child: Text('Tardy'),
                                ),
                                DropdownMenuItem(
                                  value: 'excused',
                                  child: Text('Excused absence'),
                                ),
                              ],
                              onChanged: (v) => setSheet(
                                () => values[s['id'] as int]!['status'] = v,
                              ),
                            ),
                            if (values[s['id']]!['status'] == 'excused') ...[
                              const SizedBox(height: 8),
                              TextFormField(
                                initialValue: values[s['id']]!['reason'],
                                onChanged: (v) =>
                                    values[s['id'] as int]!['reason'] = v,
                                decoration: const InputDecoration(
                                  labelText: 'Reason (medical, family, approved leave…)',
                                  prefixIcon: Icon(
                                    Icons.medical_information_rounded,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              FilledButton(
                onPressed: () async {
                  await StudafyDatabase.instance.saveAttendanceDetails(
                    classId,
                    date,
                    values,
                  );
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text('Save changes'),
              ),
            ],
          ),
        ),
      ),
    );
    setState(_reloadWorkspace);
  }

  Widget _notebook() => FutureBuilder<List<Map<String, Object?>>>(
    future: _notebookFuture,
    builder: (context, snapshot) {
      final notes = snapshot.data ?? [];
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          FilledButton.icon(
            onPressed: _addNotebook,
            icon: const Icon(Icons.note_add_outlined),
            label: const Text('Add lesson notes'),
          ),
          const SizedBox(height: 16),
          const Text(
            'Digital class notebook',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: _ink,
            ),
          ),
          const Text(
            'A complete, dated record students can study from.',
            style: TextStyle(color: _muted),
          ),
          const SizedBox(height: 12),
          if (notes.isEmpty) const Text('No lesson notes yet.'),
          for (final note in notes)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: FeatureCard(
                onTap: () => _addNotebook(existing: note),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${note['day']} · Class ${note['session_number']} · Week ${_weekNumber(DateTime.parse('${note['day']}'))}',
                      style: const TextStyle(
                        color: _muted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${note['lesson']}',
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if ('${note['homework']}'.isNotEmpty) ...[
                      const Divider(),
                      Text(
                        'Practice: ${note['homework']}',
                        style: const TextStyle(color: _muted),
                      ),
                    ],
                    if ((note['attachment_count'] as int? ?? 0) > 0) ...[
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
  );
  int _weekNumber(DateTime date) =>
      ((date.difference(DateTime(date.year, 1, 1)).inDays) / 7).floor() + 1;
  Future<void> _addNotebook({Map<String, Object?>? existing}) async {
    var date = existing == null
        ? DateTime.now()
        : DateTime.parse('${existing['day']}');
    var sessionNumber = (existing?['session_number'] as int?) ?? 1;
    final lesson = TextEditingController(text: existing?['lesson'] as String?),
        practice = TextEditingController(
          text: existing?['homework'] as String?,
        );
    final attachments = <_AttachmentDraft>[];
    final schedule = await StudafyDatabase.instance.classSchedule(classId);
    List<Map<String, Object?>> slotsForDay() =>
        schedule.where((slot) => slot['weekday'] == date.weekday).toList();
    if (existing == null && slotsForDay().isEmpty && schedule.isNotEmpty) {
      final now = DateTime.now();
      final nearest = [...schedule]
        ..sort((a, b) {
          final ad = (now.weekday - (a['weekday'] as int) + 7) % 7;
          final bd = (now.weekday - (b['weekday'] as int) + 7) % 7;
          return ad.compareTo(bd);
        });
      final daysBack =
          (now.weekday - (nearest.first['weekday'] as int) + 7) % 7;
      date = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: daysBack));
      sessionNumber = nearest.first['session_number'] as int;
    }
    if (!mounted) return;
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: Text(
            existing == null ? 'Add lesson notes' : 'Edit lesson notes',
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedButton.icon(
                  onPressed: () async {
                    final p = await showDatePicker(
                      context: context,
                      initialDate: date,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (p != null) {
                      setDialog(() {
                        date = p;
                        final slots = slotsForDay();
                        sessionNumber = slots.isEmpty
                            ? 1
                            : slots.first['session_number'] as int;
                      });
                    }
                  },
                  icon: const Icon(Icons.calendar_month_rounded),
                  label: Text(date.toIso8601String().substring(0, 10)),
                ),
                const SizedBox(height: 12),
                if (slotsForDay().isEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _coral.withValues(alpha: .10),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Text(
                      'There is no classroom session scheduled on this day.',
                      style: TextStyle(
                        color: _coral,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                else
                  DropdownButtonFormField<int>(
                    initialValue:
                        slotsForDay().any(
                          (slot) => slot['session_number'] == sessionNumber,
                        )
                        ? sessionNumber
                        : slotsForDay().first['session_number'] as int,
                    decoration: const InputDecoration(
                      labelText: 'Class session',
                      prefixIcon: Icon(Icons.schedule_rounded),
                    ),
                    items: [
                      for (final slot in slotsForDay())
                        DropdownMenuItem(
                          value: slot['session_number'] as int,
                          child: Text(
                            'Class ${slot['session_number']} · ${slot['start_time']}–${slot['end_time']}',
                          ),
                        ),
                    ],
                    onChanged: (value) =>
                        setDialog(() => sessionNumber = value ?? 1),
                  ),
                const SizedBox(height: 12),
                TextField(
                  controller: lesson,
                  maxLines: 7,
                  decoration: const InputDecoration(
                    labelText: 'Full subject notes',
                    hintText: 'Lesson explanation, definitions, examples, board notes…',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: practice,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Practice or homework',
                  ),
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
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (lesson.text.trim().isEmpty || slotsForDay().isEmpty) return;
                final noteId = await StudafyDatabase.instance.saveNotebook(
                  classId,
                  lesson.text.trim(),
                  practice.text.trim(),
                  date,
                  sessionNumber,
                );
                await StudafyDatabase.instance.addAttachments(
                  'notebook',
                  noteId,
                  attachments.map((item) => item.toMap()),
                );
                if (context.mounted) Navigator.pop(context, true);
              },
              child: const Text('Publish to class'),
            ),
          ],
        ),
      ),
    );
    if (saved == true) setState(_reloadWorkspace);
  }
}
