import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/studafy_design.dart';
import 'core/studafy_domain.dart';
import 'core/studafy_localizations.dart';
import 'data/backend.dart';
import 'data/studafy_repository.dart';
import 'data/subscription_service.dart';
import 'data/session_service.dart';
import 'studafy_database.dart';
import 'student_linking.dart';
import 'features/account/presentation/delete_account_page.dart';

const _navy = Color(0xFF241D73);
const _cyan = Color(0xFF20C6E8);
const _ink = Color(0xFF171441);
const _muted = Color(0xFF9299B4);
const _canvas = Color(0xFFF7F6FE);

int _activeChildIndex(List<Map<String, Object?>> rows, int fallback) {
  final activeId = ActiveContextController.instance.selectedStudent?.id;
  final found = rows.indexWhere((row) => '${row['student_id']}' == activeId);
  return found >= 0
      ? found
      : fallback.clamp(0, rows.isEmpty ? 0 : rows.length - 1);
}

void _rememberChild(Map<String, Object?> row) {
  ActiveContextController.instance.selectStudent(
    StudentSummary(
      id: '${row['student_id']}',
      studafyId: '${row['studafy_id']}',
      displayName: '${row['student_name']}',
      verified: row['provisional'] != 1,
    ),
  );
}

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

class ParentHomePage extends StatefulWidget {
  const ParentHomePage({super.key});
  @override
  State<ParentHomePage> createState() => ParentHomePageState();
}

class ParentHomePageState extends State<ParentHomePage> {
  final controller = PageController();
  List<Map<String, Object?>> children = [];
  int selected = 0;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    ActiveContextController.instance.addListener(_contextChanged);
    _load();
  }

  void _contextChanged() {
    if (!mounted || children.isEmpty) return;
    final next = _activeChildIndex(children, selected);
    if (next != selected) {
      setState(() => selected = next);
      if (controller.hasClients) {
        controller.animateToPage(
          next,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    }
  }

  Future<void> _load({int? selectStudent}) async {
    final rows = await StudafyDatabase.instance.linkedChildren();
    if (!mounted) return;
    var next = _activeChildIndex(rows, selected);
    if (selectStudent != null) {
      final found = rows.indexWhere(
        (row) => row['student_id'] == selectStudent,
      );
      if (found >= 0) next = found;
    }
    setState(() {
      children = rows;
      selected = next;
      loading = false;
    });
    if (rows.isNotEmpty) _rememberChild(rows[next]);
    if (rows.isNotEmpty && controller.hasClients) controller.jumpToPage(next);
  }

  @override
  void dispose() {
    ActiveContextController.instance.removeListener(_contextChanged);
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _canvas,
    body: Column(
      children: [
        const _ParentHeader(),
        if (loading)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (children.isEmpty)
          Expanded(child: _EmptyChildren(onAdd: _addChild))
        else ...[
          _ChildSwitcher(
            children: children,
            selected: selected,
            onSelected: (value) {
              setState(() => selected = value);
              _rememberChild(children[value]);
              controller.animateToPage(
                value,
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
              );
            },
            onAdd: _addChild,
          ),
          Expanded(
            child: PageView.builder(
              controller: controller,
              itemCount: children.length,
              onPageChanged: (value) {
                setState(() => selected = value);
                _rememberChild(children[value]);
              },
              itemBuilder: (context, index) =>
                  _ChildDashboard(child: children[index], index: index),
            ),
          ),
        ],
      ],
    ),
  );

  Future<void> _addChild() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Add a child',
                style: TextStyle(
                  fontSize: 23,
                  color: _ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 7),
              const Text(
                'Choose how you would like to add them to your family.',
                style: TextStyle(color: _muted),
              ),
              const SizedBox(height: 18),
              _AddChildChoice(
                icon: Icons.badge_outlined,
                title: 'Connect an existing child',
                subtitle: 'Use the Studafy ID provided by their school',
                onTap: () => Navigator.pop(context, 'existing'),
              ),
              const SizedBox(height: 12),
              _AddChildChoice(
                icon: Icons.person_add_alt_1_rounded,
                title: 'Create a new child',
                subtitle: 'For a child who is not on Studafy yet',
                onTap: () => Navigator.pop(context, 'new'),
              ),
              const SizedBox(height: 10),
              const Text(
                'A school can connect the new profile to classes later.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _muted, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted) return;
    if (choice == 'existing') await _findChild();
    if (choice == 'new') await _createChild();
  }

  Future<void> _findChild() async {
    final id = TextEditingController();
    final shouldSearch = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Add a child',
              style: TextStyle(
                fontSize: 23,
                color: _ink,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 7),
            const Text(
              'Enter the Studafy ID shown on your child’s school profile.',
              style: TextStyle(color: _muted),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: id,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9-]')),
              ],
              decoration: const InputDecoration(
                labelText: 'Studafy ID',
                hintText: 'STU-0001',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(context, id.text.trim().isNotEmpty),
              child: const Text('Find child'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () async {
                final scanned = await scanStudentQr(context);
                if (scanned != null) id.text = scanned;
              },
              icon: const Icon(Icons.qr_code_scanner_rounded),
              label: const Text('Scan student QR'),
            ),
            const SizedBox(height: 8),
            const Text(
              'The ID must match exactly. You can create a profile if your child does not have one yet.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _muted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
    if (shouldSearch != true || !mounted) return;
    final found = await StudafyDatabase.instance.studentByStudafyId(id.text);
    if (!mounted) return;
    if (found != null) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const CircleAvatar(
            backgroundColor: Color(0xFFE6F9FD),
            child: Icon(Icons.person_rounded, color: _navy),
          ),
          title: Text('${found['name']}'),
          content: Text(
            'Studafy ID ${found['studafy_id']}\n\nAdd this student to your family?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Add child'),
            ),
          ],
        ),
      );
      if (confirmed == true) {
        await StudafyDatabase.instance.linkChild(found['id'] as int);
        await _load(selectStudent: found['id'] as int);
      }
      return;
    }
    final create = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.person_search_rounded, color: _navy, size: 38),
        title: const Text('No child found'),
        content: Text(
          'We could not find “${id.text.toUpperCase()}”. Check the ID with your school, or create a new child profile.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Try again'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Create profile'),
          ),
        ],
      ),
    );
    if (create == true && mounted) await _createChild();
  }

  Future<void> _createChild() async {
    final name = TextEditingController(), email = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final save = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Create child profile',
                style: TextStyle(
                  fontSize: 23,
                  color: _ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 7),
              const Text(
                'A unique Studafy ID will be created. Your school can connect academic records later.',
                style: TextStyle(color: _muted),
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: name,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Child’s full name',
                ),
                validator: (v) => v == null || v.trim().length < 2
                    ? 'Enter the child’s name'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Child’s email (optional)',
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  if (formKey.currentState!.validate()) {
                    Navigator.pop(context, true);
                  }
                },
                child: const Text('Create and add child'),
              ),
            ],
          ),
        ),
      ),
    );
    if (save == true) {
      final studentId = await StudafyDatabase.instance.createAndLinkChild(
        name: name.text,
        email: email.text,
      );
      await _load(selectStudent: studentId);
    }
  }
}

class _AddChildChoice extends StatelessWidget {
  const _AddChildChoice({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: const BorderSide(color: Color(0xFFDDE0ED)),
    ),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: const Color(0xFFE6F9FD),
              child: Icon(icon, color: _navy),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: _ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(color: _muted, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: _muted),
          ],
        ),
      ),
    ),
  );
}

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
    final rows = await StudafyDatabase.instance.linkedChildren();
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
            future: StudafyDatabase.instance.unreadNotificationCount(),
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

