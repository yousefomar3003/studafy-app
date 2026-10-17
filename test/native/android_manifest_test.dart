import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/core/class_join_link.dart';

/// The release manifest is the main one: Flutter's debug and profile
/// manifests add INTERNET for development only, so without it here a store
/// build could not reach the server (launch plan 3.2).
void main() {
  final manifest = File('android/app/src/main/AndroidManifest.xml')
      .readAsStringSync();

  test('a release build may use the network', () {
    expect(
      manifest,
      contains('<uses-permission android:name="android.permission.INTERNET"/>'),
    );
  });

  test('the app is called Studafy under its icon (DL-029)', () {
    expect(manifest, contains('android:label="Studafy"'));
  });

  // iOS opens every io.studafy.app link (CFBundleURLSchemes); Android only
  // the hosts its intent filters list.
  test('a tapped class join link opens the app, as on iOS (JOIN-052)', () {
    expect(
      manifest,
      contains(
        '<data android:scheme="$classJoinLinkScheme" '
        'android:host="$classJoinLinkHost"/>',
      ),
    );
  });

  test('the sign-in callbacks open the app (AUTH-030)', () {
    expect(
      manifest,
      contains(
        '<data android:scheme="io.studafy.app" android:host="login-callback"/>',
      ),
    );
    expect(manifest, contains('android:host="app.studafy.com"'));
    expect(manifest, contains('android:pathPrefix="/auth/callback"'));
  });

  test('downloaded attachments can be handed to a viewer app', () {
    expect(
      manifest,
      contains(r'android:authorities="${applicationId}.attachments"'),
    );
    final paths = File('android/app/src/main/res/xml/attachment_paths.xml')
        .readAsStringSync();
    expect(
      paths,
      contains('<cache-path name="attachments" path="attachments/" />'),
    );
    final activity = File(
      'android/app/src/main/kotlin/com/studafy/light/MainActivity.kt',
    ).readAsStringSync();
    expect(activity, contains('"com.studafy.light/attachments"'));
    expect(activity, contains(r'"$packageName.attachments"'));
  });

  test('push uses a status bar icon Android can draw', () {
    expect(
      manifest,
      contains('com.google.firebase.messaging.default_notification_icon'),
    );
    for (final density in ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi']) {
      expect(
        File('android/app/src/main/res/drawable-$density/ic_notification.png')
            .existsSync(),
        isTrue,
        reason: density,
      );
    }
  });

  test('no plain HTTP in a release build', () {
    expect(manifest, isNot(contains('usesCleartextTraffic="true"')));
    expect(manifest, isNot(contains('networkSecurityConfig')));
  });
}
