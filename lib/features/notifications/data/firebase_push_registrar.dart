import 'dart:async';
import 'dart:io' show Platform, SocketException;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../../../core/failures.dart';
import '../../../core/telemetry.dart';
import '../../../data/contracts/v1_client.generated.dart';
import '../../../data/contracts/v1_http_transport.dart';
import '../domain/notification_taps.dart';
import '../domain/push_registrar.dart';

/// Push through Firebase Cloud Messaging, which relays to Apple's service on
/// iPhone. The server keeps the token against the signed-in account and
/// drops it when Firebase says it is dead.
///
/// On when the build carries Firebase's config, off without it
/// ([pushEnabledFor]). The config comes from one of two places
/// (docs/deployment/push-notifications.md):
///
/// * the `FIREBASE_*` dart-defines below, which need no change to the
///   native projects and turn push on by themselves; or
/// * the native files (android/app/google-services.json, and
///   ios/Runner/GoogleService-Info.plist added to the Runner target), which
///   the app cannot see from Dart, so they also need `PUSH_ENABLED=true`.
///
/// `PUSH_ENABLED=false` keeps push off whatever is configured. A build
/// without any of it starts normally and only skips push; in-app
/// notifications are unaffected. Any Firebase failure is swallowed the same
/// way, so a wrong config can never stop the app; it is counted in telemetry
/// (`push_registration_failed` with a coarse code, never the token).
///
/// Both are the app's public Firebase identifiers, not secrets. The server's
/// service-account key never comes near the app: it lives only in the
/// worker's FCM_SERVICE_ACCOUNT_JSON.
///
/// It also hands taps on a notification to [NotificationTaps]: the one that
/// started the app, and any while it runs. They are read once someone is
/// signed in, because a push carries only the in-app notification's id and
/// the app looks it up as the signed-in account.
class FirebasePushRegistrar implements PushRegistrar {
  /// [messaging] and [openedApp] stand in for Firebase in tests.
  FirebasePushRegistrar(
    this._client, {
    this._telemetry = const NoopTelemetry(),
    this._taps,
    Future<FirebaseMessaging?> Function()? messaging,
    Stream<RemoteMessage> Function()? openedApp,
  }) : _messagingOverride = messaging,
       _openedApp = openedApp ?? (() => FirebaseMessaging.onMessageOpenedApp);

  final V1ApiClient _client;
  final Telemetry _telemetry;
  final NotificationTaps? _taps;
  final Future<FirebaseMessaging?> Function()? _messagingOverride;
  final Stream<RemoteMessage> Function() _openedApp;

  static final enabled = pushEnabledFor(
    pushEnabled: const String.fromEnvironment('PUSH_ENABLED'),
    hasFirebaseDefines: firebaseOptionsFromDefines() != null,
  );

  String? _token;
  StreamSubscription<String>? _refresh;

  /// Taps, for the app's whole life: a tap after sign-out is held for
  /// whoever signs in next, so this is never cancelled.
  // ignore: cancel_subscriptions
  StreamSubscription<RemoteMessage>? _opened;