class _AcademicTabs extends StatelessWidget {
  const _AcademicTabs({required this.selected, required this.onSelected});
  final int selected;
  final ValueChanged<int> onSelected;
  @override
  Widget build(BuildContext context) => Container(
    height: 52,
    margin: const EdgeInsets.fromLTRB(20, 16, 20, 10),
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: const Color(0xFFEDEEF7),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        for (var i = 0; i < 4; i++)
          Expanded(
            child: InkWell(
              onTap: () => onSelected(i),
              borderRadius: BorderRadius.circular(11),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected == i ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(11),
                  boxShadow: selected == i
                      ? const [
                          BoxShadow(color: Color(0x10241D73), blurRadius: 6),
                        ]
                      : null,
                ),
                child: Text(
                  const ['Classes', 'Grades', 'Attend.', 'Work'][i],
                  style: TextStyle(
                    color: selected == i ? _navy : _muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class _ClassesTab extends StatelessWidget {
  const _ClassesTab({super.key, required this.studentId});
  final int studentId;
  @override
  Widget build(BuildContext context) =>
      FutureBuilder<List<Map<String, Object?>>>(
        future: StudafyDatabase.instance.classesForStudent(studentId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final classes = snapshot.data!;
          if (classes.isEmpty) {
            return const _AcademicEmpty(
              icon: Icons.class_outlined,
              title: 'No connected classes',
              message: 'Classes appear here when a teacher adds this child to a classroom.',
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              const Text(
                'CURRENT CLASSES',
                style: TextStyle(
                  color: _muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .5,
                ),
              ),
              const SizedBox(height: 10),
              for (final item in classes)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ClassCard(item: item),
                ),
              const SizedBox(height: 4),
              const Text(
                'Only classrooms created by teachers using Studafy are shown.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _muted, fontSize: 11),
              ),
            ],
          );
        },
      );
}

class _ClassCard extends StatelessWidget {
  const _ClassCard({required this.item});
  final Map<String, Object?> item;
  @override
  Widget build(BuildContext context) {
    final color = Color(item['color'] as int);
    return _Card(
      child: Row(
        children: [
          Container(
            width: 5,
            height: 70,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${item['name']}',
                  style: const TextStyle(
                    color: _navy,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Grade ${item['grade']} · Section ${item['section']}',
                  style: const TextStyle(color: _muted),
                ),
                Text(
                  '${item['room']} · ${item['start_time']}–${item['end_time']}',
                  style: const TextStyle(color: _muted, fontSize: 12),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: _muted),
        ],
      ),
    );
  }
}

class _GradesTab extends StatelessWidget {
  const _GradesTab({super.key, required this.childIndex});
  final int childIndex;
  @override
  Widget build(BuildContext context) {
    final offset = childIndex * 2;
    final subjects = [
      ('Biology', 84 + offset, _navy),
      ('Mathematics', 81 + offset, _cyan),
      ('History', 84 - offset, Color(0xFF7737EE)),
      ('English', 80 + offset, Color(0xFFFF315F)),
      ('Chemistry', 85 - offset, Color(0xFFE47B00)),
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFCF4),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFEAD394)),
          ),
          child: const Row(
            children: [
              Icon(Icons.workspace_premium_outlined, color: Color(0xFFB98921)),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Certificate issued',
                      style: TextStyle(
                        color: _navy,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Semester 1 and full year',
                      style: TextStyle(color: Color(0xFFA99973), fontSize: 12),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: Color(0xFFB98921)),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const Align(
          alignment: Alignment.centerLeft,
          child: Chip(label: Text('Term 2 · 2025–26')),
        ),
        const SizedBox(height: 10),
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Term average', style: TextStyle(color: _muted)),
              Text(
                '${83 + offset}%',
                style: const TextStyle(
                  color: _navy,
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Text(
                'Pass mark 50% · Set by Al-Noor International',
                style: TextStyle(color: _muted, fontSize: 11),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        for (final subject in subjects)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _Card(
              child: Row(
                children: [
                  Container(width: 3, height: 30, color: subject.$3),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      subject.$1,
                      style: const TextStyle(
                        color: _navy,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    '${subject.$2}%',
                    style: const TextStyle(
                      color: _navy,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.keyboard_arrow_down_rounded, color: _muted),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _AttendanceTab extends StatelessWidget {
  const _AttendanceTab({super.key, required this.childIndex});
  final int childIndex;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
    children: [
      Row(
        children: [
          _Stat(
            value: '${96 - childIndex}%',
            label: 'Present',
            color: const Color(0xFF159B68),
          ),
          const SizedBox(width: 8),
          _Stat(
            value: '${2 + childIndex}',
            label: 'Absences',
            color: const Color(0xFFFF4757),
          ),
          const SizedBox(width: 8),
          _Stat(
            value: '$childIndex',
            label: 'Late',
            color: const Color(0xFFB87500),
          ),
        ],
      ),
      const SizedBox(height: 14),
      const _Card(child: _AttendanceCalendar()),
    ],
  );
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, required this.color});
  final String value, label;
  final Color color;
  @override
  Widget build(BuildContext context) => Expanded(
    child: _Card(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(label, style: const TextStyle(color: _muted, fontSize: 11)),
        ],
      ),
    ),
  );
}

class _AttendanceCalendar extends StatelessWidget {
  const _AttendanceCalendar();
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(Icons.chevron_left_rounded, color: _muted),
          Text(
            'March 2026',
            style: TextStyle(color: _navy, fontWeight: FontWeight.w800),
          ),
          Icon(Icons.chevron_right_rounded, color: _muted),
        ],
      ),
      const SizedBox(height: 18),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          for (final day in ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
            Text(day, style: const TextStyle(color: _muted, fontSize: 11)),
        ],
      ),
      const SizedBox(height: 10),
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 31,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 7,
          childAspectRatio: 1.15,
        ),
        itemBuilder: (context, index) {
          final day = index + 1;
          final marker = day == 5 || day == 6
              ? const Color(0xFFFF4757)
              : day == 12
              ? const Color(0xFFF0A000)
              : day == 19
              ? const Color(0xFF1687C0)
              : null;
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$day',
                style: TextStyle(
                  color: day == 17 ? _navy : _muted,
                  fontWeight: day == 17 ? FontWeight.w900 : FontWeight.normal,
                ),
              ),
              if (marker != null)
                Container(
                  width: 5,
                  height: 5,
                  margin: const EdgeInsets.only(top: 2),
                  decoration: BoxDecoration(
                    color: marker,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          );
        },
      ),
      const Divider(),
      const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '● Absent',
            style: TextStyle(color: Color(0xFFFF4757), fontSize: 10),
          ),
          SizedBox(width: 12),
          Text(
            '● Late',
            style: TextStyle(color: Color(0xFFF0A000), fontSize: 10),
          ),
          SizedBox(width: 12),
          Text(
            '● Excused',
            style: TextStyle(color: Color(0xFF1687C0), fontSize: 10),
          ),
        ],
      ),
    ],
  );
}

class _WorkTab extends StatelessWidget {
  const _WorkTab({super.key, required this.studentId});
  final int studentId;
  @override
  Widget build(BuildContext context) =>
      FutureBuilder<List<Map<String, Object?>>>(
        future: StudafyDatabase.instance.workForStudent(studentId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final rows = snapshot.data!;
          if (rows.isEmpty) {
            return const _AcademicEmpty(
              icon: Icons.assignment_turned_in_outlined,
              title: 'No assigned work',
              message: 'Assignments from connected classes will appear here.',
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              for (final row in rows)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _Card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${row['class_name']}',
                          style: const TextStyle(
                            color: _muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${row['title']}',
                          style: const TextStyle(
                            color: _navy,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Due ${row['due_at']}',
                              style: const TextStyle(
                                color: _muted,
                                fontSize: 11,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: row['submitted_at'] == null
                                    ? const Color(0xFFF0F1F7)
                                    : const Color(0xFFD7F8E8),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                row['submitted_at'] == null
                                    ? 'Not submitted'
                                    : 'Submitted',
                                style: TextStyle(
                                  color: row['submitted_at'] == null
                                      ? _muted
                                      : const Color(0xFF15885D),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      );
}

class _AcademicEmpty extends StatelessWidget {
  const _AcademicEmpty({
    required this.icon,
    required this.title,
    required this.message,
  });
  final IconData icon;
  final String title, message;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _navy, size: 44),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              color: _ink,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _muted),
          ),
        ],
      ),
    ),
  );
}

class ParentInsightsPage extends StatefulWidget {
  const ParentInsightsPage({super.key});
  @override
  State<ParentInsightsPage> createState() => _ParentInsightsPageState();
}

