import 'package:flutter/material.dart';

import '../../../core/studafy_components.dart';
import '../../../core/studafy_design.dart';
import '../../../core/studafy_formatting.dart';
import '../../../l10n/generated/app_l10n.dart';
import '../domain/marking.dart';
import '../domain/online_assessment.dart';
import 'marking_review.dart';

/// About how many written answers a month Studafy AI Marking covers,
/// rounded down on purpose so the page never promises more than the plan
/// gives.
///
/// How it is worked out (2026-11-04). The plan allows 7,000,000 tokens a
/// teacher a month (DL-075, `private.marking_limits()`), and every
/// suggestion is one model call (`StudyAssistant.markAnswer`):
///
/// * the instructions (`markingInstructions` in
///   packages/domain/src/study/marking.ts) are 2,450 to 2,490 characters
///   with the strictness rule, which the worker's hold counts as 700
///   tokens (`INSTRUCTION_TOKENS` in
///   packages/infrastructure/src/study/metering.ts);
/// * the question, the teacher's reference and the student's answer: the
///   cases in scripts/ai/marking-eval-cases.json average about 300
///   characters and the longest is about 500; the example on this page,
///   wrapped as `markingPrompt` sends it, is 520. A generous everyday
///   written answer with its reference is taken as 2,000 characters, which
///   the pessimistic bound of 2 characters a token (`tokenBound`) makes
///   1,000 tokens - more than English or Arabic really use;
/// * the reply is capped at 900 tokens (`MARKING_OUTPUT_TOKENS` in
///   apps/worker/src/processors/markingSuggestions.ts); the JSON a
///   suggestion needs is usually far shorter.
///
/// That is at most 700 + 1,000 + 900 = 2,600 tokens a suggestion, every
/// part taken at its worst case, so 7,000,000 / 2,600 ≈ 2,690 - rounded
/// down to 2,500. The ledger settles to what the provider reports, so most
/// teachers will get more. A photo of handwriting is first transcribed,
/// held at about 16,000 image tokens a page (`PHOTO_INPUT_TOKENS`), which
/// is why the page says photos use more. The US$3 cost cap beneath the
/// tokens only bites if the model's price changes (DL-075).
const markingAnswersPerMonth = 2500;

/// Everything that explains Studafy AI Marking before its price: how it
/// works, a worked example drawn with the real review, what is included
/// and why the teacher can trust it. Shown to everyone on the plan page;
/// a teacher who holds the plan sees it under their allowance.
class MarkingPlanExplainer extends StatelessWidget {
  const MarkingPlanExplainer({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(l10n.markingLandingHowTitle),
        PlanSteps(
          steps: [
            l10n.markingLandingStep1,
            l10n.markingLandingStep2,
            l10n.markingLandingStep3,
          ],
        ),
        SectionHeader(l10n.markingExampleTitle),
        const MarkingExampleCard(),
        SectionHeader(l10n.markingPlanWhatYouGet),
        FeatureCard(
          child: PlanChecklist(
            items: [
              l10n.markingIncludedOnline,
              l10n.markingIncludedHandIns,
              l10n.markingPlanFeatureDetail,
              l10n.markingIncludedCapacity(
                studafyNumber(context, markingAnswersPerMonth),
              ),
            ],
          ),
        ),
        SectionHeader(l10n.markingTrustTitle),
        FeatureCard(
          child: PlanChecklist(
            icon: Icons.verified_user_outlined,
            items: [
              l10n.markingPlanFeatureDecide,
              l10n.markingPlanFeaturePrivacy,
              l10n.markingTrustTraining,
              l10n.markingPlanFeatureOptOut,
            ],
          ),
        ),
      ],
    );
  }
}

/// A worked example, labelled as one: a question, the teacher's key
/// points, a sample answer and the suggestion for it, drawn with the same
/// review the teacher marks with. Nothing here is real student work and
/// nothing is sent anywhere.
class MarkingExampleCard extends StatelessWidget {
  const MarkingExampleCard({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final points = [
      l10n.markingExamplePoint1,
      l10n.markingExamplePoint2,
      l10n.markingExamplePoint3,
      l10n.markingExamplePoint4,
    ];
    final question = AssessmentQuestion(
      id: 'example',
      position: 1,
      prompt: l10n.markingExampleQuestion,
      maximumScore: 4,
    );
    return FeatureCard(
      tint: studafySky,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PlanExampleHeader(
            label: l10n.markingExampleLabel,
            note: l10n.markingExampleNote,
          ),
          const SizedBox(height: 12),
          MarkingAnswerReview(
            answer: AttemptAnswer(
              question: question,
              answerText: l10n.markingExampleAnswer,
            ),
            reference: MarkingReference(
              questionId: question.id,
              position: 1,
              kind: QuestionKind.essay,
              prompt: question.prompt,
              maximumScore: 4,
              keyPoints: [
                for (final point in points)
                  MarkingKeyPoint(text: point, marks: 1),
              ],
            ),
            suggestion: MarkingSuggestion(
              id: 'example',
              studentId: 'example',
              status: MarkingSuggestionStatus.ready,
              maximumScore: 4,
              suggestedScore: 3,
              met: points.take(3).toList(),
              missed: [l10n.markingExampleMissed],
              feedback: l10n.markingExampleFeedback,
              referenceVersion: 1,
              strictness: MarkingStrictness.balanced,
            ),
          ),
        ],
      ),
    );
  }
}
