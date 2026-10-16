import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/core/failures.dart';
import 'package:studafy/core/secure_storage.dart';
import 'package:studafy/data/contracts/v1_http_transport.dart';
import 'package:studafy/features/session/data/api_session_repository.dart';
import 'package:studafy/features/session/domain/session_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A password account (the store reviewers') through the real repository,
/// the real auth client and the real API transport, against a loopback
/// stand-in for Supabase Auth and the API.
///
/// What matters is launch plan 2.10: deleting the account or exporting its
/// data needs a sign-in from moments ago. An OAuth account gets its
/// provider's sign-in; a password account must be asked for its password
/// and signed in again, never left with "sign out and in again" as its only
/// way through.
void main() {
  late _StandIn server;
  late SupabaseClient client;
  late ApiSessionRepository repository;

  setUp(() async {
    server = await _StandIn.start();
    client = SupabaseClient(
      server.url,
      'public-test-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    repository = ApiSessionRepository(
      client: client,
      secureStore: InMemorySecureStore(),
      transport: V1HttpTransport(
        baseUri: Uri.parse(server.url),
        accessToken: () async => client.auth.currentSession?.accessToken,
        refreshSession: () async => false,
        onSessionLost: () {},
      ),
    );
  });

  tearDown(() async {
    await client.dispose();
    await server.close();
  });

  group('signing in with a password', () {
    test('establishes a session for the provisioned account', () async {
      await repository.signInWithPassword(
        email: ' teacher@review.studafy.com ',
        password: 'right',
      );
      expect(repository.currentUserId, _StandIn.reviewer);
      expect(server.passwordSignIns.single, {
        'email': 'teacher@review.studafy.com',
        'password': 'right',
      });
    });

    test('a wrong password is reported as such, nothing more', () async {
      server.passwordAnswer = 'wrong';
      await expectLater(
        repository.signInWithPassword(email: 'a@b.co', password: 'x'),
        throwsA(
          isA<PasswordSignInException>().having(
            (e) => e.error,
            'error',
            PasswordSignInError.invalidCredentials,
          ),
        ),
      );
      expect(repository.hasCurrentSession, isFalse);
    });

    test('the auth rate limit is reported as too many attempts', () async {
      server.passwordAnswer = 'limited';
      await expectLater(
        repository.signInWithPassword(email: 'a@b.co', password: 'x'),
        throwsA(
          isA<PasswordSignInException>().having(
            (e) => e.error,
            'error',
            PasswordSignInError.tooManyAttempts,
          ),
        ),
      );
    });

    test('an unreachable server is reported as no connection', () async {
      await server.close();
      await expectLater(
        repository.signInWithPassword(email: 'a@b.co', password: 'x'),
        throwsA(
          isA<PasswordSignInException>().having(
            (e) => e.error,
            'error',
            PasswordSignInError.network,
          ),
        ),
      );
    });
  });

  group('a recent sign-in for a password account', () {
    setUp(() async {
      await repository.signInWithPassword(
        email: 'parent@review.studafy.com',
        password: 'right',
      );
      server.passwordSignIns.clear();
      server.refuseFirstReauth = true;
    });

    test('asks for the password, signs in again and retries once', () async {
      final asked = <String>[];
      repository.usePasswordReauthPrompt((email) async {
        asked.add(email);
        return 'right';
      });
      final tokenBefore = client.auth.currentSession!.accessToken;

      await repository.confirmRecentAuth(ReauthPurpose.accountDeletion);

      expect(asked, ['parent@review.studafy.com']);
      expect(server.passwordSignIns.single, {
        'email': 'parent@review.studafy.com',
        'password': 'right',
      });
      expect(server.reauthBearers, hasLength(2));
      expect(server.reauthBearers.first, tokenBefore);
      // The retry carries the new sign-in, whose `amr` is from just now.
      expect(server.reauthBearers.last, isNot(tokenBefore));
      expect(repository.currentUserId, _StandIn.reviewer);
    });

    test('works for a data export the same way', () async {
      repository.usePasswordReauthPrompt((_) async => 'right');
      await repository.confirmRecentAuth(ReauthPurpose.accountDataExport);
      expect(server.reauthPurposes, [
        'account_data_export',
        'account_data_export',
      ]);
    });

    test('cancelling stops there, with nothing granted', () async {
      repository.usePasswordReauthPrompt((_) async => null);
      await expectLater(
        repository.confirmRecentAuth(ReauthPurpose.accountDeletion),
        throwsA(
          isA<Failure>().having(
            (f) => f.code,
            'code',
            Failure.recentSignInCode,
          ),
        ),
      );
      expect(server.passwordSignIns, isEmpty);
      expect(server.reauthBearers, hasLength(1));
    });

    test('a wrong password says so and grants nothing', () async {
      repository.usePasswordReauthPrompt((_) async => 'wrong');
      server.passwordAnswer = 'wrong';
      await expectLater(
        repository.confirmRecentAuth(ReauthPurpose.accountDeletion),
        throwsA(
          isA<Failure>()
              .having((f) => f.code, 'code', Failure.recentSignInCode)
              .having(
                (f) => f.message,
                'message',
                'That password is not right. Try again.',
              ),
        ),
      );
      expect(server.reauthBearers, hasLength(1));
    });

    test('without a prompt, it asks the person to sign in again', () async {
      await expectLater(
        repository.confirmRecentAuth(ReauthPurpose.accountDeletion),
        throwsA(
          isA<Failure>().having(
            (f) => f.message,
            'message',
            contains('sign out and sign in again'),
          ),
        ),
      );
      expect(server.passwordSignIns, isEmpty);
    });
  });

  group('which accounts are password accounts', () {
    User user(Map<String, dynamic> app, String email) => User(
      id: 'u',
      appMetadata: app,
      userMetadata: const {},
      aud: 'authenticated',
      createdAt: '2026-10-15T00:00:00Z',
      email: email,
    );

    test('a provisioned email account is', () {
      expect(
        isPasswordAccount(
          user({'provider': 'email'}, 'student@review.studafy.com'),
        ),
        isTrue,
      );
    });

    test('a managed child, also an email identity, is not', () {
      expect(
        isPasswordAccount(
          user({
            'provider': 'email',
            'studafy_managed_by': 'parent-1',
          }, 'child-1@managed.studafy.invalid'),
        ),
        isFalse,
      );
      expect(
        isPasswordAccount(
          user({'provider': 'email'}, 'child-1@managed.studafy.invalid'),
        ),
        isFalse,
      );
    });

    test('an OAuth account is not', () {
      expect(
        isPasswordAccount(user({'provider': 'google'}, 'a@gmail.com')),
        isFalse,
      );
    });
  });

  group('what a failed password sign-in means', () {
    test('maps the auth client errors', () {
      expect(
        passwordSignInErrorFor(
          const AuthApiException(
            'Invalid login credentials',
            statusCode: '400',
            code: 'invalid_credentials',
          ),
        ),
        PasswordSignInError.invalidCredentials,
      );
      expect(
        passwordSignInErrorFor(
          const AuthApiException('slow down', statusCode: '429'),
        ),
        PasswordSignInError.tooManyAttempts,
      );
      expect(
        passwordSignInErrorFor(AuthRetryableFetchException()),
        PasswordSignInError.network,
      );
      expect(
        passwordSignInErrorFor(AuthRetryableFetchException(statusCode: '503')),
        PasswordSignInError.unavailable,
      );
      expect(
        passwordSignInErrorFor(
          const AuthApiException(
            'Email logins are disabled',
            statusCode: '422',
            code: 'email_provider_disabled',
          ),
        ),
        PasswordSignInError.unavailable,
      );
      expect(
        passwordSignInErrorFor(const SocketException('down')),
        PasswordSignInError.network,
      );
      expect(passwordSignInErrorFor(StateError('x')), isNotNull);
    });
  });
}

