import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'package:supabase_flutter/supabase_flutter.dart' hide SignOutScope;
import 'package:supabase_flutter/supabase_flutter.dart'
    as supabase
    show SignOutScope;

import '../../../core/ids.dart';
import '../../../core/secure_storage.dart';
import '../../../core/studafy_domain.dart';
import '../../../data/backend.dart';
import '../../../data/contracts/v1_client.generated.dart';
import '../../../data/contracts/v1_http_transport.dart';
import '../domain/session_repository.dart';

/// Session source backed by the `/v1` API (AUTH-030).
///
/// Supabase Auth remains the identity provider — it mints and refreshes the
/// tokens — but every authority question is answered by the API, which
/// verifies the token against JWKS and resolves roles from the database.
/// Nothing here reads a role from the client-side session object.
class ApiSessionRepository implements SessionRepository {
  ApiSessionRepository({
    required V1HttpTransport transport,
    required SecureStore secureStore,
    SupabaseClient? client,
  }) // Not an initializing formal, for the same reason as the transport:
    // call sites should read `secureStore:`, not `_secureStore:`.
    // ignore_for_file: prefer_initializing_formals
    : _transport = transport,
       _client = V1ApiClient(transport),
       _secureStore = secureStore,
       _supabase = client;

  final V1HttpTransport _transport;
  final V1ApiClient _client;
  final SecureStore _secureStore;
  final SupabaseClient? _supabase;

  SupabaseClient get _auth => _supabase ?? StudafyBackend.client;

  /// Policy version accepted by the consent checkbox. The database refuses a
  /// version with no published policy row, so bumping this alone fails closed.
  static const _termsPolicyVersion = '2026-09-09';

  @override
  bool get hasCurrentSession => _auth.auth.currentSession != null;

  @override
  Stream<bool> get sessionChanges =>
      _auth.auth.onAuthStateChange.map((state) => state.session != null);

  @override
  Stream<SessionLifecycleEvent> get lifecycleEvents {
    // A failed refresh surfaces as a stream *error*, not as an event, so it
    // has to be caught and translated. Letting it propagate would leave the
    // app showing a stale signed-in shell backed by a dead session.
    final controller = StreamController<SessionLifecycleEvent>.broadcast();
    late final StreamSubscription<AuthState> subscription;
    subscription = _auth.auth.onAuthStateChange.listen(
      (state) => controller.add(_lifecycleFor(state.event)),
      onError: (Object _) =>
          controller.add(SessionLifecycleEvent.refreshFailed),
    );
    controller.onCancel = subscription.cancel;
    return controller.stream;
  }

  static SessionLifecycleEvent _lifecycleFor(AuthChangeEvent event) =>
      switch (event) {
        AuthChangeEvent.signedIn ||
        AuthChangeEvent.initialSession => SessionLifecycleEvent.signedIn,
        AuthChangeEvent.tokenRefreshed => SessionLifecycleEvent.tokenRefreshed,
        AuthChangeEvent.signedOut => SessionLifecycleEvent.signedOut,
        _ => SessionLifecycleEvent.userUpdated,
      };

  @override
  bool supportsProvider(LoginProvider provider) {
    if (provider != LoginProvider.apple) return true;
    return _isApplePlatform &&
        const bool.fromEnvironment('APPLE_SIGN_IN_ENABLED');
  }

