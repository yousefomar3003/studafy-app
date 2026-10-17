import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/core/tab_back_scope.dart';

import '../support/system_back.dart';

/// Android back on a tabbed home screen: to the first tab, then out.
class _Tabs extends StatefulWidget {
  const _Tabs();

  @override
  State<_Tabs> createState() => _TabsState();
}

class _TabsState extends State<_Tabs> {
  int index = 0;

  @override
  Widget build(BuildContext context) => TabBackScope(
    atFirstTab: index == 0,
    onBack: () => setState(() => index = 0),
    child: Scaffold(
      body: Text('tab $index'),
      bottomNavigationBar: Row(
        children: [
          for (var i = 0; i < 3; i++)
            TextButton(
              onPressed: () => setState(() => index = i),
              child: Text('go $i'),
            ),
        ],
      ),
    ),
  );
}

void main() {
  testWidgets('back from another tab goes to the first, then leaves', (
    tester,
  ) async {
    final exits = AppExits(tester);
    await tester.pumpWidget(const MaterialApp(home: _Tabs()));

    await tester.tap(find.text('go 2'));
    await tester.pump();
    expect(find.text('tab 2'), findsOneWidget);

    await systemBack(tester);
    expect(find.text('tab 0'), findsOneWidget);
    expect(exits.count, 0);

    await systemBack(tester);
    expect(exits.count, 1);
  });

  testWidgets('a page pushed over the tabs pops as usual', (tester) async {
    final exits = AppExits(tester);
    await tester.pumpWidget(const MaterialApp(home: _Tabs()));
    await tester.tap(find.text('go 1'));
    await tester.pump();

    tester
        .state<NavigatorState>(find.byType(Navigator))
        .push(
          MaterialPageRoute<void>(builder: (_) => const Text('pushed page')),
        );
    await tester.pumpAndSettle();

    await systemBack(tester);
    expect(find.text('pushed page'), findsNothing);
    // The tab under it is where it was.
    expect(find.text('tab 1'), findsOneWidget);
    expect(exits.count, 0);
  });
}
