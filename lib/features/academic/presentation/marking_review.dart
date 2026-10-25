import 'package:flutter/material.dart';

import '../../../core/coursework_attachments.dart';
import '../../../core/studafy_components.dart';
import '../../../core/studafy_design.dart';
import '../../../core/user_content_text.dart';
import '../../../l10n/generated/app_l10n.dart';
import '../domain/marking.dart';
import '../domain/online_assessment.dart';

String _number(double value) =>
    value == value.roundToDouble() ? value.toInt().toString() : '$value';

/// One written answer as the teacher reviews a suggestion for it: the
/// question, their own reference, the student's answer and the suggestion,
/// side by side on a wide screen and one under the other on a phone.
///
/// Nothing here saves anything. "Use suggestion" fills in the teacher's own
/// fields through [onUse]; the page's save is still the only writer.
class MarkingAnswerReview extends StatelessWidget {
  const MarkingAnswerReview({
    super.key,
    required this.answer,
    this.reference,
    this.suggestion,
    this.onUse,
    this.onDismiss,
    this.onSuggestAgain,
  });

  final AttemptAnswer answer;
  final MarkingReference? reference;
  final MarkingSuggestion? suggestion;
  final VoidCallback? onUse;
  final VoidCallback? onDismiss;
  final VoidCallback? onSuggestAgain;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);
    final q = answer.question;
    final text = (answer.answerText ?? '').trim();
    final question = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: UserContentText(
                q.prompt,
                style: theme.textTheme.titleSmall,
              ),
            ),
            Text(
              l10n.markOutOf(_number(q.maximumScore)),
              style: theme.textTheme.labelLarge?.copyWith(color: studafyMuted),
            ),
          ],
        ),
        AttachmentsView(
          attachments: q.attachments,
          links: q.links,
          dense: true,
        ),
      ],
    );
    final given = _Block(
      title: l10n.markStudentAnswer,
      icon: Icons.person_outline_rounded,
      children: [
        text.isEmpty
            ? Text(
                l10n.takeNoAnswer,
                style: const TextStyle(color: studafyMuted),
              )
            : UserContentText(text),
      ],
    );
    final reference = MarkingReferencePanel(reference: this.reference);
    final suggestion = this.suggestion == null
        ? null
        : MarkingSuggestionPanel(
            suggestion: this.suggestion!,
            onUse: onUse,
            onDismiss: onDismiss,
            onSuggestAgain: onSuggestAgain,
          );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 640) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              question,
              const SizedBox(height: 10),
              reference,
              const SizedBox(height: 10),
              given,
              if (suggestion != null) ...[
                const SizedBox(height: 10),
                suggestion,
              ],
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            question,
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: reference),
                const SizedBox(width: 16),
                Expanded(child: given),
                if (suggestion != null) ...[
                  const SizedBox(width: 16),
                  Expanded(child: suggestion),
                ],
              ],
            ),
          ],
        );
      },
    );
  }
}

/// A bordered block with a label, for the parts of a review.
class _Block extends StatelessWidget {
  const _Block({required this.title, required this.children, this.icon});

  final String title;
  final IconData? icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: studafyWash.withValues(alpha: .5),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: studafyHairline),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: studafyNavy),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.labelLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ...children,
      ],
    ),
  );
}

Widget _labelled(BuildContext context, String label, String text) => Padding(
  padding: const EdgeInsets.only(top: 4),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.labelSmall),
      UserContentText(text),
    ],
  ),
);

Widget _bullets(List<String> items, IconData icon, Color color) => Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    for (final item in items)
      Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Expanded(child: UserContentText(item)),
          ],
        ),
      ),
  ],
);

/// The teacher's reference: the model answer, the key points with what each
/// is worth, and how part marks are given.
class MarkingReferencePanel extends StatelessWidget {
  const MarkingReferencePanel({super.key, required this.reference});

  final MarkingReference? reference;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final r = reference;
    String? text(String? value) =>
        (value ?? '').trim().isEmpty ? null : value!.trim();
    final accepted = r?.acceptedAnswers ?? const <String>[];
    final parts = r == null
        ? const <Widget>[]
        : [
            if (accepted.isNotEmpty)
              _labelled(
                context,
                l10n.takeAcceptedAnswers,
                accepted.join(' / '),
              ),
            if (text(r.preferredAnswer) case final model?)
              _labelled(context, l10n.builderModelAnswer, model),
            if (r.keyPoints.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                l10n.markingRefsKeyPoints,
                style: Theme.of(context).textTheme.labelSmall,
              ),
              _bullets(
                [
                  for (final point in r.keyPoints)
                    point.marks == null
                        ? point.text
                        : l10n.markingKeyPointWorth(
                            point.text,
                            _number(point.marks!),
                          ),
                ],
                Icons.key_rounded,
                studafyNavy,
              ),
            ],
            if (text(r.acceptedMethods) case final methods?)
              _labelled(context, l10n.markingRefsMethods, methods),
            if (text(r.partialCredit) case final partial?)
              _labelled(context, l10n.markingRefsPartial, partial),
            if (text(r.markingGuidance) case final guidance?)
              _labelled(context, l10n.builderGuidance, guidance),
          ];
    return _Block(
      title: l10n.markingReviewReference,
      icon: Icons.menu_book_rounded,
      children: parts.isEmpty
          ? [
              Text(
                l10n.markingReviewNoReference,
                style: const TextStyle(color: studafyMuted),
              ),
            ]
          : parts,
    );
  }
}

