import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/ids.dart';
import '../../../core/studafy_domain.dart';
import '../../../data/backend.dart';
import '../../../data/supabase_repository.dart';
import '../domain/session_repository.dart';

/// Policy version accepted by the consent checkbox. Bumping it is a reviewed
/// change tied to the policy text shown on the login screen.
const _termsPolicyVersion = '2026-09-09';

/// Remote session source over Supabase Auth and PostgREST (RLS-scoped).
class SupabaseSessionRepository implements SessionRepository {
  SupabaseClient get _client => StudafyBackend.client;

  @override
  bool get hasCurrentSession => _client.auth.currentSession != null;

  @override
  Stream<bool> get sessionChanges =>
      _client.auth.onAuthStateChange.map((state) => state.session != null);

  @override
  Future<void> signInWithProvider(LoginProvider provider) {
    return _client.auth.signInWithOAuth(
      _providerFor(provider),
      redirectTo: 'io.studafy.app://login-callback',
    );
  }

  @override
  Future<UserProfile?> currentProfile() {
    // Delegates to the existing typed repository (same join, same RLS).
    return SupabaseStudafyRepository().currentProfile();
  }

  @override
  Future<TermInfo?> activeTermForSchool(SchoolId school) async {
    final rows = await _client
        .from('terms')
        .select('id, name')
        .eq('school_id', school.value)
        .eq('active', true)
        .limit(1);
    if (rows.isEmpty) return null;
    final row = rows.first;
    return TermInfo(
      id: TermId(row['id'] as String),
      name: row['name'] as String,
    );
  }

  @override
  Future<void> recordTermsConsent({required String locale}) {
    return _client.rpc(
      'record_policy_consent',
      params: {
        'requested_purpose': 'terms_and_privacy',
        'requested_version': _termsPolicyVersion,
        'requested_locale': locale,
      },
    );
  }

  @override
  Future<void> signOut() => _client.auth.signOut();

  static OAuthProvider _providerFor(LoginProvider provider) =>
      switch (provider) {
        LoginProvider.google => OAuthProvider.google,
        LoginProvider.microsoft => OAuthProvider.azure,
        LoginProvider.apple => OAuthProvider.apple,
      };
}
