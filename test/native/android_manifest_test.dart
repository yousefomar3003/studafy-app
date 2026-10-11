import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

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
}
