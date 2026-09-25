import 'dart:async';
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
import '../features/family/presentation/family_scope.dart';
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
        padding: const EdgeInsetsDirectional.fromSTEB(20, 20, 20, 32),
        children: [
          _ProfileHeader(
            name: profile?.displayName ?? t('unknown'),
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
            const _StudafyIdCard(),
          ],
          const SizedBox(height: 24),
          _SectionLabel(t('section.account')),
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
              ],
            ),
          ),
          const SizedBox(height: 24),
          _SectionLabel(t('section.preferences')),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.language_rounded),
                  title: Text(t('language')),
                  trailing: Icon(forwardChevron(context)),
                  onTap: () => showStudafyLanguagePicker(context),
                ),
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
          const SizedBox(height: 24),
          _SectionLabel(t('section.privacy')),
          Card(
            child: Column(
              children: [_DataExportTile(account: AccountScope.of(context))],
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
    'section.account': 'Account',
    'section.preferences': 'Preferences',
    'section.privacy': 'Privacy and data',
    'studafyId': 'Your Studafy ID',
    'studafyId.detail': 'Give this to a parent so they can ask to link.',
    'studafyId.copy': 'Copy your Studafy ID',
    'studafyId.copied': 'Studafy ID copied.',
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
    'section.account': 'الحساب',
    'section.preferences': 'التفضيلات',
    'section.privacy': 'الخصوصية والبيانات',
    'studafyId': 'معرّف ستودافاي الخاص بك',
    'studafyId.detail': 'أعطِ هذا لولي أمرك ليتمكن من طلب الارتباط.',
    'studafyId.copy': 'نسخ معرّف ستودافاي',
    'studafyId.copied': 'تم نسخ معرّف ستودافاي.',
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

/// A small uppercase heading that groups the settings below it.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(start: 4, bottom: 8),
    child: Text(
      text.toUpperCase(),
      style: const TextStyle(
        color: studafyMuted,
        fontSize: 12,
        fontWeight: FontWeight.w800,
        letterSpacing: .8,
      ),
    ),
  );
}

/// Who you are, at the top of your own profile.
///
/// The name and email come from the sign-in provider and the school and role
/// from the server, so nothing here is editable and nothing is invented: an
/// account with no school shows no school rather than a placeholder one.
class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.name,
    required this.email,
    required this.membership,
    required this.roleLabel,
  });

  final String name;
  final String email;
  final SchoolMembership? membership;
  final String? roleLabel;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(28),
      // Directional so the gradient runs the same way the text does.
      gradient: const LinearGradient(
        begin: AlignmentDirectional.topStart,
        end: AlignmentDirectional.bottomEnd,
        colors: [studafyNavy, Color(0xFF2F2A9E)],
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: Colors.white.withValues(alpha: .18),
              child: Text(
                _initials(name),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (email.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      email,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .82),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        if (membership != null && roleLabel != null) ...[
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _HeaderChip(icon: Icons.badge_outlined, label: roleLabel!),
              _HeaderChip(
                icon: Icons.apartment_rounded,
                label: membership!.schoolName,
              ),
            ],
          ),
        ],
      ],
    ),
  );
}

class _HeaderChip extends StatelessWidget {
  const _HeaderChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .16),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: Colors.white),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

/// The student's own Studafy ID.
///
/// A parent cannot ask to be linked without it, and until now the only place
/// it appeared was inside the family screen - so a student being asked for it
/// by a parent had nowhere obvious to look. Shown only to students, because
/// it identifies one and nobody else needs to read it here.
class _StudafyIdCard extends StatefulWidget {
  const _StudafyIdCard();

  @override
  State<_StudafyIdCard> createState() => _StudafyIdCardState();
}

class _StudafyIdCardState extends State<_StudafyIdCard> {
  String? _id;
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    unawaited(_load());
  }

  Future<void> _load() async {
    // Absent in shells that install no family scope, and in widget tests
    // that pump this page alone. The card is an extra, so it disappears
    // rather than taking the profile down with it.
    final family = FamilyScope.maybeOf(context);
    if (family == null) return;
    final result = await family.studentFamily();
    if (!mounted) return;
    setState(() {
      _id = result.fold(
        onSuccess: (family) => family.identities.firstOrNull?.studafyId,
        // A missing id is not worth an error on a profile screen; the card
        // simply does not appear.
        onFailure: (_) => null,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final id = _id;
    if (id == null) return const SizedBox.shrink();
    return FeatureCard(
      tint: studafyCyan,
      child: Row(
        children: [
          const Icon(Icons.qr_code_rounded, color: studafyCyan),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _accountText(context, 'studafyId'),
                  style: const TextStyle(
                    color: studafyInk,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  id,
                  style: const TextStyle(
                    color: studafyInk,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                  ),
                ),
                Text(
                  _accountText(context, 'studafyId.detail'),
                  style: const TextStyle(color: studafyMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: _accountText(context, 'studafyId.copy'),
            icon: const Icon(Icons.copy_rounded),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final copied = _accountText(context, 'studafyId.copied');
              await Clipboard.setData(ClipboardData(text: id));
              messenger.showSnackBar(SnackBar(content: Text(copied)));
            },
          ),
        ],
      ),
    );
  }
}
