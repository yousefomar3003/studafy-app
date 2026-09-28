import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/feedback.dart';
import '../core/language_picker.dart';
import '../core/studafy_design.dart';
import '../core/studafy_domain.dart';
import '../features/account/presentation/delete_account_page.dart';
import '../features/session/presentation/account_security_page.dart';
import '../l10n/generated/app_l10n.dart';
import 'account/account_text.dart';
import 'account/account_widgets.dart';
import 'account/data_export_tile.dart';
import 'account/role_switcher.dart';
import 'account_scope.dart';
import 'session_scope.dart';

/// Opens the shared account screen. Every role shell shows it, because
/// sign-out and in-app account deletion must be reachable for everyone
/// (Apple guideline 5.1.1(v), Google Play account deletion policy).
class AccountButton extends StatelessWidget {
  const AccountButton({super.key});

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: AppL10n.of(context).accountTitle,
    icon: const Icon(Icons.account_circle_outlined),
    onPressed: () => Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => const AccountHubPage()),
    ),
  );
}

/// One account screen for teachers, guardians and students, built from the
/// authenticated profile. No sample names or addresses.
class AccountHubPage extends StatelessWidget {
  const AccountHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    String t(String key) => accountText(context, key);
    final context_ = ActiveContextController.instance;
    final profile = context_.profile;
    final membership = context_.membership;
    final session = SessionScope.maybeOf(context);
    return Scaffold(
      backgroundColor: studafyCanvas,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(AppL10n.of(context).accountTitle),
      ),
      body: ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(20, 20, 20, 32),
        children: [
          AccountProfileHeader(
            name: profile?.displayName ?? AppL10n.of(context).accountUnknown,
            email: profile?.email ?? '',
            membership: membership,
            roleLabel: membership == null
                ? null
                : t('role.${membership.role.name}'),
          ),
          // A student has to hand this to a parent before a link request can
          // be made, and there was nowhere in the app to read it.
          if (membership?.role == StudafyRole.student) ...[
            const SizedBox(height: 12),
            const StudafyIdCard(),
          ],
          const SizedBox(height: 24),
          AccountSectionLabel(AppL10n.of(context).accountSectionAccount),
          Card(
            child: Column(
              children: [
                if (profile != null)
                  ListTile(
                    leading: const Icon(Icons.badge_outlined),
                    title: Text(AppL10n.of(context).accountAccountId),
                    subtitle: Text(
                      '${profile.id}\n${AppL10n.of(context).accountAccountIdDetail}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    isThreeLine: true,
                    trailing: const Icon(Icons.copy_rounded),
                    onTap: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final copied = AppL10n.of(context).accountAccountIdCopied;
                      await Clipboard.setData(ClipboardData(text: profile.id));
                      messenger.showMessage(copied);
                    },
                  ),
                // A teacher is often a parent at the same school. The domain
                // has always supported holding both; this is the way to use
                // the other one without signing out and back in.
                if (switchableRoles(context_).isNotEmpty)
                  ListTile(
                    leading: const Icon(Icons.swap_horiz_rounded),
                    title: Text(AppL10n.of(context).accountSwitchRole),
                    subtitle: Text(AppL10n.of(context).accountSwitchRoleDetail),
                    trailing: Icon(forwardChevron(context)),
                    onTap: () => showRoleSwitcher(context, context_),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          AccountSectionLabel(AppL10n.of(context).accountSectionPreferences),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.language_rounded),
                  title: Text(AppL10n.of(context).accountLanguage),
                  trailing: Icon(forwardChevron(context)),
                  onTap: () => showStudafyLanguagePicker(context),
                ),
                if (session != null)
                  ListTile(
                    leading: const Icon(Icons.shield_outlined),
                    title: Text(AppL10n.of(context).accountSecurity),
                    subtitle: Text(AppL10n.of(context).accountSecurityDetail),
                    trailing: Icon(forwardChevron(context)),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => AccountSecurityPage(session: session),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          AccountSectionLabel(AppL10n.of(context).accountSectionPrivacy),
          Card(
            child: Column(
              children: [DataExportTile(account: AccountScope.of(context))],
            ),
          ),
          const SizedBox(height: 28),
          if (session != null)
            OutlinedButton(
              onPressed: () async {
                // Leaving is not allowed to fail. The interactor clears this
                // device in a finally, so the only thing left to guarantee is
                // that the person actually lands back on the role screen.
                try {
                  await session.signOut();
                } catch (_) {
                  // Swallowed on purpose. This device is already cleared by
                  // the interactor's finally, so there is nothing left to
                  // tell the person and nothing they could do about it.
                }
                if (context.mounted) {
                  Navigator.of(context)
                      .pushNamedAndRemoveUntil('/roles', (_) => false);
                }
              },
              child: Text(AppL10n.of(context).accountSignOut),
            ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => DeleteAccountPage(
                  email: accountEmail(context),
                  account: AccountScope.of(context),
                ),
              ),
            ),
            child: Text(
              AppL10n.of(context).accountDelete,
              style: const TextStyle(color: Color(0xFFB3261E)),
            ),
          ),
        ],
      ),
    );
  }
}
