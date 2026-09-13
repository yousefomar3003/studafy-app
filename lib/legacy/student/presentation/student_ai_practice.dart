import 'package:flutter/material.dart';

import '../../../features/study_coach/domain/study_coach_repository.dart';
import '../../../features/study_coach/presentation/study_coach_scope.dart';
import 'student_shared.dart';

class StudentAiPracticePage extends StatefulWidget {
  const StudentAiPracticePage({
    super.key,
    required this.classes,
    required this.notes,
    required this.flashcards,
    this.initialClass,
  });
  final List<Map<String, Object?>> classes, notes;
  final bool flashcards;
  final String? initialClass;
  @override
  State<StudentAiPracticePage> createState() => _StudentAiPracticePageState();
}

class _StudentAiPracticePageState extends State<StudentAiPracticePage> {
  String? selectedClass;
  String? selectedTopic;
  bool generating = false;
  String? error;

  List<String> get classNames => widget.classes
      .map((entry) => '${entry['name']}')
      .where((name) => name.trim().isNotEmpty)
      .toSet()
      .toList();

  @override
  void initState() {
    super.initState();
    selectedClass =
        widget.initialClass ?? (classNames.isEmpty ? null : classNames.first);
  }

  List<String> get topics {
    final found = widget.notes
        .where((e) => e['class_name'] == selectedClass)
        .map((e) => '${e['lesson']}')
        .where((e) => e.trim().isNotEmpty)
        .toSet()
        .toList();
    return found.isEmpty
        ? ['Current lesson', 'Recent homework', 'Key concepts']
        : found;
  }