  Future<FirebaseMessaging?> _messaging() async {
    final override = _messagingOverride;
    if (override != null) return override();
    if (!enabled) return null;
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: firebaseOptionsFromDefines());
    }
    return FirebaseMessaging.instance;
  }

  static String get _platform => Platform.isIOS ? 'ios' : 'android';

  @override
  Future<void> register() async {
    try {
      final messaging = await _messaging();
      if (messaging == null) return;
      await _listenForTaps(messaging);
      final settings = await messaging.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        _telemetry.event('push_permission_denied');
        return;
      }
      // Shown while the app is open too, like any other app's. iOS only:
      // Android shows no banner for a push that arrives while Studafy is
      // open; it is in the in-app notifications list.
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
      // iOS hands Firebase its Apple token asynchronously after permission.
      if (Platform.isIOS) {
        for (var i = 0; i < 10 && await messaging.getAPNSToken() == null; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 500));
        }
      }
      final token = await messaging.getToken();
      if (token == null) {
        _failed('token_unavailable');
        return;
      }
      await _send(token);
      _refresh ??= messaging.onTokenRefresh.listen((next) {
        unawaited(
          _send(next).catchError((Object error) {
            _failed(pushFailureCode(error));
          }),
        );
      });
    } on Object catch (error) {
      // No push on this phone; in-app notifications are unaffected.
      _failed(pushFailureCode(error));
    }
  }

  Future<void> _send(String token) async {
    await _client.registerPushDevice(
      V1RegisterPushDeviceRequestDto(platform: _platform, token: token),
    );
    _token = token;
    _telemetry.event('push_registered');
  }

  /// Only the coarse code: never the token, the error's text or the account.
  void _failed(String code) =>
      _telemetry.event('push_registration_failed', {'code': code});

  /// Starts passing taps on to [NotificationTaps], once for the app's life:
  /// the tap that launched the app, if one did, and every later one.
  Future<void> _listenForTaps(FirebaseMessaging messaging) async {
    final taps = _taps;
    if (taps == null || _opened != null) return;
    _opened = _openedApp().listen(
      (message) => taps.tapped(_notificationId(message)),
      onError: (Object _) {},
    );
    try {
      final initial = await messaging.getInitialMessage();
      if (initial != null) taps.tapped(_notificationId(initial));
    } on Object {
      // A launch tap that cannot be read opens nothing; the app still starts.
    }
  }

  static String? _notificationId(RemoteMessage message) {
    final id = message.data['notificationId'];
    return id is String ? id : null;
  }

  @override
  Future<void> unregister() async {
    await _refresh?.cancel();
    _refresh = null;
    final token = _token;
    if (token == null) return;
    try {
      await _client.unregisterPushDevice(
        V1UnregisterPushDeviceRequestDto(token: token),
      );
    } on Object {
      // The server also drops tokens Firebase reports dead.
    }
    _token = null;
  }
}

/// Why registering for push failed, as one coarse code for telemetry:
/// `permission_denied`, `token_unavailable`, `apns_missing`,
/// `server_refused`, `network` or `unknown`. Never the error's own text,
/// which can carry the token or a device detail.
String pushFailureCode(Object error) {
  if (error is V1ApiException) return 'server_refused';
  if (error is FirebaseException) {
    final code = error.code.toLowerCase();
    final message = (error.message ?? '').toUpperCase();
    if (code.contains('apns') || message.contains('APNS')) {
      return 'apns_missing';
    }
    if (code.contains('permission')) return 'permission_denied';
    if (code.contains('network') ||
        code == 'unavailable' ||
        message.contains('SERVICE_NOT_AVAILABLE') ||
        message.contains('TIMEOUT')) {
      return 'network';
    }
    return 'unknown';
  }
  if (error is SocketException || error is TimeoutException) return 'network';
  if (Failure.fromError(error).code == Failure.networkCode) return 'network';
  return 'unknown';
}

/// Firebase app config from `--dart-define`s, or null to use the native
/// config files. FIREBASE_PROJECT_ID, FIREBASE_MESSAGING_SENDER_ID and the
/// platform's API key and app id must all be set; a partial set is ignored
/// rather than half-configuring Firebase.
FirebaseOptions? firebaseOptionsFromDefines() {
  const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  const senderId = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
  const iosBundleId = String.fromEnvironment('FIREBASE_IOS_BUNDLE_ID');
  final (apiKey, appId) = Platform.isIOS
      ? (
          const String.fromEnvironment('FIREBASE_IOS_API_KEY'),
          const String.fromEnvironment('FIREBASE_IOS_APP_ID'),
        )
      : (
          const String.fromEnvironment('FIREBASE_ANDROID_API_KEY'),
          const String.fromEnvironment('FIREBASE_ANDROID_APP_ID'),
        );
  if ([projectId, senderId, apiKey, appId].any((value) => value.isEmpty)) {
    return null;
  }
  return FirebaseOptions(
    apiKey: apiKey,
    appId: appId,
    messagingSenderId: senderId,
    projectId: projectId,
    iosBundleId: Platform.isIOS && iosBundleId.isNotEmpty ? iosBundleId : null,
  );
}

/// Whether push runs: `PUSH_ENABLED=true` always (native config files),
/// `PUSH_ENABLED=false` never, and unset only when the `FIREBASE_*`
/// defines are complete for this platform, so adding them to the release
/// defines is the whole switch.
bool pushEnabledFor({
  required String pushEnabled,
  required bool hasFirebaseDefines,
}) => switch (pushEnabled) {
  'true' => true,
  'false' => false,
  _ => hasFirebaseDefines,
};
