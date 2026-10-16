import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/features/study/domain/study.dart';

StudyPlan plan({bool? aiEnabled, String? aiAccess}) => StudyPlan(
  tier: StudyPlanTier.free,
  allowance: StudyPlan.free.allowance,
  available: const {},
  aiEnabled: aiEnabled,
  aiAccess: aiAccess,
);

void main() {
  test('a student in no class keeps the helper tab only while AI is on', () {
    expect(plan(aiEnabled: true, aiAccess: 'no_class').helperNeedsClass, true);
    // AI off for everyone, or a server that does not say: no dead tab.
    expect(
      plan(aiEnabled: false, aiAccess: 'no_class').helperNeedsClass,
      false,
    );
    expect(plan(aiAccess: 'no_class').helperNeedsClass, false);
    // Not a student: never.
    expect(
      plan(aiEnabled: true, aiAccess: 'not_student').helperNeedsClass,
      false,
    );
    expect(plan(aiEnabled: true, aiAccess: 'ok').helperNeedsClass, false);
  });
}
