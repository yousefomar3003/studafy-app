import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/core/studafy_components.dart';
import 'package:studafy/core/studafy_design.dart';

import '../support/localized_app.dart';

void main() {
  group('initials', () {
    test('are the first two letters of the name', () {
      expect(profileInitials('Mr.ahmad'), 'MR');
      expect(profileInitials('Yousef Omar'), 'YO');
      expect(profileInitials('sara'), 'SA');
    });

    test('skip spaces, punctuation, digits and emoji', () {
      expect(profileInitials('   Yousef    Omar  '), 'YO');
      expect(profileInitials('12. Omar'), 'OM');
      expect(profileInitials('😀 Lina'), 'LI');
    });

    test('work for short names, empty names and other scripts', () {
      expect(profileInitials('A'), 'A');
      expect(profileInitials(''), '?');
      expect(profileInitials('  !! 42 '), '?');
      expect(profileInitials('محمد علي'), 'مح');
    });
  });

  testWidgets('the "+" says Create to screen readers and on long press', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      localizedApp(
        home: Scaffold(
          body: Center(
            child: StudafyCreateButton(
              label: 'Create',
              onPressed: () => taps++,
            ),
          ),
        ),
      ),
    );
    expect(find.bySemanticsLabel('Create'), findsOne);
    expect(find.byTooltip('Create'), findsOne);
    await tester.tap(find.byType(StudafyCreateButton));
    expect(taps, 1);
  });

  group('the floating navigation bar', () {
    Widget bar({
      required bool compact,
      required ValueChanged<int> onSelected,
    }) => localizedApp(
      home: Scaffold(
        bottomNavigationBar: StudafyNavigationBar(
          selectedIndex: 0,
          compact: compact,
          onSelected: onSelected,
          items: const [
            StudafyNavItem('Today', Icons.home_outlined, Icons.home),
            StudafyNavItem('Inbox', Icons.send_outlined, Icons.send),
          ],
        ),
      ),
    );

    testWidgets('shows labels, and every destination can be reached', (
      tester,
    ) async {
      final chosen = <int>[];
      await tester.pumpWidget(bar(compact: false, onSelected: chosen.add));
      expect(find.text('Today'), findsOne);
      expect(find.text('Inbox'), findsOne);
      await tester.tap(find.byType(StudafyNavDestination).last);
      expect(chosen, [1]);
    });

    testWidgets('compact hides the labels but keeps them for screen readers', (
      tester,
    ) async {
      final chosen = <int>[];
      await tester.pumpWidget(bar(compact: true, onSelected: chosen.add));
      await tester.pumpAndSettle();
      expect(find.text('Inbox'), findsNothing);
      expect(find.bySemanticsLabel('Inbox'), findsOne);
      expect(find.byTooltip('Inbox'), findsOne);
      // Still one tap to every destination.
      await tester.tap(find.byType(StudafyNavDestination).last);
      expect(chosen, [1]);
    });

    testWidgets('with reduced motion it changes without animating', (
      tester,
    ) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: bar(compact: false, onSelected: (_) {}),
        ),
      );
      expect(tester.hasRunningAnimations, isFalse);
    });
  });
}
