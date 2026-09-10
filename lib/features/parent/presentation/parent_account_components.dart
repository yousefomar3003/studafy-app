part of '../../../parent_features.dart';

class _ParentHeader extends StatelessWidget {
  const _ParentHeader({this.title});
  final String? title;
  @override
  Widget build(BuildContext context) => Container(
    color: Colors.white,
    padding: const EdgeInsets.fromLTRB(20, 10, 16, 12),
    child: SafeArea(
      bottom: false,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title ?? '⁺studafy',
                  style: const TextStyle(
                    color: _navy,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                  ),
                ),
                if (title == null)
                  const Text(
                    'Al-Noor International',
                    style: TextStyle(color: _muted, fontSize: 12),
                  ),
              ],
            ),
          ),
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
            tooltip: 'Account settings',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const ParentAccountPage(),
              ),
            ),
            icon: const CircleAvatar(
              backgroundColor: _navy,
              child: Text(
                'NH',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _ChildSwitcher extends StatelessWidget {
  const _ChildSwitcher({
    required this.children,
    required this.selected,
    required this.onSelected,
    required this.onAdd,
  });
  final List<Map<String, Object?>> children;
  final int selected;
  final ValueChanged<int> onSelected;
  final VoidCallback onAdd;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 76,
    child: ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
      scrollDirection: Axis.horizontal,
      itemCount: children.length + 1,
      separatorBuilder: (_, _) => const SizedBox(width: 9),
      itemBuilder: (context, index) {
        if (index == children.length) {
          return ActionChip(
            avatar: const Icon(Icons.add_rounded),
            label: const Text('Add'),
            onPressed: onAdd,
            side: const BorderSide(
              color: Color(0xFFD4D6E5),
              style: BorderStyle.solid,
            ),
          );
        }
        final name = '${children[index]['student_name']}';
        final active = selected == index;
        return ChoiceChip(
          selected: active,
          onSelected: (_) => onSelected(index),
          avatar: CircleAvatar(
            backgroundColor: index.isEven ? _navy : _cyan,
            child: Text(
              _initials(name),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          label: Text(name.split(' ').first),
          selectedColor: Colors.white,
          backgroundColor: Colors.white,
          side: BorderSide(
            color: active ? _navy : const Color(0xFFE0E2EE),
            width: active ? 1.5 : 1,
          ),
        );
      },
    ),
  );
}

class _ChildDashboard extends StatelessWidget {
  const _ChildDashboard({required this.child, required this.index});
  final Map<String, Object?> child;
  final int index;
  @override
  Widget build(BuildContext context) {
    final first = '${child['student_name']}'.split(' ').first;
    final grade = index.isEven ? '13/20' : '17/20';
    final fee = index.isEven ? r'$207.00' : r'$95.00';
    return ListView(
      key: PageStorageKey('parent-$index'),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        Text(
          'Good morning, Nadia',
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(color: _navy),
        ),
        const SizedBox(height: 3),
        const Text('Tuesday, 17 March', style: TextStyle(color: _muted)),
        const SizedBox(height: 16),
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'TODAY AT SCHOOL',
                style: TextStyle(
                  color: _muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Chemistry · Period 5',
                style: TextStyle(
                  color: _navy,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Text(
                'Starts 12:40 · Lab 2 · Mr. Saleh',
                style: TextStyle(color: _muted, fontSize: 12),
              ),
              const SizedBox(height: 14),
              const Row(
                children: [
                  _Lesson(label: 'Biology', time: '09:00'),
                  SizedBox(width: 6),
                  _Lesson(label: 'Arabic', time: '09:55'),
                  SizedBox(width: 6),
                  _Lesson(label: 'Maths', time: '11:00'),
                  SizedBox(width: 6),
                  _Lesson(label: 'Chemistry', time: '12:40', active: true),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _Card(
          child: Column(
            children: [
              _DataRow(
                label: 'Attendance',
                trailing: index.isEven
                    ? '2 absences this month'
                    : 'Perfect this month',
                badge: true,
              ),
              const Divider(),
              _DataRow(
                label: 'Latest grade',
                detail: 'Mathematics · Quiz 4',
                trailing: grade,
              ),
              const Divider(),
              _DataRow(label: 'Fees', detail: 'Due 25 March', trailing: fee),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _Card(
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundColor: _navy,
              child: Text(
                _initials('${child['student_name']}'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            title: Text(
              "Open $first's student view",
              style: const TextStyle(color: _navy, fontWeight: FontWeight.w800),
            ),
            subtitle: const Text(
              'For younger children without their own phone',
              style: TextStyle(color: _muted, fontSize: 12),
            ),
            trailing: const Icon(Icons.chevron_right_rounded, color: _muted),
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFAED),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFF2E4BA)),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '▣  3 lessons filed today',
                style: TextStyle(color: _navy, fontWeight: FontWeight.w800),
              ),
              SizedBox(height: 8),
              Text(
                'Biology, Mathematics and Chemistry · 7 board photos',
                style: TextStyle(color: Color(0xFFA29573), fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Coming up',
              style: TextStyle(
                color: _navy,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              'All work',
              style: TextStyle(
                color: Color(0xFF1687A0),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        const _Card(
          child: Column(
            children: [
              _Upcoming(
                tag: 'Due',
                title: 'Photosynthesis lab report',
                detail: 'Biology · due tomorrow 15:00',
              ),
              Divider(),
              _Upcoming(
                tag: 'Exam',
                title: 'Unit 3 exam — Chemistry',
                detail: 'Thursday 26 March · Hall A',
              ),
              Divider(),
              _Upcoming(
                tag: 'School',
                title: 'Parent evening',
                detail: 'Saturday 28 March · 17:00–19:00',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(17),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0B241D73),
          blurRadius: 14,
          offset: Offset(0, 5),
        ),
      ],
    ),
    child: child,
  );
}

class _Lesson extends StatelessWidget {
  const _Lesson({required this.label, required this.time, this.active = false});
  final String label, time;
  final bool active;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
      decoration: BoxDecoration(
        color: active ? const Color(0xFFE7FAFD) : const Color(0xFFF1F2F8),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Column(
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: active ? const Color(0xFF1687A0) : _muted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(time, style: const TextStyle(color: _muted, fontSize: 10)),
        ],
      ),
    ),
  );
}

class _DataRow extends StatelessWidget {
  const _DataRow({
    required this.label,
    required this.trailing,
    this.detail,
    this.badge = false,
  });
  final String label, trailing;
  final String? detail;
  final bool badge;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: _muted)),
            if (detail != null)
              Text(
                detail!,
                style: const TextStyle(color: Color(0xFFB0B5C9), fontSize: 11),
              ),
          ],
        ),
      ),
      Container(
        padding: badge
            ? const EdgeInsets.symmetric(horizontal: 9, vertical: 5)
            : EdgeInsets.zero,
        decoration: badge
            ? BoxDecoration(
                color: const Color(0xFFFFF3C7),
                borderRadius: BorderRadius.circular(20),
              )
            : null,
        child: Text(
          trailing,
          style: TextStyle(
            color: badge ? const Color(0xFFB7791F) : _navy,
            fontSize: badge ? 10 : 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    ],
  );
}

class _Upcoming extends StatelessWidget {
  const _Upcoming({
    required this.tag,
    required this.title,
    required this.detail,
  });
  final String tag, title, detail;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFE9F9FC),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          tag,
          style: const TextStyle(
            color: Color(0xFF1687A0),
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(color: _navy, fontWeight: FontWeight.w700),
            ),
            Text(detail, style: const TextStyle(color: _muted, fontSize: 11)),
          ],
        ),
      ),
    ],
  );
}

class _EmptyChildren extends StatelessWidget {
  const _EmptyChildren({required this.onAdd});
  final VoidCallback onAdd;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircleAvatar(
            radius: 34,
            backgroundColor: Color(0xFFE6F9FD),
            child: Icon(Icons.family_restroom_rounded, color: _navy, size: 32),
          ),
          const SizedBox(height: 18),
          const Text(
            'Add your first child',
            style: TextStyle(
              color: _ink,
              fontSize: 21,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 7),
          const Text(
            'Connect with their Studafy ID to see school updates in one place.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _muted),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add a child'),
          ),
        ],
      ),
    ),
  );
}
