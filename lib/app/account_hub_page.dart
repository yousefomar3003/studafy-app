import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../core/studafy_design.dart';
import '../core/language_picker.dart';
import '../core/studafy_domain.dart';
import '../core/studafy_localizations.dart';
import '../core/failures.dart';
import '../features/account/application/account_interactor.dart';
import '../features/account/domain/data_export.dart';
import '../features/account/presentation/delete_account_page.dart';
import '../features/session/application/session_interactor.dart';
import '../features/session/presentation/account_security_page.dart';
import 'account_scope.dart';

/// Provides the session interactor to shared account screens. Composed at
/// the app root, above the Navigator, beside [AccountScope].
class SessionScope extends InheritedWidget {
  const SessionScope({super.key, required this.session, required super.child});

  final SessionInteractor session;

  static SessionInteractor? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<SessionScope>()?.session;

  @override
  bool updateShouldNotify(SessionScope oldWidget) =>
      session != oldWidget.session;
}

/// Opens the shared account screen. Every role shell shows it, because
/// sign-out and in-app account deletion must be reachable for everyone
/// (Apple guideline 5.1.1(v), Google Play account deletion policy).
class AccountButton extends StatelessWidget {
  const AccountButton({super.key});

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: _accountText(context, 'title'),
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
    String t(String key) => _accountText(context, key);
    final context_ = ActiveContextController.instance;
    final profile = context_.profile;
    final membership = context_.membership;
    final session = SessionScope.maybeOf(context);
    return Scaffold(
      backgroundColor: studafyCanvas,
      appBar: AppBar(backgroundColor: Colors.white, title: Text(t('title'))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          FeatureCard(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: studafyNavy,
                  child: Text(
                    _initials(profile?.displayName ?? ''),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile?.displayName ?? t('unknown'),
                        style: const TextStyle(
                          color: studafyInk,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if ((profile?.email ?? '').isNotEmpty)
                        Text(
                          profile!.email,
                          style: const TextStyle(color: studafyMuted),
                        ),
                      if (membership != null)
                        Text(
                          '${membership.schoolName} · '
                          '${t('role.${membership.role.name}')}',
                          style: const TextStyle(
                            color: studafyMuted,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                if (profile != null)
                  ListTile(
                    leading: const Icon(Icons.badge_outlined),
                    title: Text(t('accountId')),
                    subtitle: Text(
                      '${profile.id}\n${t('accountId.detail')}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    isThreeLine: true,
                    trailing: const Icon(Icons.copy_rounded),
                    onTap: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      await Clipboard.setData(ClipboardData(text: profile.id));
                      messenger.showSnackBar(
                        SnackBar(content: Text(t('accountId.copied'))),
                      );
                    },
                  ),
                // A teacher is often a parent at the same school. The domain
                // has always supported holding both; this is the way to use
                // the other one without signing out and back in.
                if (_switchableRoles(context_).isNotEmpty)
                  ListTile(
                    leading: const Icon(Icons.swap_horiz_rounded),
                    title: Text(t('switchRole')),
                    subtitle: Text(t('switchRole.detail')),
                    trailing: Icon(forwardChevron(context)),
                    onTap: () => _showRoleSwitcher(context, context_),
                  ),
                ListTile(
                  leading: const Icon(Icons.language_rounded),
                  title: Text(t('language')),
                  trailing: Icon(forwardChevron(context)),
                  onTap: () => showStudafyLanguagePicker(context),
                ),
                _DataExportTile(account: AccountScope.of(context)),
                if (session != null)
                  ListTile(
                    leading: const Icon(Icons.shield_outlined),
                    title: Text(t('security')),
                    subtitle: Text(t('security.detail')),
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
          const SizedBox(height: 20),
          if (session != null)
            OutlinedButton(
              onPressed: () async {
                await session.signOut();
                if (context.mounted) {
                  Navigator.of(context)
                      .pushNamedAndRemoveUntil('/roles', (_) => false);
                }
              },
              child: Text(t('signOut')),
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
              t('delete'),
              style: const TextStyle(color: Color(0xFFB3261E)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Right of access (DL-051): ask for a copy of your data, then share the
/// finished JSON file. Hidden in builds with no server to export from.
class _DataExportTile extends StatefulWidget {
  const _DataExportTile({required this.account});

  final AccountInteractor account;

  @override
  State<_DataExportTile> createState() => _DataExportTileState();
}

class _DataExportTileState extends State<_DataExportTile> {
  DataExportStatus? _status;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.account.exportAvailable) _refresh();
  }

  Future<void> _refresh() async {
    final result = await widget.account.exportStatus();
    if (!mounted) return;
    setState(
      () => _status = result.fold(onSuccess: (s) => s, onFailure: (_) => null),
    );
  }

  void _say(String key) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_accountText(context, key))));

  Future<void> _request() async {
    setState(() => _busy = true);
    final result = await widget.account.requestExport();
    if (!mounted) return;
    setState(() => _busy = false);
    result.fold(
      onSuccess: (status) {
        setState(() => _status = status);
        _say('export.requested');
      },
      onFailure: (failure) => _say(
        failure.code == 'REAUTH_REQUIRED' ? 'export.reauth' : 'export.failed',
      ),
    );
  }

  Future<void> _download() async {
    setState(() => _busy = true);
    final result = await widget.account.downloadExport();
    if (!mounted) return;
    setState(() => _busy = false);
    final json = result.fold<String?>(
      onSuccess: (v) => v,
      onFailure: (_) => null,
    );
    if (json == null) {
      _say(
        result.fold(onSuccess: (_) => '', onFailure: (f) => f.code) ==
                Failure.notFoundCode
            ? 'export.expired'
            : 'export.failed',
      );
      await _refresh();
      return;
    }
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(
            utf8.encode(json),
            name: 'studafy-my-data.json',
            mimeType: 'application/json',
          ),
        ],
        fileNameOverrides: const ['studafy-my-data.json'],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.account.exportAvailable) return const SizedBox.shrink();
    String t(String key) => _accountText(context, key);
    final state = _status?.state;
    final ready = state == DataExportState.ready;
    final pending = state == DataExportState.pending;
    return ListTile(
      leading: const Icon(Icons.download_rounded),
      title: Text(t('export')),
      subtitle: Text(
        ready
            ? t('export.ready')
            : pending
            ? t('export.pending')
            : t('export.detail'),
      ),
      trailing: _busy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : TextButton(
              onPressed: ready ? _download : (pending ? _refresh : _request),
              child: Text(
                ready
                    ? t('export.download')
                    : pending
                    ? t('export.check')
                    : t('export.request'),
              ),
            ),
    );
  }
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  if (parts.isEmpty) return '?';
  return parts.take(2).map((p) => p.characters.first.toUpperCase()).join();
}

/// Roles this account holds at the active school, other than the current one.
///
/// Empty for the ordinary case of someone with a single role, so the switcher
/// is offered only where there is something to switch to.
List<StudafyRole> _switchableRoles(ActiveContextController context_) {
  final current = context_.membership?.role;
  final school = context_.membership?.schoolId;
  final seen = <StudafyRole>{};
  return [
    for (final membership in context_.profile?.memberships ?? const [])
      if (membership.active &&
          membership.role != StudafyRole.schoolAdmin &&
          membership.schoolId == school &&
          membership.role != current &&
          seen.add(membership.role))
        membership.role,
  ];
}

Future<void> _showRoleSwitcher(
  BuildContext context,
  ActiveContextController context_,
) async {
  String t(String key) => _accountText(context, key);
  final chosen = await showModalBottomSheet<StudafyRole>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final role in _switchableRoles(context_))
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

String _accountText(BuildContext context, String key) {
  final code = StudafyLocalizations.of(context).locale.languageCode;
  return _strings[code]?[key] ?? _strings['en']![key] ?? key;
}

/// Every key in both locales, for the parity test.
Map<String, Set<String>> accountHubStringKeys() => {
  for (final entry in _strings.entries) entry.key: entry.value.keys.toSet(),
};

const _strings = <String, Map<String, String>>{
  'en': {
    'accountId': 'Account ID',
    'accountId.detail': 'Share this with your school to link your account.',
    'accountId.copied': 'Account ID copied',
    'switchRole': 'Switch role',
    'switchRole.detail': 'You belong to this school in more than one role.',
    'title': 'Account',
    'unknown': 'Your account',
    'language': 'Language',
    'security': 'Sign-in and security',
    'security.detail': 'Devices, two-step verification, sign out everywhere',
    'signOut': 'Sign out',
    'delete': 'Delete account',
    'role.schoolAdmin': 'School administrator',
    'role.teacher': 'Teacher',
    'role.parent': 'Parent or guardian',
    'role.student': 'Student',
    'export': 'Download my data',
    'export.detail': 'Get a copy of the information Studafy holds about you.',
    'export.request': 'Request',
    'export.pending': 'Preparing your copy. This can take a few minutes.',
    'export.check': 'Check',
    'export.ready': 'Your copy is ready for 7 days.',
    'export.download': 'Download',
    'export.requested': 'Request received. We are preparing your copy.',
    'export.reauth': 'For your security, sign out and sign in again first.',
    'export.expired': 'That copy has expired. Request a new one.',
    'export.failed': 'That did not work. Please try again.',
  },
  'ar': {
    'accountId': 'معرّف الحساب',
    'accountId.detail': 'شارك هذا المعرّف مع مدرستك لربط حسابك.',
    'accountId.copied': 'تم نسخ معرّف الحساب',
    'switchRole': 'تبديل الدور',
    'switchRole.detail': 'أنت مرتبط بهذه المدرسة بأكثر من دور.',
    'title': 'الحساب',
    'unknown': 'حسابك',
    'language': 'اللغة',
    'security': 'تسجيل الدخول والأمان',
    'security.detail': 'الأجهزة، التحقق بخطوتين، تسجيل الخروج من كل الأجهزة',
    'signOut': 'تسجيل الخروج',
    'delete': 'حذف الحساب',
    'role.schoolAdmin': 'مسؤول المدرسة',
    'role.teacher': 'معلم',
    'role.parent': 'ولي أمر',
    'role.student': 'طالب',
    'export': 'تنزيل بياناتي',
    'export.detail': 'احصل على نسخة من المعلومات التي يحتفظ بها Studafy عنك.',
    'export.request': 'طلب',
    'export.pending': 'نجهّز نسختك. قد يستغرق ذلك بضع دقائق.',
    'export.check': 'تحقق',
    'export.ready': 'نسختك جاهزة لمدة 7 أيام.',
    'export.download': 'تنزيل',
    'export.requested': 'تم استلام الطلب. نجهّز نسختك الآن.',
    'export.reauth': 'لحمايتك، سجّل الخروج ثم سجّل الدخول مرة أخرى أولاً.',
    'export.expired': 'انتهت صلاحية تلك النسخة. اطلب نسخة جديدة.',
    'export.failed': 'لم ينجح ذلك. يرجى المحاولة مرة أخرى.',
  },
};
