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
        padding: const EdgeInsetsDirectional.fromSTEB(20, 8, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              AppL10n.of(c).dashTakeAttendance,
              style: Theme.of(c).textTheme.headlineSmall,
            ),
            UserContentText(className, style: const TextStyle(color: muted)),
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
                            // The status values are the server's vocabulary;
                            // only their labels change with language.
                            items: [
                              DropdownMenuItem(
                                value: 'present',
                                child: Text(AppL10n.of(c).attendancePresent),
                              ),
                              DropdownMenuItem(
                                value: 'absent',
                                child: Text(AppL10n.of(c).attendanceAbsent),
                              ),
                              DropdownMenuItem(
                                value: 'tardy',
                                child: Text(AppL10n.of(c).attendanceTardy),
                              ),
                              DropdownMenuItem(
                                value: 'excused',
                                child: Text(AppL10n.of(c).attendanceExcused),
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
                              decoration: InputDecoration(
                                labelText: AppL10n.of(c)
                                    .attendanceExcusedReason,
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
                  SnackBar(content: Text(AppL10n.of(c).attendanceSaved)),
                );
              },
              child: Text(AppL10n.of(c).attendanceSave),
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
      padding: EdgeInsetsDirectional.fromSTEB(
        20,
        8,
        20,
        MediaQuery.viewInsetsOf(c).bottom + 28,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            AppL10n.of(c).notebookTitle,
            style: Theme.of(c).textTheme.headlineSmall,
          ),
          UserContentText(className, style: const TextStyle(color: muted)),
          const SizedBox(height: 16),
          TextField(
            controller: lesson,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: AppL10n.of(c).notebookLessonLabel,
              hintText: AppL10n.of(c).notebookLessonHint,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: homework,
            decoration: InputDecoration(
              labelText: AppL10n.of(c).notebookHomeworkLabel,
            ),
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
            child: Text(AppL10n.of(c).notebookSave),
          ),
        ],
      ),
    ),
  );
}
