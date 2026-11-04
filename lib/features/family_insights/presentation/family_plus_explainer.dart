import 'package:flutter/material.dart';

import '../../../core/studafy_components.dart';
import '../../../core/studafy_design.dart';
import '../../../l10n/generated/app_l10n.dart';
import '../domain/family_insights.dart';
import 'family_insights_page.dart';

/// What Family+ does, before what it costs: a worked example drawn with the
/// real insight cards (labelled Example), how it works, what each plan
/// covers, and why a parent can trust it - as the privacy policy describes
/// Family+: it summarises what the parent can already see, compares a child
/// only with their own earlier record, and uses no AI.
class FamilyPlusExplainer extends StatelessWidget {
  const FamilyPlusExplainer({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(l10n.familyExampleTitle),
        const FamilyPlusExampleCard(),
        SectionHeader(l10n.familyLandingHowTitle),
        PlanSteps(
          steps: [
            l10n.familyLandingStep1,
            l10n.familyLandingStep2,
            l10n.familyLandingStep3,
          ],
        ),
        SectionHeader(l10n.familyPlusWhatYouGet),
        FeatureCard(
          child: PlanChecklist(
            items: [
              l10n.familyPlusFeatureFocus,
              l10n.familyPlusFeatureClasses,
              l10n.familyPlusFeatureChart,
              l10n.familyPlusFeatureMissing,
              l10n.familyPlusFeatureTrends,
              l10n.familyPlusFeatureSchool,
              l10n.familyIncludesSizes,
            ],
          ),
        ),
        SectionHeader(l10n.familyTrustTitle),
        FeatureCard(
          child: PlanChecklist(
            icon: Icons.verified_user_outlined,
            items: [
              l10n.familyTrustNoAi,
              l10n.familyTrustOwnRecord,
              l10n.familyTrustSeeable,
            ],
          ),
        ),
      ],
    );
  }
}

/// One sample child's insight, labelled as an example: what to focus on
/// this week, and two classes - one trending up, one with work missing -
/// drawn with the cards Family+ itself shows. No real child's records.
class FamilyPlusExampleCard extends StatelessWidget {
  const FamilyPlusExampleCard({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final maths = l10n.familyExampleMaths;
    final science = l10n.familyExampleScience;
    return FeatureCard(
      tint: studafySky,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PlanExampleHeader(
            label: l10n.planExampleLabel,
            note: l10n.familyExampleNote,
          ),
          const SizedBox(height: 14),
          Text(
            l10n.insightsFocusTitle,
            style: const TextStyle(
              color: studafyMuted,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          InsightSignalCard(
            signal: InsightSignal(
              kind: InsightKind.subjectFocus,
              subject: science,
              strength: InsightStrength.medium,
              evidence: const [
                InsightEvidenceItem(
                  label: '',
                  value: '58%',
                  recordCount: 6,
                  code: InsightEvidenceCode.classAverage,
                ),
                InsightEvidenceItem(
                  label: '',
                  value: '74%',
                  recordCount: 18,
                  code: InsightEvidenceCode.overallAverage,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            l10n.insightsByClass,
            style: const TextStyle(
              color: studafyMuted,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          InsightClassCard(
            line: ClassInsight(
              classroomId: 'example-maths',
              className: maths,
              averagePercent: 82,
              gradedCount: 6,
              latestPercent: 88,
              trend: ClassTrend.up,
              trendPoints: 8,
              missedAssessments: 0,
              attendanceRatePercent: 96,
              absences: 1,
              homeworkDue: 5,
              homeworkMissing: 0,
              homeworkLate: 0,
              homeworkOnTimePercent: 100,
              standing: ClassStanding.strongest,
            ),
          ),
          InsightClassCard(
            line: ClassInsight(
              classroomId: 'example-science',
              className: science,
              averagePercent: 58,
              gradedCount: 6,
              latestPercent: 55,
              trend: ClassTrend.down,
              trendPoints: -6,
              missedAssessments: 0,
              attendanceRatePercent: 90,
              absences: 2,
              homeworkDue: 6,
              homeworkMissing: 2,
              homeworkLate: 1,
              homeworkOnTimePercent: 50,
              standing: ClassStanding.weakest,
            ),
          ),
        ],
      ),
    );
  }
}
