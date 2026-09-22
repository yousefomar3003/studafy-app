import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import '../../core/failures.dart';
import 'v1_client.generated.dart';

/// Raised when the API refuses a request. [code] is the stable machine code
/// from the error envelope; the message is safe to show but deliberately
/// uninformative about why authentication failed.
class V1ApiException implements Exception, FailureConvertible {
  const V1ApiException({
    required this.status,
    required this.code,
    required this.message,
    this.requestId,
  });

  final int status;
  final String code;
  final String message;
  final String? requestId;

  bool get isUnauthenticated => code == 'UNAUTHENTICATED';
  bool get isReauthRequired => code == 'REAUTH_REQUIRED';
  bool get isMfaRequired => code == 'MFA_REQUIRED';

  /// Places the refusal in the shared taxonomy.
  ///
  /// Without this every refusal reached the user as `UNKNOWN`, which named
  /// neither the cause nor the fix. The envelope's own message is not shown:
  /// it describes the request, while the taxonomy speaks to the person.
  @override
  Failure get failure => switch (status) {
    401 => Failure.unauthorized,
    403 => Failure.forbidden,
    404 => Failure.notFound,
    // A refused request is the client's to correct, so it is reported as
    // such rather than as an unexplained error.
    400 || 409 || 413 || 415 || 422 => const Failure.validation(
      'Studafy could not complete that request. Please check the details '
      'and try again.',
    ),
    429 || 503 || 504 => Failure.network,
    _ => Failure.unknown,
  };

  @override
  String toString() => 'V1ApiException($status $code)';
}

/// Supplies the current access token, or null when signed out.
typedef AccessTokenReader = Future<String?> Function();

/// Attempts a refresh, returning true when a new token is available.
typedef SessionRefresher = Future<bool> Function();

/// Called when the session is definitively gone and the UI must say so.
typedef SessionLostCallback = void Function();

/// HTTP transport for the generated `/v1` client (AUTH-030).
///
/// On a 401 it refreshes once and retries once. If that retry also fails the
/// session is reported lost — there is no third attempt and no silent
/// downgrade, because a client that keeps retrying an unauthenticated request
/// looks broken rather than signed out.
class V1HttpTransport implements V1JsonTransport {
  V1HttpTransport({
    required Uri baseUri,
    required AccessTokenReader accessToken,
    required SessionRefresher refreshSession,
    required this.onSessionLost,
    HttpClient? client,
    this.deviceId,
    Duration timeout = const Duration(seconds: 20),
  }) // Not initializing formals: the fields are private, and `this._baseUri`
    // would put the underscored spelling in every call site.
    // ignore_for_file: prefer_initializing_formals
    : _baseUri = baseUri,
       _accessToken = accessToken,
       _refreshSession = refreshSession,
       _timeout = timeout,
       _client = client ?? HttpClient();

  final Uri _baseUri;
  final AccessTokenReader _accessToken;
  final SessionRefresher _refreshSession;
  final SessionLostCallback onSessionLost;
  final HttpClient _client;
  final Duration _timeout;

  /// Opaque per-installation identifier, hashed server-side. Never a hardware
  /// identifier: those are stable across uninstall and across apps.
  final String? deviceId;

  /// Set for the next privileged request only, then cleared.
  String? _pendingReauthGrant;

  /// Presents [grant] on the next request and forgets it afterwards, so a
  /// single-use grant cannot be accidentally replayed by a later call.
  void useReauthGrant(String grant) => _pendingReauthGrant = grant;

  @override
  Future<Map<String, dynamic>> get(String path) => _send('GET', path, null);

  @override
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, Object?> body, {
    String? idempotencyKey,
    bool requiresIdempotency = false,
  }) => _send(
    'POST',
    path,
    body,
    idempotencyKey: requiresIdempotency
        ? idempotencyKey ?? _newIdempotencyKey()
        : idempotencyKey,
  );

  Future<Map<String, dynamic>> _send(
    String method,
    String path,
    Map<String, Object?>? body, {
    String? idempotencyKey,
  }) async {
    final grant = _pendingReauthGrant;
    _pendingReauthGrant = null;

    var response = await _attempt(method, path, body, grant, idempotencyKey);
    if (response.status == 401) {
      final refreshed = await _refreshSession();
      if (!refreshed) {
        onSessionLost();
        throw _exceptionFrom(response);
      }
      response = await _attempt(method, path, body, grant, idempotencyKey);
      if (response.status == 401) {
        onSessionLost();
        throw _exceptionFrom(response);
      }
    }
    if (response.status >= 400) throw _exceptionFrom(response);
    return response.body;
  }

  Future<_RawResponse> _attempt(
    String method,
    String path,
    Map<String, Object?>? body,
    String? reauthGrant,
    String? idempotencyKey,
  ) async {
    try {
      return await _exchange(method, path, body, reauthGrant, idempotencyKey);
    } on SocketException {
      throw Failure.network;
    } on TimeoutException {
      throw Failure.network;
    } on HttpException {
      throw Failure.network;
    }
  }

  /// Performs one request/response exchange. A transport-level failure here
  /// means the school system was unreachable, which [_attempt] reports as
  /// such rather than letting it surface as an unexplained error.
  Future<_RawResponse> _exchange(
    String method,
    String path,
    Map<String, Object?>? body,
    String? reauthGrant,
    String? idempotencyKey,
  ) async {
    final request = await _client
        .openUrl(method, _baseUri.resolve(path))
        .timeout(_timeout);
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');

    final token = await _accessToken();
    if (token != null) {
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    }
    if (deviceId != null) {
      request.headers.set('X-Studafy-Device', deviceId!);
    }
    if (reauthGrant != null) {
      request.headers.set('X-Studafy-Reauth', reauthGrant);
    }
    if (idempotencyKey != null) {
      request.headers.set('Idempotency-Key', idempotencyKey);
    }
    if (body != null) {
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(body));
    }

    final response = await request.close().timeout(_timeout);
    final text = await response.transform(utf8.decoder).join();
    Map<String, dynamic> decoded;
    try {
      final parsed = text.isEmpty
          ? const <String, dynamic>{}
          : jsonDecode(text);
      decoded = parsed is Map<String, dynamic> ? parsed : <String, dynamic>{};
    } catch (_) {
      decoded = <String, dynamic>{};
    }
    return _RawResponse(response.statusCode, decoded);
  }

  V1ApiException _exceptionFrom(_RawResponse response) {
    if (response.body['code'] is String) {
      return V1ApiException(
        status: response.status,
        code: response.body['code'] as String? ?? 'INTERNAL_ERROR',
        message: response.body['detail'] as String? ?? 'The request failed.',
        requestId: response.body['requestId'] as String?,
      );
    }
    return V1ApiException(
      status: response.status,
      code: 'INTERNAL_ERROR',
      message: 'The request failed.',
    );
  }

  void close() => _client.close(force: true);

  static String _newIdempotencyKey() {
    final random = Random.secure();
    const alphabet =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_';
    return List.generate(
      32,
      (_) => alphabet[random.nextInt(alphabet.length)],
    ).join();
  }
}

class _RawResponse {
  const _RawResponse(this.status, this.body);
  final int status;
  final Map<String, dynamic> body;
}
