import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/data/contracts/v1_http_transport.dart';
import 'package:studafy/features/session/data/api_session_repository.dart';
import 'package:studafy/features/session/domain/session_repository.dart';

/// Launch plan 2.10: a re-authentication grant needs a sign-in from moments
/// ago, so the app signs in again once when the server says so.
void main() {
  V1ApiException refusal(String code, {int status = 403}) =>
      V1ApiException(status: status, code: code, message: 'refused');

  test(
    'signs in again once, then retries, when a recent sign-in is needed',
    () async {
      var attempts = 0;
      var signIns = 0;
      final result = await withRecentSignIn(() async {
        attempts += 1;
        if (attempts == 1) throw refusal('RECENT_SIGN_IN_REQUIRED');
        return 'grant';
      }, () async => signIns += 1);
      expect(result, 'grant');
      expect(attempts, 2);
      expect(signIns, 1);
    },
  );

  test('a fresh session is not asked to sign in again', () async {
    var signIns = 0;
    final result = await withRecentSignIn(
      () async => 'grant',
      () async => signIns += 1,
    );
    expect(result, 'grant');
    expect(signIns, 0);
  });

  test('other refusals are not turned into a sign-in', () async {
    var signIns = 0;
    await expectLater(
      withRecentSignIn<String>(
        () async => throw refusal('MFA_REQUIRED'),
        () async => signIns += 1,
      ),
      throwsA(isA<V1ApiException>()),
    );
    expect(signIns, 0);
  });

  test('a second refusal reaches the caller; no loop', () async {
    var attempts = 0;
    await expectLater(
      withRecentSignIn<String>(() async {
        attempts += 1;
        throw refusal('RECENT_SIGN_IN_REQUIRED');
      }, () async {}),
      throwsA(isA<V1ApiException>()),
    );
    expect(attempts, 2);
  });

  test('a cancelled sign-in stops the action', () async {
    var attempts = 0;
    await expectLater(
      withRecentSignIn<String>(() async {
        attempts += 1;
        throw refusal('RECENT_SIGN_IN_REQUIRED');
      }, () async => throw StateError('cancelled')),
      throwsA(isA<StateError>()),
    );
    expect(attempts, 1);
  });

  test('only accounts with a provider of their own can sign in again', () {
    expect(loginProviderFor('google'), LoginProvider.google);
    expect(loginProviderFor('azure'), LoginProvider.microsoft);
    expect(loginProviderFor('apple'), LoginProvider.apple);
    // A managed child signs in through a magic link the parent issues.
    expect(loginProviderFor('email'), isNull);
    expect(loginProviderFor(null), isNull);
  });
}