  Future<void> _generate() async {
    final topic = selectedTopic ?? topics.first;
    setState(() {
      generating = true;
      error = null;
    });
    try {
      final row = widget.classes.firstWhere(
        (item) => '${item['name']}' == selectedClass,
      );
      final classroomId = row['remote_id'] as String?;
      if (classroomId == null) {
        throw StateError(
          'This class is still syncing. Practice can be generated when sync completes.',
        );
      }
      final studyCoach = StudyCoachScope.read(context);
      final page = widget.flashcards
          ? _FlashcardSession(
              subject: selectedClass ?? 'Class',
              topic: topic,
              cards: await studyCoach.flashcards(
                classroomId: classroomId,
                topic: topic,
              ),
            )
          : _AiQuizSession(
              subject: selectedClass ?? 'Class',
              topic: topic,
              questions: await studyCoach.quiz(
                classroomId: classroomId,
                topic: topic,
              ),
            );
      if (mounted) {
        await Navigator.of(context)
            .push(MaterialPageRoute<void>(builder: (_) => page));
      }
    } catch (caught) {
      if (mounted) {
        setState(() => error = '$caught'.replaceFirst('Bad state: ', ''));
      }
    } finally {
      if (mounted) setState(() => generating = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: studentCanvas,
    appBar: AppBar(
      title: Text(widget.flashcards ? 'Create flashcards' : 'Create a quiz'),
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Choose your material',
          style: TextStyle(
            color: studentInk,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'The AI uses the selected teacher notebook and its attachments automatically.',
          style: TextStyle(color: studentMuted, height: 1.4),
        ),
        const SizedBox(height: 22),
        DropdownButtonFormField<String>(
          initialValue: selectedClass,
          decoration: const InputDecoration(labelText: 'Class'),
          items: classNames
              .map((name) => DropdownMenuItem(value: name, child: Text(name)))
              .toList(),
          onChanged: (v) => setState(() {
            selectedClass = v;
            selectedTopic = null;
          }),
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(
          initialValue: selectedTopic,
          decoration: const InputDecoration(labelText: 'Topic'),
          items: topics
              .map(
                (e) => DropdownMenuItem(
                  value: e,
                  child: Text(e, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
          onChanged: (v) => setState(() => selectedTopic = v),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: selectedClass == null || generating ? null : _generate,
          style: FilledButton.styleFrom(
            backgroundColor: studentNavy,
            minimumSize: const Size.fromHeight(54),
          ),
          icon: Icon(
            widget.flashcards ? Icons.style_outlined : Icons.quiz_outlined,
          ),
          label: Text(
            generating
                ? 'Generating from class material…'
                : widget.flashcards
                ? 'Generate flashcards'
                : 'Generate quiz',
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 10),
          Text(error!, style: const TextStyle(color: Color(0xFFE74747))),
        ],
      ],
    ),
  );
}

class _AiQuizSession extends StatefulWidget {
  const _AiQuizSession({
    required this.subject,
    required this.topic,
    required this.questions,
  });
  final String subject, topic;
  final List<StudyQuizQuestion> questions;
  @override
  State<_AiQuizSession> createState() => _AiQuizSessionState();
}

class _AiQuizSessionState extends State<_AiQuizSession> {
  int index = 0;
  int? selected;
  int correct = 0;
  List<StudyQuizQuestion> get questions => widget.questions;

  void _next() {
    if (selected == null) return;
    if (selected == questions[index].correctIndex) correct++;
    if (index == questions.length - 1) {
      showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Quiz complete'),
          content: Text(
            'You scored $correct out of ${questions.length}. Your result can now inform future study recommendations.',
          ),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text('Done'),
            ),
          ],
        ),
      );
    } else {
      setState(() {
        index++;
        selected = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = questions[index];
    return Scaffold(
      backgroundColor: studentCanvas,
      appBar: AppBar(title: Text(widget.subject)),
      body: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LinearProgressIndicator(
              value: (index + 1) / questions.length,
              color: studentCyan,
              backgroundColor: const Color(0xFFE5E6F1),
            ),
            const SizedBox(height: 28),
            Text(
              'Question ${index + 1} of ${questions.length}',
              style: const TextStyle(
                color: studentMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              q.prompt,
              style: const TextStyle(
                color: studentInk,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 20),
            RadioGroup<int>(
              groupValue: selected,
              onChanged: (value) => setState(() => selected = value),
              child: Column(
                children: [
                  for (var i = 0; i < q.options.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: RadioListTile<int>(
                        value: i,
                        title: Text(q.options[i]),
                        tileColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                          side: const BorderSide(color: Color(0xFFE2E4F0)),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const Spacer(),
            FilledButton(
              onPressed: selected == null ? null : _next,
              style: FilledButton.styleFrom(
                backgroundColor: studentNavy,
                minimumSize: const Size.fromHeight(54),
              ),
              child: Text(
                index == questions.length - 1 ? 'Finish quiz' : 'Next question',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FlashcardSession extends StatefulWidget {
  const _FlashcardSession({
    required this.subject,
    required this.topic,
    required this.cards,
  });
  final String subject, topic;
  final List<StudyFlashcard> cards;
  @override
  State<_FlashcardSession> createState() => _FlashcardSessionState();
}

class _FlashcardSessionState extends State<_FlashcardSession> {
  int index = 0;
  bool answer = false;
  List<StudyFlashcard> get cards => widget.cards;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: studentCanvas,
    appBar: AppBar(title: const Text('Flashcards')),
    body: Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        children: [
          Text(
            '${widget.subject} · ${index + 1} of ${cards.length}',
            style: const TextStyle(
              color: studentMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => answer = !answer),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: const [
                    BoxShadow(color: Color(0x12000000), blurRadius: 18),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      answer ? 'ANSWER' : 'QUESTION',
                      style: const TextStyle(
                        color: studentCyan,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 15),
                    Text(
                      answer ? cards[index].back : cards[index].front,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: studentInk,
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      'Tap card to flip',
                      style: TextStyle(color: studentMuted),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: index == 0
                      ? null
                      : () => setState(() {
                          index--;
                          answer = false;
                        }),
                  child: const Text('Previous'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    if (index == cards.length - 1) {
                      Navigator.pop(context);
                    } else {
                      setState(() {
                        index++;
                        answer = false;
                      });
                    }
                  },
                  style: FilledButton.styleFrom(backgroundColor: studentNavy),
                  child: Text(index == cards.length - 1 ? 'Finish' : 'Next'),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
