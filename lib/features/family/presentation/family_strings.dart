import 'package:flutter/widgets.dart';

import '../../../core/failures.dart';
import '../../../l10n/generated/app_l10n.dart';

/// Guardian home copy in both shipped locales.
/// A table key looked up at runtime (an error code, a role, a status),
/// resolved against the app's translations. Literal keys are read from
/// AppL10n directly.
String familyText(
  BuildContext context,
  String key, [
  Map<String, String> args = const {},
]) {
  final l = AppL10n.of(context);
  return switch (key) {
    'title' => l.famTitle,
    'children' => l.famChildren,
    'empty.title' => l.famEmptyTitle,
    'empty.message' => l.famEmptyMessage,
    'link' => l.famLink,
    'link.title' => l.famLinkTitle,
    'link.hint' => l.famLinkHint,
    'link.find' => l.famLinkFind,
    'link.notFound' => l.famLinkNotFound,
    'link.confirm' => l.famLinkConfirm(args['name'] ?? ''),
    'link.sent' => l.famLinkSent(args['name'] ?? ''),
    'status.pending' => l.famStatusPending,
    'status.verified' => l.famStatusVerified,
    'status.declined' => l.famStatusDeclined,
    'status.revoked' => l.famStatusRevoked,
    'view' => l.famView,
    'progress.title' => l.famProgressTitle(args['name'] ?? ''),
    'progress.average' => l.famProgressAverage,
    'progress.graded' => l.famProgressGraded(args['count'] ?? ''),
    'progress.attendance' => l.famProgressAttendance,
    'progress.sessions' => l.famProgressSessions(args['count'] ?? ''),
    'progress.none' => l.famProgressNone,
    'progress.breakdown' => l.famProgressBreakdown(
      args['present'] ?? '',
      args['late'] ?? '',
      args['absent'] ?? '',
      args['excused'] ?? '',
    ),
    'progress.source' => l.famProgressSource,
    'approvals.title' => l.famApprovalsTitle,
    'approvals.detail' => l.famApprovalsDetail(
      args['name'] ?? '',
      args['plan'] ?? '',
    ),
    'approvals.approve' => l.famApprovalsApprove,
    'approvals.decline' => l.famApprovalsDecline,
    'approvals.done' => l.famApprovalsDone,
    'retry' => l.famRetry,
    'cancel' => l.famCancel,
    'error.title' => l.famErrorTitle,
    'error.REAUTH_REQUIRED' => l.famErrorReauthRequired,
    'error.FORBIDDEN' => l.famErrorForbidden,
    'error.NOT_FOUND' => l.famErrorNotFound,
    'error.INVALID_STATE' => l.famErrorInvalidState,
    'error.RATE_LIMITED' => l.famErrorRateLimited,
    'error.NETWORK' => l.famErrorNetwork,
    'error.UNAUTHORIZED' => l.famErrorUnauthorized,
    'error.VALIDATION' => l.famErrorValidation,
    'error.UNKNOWN' => l.famErrorUnknown,
    _ => key,
  };
}

String familyFailureText(BuildContext context, Failure failure) {
  final key = 'error.${failure.code}';
  final value = familyText(context, key);
  return value == key ? AppL10n.of(context).famErrorUnknown : value;
}
