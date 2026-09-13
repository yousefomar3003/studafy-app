import 'package:flutter/material.dart';

import 'student_ai_practice.dart';
import 'student_shared.dart';

class StudentAiStudyPage extends StatelessWidget {
  const StudentAiStudyPage({
    super.key,
    required this.subject,
    required this.topic,
    required this.notes,
  });
  final String subject, topic;
  final List<Map<String, Object?>> notes;
  @override
  Widget build(BuildContext context) {
    final material = notes.where((e) => e['class_name'] == subject).toList();
    return Scaffold(
      backgroundColor: studentCanvas,
      appBar: AppBar(title: Text(subject)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            topic,
            style: const TextStyle(
              color: studentInk,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Recommended teacher material',
            style: TextStyle(color: studentMuted),
          ),
          const SizedBox(height: 18),
          for (final note in material)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(17),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${note['lesson']}',
                    style: const TextStyle(
                      color: studentInk,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if ('${note['homework'] ?? ''}'.isNotEmpty) ...[
                    const SizedBox(height: 7),
                    Text(
                      '${note['homework']}',
                      style: const TextStyle(color: studentMuted),
                    ),
                  ],
                  const SizedBox(height: 9),
                  Text(
                    '${note['attachment_count'] ?? 0} teacher attachments',
                    style: const TextStyle(
                      color: studentNavy,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          if (material.isEmpty)
            const StudentEmptyState(
              icon: Icons.menu_book_outlined,
              title: 'No material yet',
              message: 'This recommendation will fill in when the teacher publishes the lesson notebook.',
            ),
        ],
      ),
    );
  }
}

class StudentAiEvaluatorPage extends StatelessWidget {
  const StudentAiEvaluatorPage({
    super.key,
    required this.classes,
    required this.notes,
    required this.grades,
    required this.work,
  });
  final List<Map<String, Object?>> classes, notes, grades, work;
  @override
  Widget build(BuildContext context) {
    final rows = classes.map((c) {
      final name = '${c['name']}';
      final values = <double>[
        ...grades
            .where((e) => e['class_name'] == name)
            .map((e) => (e['score'] as num) * 100 / (e['max_score'] as num)),
        ...work
            .where((e) => e['class_name'] == name && e['score'] != null)
            .map((e) => (e['score'] as num).toDouble()),
      ];
      final average = values.isEmpty
          ? null
          : values.reduce((a, b) => a + b) / values.length;
      final overdue = work
          .where(
            (e) =>
                e['class_name'] == name &&
                e['submitted_at'] == null &&
                (DateTime.tryParse('${e['due_at']}')
                        ?.isBefore(DateTime.now()) ??
                    false),
          )
          .length;
      return (
        name: name,
        average: average,
        sample: values.length,
        overdue: overdue,
        topic: studentTopicFor(name, notes),
      );
    }).toList()..sort((a, b) => (a.average ?? 101).compareTo(b.average ?? 101));
    return Scaffold(
      backgroundColor: studentCanvas,
      appBar: AppBar(title: const Text('Learning evaluator')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Your learning signals',
            style: TextStyle(
              color: studentInk,
              fontSize: 23,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          const Text(
            'Recommendations use published quizzes, exams, homework scores, submissions, and notebook topics. They are study guidance—not a final grade.',
            style: TextStyle(color: studentMuted, height: 1.4),
          ),
          const SizedBox(height: 18),
          for (final row in rows)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(17),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: row.average != null && row.average! < 70
                      ? const Color(0xFFFFD0D0)
                      : const Color(0xFFE9EAF4),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          row.name,
                          style: const TextStyle(
                            color: studentInk,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      Text(
                        row.average == null || row.sample < 3
                            ? 'Insufficient data'
                            : '${row.average!.round()}%',
                        style: TextStyle(
                          color: row.average != null && row.average! < 70
                              ? const Color(0xFFE74747)
                              : const Color(0xFF15885D),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Text(
                    row.average == null || row.sample < 3
                        ? '${row.sample} published result(s). At least 3 are required before Study Coach identifies a learning pattern.'
                        : row.average! < 70
                        ? 'Focus next: ${row.topic}. ${row.overdue > 0 ? '${row.overdue} overdue item also needs attention.' : 'Practice recall before your next assessment.'}'
                        : 'On track. Keep reviewing ${row.topic} to maintain momentum.',
                    style: const TextStyle(color: studentMuted, height: 1.4),
                  ),
                  if (row.average != null &&
                      row.sample >= 3 &&
                      row.average! < 70) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: [
                        ActionChip(
                          label: const Text('Study material'),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => StudentAiStudyPage(
                                subject: row.name,
                                topic: row.topic,
                                notes: notes,
                              ),
                            ),
                          ),
                        ),
                        ActionChip(
                          label: const Text('Make quiz'),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => StudentAiPracticePage(
                                classes: classes,
                                notes: notes,
                                initialClass: row.name,
                                flashcards: false,
                              ),
                            ),
                          ),
                        ),
                        ActionChip(
                          label: const Text('Flashcards'),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => StudentAiPracticePage(
                                classes: classes,
                                notes: notes,
                                initialClass: row.name,
                                flashcards: true,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

String? weakestStudentClass(
  List<Map<String, Object?>> classes,
  List<Map<String, Object?>> grades,
  List<Map<String, Object?>> work,
) {
  String? result;
  double lowest = double.infinity;
  for (final c in classes) {
    final name = '${c['name']}';
    final values = <double>[
      ...grades
          .where((e) => e['class_name'] == name)
          .map((e) => (e['score'] as num) * 100 / (e['max_score'] as num)),
      ...work
          .where((e) => e['class_name'] == name && e['score'] != null)
          .map((e) => (e['score'] as num).toDouble()),
    ];
    final overdue = work
        .where(
          (e) =>
              e['class_name'] == name &&
              e['submitted_at'] == null &&
              (DateTime.tryParse('${e['due_at']}')?.isBefore(DateTime.now()) ??
                  false),
        )
        .length;
    if (values.length < 3 && overdue < 2) continue;
    final average = values.isEmpty
        ? 59.0
        : values.reduce((a, b) => a + b) / values.length;
    if (average < lowest) {
      lowest = average;
      result = name;
    }
  }
  return result;
}

String studentTopicFor(String? subject, List<Map<String, Object?>> notes) {
  final found = notes.where((e) => e['class_name'] == subject).toList();
  return found.isEmpty ? 'recent class topics' : '${found.first['lesson']}';
}
