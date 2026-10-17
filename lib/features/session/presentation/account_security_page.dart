import 'package:flutter/material.dart';

import '../../../core/feedback.dart';
import '../../../core/studafy_components.dart';
import '../../../core/studafy_design.dart';
import '../../../l10n/generated/app_l10n.dart';
import '../application/session_interactor.dart';
import '../domain/session_repository.dart';

/// Account security: second factor, active devices, and sign out everywhere
/// (AUTH-030).
///
/// Reachable by every role. School administrators are *required* to hold a
/// second factor — the API refuses their privileged actions at aal1 — but the
/// screen is not admin-only, because a teacher or guardian who wants one
/// should not have to ask for it.
class AccountSecurityPage extends StatefulWidget {
  const AccountSecurityPage({
    super.key,
    required this.session,
    this.onDeleteAccount,
    this.reviewsReports = false,
  });

  final SessionInteractor session;

  /// True for a platform operator (GET /v1/me), who needs two-factor to
  /// open a safety report; everyone else is told only that it is optional.
  final bool reviewsReports;

  /// Opens the account deletion flow, which the app layer composes (it
  /// belongs to the account feature). Null hides the section.
  final void Function(BuildContext context)? onDeleteAccount;

  @override
  State<AccountSecurityPage> createState() => _AccountSecurityPageState();
}

