import 'dart:async';
import 'dart:io' show SocketException;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/backend.dart';
import '../domain/safety_review.dart';

/// Presents the account's authenticator (TOTP) code to Supabase Auth as a
/// second factor for this session (an MFA challenge, then its verification),
/// so the session's next token carries `aal2`. The moderation routes refuse
/// anything less (DL-063). Same factor as Account -> Security enrols.
class SupabaseSecondFactor {
  SupabaseSecondFactor([this._client]);

  final SupabaseClient? _client;

  SupabaseClient get _auth => _client ?? StudafyBackend.client;

  Future<void> verify(String code) async {
    final List<Factor> factors;
    try {
      // Verified authenticators only: one still being set up cannot step up.
      factors = (await _auth.auth.mfa.listFactors()).totp;
    } on Object catch (error) {
      throw SafetyReviewException(secondFactorErrorFor(error));
    }
    final factor = factors.firstOrNull;
    if (factor == null) {
      throw const SafetyReviewException(SafetyReviewError.notEnrolled);
    }
    try {
      final challenge = await _auth.auth.mfa.challenge(factorId: factor.id);
      await _auth.auth.mfa.verify(
        factorId: factor.id,
        challengeId: challenge.id,
        code: code,
      );
    } on Object catch (error) {
      throw SafetyReviewException(secondFactorErrorFor(error, verifying: true));
    }
  }
}

/// What a failed second-factor step means to the operator. When [verifying],
/// a refusal from Auth (a 4xx other than rate limiting) is a code that did
/// not match; anything else is the service or the connection.
SafetyReviewError secondFactorErrorFor(Object error, {bool verifying = false}) {
  if (error is SocketException || error is TimeoutException) {
    return SafetyReviewError.unavailable;
  }
  if (error is AuthRetryableFetchException) {
    return SafetyReviewError.unavailable;
  }
  if (error is AuthException && verifying) {
    if (error.code == 'mfa_verification_failed' ||
        error.code == 'mfa_challenge_expired' ||
        error.code == 'mfa_verification_rejected') {
      return SafetyReviewError.wrongCode;
    }
    final status = int.tryParse(error.statusCode ?? '');
    if (status != null && status >= 400 && status < 500 && status != 429) {
      return SafetyReviewError.wrongCode;
    }
  }
  return SafetyReviewError.unavailable;
}
