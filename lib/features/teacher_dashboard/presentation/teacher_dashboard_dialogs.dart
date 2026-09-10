part of 'teacher_dashboard.dart';

void showAttendance(BuildContext c, String className) async {
  final repository = TeacherDashboardRepositoryScope.read(c);
  final roster = await repository.attendanceRoster(className);
  if (roster == null || !c.mounted) return;
  final students = roster.students;
  if (!c.mounted) return;
  final values = {
    for (final student in students)
      student.localId: const AttendanceEntry(status: 'present'),
  };
  showModalBottomSheet(
    context: c,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (c) => StatefulBuilder(
      builder: (c, setSheet) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Take attendance', style: Theme.of(c).textTheme.headlineSmall),
            Text(className, style: const TextStyle(color: muted)),
            const SizedBox(height: 12),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  ...students.map(
                    (student) => Container(
                      margin: const EdgeInsets.only(bottom: 9),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: canvas,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            student.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: ink,
                            ),
                          ),
                          const SizedBox(height: 7),
                          DropdownButtonFormField<String>(
                            initialValue: values[student.localId]!.status,
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
                            onChanged: (value) {
                              if (value == null) return;
                              setSheet(
                                () => values[student.localId] =
                                    values[student.localId]!.copyWith(
                                      status: value,
                                    ),
                              );
                            },
                          ),
                          if (values[student.localId]!.status == 'excused') ...[
                            const SizedBox(height: 7),
                            TextFormField(
                              onChanged: (value) => values[student.localId] =
                                  values[student.localId]!.copyWith(
                                    status: 'excused',
                                    reason: value,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'Reason for excused absence',
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            FilledButton(
              onPressed: () async {
                await repository.saveAttendance(
                  roster.classId,
                  DateTime.now(),
                  values,
                );
                if (!c.mounted) return;
                Navigator.pop(c);
                ScaffoldMessenger.of(c).showSnackBar(
                  const SnackBar(
                    content: Text('Attendance saved successfully.'),
                  ),
                );
              },
              child: const Text('Save attendance'),
            ),
          ],
        ),
      ),
    ),
  );
}

void showNotebook(BuildContext c, String className) async {
  final repository = TeacherDashboardRepositoryScope.read(c);
  final lesson = TextEditingController(), homework = TextEditingController();
  showModalBottomSheet(
    context: c,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (c) => Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        8,
        20,
        MediaQuery.viewInsetsOf(c).bottom + 28,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Lesson notebook', style: Theme.of(c).textTheme.headlineSmall),
          Text(className, style: const TextStyle(color: muted)),
          const SizedBox(height: 16),
          TextField(
            controller: lesson,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Lesson covered',
              hintText: 'What did you teach today?',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: homework,
            decoration: const InputDecoration(labelText: 'Homework (optional)'),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: () async {
              if (lesson.text.trim().isEmpty) return;
              final saved = await repository.saveNotebook(
                classLabel: className,
                lesson: lesson.text.trim(),
                homework: homework.text.trim(),
              );
              if (saved && c.mounted) Navigator.pop(c);
            },
            child: const Text('Save notebook'),
          ),
        ],
      ),
    ),
  );
}
