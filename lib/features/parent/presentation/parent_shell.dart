part of '../../../parent_features.dart';

class ParentShell extends StatefulWidget {
  const ParentShell({super.key, required this.academic});
  final AcademicRepository academic;
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

  @override
  Widget build(BuildContext context) =>
      StudafyRuntime.policy.requiresRemoteBackend
      ? _remote(context)
      : _synthetic(context);

  /// Real builds: every tab is on authoritative /v1 data. Paid Insights+
  /// stays out until its legal sign-off (§29); free progress lives on each
  /// child's card on the home tab.
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
                ),
              ),
        ),
        AcademicOverviewPage(
          key: ValueKey(ActiveContextController.instance.selectedStudent?.id),
          actions: const [AccountButton()],
          repository: widget.academic,
          studentId: ActiveContextController.instance.selectedStudent?.id,
          initialFeed: AcademicFeed.grades,
        ),
        const NotificationsPage(),
        const ConversationsPage(),
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

  /// The synthetic demo keeps the legacy screens on preview data.
  Widget _synthetic(BuildContext context) => Scaffold(
    body: IndexedStack(
      index: index,
      children: [
        ParentHomePage(key: homeKey),
        AcademicOverviewPage(
          repository: widget.academic,
          studentId: ActiveContextController.instance.selectedStudent?.id,
          initialFeed: AcademicFeed.grades,
        ),
        const ParentInsightsPage(),
        const ParentMessagesPage(initialTab: 1, updatesOnly: true),
        const ParentMessagesPage(),
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
        StudafyNavItem(
          StudafyLocalizations.of(context).text('insights'),
          Icons.query_stats_outlined,
          Icons.query_stats_rounded,
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
