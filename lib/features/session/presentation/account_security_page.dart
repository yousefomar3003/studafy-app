import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/feedback.dart';
import '../../../core/studafy_components.dart';
import '../../../core/studafy_design.dart';
import '../../../l10n/generated/app_l10n.dart';
import '../application/session_interactor.dart';
import '../domain/session_repository.dart';

/// Account security: second factor, active devices, and sign out everywhere
/// (AUTH-030).
///
/// Reachable by every role. Two-factor is optional for everyone except a
/// platform operator, who needs it to open a safety report (DL-063).
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
    final TotpEnrolment enrolment;
    try {
      enrolment = await widget.session.beginTotpEnrolment();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showMessage(AppL10n.of(context).securitySetupFailed);
      return;
    }
    if (!mounted) return;
    final verified = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _TotpEnrolmentDialog(
        enrolment: enrolment,
        verify: (code) => widget.session.verifyTotp(enrolment.factorId, code),
      ),
    );
    if (verified == true && mounted) await _load();
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
  const _TotpEnrolmentDialog({required this.enrolment, required this.verify});
  final TotpEnrolment enrolment;

  /// True when the code verified the factor, false when it was wrong.
  final Future<bool> Function(String code) verify;

  @override
  State<_TotpEnrolmentDialog> createState() => _TotpEnrolmentDialogState();
}

class _TotpEnrolmentDialogState extends State<_TotpEnrolmentDialog> {
  final controller = TextEditingController();
  bool verifying = false;
  String? error;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  /// The key in groups of four, which is how authenticator apps show it and
  /// easier to check by eye.
  String get _groupedSecret => widget.enrolment.secret
      .replaceAllMapped(RegExp('.{1,4}'), (m) => '${m[0]} ')
      .trim();

  Future<void> _openInApp() async {
    final l10n = AppL10n.of(context);
    var opened = false;
    try {
      opened = await launchUrl(
        Uri.parse(widget.enrolment.uri),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      opened = false;
    }
    if (!opened && mounted) setState(() => error = l10n.securityTotpNoApp);
  }

  Future<void> _copyKey() async {
    final l10n = AppL10n.of(context);
    await Clipboard.setData(ClipboardData(text: widget.enrolment.secret));
    if (mounted) {
      ScaffoldMessenger.of(context).showMessage(l10n.securityTotpKeyCopied);
    }
  }

  Future<void> _verify() async {
    final l10n = AppL10n.of(context);
    setState(() {
      verifying = true;
      error = null;
    });
    try {
      final verified = await widget.verify(controller.text.trim());
      if (!mounted) return;
      if (verified) {
        Navigator.pop(context, true);
        return;
      }
      setState(() {
        verifying = false;
        error = l10n.securityCodeMismatch;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        verifying = false;
        error = l10n.securitySetupFailed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return AlertDialog(
      title: Text(l10n.securityTotpTitle),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.securityTotpBody),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _openInApp,
            icon: const Icon(Icons.open_in_new_rounded),
            label: Text(l10n.securityTotpOpenApp),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.securityTotpKeyLabel,
            style: const TextStyle(fontSize: 12, color: studafyMuted),
          ),
          const SizedBox(height: 4),
          // The key reads left to right in every language.
          Directionality(
            textDirection: TextDirection.ltr,
            child: SelectableText(
              _groupedSecret,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 15,
                letterSpacing: 1,
              ),
            ),
          ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: _copyKey,
              icon: const Icon(Icons.copy_rounded, size: 18),
              label: Text(l10n.securityTotpCopyKey),
            ),
          ),
          const SizedBox(height: 8),
          Text(l10n.securityTotpCodePrompt),
          const SizedBox(height: 4),
          TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            autocorrect: false,
            enableSuggestions: false,
            autofillHints: const [AutofillHints.oneTimeCode],
            maxLength: 6,
            decoration: InputDecoration(
              hintText: '123456',
              counterText: '',
              errorText: error,
              errorMaxLines: 3,
            ),
            onChanged: (_) => setState(() => error = null),
            onSubmitted: (_) {
              if (controller.text.trim().length == 6 && !verifying) _verify();
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: verifying ? null : () => Navigator.pop(context, false),
          child: Text(l10n.securityCancel),
        ),
        FilledButton(
          onPressed: verifying || controller.text.trim().length < 6
              ? null
              : _verify,
          child: Text(l10n.securityVerify),
        ),
      ],
    );
  }
}
