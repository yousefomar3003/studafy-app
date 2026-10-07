import 'package:flutter/material.dart';

import '../l10n/generated/app_l10n.dart';
import 'ai_tokens.dart';
import 'material_selection.dart';
import 'studafy_design.dart';
import 'user_content_text.dart';

/// Chosen files or links that cannot be used now, named, with the two
/// honest ways on (ADR-0039): wait and try again, or continue without
/// them. True means continue without them; anything else, do nothing yet.
Future<bool> confirmContinueWithout(
  BuildContext context,
  MaterialUnavailableException error, {
  MaterialSelection? selection,
}) async {
  final l10n = AppL10n.of(context);
  final go = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.unavailableTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.unavailableBody),
            const SizedBox(height: 10),
            for (final entry in error.sources.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(
                        Icons.insert_drive_file_outlined,
                        size: 18,
                        color: studafyMuted,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          UserContentText(
                            selection?.sourceName(entry.key) ??
                                l10n.unavailableFile,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            entry.value == 'processing'
                                ? l10n.pickStillReading
                                : readingReasonText(l10n, entry.value),
                            style: const TextStyle(
                              color: studafyMuted,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(l10n.unavailableLater),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(l10n.unavailableContinue),
        ),
      ],
    ),
  );
  return go ?? false;
}
