import 'package:flutter/material.dart';

import '../../../core/studafy_design.dart';
import '../domain/messaging.dart';
import 'messaging_scope.dart';
import 'messaging_strings.dart';

/// Opens the report sheet. Returns true once a report was accepted.
///
/// Apple guideline 1.2 and Google Play's user-generated-content policy both
/// require a clearly labelled way to report content and people. This sheet
/// is that control, and it offers to block the person in the same step.
Future<bool> showReportSheet(
  BuildContext context, {
  required String schoolId,
  required ReportTarget target,
  String? messageId,
  String? conversationId,
  String? subjectUserId,
  String? subjectName,
}) async {
  final sent = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
      ),
      child: _ReportSheet(
        schoolId: schoolId,
        target: target,
        messageId: messageId,
        conversationId: conversationId,
        subjectUserId: subjectUserId,
        subjectName: subjectName,
      ),
    ),
  );
  return sent ?? false;
}

class _ReportSheet extends StatefulWidget {
  const _ReportSheet({
    required this.schoolId,
    required this.target,
    this.messageId,
    this.conversationId,
    this.subjectUserId,
    this.subjectName,
  });

  final String schoolId;
  final ReportTarget target;
  final String? messageId;
  final String? conversationId;
  final String? subjectUserId;
  final String? subjectName;

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  ReportReason? _reason;
  final _details = TextEditingController();
  bool _consent = false;
  bool _alsoBlock = false;
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final reason = _reason;
    if (reason == null || _sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    final interactor = MessagingScope.of(context);
    final result = await interactor.report(
      schoolId: widget.schoolId,
      target: widget.target,
      reasonLabel: messagingText(context, 'reason.${reason.name}'),
      details: _details.text,
      messageId: widget.messageId,
      conversationId: widget.conversationId,
      subjectUserId: widget.subjectUserId,
      contactConsent: _consent,
    );
    if (!mounted) return;
    final failure = result.fold(onSuccess: (_) => null, onFailure: (f) => f);
    if (failure != null) {
      setState(() {
        _sending = false;
        _error = messagingFailureText(context, failure);
      });
      return;
    }
    final subject = widget.subjectUserId;
    if (_alsoBlock && subject != null) {
      await interactor.block(schoolId: widget.schoolId, userId: subject);
    }
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    String t(String key) => messagingText(context, key);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.subjectName == null
                  ? t('report.title')
                  : messagingText(context, 'menu.reportPerson', {
                      'name': widget.subjectName!,
                    }),
              style: const TextStyle(
                color: studafyInk,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              t('report.intro'),
              style: const TextStyle(color: studafyMuted),
            ),
            const SizedBox(height: 16),
            Text(
              t('report.reason'),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            RadioGroup<ReportReason>(
              groupValue: _reason,
              onChanged: (value) => setState(() => _reason = value),
              child: Column(
                children: [
                  for (final reason in ReportReason.values)
                    RadioListTile<ReportReason>(
                      value: reason,
                      contentPadding: EdgeInsets.zero,
                      title: Text(t('reason.${reason.name}')),
                    ),
                ],
              ),
            ),
            if (_reason == ReportReason.safety)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1F0),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  t('report.urgent'),
                  style: const TextStyle(color: Color(0xFF8A1C12)),
                ),
              ),
            TextField(
              controller: _details,
              maxLength: 1000,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: t('report.details'),
                border: const OutlineInputBorder(),
              ),
            ),
            CheckboxListTile(
              value: _consent,
              contentPadding: EdgeInsets.zero,
              onChanged: (value) => setState(() => _consent = value ?? false),
              title: Text(t('report.consent')),
            ),
            if (widget.subjectUserId != null)
              CheckboxListTile(
                value: _alsoBlock,
                contentPadding: EdgeInsets.zero,
                onChanged: (value) =>
                    setState(() => _alsoBlock = value ?? false),
                title: Text(t('report.alsoBlock')),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Color(0xFFB3261E)),
                ),
              ),
            FilledButton(
              onPressed: _reason == null || _sending ? null : _submit,
              child: Text(t('report.submit')),
            ),
          ],
        ),
      ),
    );
  }
}

/// Confirms and applies a block. Returns true when the person is blocked.
Future<bool> confirmBlock(
  BuildContext context, {
  required String schoolId,
  required String userId,
  required String name,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(messagingText(dialogContext, 'block.title', {'name': name})),
      content: Text(messagingText(dialogContext, 'block.message')),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(messagingText(dialogContext, 'cancel')),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(messagingText(dialogContext, 'block.confirm')),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return false;
  final result = await MessagingScope.of(context)
      .block(schoolId: schoolId, userId: userId);
  if (!context.mounted) return false;
  final messenger = ScaffoldMessenger.of(context);
  return result.fold(
    onSuccess: (_) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(messagingText(context, 'block.done', {'name': name})),
        ),
      );
      return true;
    },
    onFailure: (failure) {
      messenger.showSnackBar(
        SnackBar(content: Text(messagingFailureText(context, failure))),
      );
      return false;
    },
  );
}
