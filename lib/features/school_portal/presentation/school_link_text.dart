import 'package:flutter/material.dart';

import '../../../core/failures.dart';
import '../../../l10n/generated/app_l10n.dart';
import '../domain/school_links.dart';

/// What a link's state is called on screen (a waiting one is listed under
/// its own heading instead).
String schoolLinkStatusText(AppL10n l10n, SchoolLinkStatus status) =>
    switch (status) {
      SchoolLinkStatus.pending => l10n.schoolLinksPendingSection,
      SchoolLinkStatus.linked => l10n.schoolLinkStatusLinked,
      SchoolLinkStatus.declined => l10n.schoolLinkStatusDeclined,
      SchoolLinkStatus.cancelled => l10n.schoolLinkStatusCancelled,
      SchoolLinkStatus.expired => l10n.schoolLinkStatusExpired,
      SchoolLinkStatus.unlinked => l10n.schoolLinkStatusUnlinked,
    };

String schoolKindText(AppL10n l10n, SchoolKind kind) => switch (kind) {
  SchoolKind.public => l10n.schoolLinkKindPublic,
  SchoolKind.private => l10n.schoolLinkKindPrivate,
  SchoolKind.international => l10n.schoolLinkKindInternational,
  SchoolKind.other => l10n.schoolLinkKindOther,
};

/// Why a School Portal action did not happen, in the reader's words.
String schoolLinkFailureText(AppL10n l10n, Failure failure) =>
    switch (failure.code) {
      'SCHOOL_UNAVAILABLE' => l10n.schoolLinkErrorUnavailable,
      'ALREADY_REPORTED' => l10n.schoolLinkErrorAlreadyReported,
      'INVALID_STATE' || 'NOT_FOUND' => l10n.schoolLinkNoLongerWaiting,
      _ when failure.code == Failure.network.code =>
        l10n.schoolLinkErrorNetwork,
      _ => l10n.schoolLinkErrorGeneric,
    };

/// A yes/no question; true only when the person confirms.
Future<bool> confirmSchoolLink(
  BuildContext context, {
  required String title,
  required String body,
  required String confirm,
  bool destructive = false,
}) async {
  final l10n = AppL10n.of(context);
  final answer = await showDialog<bool>(
    context: context,
    builder: (dialog) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialog).pop(false),
          child: Text(l10n.schoolLinkCancel),
        ),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(
                  backgroundColor: Theme.of(dialog).colorScheme.error,
                )
              : null,
          onPressed: () => Navigator.of(dialog).pop(true),
          child: Text(confirm),
        ),
      ],
    ),
  );
  return answer == true;
}
