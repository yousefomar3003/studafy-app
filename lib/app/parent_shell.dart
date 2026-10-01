import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;

import '../core/feedback.dart';
import '../core/navigation.dart';
import '../core/studafy_components.dart';
import '../core/studafy_design.dart';
import '../core/studafy_domain.dart';
import '../core/studafy_formatting.dart';
import '../features/academic/domain/academic_repository.dart';
import '../features/academic/presentation/academic_overview_page.dart';
import '../features/academic/presentation/submit_work_page.dart';
import '../features/family/domain/family.dart';
import '../features/family/presentation/family_home_page.dart';
import '../features/family/presentation/linked_child_switcher.dart';
import '../features/family_insights/application/family_insights_interactor.dart';
import '../features/family_insights/domain/parent_subscription_repository.dart';
import '../features/family_insights/presentation/family_insights_page.dart';
import '../features/family_insights/presentation/family_plus_gate.dart';
import '../features/meetings/presentation/upcoming_meetings_section.dart';
import '../features/messaging/domain/messaging.dart';
import '../features/messaging/presentation/announcements_page.dart';
import '../features/messaging/presentation/conversations_page.dart';
import '../features/messaging/presentation/messaging_scope.dart';
import '../features/notifications/domain/notification.dart';
import '../features/notifications/presentation/notifications_page.dart';
import '../features/notifications/presentation/notifications_scope.dart';
import '../l10n/generated/app_l10n.dart';
import 'account/account_switching.dart';
import 'account/managed_children_section.dart';
import 'account_hub_page.dart';

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
  bool _navCompact = false;

  @override
  void initState() {
    super.initState();
    ActiveContextController.instance.addListener(_contextChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadUnread());
  }

  @override
  void dispose() {
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
    if (MessagingScope.isAvailable(context)) ...[
      _Tab.announcements,
      _Tab.messages,
    ],
  ];

  void _go(_Tab tab) {
    final at = _tabs.indexOf(tab);
    if (at >= 0) {
      setState(() {
        index = at;
        _navCompact = false;
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

  bool _openNotification(NotificationItem item) {
    final key = item.templateKey;
    final tab = switch (key.split('.').first) {
      'academic' => _Tab.learning,
      'communications' when key.contains('announcement') => _Tab.announcements,
      'communications' => _Tab.messages,
      'billing' when widget.insights != null => _Tab.familyPlus,
      _ => _Tab.today,
    };
    if (tab == _Tab.learning && _verified.length > 1) {
      // The notification names no child, so show them all, each labelled.
      setState(() => _learningShowsAll = true);
    }
    _go(tab);
    return true;
  }

  bool _onScroll(UserScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;
    final compact = switch (notification.direction) {
      ScrollDirection.reverse => true,
      ScrollDirection.forward => false,
      ScrollDirection.idle => _navCompact,
    };
    if (compact != _navCompact) setState(() => _navCompact = compact);
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
          schoolId: schoolId,
          studentId: child,
        ),
      ),
    );
    if (done != null) messenger.showMessage(done);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final tabs = _tabs;
    if (index >= tabs.length) index = 0;
    final messaging = MessagingScope.isAvailable(context);
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
          const AccountButton(),
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
          if (messaging)
            FamilyQuickAction(
              icon: Icons.send_rounded,
              label: l10n.parentQuickMessages,
              onTap: () => _go(_Tab.messages),
            ),
        ],
        onChildrenChanged: (children) {
          if (mounted) setState(() => _children = children);
        },
        // Meetings with the teacher, on Google Meet; and the child
        // accounts this parent created.
        sections: const [UpcomingMeetingsSection(), ManagedChildrenSection()],
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
          key: ValueKey((
            [for (final child in verified) child.studentId].join(),
            selected?.id,
            _learningShowsAll,
          )),
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
          initialFeed: AcademicFeed.assignments,
          // Work comes first: a guardian of a young child is not only
          // reading the record, they are the one handing the work in. What
          // the child sees, bar wellbeing: those notes can record concerns
          // about the home, and are not shared with guardians.
          availableFeeds: const [
            AcademicFeed.assignments,
            AcademicFeed.assessments,
            AcademicFeed.content,
            AcademicFeed.grades,
            AcademicFeed.attendance,
          ],
          onOpenStudentRecord: _handIn,
        ),
      if (widget.insights != null)
        _InsightsTab(
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
      // Re-read when its tab comes into view: an IndexedStack keeps every
      // page alive. Conversations only - announcements have their own tab.
      if (messaging)
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
        child: IndexedStack(index: index, children: pages),
      ),
      bottomNavigationBar: StudafyNavigationBar(
        selectedIndex: index,
        compact: _navCompact,
        onInteract: () {
          if (_navCompact) setState(() => _navCompact = false);
        },
        onSelected: (value) => setState(() {
          index = value;
          _navCompact = false;
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
                l10n.navAnnouncements,
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

/// The Family+ tab.
///
/// With no child selected there is nothing to report on, which is a different
/// state from "you have not paid" and says so.
class _InsightsTab extends StatelessWidget {
  const _InsightsTab({
    required this.insights,
    required this.familyPlus,
    required this.childName,
    required this.studentId,
    required this.onSelectChild,
    required this.severalChildren,
  });

  final FamilyInsightsInteractor insights;
  final ParentSubscriptionRepository? familyPlus;
  final String childName;
  final String? studentId;
  final ValueChanged<GuardianChild> onSelectChild;
  final bool severalChildren;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final id = studentId;
    if (id == null) {
      return Scaffold(
        body: Column(
          children: [
            StudafyLargeTitle(title: l10n.insightsTitle),
            Expanded(
              child: Center(
                child: StudafyEmptyState(
                  icon: Icons.child_care_outlined,
                  title: l10n.insightsNoChildTitle,
                  message: l10n.insightsNoChildBody,
                ),
              ),
            ),
          ],
        ),
      );
    }
    // No profile button here: it is on Today. Which child, when there are
    // several - and, once subscribed, the plan.
    final switcher = [
      if (severalChildren) LinkedChildSwitcher(onSelect: onSelectChild),
    ];
    // Keyed by child, so switching child checks that child's Family+.
    return FamilyPlusGate(
      key: ValueKey(id),
      subscriptions: familyPlus,
      studentId: id,
      childName: childName,
      actions: switcher,
      insights: FamilyInsightsPage(
        insights: insights,
        studentId: id,
        actions: [
          ...switcher,
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: StudafyPillButton(
              icon: Icons.workspace_premium_rounded,
              label: l10n.familyPlusManagePlan,
              onPressed: () => Navigator.of(context).pushOnce(
                MaterialPageRoute<void>(
                  builder: (_) => Scaffold(
                    appBar: AppBar(title: Text(l10n.insightsTitle)),
                    body: FamilyPlusOffer(
                      subscriptions: familyPlus,
                      studentId: id,
                      childName: childName,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
