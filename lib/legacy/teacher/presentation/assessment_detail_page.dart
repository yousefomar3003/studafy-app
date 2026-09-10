part of '../../../teacher_features.dart';

class AssessmentDetailPage extends StatefulWidget {
  const AssessmentDetailPage({super.key, required this.assessment});
  final Map<String, Object?> assessment;
  @override
  State<AssessmentDetailPage> createState() => _AssessmentDetailPageState();
}

class _AssessmentDetailPageState extends State<AssessmentDetailPage> {
  int tab = 0;
  late Future<List<Map<String, Object?>>> _questionsFuture;
  late Future<List<Map<String, Object?>>> _submissionsFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _questionsFuture = StudafyDatabase.instance.assessmentQuestions(
      widget.assessment['id'] as int,
    );
    _submissionsFuture = StudafyDatabase.instance.assessmentSubmissions(
      widget.assessment['id'] as int,
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _canvasColor,
    appBar: AppBar(
      backgroundColor: Colors.white,
      title: Text('${widget.assessment['title']}'),
    ),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Segments(
            labels: const ['Questions', 'Submissions'],
            index: tab,
            onTap: (v) => setState(() => tab = v),
          ),
        ),
        Expanded(child: tab == 0 ? _questions() : _submissions()),
      ],
    ),
  );
  Widget _questions() => FutureBuilder(
    future: _questionsFuture,
    builder: (context, snapshot) {
      final rows = snapshot.data ?? [];
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          FeatureCard(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${widget.assessment['delivery']}' == 'online'
                            ? 'ONLINE EXAM'
                            : 'PAPER / IN-CLASS EXAM',
                        style: const TextStyle(
                          color: _muted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Maximum grade: ${widget.assessment['max_score']}',
                        style: const TextStyle(
                          color: _ink,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                StatusBadge('${widget.assessment['status']}'),
              ],
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: _addQuestion,
            icon: const Icon(Icons.add),
            label: const Text('Add question'),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < rows.length; i)
            Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: FeatureCard(
                onTap: () => _editPreferredAnswer(rows[i]),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: _navy,
                      child: Text(
                        '${i + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${rows[i]['prompt']}',
                            style: const TextStyle(
                              color: _ink,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            rows[i]['answer'] == null ||
                                    '${rows[i]['answer']}'.isEmpty
                                ? 'Tap to add preferred answer'
                                : 'Answer key: ${rows[i]['answer']}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: _muted, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${rows[i]['points']} pts',
                      style: const TextStyle(color: _muted),
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
    },
  );
  Widget _submissions() => FutureBuilder(
    future: _submissionsFuture,
    builder: (context, snapshot) {
      final rows = snapshot.data ?? [];
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (rows.isEmpty)
            const Text('No submissions yet.', style: TextStyle(color: _muted)),
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: FeatureCard(
                onTap: () async {
                  await showGradeSubmission(context, {
                    ...row,
                    'max_score': widget.assessment['max_score'],
                    'assessment_title': widget.assessment['title'],
                    'delivery': widget.assessment['delivery'],
                  });
                  setState(() {
                    _reload();
                  });
                },
                child: Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: _navy,
                      child: Icon(Icons.person, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${row['student_name']}',
                            style: const TextStyle(
                              color: _ink,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            row['score'] == null
                                ? 'Ready for grading'
                                : '${row['score']}/${widget.assessment['max_score']} · ${row['publication_state'] ?? 'draft'}',
                            style: const TextStyle(color: _muted),
                          ),
                        ],
                      ),
                    ),
                    if (row['publication_state'] == 'reviewed')
                      IconButton(
                        tooltip: 'Publish reviewed grade',
                        onPressed: () async {
                          await StudafyDatabase.instance.publishGradeSubmission(
                            row['id'] as int,
                          );
                          if (context.mounted) setState(_reload);
                        },
                        icon: const Icon(Icons.publish_rounded, color: _navy),
                      )
                    else
                      const Icon(Icons.chevron_right, color: _muted),
                  ],
                ),
              ),
            ),
        ],
      );
    },
  );
  Future<void> _addQuestion() async {
    final prompt = TextEditingController(),
        points = TextEditingController(text: '1'),
        answer = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add question'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: prompt,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Question'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: points,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Points'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: answer,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Preferred answer / marking key',
                hintText:
                    'Include required concepts and acceptable alternatives',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              await StudafyDatabase.instance.addQuestion({
                'assessment_id': widget.assessment['id'],
                'prompt': prompt.text.trim(),
                'type': 'long_answer',
                'points': int.tryParse(points.text) ?? 1,
                'options': null,
                'answer': answer.text.trim(),
              });
              if (context.mounted) Navigator.pop(context, true);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (saved == true) {
      setState(() {
        _reload();
      });
    }
  }

  Future<void> _editPreferredAnswer(Map<String, Object?> question) async {
    final answer = TextEditingController(text: '${question['answer'] ?? ''}');
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Preferred answer'),
        content: TextField(
          controller: answer,
          maxLines: 6,
          decoration: const InputDecoration(
            hintText:
                'Required ideas, model answer and acceptable alternatives',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              await StudafyDatabase.instance.updateQuestionAnswer(
                question['id'] as int,
                answer.text.trim(),
              );
              if (context.mounted) Navigator.pop(context, true);
            },
            child: const Text('Save answer key'),
          ),
        ],
      ),
    );
    if (saved == true) setState(_reload);
  }
}

