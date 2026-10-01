import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../core/feedback.dart';
import '../core/language_picker.dart';
import '../core/navigation.dart';
import '../core/profile_photo.dart';
import '../core/studafy_components.dart';
import '../core/studafy_design.dart';
import '../core/studafy_domain.dart';
import '../features/account/presentation/delete_account_page.dart';
import '../features/notifications/presentation/notification_preferences_page.dart';
import '../features/session/presentation/account_security_page.dart';
import '../l10n/generated/app_l10n.dart';
import 'account/account_switching.dart';
import 'account/account_text.dart';
import 'account/account_widgets.dart';
import 'account/data_export_tile.dart';
import 'account/role_switcher.dart';
import 'account_scope.dart';
import 'session_scope.dart';

/// The Subscription row on a profile: where the plans are, and the plan the
/// person has now. Supplied by a shell that sells plans; absent otherwise.
@immutable
class SubscriptionEntry {
  const SubscriptionEntry({required this.open, this.currentPlan});

  final Future<void> Function(BuildContext context) open;

  /// The current plan's name, shown under the row.
  final Future<String?> Function()? currentPlan;
}

/// Opens the shared account screen. Every role shell shows it, because
/// sign-out and in-app account deletion must be reachable for everyone
/// (Apple guideline 5.1.1(v), Google Play account deletion policy).
class AccountButton extends StatelessWidget {
  const AccountButton({super.key, this.subscription});

  /// Adds a Subscription group to the profile it opens.
  final SubscriptionEntry? subscription;