class _ParentInsightsPageState extends State<ParentInsightsPage> {
  List<Map<String, Object?>> children = [];
  int selectedChild = 0;
  String period = 'Current term';
  final subscription = StoreSubscriptionRepository();
  SubscriptionEntitlement? entitlement;
  bool entitlementLoading = StudafyBackend.isRemote;

  Map<String, Object?>? get child =>
      children.isEmpty ? null : children[selectedChild];

  DateTime? get periodStart {
    final now = DateTime.now();
    return switch (period) {
      'Last 30 days' => now.subtract(const Duration(days: 30)),
      'School year' => DateTime(now.month >= 8 ? now.year : now.year - 1, 8, 1),
      _ => DateTime(
        now.month >= 1 && now.month <= 6 ? now.year : now.year - 1,
        1,
        1,
      ),
    };
  }

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
    subscription.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final rows = await StudafyDatabase.instance.linkedChildren();
    SubscriptionEntitlement? access;
    if (StudafyBackend.isRemote) {
      try {
        access = await subscription.entitlement();
      } catch (_) {
        access = const SubscriptionEntitlement(
          active: false,
          source: 'unavailable',
        );
      }
    }
    if (!mounted) return;
    setState(() {
      children = rows;
      selectedChild = _activeChildIndex(rows, selectedChild);
      entitlement = access;
      entitlementLoading = false;
    });
  }

  Future<void> _purchase() async {
    try {
      await subscription.purchaseInsightsMonthly();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Complete the purchase in the store. Access appears after server verification.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$error'.replaceFirst('Bad state: ', ''))),
        );
      }
    }
  }

  Future<void> _restore() async {
    try {
      await subscription.restorePurchases();
      await Future<void>.delayed(const Duration(milliseconds: 500));
      await _load();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$error'.replaceFirst('Bad state: ', ''))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _canvas,
    body: Column(
      children: [
        _AcademicsHeader(
          title: 'Insights',
          children: children,
          selected: selectedChild,
          onSelected: (value) {
            setState(() => selectedChild = value);
            _rememberChild(children[value]);
          },
        ),
        if (child == null)
          const Expanded(
            child: Center(
              child: Text('Add a child from Home to view insights.'),
            ),
          )
        else if (entitlementLoading)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (StudafyBackend.isRemote && !(entitlement?.active ?? false))
          Expanded(
            child: _InsightsPaywall(onPurchase: _purchase, onRestore: _restore),
          )
        else
          Expanded(
            child: FutureBuilder<Map<String, num>>(
              future: StudafyDatabase.instance.insightMetricsForStudent(
                child!['student_id'] as int,
                since: periodStart,
              ),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final insight = _StudentInsight.from(snapshot.data!);
                final firstName = '${child!['student_name']}'.split(' ').first;
                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$firstName’s evidence-backed insights',
                                style: const TextStyle(
                                  color: _ink,
                                  fontSize: 21,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const Text(
                                'A transparent summary of connected school data',
                                style: TextStyle(color: _muted, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: period,
                            borderRadius: BorderRadius.circular(14),
                            items:
                                ['Last 30 days', 'Current term', 'School year']
                                    .map(
                                      (value) => DropdownMenuItem(
                                        value: value,
                                        child: Text(
                                          value,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                            onChanged: (value) {
                              if (value != null) setState(() => period = value);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _InsightHero(insight: insight),
                    const SizedBox(height: 14),
                    _ParentPremiumBrief(insight: insight, firstName: firstName),
                    const SizedBox(height: 14),
                    _DataQualityCard(insight: insight),
                    const SizedBox(height: 18),
                    const Text(
                      'DETAILED SIGNALS',
                      style: TextStyle(
                        color: _muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: .5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _MetricCard(
                      icon: Icons.fact_check_outlined,
                      title: 'Attendance consistency',
                      value: insight.attendance,
                      color: const Color(0xFF15885D),
                      weight: 'Source: attendance records',
                      detail:
                          '${insight.present.toInt()} present · ${insight.absent.toInt()} absent · ${insight.tardy.toInt()} late',
                      sample:
                          '${insight.attendanceTotal.toInt()} recorded school days',
                    ),
                    const SizedBox(height: 10),
                    _MetricCard(
                      icon: Icons.workspace_premium_outlined,
                      title: 'Assessment mastery',
                      value: insight.grades,
                      color: _navy,
                      weight: 'Source: published results',
                      detail: 'Average normalized against each assessment’s maximum score',
                      sample:
                          '${insight.gradedCount.toInt()} graded assessments',
                    ),
                    const SizedBox(height: 10),
                    _MetricCard(
                      icon: Icons.assignment_turned_in_outlined,
                      title: 'Submission reliability',
                      value: insight.submissions,
                      color: const Color(0xFF1687A0),
                      weight: 'Source: due submissions',
                      detail:
                          '${insight.submitted.toInt()} submitted of ${insight.assigned.toInt()} assignments',
                      sample: '${insight.assigned.toInt()} assigned items',
                    ),
                    const SizedBox(height: 10),
                    _MetricCard(
                      icon: Icons.psychology_alt_outlined,
                      title: 'Classroom engagement',
                      value: insight.engagement,
                      color: const Color(0xFF7737EE),
                      weight: 'Source: teacher observations',
                      detail:
                          '${insight.positive.toInt()} positive observations · ${insight.concerns.toInt()} concerns',
                      sample:
                          '${insight.behaviourTotal.toInt()} teacher observations',
                    ),
                    const SizedBox(height: 18),
                    _PriorityCard(insight: insight, firstName: firstName),
                    const SizedBox(height: 14),
                    _MethodCard(insight: insight),
                  ],
                );
              },
            ),
          ),
      ],
    ),
  );
}

class _InsightsPaywall extends StatelessWidget {
  const _InsightsPaywall({required this.onPurchase, required this.onRestore});
  final VoidCallback onPurchase;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [_navy, Color(0xFF4B3FB5)]),
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PremiumTag(),
            SizedBox(height: 14),
            Text(
              'Understand the pattern, then take one useful action.',
              style: TextStyle(
                color: Colors.white,
                fontSize: 23,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Insights+ explains mastery, attendance patterns, workload conflicts, momentum, and what evidence produced each recommendation.',
              style: TextStyle(color: Colors.white70, height: 1.4),
            ),
          ],
        ),
      ),
      const SizedBox(height: 18),
      const _Card(
        child: Column(
          children: [
            ListTile(
              leading: Icon(Icons.fact_check_outlined, color: _navy),
              title: Text('Evidence and sample size on every insight'),
            ),
            Divider(),
            ListTile(
              leading: Icon(Icons.calendar_month_outlined, color: _navy),
              title: Text('Weekly family action plan'),
            ),
            Divider(),
            ListTile(
              leading: Icon(Icons.calculate_outlined, color: _navy),
              title: Text('“What mark is needed?” scenarios'),
            ),
          ],
        ),
      ),
      const SizedBox(height: 18),
      FilledButton(
        onPressed: onPurchase,
        child: const Text('Start Insights+ · monthly'),
      ),
      TextButton(onPressed: onRestore, child: const Text('Restore purchase')),
      const Text(
        'Grades, attendance, messages, alerts, and official school records remain free.',
        textAlign: TextAlign.center,
        style: TextStyle(color: _muted, fontSize: 11),
      ),
    ],
  );
}

class _ParentPremiumBrief extends StatelessWidget {
  const _ParentPremiumBrief({required this.insight, required this.firstName});
  final _StudentInsight insight;
  final String firstName;

  @override
  Widget build(BuildContext context) {
    final missing = (insight.assigned - insight.submitted)
        .clamp(0, 999)
        .toInt();
    final items =
        <({IconData icon, Color color, String title, String detail})>[];
    if (missing > 0) {
      items.add((
        icon: Icons.assignment_late_outlined,
        color: const Color(0xFFE07A12),
        title: '$missing unfinished ${missing == 1 ? 'item' : 'items'}',
        detail:
            'Ask $firstName which task is blocked, then agree on one completion time.',
      ));
    }
    if (insight.attendance != null && insight.attendance! < 95) {
      items.add((
        icon: Icons.event_busy_outlined,
        color: const Color(0xFFD94C4C),
        title: 'Attendance needs attention',
        detail:
            '${insight.absent.toInt()} absence(s) and ${insight.tardy.toInt()} late arrival(s) are recorded. Review dates with the school.',
      ));
    }
    if (insight.grades != null && insight.grades! < 75) {
      items.add((
        icon: Icons.school_outlined,
        color: _navy,
        title: 'Assessment support recommended',
        detail:
            'Current normalized assessment average is ${insight.grades!.round()}%. Open Academics to identify the lowest class before contacting its teacher.',
      ));
    }
    if (items.isEmpty) {
      items.add((
        icon: Icons.verified_rounded,
        color: const Color(0xFF15966A),
        title: 'No urgent intervention detected',
        detail:
            'Keep the routine steady and recognize $firstName’s consistency this week.',
      ));
    }
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE5E6F1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome_rounded, color: Color(0xFF7737EE)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Parent action brief',
                  style: TextStyle(
                    color: _ink,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _PremiumTag(),
            ],
          ),
          const SizedBox(height: 5),
          const Text(
            'The highest-value actions generated from current school records.',
            style: TextStyle(color: _muted, fontSize: 11),
          ),
          const SizedBox(height: 13),
          for (var i = 0; i < items.take(3).length; i++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: items[i].color.withValues(alpha: .11),
                  child: Icon(items[i].icon, color: items[i].color, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        items[i].title,
                        style: const TextStyle(
                          color: _ink,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        items[i].detail,
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 11,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (i != items.take(3).length - 1) const Divider(height: 22),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    showDragHandle: true,
                    builder: (context) => Padding(
                      padding: const EdgeInsets.fromLTRB(22, 6, 22, 30),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'This week’s family plan',
                            style: TextStyle(
                              color: _ink,
                              fontSize: 21,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 12),
                          for (final item in items.take(3))
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: CircleAvatar(
                                backgroundColor: item.color.withValues(
                                  alpha: .1,
                                ),
                                child: Icon(item.icon, color: item.color),
                              ),
                              title: Text(item.title),
                              subtitle: Text(item.detail),
                            ),
                        ],
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.calendar_month_outlined, size: 17),
                  label: const Text('Weekly plan'),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const ParentMessagesPage(),
                    ),
                  ),
                  icon: const Icon(Icons.chat_bubble_outline, size: 17),
                  label: const Text('Ask teacher'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PremiumTag extends StatelessWidget {
  const _PremiumTag();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: const Color(0xFFF0EAFF),
      borderRadius: BorderRadius.circular(20),
    ),
    child: const Text(
      'PLUS',
      style: TextStyle(
        color: Color(0xFF6D35D5),
        fontSize: 9,
        fontWeight: FontWeight.w900,
      ),
    ),
  );
}

