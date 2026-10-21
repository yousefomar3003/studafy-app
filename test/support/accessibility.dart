import 'package:flutter_test/flutter_test.dart';

/// The accessibility checks every main screen must pass (launch plan 7.1):
/// tap targets big enough on Android (48 dp) and iOS (44 pt), every tappable
/// thing labelled for screen readers, and text with enough contrast.
///
/// Call `tester.ensureSemantics()` before pumping, and dispose the handle.
///
/// [contrast] false skips only the contrast check, for a screen whose
/// colours are checked in another language: the contrast check samples the
/// rendered pixels, and the Linux test font draws some Arabic words so thin
/// that it measures the background instead of the text.
Future<void> expectAccessible(
  WidgetTester tester, {
  bool contrast = true,
}) async {
  await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  if (contrast) {
    await expectLater(tester, meetsGuideline(textContrastGuideline));
  }
}
