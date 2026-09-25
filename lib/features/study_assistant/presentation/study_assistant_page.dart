import 'package:flutter/material.dart';

import '../../../core/user_content_text.dart';
import '../../../l10n/generated/app_l10n.dart';
import '../application/study_assistant_interactor.dart';
import '../domain/study_assistant_repository.dart';

/// The student's study assistant.
///
/// Deliberately a single question and answer rather than a running chat: a
/// transcript would be a record of a child's questions, and the less of that
/// exists the less there is to lose. Nothing here is stored on the device or
/// on the server.
class StudyAssistantPage extends StatefulWidget {
  const StudyAssistantPage({super.key, required this.assistant, this.actions});

  final StudyAssistantInteractor assistant;
  final List<Widget>? actions;

  @override
  State<StudyAssistantPage> createState() => _StudyAssistantPageState();
}

class _StudyAssistantPageState extends State<StudyAssistantPage> {
  final TextEditingController _controller = TextEditingController();
  bool _asking = false;
  String? _answer;
  String? _error;
  int? _remaining;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _ask() async {
    // Guarded rather than only disabled: a second tap that lands in the same
    // frame would otherwise spend two of the day's questions on one.
    if (_asking) return;
    final question = _controller.text.trim();
    if (question.length < 3) return;
    setState(() {
      _asking = true;
      _error = null;
      _answer = null;
    });
    final result = await widget.assistant.ask(question);
    if (!mounted) return;
    result.fold(
      onSuccess: (StudyAnswer value) => setState(() {
        _asking = false;
        _answer = value.answer;
        _remaining = value.remainingToday;
      }),
      onFailure: (failure) => setState(() {
        _asking = false;
        _error = failure.message;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final answer = _answer;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.studyAssistantTitle),
        actions: widget.actions,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              l10n.studyAssistantIntro,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              enabled: !_asking,
              minLines: 2,
              maxLines: 5,
              maxLength: 1000,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                labelText: l10n.studyAssistantField,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _asking ? null : _ask,
              icon: const Icon(Icons.school_outlined),
              label: Text(
                _asking ? l10n.studyAssistantBusy : l10n.studyAssistantAsk,
              ),
            ),
            if (_asking) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ],
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            if (answer != null) ...[
              const SizedBox(height: 20),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  // The model's reply is text somebody else produced, so it
                  // renders in its own direction rather than the interface's.
                  child: UserContentText(answer),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.studyAssistantCheckWork,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (_remaining != null) ...[
              const SizedBox(height: 8),
              Text(
                l10n.studyAssistantRemaining(_remaining!),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
