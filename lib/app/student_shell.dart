import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;

import '../core/device_settings.dart';
import '../core/feedback.dart';
import '../core/file_upload_repository.dart';
import '../core/lazy_indexed_stack.dart';
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
import '../features/study_assistant/application/study_assistant_interactor.dart';
import '../features/study_assistant/domain/study_assistant_repository.dart';
import '../features/study_assistant/presentation/study_assistant_page.dart';
import '../l10n/generated/app_l10n.dart';
import 'account_hub_page.dart';
import 'app_dependencies.dart';
import 'assessment_navigation.dart';
import 'school_messaging_switch.dart';
import 'student_helper_needs_class.dart';
import 'student_lessons_page.dart';
import 'student_no_class_yet.dart';
import 'student_study_actions.dart';
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
    this.settings,
  });

  /// The shell as the app builds it, from the composition root.
  factory StudentShell.withDependencies(AppDependencies deps) => StudentShell(
    academic: deps.academic,
    classes: deps.classes,
    studyPlans: deps.studyPlans,
    study: deps.study,
    session: deps.session,
    studyAssistant: deps.studyAssistant,
    studyChats: deps.studyChats,
    fileUploads: deps.fileUploads,
    settings: deps.deviceSettings,
  );

  /// Where this device remembers that the join-a-class step was passed.
  /// Null keeps it for this run only.
  final DeviceSettingsStore? settings;

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
    unawaited(_readClassStep());
    // A class joined anywhere in the app brings its tabs in with it.
    _member = ActiveContextController.instance.membership?.id;
    ActiveContextController.instance.addListener(_contextChanged);
    // A plan bought or restored unlocks what the tabs offer at once.
    widget.studyPlans?.addEntitlementListener(_entitlementChanged);
  }

  String? _member;

  void _contextChanged() {
    final member = ActiveContextController.instance.membership?.id;
    if (member == _member || !mounted) return;
    _member = member;
    setState(() => index = 0);
    unawaited(_loadPlan());
  }

  void _entitlementChanged() => unawaited(_loadPlan());

  /// The join-a-class step after sign-up, passed or not on this device.
  late final _classStep = StudentClassStep(widget.settings);

  Future<void> _readClassStep() async {
    await _classStep.read();
    if (mounted) setState(() {});
  }

  Future<void> _skipClassStep() async {
    setState(() => index = 0);
    await _classStep.pass();
    if (mounted) setState(() {});
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

  /// The AI Tutor tab without the Tutor: the AI tools are on for this
  /// server, but it does not yet know this account as a student (ADR-0045),
  /// so the tab says what to do. With AI off for everyone it stays hidden.
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
    // In no class there is no work, no lessons and no inbox to open.
    if (_independent) return false;
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
    ActiveContextController.instance.removeListener(_contextChanged);
    widget.studyPlans?.removeEntitlementListener(_entitlementChanged);
    _navCompact.dispose();
    _openHelperWith.dispose();
    super.dispose();
  }

  /// Opens the AI Tutor tab, remembering where the student came from.
  void _openTutor() {
    final helper = _helperIndex;
    if (helper == null) return;
    setState(() {
      if (index != helper) _beforeHelper = index;
      index = helper;
    });
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

  /// What the study tools open. Null in the preview shell, with no study
  /// service behind it.
  StudentStudyActions? get _actions => switch (widget.study) {
    final study? => StudentStudyActions(
      study: study,
      studyPlans: widget.studyPlans,
    ),
    null => null,
  };

  /// The Subscription row on the student's profile. The plans are the AI
  /// study tools, so it is there only when they are.
  SubscriptionEntry? get _subscription =>
      _aiOn ? _actions?.subscription() : null;

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

  /// A student in no class (ADR-0045): Today, the Notebook and the AI Tutor.
  /// The preview shell, with no class service, keeps its usual tabs.
  bool get _independent => _hasNoClassYet && widget.classes != null;

  Future<void> _joinClass() async {
    final classes = widget.classes;
    if (classes == null) return;
    final joined = await Navigator.of(context).pushOnce<Object?>(
      MaterialPageRoute<void>(builder: (_) => JoinClassPage(classes: classes)),
    );
    if (joined == null || !mounted) return;
    unawaited(_skipClassStep());
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
    final classes = widget.classes;
    // Signed up, not in a class, and the join step not yet passed on this
    // device: the step, once, with "Skip for now" (ADR-0045).
    if (_hasNoClassYet && classes != null && !_classStep.known) {
      // A moment, while this device says whether the step was passed.
      return const Scaffold(backgroundColor: studafyCanvas);
    }
    if (_hasNoClassYet && classes != null && !_classStep.done) {
      return Scaffold(
        body: SafeArea(
          child: StudentNoClassYet(
            onJoin: _joinClass,
            onSkip: _skipClassStep,
            actions: [AccountButton(subscription: _subscription)],
          ),
        ),
      );
    }
    final independent = _independent;
    final messaging = !independent && MessagingScope.isAvailable(context);
    readMessagingSwitch();
    // Where the school has messaging off, the tab is its announcements.
    final messages = messagingOn;
    final assistant = _helperOn ? widget.studyAssistant : null;
    final helperTab = _helperTab;
    final study = widget.study;
    final actions = _actions;
    final today = StudentTodayPage(
      academic: repository,
      onWork: () => setState(() => index = 2),
      onNotebook: () => setState(() => index = 1),
      classes: widget.classes,
      onJoinClass: widget.classes == null ? null : _joinClass,
      subscription: _subscription,
      onOpenNotification: _openNotification,
      independent: independent,
      study: study,
      onOpenTutor: assistant == null ? null : _openTutor,
      onOpenNotebook: actions == null
          ? null
          : independent
          ? () => setState(() => index = 1)
          : () => actions.openNotebook(context, inClass: true),
      onPractise: actions == null
          ? null
          : (kind) =>
                actions.openPractice(context, kind, inClass: !independent),
    );
    // Today, Lessons, Work, then the two optional tabs in that order; in no
    // class, Today, the Notebook and the AI Tutor.
    final messagesIndex = 3 + (helperTab ? 1 : 0);
    final pages = <Widget>[
      today,
      if (independent && actions != null)
        actions.notebookTab()
      else if (independent)
        const SizedBox.shrink()
      // Lessons are free (2026-09-27): every class, its lessons by date and
      // the student's own notebook for it.
      else if (widget.study != null && widget.classes != null)
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
      if (!independent)
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
                  schoolId:
                      ActiveContextController.instance.membership?.schoolId,
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
          abilities: actions?.abilities,
          pickReferences: switch ((widget.classes, actions)) {
            (final classes?, final actions?) => (
              context,
              current,
            ) => actions.pickReferences(context, current, classes, repository),
            _ => null,
          },
          uploads: widget.fileUploads,
          schoolId: ActiveContextController.instance.membership?.schoolId,
          attachmentSource: pickPlatformAttachment,
          onPhotoToNotes: actions?.photoToNotes,
          onPlanLimit: actions?.planLimit,
          plan: actions == null ? null : () => actions.helperPlan(context),
          onUpgrade: actions == null ? null : () => actions.openPlans(context),
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
    final l10n = AppL10n.of(context);
    final items = <StudafyNavItem>[
      StudafyNavItem(l10n.navToday, Icons.home_outlined, Icons.home_rounded),
      if (independent)
        StudafyNavItem(
          l10n.todayToolNotebook,
          Icons.menu_book_outlined,
          Icons.menu_book_rounded,
        )
      else ...[
        StudafyNavItem(
          l10n.feedContent,
          Icons.auto_stories_outlined,
          Icons.auto_stories_rounded,
        ),
        StudafyNavItem(
          l10n.navWork,
          Icons.assignment_outlined,
          Icons.assignment_rounded,
        ),
      ],
      if (helperTab)
        StudafyNavItem(
          l10n.studyAssistantTab,
          Icons.auto_awesome_outlined,
          Icons.auto_awesome_rounded,
        ),
      if (messaging && messages)
        StudafyNavItem(
          l10n.navMessages,
          Icons.send_outlined,
          Icons.send_rounded,
        )
      else if (messaging)
        StudafyNavItem(
          l10n.navAnnouncementsTab,
          Icons.campaign_outlined,
          Icons.campaign_rounded,
        ),
    ];
    final selected = index < pages.length ? index : 0;
    return Scaffold(
      backgroundColor: studafyCanvas,
      // Joining another class is on Today, beside the class list, rather
      // than a floating button that sat over the cards and the bar.
      body: NotificationListener<UserScrollNotification>(
        onNotification: _onScroll,
        child: LazyIndexedStack(
          index: selected,
          // The inbox acknowledges delivery while out of sight.
          builtAhead: {if (messaging) messagesIndex},
          children: pages,
        ),
      ),
      // The AI Tutor is a chat and has the whole screen; its back arrow
      // returns to the tab it was opened from.
      bottomNavigationBar: selected == helperIndex
          ? null
          : ValueListenableBuilder<bool>(
              // Only the bar follows scrolling; the tabs are not rebuilt.
              valueListenable: _navCompact,
              builder: (context, compact, _) => StudafyNavigationBar(
                selectedIndex: selected,
                compact: compact,
                onInteract: () {
                  _navCompact.value = false;
                },
                onSelected: (value) => setState(() {
                  if (value == helperIndex) _beforeHelper = index;
                  index = value;
                  _navCompact.value = false;
                }),
                items: items,
                accent: studafyNavy,
              ),
            ),
    );
  }
}
