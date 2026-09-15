import 'package:flutter/material.dart';

import '../../../studafy_database.dart';
import '../../../features/academic/data/preview_student_identity.dart';
import 'student_account_pages.dart';
import 'student_ai_ask_page.dart';
import 'student_ai_insights.dart';
import 'student_ai_practice.dart';
import 'student_shared.dart';

class StudentAiPage extends StatefulWidget {
  const StudentAiPage({super.key});
  @override
  State<StudentAiPage> createState() => _StudentAiPageState();
}

class _StudentAiPageState extends State<StudentAiPage> {
  static const studentId = PreviewStudentIdentity.localId;
  late Future<List<Object>> data;

  @override
  void initState() {
    super.initState();
    data = Future.wait<Object>([
      StudafyDatabase.instance.classesForStudent(studentId),
      StudafyDatabase.instance.studentNotebooks(studentId),
      StudafyDatabase.instance.gradesForStudent(studentId),
      StudafyDatabase.instance.workForStudent(studentId),
    ]);
  }

  void _open(Widget page) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: studentCanvas,
    body: Column(
      children: [
        const StudentHeader(title: 'Study Coach'),
        Expanded(
          child: FutureBuilder<List<Object>>(
            future: data,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final classes = snapshot.data![0] as List<Map<String, Object?>>;
              final notes = snapshot.data![1] as List<Map<String, Object?>>;
              final grades = snapshot.data![2] as List<Map<String, Object?>>;
              final work = snapshot.data![3] as List<Map<String, Object?>>;
              final weak = weakestStudentClass(classes, grades, work);
              final weakTopic = studentTopicFor(weak, notes);
              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                children: [
                  Container(
                    padding: const EdgeInsets.all(21),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [studentNavy, Color(0xFF4B3FC2)],
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.auto_awesome_rounded,
                          color: studentCyan,
                          size: 30,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Learn from your classes',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 23,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Your teacher’s notebook content is already connected. Choose a tool and start studying.',
                          style: TextStyle(color: Colors.white70, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                  if (weak != null) ...[
                    const SizedBox(height: 16),
                    _AiRecommendation(
                      subject: weak,
                      topic: weakTopic,
                      onStudy: () => _open(
                        StudentAiStudyPage(
                          subject: weak,
                          topic: weakTopic,
                          notes: notes,
                        ),
                      ),
                      onQuiz: () => _open(
                        StudentAiPracticePage(
                          classes: classes,
                          notes: notes,
                          initialClass: weak,
                          flashcards: false,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  const Text(
                    'Study tools',
                    style: TextStyle(
                      color: studentInk,
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _AiToolTile(
                    icon: Icons.chat_bubble_outline_rounded,
                    title: 'Ask Me',
                    subtitle:
                        'Ask about your notebook, or attach something new',
                    onTap: () => _open(const AskAiPage()),
                  ),
                  _AiToolTile(
                    icon: Icons.quiz_outlined,
                    title: 'Create a quiz',
                    subtitle: 'Choose a class and lesson topic',
                    onTap: () => _open(
                      StudentAiPracticePage(
                        classes: classes,
                        notes: notes,
                        flashcards: false,
                      ),
                    ),
                  ),
                  _AiToolTile(
                    icon: Icons.style_outlined,
                    title: 'Make flashcards',
                    subtitle: 'Review key facts from teacher materials',
                    onTap: () => _open(
                      StudentAiPracticePage(
                        classes: classes,
                        notes: notes,
                        flashcards: true,
                      ),
                    ),
                  ),
                  _AiToolTile(
                    icon: Icons.insights_rounded,
                    title: 'Learning evaluator',
                    subtitle: 'Find weak subjects and get a focused next step',
                    onTap: () => _open(
                      StudentAiEvaluatorPage(
                        classes: classes,
                        notes: notes,
                        grades: grades,
                        work: work,
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

class _AiRecommendation extends StatelessWidget {
  const _AiRecommendation({
    required this.subject,
    required this.topic,
    required this.onStudy,
    required this.onQuiz,
  });
  final String subject, topic;
  final VoidCallback onStudy, onQuiz;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF8E8),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFF0D89A)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recommended for you',
          style: TextStyle(
            color: Color(0xFFB87500),
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          '$subject · $topic',
          style: const TextStyle(
            color: studentInk,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 5),
        const Text(
          'Recent results suggest this is the best place to focus next.',
          style: TextStyle(color: studentMuted, height: 1.35),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: onStudy,
                child: const Text('Study material'),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: FilledButton(
                onPressed: onQuiz,
                style: FilledButton.styleFrom(backgroundColor: studentNavy),
                child: const Text('Practice quiz'),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _AiToolTile extends StatelessWidget {
  const _AiToolTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 11),
    child: Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFE9EAF4)),
      ),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFEFEDFF),
          foregroundColor: studentNavy,
          child: Icon(icon),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: studentInk,
            fontWeight: FontWeight.w900,
          ),
        ),
        subtitle: Text(subtitle, style: const TextStyle(color: studentMuted)),
        trailing: const Icon(Icons.chevron_right_rounded, color: studentMuted),
      ),
    ),
  );
}
