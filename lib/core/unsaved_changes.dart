import 'package:flutter/material.dart';

import '../l10n/generated/app_l10n.dart';

/// Asks before leaving a page that would throw away what was typed or added.
///
/// The same idea as an exam's "Leave without submitting?": back, the
/// Android back button, iOS swipe-back and a tap outside a sheet all ask
/// first - but only while [unsaved] is true, so a page with nothing on it
/// closes as it always did.
///
/// A modal sheet's drag-to-close does not go through this, so a sheet that
/// uses it is opened with dragging off.
class UnsavedChangesScope extends StatelessWidget {
  const UnsavedChangesScope({
    super.key,
    required this.unsaved,
    required this.child,
  });

  /// Whether leaving now would lose something.
  final bool unsaved;

  final Widget child;

  @override
  Widget build(BuildContext context) => PopScope<Object?>(
    canPop: !unsaved,
    onPopInvokedWithResult: (didPop, _) async {
      if (didPop) return;
      final navigator = Navigator.of(context);
      if (await confirmDiscardChanges(context)) navigator.pop();
    },
    child: child,
  );
}

/// "Discard changes?" Answers true when the person chose to discard.
Future<bool> confirmDiscardChanges(BuildContext context) async {
  final l10n = AppL10n.of(context);
  final discard = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.unsavedDiscardTitle),
      content: Text(l10n.unsavedDiscardBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(l10n.unsavedKeepEditing),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(l10n.unsavedDiscard),
        ),
      ],
    ),
  );
  return discard ?? false;
}