class _StudentInsight {
  const _StudentInsight({
    required this.attendance,
    required this.grades,
    required this.submissions,
    required this.engagement,
    required this.availableSignals,
    required this.attendanceTotal,
    required this.present,
    required this.absent,
    required this.tardy,
    required this.gradedCount,
    required this.assigned,
    required this.submitted,
    required this.behaviourTotal,
    required this.positive,
    required this.concerns,
  });
  final double? attendance, grades, submissions, engagement;
  final int availableSignals;
  final num attendanceTotal,
      present,
      absent,
      tardy,
      gradedCount,
      assigned,
      submitted,
      behaviourTotal,
      positive,
      concerns;

  factory _StudentInsight.from(Map<String, num> data) {
    final attendanceTotal = data['attendance_total'] ?? 0,
        assigned = data['assigned'] ?? 0,
        graded = data['graded_count'] ?? 0,
        behaviour = data['behaviour_total'] ?? 0;
    final attendance = attendanceTotal > 0
        ? ((data['present'] ?? 0) / attendanceTotal * 100)
              .clamp(0, 100)
              .toDouble()
        : null;
    final grades = graded > 0
        ? (data['grade_average'] ?? 0).clamp(0, 100).toDouble()
        : null;
    final submissions = assigned > 0
        ? ((data['submitted'] ?? 0) / assigned * 100).clamp(0, 100).toDouble()
        : null;
    final engagement = behaviour > 0
        ? (50 +
                  (((data['positive'] ?? 0) - (data['concerns'] ?? 0)) /
                      behaviour *
                      50))
              .clamp(0, 100)
              .toDouble()
        : null;
    final available = [
      attendance,
      grades,
      submissions,
      engagement,
    ].where((item) => item != null).toList();
    return _StudentInsight(
      attendance: attendance,
      grades: grades,
      submissions: submissions,
      engagement: engagement,
      availableSignals: available.length,
      attendanceTotal: attendanceTotal,
      present: data['present'] ?? 0,
      absent: data['absent'] ?? 0,
      tardy: data['tardy'] ?? 0,
      gradedCount: graded,
      assigned: assigned,
      submitted: data['submitted'] ?? 0,
      behaviourTotal: behaviour,
      positive: data['positive'] ?? 0,
      concerns: data['concerns'] ?? 0,
    );
  }
}

class _InsightHero extends StatelessWidget {
  const _InsightHero({required this.insight});
  final _StudentInsight insight;
  @override
  Widget build(BuildContext context) {
    final label = insight.availableSignals < 2
        ? 'Not enough evidence yet'
        : '${insight.availableSignals} source categories available';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_navy, Color(0xFF4B3FB5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x30241D73),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 88,
            height: 88,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white12,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.query_stats_rounded, color: _cyan, size: 42),
            ),
          ),
          const SizedBox(width: 17),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Evidence snapshot',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 7),
                const Text(
                  'No hidden child score, ranking, diagnosis, or prediction. Open each signal to see its source and sample size.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DataQualityCard extends StatelessWidget {
  const _DataQualityCard({required this.insight});
  final _StudentInsight insight;
  @override
  Widget build(BuildContext context) {
    final ratio = insight.availableSignals / 4;
    final label = insight.availableSignals == 4
        ? 'Complete'
        : insight.availableSignals >= 2
        ? 'Partial'
        : 'Limited';
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.verified_outlined,
                color: Color(0xFF1687A0),
                size: 20,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Data confidence',
                  style: TextStyle(color: _navy, fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF1687A0),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: ratio,
            minHeight: 7,
            borderRadius: BorderRadius.circular(8),
            backgroundColor: const Color(0xFFE8EAF3),
            color: const Color(0xFF20A6BF),
          ),
          const SizedBox(height: 8),
          Text(
            '${insight.availableSignals} of 4 source categories contain records. Missing categories are shown as missing and never guessed.',
            style: const TextStyle(color: _muted, fontSize: 10, height: 1.35),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
    required this.weight,
    required this.detail,
    required this.sample,
  });
  final IconData icon;
  final String title, weight, detail, sample;
  final double? value;
  final Color color;
  @override
  Widget build(BuildContext context) => _Card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: .1),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: _navy,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    weight,
                    style: const TextStyle(color: _muted, fontSize: 10),
                  ),
                ],
              ),
            ),
            Text(
              value == null ? 'No data' : '${value!.round()}%',
              style: TextStyle(
                color: value == null ? _muted : color,
                fontSize: value == null ? 13 : 22,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        LinearProgressIndicator(
          value: value == null ? 0 : value! / 100,
          minHeight: 7,
          borderRadius: BorderRadius.circular(8),
          backgroundColor: const Color(0xFFEDEEF5),
          color: color,
        ),
        const SizedBox(height: 9),
        Text(
          detail,
          style: const TextStyle(color: Color(0xFF606780), fontSize: 11),
        ),
        const SizedBox(height: 3),
        Text(sample, style: const TextStyle(color: _muted, fontSize: 10)),
      ],
    ),
  );
}

