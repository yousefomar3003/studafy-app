import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/features/study/domain/study.dart';
import 'package:studafy/features/study/presentation/upgrade_prompt.dart';

import '../../support/localized_app.dart';

StudyPlan planOf(StudyPlanTier tier) => StudyPlan(
  tier: tier,
  allowance: AiAllowance(
    weekly: tier == StudyPlanTier.free,
    total: tier == StudyPlanTier.free ? 40000 : 3000000,
    used: tier == StudyPlanTier.free ? 40000 : 3000000,
    remaining: 0,
    resetsAt: DateTime(2026, 10, 12),
  ),
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
  testWidgets('out of free tokens: when they renew, what Plus adds, Upgrade', (
    tester,
  ) async {
    final opened = <String>[];
    await tester.pumpWidget(
      host(UpgradeReason.tokensUsed, planOf(StudyPlanTier.free), opened),
    );
    await tester.tap(find.text('limit'));
    await tester.pumpAndSettle();

    expect(find.text("You've reached your AI usage limit"), findsOne);
    expect(
      find.text(
        'It resets on Mon, Oct 12. Your work is kept. A bigger plan gives you more.',
      ),
      findsOne,
    );
    expect(find.text('What Studafy Plus unlocks'), findsOne);
    expect(
      find.text('Regular AI use - questions, notes and notebooks on most days'),
      findsOne,
    );
    // No plan promises unlimited AI, and no counts are shown.
    expect(find.textContaining('nlimited'), findsNothing);
    expect(find.textContaining('token'), findsNothing);
    expect(find.textContaining(RegExp(r'\d,\d{3}')), findsNothing);

    await tester.tap(find.text('Upgrade'));
    await tester.pumpAndSettle();
    expect(opened, ['plans']);
    expect(find.text("You've reached your AI usage limit"), findsNothing);
  });

  testWidgets('Plus out of tokens is offered Max', (tester) async {
    final opened = <String>[];
    await tester.pumpWidget(
      host(UpgradeReason.tokensUsed, planOf(StudyPlanTier.plus), opened),
    );
    await tester.tap(find.text('limit'));
    await tester.pumpAndSettle();
    expect(find.text("You've reached your AI usage limit"), findsOne);
    expect(find.text('What Studafy Max unlocks'), findsOne);
    expect(
      find.text(
        'Heavy AI use - twice Plus, for daily quizzes, flashcards and notebooks',
      ),
      findsOne,
    );
  });

  testWidgets('on Max there is nothing to sell, only the explanation', (
    tester,
  ) async {
    final opened = <String>[];
    await tester.pumpWidget(
      host(UpgradeReason.tokensUsed, planOf(StudyPlanTier.max), opened),
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
      upgradeReasonFor(StudyRefusal.allowanceUsed),
      UpgradeReason.tokensUsed,
    );
    expect(upgradeReasonFor(StudyRefusal.materialProcessing), isNull);
    expect(upgradeReasonFor(StudyRefusal.planRequired), UpgradeReason.feature);
    expect(upgradeReasonFor(StudyRefusal.photoUnreadable), isNull);
    expect(upgradeReasonFor(StudyRefusal.failed), isNull);
  });
}
