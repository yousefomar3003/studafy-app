import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/core/lazy_indexed_stack.dart';
import 'package:studafy/core/studafy_design.dart';

void main() {
  group('LazyIndexedStack', () {
    testWidgets('builds a tab only when it is first shown, then keeps it', (
      tester,
    ) async {
      final built = <String>[];
      Widget stack(int index) => Directionality(
        textDirection: TextDirection.ltr,
        child: LazyIndexedStack(
          index: index,
          children: [
            for (final name in ['today', 'work', 'messages'])
              _Tab(name, onInit: built.add),
          ],
        ),
      );

      await tester.pumpWidget(stack(0));
      expect(built, ['today']);

      await tester.pumpWidget(stack(2));
      expect(built, ['today', 'messages']);

      // Back to a tab already built: kept, not built again.
      await tester.pumpWidget(stack(0));
      expect(built, ['today', 'messages']);
    });
  });

  group('StudafyNavigationBar', () {
    testWidgets('steps aside while typing and comes back after', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: const TextField(),
            bottomNavigationBar: StudafyNavigationBar(
              selectedIndex: 0,
              onSelected: (_) {},
              items: const [
                StudafyNavItem('Today', Icons.home_outlined, Icons.home),
                StudafyNavItem('Helper', Icons.star_outline, Icons.star),
              ],
            ),
          ),
        ),
      );
      expect(find.text('Helper'), findsOneWidget);

      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      expect(find.text('Helper'), findsNothing);

      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      expect(find.text('Helper'), findsOneWidget);
    });
  });

  group('StudafyPressable', () {
    /// The press scale of the card showing [label].
    double scaleOf(WidgetTester tester, String label) => tester
        .widget<AnimatedScale>(
          find.ancestor(
            of: find.text(label),
            matching: find.byType(AnimatedScale),
          ),
        )
        .scale;

    Widget list() => MaterialApp(
      home: Scaffold(
        body: ListView(
          children: [
            for (var i = 0; i < 20; i++)
              FeatureCard(
                onTap: () {},
                child: SizedBox(height: 80, child: Text('Card $i')),
              ),
          ],
        ),
      ),
    );

    testWidgets('a held finger presses the card', (tester) async {
      await tester.pumpWidget(list());
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Card 1')),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(scaleOf(tester, 'Card 1'), lessThan(1));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(scaleOf(tester, 'Card 1'), 1);
    });

    testWidgets('the card still gets the tap', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FeatureCard(onTap: () => taps++, child: const Text('Card')),
          ),
        ),
      );
      await tester.tap(find.text('Card'));
      await tester.pumpAndSettle();
      expect(taps, 1);
    });

    testWidgets('a scroll that starts on a card does not press it', (
      tester,
    ) async {
      await tester.pumpWidget(list());
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Card 1')),
      );
      await gesture.moveBy(const Offset(0, -60));
      await tester.pump(const Duration(milliseconds: 200));
      await gesture.moveBy(const Offset(0, -60));
      await tester.pump(const Duration(milliseconds: 200));
      final scales = tester
          .widgetList<AnimatedScale>(find.byType(AnimatedScale))
          .map((scale) => scale.scale);
      expect(scales, everyElement(1));
      await gesture.up();
    });
  });
}

class _Tab extends StatefulWidget {
  const _Tab(this.name, {required this.onInit});
  final String name;
  final ValueChanged<String> onInit;
  @override
  State<_Tab> createState() => _TabState();
}

class _TabState extends State<_Tab> {
  @override
  void initState() {
    super.initState();
    widget.onInit(widget.name);
  }

  @override
  Widget build(BuildContext context) => Text(widget.name);
}
