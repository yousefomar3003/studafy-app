import 'package:flutter/material.dart';

import '../../../l10n/generated/app_l10n.dart';
import '../domain/academic_repository.dart';

/// A student handing work in against an assignment.
///
/// Text only today. The submission model already carries attachments —
/// file_bindings links a file to a submission attempt — but the upload
/// pipeline is switched off, so the screen says so plainly and suggests a
/// link rather than offering a button that would fail.
class SubmitWorkPage extends StatefulWidget {
  const SubmitWorkPage({
    super.key,
    required this.repository,
    required this.assignmentId,
    required this.assignmentTitle,
    this.canSubmit = true,
  });

  final AcademicRepository repository;
  final String assignmentId;
  final String assignmentTitle;

  /// False for work that is not open, so a student is told before typing
  /// rather than after.
  final bool canSubmit;

  @override
  State<SubmitWorkPage> createState() => _SubmitWorkPageState();
}

class _SubmitWorkPageState extends State<SubmitWorkPage> {
  final _answer = TextEditingController();
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _answer.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_sending) return;
    final l10n = AppL10n.of(context);
    if (_answer.text.trim().isEmpty) {
      setState(() => _error = l10n.submitEmpty);
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    final done = l10n.submitDone;
    final failed = l10n.submitFailed;
    try {
      await widget.repository.submitAssignment(
        widget.assignmentId,
        _answer.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(done);
    } on Object {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = failed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.submitTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              widget.assignmentTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            if (!widget.canSubmit)
              Text(
                l10n.submitClosed,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              )
            else ...[
              TextField(
                controller: _answer,
                enabled: !_sending,
                minLines: 6,
                maxLines: 16,
                maxLength: 100000,
                decoration: InputDecoration(
                  labelText: l10n.submitAnswerLabel,
                  hintText: l10n.submitAnswerHint,
                  border: const OutlineInputBorder(),
                ),
              ),
              Text(
                l10n.submitAttachmentsSoon,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _sending ? null : _submit,
                child: Text(_sending ? l10n.submitSending : l10n.submitSend),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