class _PriorityCard extends StatelessWidget {
  const _PriorityCard({required this.insight, required this.firstName});
  final _StudentInsight insight;
  final String firstName;
  @override
  Widget build(BuildContext context) {
    final metrics = <(String, double?)>[
      ('attendance routine', insight.attendance),
      ('assessment understanding', insight.grades),
      ('assignment completion', insight.submissions),
      ('classroom engagement', insight.engagement),
    ];
    final available = metrics.where((item) => item.$2 != null).toList()
      ..sort((a, b) => a.$2!.compareTo(b.$2!));
    final focus = available.isEmpty ? null : available.first;
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFAED),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF0DEAC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.track_changes_rounded, color: Color(0xFFB87500)),
              SizedBox(width: 8),
              Text(
                'Most useful next step',
                style: TextStyle(color: _navy, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            focus == null
                ? 'More school records are needed before suggesting a focus.'
                : '${focus.$1[0].toUpperCase()}${focus.$1.substring(1)} is currently $firstName’s lowest available signal (${focus.$2!.round()}%). Start there, while preserving strengths in other areas.',
            style: const TextStyle(
              color: Color(0xFF625B48),
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Discuss context with the child and teacher before acting on a score.',
            style: TextStyle(color: Color(0xFFA29573), fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _MethodCard extends StatelessWidget {
  const _MethodCard({required this.insight});
  final _StudentInsight insight;
  @override
  Widget build(BuildContext context) => ExpansionTile(
    tilePadding: const EdgeInsets.symmetric(horizontal: 4),
    childrenPadding: const EdgeInsets.fromLTRB(4, 0, 4, 14),
    leading: const Icon(Icons.calculate_outlined, color: _navy),
    title: const Text(
      'How this is calculated',
      style: TextStyle(color: _navy, fontWeight: FontWeight.w800),
    ),
    children: const [
      Text(
        'Assessment mastery 35% + attendance consistency 30% + submission reliability 25% + classroom engagement 10%. Assessment scores are normalized by maximum points. Attendance uses recorded present days. Submission reliability uses assigned versus submitted work. Engagement balances positive and concern observations around a neutral midpoint. Missing categories are excluded and weights are rebalanced.',
        style: TextStyle(color: _muted, fontSize: 11, height: 1.45),
      ),
      SizedBox(height: 8),
      Text(
        'The pulse is descriptive, not predictive. It should never be used alone for discipline, placement, safeguarding, or clinical decisions.',
        style: TextStyle(
          color: Color(0xFFB42318),
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );
}

class ParentBehavioursPage extends StatefulWidget {
  const ParentBehavioursPage({super.key});
  @override
  State<ParentBehavioursPage> createState() => _ParentBehavioursPageState();
}

class _ParentBehavioursPageState extends State<ParentBehavioursPage> {
  List<Map<String, Object?>> children = [];
  int selectedChild = 0;
  String filter = 'all';
  final Set<String> acknowledged = {};

  Map<String, Object?>? get child =>
      children.isEmpty ? null : children[selectedChild];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rows = await StudafyDatabase.instance.linkedChildren();
    if (!mounted) return;
    setState(() {
      children = rows;
      selectedChild = selectedChild.clamp(
        0,
        rows.isEmpty ? 0 : rows.length - 1,
      );
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _canvas,
    body: Column(
      children: [
        _AcademicsHeader(
          title: 'Behaviours',
          children: children,
          selected: selectedChild,
          onSelected: (value) => setState(() {
            selectedChild = value;
            filter = 'all';
          }),
        ),
        if (child == null)
          const Expanded(
            child: Center(
              child: Text('Add a child from Home to view behaviour updates.'),
            ),
          )
        else
          Expanded(
            child: FutureBuilder<List<Map<String, Object?>>>(
              future: StudafyDatabase.instance.behavioursForStudent(
                child!['student_id'] as int,
              ),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final source = snapshot.data!.isEmpty
                    ? _sampleBehaviours(selectedChild)
                    : snapshot.data!;
                final positive = source
                    .where((row) => _kind(row) == 'positive')
                    .length;
                final negative = source
                    .where((row) => _kind(row) == 'negative')
                    .length;
                final notes = source
                    .where((row) => _kind(row) == 'note')
                    .length;
                final visible = filter == 'all'
                    ? source
                    : source.where((row) => _kind(row) == filter).toList();
                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  children: [
                    _BehaviourFilters(
                      selected: filter,
                      counts: {
                        'all': source.length,
                        'positive': positive,
                        'negative': negative,
                        'note': notes,
                      },
                      onSelected: (value) => setState(() => filter = value),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _BehaviourStat(
                          value: '$positive',
                          label: 'Positive',
                          color: const Color(0xFF15885D),
                        ),
                        const SizedBox(width: 9),
                        _BehaviourStat(
                          value: '$negative',
                          label: 'Needs attention',
                          color: const Color(0xFFC62828),
                        ),
                        const SizedBox(width: 9),
                        _BehaviourStat(
                          value: '$notes',
                          label: 'Notes',
                          color: const Color(0xFF1687A0),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (filter == 'all') ...[
                      _BehaviourInsight(
                        firstName: '${child!['student_name']}'.split(' ').first,
                        positive: positive,
                        negative: negative,
                      ),
                      const SizedBox(height: 14),
                    ],
                    if (visible.isEmpty)
                      _AcademicEmpty(
                        icon: Icons.sentiment_satisfied_alt_rounded,
                        title:
                            'No ${filter == 'negative' ? 'concerns' : filter} updates',
                        message: 'Teacher observations in this category will appear here.',
                      )
                    else
                      for (var i = 0; i < visible.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _BehaviourCard(
                            item: visible[i],
                            index: i,
                            acknowledged: acknowledged.contains(
                              '${visible[i]['created_at']}-$i',
                            ),
                            onAcknowledge: () => setState(
                              () => acknowledged.add(
                                '${visible[i]['created_at']}-$i',
                              ),
                            ),
                            onMessage: () => _messageTeacher(visible[i]),
                          ),
                        ),
                    if (filter == 'all') ...[
                      const SizedBox(height: 2),
                      const _SupportCard(),
                    ],
                  ],
                );
              },
            ),
          ),
      ],
    ),
  );

  void _messageTeacher(Map<String, Object?> item) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Message the teacher',
              style: TextStyle(
                color: _ink,
                fontSize: 21,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Regarding “${item['tag']}”',
              style: const TextStyle(color: _muted),
            ),
            const SizedBox(height: 16),
            const TextField(
              maxLines: 4,
              decoration: InputDecoration(
                hintText:
                    'Ask for context or share how you will follow up at home…',
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(
                    content: Text('Message added to your conversation draft.'),
                  ),
                );
              },
              child: const Text('Save message draft'),
            ),
          ],
        ),
      ),
    );
  }
}

class _BehaviourFilters extends StatelessWidget {
  const _BehaviourFilters({
    required this.selected,
    required this.counts,
    required this.onSelected,
  });
  final String selected;
  final Map<String, int> counts;
  final ValueChanged<String> onSelected;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 42,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: counts.length,
      separatorBuilder: (_, _) => const SizedBox(width: 8),
      itemBuilder: (context, index) {
        final key = counts.keys.elementAt(index), active = key == selected;
        final label = key == 'all'
            ? 'All'
            : key == 'note'
            ? 'Notes'
            : '${key[0].toUpperCase()}${key.substring(1)}';
        return ChoiceChip(
          selected: active,
          onSelected: (_) => onSelected(key),
          label: Text('$label ${counts[key]}'),
          selectedColor: _navy,
          labelStyle: TextStyle(
            color: active ? Colors.white : _muted,
            fontWeight: FontWeight.w800,
          ),
          backgroundColor: Colors.white,
          side: BorderSide(color: active ? _navy : const Color(0xFFE0E2ED)),
        );
      },
    ),
  );
}

class _BehaviourStat extends StatelessWidget {
  const _BehaviourStat({
    required this.value,
    required this.label,
    required this.color,
  });
  final String value, label;
  final Color color;
  @override
  Widget build(BuildContext context) => Expanded(
    child: _Card(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 23,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _muted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    ),
  );
}

