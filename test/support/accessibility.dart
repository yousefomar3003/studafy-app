import 'package:flutter_test/flutter_test.dart';

/// The accessibility checks every main screen must pass (launch plan 7.1):
/// tap targets big enough on Android (48 dp) and iOS (44 pt), every tappable
/// thing labelled for screen readers, and text with enough contrast.
///
/// Call `tester.ensureSemantics()` before pumping, and dispose the handle.
Future<void> expectAccessible(WidgetTester tester) async {
  await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  await expectLater(tester, meetsGuideline(textContrastGuideline));
}
