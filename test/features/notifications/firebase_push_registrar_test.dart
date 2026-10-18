import 'dart:async';
import 'dart:io' show SocketException;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/core/failures.dart';
import 'package:studafy/core/telemetry.dart';
import 'package:studafy/data/contracts/v1_client.generated.dart';
import 'package:studafy/data/contracts/v1_http_transport.dart';
import 'package:studafy/features/notifications/data/firebase_push_registrar.dart';
import 'package:studafy/features/notifications/domain/notification_taps.dart';

/// Push registration is counted, never silent, and never carries the
/// token; and a tap on a push is handed on for the signed-in shell to open.
void main() {
  const token = 'fcm-token-that-must-never-be-logged-0123456789';

  ({FirebasePushRegistrar registrar, _Telemetry telemetry, _Transport server})
  build(
    _Messaging messaging, {
    NotificationTaps? taps,
    Stream<RemoteMessage>? opened,
    Object? serverError,
  }) {
    final telemetry = _Telemetry();
    final server = _Transport(serverError);
    final registrar = FirebasePushRegistrar(
      V1ApiClient(server),
      telemetry: telemetry,
      taps: taps,
      messaging: () async => messaging,
      openedApp: () => opened ?? const Stream.empty(),
    );
    return (registrar: registrar, telemetry: telemetry, server: server);
  }

  test('a registered phone is counted, without its token', () async {
    final run = build(_Messaging(token: token));
    await run.registrar.register();

    expect(run.server.registered, [token]);
    expect(run.telemetry.names, ['push_registered']);
    expect(run.telemetry.toString(), isNot(contains(token)));
  });

  test('a person who says no is counted, and nothing is sent', () async {
    final run = build(
      _Messaging(token: token, status: AuthorizationStatus.denied),
    );
    await run.registrar.register();

    expect(run.server.registered, isEmpty);
    expect(run.telemetry.names, ['push_permission_denied']);
  });

  test('no token from Firebase is a failure with its own code', () async {
    final run = build(_Messaging(token: null));
    await run.registrar.register();

    expect(run.telemetry.events, [
      'push_registration_failed {code: token_unavailable}',
    ]);
  });

  test('a refusal from the server is counted, and never throws', () async {
    final run = build(
      _Messaging(token: token),
      serverError: const V1ApiException(
        status: 409,
        code: 'CONFLICT',
        message: 'refused $token',
      ),
    );
    await run.registrar.register();

    expect(run.telemetry.events, [
      'push_registration_failed {code: server_refused}',
    ]);
    expect(run.telemetry.toString(), isNot(contains(token)));
  });

  test('a Firebase failure is counted by a coarse code only', () async {
    final run = build(
      _Messaging(
        tokenError: FirebaseException(
          plugin: 'firebase_messaging',
          code: 'unknown',
          message: 'java.io.IOException: SERVICE_NOT_AVAILABLE $token',
        ),
      ),
    );
    await run.registrar.register();

    expect(run.telemetry.events, ['push_registration_failed {code: network}']);
    expect(run.telemetry.toString(), isNot(contains('SERVICE_NOT_AVAILABLE')));
  });

  test('a failed re-registration after a token rotation is counted', () async {
    final messaging = _Messaging(token: token);
    final run = build(messaging);
    await run.registrar.register();
    run.server.error = Failure.network;

    messaging.refresh.add('rotated-token-0123456789-0123456789');
    await pumpEventQueue();

    expect(run.telemetry.events, [
      'push_registered',
      'push_registration_failed {code: network}',
    ]);
  });

  test('errors map to the coarse codes', () {
    FirebaseException firebase(String code, [String? message]) =>
        FirebaseException(plugin: 'p', code: code, message: message);
    expect(pushFailureCode(firebase('apns-token-not-set')), 'apns_missing');
    expect(
      pushFailureCode(firebase('permission-blocked')),
      'permission_denied',
    );
    expect(pushFailureCode(firebase('unknown', 'TIMEOUT')), 'network');
    expect(pushFailureCode(firebase('unknown', 'boom')), 'unknown');
    expect(
      pushFailureCode(
        const V1ApiException(status: 500, code: 'X', message: 'x'),
      ),
      'server_refused',
    );
    expect(pushFailureCode(Failure.network), 'network');
    expect(pushFailureCode(const SocketException('down')), 'network');
    expect(pushFailureCode(TimeoutException('slow')), 'network');
    expect(pushFailureCode(StateError('x')), 'unknown');
  });

  test('the tap that launched the app and later taps are handed on', () async {
    final taps = NotificationTaps();
    final opened = StreamController<RemoteMessage>();
    addTearDown(opened.close);
    final messaging = _Messaging(
      token: token,
      initial: const RemoteMessage(data: {'notificationId': '41'}),
    );
    final run = build(messaging, taps: taps, opened: opened.stream);

    await run.registrar.register();
    expect(taps.consume()?.notificationId, '41');

    opened.add(const RemoteMessage(data: {'notificationId': '42'}));
    await pumpEventQueue();
    expect(taps.consume()?.notificationId, '42');

    // A push from before pushes named their notification opens the list.
    opened.add(const RemoteMessage(data: {'templateKey': 'academic.x'}));
    await pumpEventQueue();
    final tap = taps.consume();
    expect(tap, isNotNull);
    expect(tap!.notificationId, isNull);

    // Registering again (another account signed in) reads the launch tap
    // only once.
    await run.registrar.register();
    expect(messaging.initialReads, 1);
    expect(taps.pending, isNull);
  });

  test('taps are handed on even when the person said no to push', () async {
    final taps = NotificationTaps();
    final run = build(
      _Messaging(
        token: token,
        status: AuthorizationStatus.denied,
        initial: const RemoteMessage(data: {'notificationId': '7'}),
      ),
      taps: taps,
    );
    await run.registrar.register();
    expect(taps.consume()?.notificationId, '7');
  });

  group('NotificationTaps', () {
    test('one tap opens one screen', () {
      final taps = NotificationTaps();
      var notified = 0;
      taps.addListener(() => notified++);
      taps.tapped('12');
      expect(notified, 1);
      expect(taps.consume()?.notificationId, '12');
      expect(taps.consume(), isNull);
    });

    test('anything but a plain id opens the list', () {
      final taps = NotificationTaps();
      for (final value in ['', '  ', '../x', 'a b', 'x' * 65, null]) {
        taps.tapped(value);
        expect(taps.consume()!.notificationId, isNull, reason: '$value');
      }
      taps.tapped('3f2a-19');
      expect(taps.consume()!.notificationId, '3f2a-19');
    });

    test('a deferred tap waits silently, and a newer tap wins', () {
      final taps = NotificationTaps();
      var notified = 0;
      taps.addListener(() => notified++);
      taps.defer(const NotificationTap('1'));
      expect(notified, 0);
      expect(taps.pending?.notificationId, '1');
      taps.tapped('2');
      taps.defer(const NotificationTap('1'));
      expect(taps.consume()?.notificationId, '2');
    });
  });
}

