import 'package:flutter/material.dart';

import '../../l10n/generated/app_l10n.dart';

/// A table key looked up at runtime (an error code, a role, a status),
/// resolved against the app's translations. Literal keys are read from
/// AppL10n directly.
String accountText(BuildContext context, String key) {
  final l = AppL10n.of(context);
  return switch (key) {
    'accountId' => l.accountAccountId,
    'accountId.detail' => l.accountAccountIdDetail,
    'accountId.copied' => l.accountAccountIdCopied,
    'switchRole' => l.accountSwitchRole,
    'switchRole.detail' => l.accountSwitchRoleDetail,
    'title' => l.accountTitle,
    'section.account' => l.accountSectionAccount,
    'section.preferences' => l.accountSectionPreferences,
    'section.privacy' => l.accountSectionPrivacy,
    'studafyId' => l.accountStudafyId,
    'studafyId.detail' => l.accountStudafyIdDetail,
    'studafyId.copy' => l.accountStudafyIdCopy,
    'studafyId.copied' => l.accountStudafyIdCopied,
    'unknown' => l.accountUnknown,
    'language' => l.accountLanguage,
    'security' => l.accountSecurity,
    'security.detail' => l.accountSecurityDetail,
    'signOut' => l.accountSignOut,
    'delete' => l.accountDelete,
    'role.schoolAdmin' => l.accountRoleSchoolAdmin,
    'role.teacher' => l.accountRoleTeacher,
    'role.parent' => l.accountRoleParent,
    'role.student' => l.accountRoleStudent,
    'export' => l.accountExport,
    'export.detail' => l.accountExportDetail,
    'export.request' => l.accountExportRequest,
    'export.pending' => l.accountExportPending,
    'export.check' => l.accountExportCheck,
    'export.ready' => l.accountExportReady,
    'export.download' => l.accountExportDownload,
    'export.requested' => l.accountExportRequested,
    'export.reauth' => l.accountExportReauth,
    'export.expired' => l.accountExportExpired,
    'export.failed' => l.accountExportFailed,
    _ => key,
  };
}
