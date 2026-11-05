import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/core/keyboard_dismissal.dart';

void main() {
  late int saves;

  Future<void> pump(WidgetTester tester) async {
    saves = 0;
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => KeyboardDismissal(child: child!),
        home: Scaffold(
          body: ListView(
            children: [
              const TextField(
                key: Key('mark'),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
              ),
              const TextField(key: Key('answer'), maxLines: 3),
              const SizedBox(height: 200, child: Text('Question 1')),
              FilledButton(onPressed: () => saves++, child: const Text('Save')),
              const SizedBox(height: 1200),
            ],
          ),
        ),
      ),
    );
  }

  bool focused(WidgetTester tester, String key) => tester
      .widget<EditableText>(
        find.descendant(
          of: find.byKey(Key(key), skipOffstage: false),
          matching: find.byType(EditableText, skipOffstage: false),
          skipOffstage: false,
        ),
      )
      .focusNode
      .hasFocus;

  testWidgets('a tap outside any field closes the keyboard', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('mark')));
    await tester.pump();
    expect(focused(tester, 'mark'), isTrue);
    expect(tester.testTextInput.isVisible, isTrue);

    await tester.tap(find.text('Question 1'));
    await tester.pump();
    expect(focused(tester, 'mark'), isFalse);
    expect(tester.testTextInput.isVisible, isFalse);
  });

  testWidgets('a tap on a button still reaches it', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('mark')));
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(saves, 1);
  });

  testWidgets('a tap on another field moves the keyboard there', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('mark')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('answer')));
    await tester.pump();
    expect(focused(tester, 'mark'), isFalse);
    expect(focused(tester, 'answer'), isTrue);
  });

  testWidgets('dragging the page closes the keyboard', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('mark')));
    await tester.pump();
    await tester.drag(find.text('Question 1'), const Offset(0, -80));
    await tester.pumpAndSettle();
    expect(focused(tester, 'mark'), isFalse);
    expect(tester.testTextInput.isVisible, isFalse);
  });

  testWidgets('scrolling inside a long answer keeps the keyboard', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('answer')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('answer')),
      List.generate(12, (i) => 'line $i').join('\n'),
    );
    await tester.pump();
    final field = tester.getCenter(find.byKey(const Key('answer')));
    final gesture = await tester.startGesture(field);
    await gesture.moveBy(const Offset(0, -10));
    await gesture.moveBy(const Offset(0, -30));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(focused(tester, 'answer'), isTrue);
  });
}
