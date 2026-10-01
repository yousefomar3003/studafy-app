import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/app_routes.dart';
import '../../core/studafy_domain.dart';
import '../../features/session/presentation/role_page.dart';
import '../../l10n/generated/app_l10n.dart';
import 'account_text.dart';

/// The roles this account can move to, other than the one it is in now.
///
/// One kind of account per email: a student account is a student only, so it
/// has nothing to switch to. An adult's account may be a teacher and a
/// parent, whichever school the teaching is at, so it is offered the other
/// of the two - teaching even before a workspace exists, which then starts
/// teacher setup.
List<StudafyRole> switchableRoles(ActiveContextController context_) {
  final profile = context_.profile;
  if (profile == null) return const [];
  final current = context_.signedInAs ?? context_.membership?.role;
  final kind = profile.effectiveKind;
  final adult =
      kind == AccountKind.adult ||
      (kind == null && current != null && current != StudafyRole.student);
  if (!adult) return const [];
  return [
    if (current != StudafyRole.teacher) StudafyRole.teacher,
    if (current != StudafyRole.parent) StudafyRole.parent,
  ];
}

Future<void> showRoleSwitcher(
  BuildContext context,
  ActiveContextController context_,
) async {
  String t(String key) => accountText(context, key);
  final l10n = AppL10n.of(context);
  final chosen = await showModalBottomSheet<StudafyRole>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final role in switchableRoles(context_))
            ListTile(
              leading: Icon(
                role == StudafyRole.parent
                    ? Icons.family_restroom_rounded
                    : Icons.school_rounded,
              ),
              title: Text(t('role.${role.name}')),
              subtitle: Text(
                role == StudafyRole.teacher &&
                        !context_.canSwitchTo(StudafyRole.teacher)
                    ? l10n.onboardingTeacherReadyTitle
                    : role == StudafyRole.parent
                    ? l10n.roleParentDetail
                    : l10n.roleTeacherDetail,
              ),
              onTap: () => Navigator.pop(sheetContext, role),
            ),
        ],
      ),
    ),
  );
  if (chosen == null || !context.mounted) return;
  final navigator = Navigator.of(context);
  switch (chosen) {
    case StudafyRole.parent:
      // A parent acts through their children, not a school membership.
      final profile = context_.profile;
      if (profile == null) return;
      context_.hydrate(
        authenticatedProfile: profile,
        signedInAs: StudafyRole.parent,
      );
      unawaited(navigator.pushNamedAndRemoveUntil(parentRoute, (_) => false));
    case StudafyRole.teacher when context_.canSwitchTo(StudafyRole.teacher):
      context_.switchRole(StudafyRole.teacher);
      unawaited(navigator.pushNamedAndRemoveUntil(teacherRoute, (_) => false));
    case StudafyRole.teacher:
      // No workspace yet: teacher setup makes one, then opens it.
      unawaited(
        navigator.pushNamedAndRemoveUntil(
          onboardingRoute,
          (_) => false,
          arguments: UserRole.teacher,
        ),
      );
    case StudafyRole.student || StudafyRole.schoolAdmin:
      return;
  }
}
