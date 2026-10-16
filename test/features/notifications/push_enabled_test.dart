import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/features/notifications/data/firebase_push_registrar.dart';

void main() {
  test('push turns on by itself once the Firebase defines are given', () {
    expect(pushEnabledFor(pushEnabled: '', hasFirebaseDefines: true), isTrue);
    expect(pushEnabledFor(pushEnabled: '', hasFirebaseDefines: false), isFalse);
  });

  test('PUSH_ENABLED decides when it is given', () {
    // true: the native config files, which Dart cannot see.
    expect(
      pushEnabledFor(pushEnabled: 'true', hasFirebaseDefines: false),
      isTrue,
    );
    expect(
      pushEnabledFor(pushEnabled: 'false', hasFirebaseDefines: true),
      isFalse,
    );
  });

  test('a test build has no Firebase config, so push stays off', () {
    expect(firebaseOptionsFromDefines(), isNull);
    expect(FirebasePushRegistrar.enabled, isFalse);
  });
}
