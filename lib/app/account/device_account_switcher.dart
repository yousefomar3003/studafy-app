import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/studafy_domain.dart';
import '../../features/accounts/domain/device_account.dart';
import '../../features/session/application/session_interactor.dart';
import '../../features/session/domain/session_repository.dart';

/// Why a switch did not happen. The account that was current is restored
/// whenever it still can be.
enum AccountSwitchFailure {
  /// The account's saved session is over: sign in to it again.
  needsSignIn,

  /// A child account whose parent is not signed in on this device.
  needsParent,
}

class AccountSwitchException implements Exception {
  const AccountSwitchException(this.failure);
  final AccountSwitchFailure failure;

  @override
  String toString() => 'AccountSwitchException($failure)';
}

/// Several accounts on one device, and a parent's child accounts.
///
/// Composed in the app layer because it joins two features - the session
/// (whose session is current) and accounts (which ones the device keeps) -
/// and features may not import each other.
///
/// Only one session is current. Every other account waits in the vault with
/// its latest refresh token, which is kept current by following every token
/// the session layer is issued: tokens rotate, and resuming with an old one
/// would end that account's session. A child account can also always be
/// entered afresh through its parent, with a one-time sign-in the server
/// issues to the parent alone.
class DeviceAccountSwitcher extends ChangeNotifier {
  DeviceAccountSwitcher({
    required this.session,
    required this.vault,
    this.managedChildren,
    this.forgetAccount,
    this.beforeSignOut,
    ActiveContextController? context,
  }) : context = context ?? ActiveContextController.instance {
    _tokens = session.sessionTokens.listen(_onToken);
    this.context.addListener(_onContext);
    _ready = _load();
  }

  final SessionInteractor session;
  final AccountVault vault;

  /// Null in builds that cannot create child accounts.
  final ManagedChildrenRepository? managedChildren;

  /// Deletes what the device keeps for an account that leaves it - its
  /// study helper chats. Called for the account signed out and for every
  /// child account that leaves with it.
  final Future<void> Function(String userId)? forgetAccount;

  /// Runs while the account is still signed in, just before it signs out -
  /// taking this phone off its push notifications.
  final Future<void> Function()? beforeSignOut;
  final ActiveContextController context;

  late final StreamSubscription<SessionToken> _tokens;
  late final Future<void> _ready;

  List<DeviceAccount> _accounts = const [];
  Map<String, String> _tokenById = const {};
  bool _switching = false;
  String? _lastProfileId;

  /// Serialises vault writes, so a token refresh and a list change cannot
  /// interleave and write an older state last.
  Future<void> _writes = Future.value();

  List<DeviceAccount> get accounts => _accounts;
  bool get switching => _switching;

  /// The account whose session is current, when it is one the device keeps.
  DeviceAccount? get current {
    final id = context.profile?.id;
    if (id == null) return null;
    return _accounts.where((account) => account.userId == id).firstOrNull;
  }

  /// Whether the current account may create child accounts: only in the
  /// parent's interface, and never in a child account. The server refuses a
  /// student or a child account too, whatever this says.
  bool get canCreateChild =>
      managedChildren != null &&
      context.profile != null &&
      context.signedInAs == StudafyRole.parent &&
      !(current?.isManaged ?? false);

  @override
  void dispose() {
    unawaited(_tokens.cancel());
    context.removeListener(_onContext);
    super.dispose();
  }

  Future<void> _load() async {
    final saved = await vault.read();
    _accounts = saved.accounts;
    _tokenById = {...saved.tokens, ..._tokenById};
    notifyListeners();
  }

  void _onToken(SessionToken token) {
    _tokenById = {..._tokenById, token.userId: token.refreshToken};
    _persist();
  }

  // Keeps the current account's entry in step with who is signed in: a new
  // sign-in joins the list, and a changed name is picked up.
  void _onContext() {
    final profile = context.profile;
    // Whoever is current decides [current], and the sub-account banner with
    // it, even when the list itself does not change.
    if (profile?.id != _lastProfileId) {
      _lastProfileId = profile?.id;
      notifyListeners();
    }
    final role = context.signedInAs;
    if (profile == null || role == null) return;
    final index = _accounts.indexWhere((a) => a.userId == profile.id);
    if (index < 0) {
      _accounts = [
        ..._accounts,
        DeviceAccount(
          userId: profile.id,
          displayName: profile.displayName,
          role: role,
        ),
      ];
    } else {
      final existing = _accounts[index];
      // A child account is always opened as a student.
      final next = existing.copyWith(
        displayName: profile.displayName,
        role: existing.isManaged ? StudafyRole.student : role,
      );
      if (next.displayName == existing.displayName &&
          next.role == existing.role) {
        return;
      }
      _accounts = [..._accounts]..[index] = next;
    }
    _persist();
    notifyListeners();
  }

  void _persist() {
    // Only tokens for accounts the device keeps, and the one signing in now.
    final keep = {
      for (final account in _accounts) account.userId,
      ?session.currentUserId,
    };
    final list = DeviceAccountList(
      accounts: _accounts,
      tokens: {
        for (final entry in _tokenById.entries)
          if (keep.contains(entry.key)) entry.key: entry.value,
      },
    );
    _writes = _writes.then((_) => vault.write(list)).catchError((Object _) {});
  }

