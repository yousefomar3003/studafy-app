import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;

import '../core/feedback.dart';
import '../core/file_upload_repository.dart';
import '../core/lazy_indexed_stack.dart';
import '../core/navigation.dart';
import '../core/platform_attachment_source.dart';
import '../core/studafy_components.dart';
import '../core/studafy_design.dart';
import '../core/studafy_domain.dart';
import '../features/academic/domain/academic_repository.dart';
import '../features/academic/presentation/academic_overview_page.dart';
import '../features/academic/presentation/submit_work_page.dart';
import '../features/classes/application/class_list_interactor.dart';
import '../features/classes/presentation/join_class_page.dart';
import '../features/messaging/domain/messaging.dart';
import '../features/messaging/presentation/conversations_page.dart';
import '../features/messaging/presentation/messaging_scope.dart';
import '../features/notifications/domain/notification.dart';
import '../features/session/application/session_interactor.dart';
import '../features/study/domain/study.dart';
import '../features/study/presentation/study_plan_copy.dart';
import '../features/study/presentation/study_plans_page.dart';
import '../features/study/presentation/upgrade_prompt.dart';
import '../features/study_assistant/application/study_assistant_interactor.dart';
import '../features/study_assistant/domain/study_assistant_repository.dart';
import '../features/study_assistant/presentation/study_assistant_page.dart';
import '../l10n/generated/app_l10n.dart';
import 'account_hub_page.dart';
import 'assessment_navigation.dart';
import 'student_lessons_page.dart';
import 'student_today_page.dart';
import 'study_reference_picker.dart';

class StudentShell extends StatefulWidget {
  const StudentShell({
    super.key,
    required this.academic,
    this.classes,
    this.studyPlans,
    this.study,
    this.session,
    this.studyAssistant,
    this.studyChats,
    this.fileUploads,
  });

  /// Buying Studafy Plus / Max. Null without billing.
  final StudyPlanSubscriptionRepository? studyPlans;

  /// Plans, notebooks and study sets. Null in the preview shell.
  final StudyRepository? study;
  final AcademicRepository academic;

  /// Lets a student join a class from a link they were sent. Optional so the
  /// preview shell, which has no school service behind it, still builds.
  final ClassListInteractor? classes;

  /// Re-reads the profile after a join, because the membership that makes the
  /// rest of this shell work is created on the server. Optional for the same
  /// reason as [classes].
  final SessionInteractor? session;

  /// The study helper. Null when the server has no AI provider configured,
  /// and the tab is then absent rather than present and always failing.
  final StudyAssistantInteractor? studyAssistant;

  /// Where the helper's chats are kept, on this device.
  final StudyChatStore? studyChats;

  /// Lets a student attach documents and photos to the work they hand in.
  /// Null in builds with no upload pipeline, and the control is then absent.
  final FileUploadRepository? fileUploads;

  @override
  State<StudentShell> createState() => _StudentShellState();
}

class _StudentShellState extends State<StudentShell> {
  int index = 0;

  /// The tab Work opens on; a notification about marks opens Grades.
  AcademicFeed _workFeed = AcademicFeed.assignments;

  /// Opens what a notification is about, in this student's app.
  bool _openNotification(NotificationItem item) {
    final key = item.templateKey;
    final messagesIndex = 3 + (widget.studyAssistant == null ? 0 : 1);
    final (int, AcademicFeed?)? target = switch (key.split('.').first) {
      'academic' when key.contains('grade') => (2, AcademicFeed.grades),
      'academic' when key.contains('assessment') => (
        2,
        AcademicFeed.assessments,
      ),
      'academic' when key.contains('resource') => (1, null),
      'academic' => (2, AcademicFeed.assignments),
      'communications' when MessagingScope.isAvailable(context) => (
        messagesIndex,
        null,
      ),
      _ => null,
    };
    if (target == null) return false;
    setState(() {
      index = target.$1;
      if (target.$2 case final feed?) _workFeed = feed;
      _navCompact.value = false;
    });
    return true;
  }