  @override
  Widget build(BuildContext context) {
    final profile = ActiveContextController.instance.profile;
    final name = profile?.displayName ?? '';
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 4, end: 12),
      child: Semantics(
        button: true,
        label: AppL10n.of(context).accountTitle,
        excludeSemantics: true,
        child: Tooltip(
          message: AppL10n.of(context).accountTitle,
          excludeFromSemantics: true,
          child: InkWell(
            customBorder: const CircleBorder(),
            // A long press goes straight to the account list, as on
            // Instagram.
            onLongPress: DeviceAccountsScope.maybeOf(context) == null
                ? null
                : () => openAccountSwitcher(context),
            onTap: () => Navigator.of(context).pushOnce(
              MaterialPageRoute<void>(
                builder: (_) => AccountHubPage(subscription: subscription),
              ),
            ),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: studafyHairline, width: 1.5),
                color: Colors.white,
              ),
              // The photo when this person added one on this device, and
              // otherwise the first two letters of their name.
              child: ProfileAvatar(
                userId: profile?.id,
                radius: 18,
                backgroundColor: studafyWash,
                fallback: Text(
                  profileInitials(name),
                  style: const TextStyle(
                    color: studafyNavy,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The notifications button in a shell's header: a quiet round button with
/// a count badge when something is unread.
class NotificationBellButton extends StatelessWidget {
  const NotificationBellButton({
    super.key,
    required this.onPressed,
    this.unread = 0,
    this.label,
  });

  final VoidCallback onPressed;
  final int unread;

  /// The count as the reader writes numbers; defaults to [unread].
  final String? label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: IconButton(
      tooltip: AppL10n.of(context).todayNotifications,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: Colors.white,
        side: const BorderSide(color: studafyHairline, width: 1.2),
        fixedSize: const Size(42, 42),
        minimumSize: const Size(42, 42),
      ),
      icon: Badge(
        isLabelVisible: unread > 0,
        backgroundColor: studafyDanger,
        label: Text(unread > 99 ? '99+' : (label ?? '$unread')),
        child: const Icon(
          Icons.notifications_none_rounded,
          color: studafyInk,
          size: 22,
        ),
      ),
    ),
  );
}

/// One account screen for teachers, guardians and students, built from the
/// authenticated profile. No sample names or addresses.
///
/// Grouped as in iOS Settings: who you are, your account, preferences,
/// notifications, subscription, then sign-in and security - where deleting
/// the account lives, as on the teacher's profile.
class AccountHubPage extends StatelessWidget {
  const AccountHubPage({super.key, this.subscription});

  final SubscriptionEntry? subscription;

  @override
  Widget build(BuildContext context) {
    String t(String key) => accountText(context, key);
    final l10n = AppL10n.of(context);
    final context_ = ActiveContextController.instance;
    final profile = context_.profile;
    final membership = context_.membership;
    final session = SessionScope.maybeOf(context);
    final deviceAccounts = DeviceAccountsScope.maybeOf(context);
    final student = membership?.role == StudafyRole.student;
    final subscription = this.subscription;
    final accountRows = [
      // Several accounts on one device, Instagram-style, and a parent's
      // child accounts.
      if (deviceAccounts != null)
        SettingsRow(
          icon: Icons.switch_account_rounded,
          title: l10n.accountsSwitchAccount,
          subtitle: l10n.accountsSwitchAccountDetail,
          onTap: () => openAccountSwitcher(context),
        ),
      // A teacher is often a parent at the same school. The domain has always
      // supported holding both; this is the way to use the other one without
      // signing out and back in.
      if (switchableRoles(context_).isNotEmpty)
        SettingsRow(
          icon: Icons.swap_horiz_rounded,
          title: l10n.accountSwitchRole,
          subtitle: l10n.accountSwitchRoleTeacherParent,
          onTap: () => showRoleSwitcher(context, context_),
        ),
    ];
    return Scaffold(
      backgroundColor: studafyCanvas,
      appBar: AppBar(title: Text(l10n.accountTitle)),
      body: ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 40),
        children: [
          AccountProfileHeader(
            name: profile?.displayName ?? l10n.accountUnknown,
            email: profile?.email ?? '',
            membership: membership,
            roleLabel: membership == null
                ? null
                : t('role.${membership.role.name}'),
            userId: profile?.id,
            onPhotoTap: profile == null
                ? null
                : () => _choosePhoto(context, profile.id),
          ),
          SettingsGroup(
            title: l10n.accountSectionProfile,
            children: [
              if (profile != null)
                SettingsRow(
                  icon: Icons.photo_camera_rounded,
                  title: l10n.accountChangePhoto,
                  subtitle: l10n.profilePhotoOnDevice,
                  onTap: () => _choosePhoto(context, profile.id),
                ),
              // A student has one identifier worth knowing: the Studafy ID a
              // parent asks for. Their internal account id is kept out of
              // the way, under sign-in and security.
              if (student)
                const StudafyIdRow()
              else if (profile != null)
                _AccountIdRow(
                  id: profile.id,
                  title: l10n.accountAccountId,
                  detail: l10n.accountAccountIdDetail,
                  copied: l10n.accountAccountIdCopied,
                ),
            ],
          ),
          if (accountRows.isNotEmpty)
            SettingsGroup(
              title: l10n.accountSectionAccount,
              children: accountRows,
            ),
          SettingsGroup(
            title: l10n.accountSectionPreferences,
            children: [
              SettingsRow(
                icon: Icons.language_rounded,
                title: l10n.accountLanguage,
                onTap: () => showStudafyLanguagePicker(context),
              ),
            ],
          ),
          // What each person is notified about, and how - in every role.
          SettingsGroup(
            title: l10n.accountSectionNotifications,
            children: [
              SettingsRow(
                icon: Icons.notifications_active_rounded,
                title: l10n.notificationsNotificationPreferences,
                onTap: () => Navigator.of(context).pushOnce(
                  MaterialPageRoute<void>(
                    builder: (_) => const NotificationPreferencesPage(),
                  ),
                ),
              ),
            ],
          ),
          if (subscription != null)
            SettingsGroup(
              title: l10n.accountSectionSubscription,
              children: [_SubscriptionRow(entry: subscription)],
            ),
          SettingsGroup(
            title: l10n.accountSecurity,
            children: [
              if (session != null)
                SettingsRow(
                  icon: Icons.shield_rounded,
                  title: l10n.accountSecurity,
                  subtitle: l10n.accountSecurityDetailFull,
                  onTap: () => Navigator.of(context).pushOnce(
                    MaterialPageRoute<void>(
                      builder: (_) => AccountSecurityPage(
                        session: session,
                        // Deleting the account is kept with the other
                        // sign-in and security controls, not on the
                        // profile itself.
                        onDeleteAccount: (securityContext) =>
                            Navigator.of(securityContext).pushOnce(
                              MaterialPageRoute<void>(
                                builder: (_) => DeleteAccountPage(
                                  email: accountEmail(context),
                                  account: AccountScope.of(context),
                                ),
                              ),
                            ),
                      ),
                    ),
                  ),
                ),
              DataExportTile(account: AccountScope.of(context)),
              if (student && profile != null)
                _AccountIdRow(
                  id: profile.id,
                  title: l10n.accountTechnicalId,
                  detail: l10n.accountTechnicalIdDetail,
                  copied: l10n.accountAccountIdCopied,
                  icon: Icons.tag_rounded,
                ),
            ],
          ),
          const SizedBox(height: 26),
          if (session != null)
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                foregroundColor: studafyDanger,
                backgroundColor: Colors.white,
                side: const BorderSide(color: studafyHairline),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              icon: const Icon(Icons.logout_rounded),
              onPressed: () async {
                // Only this account leaves the device; another one kept here
                // opens next.
                if (deviceAccounts != null) {
                  await signOutOfDevice(context, deviceAccounts);
                  return;
                }
                // Leaving is not allowed to fail. The interactor clears this
                // device in a finally, so the only thing left to guarantee is
                // that the person actually lands back on the role screen.
                // The photo is this account's own, on this device only.
                if (profile != null) {
                  await ProfilePhotos.delete(profile.id)
                      .catchError((Object _) {});
                }
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
              label: Text(l10n.accountSignOut),
            ),
        ],
      ),
    );
  }
}

/// An identifier with what it is for, copied with a tap.
class _AccountIdRow extends StatelessWidget {
  const _AccountIdRow({
    required this.id,
    required this.title,
    required this.detail,
    required this.copied,
    this.icon = Icons.badge_rounded,
  });

