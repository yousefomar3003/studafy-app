import 'package:flutter/foundation.dart';

import '../../../core/account_lifecycle.dart';
import '../../../core/ids.dart';
import '../../../core/studafy_domain.dart';

// Re-exported so a session consumer sees the deletion types the port returns
// without also importing core directly.
export '../../../core/account_lifecycle.dart'
    show DeletionImpact, DeletionRequest;

/// OAuth providers offered on the login screen. The presentation never
/// handles Supabase types; adapters map this onto the SDK provider enum.
enum LoginProvider { google, microsoft, apple }

/// Where a sign-out applies.
enum SignOutScope {
  /// This device only. The other devices keep working.
  currentDevice,

  /// Every device. Tokens already issued elsewhere stop working on their next
  /// request, not when they would have expired.
  allDevices,
}

/// What the session layer reports upward (AUTH-030).
///
/// A refresh failure is [reauthRequired], never a silent downgrade: outside a
/// synthetic build there is no demo fallback to fall back to.
enum SessionLifecycleEvent {
  signedIn,
  tokenRefreshed,
  refreshFailed,

  /// A sign-in link's code could not be exchanged: no code verifier on this
  /// device, or a code that is invalid or has expired. Any app or web page
  /// can open such a link, so it says nothing about the session already
  /// held, which must survive it.
  signInLinkFailed,
  signedOut,
  userUpdated,
}

/// Actions that require proof the human is still present.
enum ReauthPurpose {
  accountDeletion,
  accountLink,
  allDeviceSignOut,
  deviceRevoke,

  /// A guardian approving or declining a child's purchase request.
  billingPurchaseApproval,

  /// Requesting a copy of one's own data (right of access).
  accountDataExport,
}

/// The school's currently active term, resolved after login.
@immutable
class TermInfo {
  const TermInfo({required this.id, required this.name});
  final TermId id;
  final String name;
}

/// A device that has held a session for this account.
@immutable
class AuthDevice {
  const AuthDevice({
    required this.id,
    required this.platform,
    required this.label,
    required this.lastSeenAt,
    required this.revoked,
    required this.isCurrent,
  });

  final String id;
  final String platform;
  final String? label;
  final DateTime lastSeenAt;
  final bool revoked;
  final bool isCurrent;
}

/// One account's current refresh token, as the session layer sees it change.
///
/// Refresh tokens rotate on every refresh, and presenting a rotated-out one
/// is treated by Supabase as token theft: it ends that account's session.
/// So an account kept on this device for switching back to has to hold its
/// latest token, which is what this carries each time one is issued.
@immutable
class SessionToken {
  const SessionToken({required this.userId, required this.refreshToken});

  final String userId;
  final String refreshToken;
}

/// Raised when the server demands fresh proof of presence.
class ReauthRequiredFailure implements Exception {
  const ReauthRequiredFailure(this.purpose);
  final ReauthPurpose purpose;
}

/// Why an email-and-password sign-in did not produce a session.
///
/// Only accounts Studafy sets up itself have a password - the app store
/// reviewers' accounts, for one. Nobody can create such an account from the
/// app, so there is deliberately no "no such account" case: a wrong address
/// and a wrong password read the same, which also keeps the screen from
/// telling anyone which addresses exist.
enum PasswordSignInError {
  /// The address and password do not match an account.
  invalidCredentials,

  /// The sign-in service is refusing attempts from here for a while.
  tooManyAttempts,

  /// The device could not reach the sign-in service.
  network,

  /// Password sign-in is switched off, or failed for another reason.
  unavailable,
}

/// Raised by [SessionRepository.signInWithPassword].
class PasswordSignInException implements Exception {
  const PasswordSignInException(this.error);
  final PasswordSignInError error;

  @override
  String toString() => 'PasswordSignInException(${error.name})';
}

/// Asks the person signed in with a password for it again, so a sensitive
/// action rests on a sign-in from moments ago (launch plan 2.10). [email] is
/// the account's own address, shown so the person knows which password is
/// wanted. Completes with null when they cancel.
typedef PasswordReauthPrompt = Future<String?> Function(String email);

/// Port for everything the session flow needs from the outside world.
///
/// Synthetic builds use the demo implementation; remote builds use the
/// API-backed implementation. Widgets never see either.
abstract interface class SessionRepository {
  /// Whether a remote session already exists (app restart restore).
  bool get hasCurrentSession;

