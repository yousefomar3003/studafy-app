part of '../../../parent_features.dart';

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
    future: ParentRepositoryScope.read(context).chats(query),
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
    future: ParentRepositoryScope.read(context).parentNotices(),
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
    future: ParentRepositoryScope.read(context).linkedChildren(),
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