class _AccountSecurityPageState extends State<AccountSecurityPage> {
  bool loading = true;
  String? error;
  bool mfaEnrolled = false;
  List<AuthDevice> devices = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final enrolled = await widget.session.mfaEnrolled();
      final list = await widget.session.devices();
      if (!mounted) return;
      setState(() {
        mfaEnrolled = enrolled;
        devices = list;
        loading = false;
      });
    } catch (failure) {
      if (!mounted) return;
      setState(() {
        error = AppL10n.of(context).securityLoadFailed;
        loading = false;
      });
    }
  }

  Future<void> _enrolTotp() async {
    try {
      final uri = await widget.session.beginTotpEnrolment();
      if (!mounted) return;
      final code = await showDialog<String>(
        context: context,
        builder: (context) => _TotpEnrolmentDialog(provisioningUri: uri),
      );
      if (code == null || !mounted) return;
      final verified = await widget.session.verifyTotp(code);
      if (!mounted) return;
      if (!verified) {
        ScaffoldMessenger.of(context)
            .showMessage(AppL10n.of(context).securityCodeMismatch);
        return;
      }
      await _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showMessage(AppL10n.of(context).securitySetupFailed);
    }
  }

  Future<void> _revokeDevice(AuthDevice device) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppL10n.of(context).securitySignOutDeviceTitle),
        content: Text(
          AppL10n.of(context)
              .securitySignOutDeviceBody(device.label ?? device.platform),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppL10n.of(context).securityKeepIt),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppL10n.of(context).securitySignItOut),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await widget.session.revokeDevice(device.id);
      await _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showMessage(AppL10n.of(context).securityRevokeFailed);
    }
  }

  Future<void> _signOutEverywhere() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppL10n.of(context).securitySignOutEverywhereTitle),
        content: Text(AppL10n.of(context).securitySignOutEverywhereBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppL10n.of(context).securityCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB42318),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppL10n.of(context).securitySignOutEverywhere),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final failedText = AppL10n.of(context).securitySignOutEverywhereFailed;
    // This device is cleared either way. Only the other devices are in doubt,
    // and saying so is better than a button that looks like it did nothing.
    var reachedServer = true;
    try {
      await widget.session.signOut(scope: SignOutScope.allDevices);
    } catch (_) {
      reachedServer = false;
    }
    if (!reachedServer) {
      messenger.showMessage(failedText);
    }
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  /// Says plainly what deleting does before the deletion screen, which
  /// then asks for its own typed confirmation.
  Future<void> _confirmDelete() async {
    final open = widget.onDeleteAccount;
    if (open == null) return;
    final l10n = AppL10n.of(context);
    final go = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded, color: studafyDanger),
        title: Text(l10n.securityDeleteTitle),
        content: Text(l10n.securityDeleteExplain),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(
              MaterialLocalizations.of(dialogContext).cancelButtonLabel,
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: studafyDanger),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.securityDeleteContinue),
          ),
        ],
      ),
    );
    if (go == true && mounted) open(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.securityTitle)),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 40),
              children: [
                if (error != null)
                  StudafyEmptyState(
                    icon: Icons.wifi_off_rounded,
                    title: error!,
                    actionLabel: l10n.securityTryAgain,
                    onAction: _load,
                  ),
                SettingsGroup(
                  title: l10n.securityTwoFactorHeading,
                  children: [
                    SettingsRow(
                      icon: mfaEnrolled
                          ? Icons.verified_user_rounded
                          : Icons.shield_outlined,
                      title: mfaEnrolled
                          ? l10n.securityTwoFactorOn
                          : l10n.securityTwoFactorOff,
                      subtitle: mfaEnrolled
                          ? l10n.securityTwoFactorOnDetail
                          : widget.reviewsReports
                          ? l10n.securityTwoFactorOffDetailReviewer
                          : l10n.securityTwoFactorOffDetail,
                      trailing: mfaEnrolled
                          ? const Icon(
                              Icons.check_circle_rounded,
                              color: studafyNavy,
                            )
                          : FilledButton(
                              onPressed: _enrolTotp,
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(0, 40),
                              ),
                              child: Text(l10n.securitySetUp),
                            ),
                    ),
                  ],
                ),
                SettingsGroup(
                  title: l10n.securityDevicesHeading,
                  children: [
                    if (devices.isEmpty)
                      SettingsRow(
                        icon: Icons.devices_rounded,
                        title: l10n.securityNoOtherDevices,
                        subtitle: l10n.securityOnlyThisDevice,
                      )
                    else
                      for (final device in devices)
                        SettingsRow(
                          icon: device.platform == 'ios'
                              ? Icons.phone_iphone_rounded
                              : Icons.phone_android_rounded,
                          // The device name is whatever the owner called
                          // their phone; it is shown as written.
                          title: device.isCurrent
                              ? '${device.label ?? device.platform} · '
                                    '${l10n.securityThisDevice}'
                              : device.label ?? device.platform,
                          subtitle: device.revoked
                              ? l10n.securityDeviceSignedOut
                              : l10n.securityLastUsed(
                                  _relative(context, device.lastSeenAt),
                                ),
                          trailing: device.revoked
                              ? null
                              : TextButton(
                                  onPressed: () => _revokeDevice(device),
                                  child: Text(l10n.securitySignOut),
                                ),
                        ),
                    SettingsRow(
                      icon: Icons.logout_rounded,
                      title: l10n.securitySignOutEverywhere,
                      destructive: true,
                      showChevron: false,
                      onTap: _signOutEverywhere,
                    ),
                  ],
                ),
                if (widget.onDeleteAccount != null)
                  SettingsGroup(
                    title: l10n.securityDeleteHeading,
                    footer: l10n.securityDeleteFooter,
                    children: [
                      SettingsRow(
                        icon: Icons.delete_forever_rounded,
                        title: l10n.accountDelete,
                        destructive: true,
                        onTap: _confirmDelete,
                      ),
                    ],
                  ),
              ],
            ),
    );
  }

  /// Arabic has six plural categories, so "3 minutes ago" and "11 minutes
  /// ago" take different forms. The generated plural lookups pick the right
  /// one; the old string interpolation could not, and also read
  /// "1 minutes ago" in English.
  static String _relative(BuildContext context, DateTime when) {
    final l10n = AppL10n.of(context);
    final difference = DateTime.now().difference(when);
    if (difference.inMinutes < 1) return l10n.securityJustNow;
    if (difference.inHours < 1) {
      return l10n.securityMinutesAgo(difference.inMinutes);
    }
    if (difference.inDays < 1) return l10n.securityHoursAgo(difference.inHours);
    return l10n.securityDaysAgo(difference.inDays);
  }
}

class _TotpEnrolmentDialog extends StatefulWidget {
  const _TotpEnrolmentDialog({required this.provisioningUri});
  final String provisioningUri;

  @override
  State<_TotpEnrolmentDialog> createState() => _TotpEnrolmentDialogState();
}

class _TotpEnrolmentDialogState extends State<_TotpEnrolmentDialog> {
  final controller = TextEditingController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(AppL10n.of(context).securityTotpTitle),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(AppL10n.of(context).securityTotpBody),
        const SizedBox(height: 12),
        SelectableText(
          widget.provisioningUri,
          style: const TextStyle(fontSize: 12, color: studafyMuted),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autocorrect: false,
          enableSuggestions: false,
          decoration: const InputDecoration(hintText: '123456'),
          onChanged: (_) => setState(() {}),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(AppL10n.of(context).securityCancel),
      ),
      FilledButton(
        onPressed: controller.text.trim().length < 6
            ? null
            : () => Navigator.pop(context, controller.text.trim()),
        child: Text(AppL10n.of(context).securityVerify),
      ),
    ],
  );
}