Future<void> showGradeSubmission(
  BuildContext context,
  Map<String, Object?> row,
) async {
  final score = TextEditingController(text: row['score']?.toString() ?? ''),
      feedback = TextEditingController(text: row['feedback']?.toString() ?? '');
  final questions = await StudafyDatabase.instance.assessmentQuestions(
    row['assessment_id'] as int,
  );
  final questionScores = <int, TextEditingController>{
    for (final question in questions)
      question['id'] as int: TextEditingController(),
  };
  if (!context.mounted) return;
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => StatefulBuilder(
      builder: (context, update) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          8,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 28,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${row['student_name']}',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              Text(
                '${row['assessment_title'] ?? ''}',
                style: const TextStyle(color: _muted),
              ),
              const SizedBox(height: 16),
              FeatureCard(
                child: Text(
                  '${row['answer_text'] ?? 'No answer was submitted.'}',
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0EAFF),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.auto_awesome_rounded,
                          color: Color(0xFF7737EE),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'AI-assisted paper grading',
                            style: TextStyle(
                              color: _ink,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        StatusBadge('Teacher review required'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const AiGradingContainmentControls(),
                  ],
                ),
              ),
              if (questions.isNotEmpty) ...[
                const SizedBox(height: 14),
                const Text(
                  'Question review',
                  style: TextStyle(
                    color: _ink,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                for (var i = 0; i < questions.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 9),
                    child: FeatureCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Q${i + 1}. ${questions[i]['prompt']}',
                            style: const TextStyle(
                              color: _ink,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Preferred answer: ${questions[i]['answer'] ?? 'Not supplied — add one in Questions'}',
                            style: const TextStyle(color: _muted, fontSize: 11),
                          ),
                          const SizedBox(height: 9),
                          TextField(
                            controller: questionScores[questions[i]['id']],
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText:
                                  'Mark out of ${questions[i]['points']}',
                              helperText: 'Editable teacher override',
                            ),
                            onChanged: (_) {
                              final total = questionScores.values.fold<double>(
                                0,
                                (sum, controller) =>
                                    sum +
                                    (double.tryParse(controller.text) ?? 0),
                              );
                              score.text = total.toStringAsFixed(1);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
              const SizedBox(height: 14),
              TextField(
                controller: score,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Grade out of ${row['max_score']}',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: feedback,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Feedback'),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () async {
                  final value = double.tryParse(score.text);
                  if (value == null) return;
                  await StudafyDatabase.instance.gradeSubmission(
                    row['id'] as int,
                    value,
                    feedback.text.trim(),
                  );
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text('Complete review · keep unpublished'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class AiGradingContainmentControls extends StatelessWidget {
  const AiGradingContainmentControls({super.key});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text(
        'Temporarily unavailable while secure file ownership, quarantine, malware scanning, and publication controls are built.',
        style: TextStyle(color: _muted, fontSize: 11, height: 1.35),
      ),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        key: const Key('ai-grading-upload-control'),
        onPressed: StudafyRuntime.policy.allowsAiGrading ? () {} : null,
        icon: const Icon(Icons.document_scanner_outlined),
        label: const Text('Scanned-exam uploads are temporarily unavailable'),
      ),
      const SizedBox(height: 10),
      FilledButton.icon(
        key: const Key('ai-grading-generate-control'),
        onPressed: null,
        icon: const Icon(Icons.auto_awesome_rounded),
        label: const Text('Generate proposed marks'),
      ),
    ],
  );
}