  /// Brings the parent's list of child accounts onto the device, so a new
  /// phone shows them too, and drops any the server no longer has.
  Future<void> refreshManagedChildren() async {
    await _ready;
    final repository = managedChildren;
    final parent = context.profile;
    if (repository == null || parent == null || !canCreateChild) return;
    final List<ManagedChild> children;
    try {
      children = await repository.list();
    } on Object {
      return;
    }
    final listed = {for (final child in children) child.childId: child};
    _accounts = [
      for (final account in _accounts)
        if (account.managedBy != parent.id ||
            listed.containsKey(account.userId))
          account,
      for (final child in children)
        if (!_accounts.any((account) => account.userId == child.childId))
          DeviceAccount(
            userId: child.childId,
            displayName: child.displayName,
            role: StudafyRole.student,
            managedBy: parent.id,
            managedByName: parent.displayName,
          ),
    ];
    _persist();
    notifyListeners();
  }

  /// Creates a child account managed by the current account.
  Future<ManagedChild> createChild(
    String displayName, {
    required String locale,
  }) async {
    final repository = managedChildren;
    final parent = context.profile;
    if (repository == null || parent == null || !canCreateChild) {
      throw const ManagedChildException(ManagedChildRefusal.unavailable);
    }
    final child = await repository.create(
      displayName: displayName,
      locale: locale,
    );
    _accounts = [
      ..._accounts,
      DeviceAccount(
        userId: child.childId,
        displayName: child.displayName,
        role: StudafyRole.student,
        managedBy: parent.id,
        managedByName: parent.displayName,
      ),
    ];
    _persist();
    notifyListeners();
    return child;
  }

  /// Makes [target] the current account and loads it as its role. Returns
  /// the role to open. On failure the account that was current is restored
  /// if it can be, and [AccountSwitchException] says why.
  Future<StudafyRole> switchTo(
    DeviceAccount target, {
    required String locale,
  }) async {
    await _ready;
    if (_switching) throw StateError('A switch is already under way.');
    if (session.currentUserId == target.userId && context.profile != null) {
      return target.role;
    }
    final from = current;
    _switching = true;
    notifyListeners();
    try {
      await _establish(target);
      final loaded = await session.completeRemoteLogin(
        role: target.role,
        consentAccepted: false,
        locale: locale,
      );
      if (loaded.isFailure) {
        throw const AccountSwitchException(AccountSwitchFailure.needsSignIn);
      }
      return target.role;
    } on Object catch (error) {
      await _restore(from, locale: locale);
      if (error is AccountSwitchException) rethrow;
      throw const AccountSwitchException(AccountSwitchFailure.needsSignIn);
    } finally {
      _switching = false;
      notifyListeners();
    }
  }

  Future<void> _establish(DeviceAccount target) async {
    if (await _resume(target.userId)) return;
    final parent = target.managedBy;
    final repository = managedChildren;
    if (parent == null || repository == null) {
      throw const AccountSwitchException(AccountSwitchFailure.needsSignIn);
    }
    // A child account is entered through its parent: only the parent's
    // session can be issued a sign-in to it.
    if (session.currentUserId != parent && !await _resume(parent)) {
      throw const AccountSwitchException(AccountSwitchFailure.needsParent);
    }
    final tokenHash = await repository.signInToken(target.userId);
    await session.enterManagedAccount(tokenHash);
    if (session.currentUserId != target.userId) {
      throw const AccountSwitchException(AccountSwitchFailure.needsSignIn);
    }
  }

  /// Resumes [userId]'s saved session. Checked, not assumed: Supabase keeps
  /// the current session when handed a token that was already used.
  Future<bool> _resume(String userId) async {
    final token = _tokenById[userId];
    if (token == null) return false;
    try {
      await session.resumeSession(token);
    } on Object {
      _forgetToken(userId);
      return false;
    }
    if (session.currentUserId == userId) return true;
    _forgetToken(userId);
    return false;
  }

  void _forgetToken(String userId) {
    _tokenById = {..._tokenById}..remove(userId);
    _persist();
  }

  Future<void> _restore(DeviceAccount? from, {required String locale}) async {
    if (from == null) return;
    try {
      if (session.currentUserId != from.userId && !await _resume(from.userId)) {
        return;
      }
      await session.completeRemoteLogin(
        role: from.role,
        consentAccepted: false,
        locale: locale,
      );
    } on Object {
      // Nothing more to try; the caller sends the person to sign in.
    }
  }

  /// Starts signing in to another account without leaving this one.
  void beginAddingAccount() => session.addingAccount = true;

  /// The add-account screen was left without signing in.
  void cancelAddingAccount() => session.addingAccount = false;

  /// Signs the current account out of this device and forgets it, with any
  /// child accounts it manages - they can only be reached through it. The
  /// other accounts stay. Returns the account to open next, if any.
  Future<DeviceAccount?> signOutCurrent() async {
    await _ready;
    final leaving = session.currentUserId ?? context.profile?.id;
    final leavingAccount = current;
    final remaining = [
      for (final account in _accounts)
        if (account.userId != leaving && account.managedBy != leaving) account,
    ];
    final departing = {
      ?leaving,
      for (final account in _accounts)
        if (account.managedBy == leaving) account.userId,
    };
    final tokens = {
      for (final entry in _tokenById.entries)
        if (remaining.any((account) => account.userId == entry.key))
          entry.key: entry.value,
    };
    try {
      await beforeSignOut?.call().catchError((Object _) {});
      // Erases the whole secure store, this list included; it is written
      // back below without the account that left.
      await session.signOut();
    } finally {
      _accounts = remaining;
      _tokenById = tokens;
      _persist();
      notifyListeners();
      for (final userId in departing) {
        await forgetAccount?.call(userId).catchError((Object _) {});
      }
    }
    // Leaving a child account goes back to its parent; otherwise to any
    // account somebody signed in to themselves.
    final parent = leavingAccount?.managedBy;
    return remaining.where((a) => a.userId == parent).firstOrNull ??
        remaining.where((a) => !a.isManaged).firstOrNull;
  }
}