class _BehaviourInsight extends StatelessWidget {
  const _BehaviourInsight({
    required this.firstName,
    required this.positive,
    required this.negative,
  });
  final String firstName;
  final int positive, negative;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFFEAFBFD), Color(0xFFF2EFFF)],
      ),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFD7EDF2)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const CircleAvatar(
          backgroundColor: Colors.white,
          child: Icon(Icons.auto_awesome_rounded, color: Color(0xFF7737EE)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Weekly insight',
                style: TextStyle(color: _navy, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 5),
              Text(
                positive > negative
                    ? '$firstName is showing a strong positive pattern. Teachers most often noticed collaboration and participation.'
                    : 'This week has a mixed pattern. A calm check-in about routines may help uncover what changed.',
                style: const TextStyle(color: _ink, fontSize: 12, height: 1.35),
              ),
              const SizedBox(height: 8),
              const Text(
                'Insight based on teacher observations—not a diagnosis or permanent label.',
                style: TextStyle(color: _muted, fontSize: 10),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _BehaviourCard extends StatelessWidget {
  const _BehaviourCard({
    required this.item,
    required this.index,
    required this.acknowledged,
    required this.onAcknowledge,
    required this.onMessage,
  });
  final Map<String, Object?> item;
  final int index;
  final bool acknowledged;
  final VoidCallback onAcknowledge, onMessage;
  @override
  Widget build(BuildContext context) {
    final kind = _kind(item);
    final color = kind == 'positive'
        ? const Color(0xFF15885D)
        : kind == 'negative'
        ? const Color(0xFFC62828)
        : const Color(0xFF1687A0);
    final teacher = index.isEven
        ? 'Ms Layla Fahmy · Biology'
        : 'Mr Fadi Chami · Mathematics';
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border(left: BorderSide(color: color, width: 4)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A241D73),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${item['tag']}',
                  style: const TextStyle(
                    color: _navy,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  kind == 'negative'
                      ? 'Needs attention'
                      : '${kind[0].toUpperCase()}${kind.substring(1)}',
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            '${item['note']}',
            style: const TextStyle(color: Color(0xFF5F6680), height: 1.4),
          ),
          const SizedBox(height: 12),
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                teacher,
                style: const TextStyle(color: _muted, fontSize: 10),
              ),
              Text(
                index == 0 ? 'Yesterday, 11:20' : '${index + 3} March',
                style: const TextStyle(color: _muted, fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onMessage,
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                  label: const Text('Message teacher'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                onPressed: acknowledged ? null : onAcknowledge,
                tooltip: acknowledged ? 'Acknowledged' : 'Mark as seen',
                icon: Icon(
                  acknowledged
                      ? Icons.check_circle_rounded
                      : Icons.visibility_outlined,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SupportCard extends StatelessWidget {
  const _SupportCard();
  @override
  Widget build(BuildContext context) => _Card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.favorite_outline_rounded, color: Color(0xFF7737EE)),
            SizedBox(width: 9),
            Text(
              'Continue the conversation at home',
              style: TextStyle(color: _navy, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        const SizedBox(height: 10),
        const Text(
          'Try: “I saw your teacher noticed something today. What happened from your point of view?”',
          style: TextStyle(color: Color(0xFF5F6680), fontSize: 12, height: 1.4),
        ),
        const SizedBox(height: 12),
        const Text(
          'Focus on patterns, context, and next steps—not labels. For urgent safety concerns, contact the school directly.',
          style: TextStyle(color: _muted, fontSize: 10),
        ),
        const SizedBox(height: 10),
        TextButton.icon(
          onPressed: () => showModalBottomSheet<void>(
            context: context,
            showDragHandle: true,
            builder: (context) => const Padding(
              padding: EdgeInsets.fromLTRB(24, 8, 24, 36),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'School support contacts',
                    style: TextStyle(
                      color: _ink,
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'The school has not published a support contact yet. For urgent concerns, use the verified school office details supplied at enrollment.',
                    style: TextStyle(color: _muted, height: 1.4),
                  ),
                ],
              ),
            ),
          ),
          icon: const Icon(Icons.support_agent_rounded),
          label: const Text('View school support contacts'),
        ),
      ],
    ),
  );
}

String _kind(Map<String, Object?> item) {
  final value = '${item['kind']}'.toLowerCase();
  if (value.contains('positive') || value.contains('praise')) {
    return 'positive';
  }
  if (value.contains('negative') || value.contains('concern')) {
    return 'negative';
  }
  return 'note';
}

List<Map<String, Object?>> _sampleBehaviours(int childIndex) => [
  {
    'kind': 'positive',
    'tag': childIndex.isEven ? 'Helped a peer' : 'Excellent focus',
    'note': childIndex.isEven
        ? 'Stayed behind to help a classmate finish the lab write-up without being asked.'
        : 'Worked independently throughout the reading task and asked thoughtful questions.',
    'created_at': '2026-09-01',
  },
  {
    'kind': 'negative',
    'tag': 'Homework not completed',
    'note': 'The latest problem set was not handed in. We agreed it would come in by Friday.',
    'created_at': '2026-08-31',
  },
  {
    'kind': 'positive',
    'tag': 'Great participation',
    'note': 'Led the group discussion and made space for quieter students to contribute.',
    'created_at': '2026-08-28',
  },
  {
    'kind': 'note',
    'tag': 'Check-in suggested',
    'note': 'Seemed quieter than usual after lunch. No immediate concern, but a gentle check-in may be helpful.',
    'created_at': '2026-08-27',
  },
];

class ParentAccountPage extends StatefulWidget {
  const ParentAccountPage({super.key});
  @override
  State<ParentAccountPage> createState() => _ParentAccountPageState();
}

class _ParentAccountPageState extends State<ParentAccountPage> {
  bool schoolUpdates = true, childAlerts = true, quietHours = false;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _canvas,
    appBar: AppBar(title: const Text('Account and settings')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Row(
          children: [
            CircleAvatar(
              radius: 34,
              backgroundColor: _navy,
              child: Text(
                'NH',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nadia Hassan',
                  style: TextStyle(
                    color: _ink,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  'nadia.hassan@example.com',
                  style: TextStyle(color: _muted),
                ),
                Chip(
                  label: Text('Parent'),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 22),
        ListTile(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => const StudentLinkPage(asParent: true),
            ),
          ),
          tileColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          leading: const CircleAvatar(
            backgroundColor: Color(0xFFEAFBFD),
            child: Icon(Icons.add_link_rounded, color: _navy),
          ),
          title: const Text(
            'Link a student',
            style: TextStyle(color: _ink, fontWeight: FontWeight.w900),
          ),
          subtitle: const Text('Enter their ID or scan their QR code'),
          trailing: const Icon(Icons.chevron_right_rounded),
        ),
        const SizedBox(height: 14),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('School updates'),
                value: schoolUpdates,
                onChanged: (v) => setState(() => schoolUpdates = v),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              SwitchListTile(
                title: const Text('Child alerts'),
                subtitle: const Text('Attendance, grades and deadlines'),
                value: childAlerts,
                onChanged: (v) => setState(() => childAlerts = v),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              SwitchListTile(
                title: const Text('Quiet hours'),
                value: quietHours,
                onChanged: (v) => setState(() => quietHours = v),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(
                onTap: () => showStudafyLanguagePicker(context),
                title: const Text('Language'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      StudafyLocaleController.instance.locale.languageCode ==
                              'ar'
                          ? 'العربية'
                          : 'English',
                      style: const TextStyle(color: _muted),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: _muted),
                  ],
                ),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              const ListTile(
                title: Text('Privacy & data'),
                trailing: Icon(Icons.chevron_right_rounded, color: _muted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        ListTile(
          onTap: () {
            ActiveContextController.instance.switchRole(StudafyRole.teacher);
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/teacher',
              (_) => false,
            );
          },
          tileColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          leading: const CircleAvatar(
            backgroundColor: Color(0xFFEFEDFF),
            child: Icon(Icons.swap_horiz_rounded, color: _navy),
          ),
          title: const Text(
            'Switch to Teacher',
            style: TextStyle(color: _ink, fontWeight: FontWeight.w900),
          ),
          subtitle: const Text('Available when this account has both roles'),
          trailing: const Icon(Icons.chevron_right_rounded),
        ),
        const SizedBox(height: 14),
        OutlinedButton(
          onPressed: () async {
            await SessionService.signOut();
            if (context.mounted) {
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/roles',
                (_) => false,
              );
            }
          },
          child: const Text(
            'Sign out',
            style: TextStyle(color: Color(0xFFFF5D5D)),
          ),
        ),
        const SizedBox(height: 10),
        Center(
          child: TextButton(
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFA5A3B5),
            ),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) =>
                    const DeleteAccountPage(email: 'nadia.hassan@example.com'),
              ),
            ),
            child: const Text(
              'Delete account',
              style: TextStyle(
                fontSize: 13,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

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
            future: StudafyDatabase.instance.unreadNotificationCount(),
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

class ParentMessagesPage extends StatefulWidget {
  const ParentMessagesPage({
    super.key,
    this.initialTab = 0,
    this.updatesOnly = false,
  });
  final int initialTab;
  final bool updatesOnly;
  @override
  State<ParentMessagesPage> createState() => _ParentMessagesPageState();
}

class _ParentMessagesPageState extends State<ParentMessagesPage> {
  late int tab = widget.initialTab;
  String query = '';
  final search = TextEditingController();
  final Set<int> acknowledgedNotices = {};
  bool absenceAlerts = true,
      lateAlerts = true,
      gradeAlerts = true,
      workAlerts = true;

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _canvas,
    body: Column(
      children: [
        _ParentHeader(title: widget.updatesOnly ? 'Updates' : 'Messages'),
        if (widget.updatesOnly)
          _UpdatesTabs(
            selected: tab,
            onSelected: (value) => setState(() => tab = value),
          )
        else
          _MessageTabs(
            selected: tab,
            onSelected: (value) => setState(() => tab = value),
          ),
        Expanded(
          child: IndexedStack(
            index: tab,
            children: [_teachers(), _notices(), _alerts()],
          ),
        ),
      ],
    ),
  );

  Widget _teachers() => FutureBuilder<List<Map<String, Object?>>>(
    future: StudafyDatabase.instance.chats(query),
    builder: (context, snapshot) {
      final rows = (snapshot.data ?? []).where((row) {
        final context = '${row['context']}'.toLowerCase();
        return !context.contains('grade 10 b') &&
            !context.contains('grade 10 a');
      }).toList();
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
        children: [
          TextField(
            controller: search,
            onChanged: (value) => setState(() => query = value.trim()),
            decoration: InputDecoration(
              hintText: 'Search teachers and conversations',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: query.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        search.clear();
                        setState(() => query = '');
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: const Color(0xFFEAFBFD),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.schedule_send_outlined,
                  color: Color(0xFF1687A0),
                  size: 20,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Teachers may reply during school communication hours.',
                    style: TextStyle(color: Color(0xFF436A72), fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (snapshot.connectionState == ConnectionState.waiting)
            const Center(child: CircularProgressIndicator()),
          if (snapshot.hasData && rows.isEmpty)
            const _AcademicEmpty(
              icon: Icons.forum_outlined,
              title: 'No conversations found',
              message: 'Try another teacher name or subject.',
            ),
          for (var i = 0; i < rows.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _TeacherThread(
                chat: rows[i],
                unread: i == 0 ? 2 : 0,
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => _ParentConversationPage(chat: rows[i]),
                    ),
                  );
                  if (mounted) setState(() {});
                },
              ),
            ),
        ],
      );
    },
  );

  Widget _notices() => FutureBuilder<List<Map<String, Object?>>>(
    future: StudafyDatabase.instance.parentNotices(),
    builder: (context, snapshot) {
      final rows = snapshot.data ?? [];
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'School and class updates',
                  style: TextStyle(color: _muted, fontSize: 12),
                ),
              ),
              TextButton.icon(
                onPressed: () => setState(
                  () => acknowledgedNotices.addAll(
                    rows.map((row) => row['id'] as int),
                  ),
                ),
                icon: const Icon(Icons.done_all_rounded, size: 17),
                label: const Text('Mark read'),
              ),
            ],
          ),
          if (snapshot.connectionState == ConnectionState.waiting)
            const Center(child: CircularProgressIndicator()),
          if (snapshot.hasData && rows.isEmpty)
            const _AcademicEmpty(
              icon: Icons.campaign_outlined,
              title: 'No notices',
              message: 'School and class notices will appear here.',
            ),
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 11),
              child: _NoticeCard(
                item: row,
                read: acknowledgedNotices.contains(row['id']),
                onAcknowledge: () =>
                    setState(() => acknowledgedNotices.add(row['id'] as int)),
              ),
            ),
        ],
      );
    },
  );

  Widget _alerts() => FutureBuilder<List<Map<String, Object?>>>(
    future: StudafyDatabase.instance.linkedChildren(),
    builder: (context, snapshot) {
      final children = snapshot.data ?? [];
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
        children: [
          _Card(
            child: Material(
              color: Colors.transparent,
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFEAFBFD),
                  child: Icon(
                    Icons.notifications_active_outlined,
                    color: _navy,
                  ),
                ),
                title: const Text(
                  'Alert settings',
                  style: TextStyle(color: _navy, fontWeight: FontWeight.w800),
                ),
                subtitle: const Text(
                  'Choose urgent events and quiet hours',
                  style: TextStyle(color: _muted, fontSize: 11),
                ),
                trailing: const Icon(
                  Icons.chevron_right_rounded,
                  color: _muted,
                ),
                onTap: _alertSettings,
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'RECENT ALERTS',
            style: TextStyle(
              color: _muted,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: .5,
            ),
          ),
          const SizedBox(height: 10),
          if (children.isEmpty)
            const _AcademicEmpty(
              icon: Icons.notifications_active_outlined,
              title: 'No child alerts',
              message: 'Attendance and work alerts appear after a child is connected.',
            ),
          for (var i = 0; i < children.length; i++) ...[
            _AlertCard(
              name: '${children[i]['student_name']}',
              kind: i.isEven ? 'Absent' : 'Late',
              detail: i.isEven
                  ? 'Marked absent from first period today'
                  : 'Arrived 12 minutes after registration',
              color: i.isEven
                  ? const Color(0xFFFF4757)
                  : const Color(0xFFF0A000),
            ),
            const SizedBox(height: 10),
          ],
          if (children.isNotEmpty)
            const _AlertCard(
              name: 'Assignment reminder',
              kind: 'Due soon',
              detail: 'Photosynthesis lab report is due tomorrow at 3:00 PM',
              color: Color(0xFF1687A0),
            ),
          const SizedBox(height: 14),
          const Text(
            'Alerts are generated from school records. Contact the school if an attendance status appears incorrect.',
            style: TextStyle(color: _muted, fontSize: 10, height: 1.4),
          ),
        ],
      );
    },
  );

  Future<void> _alertSettings() => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setSheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Alert settings',
                  style: TextStyle(
                    color: _ink,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                subtitle: Text(
                  'Urgent alerts can bypass the daily summary.',
                  style: TextStyle(color: _muted),
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Absence alerts'),
                subtitle: const Text('Immediately after school registration'),
                value: absenceAlerts,
                onChanged: (value) {
                  setSheet(() => absenceAlerts = value);
                  setState(() {});
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Late arrival alerts'),
                value: lateAlerts,
                onChanged: (value) {
                  setSheet(() => lateAlerts = value);
                  setState(() {});
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('New grade alerts'),
                value: gradeAlerts,
                onChanged: (value) {
                  setSheet(() => gradeAlerts = value);
                  setState(() {});
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Work deadline reminders'),
                value: workAlerts,
                onChanged: (value) {
                  setSheet(() => workAlerts = value);
                  setState(() {});
                },
              ),
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.bedtime_outlined, color: _navy),
                title: Text('Quiet hours'),
                subtitle: Text('9:00 PM–7:00 AM · urgent attendance only'),
                trailing: Icon(Icons.chevron_right_rounded, color: _muted),
              ),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Save preferences'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _UpdatesTabs extends StatelessWidget {
  const _UpdatesTabs({required this.selected, required this.onSelected});
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => Container(
    height: 52,
    margin: const EdgeInsets.fromLTRB(20, 16, 20, 10),
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: const Color(0xFFEDEEF7),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        for (final entry in const [
          (1, 'Notices', Icons.campaign_outlined),
          (2, 'Alerts', Icons.notifications_active_outlined),
        ])
          Expanded(
            child: InkWell(
              onTap: () => onSelected(entry.$1),
              borderRadius: BorderRadius.circular(11),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected == entry.$1
                      ? Colors.white
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(entry.$3, size: 17),
                    const SizedBox(width: 6),
                    Text(
                      entry.$2,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class _MessageTabs extends StatelessWidget {
  const _MessageTabs({required this.selected, required this.onSelected});
  final int selected;
  final ValueChanged<int> onSelected;
  @override
  Widget build(BuildContext context) => Container(
    height: 52,
    margin: const EdgeInsets.fromLTRB(20, 16, 20, 10),
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: const Color(0xFFEDEEF7),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        for (var i = 0; i < 3; i++)
          Expanded(
            child: InkWell(
              onTap: () => onSelected(i),
              borderRadius: BorderRadius.circular(11),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected == i ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(11),
                  boxShadow: selected == i
                      ? const [
                          BoxShadow(color: Color(0x10241D73), blurRadius: 6),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      const [
                        Icons.school_outlined,
                        Icons.campaign_outlined,
                        Icons.notifications_active_outlined,
                      ][i],
                      size: 16,
                      color: selected == i ? _navy : _muted,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      const ['Teachers', 'Notices', 'Alerts'][i],
                      style: TextStyle(
                        color: selected == i ? _navy : _muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class _TeacherThread extends StatelessWidget {
  const _TeacherThread({
    required this.chat,
    required this.unread,
    required this.onTap,
  });
  final Map<String, Object?> chat;
  final int unread;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => _Card(
    child: InkWell(
      onTap: onTap,
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: Color(chat['color'] as int),
            child: Text(
              '${chat['initials']}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${chat['contact_name']}',
                  style: const TextStyle(
                    color: _navy,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '${chat['context']}',
                  style: const TextStyle(color: _muted, fontSize: 11),
                ),
                const SizedBox(height: 5),
                Text(
                  '${chat['last_message'] ?? ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: unread > 0 ? const Color(0xFF586078) : _muted,
                    fontSize: 12,
                    fontWeight: unread > 0
                        ? FontWeight.w700
                        : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                '09:12',
                style: TextStyle(color: _muted, fontSize: 10),
              ),
              const SizedBox(height: 8),
              if (unread > 0)
                CircleAvatar(
                  radius: 10,
                  backgroundColor: _cyan,
                  child: Text(
                    '$unread',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({
    required this.item,
    required this.read,
    required this.onAcknowledge,
  });
  final Map<String, Object?> item;
  final bool read;
  final VoidCallback onAcknowledge;
  @override
  Widget build(BuildContext context) => _Card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${item['class_name']} · Grade ${item['grade']} ${item['section']}',
                style: const TextStyle(
                  color: _navy,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (item['mandatory'] == 1)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE1E1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Important',
                  style: TextStyle(
                    color: Color(0xFFC62828),
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (item['title'] != null) ...[
          Text(
            '${item['title']}',
            style: const TextStyle(
              color: _ink,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
        ],
        Text(
          '${item['message']}',
          style: const TextStyle(color: Color(0xFF626981), height: 1.35),
        ),
        const SizedBox(height: 9),
        if (item['meeting_url'] != null) ...[
          Text(
            'Google Meet · ${item['meeting_at']}',
            style: const TextStyle(color: _muted, fontSize: 11),
          ),
          const SizedBox(height: 7),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                Clipboard.setData(
                  ClipboardData(text: '${item['meeting_url']}'),
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Meet link copied. Open it in Google Meet.'),
                  ),
                );
              },
              icon: const Icon(Icons.video_call_rounded),
              label: const Text('Open in Google Meet'),
            ),
          ),
          const SizedBox(height: 7),
        ],
        Row(
          children: [
            const Expanded(
              child: Text(
                'School update',
                style: TextStyle(color: _muted, fontSize: 10),
              ),
            ),
            TextButton.icon(
              onPressed: read ? null : onAcknowledge,
              icon: Icon(
                read ? Icons.done_all_rounded : Icons.check_rounded,
                size: 15,
              ),
              label: Text(read ? 'Read' : 'Acknowledge'),
            ),
          ],
        ),
      ],
    ),
  );
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({
    required this.name,
    required this.kind,
    required this.detail,
    required this.color,
  });
  final String name, kind, detail;
  final Color color;
  @override
  Widget build(BuildContext context) => _Card(
    child: Row(
      children: [
        CircleAvatar(
          backgroundColor: color.withValues(alpha: .12),
          child: Icon(
            Icons.notifications_active_outlined,
            color: color,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  color: _navy,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(detail, style: const TextStyle(color: _muted, fontSize: 11)),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            kind,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    ),
  );
}

class _ParentConversationPage extends StatefulWidget {
  const _ParentConversationPage({required this.chat});
  final Map<String, Object?> chat;
  @override
  State<_ParentConversationPage> createState() =>
      _ParentConversationPageState();
}

class _ParentConversationPageState extends State<_ParentConversationPage> {
  final composer = TextEditingController();
  @override
  void dispose() {
    composer.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final body = composer.text.trim();
    if (body.isEmpty) return;
    await StudafyDatabase.instance.sendMessage(widget.chat['id'] as int, body);
    composer.clear();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _canvas,
    appBar: AppBar(
      backgroundColor: Colors.white,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${widget.chat['contact_name']}',
            style: const TextStyle(fontSize: 16),
          ),
          Text(
            '${widget.chat['context']}',
            style: const TextStyle(
              color: _muted,
              fontSize: 10,
              fontWeight: FontWeight.normal,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          onPressed: () => showModalBottomSheet<void>(
            context: context,
            showDragHandle: true,
            builder: (context) => Padding(
              padding: const EdgeInsets.fromLTRB(22, 6, 22, 30),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${widget.chat['contact_name']}',
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${widget.chat['context']}',
                    style: const TextStyle(color: _muted),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Messages are part of the school record. For urgent safeguarding or attendance matters, contact the school office directly.',
                    style: TextStyle(height: 1.4),
                  ),
                ],
              ),
            ),
          ),
          icon: const Icon(Icons.info_outline_rounded),
        ),
      ],
    ),
    body: Column(
      children: [
        Container(
          width: double.infinity,
          color: const Color(0xFFFFFAED),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          child: const Text(
            'Keep messages focused on learning and wellbeing. For emergencies, call the school.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF8A7650), fontSize: 10),
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Map<String, Object?>>>(
            future: StudafyDatabase.instance.messages(widget.chat['id'] as int),
            builder: (context, snapshot) => ListView(
              padding: const EdgeInsets.all(18),
              children: [
                for (final message in snapshot.data ?? <Map<String, Object?>>[])
                  Align(
                    alignment: message['sent_by_me'] == 1
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 11,
                      ),
                      constraints: const BoxConstraints(maxWidth: 290),
                      decoration: BoxDecoration(
                        color: message['sent_by_me'] == 1
                            ? _navy
                            : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        '${message['body']}',
                        style: TextStyle(
                          color: message['sent_by_me'] == 1
                              ? Colors.white
                              : _ink,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(12, 9, 12, 10),
            child: Column(
              children: [
                SizedBox(
                  height: 32,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final reply in [
                        'Thank you',
                        'Can we discuss this?',
                        'I’ll follow up at home',
                      ])
                        Padding(
                          padding: const EdgeInsets.only(right: 7),
                          child: ActionChip(
                            label: Text(
                              reply,
                              style: const TextStyle(fontSize: 10),
                            ),
                            onPressed: () {
                              composer.text = reply;
                              setState(() {});
                            },
                          ),
                        ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => const ParentMessagesPage(),
                        ),
                      ),
                      icon: const Icon(Icons.attach_file_rounded),
                    ),
                    Expanded(
                      child: TextField(
                        controller: composer,
                        minLines: 1,
                        maxLines: 4,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          hintText: 'Message teacher…',
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: composer.text.trim().isEmpty ? null : _send,
                      icon: const Icon(Icons.send_rounded),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

String _initials(String name) => name
    .trim()
    .split(RegExp(r'\s+'))
    .take(2)
    .map((part) => part.isEmpty ? '' : part[0].toUpperCase())
    .join();
