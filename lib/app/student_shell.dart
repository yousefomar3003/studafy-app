import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;

import '../core/ai_usage.dart';
import '../core/feedback.dart';
import '../core/file_upload_repository.dart';
import '../core/lazy_indexed_stack.dart';
import '../core/material_selection.dart';
import '../core/navigation.dart';
import '../core/platform_attachment_source.dart';
import '../core/studafy_design.dart';
import '../core/studafy_domain.dart';
import '../core/tab_back_scope.dart';
import '../features/academic/domain/academic_repository.dart';
import '../features/academic/presentation/academic_overview_page.dart';
import '../features/academic/presentation/submit_work_page.dart';
import '../features/classes/application/class_list_interactor.dart';
import '../features/classes/presentation/join_class_page.dart';
import '../features/messaging/domain/messaging.dart';
import '../features/messaging/presentation/conversations_page.dart';
import '../features/messaging/presentation/messaging_scope.dart';
import '../features/notifications/domain/notification.dart';
import '../features/notifications/presentation/notification_tap_opener.dart';
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
import 'material_picker.dart';
import 'school_messaging_switch.dart';
import 'student_helper_needs_class.dart';
import 'student_lessons_page.dart';
import 'student_no_class_yet.dart';
import 'student_today_page.dart';

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

class _StudentShellState extends State<StudentShell>
    with SchoolMessagingSwitch {
  int index = 0;

  /// What the server says this student can use of the AI study tools.
  /// Null until it has said: nothing about them is shown before then.
  StudyPlan? _plan;

  @override
  void initState() {
    super.initState();
    unawaited(_loadPlan());
  }

  Future<void> _loadPlan() async {
    final study = widget.study;
    if (study == null) return;
    try {
      final plan = await study.plan();
      if (mounted) setState(() => _plan = plan);
    } on Object {
      // Unread, the tools stay hidden rather than offered and failing.
    }
  }

  /// The helper tab: a provider behind it, and the server offering it to
  /// this student. The preview shell, with no plans, shows it as built.
  bool get _helperOn =>
      widget.studyAssistant != null &&
      (widget.study == null || (_plan?.assistantOn ?? false));

  /// The helper tab without the helper: the AI tools are on for this
  /// server, but this student is in no class, so the tab says to join one
  /// (the server refuses the tools until then). With AI off for everyone
  /// the tab stays hidden, as before.
  bool get _helperNeedsClass =>
      !_helperOn &&
      widget.studyAssistant != null &&
      widget.study != null &&
      (_plan?.helperNeedsClass ?? false);

  /// Whether the bar has a helper tab, live or saying to join a class.
  bool get _helperTab => _helperOn || _helperNeedsClass;

  /// Any AI study tool, and so the plans that sell them.
  bool get _aiOn => widget.study != null && (_plan?.anyToolOn ?? false);

  /// The tab Work opens on; a notification about marks opens Grades.
  AcademicFeed _workFeed = AcademicFeed.assignments;

  /// Opens what a notification is about, in this student's app.
  bool _openNotification(NotificationItem item) {
    final key = item.templateKey;
    final messagesIndex = 3 + (_helperTab ? 1 : 0);
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

  /// The Subscription row on the student's profile. The plans are the AI
  /// study tools, so it is there only when they are.
  SubscriptionEntry? get _subscription {
    final study = widget.study;
    if (study == null || !_aiOn) return null;
    return SubscriptionEntry(
      open: _openPlans,
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
    // In a class now: the AI tools may be offered, and the class's school
    // says whether messaging is on.
    await _loadPlan();
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

  /// System back does what the helper's back arrow does, takes any other
  /// tab back to Today, and leaves the app only from Today.
  void _back() => setState(() {
    index = index == _helperIndex ? _beforeHelper : 0;
    _navCompact.value = false;
  });

  /// A tapped push opens what it is about, as a tap in the list does.
  @override
  Widget build(BuildContext context) => NotificationTapOpener(
    onOpen: _openNotification,
    child: TabBackScope(
      atFirstTab: index == 0,
      onBack: _back,
      child: _page(context),
    ),
  );

  Widget _page(BuildContext context) {
    final repository = widget.academic;
    final studentId = ActiveContextController.instance.selectedStudent?.id;
    final messaging = MessagingScope.isAvailable(context);
    readMessagingSwitch();
    // Where the school has messaging off, the tab is its announcements.
    final messages = messagingOn;
    final assistant = _helperOn ? widget.studyAssistant : null;
    final helperTab = _helperTab;
    // Today, Lessons, Work, then the two optional tabs in that order.
    final messagesIndex = 3 + (helperTab ? 1 : 0);
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
            (final classes?, final study?) => (context, current) async {
              final picked = await pickMaterials(
                context,
                MaterialPickRequest(
                  action: MaterialAction.helper,
                  initial: selectionOfReferences(current),
                  allowNotes: true,
                ),
                classes: classes,
                academic: repository,
                study: study,
              );
              return picked == null ? null : referencesOfSelection(picked);
            },
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
        )
      else if (helperTab)
        StudentHelperNeedsClass(
          onJoin: widget.classes == null ? null : _joinClass,
        ),
      if (messaging)
        ConversationsPage(
          visible: index == messagesIndex,
          asRole: MessagingRole.student,
          showMessages: messages,
        ),
    ];
    final helper = pages.indexWhere((page) => page is StudyAssistantPage);
    final helperIndex = helper < 0 ? null : helper;
    _helperIndex = helperIndex;
    final classes = widget.classes;
    if (_hasNoClassYet && classes != null) {
      return Scaffold(
        body: SafeArea(
          child: StudentNoClassYet(
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
                  if (helperTab)
                    StudafyNavItem(
                      AppL10n.of(context).studyAssistantTab,
                      Icons.auto_awesome_outlined,
                      Icons.auto_awesome_rounded,
                    ),
                  if (messaging && messages)
                    StudafyNavItem(
                      AppL10n.of(context).navMessages,
                      Icons.send_outlined,
                      Icons.send_rounded,
                    )
                  else if (messaging)
                    StudafyNavItem(
                      AppL10n.of(context).navAnnouncements,
                      Icons.campaign_outlined,
                      Icons.campaign_rounded,
                    ),
                ],
                accent: studafyNavy,
              ),
            ),
    );
  }
}
