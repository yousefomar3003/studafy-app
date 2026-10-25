import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../core/ai_consent.dart';
import '../core/ai_consent_sheet.dart';
import '../core/ai_usage.dart';
import '../core/feedback.dart';
import '../core/language_picker.dart';
import '../core/navigation.dart';
import '../core/profile_photo.dart';
import '../core/studafy_components.dart';
import '../core/studafy_design.dart';
import '../core/studafy_domain.dart';
import '../features/academic/presentation/marking_opt_out_switch.dart';
import '../features/academic/presentation/marking_scope.dart';
import '../features/account/application/account_interactor.dart';
import '../features/account/domain/profile_repository.dart';
import '../features/account/presentation/delete_account_page.dart';
import '../features/notifications/presentation/notification_preferences_page.dart';
import '../features/safety_review/presentation/safety_reports_page.dart';
import '../features/session/presentation/account_security_page.dart';
import '../l10n/generated/app_l10n.dart';
import 'account/account_switching.dart';
import 'account/account_text.dart';
import 'account/account_widgets.dart';
import 'account/data_export_tile.dart';
import 'account/role_switcher.dart';
import 'account_scope.dart';
import 'session_scope.dart';

/// The Subscription part of a profile: where the plans are, the plan the
/// person has now, and Restore purchases. Supplied by a shell that sells
/// plans; absent otherwise.
@immutable
class SubscriptionEntry {
  const SubscriptionEntry({
    this.open,
    this.currentPlan,
    this.usage,
    this.restorePurchases,
    this.title,
    this.detail,
  });

  /// The plans row's name and line under it; the study plans' by default.
  final String? title;
  final String? detail;

  /// Opens the plans. Null where the profile has no plans row (a parent,
  /// whose Family+ lives on its own tab).
  final Future<void> Function(BuildContext context)? open;

  /// The current plan's name, shown under the row.
  final Future<String?> Function()? currentPlan;

  /// The plan's AI usage, as the server has it, for the AI usage section.
  final Future<AiUsageSnapshot?> Function()? usage;

  /// Asks the store again for this account's subscriptions: the student's
  /// plan, or a parent's Family+. Shown as a small link at the bottom of the
  /// Subscription group - kept out of the way, but always there, because
  /// the App Store requires a way to restore auto-renewing subscriptions.
  final Future<void> Function()? restorePurchases;
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
class AccountHubPage extends StatefulWidget {
  const AccountHubPage({super.key, this.subscription});

  final SubscriptionEntry? subscription;

  @override
  State<AccountHubPage> createState() => _AccountHubPageState();
}

class _AccountHubPageState extends State<AccountHubPage> {
  /// The person's own profile as the server has it: the name they chose and
  /// their Studafy number. Null until read, or in builds that cannot read it.
  OwnProfile? _own;
  bool _started = false;

  /// True while the profile is being read. The Studafy number's row holds its
  /// place meanwhile, so the rows below it - Switch account among them - do
  /// not jump down when the number arrives.
  bool _ownLoading = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    unawaited(_loadOwn());
  }

  Future<void> _loadOwn() async {
    final account = AccountScope.maybeOf(context);
    if (account == null || !account.profileAvailable) return;
    _ownLoading = true;
    final result = await account.ownProfile();
    if (!mounted) return;
    setState(() {
      _ownLoading = false;
      result.fold(onSuccess: (own) => _own = own, onFailure: (_) {});
    });
  }

