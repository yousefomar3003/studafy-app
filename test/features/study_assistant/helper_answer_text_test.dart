import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/features/study_assistant/presentation/helper_answer_text.dart';

import '../../support/localized_app.dart';

/// The helper's answers arrive as Markdown. They are shown formatted, never
/// as raw `**stars**`, and nothing in them reaches the network by itself.
void main() {
  Future<void> show(WidgetTester tester, String answer) async {
    await tester.pumpWidget(
      localizedApp(
        home: Scaffold(
          body: SingleChildScrollView(child: HelperAnswerText(answer)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Every span drawn on screen, with the style it is drawn in.
  List<(String, TextStyle?)> spans(WidgetTester tester) {
    final found = <(String, TextStyle?)>[];
    for (final text in tester.widgetList<Text>(find.byType(Text))) {
      void visit(InlineSpan span, TextStyle? inherited) {
        if (span is! TextSpan) return;
        final style = inherited?.merge(span.style) ?? span.style;
        if (span.text != null) found.add((span.text!, style));
        for (final child in span.children ?? const <InlineSpan>[]) {
          visit(child, style);
        }
      }

      if (text.textSpan case final span?) {
        visit(span, text.style);
      } else if (text.data case final data?) {
        found.add((data, text.style));
      }
    }
    return found;
  }

  testWidgets('bold, italics, lists, headings and code are formatted', (
    tester,
  ) async {
    await show(
      tester,
      '## Steps\n\n'
      '**Photosynthesis** makes *sugar*.\n\n'
      '- Light\n- Water\n\n'
      '1. First\n2. Second\n\n'
      'Use `CO2` here.\n\n'
      '```\nrate = light * water\n```\n\n'
      'Line one\nLine two',
    );

    final drawn = spans(tester);
    expect(drawn.map((s) => s.$1).join(), isNot(contains('**')));
    expect(drawn.map((s) => s.$1).join(), isNot(contains('##')));
    expect(
      drawn.firstWhere((s) => s.$1 == 'Photosynthesis').$2?.fontWeight,
      FontWeight.w700,
    );
    expect(
      drawn.firstWhere((s) => s.$1 == 'sugar').$2?.fontStyle,
      FontStyle.italic,
    );
    expect(
      drawn.firstWhere((s) => s.$1 == 'Steps').$2?.fontWeight,
      FontWeight.w800,
    );
    expect(drawn.firstWhere((s) => s.$1 == 'CO2').$2?.fontFamily, 'monospace');
    expect(find.text('•'), findsNWidgets(2));
    expect(find.text('1.'), findsOne);
    expect(find.text('2.'), findsOne);
    expect(find.textContaining('rate = light * water'), findsOne);
    // A single line break in the answer is kept as one.
    expect(drawn.map((s) => s.$1).join(), contains('Line one\nLine two'));
  });

  testWidgets('an Arabic answer reads right to left, bullets and all', (
    tester,
  ) async {
    await show(tester, '**التمثيل الضوئي** مهم.\n\n- الضوء\n- الماء');

    expect(directionOf(tester, find.text('•').first), TextDirection.rtl);
    final bullet = tester.getTopLeft(find.text('•').first).dx;
    final item = tester.getTopLeft(find.textContaining('الضوء')).dx;
    expect(bullet, greaterThan(item));
  });

  testWidgets('an image is never fetched; its description is shown', (
    tester,
  ) async {
    await show(tester, '![a leaf diagram](https://tracker.example/leaf.png)');

    expect(find.byType(Image), findsNothing);
    expect(find.text('a leaf diagram'), findsOne);
  });

  testWidgets('a link asks first and shows where it goes; others do nothing', (
    tester,
  ) async {
    await show(
      tester,
      'Read [the notes](https://example.org/notes) or '
      '[this](javascript:alert(1)).',
    );

    await tester.tapOnText(find.textRange.ofSubstring('the notes'));
    await tester.pumpAndSettle();
    expect(find.text('example.org'), findsOne);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    await tester.tapOnText(find.textRange.ofSubstring('this'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });
}