  /// Emits `true` whenever a remote session appears (OAuth callback).
  Stream<bool> get sessionChanges;

  /// Emits every lifecycle transition, including refresh failures.
  Stream<SessionLifecycleEvent> get lifecycleEvents;

  /// The signed-in account's id, or null when signed out.
  String? get currentUserId;

  /// Every session token this device is issued: at sign-in and at each
  /// refresh. The device's account list follows it (see [SessionToken]).
  Stream<SessionToken> get sessionTokens;

  /// Makes another account kept on this device the current one, from its
  /// latest refresh token. The account being left keeps its own session.
  Future<void> resumeSession(String refreshToken);

  /// Enters a managed child account with the one-time sign-in the child's
  /// parent was issued for it.
  Future<void> enterManagedAccount(String tokenHash);

  /// Starts the OAuth flow for [provider]. Completing only means the
  /// browser/WebView opened; the session arrives via [sessionChanges].
  ///
  /// On iOS, [LoginProvider.apple] takes the native Sign in with Apple path
  /// instead of a browser redirect (Apple guideline 4.8), and the session is
  /// established before this future completes.
  Future<void> signInWithProvider(LoginProvider provider);

  /// Signs in with an email address and password.
  ///
  /// For accounts Studafy provisions itself (the store reviewers'); the app
  /// offers no way to create one, and the server refuses email sign-up. The
  /// session arrives via [sessionChanges] like any other. Throws
  /// [PasswordSignInException] when no session was established.
  Future<void> signInWithPassword({
    required String email,
    required String password,
  });

  /// Where a password account is asked for its password again when the
  /// server wants a recent sign-in. Null removes it; such a request then
  /// fails, asking the person to sign out and in again.
  void usePasswordReauthPrompt(PasswordReauthPrompt? prompt);

  /// Whether [provider] can be offered on this platform.
  ///
  /// Sign in with Apple is offered on iOS and macOS only: Apple requires it
  /// where third-party login establishes the primary account, and showing it
  /// on Android would offer a button that cannot complete natively.
  bool supportsProvider(LoginProvider provider);

  /// The signed-in user's profile with memberships, or null when signed out.
  Future<UserProfile?> currentProfile();

  /// The active term for a school, or null when none is active.
  Future<TermInfo?> activeTermForSchool(SchoolId school);

  /// Records acceptance of the current terms/privacy policy version.
  Future<void> recordTermsConsent({required String locale});

  /// Records, once, which kind of account this is - from the role the
  /// person first signed in as. The server ignores it once decided.
  Future<void> recordAccountKind(AccountKind kind);

  /// Whether this account follows a child - linked, or asking to be. A
  /// parent holds no school membership, so this is how sign-in tells a
  /// parent's account from one that has never been used.
  Future<bool> hasLinkedChildren();

  /// Clears the session for [scope] and erases locally cached material.
  Future<void> signOut({SignOutScope scope = SignOutScope.currentDevice});

  /// Devices that have held a session for this account.
  Future<List<AuthDevice>> devices();

  /// Revokes one device. Requires a recent-auth grant.
  Future<bool> revokeDevice(String deviceId);

  /// Obtains a single-use recent-auth grant for [purpose].
  Future<void> confirmRecentAuth(ReauthPurpose purpose);

  /// Whether this account has a verified second factor enrolled.
  Future<bool> mfaEnrolled();

  /// Begins TOTP enrolment: a new, unverified factor and what the person
  /// adds to their authenticator app.
  Future<TotpEnrolment> beginTotpEnrolment();

  /// Completes the enrolment of [factorId] with a code from the app. False
  /// when the code is wrong, so the person can try again.
  Future<bool> verifyTotp(String factorId, String code);

  /// What deletion would do to this account.
  Future<DeletionImpact> deletionImpact();

  /// Schedules deletion. Requires a recent-auth grant.
  Future<DeletionRequest> requestAccountDeletion({required String reasonCode});

  /// Cancels a scheduled deletion. Deliberately needs no recent-auth grant.
  Future<bool> cancelAccountDeletion();
}

/// A TOTP enrolment that has been started but not verified yet.
class TotpEnrolment {
  const TotpEnrolment({
    required this.factorId,
    required this.uri,
    required this.secret,
  });

  /// The unverified factor the first code verifies.
  final String factorId;

  /// The otpauth:// link an authenticator app opens.
  final String uri;

  /// The same key, for typing or pasting into the app by hand.
  final String secret;
}
