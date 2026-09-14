import 'package:flutter/material.dart';

import '../../../core/studafy_design.dart';
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
        error = 'Could not load your security settings. Try again.';
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
          const SnackBar(content: Text('That code did not match.')),
        );
        return;
      }
      await _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not set up two-factor sign-in.')),
      );
    }
  }

  Future<void> _revokeDevice(AuthDevice device) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out this device?'),
        content: Text(
          '${device.label ?? device.platform} will need to sign in again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep it'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign it out'),
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
        const SnackBar(content: Text('Could not sign that device out.')),
      );
    }
  }

  Future<void> _signOutEverywhere() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out everywhere?'),
        content: const Text(
          'Every device signed in to this account will be signed out, '
          'including this one. Sessions stop working immediately.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB42318),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign out everywhere'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await widget.session.signOut(scope: SignOutScope.allDevices);
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: studafyCanvas,
    appBar: AppBar(
      backgroundColor: Colors.white,
      title: const Text('Account security'),
    ),
    body: loading
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (error != null) ...[
                Text(error!, style: const TextStyle(color: Color(0xFFB42318))),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _load,
                  child: const Text('Try again'),
                ),
                const SizedBox(height: 20),
              ],
              const _SectionLabel('TWO-FACTOR SIGN-IN'),
              const SizedBox(height: 8),
              FeatureCard(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    mfaEnrolled ? Icons.verified_user : Icons.shield_outlined,
                    color: mfaEnrolled ? studafyNavy : studafyMuted,
                  ),
                  title: Text(mfaEnrolled ? 'Turned on' : 'Not set up'),
                  subtitle: Text(
                    mfaEnrolled
                        ? 'You use an authenticator app when signing in.'
                        : 'School administrators must turn this on before '
                              'they can manage a school.',
                  ),
                  trailing: mfaEnrolled
                      ? null
                      : FilledButton(
                          onPressed: _enrolTotp,
                          child: const Text('Set up'),
                        ),
                ),
              ),
              const SizedBox(height: 22),
              const _SectionLabel('WHERE YOU ARE SIGNED IN'),
              const SizedBox(height: 8),
              if (devices.isEmpty)
                const FeatureCard(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('No other devices'),
                    subtitle: Text('Only this device is signed in.'),
                  ),
                )
              else
                for (final device in devices)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: FeatureCard(
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          device.platform == 'ios'
                              ? Icons.phone_iphone
                              : Icons.phone_android,
                          color: device.revoked ? studafyMuted : studafyNavy,
                        ),
                        title: Text(
                          '${device.label ?? device.platform}'
                          '${device.isCurrent ? ' · this device' : ''}',
                        ),
                        subtitle: Text(
                          device.revoked
                              ? 'Signed out'
                              : 'Last used ${_relative(device.lastSeenAt)}',
                        ),
                        trailing: device.revoked
                            ? null
                            : TextButton(
                                onPressed: () => _revokeDevice(device),
                                child: const Text('Sign out'),
                              ),
                      ),
                    ),
                  ),
              const SizedBox(height: 22),
              OutlinedButton.icon(
                onPressed: _signOutEverywhere,
                icon: const Icon(Icons.logout, color: Color(0xFFB42318)),
                label: const Text(
                  'Sign out everywhere',
                  style: TextStyle(color: Color(0xFFB42318)),
                ),
              ),
              const SizedBox(height: 28),
            ],
          ),
  );

  static String _relative(DateTime when) {
    final difference = DateTime.now().difference(when);
    if (difference.inMinutes < 1) return 'just now';
    if (difference.inHours < 1) return '${difference.inMinutes} minutes ago';
    if (difference.inDays < 1) return '${difference.inHours} hours ago';
    return '${difference.inDays} days ago';
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
    title: const Text('Set up two-factor sign-in'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Add this key to your authenticator app, then enter the six-digit '
          'code it shows.',
        ),
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
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: controller.text.trim().length < 6
            ? null
            : () => Navigator.pop(context, controller.text.trim()),
        child: const Text('Verify'),
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
