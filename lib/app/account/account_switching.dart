import 'package:flutter/material.dart';

import '../../core/app_routes.dart';
import '../../core/feedback.dart';
import '../../core/navigation.dart';
import '../../core/studafy_domain.dart';
import '../../features/accounts/domain/device_account.dart';
import '../../features/accounts/presentation/account_switcher_sheet.dart';
import '../../features/accounts/presentation/create_child_account_page.dart';
import '../../features/accounts/presentation/sub_account_banner.dart';
import '../../l10n/generated/app_l10n.dart';
import 'account_text.dart';
import 'device_account_switcher.dart';

/// Makes the device's accounts reachable from any screen.
class DeviceAccountsScope extends InheritedNotifier<DeviceAccountSwitcher> {
  const DeviceAccountsScope({
    super.key,
    required DeviceAccountSwitcher super.notifier,
    required super.child,
  });

  static DeviceAccountSwitcher? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<DeviceAccountsScope>()
      ?.notifier;
}

/// Puts the device's accounts in reach of every screen, and - while a parent
/// is in a child's account - a banner above every screen that says so, with
/// one tap back. Sits above the Navigator, like the synthetic banner, so no
/// pushed screen can hide it.
class DeviceAccountsFrame extends StatelessWidget {
  const DeviceAccountsFrame({
    super.key,
    required this.switcher,
    required this.onSwitch,
    required this.child,
  });

  final DeviceAccountSwitcher switcher;
  final VoidCallback onSwitch;

  /// The app's screens.
  final Widget child;

  @override
  Widget build(BuildContext context) => DeviceAccountsScope(
    notifier: switcher,
    child: Builder(
      builder: (context) {
        final current = DeviceAccountsScope.maybeOf(context)?.current;
        if (current == null || !current.isManaged) return child;
        return Column(
          children: [
            SubAccountBanner(
              parentName: current.managedByName,
              onSwitch: onSwitch,
            ),
            Expanded(
              child: MediaQuery.removePadding(
                context: context,
                removeTop: true,
                child: child,
              ),
            ),
          ],
        );
      },
    ),
  );
}

String _route(StudafyRole role) => switch (role) {
  StudafyRole.teacher || StudafyRole.schoolAdmin => teacherRoute,
  StudafyRole.parent => parentRoute,
  StudafyRole.student => studentRoute,
};

/// The Instagram-style account list: switch, add an account, or - for a
/// parent - create a child account.
Future<void> openAccountSwitcher(BuildContext context) async {
  final switcher = DeviceAccountsScope.maybeOf(context);
  if (switcher == null) return;
  await switcher.refreshManagedChildren();
  if (!context.mounted) return;
  final choice = await showAccountSwitcher(
    context,
    accounts: switcher.accounts,
    currentUserId: switcher.current?.userId ?? switcher.context.profile?.id,
    canCreateChild: switcher.canCreateChild,
    roleLabel: (role) => accountText(context, 'role.${role.name}'),
  );
  if (!context.mounted || choice == null) return;
  switch (choice) {
    case SwitchToAccount(:final account):
      await switchAccount(context, switcher, account);
    case AddAccount():
      switcher.beginAddingAccount();
      await Navigator.of(context, rootNavigator: true).pushNamed(rolesRoute);
      // Back from the sign-in screens without a new account: this one is
      // still signed in and still current.
      switcher.cancelAddingAccount();
    case CreateChildAccount():
      await openCreateChildAccount(context, switcher);
  }
}

/// A parent creates a student account for a child with no email or phone.
/// Reached from the account switcher and from "Link a child". The account
/// is the parent's to manage: nothing waits for the child to approve.
Future<void> openCreateChildAccount(
  BuildContext context,
  DeviceAccountSwitcher switcher,
) async {
  final locale = Localizations.localeOf(context).languageCode;
  await Navigator.of(context).pushOnce(
    MaterialPageRoute<void>(
      builder: (_) => CreateChildAccountPage(
        create: (name) => switcher.createChild(name, locale: locale),
        onSwitch: (child) {
          final account = switcher.accounts
              .where((a) => a.userId == child.childId)
              .firstOrNull;
          if (account != null && context.mounted) {
            switchAccount(context, switcher, account);
          }
        },
      ),
    ),
  );
}

/// Switches to [target] and opens its role's home. A switch takes a few
/// seconds and nothing else may happen meanwhile, so it holds the screen.
Future<void> switchAccount(
  BuildContext context,
  DeviceAccountSwitcher switcher,
  DeviceAccount target,
) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  final messenger = ScaffoldMessenger.of(context);
  final l10n = AppL10n.of(context);
  final locale = Localizations.localeOf(context).languageCode;
  final progress = showDialog<void>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (_) => PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 20),
            Expanded(child: Text(l10n.accountsSwitching)),
          ],
        ),
      ),
    ),
  );
  StudafyRole? role;
  AccountSwitchFailure? failure;
  try {
    role = await switcher.switchTo(target, locale: locale);
  } on AccountSwitchException catch (error) {
    failure = error.failure;
  } on Object {
    failure = AccountSwitchFailure.needsSignIn;
  }
  navigator.pop();
  await progress;
  if (role != null) {
    await navigator.pushNamedAndRemoveUntil(_route(role), (_) => false);
    return;
  }
  messenger.showMessage(switch (failure) {
    AccountSwitchFailure.needsParent => l10n.accountsNeedsParent,
    _ => l10n.accountsSwitchFailed,
  });
  // Nobody could be restored: the only way on is to sign in.
  if (switcher.context.profile == null) {
    await navigator.pushNamedAndRemoveUntil(rolesRoute, (_) => false);
  }
}

/// Signs the current account out of this device. Another account kept here
/// opens next - a child account goes back to its parent - and with none the
/// person lands on the role screen as before.
Future<void> signOutOfDevice(
  BuildContext context,
  DeviceAccountSwitcher switcher,
) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  DeviceAccount? next;
  try {
    next = await switcher.signOutCurrent();
  } on Object {
    // This device is cleared regardless; see SessionInteractor.signOut.
  }
  if (next != null && context.mounted) {
    await switchAccount(context, switcher, next);
    if (switcher.context.profile != null) return;
  }
  await navigator.pushNamedAndRemoveUntil(rolesRoute, (_) => false);
}