String markingReviewReasonText(AppL10n l10n, MarkingReviewReason reason) =>
    switch (reason) {
      MarkingReviewReason.ambiguous => l10n.markingReviewAmbiguous,
      MarkingReviewReason.unreadable => l10n.markingReviewUnreadable,
      MarkingReviewReason.noReference => l10n.markingReviewNoRef,
      MarkingReviewReason.conflict => l10n.markingReviewConflict,
      MarkingReviewReason.empty => l10n.markingReviewEmpty,
    };

/// A suggestion: the mark out of the maximum, what the answer met and
/// missed, why, feedback for the student, and anything the teacher should
/// look at themselves. [compact] keeps the reasoning behind a tap, for a
/// row of the grade sheet.
class MarkingSuggestionPanel extends StatelessWidget {
  const MarkingSuggestionPanel({
    super.key,
    required this.suggestion,
    this.onUse,
    this.onDismiss,
    this.onSuggestAgain,
    this.compact = false,
  });

  final MarkingSuggestion suggestion;
  final VoidCallback? onUse;
  final VoidCallback? onDismiss;
  final VoidCallback? onSuggestAgain;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);
    final s = suggestion;
    final dismiss = onDismiss == null
        ? null
        : TextButton(onPressed: onDismiss, child: Text(l10n.markingDismiss));
    switch (s.status) {
      case MarkingSuggestionStatus.pending:
        return _Block(
          title: l10n.markingReviewSuggestion,
          icon: Icons.auto_awesome_outlined,
          children: [Text(l10n.markingPending)],
        );
      case MarkingSuggestionStatus.failed || MarkingSuggestionStatus.skipped:
        return _Block(
          title: l10n.markingReviewSuggestion,
          icon: Icons.auto_awesome_outlined,
          children: [
            Text(
              s.optedOut
                  ? l10n.markingOptedOutHand
                  : s.status == MarkingSuggestionStatus.failed
                  ? l10n.markingFailedHand
                  : l10n.markingSkippedHand,
            ),
            ?dismiss,
          ],
        );
      case MarkingSuggestionStatus.ready:
        break;
    }
    final score = s.suggestedScore;
    final reason = s.reviewReason;
    final reasoning = [
      if (s.met.isNotEmpty) ...[
        const SizedBox(height: 6),
        Text(l10n.markingMet, style: theme.textTheme.labelSmall),
        _bullets(s.met, Icons.check_rounded, studafyTeal),
      ],
      if (s.missed.isNotEmpty) ...[
        const SizedBox(height: 6),
        Text(l10n.markingMissed, style: theme.textTheme.labelSmall),
        _bullets(s.missed, Icons.close_rounded, studafyDanger),
      ],
      if ((s.rationale ?? '').trim().isNotEmpty)
        _labelled(context, l10n.markingRationale, s.rationale!.trim()),
    ];
    return _Block(
      title: l10n.markingReviewSuggestion,
      icon: Icons.auto_awesome_outlined,
      children: [
        Text(
          score == null
              ? l10n.markingNoScore
              : l10n.markingSuggestedScore(
                  _number(score),
                  _number(s.maximumScore),
                ),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        if (s.stale || reason != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (s.stale)
                  StatusPill(
                    label: l10n.markingStale,
                    icon: Icons.history_rounded,
                    color: studafyMuted,
                  ),
                if (reason != null)
                  StatusPill(
                    label: l10n.markingNeedsReview,
                    icon: Icons.flag_outlined,
                    color: studafyDanger,
                  ),
              ],
            ),
          ),
        if (reason != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(markingReviewReasonText(l10n, reason)),
          ),
        if ((s.conflict ?? '').trim().isNotEmpty)
          _labelled(context, l10n.markingConflict, s.conflict!.trim()),
        if (compact && reasoning.isNotEmpty)
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: EdgeInsets.zero,
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            title: Text(l10n.markingWhy),
            children: reasoning,
          )
        else
          ...reasoning,
        if ((s.feedback ?? '').trim().isNotEmpty)
          _labelled(
            context,
            l10n.markingFeedbackForStudent,
            s.feedback!.trim(),
          ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (score != null && onUse != null)
              FilledButton.tonalIcon(
                onPressed: onUse,
                icon: const Icon(Icons.edit_note_rounded),
                label: Text(l10n.markingUse),
              ),
            if (s.stale && onSuggestAgain != null)
              TextButton(
                onPressed: onSuggestAgain,
                child: Text(l10n.markingSuggestAgain),
              ),
            ?dismiss,
          ],
        ),
      ],
    );
  }
}
