import '../../../l10n/generated/app_l10n.dart';
import '../domain/study.dart';

/// How a plan is named and described, the same on the Plans screen and in
/// the upgrade prompt.
class StudyPlanCopy {
  const StudyPlanCopy(this.name, this.usPrice, this.features, this.adds);
  final String name;

  /// The US list price, shown only when the store cannot be reached.
  final String usPrice;

  /// Everything the plan includes, in the reader's language.
  final List<String Function(AppL10n)> features;

  /// What it adds to the plan below it.
  final List<String Function(AppL10n)> adds;
}

final Map<StudyPlanTier, StudyPlanCopy> studyPlanCopy = {
  StudyPlanTier.free: StudyPlanCopy('Studafy Free', '', [
    (l) => l.studyPlansFeatureLessons,
    (l) => l.studyPlansFeatureNotebook,
    (l) => l.studyPlansFeatureAskLessons,
    (l) => l.studyPlansFeatureFreeTokens,
  ], const []),
  StudyPlanTier.plus: StudyPlanCopy(
    'Studafy Plus',
    r'US$3.99',
    [
      (l) => l.studyPlansFeatureEverythingInFree,
      (l) => l.studyPlansFeatureWhiteboard,
      (l) => l.studyPlansFeaturePlusTokens,
    ],
    [
      (l) => l.studyPlansFeatureWhiteboard,
      (l) => l.studyPlansFeaturePlusTokens,
    ],
  ),
  StudyPlanTier.max: StudyPlanCopy(
    'Studafy Max',
    r'US$5.99',
    [
      (l) => l.studyPlansFeatureEverythingInPlus,
      (l) => l.studyPlansFeatureQuizzes,
      (l) => l.studyPlansFeatureFlashcards,
      (l) => l.studyPlansFeatureMaxTokens,
    ],
    [
      (l) => l.studyPlansFeatureQuizzes,
      (l) => l.studyPlansFeatureFlashcards,
      (l) => l.studyPlansFeatureMaxTokens,
    ],
  ),
};

/// Each plan's AI allowance, in the tokens the server meters, exactly as
/// `private.ai_plan_limits()` sets them (supabase/migrations/
/// 202610070001_grounded_material_and_token_allowances.sql; a test checks
/// they still match): Free 40,000 a week, Plus 3,000,000 a month, Max
/// 6,000,000 a month.
///
/// The app never shows a count - usage is a bar - so the plans page says
/// only how the allowances compare, which these make exact: Plus's month
/// is 75 times Free's week, and Max's month is twice Plus's.
const studyAllowanceFreeWeekly = 40000;
const studyAllowancePlusMonthly = 3000000;
const studyAllowanceMaxMonthly = 6000000;

String storeName(SubscriptionStore store) => switch (store) {
  SubscriptionStore.appStore => 'App Store',
  SubscriptionStore.playStore => 'Google Play',
};
