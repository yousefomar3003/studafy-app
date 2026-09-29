import 'package:flutter/material.dart';

import '../../../core/studafy_design.dart';
import '../../../core/studafy_domain.dart';
import '../../../core/user_content_text.dart';
import '../../../l10n/generated/app_l10n.dart';
import '../domain/device_account.dart';

/// What was picked in the account switcher.
sealed class AccountChoice {
  const AccountChoice();
}

class SwitchToAccount extends AccountChoice {
  const SwitchToAccount(this.account);
  final DeviceAccount account;
}

class AddAccount extends AccountChoice {
  const AddAccount();
}

class CreateChildAccount extends AccountChoice {
  const CreateChildAccount();
}

/// The accounts on this device, Instagram-style: tap one to switch to it.
///
/// A child account says whose sub-account it is, so a parent with several
/// children always knows which one they are about to open.
Future<AccountChoice?> showAccountSwitcher(
  BuildContext context, {
  required List<DeviceAccount> accounts,
  required String? currentUserId,
  required bool canCreateChild,
  required String Function(StudafyRole role) roleLabel,
}) => showModalBottomSheet<AccountChoice>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (sheetContext) {
    final l10n = AppL10n.of(sheetContext);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(sheetContext).height * .8,
        ),
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 8),
              child: Text(
                l10n.accountsSheetTitle,
                style: Theme.of(sheetContext).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            for (final account in accounts)
              AccountTile(
                account: account,
                current: account.userId == currentUserId,
                roleLabel: roleLabel,
                onTap: account.userId == currentUserId
                    ? () => Navigator.pop(sheetContext)
                    : () =>
                          Navigator.pop(sheetContext, SwitchToAccount(account)),
              ),
            const Divider(height: 24),
            ListTile(
              leading: const CircleAvatar(child: Icon(Icons.add_rounded)),
              title: Text(l10n.accountsAddAccount),
              onTap: () => Navigator.pop(sheetContext, const AddAccount()),
            ),
            if (canCreateChild)
              ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.child_care_rounded),
                ),
                title: Text(l10n.accountsCreateChild),
                subtitle: Text(l10n.accountsCreateChildDetail),
                onTap: () =>
                    Navigator.pop(sheetContext, const CreateChildAccount()),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  },
);

/// One account in the switcher.
class AccountTile extends StatelessWidget {
  const AccountTile({
    super.key,
    required this.account,
    required this.current,
    required this.roleLabel,
    this.onTap,
  });

  final DeviceAccount account;
  final bool current;
  final String Function(StudafyRole role) roleLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final initial = account.displayName.trim().isEmpty
        ? '?'
        : account.displayName.trim().characters.first.toUpperCase();
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: account.isManaged ? studafyCyan : studafyNavy,
        foregroundColor: Colors.white,
        child: Text(initial),
      ),
      title: UserContentText(
        account.displayName,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        account.isManaged
            ? l10n.accountsSubAccountOf(account.managedByName ?? '')
            : roleLabel(account.role),
      ),
      trailing: current
          ? Icon(
              Icons.check_circle_rounded,
              color: Theme.of(context).colorScheme.primary,
              semanticLabel: l10n.accountsCurrent,
            )
          : null,
      onTap: onTap,
    );
  }
}
