import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Presses the Android back button: the engine's `popRoute`, delivered the
/// way the platform delivers it, so every `PopScope` runs as in the app.
Future<void> systemBack(WidgetTester tester) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/navigation',
    const JSONMethodCodec().encodeMethodCall(const MethodCall('popRoute')),
    (_) {},
  );
  await tester.pumpAndSettle();
}

/// Counts the times the app asked the platform to close it - what back
/// does when nothing in the app is left to pop.
class AppExits {
  AppExits(WidgetTester tester) {
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'SystemNavigator.pop') count++;
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );
  }

  int count = 0;
}
