import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/features/study/domain/study.dart';
import 'package:studafy/features/study/presentation/upgrade_prompt.dart';

import '../../support/localized_app.dart';

StudyPlan planOf(StudyPlanTier tier, {int askPerDay = 10}) => StudyPlan(
  tier: tier,
  allowanceUsed: 1,
  resetsAt: DateTime(2026, 10, 1),
  askToday: askPerDay,
  askPerDay: askPerDay,
);

Widget host(
  UpgradeReason reason,
  StudyPlan plan,
  List<String> opened, {
  StudyPlanTier? needs,
}) => localizedApp(
  home: Builder(
    builder: (context) => Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () => showUpgradePrompt(
            context,
            reason: reason,
            plan: plan,
            needs: needs,
            onUpgrade: () => opened.add('plans'),
          ),
          child: const Text('limit'),
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('at the free daily limit: the limit, what Plus adds, Upgrade', (
    tester,
  ) async {
    final opened = <String>[];
    await tester.pumpWidget(
      host(UpgradeReason.dailyQuestions, planOf(StudyPlanTier.free), opened),
    );
    await tester.tap(find.text('limit'));
    await tester.pumpAndSettle();

    expect(find.text("You've used today's questions"), findsOne);
    expect(
      find.text(
        'Your plan includes 10 questions a day. You can ask again tomorrow.',
      ),
      findsOne,
    );
    expect(find.text('What Studafy Plus unlocks'), findsOne);
    expect(find.text('40 questions a day'), findsOne);
    expect(
      find.text('Snap the whiteboard - get real notebook notes'),
      findsOne,
    );

    await tester.tap(find.text('Upgrade'));
    await tester.pumpAndSettle();
    expect(opened, ['plans']);
    expect(find.text("You've used today's questions"), findsNothing);
  });

  testWidgets('Plus at its monthly allowance is offered Max', (tester) async {
    final opened = <String>[];
    await tester.pumpWidget(
      host(
        UpgradeReason.monthlyAllowance,
        planOf(StudyPlanTier.plus, askPerDay: 40),
        opened,
      ),
    );
    await tester.tap(find.text('limit'));
    await tester.pumpAndSettle();
    expect(find.text("This month's AI allowance is used"), findsOne);
    expect(find.text('What Studafy Max unlocks'), findsOne);
    expect(find.text('A larger monthly AI allowance'), findsOne);
  });

  testWidgets('on Max there is nothing to sell, only the explanation', (
    tester,
  ) async {
    final opened = <String>[];
    await tester.pumpWidget(
      host(
        UpgradeReason.monthlyAllowance,
        planOf(StudyPlanTier.max, askPerDay: 60),
        opened,
      ),
    );
    await tester.tap(find.text('limit'));
    await tester.pumpAndSettle();
    expect(find.text("You're on Studafy Max, the largest plan."), findsOne);
    expect(find.text('Upgrade'), findsNothing);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(opened, isEmpty);
  });

  testWidgets('"Not now" leaves without opening the plans', (tester) async {
    final opened = <String>[];
    await tester.pumpWidget(
      host(
        UpgradeReason.feature,
        planOf(StudyPlanTier.free),
        opened,
        needs: StudyPlanTier.plus,
      ),
    );
    await tester.tap(find.text('limit'));
    await tester.pumpAndSettle();
    expect(find.text('This comes with Studafy Plus'), findsOne);
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(opened, isEmpty);
  });

  test('only plan refusals become upgrade prompts', () {
    expect(
      upgradeReasonFor(StudyRefusal.dailyLimit),
      UpgradeReason.dailyQuestions,
    );
    expect(
      upgradeReasonFor(StudyRefusal.allowanceUsed),
      UpgradeReason.monthlyAllowance,
    );
    expect(upgradeReasonFor(StudyRefusal.planRequired), UpgradeReason.feature);
    expect(upgradeReasonFor(StudyRefusal.photoUnreadable), isNull);
    expect(upgradeReasonFor(StudyRefusal.failed), isNull);
  });
}
