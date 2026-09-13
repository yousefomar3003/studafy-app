import 'package:flutter/material.dart';

import '../../../studafy_database.dart';
import 'student_shared.dart';

class StudentExamCard extends StatelessWidget {
  const StudentExamCard({super.key, required this.exam, required this.onOpen});
  final Map<String, Object?> exam;
  final VoidCallback onOpen;
  @override
  Widget build(BuildContext context) {
    final paper = '${exam['delivery']}' != 'online',
        submitted = exam['submitted_at'] != null,
        scheduled = DateTime.tryParse('${exam['scheduled_at']}'),
        open =
            !paper &&
            !submitted &&
            (scheduled == null || !scheduled.isAfter(DateTime.now()));
    final status = paper
        ? (exam['score'] == null ? 'Awaiting result' : 'Result published')
        : submitted
        ? (exam['score'] == null ? 'Submitted' : 'Marked')
        : open
        ? 'Open now'
        : 'Scheduled';
    final color = submitted
        ? studentMuted
        : open
        ? const Color(0xFF15885D)
        : const Color(0xFFB87500);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: .24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${exam['class_name']}',
                  style: const TextStyle(
                    color: studentMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              StudentWorkStatus(label: status, color: color),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            '${exam['title']}',
            style: const TextStyle(
              color: studentNavy,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            '${exam['type']} · ${exam['max_score']} marks${scheduled == null ? '' : ' · ${studentShortDate('${exam['scheduled_at']}')}'}',
            style: const TextStyle(color: studentMuted, fontSize: 11),
          ),
          const SizedBox(height: 13),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: open ? onOpen : null,
              child: Text(
                paper
                    ? (exam['score'] == null
                          ? 'Paper exam · result pending'
                          : 'Grade ${studentScore(exam['score'])}/${exam['max_score']}')
                    : submitted
                    ? (exam['score'] == null
                          ? 'Awaiting marking'
                          : 'Marked ${studentScore(exam['score'])}/${exam['max_score']}')
                    : open
                    ? 'Start ${'${exam['type']}'.toLowerCase()}'
                    : 'Not open yet',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExamRunner extends StatefulWidget {
  const _ExamRunner({required this.exam, required this.studentId});
  final Map<String, Object?> exam;
  final int studentId;
  @override
  State<_ExamRunner> createState() => _ExamRunnerState();
}

class _ExamRunnerState extends State<_ExamRunner> {
  int current = 0;
  List<Map<String, Object?>> questions = [];
  final answers = <int, String>{};

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: studentCanvas,
    appBar: AppBar(
      backgroundColor: Colors.white,
      title: Text('${widget.exam['type']}'),
      actions: [TextButton(onPressed: _review, child: const Text('Review'))],
    ),
    body: FutureBuilder<List<Map<String, Object?>>>(
      future: StudafyDatabase.instance.assessmentQuestions(
        widget.exam['id'] as int,
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        questions = snapshot.data!;
        if (questions.isEmpty) {
          return const StudentEmptyState(
            icon: Icons.quiz_outlined,
            title: 'Questions unavailable',
            message: 'Ask your teacher to publish the exam questions.',
          );
        }
        final question = questions[current],
            options = _options('${question['options'] ?? ''}');
        return Column(
          children: [
            Container(
              color: studentNavy,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Question ${current + 1} of ${questions.length} · ${widget.exam['title']}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        '${question['points']} marks',
                        style: const TextStyle(
                          color: studentCyan,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 9),
                  LinearProgressIndicator(
                    value: (current + 1) / questions.length,
                    minHeight: 4,
                    backgroundColor: Colors.white24,
                    color: studentCyan,
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    '${question['prompt']}',
                    style: const TextStyle(
                      color: studentNavy,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (options.isNotEmpty)
                    RadioGroup<String>(
                      groupValue: answers[question['id']],
                      onChanged: (value) => setState(
                        () => answers[question['id'] as int] = value ?? '',
                      ),
                      child: Column(
                        children: [
                          for (final option in options)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 9),
                              child: Material(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(15),
                                child: RadioListTile<String>(
                                  value: option,
                                  title: Text(option),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    )
                  else
                    TextFormField(
                      key: ValueKey(question['id']),
                      initialValue: answers[question['id']] ?? '',
                      minLines: 5,
                      maxLines: 10,
                      onChanged: (value) =>
                          answers[question['id'] as int] = value,
                      decoration: const InputDecoration(
                        hintText: 'Write your answer here…',
                        alignLabelWithHint: true,
                      ),
                    ),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                child: Row(
                  children: [
                    if (current > 0)
                      OutlinedButton(
                        onPressed: () => setState(() => current--),
                        child: const Text('Previous'),
                      ),
                    if (current > 0) const SizedBox(width: 9),
                    Expanded(
                      child: FilledButton(
                        onPressed: current == questions.length - 1
                            ? _review
                            : () => setState(() => current++),
                        child: Text(
                          current == questions.length - 1
                              ? 'Review answers'
                              : 'Next question',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    ),
  );

  Future<void> _review() async {
    if (questions.isEmpty) return;
    final unanswered = questions
        .where((q) => (answers[q['id']] ?? '').trim().isEmpty)
        .length;
    final submit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          unanswered == 0
              ? Icons.fact_check_outlined
              : Icons.warning_amber_rounded,
          color: unanswered == 0 ? studentNavy : const Color(0xFFB87500),
          size: 38,
        ),
        title: const Text('Review and submit'),
        content: Text(
          unanswered == 0
              ? 'All ${questions.length} questions have answers. Once submitted, you cannot change them.'
              : '$unanswered of ${questions.length} questions are unanswered. You can return to complete them or submit now.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep reviewing'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Submit exam'),
          ),
        ],
      ),
    );
    if (submit != true) return;
    final encoded = questions
        .map((q) => 'Q${q['id']}: ${answers[q['id']] ?? '[unanswered]'}')
        .join('\n');
    await StudafyDatabase.instance.submitAssessment(
      widget.exam['id'] as int,
      widget.studentId,
      encoded,
    );
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: const Icon(
          Icons.check_circle_rounded,
          color: Color(0xFF15885D),
          size: 42,
        ),
        title: const Text('Exam submitted'),
        content: const Text(
          'Your answers were submitted successfully. Your result will appear after your teacher marks and publishes it.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
    if (mounted) Navigator.pop(context);
  }
}

List<String> _options(String raw) => raw.trim().isEmpty
    ? []
    : raw
          .split(RegExp(r'\n|\|'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
