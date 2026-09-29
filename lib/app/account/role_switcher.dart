import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/studafy_domain.dart';
import 'account_text.dart';

/// Roles this account holds at the active school, other than the current one.
///
/// Empty for the ordinary case of someone with a single role, so the switcher
/// is offered only where there is something to switch to.
List<StudafyRole> switchableRoles(ActiveContextController context_) {
  final current = context_.membership?.role;
  final school = context_.membership?.schoolId;
  final seen = <StudafyRole>{};
  return [
    for (final membership
        in context_.profile?.memberships ?? const <SchoolMembership>[])
      if (membership.active &&
          membership.role != StudafyRole.schoolAdmin &&
          membership.schoolId == school &&
          membership.role != current &&
          seen.add(membership.role))
        membership.role,
  ];
}

Future<void> showRoleSwitcher(
  BuildContext context,
  ActiveContextController context_,
) async {
  String t(String key) => accountText(context, key);
  final chosen = await showModalBottomSheet<StudafyRole>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final role in switchableRoles(context_))
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text(t('role.${role.name}')),
              onTap: () => Navigator.pop(sheetContext, role),
            ),
        ],
      ),
    ),
  );
  if (chosen == null) return;
  // switchRole refuses a role the account does not actually hold, so the
  // shell is only sent onward once the context really changed.
  context_.switchRole(chosen);
  if (!context.mounted) return;
  final route = switch (context_.membership?.role) {
    StudafyRole.schoolAdmin => null,
    StudafyRole.teacher => '/teacher',
    StudafyRole.parent => '/parent',
    StudafyRole.student => '/student',
    _ => null,
  };
  if (route != null) {
    Navigator.of(context).pushNamedAndRemoveUntil(route, (_) => false);
  }
}
