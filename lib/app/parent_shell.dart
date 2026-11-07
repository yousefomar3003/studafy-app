import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;

import '../core/feedback.dart';
import '../core/lazy_indexed_stack.dart';
import '../core/navigation.dart';
import '../core/studafy_components.dart';
import '../core/studafy_design.dart';
import '../core/studafy_domain.dart';
import '../core/studafy_formatting.dart';
import '../core/tab_back_scope.dart';
import '../features/academic/domain/academic_repository.dart';
import '../features/academic/presentation/academic_overview_page.dart';
import '../features/academic/presentation/submit_work_page.dart';
import '../features/family/domain/family.dart';
import '../features/family/presentation/family_home_page.dart';
import '../features/family_insights/application/family_insights_interactor.dart';
import '../features/family_insights/domain/parent_subscription_repository.dart';
import '../features/family_insights/presentation/family_plus_prompts.dart';
import '../features/meetings/presentation/upcoming_meetings_section.dart';
import '../features/messaging/domain/messaging.dart';
import '../features/messaging/presentation/announcements_page.dart';
import '../features/messaging/presentation/conversations_page.dart';
import '../features/messaging/presentation/messaging_scope.dart';
import '../features/notifications/domain/notification.dart';
import '../features/notifications/presentation/notification_tap_opener.dart';
import '../features/notifications/presentation/notifications_page.dart';
import '../features/notifications/presentation/notifications_scope.dart';
import '../l10n/generated/app_l10n.dart';
import 'account/account_switching.dart';
import 'account/managed_children_section.dart';
import 'account_hub_page.dart';
import 'assessment_navigation.dart';
import 'notification_routes.dart';
import 'parent_insights_tab.dart';
import 'school_announcements_entry.dart';
import 'teacher_school_links.dart';

/// The parent's app: their children's day, schoolwork, Family+ insights,
/// announcements and messages. Composed here because it draws on several
/// features.
class ParentShell extends StatefulWidget {
  const ParentShell({
    super.key,
    required this.academic,
    this.insights,
    this.familyPlus,
  });
  final AcademicRepository academic;

  /// Buying Family+. Null in builds with no store; the offer is then
  /// described but cannot be bought.
  final ParentSubscriptionRepository? familyPlus;

  /// Family+. Null in builds with no backend, and the tab is then absent
  /// rather than present and always failing.
  final FamilyInsightsInteractor? insights;
  @override
  State<ParentShell> createState() => _ParentShellState();
}

enum _Tab { today, learning, familyPlus, announcements, messages }

class _ParentShellState extends State<ParentShell> {
  int index = 0;

  /// The children the parent follows, as Today last read them. Learning and
  /// Announcements filter by the same list.
  List<GuardianChild> _children = const [];
  int _unread = 0;

  /// Learning shows every child together - after opening a notification
  /// about schoolwork, which does not say which child it is about.
  bool _learningShowsAll = false;

