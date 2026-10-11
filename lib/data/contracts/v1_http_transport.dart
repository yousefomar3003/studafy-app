import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

import '../../core/failures.dart';
import '../../core/idempotency.dart' as ids;
import 'response_cache.dart';
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
    this.fieldErrors = const {},
  });

  final int status;
  final String code;
  final String message;
  final String? requestId;

  /// The problem's `errors`: which part of the request was refused (a path
  /// such as `students/<id>`) and a fixed reason code. A bulk command that
  /// refuses some rows names each one, so a screen can point at them.
  final Map<String, String> fieldErrors;

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
    Duration recentFor = const Duration(seconds: 20),
    DateTime Function() now = DateTime.now,
  }) // Not initializing formals: the fields are private, and `this._baseUri`
    // would put the underscored spelling in every call site.
    // ignore_for_file: prefer_initializing_formals
    : _baseUri = baseUri,
       _accessToken = accessToken,
       _refreshSession = refreshSession,
       _timeout = timeout,
       _recentFor = recentFor,
       _now = now,
       // Kept open longer than the 15s default, so a tap after a short pause
       // reuses the connection instead of paying a new TLS handshake. Still
       // under the 60s after which Fly's proxy drops an idle connection.
       _client = client ?? (HttpClient()..idleTimeout = idleConnectionTimeout);

  /// How long an unused connection to the API is kept for reuse.
  static const idleConnectionTimeout = Duration(seconds: 50);

  final Uri _baseUri;
  final AccessTokenReader _accessToken;
  final SessionRefresher _refreshSession;
  final SessionLostCallback onSessionLost;
  final HttpClient _client;
  final Duration _timeout;
  final Duration _recentFor;
  final DateTime Function() _now;

  /// Opaque per-installation identifier, hashed server-side. Never a hardware
  /// identifier: those are stable across uninstall and across apps.
  final String? deviceId;

  /// Set for the next privileged request only, then cleared.
  String? _pendingReauthGrant;

  /// Keeps answers on the device for when the server cannot be reached.
  /// Null keeps nothing (synthetic builds, tests).
  ResponseCache? responseCache;

  /// Reads that are never kept: sign-in and account authority, billing
  /// (always the store's current word), single-use file and export links,
  /// upload progress, a class's join link, and the safeguarding records
  /// (wellbeing, reports, content controls), which must not sit on a phone
  /// a family shares.
  static final _neverKept = RegExp(
    r'^/v1/(auth|billing|files|uploads|reports|wellbeing|control-panel)(/|\?|$)'
    r'|^/v1/me(\?|$)'
    r'|^/v1/account/export-'
    r'|/join-link(\?|$)',
  );

  /// Reads that are live - a chat polled for new messages and ticks, the
  /// inbox, notifications, study notebooks followed while they are written
  /// - are kept on the device like any other, but never reused from the
  /// last few seconds: a poll that got the previous answer back would show
  /// nothing new.
  static final _live = RegExp(
    r'^/v1/(conversations|notifications|study-notebooks)(/|\?|$)'
    r'|^/v1/classrooms/[^/?]+/study-notebooks(\?|$)',
  );

  /// Commands that only read something the server made once and keeps: a
  /// lesson's quiz or flashcards. Kept like a read.
  static final _keptCommands = RegExp(r'^/v1/resources/[^/?]+/study-set$');

  @visibleForTesting
  static bool keeps(String method, String path) => method == 'GET'
      ? !_neverKept.hasMatch(path)
      : _keptCommands.hasMatch(path);

  /// Network first. A good answer is kept; when the server cannot be
  /// reached (no connection, a timeout, 429/503/504) the kept answer is
  /// returned instead. Every other failure - a refusal, a lost session - is
  /// the server's word and is never covered up by a kept copy.
  Future<Map<String, dynamic>> _keeping(
    String key,
    Future<Map<String, dynamic>> Function() send,
  ) async {
    final cache = responseCache;
    if (cache == null) return send();
    try {
      final body = await send();
      // Not awaited: the screen has its answer now, and keeping a copy on the
      // device (encode, then a SQLite write) is no reason to make it wait.
      unawaited(_keep(cache, key, body));
      return body;
    } on Object catch (error) {
      if (Failure.fromError(error).code != Failure.networkCode) rethrow;
      Map<String, dynamic>? kept;
      try {
        kept = await cache.read(key);
      } on Object {
        kept = null;
      }
      if (kept == null) rethrow;
      return kept;
    }
  }

  Future<void> _keep(
    ResponseCache cache,
    String key,
    Map<String, dynamic> body,
  ) async {
    try {
      await cache.write(key, body);
    } on Object {
      // A full or closed cache never fails the request it would have kept.
    }
  }

  /// Presents [grant] on the next request and forgets it afterwards, so a
  /// single-use grant cannot be accidentally replayed by a later call.
  void useReauthGrant(String grant) => _pendingReauthGrant = grant;

  /// Reads already on their way, by who asked and what for.
  final Map<String, Future<Map<String, dynamic>>> _inFlight = {};

  /// Answers to kept reads from the last few seconds, by who asked and what
  /// for. See [get].
  final Map<String, ({DateTime at, Map<String, dynamic> body})> _recent = {};

  /// Bumped by every change sent and by [forgetRecentReads], so a read that
  /// was already on its way when something changed is not remembered.
  int _generation = 0;

  static const _recentLimit = 200;

  /// Drops every remembered answer, so the next read of anything goes to the
  /// server. A pull-to-refresh asks for this: the person wants it fresh.
  void forgetRecentReads() {
    _generation++;
    _recent.clear();
  }

  /// Anything sent may change what a read would answer, so nothing read
  /// before it is reused after it - not even a read still on its way.
  void _changing() {
    forgetRecentReads();
    _inFlight.clear();
  }

  /// A read already on its way is shared rather than sent again. Screens
  /// that open together, or a tap repeated while the first is still
  /// loading, would otherwise each cost the server a full request.
  ///
  /// A kept read answered in the last [_recentFor] is reused too, so tabs and
  /// screens that ask for the same thing (the classes, the study plan) and a
  /// screen opened again moments later are instant. Any change sent through
  /// [post] forgets them all, so what was just sent, submitted or saved is
  /// always read back fresh. The key carries the caller's token, so two
  /// accounts on one device never share an answer.
  @override
  Future<Map<String, dynamic>> get(String path) async {
    final token = await _accessToken();
    final key =
        '${token == null ? '' : sha256.convert(utf8.encode(token))}'
        ' $path';
    final pending = _inFlight[key];
    if (pending != null) return pending;
    final kept = keeps('GET', path);
    final remembered = kept && !_live.hasMatch(path);
    if (remembered) {
      final recent = _recent[key];
      if (recent != null && _now().difference(recent.at) < _recentFor) {
        return recent.body;
      }
    }
    final generation = _generation;
    final request = kept
        ? _keeping('GET $path', () => _send('GET', path, null))
        : _send('GET', path, null);
    _inFlight[key] = request;
    try {
      final body = await request;
      if (remembered && generation == _generation) _remember(key, body);
      return body;
    } finally {
      if (identical(_inFlight[key], request)) {
        unawaited(_inFlight.remove(key));
      }
    }
  }

  void _remember(String key, Map<String, dynamic> body) {
    final now = _now();
    if (_recent.length >= _recentLimit) {
      _recent.removeWhere((_, entry) => now.difference(entry.at) >= _recentFor);
      if (_recent.length >= _recentLimit) _recent.clear();
    }
    _recent[key] = (at: now, body: body);
  }

  @override
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, Object?> body, {
    String? idempotencyKey,
    bool requiresIdempotency = false,
  }) {
    Future<Map<String, dynamic>> send() => _send(
      'POST',
      path,
      body,
      idempotencyKey: requiresIdempotency
          ? idempotencyKey ?? newIdempotencyKey()
          : idempotencyKey,
    );
    if (keeps('POST', path)) {
      return _keeping('POST $path ${jsonEncode(body)}', send);
    }
    return _changed(send);
  }

  /// Sends a change, forgetting remembered reads both before it goes and
  /// once it lands: a read made while it was on its way may predate it.
  Future<Map<String, dynamic>> _changed(
    Future<Map<String, dynamic>> Function() send,
  ) async {
    _changing();
    try {
      return await send();
    } finally {
      _changing();
    }
  }

  Future<Map<String, dynamic>> _send(
    String method,
    String path,
    Map<String, Object?>? body, {
    String? idempotencyKey,
  }) async {
    final grant = _pendingReauthGrant;
    _pendingReauthGrant = null;

    var response = await _attemptReading(
      method,
      path,
      body,
      grant,
      idempotencyKey,
    );
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

  /// A read that fails to connect is tried once more straight away: a
  /// connection kept open for reuse can be closed by the server just as it
  /// is picked up, and a read is safe to repeat. A timeout is not retried -
  /// the person has already waited long enough. A change is never repeated
  /// here; its idempotency key lets the person retry it.
  Future<_RawResponse> _attemptReading(
    String method,
    String path,
    Map<String, Object?>? body,
    String? reauthGrant,
    String? idempotencyKey,
  ) async {
    // A single-use grant is never presented twice.
    if (method != 'GET' || reauthGrant != null) {
      return _attempt(method, path, body, reauthGrant, idempotencyKey);
    }
    try {
      return await _exchange(method, path, body, reauthGrant, idempotencyKey);
    } on SocketException {
      // Tried again below.
    } on HttpException {
      // Tried again below.
    } on TimeoutException {
      throw Failure.network;
    }
    return _attempt(method, path, body, reauthGrant, idempotencyKey);
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
    // The body has a deadline too: a response that starts and then stalls
    // would otherwise leave the screen spinning for good.
    final text = await response
        .timeout(_timeout)
        .transform(utf8.decoder)
        .join();
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

  /// Fetches file bytes from a delivery link the API issued (FILE-051).
  ///
  /// The link is single-use and bound to the signed-in person, so it has to
  /// carry the session - which is why this lives on the transport rather than
  /// being handed to a browser. The bearer token goes only to the API's own
  /// origin: a link that points anywhere else is refused before any request,
  /// so a tampered or misconfigured URL cannot collect the token.
  Future<Uint8List> getBytes(Uri url) async {
    if (url.scheme != _baseUri.scheme ||
        url.host != _baseUri.host ||
        url.port != _baseUri.port) {
      throw Failure.forbidden;
    }
    try {
      var (status, bytes) = await _bytesOnce(url);
      // A 401 is the sign-in check refusing an expired token, before the
      // link is looked at, so the link is still unspent: refresh once and
      // retry, as every other request does. Opening a file an hour after
      // signing in used to fail here every time. Any other refusal means
      // the link itself was spent or withdrawn, and only a new link helps.
      if (status == 401 && await _refreshSession()) {
        (status, bytes) = await _bytesOnce(url);
      }
      if (status == 401) throw Failure.unauthorized;
      if (status != 200) throw Failure.notFound;
      return bytes;
    } on SocketException {
      throw Failure.network;
    } on TimeoutException {
      throw Failure.network;
    } on HttpException {
      throw Failure.network;
    }
  }

  /// One authenticated GET of a delivery link: its status and its bytes.
  Future<(int, Uint8List)> _bytesOnce(Uri url) async {
    final request = await _client.getUrl(url).timeout(_timeout);
    request.followRedirects = false;
    final token = await _accessToken();
    if (token != null) {
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    }
    if (deviceId != null) {
      request.headers.set('X-Studafy-Device', deviceId!);
    }
    final response = await request.close().timeout(_timeout);
    final builder = BytesBuilder(copy: false);
    // A deadline on each pause rather than the whole file, so a large
    // file on a slow connection still arrives, and a stalled one fails.
    await for (final chunk in response.timeout(_timeout)) {
      builder.add(chunk);
    }
    return (response.statusCode, builder.takeBytes());
  }

  V1ApiException _exceptionFrom(_RawResponse response) {
    if (response.body['code'] is String) {
      return V1ApiException(
        status: response.status,
        code: response.body['code'] as String? ?? 'INTERNAL_ERROR',
        message: response.body['detail'] as String? ?? 'The request failed.',
        requestId: response.body['requestId'] as String?,
        fieldErrors: {
          for (final item
              in (response.body['errors'] as List<Object?>? ?? const []))
            if (item case {
              'path': final String path,
              'code': final String code,
            })
              path: code,
        },
      );
    }
    return V1ApiException(
      status: response.status,
      code: 'INTERNAL_ERROR',
      message: 'The request failed.',
    );
  }

  void close() => _client.close(force: true);

  /// A fresh key the server accepts: `^[A-Za-z0-9][A-Za-z0-9._:-]{15,127}$`.
  ///
  /// The first character must be a letter or digit. Drawing it from the full
  /// alphabet, as this did, started one key in 32 with `-` or `_`, and the
  /// server refused that request outright - an intermittent failure of any
  /// command that let the transport pick its key.
  @visibleForTesting
  static String newIdempotencyKey() => ids.newIdempotencyKey('request');
}

class _RawResponse {
  const _RawResponse(this.status, this.body);
  final int status;
  final Map<String, dynamic> body;
}
