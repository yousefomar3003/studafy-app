import 'package:flutter/widgets.dart';

import '../../../core/failures.dart';
import '../../../l10n/generated/app_l10n.dart';

/// A table key looked up at runtime (an error code, a role, a status),
/// resolved against the app's translations. Literal keys are read from
/// AppL10n directly.
String messagingText(
  BuildContext context,
  String key, [
  Map<String, String> args = const {},
]) {
  final l = AppL10n.of(context);
  return switch (key) {
    'title' => l.msgTitle,
    'empty.title' => l.msgEmptyTitle,
    'empty.message' => l.msgEmptyMessage,
    'empty.awaitingLink' => l.msgEmptyAwaitingLink,
    'new' => l.msgNew,
    'noSchool' => l.msgNoSchool,
    'retry' => l.msgRetry,
    'error.title' => l.msgErrorTitle,
    'compose.hint' => l.msgComposeHint,
    'send' => l.msgSend,
    'sendFailed' => l.msgSendFailed,
    'loadOlder' => l.msgLoadOlder,
    'you' => l.msgYou,
    'unknownPerson' => l.msgUnknownPerson,
    'menu.reportConversation' => l.msgMenuReportConversation,
    'menu.reportPerson' => l.msgMenuReportPerson(args['name'] ?? ''),
    'menu.blockPerson' => l.msgMenuBlockPerson(args['name'] ?? ''),
    'menu.blocked' => l.msgMenuBlocked,
    'message.report' => l.msgMessageReport,
    'report.title' => l.msgReportTitle,
    'report.intro' => l.msgReportIntro,
    'report.reason' => l.msgReportReason,
    'reason.harassment' => l.msgReasonHarassment,
    'reason.inappropriate' => l.msgReasonInappropriate,
    'reason.safety' => l.msgReasonSafety,
    'reason.spam' => l.msgReasonSpam,
    'reason.other' => l.msgReasonOther,
    'report.details' => l.msgReportDetails,
    'report.consent' => l.msgReportConsent,
    'report.alsoBlock' => l.msgReportAlsoBlock,
    'report.submit' => l.msgReportSubmit,
    'report.sent' => l.msgReportSent,
    'report.urgent' => l.msgReportUrgent,
    'block.title' => l.msgBlockTitle(args['name'] ?? ''),
    'block.message' => l.msgBlockMessage,
    'block.confirm' => l.msgBlockConfirm,
    'block.done' => l.msgBlockDone(args['name'] ?? ''),
    'cancel' => l.msgCancel,
    'blocked.title' => l.msgBlockedTitle,
    'blocked.empty' => l.msgBlockedEmpty,
    'unblock' => l.msgUnblock,
    'unblock.done' => l.msgUnblockDone,
    'blocked.banner' => l.msgBlockedBanner,
    'new.title' => l.msgNewTitle,
    'new.empty' => l.msgNewEmpty,
    'new.search' => l.msgNewSearch,
    'subject.hint' => l.msgSubjectHint,
    'start' => l.msgStart,
    'role.staff' => l.msgRoleStaff,
    'role.student' => l.msgRoleStudent,
    'role.guardian' => l.msgRoleGuardian,
    'guardianOf' => l.msgGuardianOf(args['names'] ?? ''),
    'error.MESSAGING_DISABLED' => l.msgErrorMessagingDisabled,
    'error.CONTACT_NOT_ALLOWED' => l.msgErrorContactNotAllowed,
    'error.FORBIDDEN' => l.msgErrorForbidden,
    'error.NOT_FOUND' => l.msgErrorNotFound,
    'error.INVALID_STATE' => l.msgErrorInvalidState,
    'error.WINDOW_CLOSED' => l.msgErrorWindowClosed,
    'error.RATE_LIMITED' => l.msgErrorRateLimited,
    'error.NETWORK' => l.msgErrorNetwork,
    'error.UNAUTHORIZED' => l.msgErrorUnauthorized,
    'error.VALIDATION' => l.msgErrorValidation,
    'error.UNKNOWN' => l.msgErrorUnknown,
    'error.ATTACHMENT_REFUSED' => l.msgErrorAttachmentRefused,
    _ => key,
  };
}

/// A failure explained in the reader's language. Server text never shows.
String messagingFailureText(BuildContext context, Failure failure) {
  final key = 'error.${failure.code}';
  final value = messagingText(context, key);
  return value == key ? AppL10n.of(context).msgErrorUnknown : value;
}