  final String id;
  final String title;
  final String detail;
  final String copied;
  final IconData icon;

  @override
  Widget build(BuildContext context) => SettingsRow(
    icon: icon,
    title: title,
    subtitle: '$id\n$detail',
    trailing: Tooltip(
      message: MaterialLocalizations.of(context).copyButtonLabel,
      child: const Icon(Icons.copy_rounded, color: studafyMuted, size: 20),
    ),
    onTap: () async {
      final messenger = ScaffoldMessenger.of(context);
      await Clipboard.setData(ClipboardData(text: id));
      messenger.showMessage(copied);
    },
  );
}

/// The plan row: the plan the person has, and the way to the Plans screen.
class _SubscriptionRow extends StatefulWidget {
  const _SubscriptionRow({required this.entry});

  final SubscriptionEntry entry;

  @override
  State<_SubscriptionRow> createState() => _SubscriptionRowState();
}

class _SubscriptionRowState extends State<_SubscriptionRow> {
  String? _plan;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final load = widget.entry.currentPlan;
    if (load == null) return;
    try {
      final plan = await load();
      if (mounted) setState(() => _plan = plan);
    } on Object {
      // The row still opens the plans; only the name is missing.
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return SettingsRow(
      icon: Icons.workspace_premium_rounded,
      title: l10n.accountStudyPlan,
      subtitle: _plan == null
          ? l10n.accountStudyPlanDetail
          : '$_plan · ${l10n.accountStudyPlanDetail}',
      onTap: () async {
        await widget.entry.open(context);
        await _load();
      },
    );
  }
}

/// Choose, take or remove the profile photo. It stays on this phone.
Future<void> _choosePhoto(BuildContext context, String userId) async {
  final l10n = AppL10n.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final hasPhoto = await ProfilePhotos.read(userId) != null;
  if (!context.mounted) return;
  final choice = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 8),
            child: Text(
              l10n.profilePhotoOnDevice,
              style: Theme.of(sheetContext).textTheme.bodySmall,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: Text(l10n.profilePhotoChoose),
            onTap: () => Navigator.pop(sheetContext, 'gallery'),
          ),
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: Text(l10n.profilePhotoTake),
            onTap: () => Navigator.pop(sheetContext, 'camera'),
          ),
          if (hasPhoto)
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: Text(l10n.profilePhotoRemove),
              onTap: () => Navigator.pop(sheetContext, 'remove'),
            ),
        ],
      ),
    ),
  );
  if (choice == null) return;
  try {
    if (choice == 'remove') {
      await ProfilePhotos.delete(userId);
      return;
    }
    final bytes = await ProfilePhotos.pick(
      choice == 'camera' ? ImageSource.camera : ImageSource.gallery,
    );
    if (bytes == null) return;
    await ProfilePhotos.save(userId, bytes);
  } on Object {
    messenger.showMessage(l10n.profilePhotoFailed);
  }
}
