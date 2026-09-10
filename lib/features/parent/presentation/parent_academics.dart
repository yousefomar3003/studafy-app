part of '../../../parent_features.dart';

class ParentAcademicsPage extends StatefulWidget {
  const ParentAcademicsPage({super.key});
  @override
  State<ParentAcademicsPage> createState() => _ParentAcademicsPageState();
}

class _ParentAcademicsPageState extends State<ParentAcademicsPage> {
  List<Map<String, Object?>> children = [];
  int selectedChild = 0;
  int tab = 0;
  bool loading = true;

  Map<String, Object?>? get child =>
      children.isEmpty ? null : children[selectedChild];

  @override
  void initState() {
    super.initState();
    ActiveContextController.instance.addListener(_contextChanged);
    _load();
  }

  void _contextChanged() {
    if (!mounted || children.isEmpty) return;
    final next = _activeChildIndex(children, selectedChild);
    if (next != selectedChild) setState(() => selectedChild = next);
  }

  @override
  void dispose() {
    ActiveContextController.instance.removeListener(_contextChanged);
    super.dispose();
  }

  Future<void> _load() async {
    final rows = await ParentRepositoryScope.read(context).linkedChildren();
    if (!mounted) return;
    setState(() {
      children = rows;
      selectedChild = _activeChildIndex(rows, selectedChild);
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _canvas,
    body: Column(
      children: [
        _AcademicsHeader(
          title: 'Academics',
          children: children,
          selected: selectedChild,
          onSelected: (value) {
            setState(() => selectedChild = value);
            _rememberChild(children[value]);
          },
        ),
        if (loading)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (child == null)
          const Expanded(
            child: Center(
              child: Text('Add a child from Home to view academics.'),
            ),
          )
        else
          Expanded(
            child: Column(
              children: [
                _AcademicTabs(
                  selected: tab,
                  onSelected: (value) => setState(() => tab = value),
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: switch (tab) {
                      0 => _ClassesTab(
                        key: ValueKey('classes-$selectedChild'),
                        studentId: child!['student_id'] as int,
                      ),
                      1 => _GradesTab(
                        key: ValueKey('grades-$selectedChild'),
                        childIndex: selectedChild,
                      ),
                      2 => _AttendanceTab(
                        key: ValueKey('attendance-$selectedChild'),
                        childIndex: selectedChild,
                      ),
                      _ => _WorkTab(
                        key: ValueKey('work-$selectedChild'),
                        studentId: child!['student_id'] as int,
                      ),
                    },
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

class _AcademicsHeader extends StatelessWidget {
  const _AcademicsHeader({
    required this.title,
    required this.children,
    required this.selected,
    required this.onSelected,
  });
  final String title;
  final List<Map<String, Object?>> children;
  final int selected;
  final ValueChanged<int> onSelected;
  @override
  Widget build(BuildContext context) => Container(
    color: Colors.white,
    padding: const EdgeInsets.fromLTRB(20, 10, 14, 12),
    child: SafeArea(
      bottom: false,
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              color: _navy,
              fontSize: 21,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 12),
          if (children.isNotEmpty)
            Expanded(
              child: PopupMenuButton<int>(
                initialValue: selected,
                onSelected: onSelected,
                position: PopupMenuPosition.under,
                itemBuilder: (context) => [
                  for (var i = 0; i < children.length; i++)
                    PopupMenuItem(
                      value: i,
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: i.isEven ? _navy : _cyan,
                            child: Text(
                              _initials('${children[i]['student_name']}'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text('${children[i]['student_name']}'),
                          ),
                          if (i == selected)
                            const Icon(Icons.check_rounded, color: _navy),
                        ],
                      ),
                    ),
                ],
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 17,
                      backgroundColor: selected.isEven ? _navy : _cyan,
                      child: Text(
                        _initials('${children[selected]['student_name']}'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${children[selected]['student_name']}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _navy,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                          const Text(
                            'Al-Noor International',
                            style: TextStyle(color: _muted, fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: _muted,
                    ),
                  ],
                ),
              ),
            ),
          if (children.isEmpty) const Spacer(),
          FutureBuilder<int>(
            future: ParentRepositoryScope.read(context)
                .unreadNotificationCount(),
            builder: (context, snapshot) => Badge(
              isLabelVisible: (snapshot.data ?? 0) > 0,
              label: Text('${snapshot.data ?? 0}'),
              backgroundColor: const Color(0xFFFF5D5D),
              child: IconButton(
                tooltip: 'Updates',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const ParentMessagesPage(
                      initialTab: 1,
                      updatesOnly: true,
                    ),
                  ),
                ),
                icon: const Icon(Icons.notifications_none_rounded),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Profile',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const ParentAccountPage(),
              ),
            ),
            icon: const CircleAvatar(
              radius: 19,
              backgroundColor: _navy,
              child: Text(
                'NH',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
