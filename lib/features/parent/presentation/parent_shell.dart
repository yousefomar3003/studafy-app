part of '../../../parent_features.dart';

class ParentShell extends StatefulWidget {
  const ParentShell({super.key});
  @override
  State<ParentShell> createState() => _ParentShellState();
}

class _ParentShellState extends State<ParentShell> {
  int index = 0;
  final homeKey = GlobalKey<ParentHomePageState>();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: IndexedStack(
      index: index,
      children: [
        ParentHomePage(key: homeKey),
        const ParentAcademicsPage(),
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