  /// Guarded so widget tests, which run on the host platform, can construct
  /// the repository without `Platform` throwing.
  static bool get _isApplePlatform {
    try {
      return Platform.isIOS || Platform.isMacOS;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> signInWithProvider(LoginProvider provider) async {
    if (provider == LoginProvider.apple && _isApplePlatform) {
      await _signInWithAppleNatively();
      return;
    }
    // The owned HTTPS callback is preferred; the custom scheme remains
    // registered as a fallback while domain verification is outstanding.
    final launched = await _auth.auth.signInWithOAuth(
      _providerFor(provider),
      redirectTo: 'io.studafy.app://login-callback',
      // The browser keeps the provider's own cookies, so without this the
      // provider silently reuses whichever account signed in last and never
      // shows a chooser. A phone shared by a parent and a student - the
      // normal case here - would then be locked to one of them, and the only
      // symptom is this app's "wrong role" error, which reads as a bug in
      // Studafy rather than an account it picked. Supabase forwards the
      // parameter unchanged to Google and Azure, which both honour it.
      queryParams: const {'prompt': 'select_account'},
      // Supabase needs Azure's email claim to establish the identity.
      scopes: provider == LoginProvider.microsoft ? 'email' : null,
    );
    if (!launched) throw StateError('Could not open the sign-in browser.');
  }

  /// Native Sign in with Apple (Apple guideline 4.8).
  ///
  /// The browser redirect is deliberately not used on iOS: it shows a web view
  /// for a credential the system can supply directly, which reviewers treat as
  /// a non-equivalent implementation.
  ///
  /// The raw nonce is sent to Supabase and only its SHA-256 goes to Apple, so
  /// the returned identity token is bound to this request and an intercepted
  /// token cannot be replayed into a different sign-in.
  Future<void> _signInWithAppleNatively() async {
    final rawNonce = _randomNonce();
    final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: const [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: hashedNonce,
    );

    final idToken = credential.identityToken;
    if (idToken == null) {
      throw StateError('Apple did not return an identity token.');
    }

    await _auth.auth.signInWithIdToken(
      provider: OAuthProvider.apple,
      idToken: idToken,
      nonce: rawNonce,
    );
  }

  static String _randomNonce([int length = 32]) {
    const characters =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => characters[random.nextInt(characters.length)],
    ).join();
  }

  @override
  Future<UserProfile?> currentProfile() async {
    final me = await _client.getMe();
    return UserProfile(
      id: me.id,
      displayName: me.displayName,
      // Email is identity-provider profile data, not school authorization
      // data; the API-040 /v1/me contract therefore does not duplicate it.
      email: _auth.auth.currentUser?.email ?? '',
      memberships: [
        for (final membership in me.memberships)
          if (_roleFor(membership.role) case final role?)
            SchoolMembership(
              id: membership.id,
              schoolId: membership.schoolId,
              schoolName: membership.schoolName,
              role: role,
              active: membership.active,
            ),
      ],
    );
  }

  @override
  Future<TermInfo?> activeTermForSchool(SchoolId school) async {
    final context = await _client.getAuthContext();
    for (final membership in context.memberships) {
      if (membership.schoolId == school.value) {
        final termId = membership.activeTermId;
        return termId == null
            ? null
            : TermInfo(id: TermId(termId), name: membership.schoolName);
      }
    }
    return null;
  }

  @override
  Future<void> recordTermsConsent({required String locale}) {
    return _auth.rpc(
      'record_policy_consent',
      params: {
        'requested_purpose': 'terms_and_privacy',
        'requested_version': _termsPolicyVersion,
        'requested_locale': locale,
      },
    );
  }

  @override
  Future<void> signOut({
    SignOutScope scope = SignOutScope.currentDevice,
  }) async {
    if (scope == SignOutScope.allDevices) {
      // Tell the server first: it sets the watermark that stops access tokens
      // already in flight on other devices. Doing it after the local sign-out
      // would leave no token to authorize the call. A failure here is not
      // swallowed - the other devices really are still live, and the screen
      // says so - but this device is signed out either way, below.
      try {
        await _client.signOut(const V1AuthSignOutRequestDto(scope: 'all'));
      } finally {
        await _endLocalSession(global: true);
      }
    } else {
      // For the current device the server call only records an audit event;
      // the session itself ends locally. So it is advisory, and must never be
      // able to keep someone signed in: an offline device, an expired token
      // or a 5xx once left the button doing nothing at all, which is both a
      // dead end for the person and an Apple 5.1.1(v) failure.
      try {
        await _client.signOut(const V1AuthSignOutRequestDto(scope: 'current'));
      } catch (_) {
        // Deliberately ignored. The local sign-out below is the one that
        // decides whether this device is still signed in.
      }
      await _endLocalSession(global: false);
    }
  }

  /// Ends the session on this device, whatever the server said.
  ///
  /// The secure store is erased even when the Supabase SDK throws: cached
  /// tokens outliving a sign-out is the worse of the two failures, and it is
  /// the one nothing else would clean up.
  Future<void> _endLocalSession({required bool global}) async {
    try {
      await (global
          ? _auth.auth.signOut(scope: supabase.SignOutScope.global)
          : _auth.auth.signOut());
    } finally {
      await _secureStore.deleteAll();
    }
  }

  @override
  Future<List<AuthDevice>> devices() async {
    final response = await _client.listAuthDevices();
    return [
      for (final device in response.devices)
        AuthDevice(
          id: device.id,
          platform: device.platform,
          label: device.displayLabel,
          lastSeenAt:
              DateTime.tryParse(device.lastSeenAt)?.toLocal() ?? DateTime.now(),
          revoked: device.revokedAt != null,
          isCurrent: device.current,
        ),
    ];
  }

  @override
  Future<bool> revokeDevice(String deviceId) async {
    await confirmRecentAuth(ReauthPurpose.deviceRevoke);
    final response = await _client.revokeAuthDevice(
      V1AuthDeviceRevokeRequestDto(deviceId: deviceId),
    );
    return response.revoked;
  }

  @override
  Future<void> confirmRecentAuth(ReauthPurpose purpose) async {
    final wire = _purposeWire(purpose);
    final verified = await _client.verifyReauth(
      V1ReauthVerifyRequestDto(purpose: wire),
    );
    // Held for exactly one request; the transport clears it after sending.
    _transport.useReauthGrant(verified.grant);
  }

  @override
  Future<bool> mfaEnrolled() async {
    final context = await _client.getAuthContext();
    return context.mfaEnrolled;
  }

  @override
  Future<String> beginTotpEnrolment() async {
    final response = await _auth.auth.mfa.enroll(factorType: FactorType.totp);
    final uri = response.totp?.uri;
    if (uri == null) {
      throw StateError('Enrolment did not return a provisioning URI.');
    }
    return uri;
  }

  @override
  Future<bool> verifyTotp(String code) async {
    final factors = await _auth.auth.mfa.listFactors();
    final factor = factors.totp.firstOrNull;
    if (factor == null) return false;
    final challenge = await _auth.auth.mfa.challenge(factorId: factor.id);
    await _auth.auth.mfa.verify(
      factorId: factor.id,
      challengeId: challenge.id,
      code: code,
    );
    return true;
  }

  @override
  Future<DeletionImpact> deletionImpact() async {
    final impact = await _client.getDeletionImpact();
    return DeletionImpact(
      schools: [
        for (final membership in impact.memberships) membership.schoolName,
      ],
      retainedSchoolRecords: {
        'attendance': impact.retainedSchoolRecords.attendance,
        'grades': impact.retainedSchoolRecords.grades,
        'submissions': impact.retainedSchoolRecords.submissions,
        'wellbeing': impact.retainedSchoolRecords.wellbeing,
      },
      deletedPersonalRecords: {
        'profile': impact.deletedPersonalData.profile,
        'devices': impact.deletedPersonalData.devices,
        'consents': impact.deletedPersonalData.consents,
        'notifications': impact.deletedPersonalData.notifications,
      },
      gracePeriodDays: impact.gracePeriodDays,
    );
  }

  @override
  Future<DeletionRequest> requestAccountDeletion({
    required String reasonCode,
  }) async {
    await confirmRecentAuth(ReauthPurpose.accountDeletion);
    final response = await _client.requestAccountDeletion(
      V1DeletionRequestRequestDto(
        reasonCode: reasonCode,
        confirmation: 'DELETE',
      ),
    );
    return DeletionRequest(
      id: response.id,
      state: response.state,
      executeAfter:
          DateTime.tryParse(response.executeAfter)?.toLocal() ?? DateTime.now(),
    );
  }

  @override
  Future<bool> cancelAccountDeletion() async {
    final response = await _client.cancelAccountDeletion(
      const V1DeletionCancelRequestDto(),
    );
    return response.cancelled;
  }

  static String _purposeWire(ReauthPurpose purpose) => switch (purpose) {
    ReauthPurpose.accountDeletion => 'account_deletion',
    ReauthPurpose.accountLink => 'account_link',
    ReauthPurpose.allDeviceSignOut => 'all_device_sign_out',
    ReauthPurpose.deviceRevoke => 'device_revoke',
    ReauthPurpose.billingPurchaseApproval => 'billing_purchase_approval',
    ReauthPurpose.accountDataExport => 'account_data_export',
  };

  /// Maps a server role onto the client's role vocabulary.
  ///
  /// Authority remains server-derived; this maps the signed membership onto
  /// its matching client shell without widening any permissions locally.
  static StudafyRole? _roleFor(String role) => switch (role) {
    'school_admin' => null, // Not a mobile role in the MVP.
    'teacher' => StudafyRole.teacher,
    'parent' || 'guardian' => StudafyRole.parent,
    'student' => StudafyRole.student,
    _ => null,
  };

  static OAuthProvider _providerFor(LoginProvider provider) =>
      switch (provider) {
        LoginProvider.google => OAuthProvider.google,
        LoginProvider.microsoft => OAuthProvider.azure,
        LoginProvider.apple => OAuthProvider.apple,
      };
}
