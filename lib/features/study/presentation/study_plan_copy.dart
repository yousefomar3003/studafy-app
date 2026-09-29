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
    (l) => l.studyPlansFeatureTenQuestions,
  ], const []),
  StudyPlanTier.plus: StudyPlanCopy(
    'Studafy Plus',
    r'US$3.99',
    [
      (l) => l.studyPlansFeatureEverythingInFree,
      (l) => l.studyPlansFeatureWhiteboard,
      (l) => l.studyPlansFeatureFortyQuestions,
    ],
    [
      (l) => l.studyPlansFeatureWhiteboard,
      (l) => l.studyPlansFeatureFortyQuestions,
    ],
  ),
  StudyPlanTier.max: StudyPlanCopy(
    'Studafy Max',
    r'US$5.99',
    [
      (l) => l.studyPlansFeatureEverythingInPlus,
      (l) => l.studyPlansFeatureQuizzes,
      (l) => l.studyPlansFeatureFlashcards,
      (l) => l.studyPlansFeatureSixtyQuestions,
    ],
    [
      (l) => l.studyPlansFeatureQuizzes,
      (l) => l.studyPlansFeatureFlashcards,
      (l) => l.studyPlansFeatureSixtyQuestions,
      (l) => l.upgradeLargerAllowance,
    ],
  ),
};

String storeName(SubscriptionStore store) => switch (store) {
  SubscriptionStore.appStore => 'App Store',
  SubscriptionStore.playStore => 'Google Play',
};
