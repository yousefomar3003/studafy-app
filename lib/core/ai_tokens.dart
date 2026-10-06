import 'package:flutter/material.dart';

import '../l10n/generated/app_l10n.dart';
import 'studafy_design.dart';

/// What AI tokens are, in plain words, with a rough guide to what things
/// use (ADR-0037). Every figure is labelled an estimate: the real count is
/// what the AI provider reports for each request.
Future<void> showTokenGuide(BuildContext context) {
  final l10n = AppL10n.of(context);
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.tokensWhatAreThey,
              style: Theme.of(sheetContext).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.tokensExplained,
              style: const TextStyle(color: studafyInk, height: 1.45),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.tokensGuideTitle,
              style: const TextStyle(
                color: studafyInk,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            for (final (label, amount) in [
              (l10n.tokensGuideShortQuestion, l10n.tokensAbout('1,000')),
              (l10n.tokensGuideLessonQuestion, l10n.tokensAbout('3,000–5,000')),
              (l10n.tokensGuideNotes, l10n.tokensAbout('8,000–15,000')),
              (l10n.tokensGuidePhoto, l10n.tokensAbout('17,000')),
            ])
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(child: Text(label)),
                    const SizedBox(width: 12),
                    Text(
                      amount,
                      style: const TextStyle(
                        color: studafySteel,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 10),
            Text(
              l10n.tokensGuideEstimate,
              style: const TextStyle(color: studafyMuted, fontSize: 12.5),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Why a lesson's file or link could not be read for the AI helper, in
/// words (ADR-0037): the codes the server sends.
String readingReasonText(AppL10n l10n, String? reason) => switch (reason) {
  'processing' => l10n.readingProcessing,
  'needs_model' || 'reading_budget_used' => l10n.readingScannedSkipped,
  'no_text' => l10n.readingNoText,
  'unsupported_type' => l10n.readingUnsupportedType,
  'partly_read' => l10n.readingPartly,
  'link_needs_sign_in' => l10n.readingLinkSignIn,
  'link_video' => l10n.readingLinkVideo,
  'link_not_found' => l10n.readingLinkGone,
  'link_blocked_address' ||
  'link_unreachable' ||
  'link_unsupported_type' ||
  'link_too_large' => l10n.readingLinkUnreachable,
  _ => l10n.readingFailed,
};