/// Records each event as `name` or `name {field: value}`.
class _Telemetry implements Telemetry {
  final events = <String>[];

  List<String> get names => [for (final line in events) line.split(' ').first];

  @override
  void event(String name, [Map<String, Object?> fields = const {}]) =>
      events.add(fields.isEmpty ? name : '$name $fields');

  @override
  String toString() => events.toString();
}

class _Transport implements V1JsonTransport {
  _Transport(this.error);

  Object? error;
  final registered = <String>[];

  @override
  Future<Map<String, dynamic>> get(String path) async => {};

  @override
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, Object?> body, {
    String? idempotencyKey,
    bool requiresIdempotency = false,
  }) async {
    final failure = error;
    if (failure != null) throw failure;
    registered.add(body['token']! as String);
    return {'registered': true};
  }
}

class _Messaging extends Fake implements FirebaseMessaging {
  _Messaging({
    this.token,
    this.tokenError,
    this.status = AuthorizationStatus.authorized,
    this.initial,
  });

  final String? token;
  final Object? tokenError;
  final AuthorizationStatus status;
  final RemoteMessage? initial;

  /// Lives as long as the fake, like Firebase's own stream.
  // ignore: close_sinks
  final refresh = StreamController<String>.broadcast();
  int initialReads = 0;

  @override
  Future<RemoteMessage?> getInitialMessage() async {
    initialReads++;
    return initial;
  }

  @override
  Future<NotificationSettings> requestPermission({
    bool alert = true,
    bool announcement = false,
    bool badge = true,
    bool carPlay = false,
    bool criticalAlert = false,
    bool provisional = false,
    bool sound = true,
    bool providesAppNotificationSettings = false,
  }) async => NotificationSettings(
    alert: AppleNotificationSetting.notSupported,
    announcement: AppleNotificationSetting.notSupported,
    authorizationStatus: status,
    badge: AppleNotificationSetting.notSupported,
    carPlay: AppleNotificationSetting.notSupported,
    lockScreen: AppleNotificationSetting.notSupported,
    notificationCenter: AppleNotificationSetting.notSupported,
    showPreviews: AppleShowPreviewSetting.notSupported,
    timeSensitive: AppleNotificationSetting.notSupported,
    criticalAlert: AppleNotificationSetting.notSupported,
    sound: AppleNotificationSetting.notSupported,
    providesAppNotificationSettings: AppleNotificationSetting.notSupported,
  );

  @override
  Future<void> setForegroundNotificationPresentationOptions({
    bool alert = false,
    bool badge = false,
    bool sound = false,
  }) async {}

  @override
  Future<String?> getToken({
    String? vapidKey,
    String? serviceWorkerScriptPath,
  }) async {
    final error = tokenError;
    if (error != null) throw error;
    return token;
  }

  @override
  Stream<String> get onTokenRefresh => refresh.stream;
}
