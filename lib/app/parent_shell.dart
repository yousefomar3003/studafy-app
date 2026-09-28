import 'package:flutter/material.dart';

import '../core/feedback.dart';
import '../core/studafy_design.dart';
import '../core/studafy_domain.dart';
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
import '../features/messaging/presentation/conversations_page.dart';
import '../features/notifications/presentation/notifications_page.dart';
import '../l10n/generated/app_l10n.dart';
import 'account_hub_page.dart';

/// The parent's app: their children's day, schoolwork, Family+ insights,
/// updates and messages. Composed here because it draws on several features.
class ParentShell extends StatefulWidget {
  const ParentShell({
    super.key,
    required this.academic,
    this.insights,
    this.familyPlus,
  });
  final AcademicRepository academic;

  /// Buying Family+ for a child. Null in builds with no store; the offer is
  /// then described but cannot be bought.
  final ParentSubscriptionRepository? familyPlus;

  /// Family+. Null in builds with no backend, and the tab is then absent
  /// rather than present and always failing.
  final FamilyInsightsInteractor? insights;
  @override
  State<ParentShell> createState() => _ParentShellState();
}

class _ParentShellState extends State<ParentShell> {
  int index = 0;

  @override
  void initState() {
    super.initState();
    ActiveContextController.instance.addListener(_contextChanged);
  }

  @override
  void dispose() {
    ActiveContextController.instance.removeListener(_contextChanged);
    super.dispose();
  }

  // The Learning tab follows the selected child.
  void _contextChanged() {
    if (mounted) setState(() {});
  }

  /// The last two tabs, whose positions move by one when Family+ is absent.
  int get _updatesIndex => widget.insights == null ? 2 : 3;
  int get _messagesIndex => _updatesIndex + 1;

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

  @override
  Widget build(BuildContext context) => _remote(context);

  /// Real builds: every tab is on authoritative /v1 data.
  ///
  /// Family+ is the paid tab. It appears for everyone but the server refuses
  /// the data without a live subscription, so the screen shows the offer
  /// rather than the insights - the paywall is not a client-side decision.
  Widget _remote(BuildContext context) => Scaffold(
    body: IndexedStack(
      index: index,
      children: [
        FamilyHomePage(
          actions: const [AccountButton()],
          // Meetings with the teacher, on Google Meet.
          sections: const [UpcomingMeetingsSection()],
          onOpenChild: _selectChild,
        ),
        AcademicOverviewPage(
          key: ValueKey(ActiveContextController.instance.selectedStudent?.id),
          // Which child this is about, and a way to switch to another.
          actions: [
            LinkedChildSwitcher(onSelect: _selectChild),
            const AccountButton(),
          ],
          repository: widget.academic,
          studentId: ActiveContextController.instance.selectedStudent?.id,
          initialFeed: AcademicFeed.assignments,
          // Work comes first now: a guardian of a young child is not only
          // reading the record, they are the one handing the work in.
          // What the child sees, bar wellbeing: those notes can record
          // concerns about the home, and are not shared with guardians.
          availableFeeds: const [
            AcademicFeed.assignments,
            AcademicFeed.assessments,
            AcademicFeed.content,
            AcademicFeed.grades,
            AcademicFeed.attendance,
          ],
          // Children with no device of their own hand work in from a parent's
          // phone. The server authorises it on the verified guardian link and
          // records which guardian acted.
          onOpenRecord: (record) async {
            final child = ActiveContextController.instance.selectedStudent;
            if (child == null) return;
            final messenger = ScaffoldMessenger.of(context);
            final done = await Navigator.of(context).push<String>(
              MaterialPageRoute<String>(
                builder: (_) => SubmitWorkPage(
                  repository: widget.academic,
                  assignmentId: record.id,
                  assignmentTitle: record.title,
                  canSubmit: record.state == 'published',
                  instructions: record.detail,
                  material: record.attachments,
                  schoolId: child.schoolId,
                  studentId: child.id,
                ),
              ),
            );
            if (done != null) {
              messenger.showMessage(done);
            }
          },
        ),
        if (widget.insights != null)
          _InsightsTab(
            insights: widget.insights!,
            familyPlus: widget.familyPlus,
            childName:
                ActiveContextController.instance.selectedStudent?.displayName ??
                '',
            onSelectChild: _selectChild,
            // Keyed so switching child reloads rather than showing the
            // previous child's record under the new name.
            studentId: ActiveContextController.instance.selectedStudent?.id,
          ),
        // Both re-read when their tab comes into view: an IndexedStack keeps
        // every page alive, so a page that only loads in initState shows
        // whatever was true at launch for the rest of the session.
        NotificationsPage(visible: index == _updatesIndex),
        ConversationsPage(
          visible: index == _messagesIndex,
          asRole: MessagingRole.guardian,
        ),
      ],
    ),
    bottomNavigationBar: StudafyNavigationBar(
      selectedIndex: index,
      onSelected: (value) => setState(() => index = value),
      items: [
        StudafyNavItem(
          AppL10n.of(context).navToday,
          Icons.home_outlined,
          Icons.home_rounded,
        ),
        StudafyNavItem(
          AppL10n.of(context).navLearning,
          Icons.menu_book_outlined,
          Icons.menu_book_rounded,
        ),
        if (widget.insights != null)
          StudafyNavItem(
            AppL10n.of(context).insightsTitle,
            Icons.insights_outlined,
            Icons.insights_rounded,
          ),
        StudafyNavItem(
          AppL10n.of(context).navUpdates,
          Icons.notifications_outlined,
          Icons.notifications_rounded,
        ),
        StudafyNavItem(
          AppL10n.of(context).navMessages,
          Icons.forum_outlined,
          Icons.forum_rounded,
        ),
      ],
      accent: studafyNavy,
    ),
  );
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
  });

  final FamilyInsightsInteractor insights;
  final ParentSubscriptionRepository? familyPlus;
  final String childName;
  final String? studentId;
  final ValueChanged<GuardianChild> onSelectChild;

  @override
  Widget build(BuildContext context) {
    final id = studentId;
    if (id == null) {
      return Scaffold(
        backgroundColor: studafyCanvas,
        appBar: AppBar(
          backgroundColor: Colors.white,
          title: Text(AppL10n.of(context).insightsTitle),
          actions: const [AccountButton()],
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: StudafyStatusCard(
              icon: Icons.child_care_outlined,
              title: AppL10n.of(context).insightsNoChildTitle,
              message: AppL10n.of(context).insightsNoChildBody,
            ),
          ),
        ),
      );
    }
    final actions = [
      LinkedChildSwitcher(onSelect: onSelectChild),
      const AccountButton(),
    ];
    // Keyed by child, so switching child checks that child's Family+.
    return FamilyPlusGate(
      key: ValueKey(id),
      subscriptions: familyPlus,
      studentId: id,
      childName: childName,
      actions: actions,
      insights: FamilyInsightsPage(
        insights: insights,
        studentId: id,
        actions: actions,
      ),
    );
  }
}
