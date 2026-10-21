import 'package:flutter/material.dart';

import '../core/ai_usage.dart';
import '../core/material_selection.dart';
import '../core/navigation.dart';
import '../core/platform_attachment_source.dart';
import '../features/academic/domain/academic_repository.dart';
import '../features/classes/application/class_list_interactor.dart';
import '../features/study/domain/study.dart';
import '../features/study/presentation/note_page.dart';
import '../features/study/presentation/notebook_home_page.dart';
import '../features/study/presentation/practice_page.dart';
import '../features/study/presentation/study_plan_copy.dart';
import '../features/study/presentation/study_plans_page.dart';
import '../features/study/presentation/upgrade_prompt.dart';
import '../features/study_assistant/domain/study_assistant_repository.dart';
import '../features/study_assistant/presentation/study_assistant_page.dart';
import '../l10n/generated/app_l10n.dart';
import 'account_hub_page.dart';
import 'material_picker.dart';

/// What the student's study tools open, wherever they are opened from:
/// the plans, the Notebook, flashcards and quizzes, notes from a photo,
/// and the plan as the AI Tutor and the profile show it.
///
/// The shell lays out tabs; this connects the study feature to the rest of
/// the app, since only lib/app may reach across features.
class StudentStudyActions {
  const StudentStudyActions({required this.study, this.studyPlans});

  final StudyRepository study;

  /// Buying Studafy Plus / Max. Null without billing.
  final StudyPlanSubscriptionRepository? studyPlans;

  /// Opens the Plans screen, from wherever a plan is mentioned.
  Future<void> openPlans(BuildContext context) async {
    await Navigator.of(context).pushOnce(
      MaterialPageRoute<void>(
        builder: (_) => StudyPlansPage(study: study, subscriptions: studyPlans),
      ),
    );
  }

  /// The Notebook over the current tab - for a student in a class, whose
  /// tab bar has Lessons and Work where a student in no class has it.
  Future<void> openNotebook(
    BuildContext context, {
    required bool inClass,
  }) async {
    await Navigator.of(context).pushOnce(
      MaterialPageRoute<void>(
        builder: (context) => NotebookHomePage(
          study: study,
          pickPhoto: pickPlatformAttachment,
          onOpenPlans: () => openPlans(context),
          onBack: () => Navigator.of(context).pop(),
          inClass: inClass,
        ),
      ),
    );
  }

  /// The Notebook as a tab of its own, for a student in no class.
  Widget notebookTab() => Builder(
    builder: (context) => NotebookHomePage(
      study: study,
      pickPhoto: pickPlatformAttachment,
      onOpenPlans: () => openPlans(context),
    ),
  );

  Future<void> openPractice(
    BuildContext context,
    StudySetKind kind, {
    required bool inClass,
  }) async {
    await Navigator.of(context).pushOnce(
      MaterialPageRoute<void>(
        builder: (context) => PracticePage(
          study: study,
          initialKind: kind,
          onOpenPlans: () => openPlans(context),
          inClass: inClass,
        ),
      ),
    );
  }

  /// From the AI Tutor: a photo or screenshot into notes in the personal
  /// notebook (Studafy Plus), then the note itself.
  Future<void> photoToNotes(BuildContext context) async {
    StudyPlan? plan;
    try {
      plan = await study.plan();
    } on Object {
      plan = null;
    }
    if (!context.mounted) return;
    final entry = await notesFromPhoto(
      context,
      study: study,
      pickPhoto: pickPlatformAttachment,
      plan: plan,
      onOpenPlans: () => openPlans(context),
    );
    if (entry == null || !context.mounted) return;
    await Navigator.of(context).pushOnce(
      MaterialPageRoute<void>(
        builder: (_) => NotePage(study: study, entry: entry),
      ),
    );
  }

  /// The plan as the AI Tutor shows it: its name, its AI tokens, and what
  /// the next plan adds - nothing to upgrade to on Studafy Max.
  Future<HelperPlan?> helperPlan(BuildContext context) async {
    final l10n = AppL10n.of(context);
    final plan = await study.plan();
    final next = plan.tier.next;
    return HelperPlan(
      name: studyPlanCopy[plan.tier]!.name,
      allowance: HelperAllowance(
        weekly: plan.allowance.weekly,
        total: plan.allowance.total,
        used: plan.allowance.used,
        remaining: plan.allowance.remaining,
        resetsAt: plan.allowance.resetsAt,
      ),
      upgradeTo: next == null ? null : studyPlanCopy[next]!.name,
      upgradeBenefits: next == null
          ? const []
          : [for (final line in studyPlanCopy[next]!.adds) line(l10n)],
    );
  }

  /// A question refused by the plan: its tokens are used, or photos need
  /// Studafy Plus. Explains the limit and offers the plans.
  Future<void> planLimit(BuildContext context, String code) async {
    StudyPlan? plan;
    try {
      plan = await study.plan();
    } on Object {
      plan = null;
    }
    if (!context.mounted) return;
    await showUpgradePrompt(
      context,
      reason: code == StudyAssistantFailure.allowanceUsed
          ? UpgradeReason.tokensUsed
          : UpgradeReason.feature,
      plan: plan,
      // Photos to the AI Tutor are Studafy Plus.
      needs: StudyPlanTier.plus,
      onUpgrade: () => openPlans(context),
    );
  }

  /// The Subscription row on the student's profile: the plan, its AI
  /// usage, and Restore purchases where a store sells the plans. Restoring
  /// lives here and only here, never on a study screen.
  SubscriptionEntry subscription() {
    final plans = studyPlans;
    return SubscriptionEntry(
      open: openPlans,
      // Only where a store sells the plans (not the web or desktop).
      restorePurchases: plans == null || plans.purchaseStore == null
          ? null
          : plans.restorePurchases,
      currentPlan: () async => studyPlanCopy[(await study.plan()).tier]!.name,
      // What the server metered, shown as a bar and a label only.
      usage: () async {
        final plan = await study.plan();
        return AiUsageSnapshot(
          planName: studyPlanCopy[plan.tier]!.name,
          used: plan.allowance.used,
          total: plan.allowance.total,
          resetsAt: plan.allowance.resetsAt,
          weekly: plan.allowance.weekly,
          canUpgrade: plan.tier.next != null,
        );
      },
    );
  }

  /// What the student may give the AI Tutor besides a question.
  Future<HelperAbilities> abilities() async {
    final plan = await study.plan();
    return HelperAbilities(
      ask: plan.assistantOn,
      classMaterial: plan.classMaterialOn,
      photos: plan.helperPhotosOn,
    );
  }

  /// Chooses notes and lessons for the AI Tutor to answer from.
  Future<List<ChatReference>?> pickReferences(
    BuildContext context,
    List<ChatReference> current,
    ClassListInteractor classes,
    AcademicRepository academic,
  ) async {
    final picked = await pickMaterials(
      context,
      MaterialPickRequest(
        action: MaterialAction.helper,
        initial: selectionOfReferences(current),
        allowNotes: true,
      ),
      classes: classes,
      academic: academic,
      study: study,
    );
    return picked == null ? null : referencesOfSelection(picked);
  }
}
