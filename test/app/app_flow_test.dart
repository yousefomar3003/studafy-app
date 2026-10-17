import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studafy/core/studafy_design.dart';
import 'package:studafy/features/session/presentation/splash_page.dart';
import 'package:studafy/main.dart';

void main() {
  testWidgets('splash transitions to role selection', (tester) async {
    // A fresh install: nothing stored on the device yet.
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const StudafyApp());
    await tester.pump();
    expect(find.byType(SplashPage), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    // A first launch opens on the welcome slides, which can be skipped.
    expect(find.text('Your whole school day in one place'), findsOneWidget);
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(find.text('How will you use Studafy?'), findsOneWidget);
    expect(find.text('Teacher'), findsOneWidget);
    expect(find.text('Student'), findsOneWidget);
    expect(find.text('Parent'), findsOneWidget);
    expect(find.text('School administrator'), findsNothing);
  });

  testWidgets('both wordmarks are loading from the first build, so the '
      'splash never shows its tagline alone', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const StudafyApp());
    final context = tester.element(find.byType(SplashPage));
    for (final asset in [studafyWordmarkOnDarkAsset, studafyWordmarkAsset]) {
      final key = await AssetImage(asset)
          .obtainKey(createLocalImageConfiguration(context));
      expect(imageCache.containsKey(key), isTrue, reason: asset);
    }
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
  });
}
