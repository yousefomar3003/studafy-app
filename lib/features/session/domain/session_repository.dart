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

/// Raised when the server demands fresh proof of presence.
class ReauthRequiredFailure implements Exception {
  const ReauthRequiredFailure(this.purpose);
  final ReauthPurpose purpose;
}

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

  /// Starts the OAuth flow for [provider]. Completing only means the
  /// browser/WebView opened; the session arrives via [sessionChanges].
  ///
  /// On iOS, [LoginProvider.apple] takes the native Sign in with Apple path
  /// instead of a browser redirect (Apple guideline 4.8), and the session is
  /// established before this future completes.
  Future<void> signInWithProvider(LoginProvider provider);

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

  /// Begins TOTP enrolment, returning the provisioning URI to display.
  Future<String> beginTotpEnrolment();

  /// Completes TOTP enrolment or a challenge with a user-supplied code.
  Future<bool> verifyTotp(String code);

  /// What deletion would do to this account.
  Future<DeletionImpact> deletionImpact();

  /// Schedules deletion. Requires a recent-auth grant.
  Future<DeletionRequest> requestAccountDeletion({required String reasonCode});

  /// Cancels a scheduled deletion. Deliberately needs no recent-auth grant.
  Future<bool> cancelAccountDeletion();
}
