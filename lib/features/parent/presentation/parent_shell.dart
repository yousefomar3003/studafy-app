part of '../../../parent_features.dart';

class ParentShell extends StatefulWidget {
  const ParentShell({super.key, required this.academic, this.insights});
  final AcademicRepository academic;

  /// Family+. Null in builds with no backend, and the tab is then absent
  /// rather than present and always failing.
  final FamilyInsightsInteractor? insights;
  @override
  State<ParentShell> createState() => _ParentShellState();
}

class _ParentShellState extends State<ParentShell> {
  int index = 0;
  final homeKey = GlobalKey<ParentHomePageState>();

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
          onOpenChild: (child) =>
              ActiveContextController.instance.selectStudent(
                StudentSummary(
                  id: child.studentId,
                  studafyId: '',
                  displayName: child.studentName,
                  verified: child.isVerified,
                  // A guardian holds no membership, so this is the only
                  // school the app ever learns for them. Messaging needs it
                  // to know whose teachers they may write to.
                  schoolId: child.schoolId,
                ),
              ),
        ),
        AcademicOverviewPage(
          key: ValueKey(ActiveContextController.instance.selectedStudent?.id),
          actions: const [AccountButton()],
          repository: widget.academic,
          studentId: ActiveContextController.instance.selectedStudent?.id,
          initialFeed: AcademicFeed.assignments,
          // Work comes first now: a guardian of a young child is not only
          // reading the record, they are the one handing the work in.
          availableFeeds: const [
            AcademicFeed.assignments,
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
                  schoolId: child.schoolId,
                  studentId: child.id,
                ),
              ),
            );
            if (done != null) {
              messenger.showSnackBar(SnackBar(content: Text(done)));
            }
          },
        ),
        if (widget.insights != null)
          _InsightsTab(
            insights: widget.insights!,
            // Keyed so switching child reloads rather than showing the
            // previous child's record under the new name.
            studentId: ActiveContextController.instance.selectedStudent?.id,
          ),
        // Both re-read when their tab comes into view: an IndexedStack keeps
        // every page alive, so a page that only loads in initState shows
        // whatever was true at launch for the rest of the session.
        NotificationsPage(visible: index == _updatesIndex),
        ConversationsPage(visible: index == _messagesIndex),
      ],
    ),
    bottomNavigationBar: StudafyNavigationBar(
      selectedIndex: index,
      onSelected: (value) => setState(() => index = value),
      items: [
        StudafyNavItem(
          StudafyLocalizations.of(context).text('today'),
          Icons.home_outlined,
          Icons.home_rounded,
        ),
        StudafyNavItem(
          StudafyLocalizations.of(context).text('learning'),
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
          StudafyLocalizations.of(context).text('updates'),
          Icons.notifications_outlined,
          Icons.notifications_rounded,
        ),
        StudafyNavItem(
          StudafyLocalizations.of(context).text('messages'),
          Icons.forum_outlined,
          Icons.forum_rounded,
        ),
      ],
      accent: _navy,
    ),
  );
}

/// The Family+ tab.
///
/// With no child selected there is nothing to report on, which is a different
/// state from "you have not paid" and says so.
class _InsightsTab extends StatelessWidget {
  const _InsightsTab({required this.insights, required this.studentId});

  final FamilyInsightsInteractor insights;
  final String? studentId;

  @override
  Widget build(BuildContext context) {
    final id = studentId;
    if (id == null) {
      return Scaffold(
        backgroundColor: _canvas,
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
    return FamilyInsightsPage(
      key: ValueKey(id),
      insights: insights,
      studentId: id,
      actions: const [AccountButton()],
    );
  }
}
