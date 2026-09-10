import 'package:flutter/foundation.dart';

import '../../../core/ids.dart';
import '../../../core/studafy_domain.dart';

/// OAuth providers offered on the login screen. The presentation never
/// handles Supabase types; adapters map this onto the SDK provider enum.
enum LoginProvider { google, microsoft, apple }

/// The school's currently active term, resolved after login.
@immutable
class TermInfo {
  const TermInfo({required this.id, required this.name});
  final TermId id;
  final String name;
}

/// Port for everything the session flow needs from the outside world.
///
/// Synthetic builds use the demo implementation; remote builds use the
/// Supabase implementation. Widgets never see either.
abstract interface class SessionRepository {
  /// Whether a remote session already exists (app restart restore).
  bool get hasCurrentSession;

  /// Emits `true` whenever a remote session appears (OAuth callback).
  Stream<bool> get sessionChanges;

  /// Starts the OAuth flow for [provider]. Completing only means the
  /// browser/WebView opened; the session arrives via [sessionChanges].
  Future<void> signInWithProvider(LoginProvider provider);

  /// The signed-in user's profile with memberships, or null when signed out.
  Future<UserProfile?> currentProfile();

  /// The active term for a school, or null when none is active.
  Future<TermInfo?> activeTermForSchool(SchoolId school);

  /// Records acceptance of the current terms/privacy policy version.
  Future<void> recordTermsConsent({required String locale});

  /// Clears the remote session.
  Future<void> signOut();
}
