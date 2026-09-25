import 'package:flutter/material.dart';

import '../../../core/studafy_design.dart';
import '../../../core/user_content_text.dart';
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
  const AccountSecurityPage({super.key, required this.session});

  final SessionInteractor session;

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppL10n.of(context).securityCodeMismatch)),
        );
        return;
      }
      await _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppL10n.of(context).securitySetupFailed)),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppL10n.of(context).securityRevokeFailed)),
      );
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
      messenger.showSnackBar(SnackBar(content: Text(failedText)));
    }
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return Scaffold(
      backgroundColor: studafyCanvas,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(l10n.securityTitle),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (error != null) ...[
                  Text(
                    error!,
                    style: const TextStyle(color: Color(0xFFB42318)),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _load,
                    child: Text(l10n.securityTryAgain),
                  ),
                  const SizedBox(height: 20),
                ],
                _SectionLabel(l10n.securityTwoFactorHeading),
                const SizedBox(height: 8),
                FeatureCard(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      mfaEnrolled ? Icons.verified_user : Icons.shield_outlined,
                      color: mfaEnrolled ? studafyNavy : studafyMuted,
                    ),
                    title: Text(
                      mfaEnrolled
                          ? l10n.securityTwoFactorOn
                          : l10n.securityTwoFactorOff,
                    ),
                    subtitle: Text(
                      mfaEnrolled
                          ? l10n.securityTwoFactorOnDetail
                          : l10n.securityTwoFactorOffDetail,
                    ),
                    trailing: mfaEnrolled
                        ? null
                        : FilledButton(
                            onPressed: _enrolTotp,
                            child: Text(l10n.securitySetUp),
                          ),
                  ),
                ),
                const SizedBox(height: 22),
                _SectionLabel(l10n.securityDevicesHeading),
                const SizedBox(height: 8),
                if (devices.isEmpty)
                  FeatureCard(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(l10n.securityNoOtherDevices),
                      subtitle: Text(l10n.securityOnlyThisDevice),
                    ),
                  )
                else
                  for (final device in devices)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(bottom: 10),
                      child: FeatureCard(
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            device.platform == 'ios'
                                ? Icons.phone_iphone
                                : Icons.phone_android,
                            color: device.revoked ? studafyMuted : studafyNavy,
                          ),
                          // The device name is whatever the owner called their
                          // phone, so it renders verbatim in its own direction.
                          title: UserContentText(
                            device.isCurrent
                                ? '${device.label ?? device.platform} · '
                                      '${l10n.securityThisDevice}'
                                : device.label ?? device.platform,
                          ),
                          subtitle: Text(
                            device.revoked
                                ? l10n.securityDeviceSignedOut
                                : l10n.securityLastUsed(
                                    _relative(context, device.lastSeenAt),
                                  ),
                          ),
                          trailing: device.revoked
                              ? null
                              : TextButton(
                                  onPressed: () => _revokeDevice(device),
                                  child: Text(l10n.securitySignOut),
                                ),
                        ),
                      ),
                    ),
                const SizedBox(height: 22),
                OutlinedButton.icon(
                  onPressed: _signOutEverywhere,
                  icon: const Icon(Icons.logout, color: Color(0xFFB42318)),
                  label: Text(
                    l10n.securitySignOutEverywhere,
                    style: const TextStyle(color: Color(0xFFB42318)),
                  ),
                ),
                const SizedBox(height: 28),
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

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      color: studafyMuted,
      fontWeight: FontWeight.w700,
      letterSpacing: .5,
    ),
  );
}