/// Supabase Auth's password grant and the API's re-authentication route,
/// answered from memory on a loopback port.
class _StandIn {
  _StandIn._(this._server);

  static const reviewer = '00000000-0000-4000-8000-00000000a001';

  final HttpServer _server;
  String get url => 'http://127.0.0.1:${_server.port}';

  /// 'ok', 'wrong' (400 invalid_credentials) or 'limited' (429).
  String passwordAnswer = 'ok';
  bool refuseFirstReauth = false;
  final passwordSignIns = <Map<String, Object?>>[];
  final reauthBearers = <String>[];
  final reauthPurposes = <String>[];
  var _issued = 0;
  var _closed = false;

  static Future<_StandIn> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final standIn = _StandIn._(server);
    server.listen(standIn._handle);
    return standIn;
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _server.close(force: true);
  }

  Future<void> _handle(HttpRequest request) async {
    final body = await utf8.decoder.bind(request).join();
    final json = body.isEmpty
        ? const <String, Object?>{}
        : jsonDecode(body) as Map<String, Object?>;
    final response = request.response..headers.contentType = ContentType.json;
    final path = request.uri.path;
    if (path == '/auth/v1/token' &&
        request.uri.queryParameters['grant_type'] == 'password') {
      passwordSignIns.add({
        'email': json['email'],
        'password': json['password'],
      });
      switch (passwordAnswer) {
        case 'wrong':
          response.statusCode = 400;
          response.write(
            jsonEncode({
              'code': 400,
              'error_code': 'invalid_credentials',
              'msg': 'Invalid login credentials',
            }),
          );
        case 'limited':
          response.statusCode = 429;
          response.write(
            jsonEncode({
              'code': 429,
              'error_code': 'over_request_rate_limit',
              'msg': 'Request rate limit reached',
            }),
          );
        default:
          response.write(jsonEncode(_session(json['email'] as String)));
      }
    } else if (path == '/v1/auth/reauth/verify') {
      reauthBearers.add(
        (request.headers.value('authorization') ?? '').replaceFirst(
          'Bearer ',
          '',
        ),
      );
      reauthPurposes.add(json['purpose'] as String);
      if (refuseFirstReauth && reauthBearers.length == 1) {
        response.statusCode = 403;
        response.write(
          jsonEncode({
            'type': 'about:blank',
            'title': 'Forbidden',
            'status': 403,
            'code': 'RECENT_SIGN_IN_REQUIRED',
            'detail': 'Sign in again.',
            'requestId': 'req-1',
          }),
        );
      } else {
        response.write(
          jsonEncode({
            'purpose': json['purpose'],
            'grant': 'grant-${reauthBearers.length}',
            'expiresAt': DateTime.now()
                .toUtc()
                .add(const Duration(minutes: 5))
                .toIso8601String(),
          }),
        );
      }
    } else {
      response.statusCode = 404;
      response.write('{}');
    }
    await response.close();
  }

  Map<String, Object?> _session(String email) {
    _issued += 1;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    String part(Object value) =>
        base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
    final token = [
      part({'alg': 'HS256', 'typ': 'JWT'}),
      part({
        'sub': reviewer,
        'exp': now + 3600,
        'iat': now,
        'session_id': 'session-$_issued',
        'amr': [
          {'method': 'password', 'timestamp': now},
        ],
      }),
      'signature',
    ].join('.');
    return {
      'access_token': token,
      'token_type': 'bearer',
      'expires_in': 3600,
      'expires_at': now + 3600,
      'refresh_token': 'refresh-$_issued',
      'user': {
        'id': reviewer,
        'aud': 'authenticated',
        'role': 'authenticated',
        'email': email,
        'app_metadata': {
          'provider': 'email',
          'providers': ['email'],
        },
        'user_metadata': <String, Object?>{},
        'created_at': '2026-10-15T00:00:00Z',
      },
    };
  }
}
