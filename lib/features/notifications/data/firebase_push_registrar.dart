import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../../../data/contracts/v1_client.generated.dart';
import '../domain/push_registrar.dart';

/// Push through Firebase Cloud Messaging, which relays to Apple's service on
/// iPhone. The server keeps the token against the signed-in account and
/// drops it when Firebase says it is dead.
///
/// Off unless the build says `PUSH_ENABLED=true`. Firebase's app config then
/// comes from one of two places (docs/deployment/push-notifications.md):
///
/// * the `FIREBASE_*` dart-defines below, which need no change to the
///   native projects; or
/// * the native files (android/app/google-services.json, and
///   ios/Runner/GoogleService-Info.plist added to the Runner target).
///
/// Both are the app's public Firebase identifiers, not secrets. The server's
/// service-account key never comes near the app: it lives only in the
/// worker's FCM_SERVICE_ACCOUNT_JSON.
class FirebasePushRegistrar implements PushRegistrar {
  FirebasePushRegistrar(this._client);

  final V1ApiClient _client;

  static const enabled = bool.fromEnvironment('PUSH_ENABLED');

  String? _token;
  StreamSubscription<String>? _refresh;

  Future<FirebaseMessaging?> _messaging() async {
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
      final settings = await messaging.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;
      // Shown while the app is open too, like any other app's.
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
      if (token == null) return;
      await _send(token);
      _refresh ??= messaging.onTokenRefresh.listen((next) {
        unawaited(_send(next).catchError((Object _) {}));
      });
    } on Object {
      // No push on this phone; in-app notifications are unaffected.
    }
  }

  Future<void> _send(String token) async {
    await _client.registerPushDevice(
      V1RegisterPushDeviceRequestDto(platform: _platform, token: token),
    );
    _token = token;
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
