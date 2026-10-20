import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform, SocketException;
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'package:supabase_flutter/supabase_flutter.dart' hide SignOutScope;
import 'package:supabase_flutter/supabase_flutter.dart'
    as supabase
    show SignOutScope;

import '../../../core/account_lifecycle.dart';
import '../../../core/failures.dart';
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
  PasswordReauthPrompt? _passwordPrompt;

  SupabaseClient get _auth => _supabase ?? StudafyBackend.client;

  @override
  bool get hasCurrentSession => _auth.auth.currentSession != null;

  @override
  Stream<bool> get sessionChanges =>
      _auth.auth.onAuthStateChange.map((state) => state.session != null);

  @override
  Stream<SessionLifecycleEvent> get lifecycleEvents {
    // A failed refresh surfaces as a stream *error*, not as an event, so it
    // has to be caught and translated. Letting it propagate would leave the
    // app showing a stale signed-in shell backed by a dead session. A sign-in
    // link that could not be exchanged arrives the same way, and is told
    // apart so that it cannot end a session it has nothing to do with.
    final controller = StreamController<SessionLifecycleEvent>.broadcast();
    late final StreamSubscription<AuthState> subscription;
    subscription = _auth.auth.onAuthStateChange.listen(
      (state) => controller.add(_lifecycleFor(state.event)),
      onError: (Object error) => controller.add(lifecycleForError(error)),
    );
    // One controller per listener set: when the last listener goes, the
    // auth subscription and the controller both close.
    controller.onCancel = () async {
      await subscription.cancel();
      await controller.close();
    };
    return controller.stream;
  }

  @override
  String? get currentUserId => _auth.auth.currentUser?.id;

  @override
  Stream<SessionToken> get sessionTokens => _auth.auth.onAuthStateChange
      // A failed refresh is reported through [lifecycleEvents]; here it only
      // means there is no new token.
      .handleError((Object _) {})
      .map((state) => state.session)
      .where((session) => (session?.refreshToken ?? '').isNotEmpty)
      .map(
        (session) => SessionToken(
          userId: session!.user.id,
          refreshToken: session.refreshToken!,
        ),
      );

  @override
  Future<void> resumeSession(String refreshToken) async {
    await _auth.auth.setSession(refreshToken);
  }

  @override
  Future<void> enterManagedAccount(String tokenHash) async {
    final response = await _auth.auth.verifyOTP(
      tokenHash: tokenHash,
      type: OtpType.magiclink,
    );
    if (response.session == null) {
      throw StateError('The sign-in did not produce a session.');
    }
  }

  /// What an error on the auth stream means.
  ///
  /// The auth client reports two unrelated failures as stream errors: a
  /// refresh that could not complete, and a sign-in link whose code could not
  /// be exchanged (no code verifier on this device, or a code that is invalid
  /// or expired). A refresh that the server refused outright is a
  /// `signedOut` event instead, so what still arrives here as a refresh
  /// failure is a network or unexpected error, or a stored session that is
  /// missing or expired. Everything else the client throws as an
  /// [AuthException] comes from a link exchange.
  static SessionLifecycleEvent lifecycleForError(Object error) =>
      isSignInLinkFailure(error)
      ? SessionLifecycleEvent.signInLinkFailed
      : SessionLifecycleEvent.refreshFailed;

  static bool isSignInLinkFailure(Object error) {
    if (error is! AuthException) return false;
    if (error is AuthRetryableFetchException ||
        error is AuthSessionMissingException ||
        error is AuthUnknownException) {
      return false;
    }
    final code = error.code;
    return code != ErrorCode.sessionExpired.code &&
        code != ErrorCode.sessionMissing.code;
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

  @override
  Future<void> signInWithPassword({
    required String email,
    required String password,
  }) async {
    final AuthResponse response;
    try {
      response = await _auth.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
    } catch (error) {
      throw PasswordSignInException(passwordSignInErrorFor(error));
    }
    if (response.session == null) {
      throw const PasswordSignInException(PasswordSignInError.unavailable);
    }
  }

  @override
  void usePasswordReauthPrompt(PasswordReauthPrompt? prompt) {
    _passwordPrompt = prompt;
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
    // Both at once: neither needs the other, and each is a full round trip.
    // The kind is on the profile, which an older server may not have; the
    // memberships then speak for it.
    final kindRead = _client.getProfile().then<AccountKind?>(
      (profile) => AccountKind.parse(profile.accountKind),
      onError: (Object _) => null,
    );
    final me = await _client.getMe();
    final kind = await kindRead;
    return UserProfile(
      accountKind: kind,
      // The server's word only; an older server leaves it out.
      platformOperator: me.platformOperator ?? false,
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
  Future<void> recordAccountKind(AccountKind kind) async {
    await _client.updateProfile(
      V1UpdateProfileRequestDto(accountKind: kind.name),
    );
  }

  @override
  Future<bool> hasLinkedChildren() async {
    final links = await _client.listMyGuardianLinks();
    return links.items.any(
      (link) => link.status == 'verified' || link.status == 'pending',
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
        'requested_version': termsPolicyVersion,
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
    final verified = await withRecentSignIn(
      () => _client.verifyReauth(V1ReauthVerifyRequestDto(purpose: wire)),
      _signInAgain,
    );
    // Held for exactly one request; the transport clears it after sending.
    _transport.useReauthGrant(verified.grant);
  }

  /// Signs the same person in again with the provider they used, so the
  /// server sees a sign-in from moments ago (launch plan 2.10).
  ///
  /// The provider's chooser may hand back another account. Then the session
  /// the person was in is put back and nothing proceeds: a grant must never
  /// be issued to, or used by, an account other than the one acting.
  Future<void> _signInAgain() async {
    final auth = _auth.auth;
    final user = auth.currentUser;
    final previous = auth.currentSession?.refreshToken;
    if (user != null && previous != null && isPasswordAccount(user)) {
      await _passwordSignInAgain(user, previous);
      return;
    }
    final provider = loginProviderFor(user?.appMetadata['provider']);
    if (user == null || previous == null || provider == null) {
      // A managed child account has no provider of its own to sign in with.
      throw const Failure.recentSignIn(
        'For your security, sign out and sign in again, then try once more.',
      );
    }
    final next = Completer<Session>();
    final subscription = auth.onAuthStateChange.listen((state) {
      final session = state.session;
      if (state.event == AuthChangeEvent.signedIn &&
          session != null &&
          !next.isCompleted) {
        next.complete(session);
      }
    }, onError: (Object _) {});
    try {
      await signInWithProvider(provider);
      final session = await next.future.timeout(const Duration(minutes: 3));
      if (session.user.id != user.id) {
        await auth.setSession(previous);
        throw const Failure.recentSignIn(
          'That was a different account. Sign in with this account to '
          'continue.',
        );
      }
    } on TimeoutException {
      throw const Failure.recentSignIn(
        'Sign-in was not completed. Try again when you are ready.',
      );
    } finally {
      await subscription.cancel();
    }
  }

  /// The password path of [_signInAgain]: the person types their password
  /// again and it is checked by the same sign-in an OAuth account goes
  /// through, so the server sees a password sign-in from moments ago - the
  /// `amr` entry it counts is method-agnostic.
  ///
  /// The address is the account's own, never typed, so the result can only
  /// be this account; the id is still compared, as for OAuth.
  Future<void> _passwordSignInAgain(User user, String previous) async {
    final prompt = _passwordPrompt;
    final email = user.email ?? '';
    if (prompt == null || email.isEmpty) {
      throw const Failure.recentSignIn(
        'For your security, sign out and sign in again, then try once more.',
      );
    }
    final password = await prompt(email);
    if (password == null || password.isEmpty) {
      throw const Failure.recentSignIn(
        'Sign-in was not completed. Try again when you are ready.',
      );
    }
    final AuthResponse response;
    try {
      response = await _auth.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } catch (error) {
      throw Failure.recentSignIn(switch (passwordSignInErrorFor(error)) {
        PasswordSignInError.invalidCredentials =>
          'That password is not right. Try again.',
        PasswordSignInError.tooManyAttempts =>
          'Too many attempts. Wait a few minutes, then try again.',
        PasswordSignInError.network => Failure.network.message,
        PasswordSignInError.unavailable =>
          'Sign-in was not completed. Try again when you are ready.',
      });
    }
    if (response.session?.user.id != user.id) {
      await _auth.auth.setSession(previous);
      throw const Failure.recentSignIn(
        'That was a different account. Sign in with this account to '
        'continue.',
      );
    }
  }

  @override
  Future<bool> mfaEnrolled() async {
    final context = await _client.getAuthContext();
    return context.mfaEnrolled;
  }

  @override
  Future<TotpEnrolment> beginTotpEnrolment() async {
    final mfa = _auth.auth.mfa;
    // A set-up left unfinished stays behind as an unverified factor. Only the
    // new one is verified, so the old ones go first.
    final existing = await mfa.listFactors();
    for (final factor in existing.all) {
      if (factor.factorType == FactorType.totp &&
          factor.status == FactorStatus.unverified) {
        await mfa.unenroll(factor.id);
      }
    }
    final response = await mfa.enroll(
      factorType: FactorType.totp,
      issuer: 'Studafy',
    );
    final totp = response.totp;
    if (totp == null) {
      throw StateError('Enrolment did not return a provisioning URI.');
    }
    return TotpEnrolment(
      factorId: response.id,
      uri: totp.uri,
      secret: totp.secret,
    );
  }

  @override
  Future<bool> verifyTotp(String factorId, String code) async {
    // The factor being enrolled is still unverified, so it is never in
    // listFactors().totp (verified factors only); it is verified by its id.
    try {
      await _auth.auth.mfa.challengeAndVerify(factorId: factorId, code: code);
      return true;
    } on AuthException catch (error) {
      if (error.code == ErrorCode.mfaVerificationFailed.code) return false;
      rethrow;
    }
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
        'notifications': impact.deletedPersonalData.notifications,
      },
      gracePeriodDays: impact.gracePeriodDays,
      managedChildAccounts: impact.managedChildAccounts,
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

/// The provider a Supabase user signed up with, or null for one that cannot
/// be signed in with again from here (a managed child's magic link, email).
LoginProvider? loginProviderFor(Object? provider) => switch (provider) {
  'google' => LoginProvider.google,
  'azure' => LoginProvider.microsoft,
  'apple' => LoginProvider.apple,
  _ => null,
};

/// Whether [user] signs in with an email and password: an account Studafy
/// provisioned (the store reviewers'). A managed child account is also an
/// `email` identity, but it has no password - it is entered only through
/// its parent - so it is never asked for one.
bool isPasswordAccount(User user) =>
    user.appMetadata['provider'] == 'email' &&
    user.appMetadata['studafy_managed_by'] == null &&
    !(user.email ?? '').endsWith('.invalid');

/// What a failed password sign-in means to the person, from what the auth
/// client threw. A wrong address and a wrong password are the same answer.
PasswordSignInError passwordSignInErrorFor(Object error) {
  if (error is AuthRetryableFetchException) {
    // No status at all: the request never got an answer.
    return error.statusCode == null
        ? PasswordSignInError.network
        : PasswordSignInError.unavailable;
  }
  if (error is AuthException) {
    if (error.statusCode == '429' || error.code == 'over_request_rate_limit') {
      return PasswordSignInError.tooManyAttempts;
    }
    if (error.code == 'invalid_credentials' ||
        (error.statusCode == '400' && error.code == null)) {
      return PasswordSignInError.invalidCredentials;
    }
    return PasswordSignInError.unavailable;
  }
  if (error is SocketException || error is TimeoutException) {
    return PasswordSignInError.network;
  }
  return PasswordSignInError.unavailable;
}

/// Runs [attempt]; if the server answers that a recent sign-in is needed,
/// runs [signInAgain] and tries exactly once more. Anything else - and a
/// second refusal - reaches the caller unchanged.
Future<T> withRecentSignIn<T>(
  Future<T> Function() attempt,
  Future<void> Function() signInAgain,
) async {
  try {
    return await attempt();
  } on V1ApiException catch (error) {
    if (error.code != 'RECENT_SIGN_IN_REQUIRED') rethrow;
  }
  await signInAgain();
  return await attempt();
}