  /// The bar is compact while scrolling down, full again on any touch.
  final _navCompact = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    ActiveContextController.instance.addListener(_contextChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadUnread());
  }

  @override
  void dispose() {
    _navCompact.dispose();
    ActiveContextController.instance.removeListener(_contextChanged);
    super.dispose();
  }

  // The Learning and Family+ tabs follow the selected child.
  void _contextChanged() {
    if (mounted) setState(() {});
  }

  List<_Tab> get _tabs => [
    _Tab.today,
    _Tab.learning,
    if (widget.insights != null) _Tab.familyPlus,
    // Announcements arrive through messaging; a build without it has
    // neither tab rather than two that always fail.
    if (MessagingScope.isAvailable(context)) _Tab.announcements,
    if (_messagingOn) _Tab.messages,
  ];

  /// Messages, only where a child's school has messaging switched on: the
  /// server refuses every new conversation and message elsewhere (DL-049),
  /// so a tab there would be a door that never opens. Each verified link
  /// says whether its school has it on.
  bool get _messagingOn =>
      MessagingScope.isAvailable(context) &&
      _verified.any((child) => child.messagingEnabled);

  void _go(_Tab tab) {
    final at = _tabs.indexOf(tab);
    if (at >= 0) {
      setState(() {
        index = at;
        _navCompact.value = false;
      });
    }
  }

  List<GuardianChild> get _verified => [
    for (final child in _children)
      if (child.isVerified) child,
  ];

  void _selectChild(GuardianChild child) =>
      ActiveContextController.instance.selectStudent(
        StudentSummary(
          id: child.studentId,
          studafyId: '',
          displayName: child.studentName,
          verified: child.isVerified,
          // A guardian holds no membership, so this is the only school the
          // app ever learns for them. Messaging needs it to know whose
          // teachers they may write to.
          schoolId: child.schoolId,
        ),
      );

  Future<void> _loadUnread() async {
    if (!mounted) return;
    final notifications = NotificationsScope.maybeOf(context);
    if (notifications == null) return;
    final result = await notifications.unreadCount();
    if (!mounted) return;
    setState(
      () => _unread = result.fold(onSuccess: (n) => n, onFailure: (_) => 0),
    );
  }

  /// Updates, now Notifications, open from Today's header. A tap on one goes
  /// to what it is about.
  Future<void> _openNotifications() async {
    await Navigator.of(context).pushOnce(
      MaterialPageRoute<void>(
        builder: (_) => NotificationsPage(onOpen: _openNotification),
      ),
    );
    unawaited(_loadUnread());
  }

  /// The feed Learning opens on, and the piece of work a notification opens.
  FeedTarget? _learningTarget;

  /// Opens exactly what a notification is about: the piece of work, test or
  /// mark (for whichever child it is), the conversation, or the tab.
  bool _openNotification(NotificationItem item) {
    VoidCallback? tab(_Tab tab) => _tabs.contains(tab) ? () => _go(tab) : null;
    return openNotificationIn(
      context,
      item,
      NotificationDestinations(
        schoolAnnouncements: openSchoolAnnouncementsIn(context),
        // A teacher using the app as a parent: a school's request is theirs.
        schoolLinks: openSchoolLinkIn(context),
        feed: (target) {
          // The notification names no child, so Learning shows them all,
          // each labelled - and finds the work whoever's it is.
          setState(() {
            _learningShowsAll = _verified.length > 1;
            _learningTarget = _learningFeeds.contains(target.feed)
                ? target
                : null;
          });
          _go(_Tab.learning);
        },
        messages: tab(_Tab.messages),
        announcements: tab(_Tab.announcements),
        meetings: tab(_Tab.today),
        family: tab(_Tab.today),
        plans: switch (tab(_Tab.familyPlus)) {
          final open? => (_) => open(),
          null => null,
        },
      ),
    );
  }

  /// What a guardian sees, bar wellbeing: those notes can record concerns
  /// about the home, and are not shared with guardians. Work comes first: a
  /// guardian of a young child is not only reading the record, they are the
  /// one handing the work in.
  static const _learningFeeds = [
    AcademicFeed.assignments,
    AcademicFeed.assessments,
    AcademicFeed.content,
    AcademicFeed.grades,
    AcademicFeed.attendance,
  ];

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

  Future<void> _handIn(AcademicRecord record, StudentChoice? student) async {
    final child =
        student?.id ?? ActiveContextController.instance.selectedStudent?.id;
    if (child == null) return;
    final schoolId = [
      for (final linked in _verified)
        if (linked.studentId == child) linked.schoolId,
    ].firstOrNull;
    final messenger = ScaffoldMessenger.of(context);
    // Children with no device of their own hand work in from a parent's
    // phone. The server authorises it on the verified guardian link and
    // records which guardian acted.
    final done = await Navigator.of(context).pushOnce<String>(
      MaterialPageRoute<String>(
        builder: (_) => SubmitWorkPage(
          repository: widget.academic,
          assignmentId: record.id,
          assignmentTitle: record.title,
          canSubmit: record.state == 'published',
          deadline: record.deadline,
          instructions: record.detail,
          material: record.attachments,
          links: record.links,
          schoolId: schoolId,
          studentId: child,
        ),
      ),
    );
    if (done != null) messenger.showMessage(done);
  }

  /// The Family+ tab, for [child] - or the child chosen, or the first.
  void _openFamilyPlus([GuardianChild? child]) {
    final chosen = ActiveContextController.instance.selectedStudent;
    child ??= chosen == null ? _verified.firstOrNull : null;
    if (child != null) _selectChild(child);
    _go(_Tab.familyPlus);
  }

  /// Family+ on a child's marks and attendance, when it is not theirs yet.
  Widget? _familyPlusNudge(AcademicFeed feed, String? id) {
    final child = _verified.where((c) => c.studentId == id).firstOrNull;
    const progress = {AcademicFeed.grades, AcademicFeed.attendance};
    if (child == null || !progress.contains(feed)) return null;
    return FamilyPlusNudge(
      key: ValueKey(id),
      subscriptions: widget.familyPlus,
      studentId: child.studentId,
      childName: child.studentName,
      onOpen: () => _openFamilyPlus(child),
    );
  }

  /// System back takes any other tab back to Today, and leaves the app
  /// only from Today.
  void _back() => setState(() {
    index = 0;
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

  /// The Subscription part of the parent's profile: only Restore purchases,
  /// for Family+, where Family+ is offered. The plans are on their own tab.
  SubscriptionEntry? get _subscription {
    final familyPlus = widget.familyPlus;
    if (familyPlus == null || widget.insights == null) return null;
    return SubscriptionEntry(restorePurchases: familyPlus.restorePurchases);
  }

  Widget _page(BuildContext context) {
    final l10n = AppL10n.of(context);
    final tabs = _tabs;
    if (index >= tabs.length) index = 0;
    final messaging = MessagingScope.isAvailable(context);
    final messagingOn = _messagingOn;
    final verified = _verified;
    final selected = ActiveContextController.instance.selectedStudent;
    final pages = <Widget>[
      FamilyHomePage(
        // The profile button is on Today only, beside Notifications - which
        // is where Updates went.
        actions: [
          NotificationBellButton(
            unread: _unread,
            label: studafyNumber(context, _unread),
            onPressed: _openNotifications,
          ),
          AccountButton(subscription: _subscription),
        ],
        quickActions: [
          FamilyQuickAction(
            icon: Icons.person_add_rounded,
            label: l10n.parentQuickLink,
            linksChild: true,
          ),
          FamilyQuickAction(
            icon: Icons.auto_stories_rounded,
            label: l10n.parentQuickLearning,
            onTap: () => _go(_Tab.learning),
          ),
          if (messaging)
            FamilyQuickAction(
              icon: Icons.campaign_rounded,
              label: l10n.parentQuickAnnouncements,
              onTap: () => _go(_Tab.announcements),
            ),
          if (messagingOn)
            FamilyQuickAction(
              icon: Icons.send_rounded,
              label: l10n.parentQuickMessages,
              onTap: () => _go(_Tab.messages),
            ),
        ],
        onChildrenChanged: (children) {
          if (mounted) setState(() => _children = children);
        },
        // Family+ while no child has it; meetings with the teacher, on
        // Google Meet; and the child accounts this parent created.
        sections: [
          if (widget.insights != null)
            FamilyPlusHomeCard(
              subscriptions: widget.familyPlus,
              studentIds: [for (final child in verified) child.studentId],
              onOpen: _openFamilyPlus,
            ),
          const UpcomingMeetingsSection(),
          const ManagedChildrenSection(),
        ],
        onOpenChild: _selectChild,
        onCreateChildAccount: switch (DeviceAccountsScope.maybeOf(context)) {
          final switcher? when switcher.canCreateChild =>
            () => openCreateChildAccount(context, switcher),
          _ => null,
        },
      ),
      if (verified.isEmpty)
        _NoChildYet(title: l10n.navLearning)
      else
        AcademicOverviewPage(
          // Only a different set of children, or a notification to open,
          // starts the page afresh. A child chosen elsewhere is followed in
          // place, keeping the open feed.
          key: ValueKey((
            [for (final child in verified) child.studentId].join(),
            _learningTarget,
          )),
          openRecordId: _learningTarget?.id,
          onRecordMissing: () => showNotificationGone(context),
          title: l10n.navLearning,
          subtitle: l10n.learningSubtitle,
          repository: widget.academic,
          students: [
            for (final child in verified)
              StudentChoice(
                id: child.studentId,
                name: child.studentName,
                schoolName: child.schoolName,
              ),
          ],
          studentId: _learningShowsAll ? null : selected?.id,
          onStudentChanged: (id) {
            final child = verified.where((c) => c.studentId == id).firstOrNull;
            _learningShowsAll = child == null;
            if (child != null) _selectChild(child);
          },
          initialFeed: _learningTarget?.feed ?? AcademicFeed.assignments,
          availableFeeds: _learningFeeds,
          onOpenStudentRecord: _handIn,
          feedBanner: widget.insights == null ? null : _familyPlusNudge,
          // Read-only: a parent sees the child's results, never sits it.
          onOpenAssessment: (id, title, student) => openAssessmentForLearner(
            context,
            widget.academic,
            id,
            title,
            studentId: student?.id ?? selected?.id,
            childName: student?.name ?? selected?.displayName,
          ),
        ),
      if (widget.insights != null)
        ParentInsightsTab(
          insights: widget.insights!,
          familyPlus: widget.familyPlus,
          childName: selected?.displayName ?? '',
          onSelectChild: _selectChild,
          severalChildren: verified.length > 1,
          // Keyed so switching child reloads rather than showing the
          // previous child's record under the new name.
          studentId: selected?.id,
        ),
      if (messaging)
        AnnouncementsPage(
          visible: tabs[index] == _Tab.announcements,
          sources: [
            for (final school in {for (final c in verified) c.schoolId})
              AnnouncementSource(
                schoolId: school,
                schoolName: verified
                    .firstWhere((c) => c.schoolId == school)
                    .schoolName,
                children: {
                  for (final c in verified)
                    if (c.schoolId == school) c.studentId: c.studentName,
                },
              ),
          ],
        ),
      // Re-read when its tab comes into view: it is built ahead, so it is
      // alive while hidden. Conversations only - announcements have their own tab.
      if (messagingOn)
        ConversationsPage(
          visible: tabs[index] == _Tab.messages,
          asRole: MessagingRole.guardian,
          showAnnouncements: false,
        ),
    ];
    return Scaffold(
      backgroundColor: studafyCanvas,
      body: NotificationListener<UserScrollNotification>(
        onNotification: _onScroll,
        child: LazyIndexedStack(
          index: index,
          // The inbox acknowledges delivery while out of sight.
          builtAhead: {if (messagingOn) tabs.indexOf(_Tab.messages)},
          children: pages,
        ),
      ),
      bottomNavigationBar: ValueListenableBuilder<bool>(
        // Only the bar follows scrolling; the tabs are not rebuilt.
        valueListenable: _navCompact,
        builder: (context, compact, _) => StudafyNavigationBar(
          selectedIndex: index,
          compact: compact,
          onInteract: () {
            _navCompact.value = false;
          },
          onSelected: (value) => setState(() {
            index = value;
            _navCompact.value = false;
          }),
          items: [
            for (final tab in tabs)
              switch (tab) {
                _Tab.today => StudafyNavItem(
                  l10n.navToday,
                  Icons.home_outlined,
                  Icons.home_rounded,
                ),
                _Tab.learning => StudafyNavItem(
                  l10n.navLearning,
                  Icons.auto_stories_outlined,
                  Icons.auto_stories_rounded,
                ),
                _Tab.familyPlus => StudafyNavItem(
                  l10n.insightsTitle,
                  Icons.insights_outlined,
                  Icons.insights_rounded,
                ),
                _Tab.announcements => StudafyNavItem(
                  l10n.navAnnouncementsTab,
                  Icons.campaign_outlined,
                  Icons.campaign_rounded,
                ),
                _Tab.messages => StudafyNavItem(
                  l10n.navMessages,
                  Icons.send_outlined,
                  Icons.send_rounded,
                ),
              },
          ],
        ),
      ),
    );
  }
}

/// A tab that needs a linked child before it has anything to show.
class _NoChildYet extends StatelessWidget {
  const _NoChildYet({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return Scaffold(
      body: Column(
        children: [
          StudafyLargeTitle(title: title),
          Expanded(
            child: Center(
              child: StudafyEmptyState(
                icon: Icons.family_restroom_rounded,
                title: l10n.learningNoChildrenTitle,
                message: l10n.learningNoChildrenBody,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