  /// The bar is compact while the student scrolls down a page, and full
  /// again as soon as they scroll back up or touch it - as on the teacher's.
  final _navCompact = ValueNotifier<bool>(false);

  /// The tab the helper was opened from, to go back to.
  int _beforeHelper = 0;

  /// Where the helper is among the tabs, as last built; and a lesson to
  /// start a chat about, when opened from one (ADR-0037).
  int? _helperIndex;
  final _openHelperWith = ValueNotifier<List<ChatReference>?>(null);

  void _askHelperAbout(String lessonId, String title) {
    final helper = _helperIndex;
    if (helper == null) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
    _openHelperWith.value = [
      ChatReference(kind: ChatReferenceKind.lesson, id: lessonId, title: title),
    ];
    setState(() {
      if (index != helper) _beforeHelper = index;
      index = helper;
    });
  }

  @override
  void dispose() {
    _navCompact.dispose();
    _openHelperWith.dispose();
    super.dispose();
  }

  bool _onScroll(UserScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;
    final compact = switch (notification.direction) {
      ScrollDirection.reverse => true,
      ScrollDirection.forward => false,
      ScrollDirection.idle => _navCompact.value,
    };
    _navCompact.value = compact;
    return false;
  }

  /// Opens the Plans screen, from wherever a plan is mentioned.
  Future<void> _openPlans(BuildContext context) async {
    final study = widget.study;
    if (study == null) return;
    await Navigator.of(context).pushOnce(
      MaterialPageRoute<void>(
        builder: (_) =>
            StudyPlansPage(study: study, subscriptions: widget.studyPlans),
      ),
    );
  }

