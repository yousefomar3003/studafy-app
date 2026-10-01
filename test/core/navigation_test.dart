import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/core/navigation.dart';

/// A tap repeated while the next page opens must open it once.
void main() {
  testWidgets('a double tap opens the page once', (tester) async {
    var built = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).pushOnce(
              MaterialPageRoute<void>(
                builder: (_) {
                  built += 1;
                  return const Scaffold(body: Text('next page'));
                },
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.tap(find.text('open'), warnIfMissed: false);
    await tester.tap(find.text('open'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('next page'), findsOneWidget);
    expect(built, 1);

    // Back, and open again: that is a new tap, and it opens.
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('next page'), findsOneWidget);
  });
}
