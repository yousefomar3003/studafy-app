part of '../../../teacher_features.dart';

class GradebookPage extends StatefulWidget {
  const GradebookPage({super.key});
  @override
  State<GradebookPage> createState() => _GradebookPageState();
}

class _GradebookPageState extends State<GradebookPage> {
  int tab = 0;
  int? classId;
  void refresh() => setState(() {});
  @override
  Widget build(BuildContext c) => Column(
    children: [
      const FeatureHeader('Gradebook'),
      Expanded(
        child: FutureBuilder(
          future: Future.wait([
            StudafyDatabase.instance.classes(),
            tab == 0
                ? StudafyDatabase.instance.assessments()
                : StudafyDatabase.instance.allAssessmentSubmissions(classId),
          ]),
          builder: (c, s) {
            final classes = s.data?[0] ?? <Map<String, Object?>>[];
            final allRows = s.data?[1] ?? <Map<String, Object?>>[];
            final rows = tab == 0 && classId != null
                ? allRows.where((r) => r['class_id'] == classId).toList()
                : allRows;
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                OutlinedButton.icon(
                  onPressed: () => showAssessmentForm(c, refresh),
                  icon: const Icon(Icons.add_task_rounded),
                  label: const Text('Create exam'),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<int?>(
                  initialValue: classId,
                  decoration: const InputDecoration(labelText: 'Class'),
                  items: [
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
                  onChanged: (v) => setState(() => classId = v),
                ),
                const SizedBox(height: 14),
                Segments(
                  labels: const ['Exams', 'Submissions'],
                  index: tab,
                  onTap: (v) => setState(() => tab = v),
                ),
                const SizedBox(height: 16),
                if (s.connectionState == ConnectionState.waiting)
                  const Center(child: CircularProgressIndicator()),
                for (final r in rows)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: FeatureCard(
                      tint: tab == 0
                          ? Color((r['color'] as int?) ?? 0xFF7737EE)
                          : _cyan,
                      onTap: () async {
                        if (tab == 0) {
                          await Navigator.push(
                            c,
                            MaterialPageRoute(
                              builder: (_) =>
                                  AssessmentDetailPage(assessment: r),
                            ),
                          );
                        } else {
                          await showGradeSubmission(c, r);
                        }
                        setState(() {});
                      },
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tab == 0
                                      ? ('${r['delivery']}' == 'online'
                                            ? 'Online exam'
                                            : 'Paper exam')
                                      : '${r['student_name']}',
                                  style: const TextStyle(
                                    color: _muted,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 7),
                                Text(
                                  tab == 0
                                      ? '${r['title']}'
                                      : '${r['assessment_title']}',
                                  style: const TextStyle(
                                    color: _ink,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  tab == 0
                                      ? 'Grade ${r['grade']} ${r['section']} · max ${r['max_score']}'
                                      : 'Grade ${r['grade']} ${r['section']} · ${r['score'] == null ? 'Awaiting grade' : '${r['score']}/${r['max_score']}'}',
                                  style: const TextStyle(color: _muted),
                                ),
                              ],
                            ),
                          ),
                          StatusBadge(
                            tab == 0
                                ? '${r['status']}'
                                : r['score'] == null
                                ? 'Grade'
                                : 'Graded',
                          ),
                          if (tab == 0) ...[
                            const SizedBox(width: 8),
                            _attachmentCount(
                              r['attachment_count'],
                              onTap: () =>
                                  _showAttachments(c, 'exam', r['id'] as int),
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
  );
}
