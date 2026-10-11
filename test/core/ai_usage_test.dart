import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/core/ai_usage.dart';

import '../support/localized_app.dart';

/// AI usage is shown as a bar and a plain label - never as a count of
/// tokens, which only the server keeps.
void main() {
  test('the level follows what the server metered', () {
    expect(aiUsageLevel(used: 0, total: 40000), AiUsageLevel.plenty);
    expect(aiUsageLevel(used: 29999, total: 40000), AiUsageLevel.plenty);
    expect(aiUsageLevel(used: 30000, total: 40000), AiUsageLevel.low);
    expect(aiUsageLevel(used: 40000, total: 40000), AiUsageLevel.reached);
    expect(aiUsageLevel(used: 0, total: 0), AiUsageLevel.reached);
  });

  Future<void> show(WidgetTester tester, AiUsageSnapshot usage) =>
      tester.pumpWidget(
        localizedApp(
          home: Scaffold(
            body: AiUsageCard(usage: usage, onPlans: () {}),
          ),
        ),
      );

  testWidgets('a plan with plenty left: its name, a bar, when it resets', (
    tester,
  ) async {
    await show(
      tester,
      AiUsageSnapshot(
        planName: 'Studafy Plus',
        used: 750000,
        total: 3000000,
        resetsAt: DateTime(2026, 11),
        weekly: false,
      ),
    );
    expect(find.text('Studafy Plus plan'), findsOne);
    expect(find.text('Plenty available'), findsOne);
    expect(find.text('Resets on Sun, Nov 1'), findsOne);
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      .25,
    );
    expect(find.text('Upgrade and compare plans'), findsOne);
    expect(find.textContaining(RegExp(r'\d{3}')), findsNothing);
    expect(find.textContaining('token'), findsNothing);
  });

  testWidgets('used up: says so plainly, keeps the work, offers more', (
    tester,
  ) async {
    await show(
      tester,
      AiUsageSnapshot(
        planName: 'Studafy Free',
        used: 40000,
        total: 40000,
        resetsAt: DateTime(2026, 10, 12),
        weekly: true,
      ),
    );
    expect(find.text('Limit reached'), findsOne);
    expect(find.textContaining('are kept'), findsOne);
    expect(find.text('Resets every Monday · next on Mon, Oct 12'), findsOne);
  });

  testWidgets('on the top plan there is nothing to upgrade to', (tester) async {
    await show(
      tester,
      AiUsageSnapshot(
        planName: 'Studafy Max',
        used: 5000000,
        total: 6000000,
        resetsAt: DateTime(2026, 11),
        weekly: false,
        canUpgrade: false,
      ),
    );
    expect(find.text('Running low'), findsOne);
    expect(find.text('Compare plans'), findsOne);
    expect(find.text('Upgrade and compare plans'), findsNothing);
  });
}