  /// Edit name: a prefilled form, saved to the server, then shown
  /// everywhere the app reads the name.
  Future<void> _editName(String current) async {
    final account = AccountScope.maybeOf(context);
    if (account == null || !account.profileAvailable) return;
    final saved = await showModalBottomSheet<OwnProfile>(
      context: context,
      isScrollControlled: true,
      // Typing grows the sheet; it stops below the status bar.
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheet) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheet).bottom),
        child: _EditNameSheet(initial: current, account: account),
      ),
    );
    if (saved == null || !mounted) return;
    final context_ = ActiveContextController.instance;
    final profile = context_.profile;
    if (profile != null) {
      context_.hydrate(
        authenticatedProfile: UserProfile(
          id: profile.id,
          displayName: saved.displayName,
          email: profile.email,
          memberships: profile.memberships,
          accountKind: profile.accountKind,
          platformOperator: profile.platformOperator,
        ),
        activeMembership: context_.membership,
        student: context_.selectedStudent,
        termId: context_.activeTermId,
        signedInAs: context_.signedInAs,
      );
    }
    setState(() => _own = saved);
    ScaffoldMessenger.of(context)
        .showMessage(AppL10n.of(context).accountNameSaved);
  }

  @override
  Widget build(BuildContext context) {
    String t(String key) => accountText(context, key);
    final l10n = AppL10n.of(context);
    final context_ = ActiveContextController.instance;
    final profile = context_.profile;
    final membership = context_.membership;
    final session = SessionScope.maybeOf(context);
    final deviceAccounts = DeviceAccountsScope.maybeOf(context);
    final student =
        membership?.role == StudafyRole.student ||
        context_.signedInAs == StudafyRole.student;
    final subscription = widget.subscription;
    final account = AccountScope.maybeOf(context);
    final safetyReview = AccountScope.safetyReviewOf(context);
    final canRename = profile != null && (account?.profileAvailable ?? false);
    final name = _own?.displayName ?? profile?.displayName ?? '';
    final publicId = switch (_own?.publicId) {
      final number? => studafyIdFor(number, teacher: _isTeacher(profile)),
      null => null,
    };
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
            name: name.isEmpty ? l10n.accountUnknown : name,
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
              if (canRename)
                SettingsRow(
                  icon: Icons.person_rounded,
                  title: l10n.accountName,
                  subtitle: name,
                  trailing: TextButton(
                    onPressed: () => _editName(name),
                    child: Text(l10n.accountEditName),
                  ),
                  onTap: () => _editName(name),
                ),
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
              // One ID a person reads out: a student's is the Studafy ID a
              // parent links with; an adult's is their Studafy number. The
              // internal account id waits under sign-in and security.
              if (student)
                const StudafyIdRow()
              else if (publicId != null || _ownLoading)
                _AccountIdRow(
                  id: publicId,
                  title: l10n.accountStudafyId,
                  detail: l10n.accountPublicIdDetail,
                  copied: l10n.accountStudafyIdCopied,
                  icon: Icons.qr_code_rounded,
                ),
            ],
          ),
          if (accountRows.isNotEmpty)
            SettingsGroup(
              title: l10n.accountSectionAccount,
              children: accountRows,
            ),
          // The AI study tools, on and off (ADR-0043). Shown only to a
          // student in a class on a server that runs them; the switch hides
          // itself, and its group with it, for anyone else.
          if (student && AiConsentGate.instance.repository != null)
            AiConsentSwitch(
              repository: AiConsentGate.instance.repository!,
              wrap: (row) =>
                  SettingsGroup(title: l10n.aiConsentTitle, children: [row]),
            ),
          // Suggested marks (ADR-0046): a student's own choice whether
          // their work may be sent for one. Students only.
          if (student && MarkingScope.maybeOf(context)?.preference != null)
            MarkingOptOutSwitch(
              preference: MarkingScope.maybeOf(context)!.preference!,
              wrap: (row) => SettingsGroup(
                title: l10n.markingOptOutSection,
                children: [row],
              ),
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
          if (subscription?.usage != null)
            SettingsGroup(
              title: l10n.usageSectionTitle,
              children: [_AiUsageSection(entry: subscription!)],
            ),
          if (subscription != null &&
              (subscription.open != null ||
                  subscription.restorePurchases != null))
            SettingsGroup(
              title: l10n.accountSectionSubscription,
              children: [
                if (subscription.open != null)
                  _SubscriptionRow(entry: subscription),
                if (subscription.restorePurchases != null)
                  _RestorePurchasesLink(
                    restore: subscription.restorePurchases!,
                  ),
              ],
            ),
          // The platform operator's safety-report review (DL-063): only for
          // an account the server marks as an operator (GET /v1/me), never
          // inferred here. The server checks every step again.
          if (profile?.platformOperator == true && safetyReview != null)
            SettingsGroup(
              title: l10n.safetyReviewSection,
              children: [
                SettingsRow(
                  icon: Icons.report_outlined,
                  title: l10n.safetyReviewTitle,
                  subtitle: l10n.safetyReviewEntrySubtitle,
                  onTap: () => Navigator.of(context).pushOnce(
                    MaterialPageRoute<void>(
                      builder: (_) => SafetyReportsPage(
                        review: safetyReview,
                        // Setting up an authenticator happens where it
                        // always does: Account -> Security.
                        onOpenSecurity: (pageContext) async {
                          if (session == null) return;
                          await Navigator.of(pageContext).pushOnce(
                            MaterialPageRoute<void>(
                              builder: (_) => AccountSecurityPage(
                                session: session,
                                reviewsReports: true,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ],
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
                        reviewsReports: profile?.platformOperator == true,
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
              if (profile != null)
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

  /// Null while it is still being read: the row keeps its place, with
  /// nothing to copy yet.
  final String? id;
  final String title;
  final String detail;
  final String copied;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final id = this.id;
    return SettingsRow(
      icon: icon,
      title: title,
      subtitle: '${id ?? '…'}\n$detail',
      trailing: Tooltip(
        message: MaterialLocalizations.of(context).copyButtonLabel,
        child: Icon(
          Icons.copy_rounded,
          color: id == null ? studafyHairline : studafyMuted,
          size: 20,
        ),
      ),
      onTap: id == null
          ? null
          : () async {
              final messenger = ScaffoldMessenger.of(context);
              await Clipboard.setData(ClipboardData(text: id));
              messenger.showMessage(copied);
            },
    );
  }
}

/// The plan row: the plan the person has, and the way to the Plans screen.
/// How much AI use is left, as a bar and a label - never a count - with
/// when it resets and the way to more.
class _AiUsageSection extends StatefulWidget {
  const _AiUsageSection({required this.entry});

  final SubscriptionEntry entry;

  @override
  State<_AiUsageSection> createState() => _AiUsageSectionState();
}

class _AiUsageSectionState extends State<_AiUsageSection> {
  AiUsageSnapshot? _usage;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final usage = await widget.entry.usage!();
      if (mounted) {
        setState(() {
          _usage = usage;
          _failed = usage == null;
        });
      }
    } on Object {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final usage = _usage;
    if (usage == null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: _failed
            ? TextButton.icon(
                onPressed: () {
                  setState(() => _failed = false);
                  _load();
                },
                icon: const Icon(Icons.refresh_rounded),
                label: Text(AppL10n.of(context).usageLoadFailed),
              )
            : const LinearProgressIndicator(),
      );
    }
    final open = widget.entry.open;
    return AiUsageCard(
      usage: usage,
      onPlans: open == null
          ? null
          : () async {
              await open(context);
              await _load();
            },
    );
  }
}

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
    final detail = widget.entry.detail ?? l10n.accountStudyPlanDetail;
    return SettingsRow(
      icon: Icons.workspace_premium_rounded,
      title: widget.entry.title ?? l10n.accountStudyPlan,
      subtitle: _plan == null ? detail : '$_plan · $detail',
      onTap: () async {
        await widget.entry.open!(context);
        await _load();
      },
    );
  }
}

/// Restore purchases, as small low-emphasis text at the bottom of the
/// Subscription group. It runs the store restore and says what happened.
class _RestorePurchasesLink extends StatefulWidget {
  const _RestorePurchasesLink({required this.restore});

  final Future<void> Function() restore;

  @override
  State<_RestorePurchasesLink> createState() => _RestorePurchasesLinkState();
}

class _RestorePurchasesLinkState extends State<_RestorePurchasesLink> {
  bool _busy = false;

  Future<void> _run() async {
    if (_busy) return;
    final l10n = AppL10n.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    String message;
    try {
      await widget.restore();
      message = l10n.accountRestoringPurchases;
    } on Object {
      message = l10n.studySetThatDidNotWorkPlease;
    }
    if (mounted) setState(() => _busy = false);
    messenger.showMessage(message);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return Align(
      alignment: AlignmentDirectional.centerEnd,
      // A real button, read out as "Restore purchases", with the usual
      // 48-point touch target: small to look at, not small to reach.
      child: TextButton(
        onPressed: _busy ? null : _run,
        style: TextButton.styleFrom(
          foregroundColor: studafyMuted,
          textStyle: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
          ),
        ),
        child: Text(l10n.accountRestorePurchases),
      ),
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

/// Edit name: the current name, ready to change. Saved only when the server
/// says so; a failure keeps the form open with the typed name.
class _EditNameSheet extends StatefulWidget {
  const _EditNameSheet({required this.initial, required this.account});

  final String initial;
  final AccountInteractor account;

  @override
  State<_EditNameSheet> createState() => _EditNameSheetState();
}

class _EditNameSheetState extends State<_EditNameSheet> {
  late final _name = TextEditingController(text: widget.initial);
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final l10n = AppL10n.of(context);
    if (normaliseDisplayName(_name.text) == null) {
      setState(() => _error = l10n.accountNameInvalid);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final result = await widget.account.rename(_name.text);
    if (!mounted) return;
    result.fold(
      onSuccess: (saved) => Navigator.pop(context, saved),
      onFailure: (_) => setState(() {
        _saving = false;
        _error = l10n.accountNameFailed;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.accountEditNameTitle,
              style: const TextStyle(
                color: studafyInk,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.accountNameHelp,
              style: const TextStyle(color: studafyMuted, height: 1.4),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              autofocus: true,
              enabled: !_saving,
              maxLength: maxDisplayNameLength,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: l10n.accountName,
                errorText: _error,
                counterText: '',
              ),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              child: _saving
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(l10n.accountSaveAction),
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: _saving ? null : () => Navigator.pop(context),
              style: TextButton.styleFrom(
                minimumSize: const Size.fromHeight(46),
              ),
              child: Text(l10n.accountCancelAction),
            ),
          ],
        ),
      ),
    );
  }
}

/// Whether this account teaches anywhere, whichever role it is in now.
bool _isTeacher(UserProfile? profile) =>
    profile?.memberships.any(
      (m) => m.active && m.role == StudafyRole.teacher,
    ) ??
    false;

/// How an adult's Studafy number is shown: a teacher's reads as a code,
/// like a student's SJ-..., so it is never taken for a phone number; a
/// parent's is the plain number. The stored number is the same either way.
String studafyIdFor(String number, {required bool teacher}) =>
    teacher ? 'TC-$number' : number;
