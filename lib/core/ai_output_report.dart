import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/generated/app_l10n.dart';
import 'feedback.dart';
import 'idempotency.dart';
import 'studafy_design.dart';

/// Reporting an AI answer (DL-076). Google Play's AI-Generated Content
/// policy and Apple's review ask that a person can flag an offensive AI
/// answer from inside the app. Every AI surface - the AI Tutor's answers,
/// notes written from a photo or a lesson, study notebooks, quizzes and
/// flashcards - offers the same small Report action and the same sheet.
///
/// Separate from the safety reports, which belong to a school: a student
/// with no class can report too. The report carries the text the AI wrote,
/// so a reviewer can see what was said.

/// Which AI feature wrote what is reported.
enum AiOutputFeature { tutor, notes, notebook, quiz, flashcards, summary }

/// Why it is reported.
enum AiOutputReportReason { offensive, harmful, wrong, other }

/// The most of an AI answer a report carries.
const aiOutputExcerptLimit = 4000;

@immutable
class AiOutputReport {
  const AiOutputReport({
    required this.feature,
    required this.reason,
    required this.excerpt,
    this.details,
  });

  final AiOutputFeature feature;
  final AiOutputReportReason reason;

  /// The AI's text as the app showed it, at most [aiOutputExcerptLimit]
  /// characters.
  final String excerpt;

  /// What the person added; null when nothing.
  final String? details;
}

/// Sends a report. Throws when it could not be sent.
abstract interface class AiOutputReporter {
  /// [idempotencyKey] is the same for a retry of the same report, so a
  /// report that did arrive before a timeout is not filed twice.
  Future<void> report(AiOutputReport report, {required String idempotencyKey});
}

/// Makes the reporter reachable from every AI surface. Installed above the
/// app Navigator; without one, no Report action is shown.
class AiOutputReportScope extends InheritedWidget {
  const AiOutputReportScope({
    super.key,
    required this.reporter,
    required super.child,
  });

  final AiOutputReporter reporter;

  static AiOutputReporter? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AiOutputReportScope>()?.reporter;

  @override
  bool updateShouldNotify(AiOutputReportScope oldWidget) =>
      reporter != oldWidget.reporter;
}

/// [text] trimmed and cut to [aiOutputExcerptLimit] UTF-16 units, never
/// through the middle of a surrogate pair.
String aiOutputExcerpt(String text) {
  final trimmed = text.trim();
  if (trimmed.length <= aiOutputExcerptLimit) return trimmed;
  var end = aiOutputExcerptLimit;
  final last = trimmed.codeUnitAt(end - 1);
  if (last >= 0xD800 && last <= 0xDBFF) end -= 1;
  return trimmed.substring(0, end);
}

/// Whether a Report action can be offered here: a reporter is installed and
/// there is something to report.
bool canReportAiOutput(BuildContext context, String excerpt) =>
    AiOutputReportScope.maybeOf(context) != null && excerpt.trim().isNotEmpty;

/// Asks why, then sends the report. A snackbar says it was sent, or that it
/// was not, with Try again (the same report, under the same key).
Future<void> reportAiOutput(
  BuildContext context, {
  required AiOutputFeature feature,
  required String excerpt,
}) async {
  final reporter = AiOutputReportScope.maybeOf(context);
  final text = aiOutputExcerpt(excerpt);
  if (reporter == null || text.isEmpty) return;
  final messenger = ScaffoldMessenger.of(context);
  final l10n = AppL10n.of(context);
  final choice = await showModalBottomSheet<_Choice>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
      ),
      child: const AiOutputReportSheet(),
    ),
  );
  if (choice == null) return;
  final report = AiOutputReport(
    feature: feature,
    reason: choice.reason,
    excerpt: text,
    details: choice.details,
  );
  final key = newIdempotencyKey('ai-output-report');
  Future<void> send() async {
    try {
      await reporter.report(report, idempotencyKey: key);
      messenger
        ..hideCurrentSnackBar()
        ..showMessage(l10n.aiReportSent);
    } on Object {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(l10n.aiReportFailed),
            action: SnackBarAction(
              label: l10n.aiReportRetry,
              onPressed: () => unawaited(send()),
            ),
          ),
        );
    }
  }

  await send();
}

/// What the person chose in the sheet.
@immutable
class _Choice {
  const _Choice(this.reason, this.details);

  final AiOutputReportReason reason;
  final String? details;
}

String aiOutputReasonLabel(AppL10n l10n, AiOutputReportReason reason) =>
    switch (reason) {
      AiOutputReportReason.offensive => l10n.aiReportReasonOffensive,
      AiOutputReportReason.harmful => l10n.aiReportReasonHarmful,
      AiOutputReportReason.wrong => l10n.aiReportReasonWrong,
      AiOutputReportReason.other => l10n.aiReportReasonOther,
    };

/// Why, and anything to add. Pops with the choice when Send is tapped.
class AiOutputReportSheet extends StatefulWidget {
  const AiOutputReportSheet({super.key});

  @override
  State<AiOutputReportSheet> createState() => _AiOutputReportSheetState();
}

class _AiOutputReportSheetState extends State<AiOutputReportSheet> {
  AiOutputReportReason? _reason;
  final _details = TextEditingController();

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  void _send() {
    final reason = _reason;
    if (reason == null) return;
    final details = _details.text.trim();
    Navigator.pop(context, _Choice(reason, details.isEmpty ? null : details));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.aiReportTitle,
              style: const TextStyle(
                color: studafyInk,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.aiReportIntro,
              style: const TextStyle(color: studafyMuted),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.aiReportReason,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            RadioGroup<AiOutputReportReason>(
              groupValue: _reason,
              onChanged: (value) => setState(() => _reason = value),
              child: Column(
                children: [
                  for (final reason in AiOutputReportReason.values)
                    RadioListTile<AiOutputReportReason>(
                      value: reason,
                      contentPadding: EdgeInsets.zero,
                      title: Text(aiOutputReasonLabel(l10n, reason)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _details,
              maxLength: 1000,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: l10n.aiReportDetails,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _reason == null ? null : _send,
              child: Text(l10n.aiReportSend),
            ),
          ],
        ),
      ),
    );
  }
}

/// The Report action for an app bar: a flag, with "Report this AI answer"
/// as its tooltip. Nothing when there is no reporter or nothing to report.
class AiOutputReportButton extends StatelessWidget {
  const AiOutputReportButton({
    super.key,
    required this.feature,
    required this.excerpt,
  });

  final AiOutputFeature feature;

  /// Read when tapped, so it is what is on screen then.
  final String Function() excerpt;

  @override
  Widget build(BuildContext context) {
    if (AiOutputReportScope.maybeOf(context) == null) {
      return const SizedBox.shrink();
    }
    return IconButton(
      tooltip: AppL10n.of(context).aiReportTooltip,
      onPressed: () =>
          reportAiOutput(context, feature: feature, excerpt: excerpt()),
      icon: const Icon(Icons.outlined_flag_rounded),
    );
  }
}