  /// The plan as the helper shows it: its name, its AI tokens, and what the
  /// next plan adds - nothing to upgrade to on Studafy Max.
  Future<HelperPlan?> _helperPlan(BuildContext context) async {
    final study = widget.study;
    if (study == null) return null;
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

  /// The Subscription row on the student's profile.
  SubscriptionEntry? get _subscription {
    final study = widget.study;
    if (study == null) return null;
    return SubscriptionEntry(
      open: _openPlans,
      currentPlan: () async => studyPlanCopy[(await study.plan()).tier]!.name,
    );
  }

  /// Signed in, but not in any class yet.
  ///
  /// Every student starts here: they make an account before a teacher has
  /// sent them anything. Being in no class is an empty state, not a locked
  /// door, so the shell opens and says what to do next rather than refusing
  /// to load. The feeds are skipped rather than shown failing, because
  /// without a membership every one of them would error identically and say
  /// nothing useful.
  bool get _hasNoClassYet =>
      ActiveContextController.instance.membership == null;

  Future<void> _joinClass() async {
    final classes = widget.classes;
    if (classes == null) return;
    final joined = await Navigator.of(context).pushOnce<Object?>(
      MaterialPageRoute<void>(builder: (_) => JoinClassPage(classes: classes)),
    );
    if (joined == null || !mounted) return;
    // The server made the membership; this is how the client learns of it.
    await widget.session?.completeRemoteLogin(
      role: StudafyRole.student,
      consentAccepted: false,
      locale: Localizations.localeOf(context).languageCode,
    );
    if (mounted) setState(() {});
  }

  /// Supplies the class filter its options. Kept here rather than in the
  /// academic slice because only the shell may reach across features.
  Future<List<ClassChoice>> _classChoices() async {
    final classes = widget.classes;
    if (classes == null) return const [];
    final result = await classes.loadClasses();
    return result.fold(
      onSuccess: (items) => [
        for (final item in items)
          ClassChoice(id: item.id.value, name: item.name),
      ],
      onFailure: (_) => const [],
    );
  }

  @override
  Widget build(BuildContext context) {
    final repository = widget.academic;
    final studentId = ActiveContextController.instance.selectedStudent?.id;
    final messaging = MessagingScope.isAvailable(context);
    final assistant = widget.studyAssistant;
    // Today, Lessons, Work, then the two optional tabs in that order.
    final messagesIndex = 3 + (assistant == null ? 0 : 1);
    final pages = <Widget>[
      StudentTodayPage(
        academic: repository,
        onWork: () => setState(() => index = 2),
        onNotebook: () => setState(() => index = 1),
        classes: widget.classes,
        onJoinClass: widget.classes == null ? null : _joinClass,
        subscription: _subscription,
        onOpenNotification: _openNotification,
      ),
      // Lessons are free (2026-09-27): every class, its lessons by date and
      // the student's own notebook for it.
      if (widget.study != null && widget.classes != null)
        StudentLessonsPage(
          classes: widget.classes!,
          academic: repository,
          study: widget.study!,
          studyPlans: widget.studyPlans,
          uploads: widget.fileUploads,
          schoolId: ActiveContextController.instance.membership?.schoolId,
          onAskHelper: assistant == null ? null : _askHelperAbout,
        )
      else
        AcademicOverviewPage(
          repository: repository,
          studentId: studentId,
          initialFeed: AcademicFeed.content,
          availableFeeds: const [AcademicFeed.content],
          loadClassChoices: widget.classes == null ? null : _classChoices,
        ),
      AcademicOverviewPage(
        // Re-keyed when a notification picks the tab Work opens on.
        key: ValueKey(_workFeed),
        repository: repository,
        studentId: studentId,
        // A tab of its own, so a large title like the others, and no
        // profile button: that lives on Today.
        title: AppL10n.of(context).navWork,
        subtitle: AppL10n.of(context).workSubtitle,
        initialFeed: _workFeed,
        availableFeeds: const [
          AcademicFeed.assignments,
          AcademicFeed.assessments,
          AcademicFeed.grades,
          AcademicFeed.attendance,
          AcademicFeed.wellbeing,
        ],
        loadClassChoices: widget.classes == null ? null : _classChoices,
        onOpenAssessment: (id, title, _) =>
            openAssessmentForLearner(context, repository, id, title),
        // Only published work can be handed in; a draft is not the
        // student's to see as open.
        onOpenRecord: (record) async {
          final messenger = ScaffoldMessenger.of(context);
          final done = await Navigator.of(context).pushOnce<String>(
            MaterialPageRoute<String>(
              builder: (_) => SubmitWorkPage(
                repository: repository,
                assignmentId: record.id,
                assignmentTitle: record.title,
                canSubmit: record.state == 'published',
                deadline: record.deadline,
                instructions: record.detail,
                material: record.attachments,
                links: record.links,
                uploads: widget.fileUploads,
                schoolId: ActiveContextController.instance.membership?.schoolId,
                studentId: studentId,
              ),
            ),
          );
          if (done != null) {
            messenger.showMessage(done);
          }
        },
      ),
      if (assistant != null)
        StudyAssistantPage(
          // Full screen, like a chat: the bar is away while it is open.
          onBack: () => setState(() => index = _beforeHelper),
          openWith: _openHelperWith,
          assistant: assistant,
          chats: widget.studyChats,
          switchedOn: switch (widget.study) {
            final study? => () async => (await study.plan()).assistantOn,
            null => null,
          },
          abilities: switch (widget.study) {
            final study? => () async {
              final plan = await study.plan();
              return HelperAbilities(
                ask: plan.assistantOn,
                classMaterial: plan.classMaterialOn,
                photos: plan.helperPhotosOn,
              );
            },
            null => null,
          },
          pickReferences: switch ((widget.classes, widget.study)) {
            (final classes?, final study?) =>
              (context, current) => pickStudyReferences(
                context,
                classes: classes,
                academic: repository,
                study: study,
                current: current,
              ),
            _ => null,
          },
          uploads: widget.fileUploads,
          schoolId: ActiveContextController.instance.membership?.schoolId,
          attachmentSource: pickPlatformAttachment,
          onPlanLimit: switch (widget.study) {
            final study? => (context, code) async {
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
                // Photos to the helper are Studafy Plus.
                needs: StudyPlanTier.plus,
                onUpgrade: () => Navigator.of(context).pushOnce(
                  MaterialPageRoute<void>(
                    builder: (_) => StudyPlansPage(
                      study: study,
                      subscriptions: widget.studyPlans,
                    ),
                  ),
                ),
              );
            },
            null => null,
          },
          plan: widget.study == null ? null : () => _helperPlan(context),
          onUpgrade: widget.study == null ? null : () => _openPlans(context),
        ),
      if (messaging)
        ConversationsPage(
          visible: index == messagesIndex,
          asRole: MessagingRole.student,
        ),
    ];
    final helper = pages.indexWhere((page) => page is StudyAssistantPage);
    final helperIndex = helper < 0 ? null : helper;
    _helperIndex = helperIndex;
    final classes = widget.classes;
    if (_hasNoClassYet && classes != null) {
      return Scaffold(
        body: SafeArea(
          child: _NoClassYet(
            onJoin: _joinClass,
            actions: [AccountButton(subscription: _subscription)],
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: studafyCanvas,
      // Joining another class is on Today, beside the class list, rather
      // than a floating button that sat over the cards and the bar.
      body: NotificationListener<UserScrollNotification>(
        onNotification: _onScroll,
        child: LazyIndexedStack(
          index: index,
          // The inbox acknowledges delivery while out of sight.
          builtAhead: {if (messaging) messagesIndex},
          children: pages,
        ),
      ),
      // The helper is a chat and has the whole screen; its back arrow
      // returns to the tab it was opened from.
      bottomNavigationBar: index == helperIndex
          ? null
          : ValueListenableBuilder<bool>(
              // Only the bar follows scrolling; the tabs are not rebuilt.
              valueListenable: _navCompact,
              builder: (context, compact, _) => StudafyNavigationBar(
                selectedIndex: index,
                compact: compact,
                onInteract: () {
                  _navCompact.value = false;
                },
                onSelected: (value) => setState(() {
                  if (value == helperIndex) _beforeHelper = index;
                  index = value;
                  _navCompact.value = false;
                }),
                items: [
                  StudafyNavItem(
                    AppL10n.of(context).navToday,
                    Icons.home_outlined,
                    Icons.home_rounded,
                  ),
                  StudafyNavItem(
                    AppL10n.of(context).feedContent,
                    Icons.auto_stories_outlined,
                    Icons.auto_stories_rounded,
                  ),
                  StudafyNavItem(
                    AppL10n.of(context).navWork,
                    Icons.assignment_outlined,
                    Icons.assignment_rounded,
                  ),
                  if (assistant != null)
                    StudafyNavItem(
                      AppL10n.of(context).studyAssistantTab,
                      Icons.auto_awesome_outlined,
                      Icons.auto_awesome_rounded,
                    ),
                  if (messaging)
                    StudafyNavItem(
                      AppL10n.of(context).navMessages,
                      Icons.send_outlined,
                      Icons.send_rounded,
                    ),
                ],
                accent: studafyNavy,
              ),
            ),
    );
  }
}

/// The student home before they are in any class.
///
/// Deliberately the whole screen rather than a banner over empty feeds: a
/// grades tab and an assignments tab that are both empty for the same reason
/// tell a new student nothing, and every one of them would have to explain
/// the same single next step.
class _NoClassYet extends StatelessWidget {
  const _NoClassYet({required this.onJoin, required this.actions});

  final Future<void> Function() onJoin;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 8, 8, 4),
          child: Row(
            children: [const StudafyLogo(size: 26), const Spacer(), ...actions],
          ),
        ),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: FeatureCard(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const IconBadge(icon: Icons.group_add_rounded, size: 72),
                      const SizedBox(height: 20),
                      Text(
                        l10n.onboardingStudentTitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: studafyInk,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -.4,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        l10n.onboardingStudentBody,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: studafyMuted,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: onJoin,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                          ),
                          icon: const Icon(Icons.group_add_rounded),
                          label: Text(l10n.joinClassAction),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
