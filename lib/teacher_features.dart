import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image_picker/image_picker.dart';

import 'studafy_database.dart';
import 'student_linking.dart';
import 'core/studafy_domain.dart';
import 'core/studafy_localizations.dart';
import 'core/runtime_environment.dart';
import 'data/backend.dart';
import 'data/studafy_repository.dart';
import 'data/supabase_repository.dart';
import 'data/session_service.dart';

const _navy = Color(0xFF241D73),
    _ink = Color(0xFF171441),
    _muted = Color(0xFF8D94AF);
const _cyan = Color(0xFF20C6E8),
    _violet = Color(0xFF7737EE),
    _coral = Color(0xFFFF6B6B),
    _mint = Color(0xFF20B981),
    _sun = Color(0xFFFFB84D);
String _dayName(int day) =>
    const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][day - 1];

class _SessionDraft {
  _SessionDraft({
    required this.weekday,
    required this.start,
    required this.end,
  });
  int weekday;
  TimeOfDay start, end;
}

class _AttachmentDraft {
  const _AttachmentDraft(this.kind, this.name, this.uri);
  final String kind, name, uri;
  Map<String, String> toMap() => {'kind': kind, 'name': name, 'uri': uri};
}

class _AttachmentComposer extends StatelessWidget {
  const _AttachmentComposer({required this.items, required this.onChanged});
  final List<_AttachmentDraft> items;
  final VoidCallback onChanged;

  Future<void> _pickFiles() async {
    final files = await FilePicker.pickFiles();
    for (final file in files) {
      if (file.path == null) continue;
      final ext = file.name.split('.').last.toLowerCase();
      final kind = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'heic'].contains(ext)
          ? 'image'
          : 'file';
      final stored = await StudafyDatabase.instance.persistAttachmentFile(
        file.path!,
        file.name,
      );
      items.add(_AttachmentDraft(kind, file.name, stored));
    }
    onChanged();
  }

  Future<void> _pickPhotos() async {
    final photos = await ImagePicker().pickMultiImage();
    for (final photo in photos) {
      final stored = await StudafyDatabase.instance.persistAttachmentFile(
        photo.path,
        photo.name,
      );
      items.add(_AttachmentDraft('image', photo.name, stored));
    }
    onChanged();
  }

  Future<void> _addLink(BuildContext context) async {
    final label = TextEditingController(), url = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Attach a link'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: label,
              decoration: const InputDecoration(labelText: 'Link title'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: url,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'URL',
                hintText: 'https://…',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Add link'),
          ),
        ],
      ),
    );
    if (saved != true || url.text.trim().isEmpty) return;
    items.add(
      _AttachmentDraft(
        'link',
        label.text.trim().isEmpty ? url.text.trim() : label.text.trim(),
        url.text.trim(),
      ),
    );
    onChanged();
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [_cyan.withValues(alpha: .10), _violet.withValues(alpha: .08)],
      ),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: _cyan.withValues(alpha: .22)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.attach_file_rounded, color: _violet, size: 19),
            SizedBox(width: 7),
            Text(
              'Attachments',
              style: TextStyle(color: _ink, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        const SizedBox(height: 9),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: [
            _AttachButton(
              icon: Icons.insert_drive_file_rounded,
              label: 'Files',
              color: _violet,
              onTap: _pickFiles,
            ),
            _AttachButton(
              icon: Icons.add_photo_alternate_rounded,
              label: 'Photos',
              color: _coral,
              onTap: _pickPhotos,
            ),
            _AttachButton(
              icon: Icons.link_rounded,
              label: 'Link',
              color: _mint,
              onTap: () => _addLink(context),
            ),
          ],
        ),
        if (items.isNotEmpty) ...[
          const SizedBox(height: 9),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final item in items)
                InputChip(
                  avatar: Icon(
                    item.kind == 'image'
                        ? Icons.image_rounded
                        : item.kind == 'link'
                        ? Icons.link_rounded
                        : Icons.description_rounded,
                    size: 16,
                    color: _navy,
                  ),
                  label: Text(item.name, overflow: TextOverflow.ellipsis),
                  onDeleted: () {
                    items.remove(item);
                    onChanged();
                  },
                ),
            ],
          ),
        ],
      ],
    ),
  );
}

class _AttachButton extends StatelessWidget {
  const _AttachButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ActionChip(
    avatar: Icon(icon, size: 17, color: color),
    label: Text(label),
    backgroundColor: Colors.white,
    side: BorderSide(color: color.withValues(alpha: .22)),
    onPressed: onTap,
  );
}

Widget _attachmentCount(Object? count, {VoidCallback? onTap}) {
  final value = (count as int?) ?? 0;
  if (value == 0) return const SizedBox.shrink();
  return ActionChip(
    visualDensity: VisualDensity.compact,
    avatar: const Icon(Icons.attach_file_rounded, size: 15, color: _violet),
    label: Text('$value'),
    onPressed: onTap,
  );
}

Future<void> _showAttachments(
  BuildContext context,
  String ownerType,
  int ownerId,
) async {
  final rows = await StudafyDatabase.instance.attachments(ownerType, ownerId);
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Attachments',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 10),
            for (final row in rows)
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: row['kind'] == 'image'
                      ? _coral.withValues(alpha: .14)
                      : row['kind'] == 'link'
                      ? _mint.withValues(alpha: .14)
                      : _violet.withValues(alpha: .14),
                  child: Icon(
                    row['kind'] == 'image'
                        ? Icons.image_rounded
                        : row['kind'] == 'link'
                        ? Icons.link_rounded
                        : Icons.description_rounded,
                    color: row['kind'] == 'image'
                        ? _coral
                        : row['kind'] == 'link'
                        ? _mint
                        : _violet,
                  ),
                ),
                title: Text('${row['name']}'),
                subtitle: Text('${row['kind']}'),
                trailing: const Icon(Icons.ios_share_rounded),
                onTap: () async {
                  if (row['kind'] == 'link') {
                    await SharePlus.instance.share(
                      ShareParams(text: '${row['uri']}'),
                    );
                  } else {
                    await SharePlus.instance.share(
                      ShareParams(files: [XFile('${row['uri']}')]),
                    );
                  }
                },
              ),
          ],
        ),
      ),
    ),
  );
}

class FeatureHeader extends StatelessWidget {
  const FeatureHeader(this.title, {super.key});
  final String title;
  @override
  Widget build(BuildContext c) => Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [Colors.white, _cyan.withValues(alpha: .055)],
      ),
    ),
    padding: const EdgeInsets.fromLTRB(20, 12, 16, 14),
    child: SafeArea(
      bottom: false,
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: _ink,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Badge(
            label: const Text('3'),
            child: IconButton(
              onPressed: () => Navigator.push(
                c,
                MaterialPageRoute(builder: (_) => const ChatsPage()),
              ),
              icon: const Icon(Icons.chat_bubble_outline),
            ),
          ),
          Badge(
            backgroundColor: Colors.red,
            label: const Text('3'),
            child: IconButton(
              onPressed: () => Navigator.push(
                c,
                MaterialPageRoute(builder: (_) => const NotificationsPage()),
              ),
              icon: const Icon(Icons.notifications_none),
            ),
          ),
          InkWell(
            onTap: () => Navigator.push(
              c,
              MaterialPageRoute(builder: (_) => const MyStudafyPage()),
            ),
            borderRadius: BorderRadius.circular(24),
            child: const CircleAvatar(
              backgroundColor: _navy,
              child: Text(
                'RH',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class FeatureCard extends StatelessWidget {
  const FeatureCard({super.key, required this.child, this.onTap, this.tint});
  final Widget child;
  final VoidCallback? onTap;
  final Color? tint;
  @override
  Widget build(BuildContext c) => Card(
    elevation: 1,
    shadowColor: _violet.withValues(alpha: .12),
    color: tint == null
        ? Colors.white
        : Color.alphaBlend(tint!.withValues(alpha: .065), Colors.white),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: BorderSide(color: (tint ?? _cyan).withValues(alpha: .11)),
    ),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(padding: const EdgeInsets.all(17), child: child),
    ),
  );
}

class Segments extends StatelessWidget {
  const Segments({
    super.key,
    required this.labels,
    required this.index,
    required this.onTap,
  });
  final List<String> labels;
  final int index;
  final ValueChanged<int> onTap;
  @override
  Widget build(BuildContext c) => Container(
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: const Color(0xFFECEEF7),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        for (var i = 0; i < labels.length; i++)
          Expanded(
            child: InkWell(
              onTap: () => onTap(i),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  color: index == i ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Text(
                  labels[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: index == i ? _navy : _muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class StatusBadge extends StatelessWidget {
  const StatusBadge(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext c) {
    final color = text == 'Published' || text == 'Marked'
        ? const Color(0xFF16875B)
        : text == 'Rejected'
        ? Colors.red
        : const Color(0xFFB37805);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class GradebookPage extends StatefulWidget {
  const GradebookPage({super.key});
  @override
  State<GradebookPage> createState() => _GradebookPageState();
}

class DatabaseClassesPage extends StatefulWidget {
  const DatabaseClassesPage({super.key});
  @override
  State<DatabaseClassesPage> createState() => _DatabaseClassesPageState();
}

class _DatabaseClassesPageState extends State<DatabaseClassesPage> {
  @override
  Widget build(BuildContext context) => Column(
    children: [
      const FeatureHeader('Classes'),
      Expanded(
        child: FutureBuilder<List<Map<String, Object?>>>(
          future: StudafyDatabase.instance.classes(),
          builder: (context, snapshot) => ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Flexible(
                    child: Text(
                      'My classes',
                      style: TextStyle(
                        color: _ink,
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: () => _createClass(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Create class'),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              if (snapshot.connectionState == ConnectionState.waiting)
                const Center(child: CircularProgressIndicator()),
              for (final row in snapshot.data ?? <Map<String, Object?>>[])
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: FeatureCard(
                    tint: Color(row['color'] as int),
                    onTap: () => _classDetails(context, row),
                    child: Row(
                      children: [
                        Container(
                          width: 4,
                          height: 64,
                          decoration: BoxDecoration(
                            color: Color(row['color'] as int),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${row['name']}',
                                style: const TextStyle(
                                  color: _ink,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                'Grade ${row['grade']} · Section ${row['section']}',
                                style: const TextStyle(color: _muted),
                              ),
                              Text(
                                '${row['student_count']} students · ${row['weekly_sessions']} classes/week · ${row['room']}',
                                style: const TextStyle(
                                  color: _muted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => _invite(context, row['id'] as int),
                          icon: const Icon(Icons.person_add_alt_1_outlined),
                        ),
                        const Icon(Icons.chevron_right, color: _muted),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ],
  );

  Future<void> _createClass(BuildContext context) async {
    final name = TextEditingController();
    final room = TextEditingController();
    int grade = 10;
    String section = 'A';
    int weeklySessions = 1;
    final sessions = <_SessionDraft>[
      _SessionDraft(
        weekday: 1,
        start: const TimeOfDay(hour: 8, minute: 0),
        end: const TimeOfDay(hour: 8, minute: 50),
      ),
    ];
    const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: const Text('Create a new classroom'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Class name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: room,
                  decoration: const InputDecoration(labelText: 'Room'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: grade,
                        decoration: const InputDecoration(labelText: 'Grade'),
                        items: List.generate(
                          12,
                          (i) => DropdownMenuItem(
                            value: i + 1,
                            child: Text('Grade ${i + 1}'),
                          ),
                        ),
                        onChanged: (v) => setDialog(() => grade = v!),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: section,
                        decoration: const InputDecoration(labelText: 'Section'),
                        items: ['A', 'B', 'C', 'D']
                            .map(
                              (v) => DropdownMenuItem(value: v, child: Text(v)),
                            )
                            .toList(),
                        onChanged: (v) => setDialog(() => section = v!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<int>(
                  isExpanded: true,
                  initialValue: weeklySessions,
                  decoration: const InputDecoration(
                    labelText: 'How many classes each week?',
                    prefixIcon: Icon(Icons.event_repeat_rounded),
                  ),
                  items: List.generate(
                    14,
                    (i) => DropdownMenuItem(
                      value: i + 1,
                      child: Text('${i + 1} ${i == 0 ? 'class' : 'classes'}'),
                    ),
                  ),
                  onChanged: (value) => setDialog(() {
                    weeklySessions = value ?? 1;
                    while (sessions.length < weeklySessions) {
                      final last = sessions.last;
                      sessions.add(
                        _SessionDraft(
                          weekday: last.weekday,
                          start: last.start,
                          end: last.end,
                        ),
                      );
                    }
                    while (sessions.length > weeklySessions) {
                      sessions.removeLast();
                    }
                  }),
                ),
                const SizedBox(height: 18),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Choose the day and time for every class',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(height: 8),
                for (var i = 0; i < sessions.length; i++)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: [
                        _cyan,
                        _violet,
                        _coral,
                        _mint,
                        _sun,
                      ][i % 5].withValues(alpha: .08),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Class ${i + 1}',
                          style: const TextStyle(
                            color: _ink,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<int>(
                          initialValue: sessions[i].weekday,
                          decoration: const InputDecoration(labelText: 'Day'),
                          items: List.generate(
                            7,
                            (day) => DropdownMenuItem(
                              value: day + 1,
                              child: Text(dayNames[day]),
                            ),
                          ),
                          onChanged: (value) =>
                              setDialog(() => sessions[i].weekday = value ?? 1),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () async {
                                  final t = await showTimePicker(
                                    context: context,
                                    initialTime: sessions[i].start,
                                  );
                                  if (t != null) {
                                    setDialog(() => sessions[i].start = t);
                                  }
                                },
                                child: Text(sessions[i].start.format(context)),
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 6),
                              child: Text('to'),
                            ),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () async {
                                  final t = await showTimePicker(
                                    context: context,
                                    initialTime: sessions[i].end,
                                  );
                                  if (t != null) {
                                    setDialog(() => sessions[i].end = t);
                                  }
                                },
                                child: Text(sessions[i].end.format(context)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (name.text.trim().isEmpty || sessions.isEmpty) return;
                String time(TimeOfDay t) =>
                    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
                final first = sessions.first;
                await StudafyDatabase.instance.addClassWithSchedule(
                  {
                    'name': name.text.trim(),
                    'grade': grade,
                    'section': section,
                    'room': room.text.trim().isEmpty ? 'TBD' : room.text.trim(),
                    'start_time': time(first.start),
                    'end_time': time(first.end),
                    'weekly_sessions': weeklySessions,
                    'color': [
                      _navy,
                      _cyan,
                      _violet,
                      _coral,
                      _mint,
                    ][DateTime.now().microsecond % 5].toARGB32(),
                  },
                  [
                    for (var i = 0; i < sessions.length; i++)
                      {
                        'weekday': sessions[i].weekday,
                        'session_number': i + 1,
                        'start_time': time(sessions[i].start),
                        'end_time': time(sessions[i].end),
                      },
                  ],
                );
                if (context.mounted) Navigator.pop(context, true);
              },
              child: const Text('Create classroom'),
            ),
          ],
        ),
      ),
    );
    if (saved == true) setState(() {});
  }

  Future<void> _invite(BuildContext context, int classId) async {
    final link = await StudafyDatabase.instance.createInviteLink(classId);
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Invite students'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Share this secure link. Students are added only after they open it and join the class.',
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _navy.withValues(alpha: .06),
                borderRadius: BorderRadius.circular(14),
              ),
              child: SelectableText(
                link,
                style: const TextStyle(
                  color: _navy,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: link));
              if (dialogContext.mounted) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('Invite link copied.')),
                );
              }
            },
            icon: const Icon(Icons.copy),
            label: const Text('Copy'),
          ),
          FilledButton.icon(
            onPressed: () => SharePlus.instance.share(
              ShareParams(text: 'Join my Studafy class: $link'),
            ),
            icon: const Icon(Icons.ios_share),
            label: const Text('Share link'),
          ),
        ],
      ),
    );
  }

  Future<void> _classDetails(
    BuildContext context,
    Map<String, Object?> row,
  ) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ClassWorkspacePage(classData: row)),
    );
    setState(() {});
  }

  Future<void> attendanceEditor(
    BuildContext context,
    Map<String, Object?> row,
    List<Map<String, Object?>> students,
  ) async {
    var date = DateTime.now();
    var saved = await StudafyDatabase.instance.attendanceFor(
      row['id'] as int,
      date,
    );
    var values = {
      for (final s in students) s['id'] as int: saved[s['id']] ?? true,
    };
    if (!context.mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Attendance · ${row['name']}',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: date,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    saved = await StudafyDatabase.instance.attendanceFor(
                      row['id'] as int,
                      picked,
                    );
                    setSheet(() {
                      date = picked;
                      values = {
                        for (final s in students)
                          s['id'] as int: saved[s['id']] ?? true,
                      };
                    });
                  }
                },
                icon: const Icon(Icons.calendar_month),
                label: Text(
                  '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
                ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final student in students)
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('${student['name']}'),
                        subtitle: Text(
                          values[student['id']]! ? 'Present' : 'Absent',
                        ),
                        value: values[student['id']]!,
                        onChanged: (v) =>
                            setSheet(() => values[student['id'] as int] = v),
                      ),
                  ],
                ),
              ),
              FilledButton(
                onPressed: () async {
                  await StudafyDatabase.instance.saveAttendance(
                    row['id'] as int,
                    values,
                    date,
                  );
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Attendance saved for selected date.'),
                      ),
                    );
                  }
                },
                child: const Text('Save attendance'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ClassWorkspacePage extends StatefulWidget {
  const ClassWorkspacePage({super.key, required this.classData});
  final Map<String, Object?> classData;
  @override
  State<ClassWorkspacePage> createState() => _ClassWorkspacePageState();
}

class _ClassWorkspacePageState extends State<ClassWorkspacePage> {
  int tab = 0;
  int get classId => widget.classData['id'] as int;
  late Future<List<Object>> _overviewFuture;
  late Future<List<Map<String, Object?>>> _attendanceFuture;
  late Future<List<Map<String, Object?>>> _notebookFuture;

  @override
  void initState() {
    super.initState();
    _reloadWorkspace();
  }

  void _reloadWorkspace() {
    _overviewFuture = Future.wait<Object>([
      StudafyDatabase.instance.classSchedule(classId),
      StudafyDatabase.instance.students(classId),
    ]);
    _attendanceFuture = StudafyDatabase.instance.attendanceDates(classId);
    _notebookFuture = StudafyDatabase.instance.notebooksForClass(classId);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _canvasColor,
    appBar: AppBar(
      backgroundColor: Colors.white,
      title: Text(
        '${widget.classData['name']} · G${widget.classData['grade']} ${widget.classData['section']}',
      ),
    ),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Segments(
            labels: const ['Class', 'Attendance', 'Notebook'],
            index: tab,
            onTap: (v) => setState(() => tab = v),
          ),
        ),
        Expanded(
          child: switch (tab) {
            0 => _overview(),
            1 => _attendanceHistory(),
            _ => _notebook(),
          },
        ),
      ],
    ),
  );
  Widget _overview() => FutureBuilder<List<Object>>(
    future: _overviewFuture,
    builder: (context, snapshot) {
      final schedule =
              (snapshot.data?[0] as List<Map<String, Object?>>?) ??
              <Map<String, Object?>>[],
          students =
              (snapshot.data?[1] as List<Map<String, Object?>>?) ??
              <Map<String, Object?>>[];
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          FeatureCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${widget.classData['room']}',
                  style: const TextStyle(color: _muted),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    for (final slot in schedule)
                      Chip(
                        label: Text(
                          '${_dayName(slot['weekday'] as int)} ${slot['start_time']}–${slot['end_time']}',
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '${students.length} students',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: _ink,
            ),
          ),
          for (final student in students)
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: _navy,
                child: Icon(Icons.person, color: Colors.white),
              ),
              title: Text('${student['name']}'),
              subtitle: Text('${student['studafy_id'] ?? student['email']}'),
            ),
        ],
      );
    },
  );
  Widget _attendanceHistory() => FutureBuilder<List<Map<String, Object?>>>(
    future: _attendanceFuture,
    builder: (context, snapshot) {
      final dates = snapshot.data ?? [];
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          FilledButton.icon(
            onPressed: () => _editAttendance(DateTime.now()),
            icon: const Icon(Icons.add),
            label: const Text('Record attendance'),
          ),
          const SizedBox(height: 16),
          const Text(
            'Attendance history',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: _ink,
            ),
          ),
          const SizedBox(height: 10),
          if (dates.isEmpty)
            const Text(
              'No attendance has been recorded yet.',
              style: TextStyle(color: _muted),
            ),
          for (final row in dates)
            Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: FeatureCard(
                onTap: () => _editAttendance(DateTime.parse('${row['day']}')),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_month, color: _navy),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${row['day']}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: _ink,
                            ),
                          ),
                          Text(
                            '${row['present']} present · ${(row['total'] as int) - (row['present'] as int)} absent',
                            style: const TextStyle(color: _muted),
                          ),
                        ],
                      ),
                    ),
                    const Text(
                      'Edit',
                      style: TextStyle(
                        color: _navy,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
    },
  );
  Future<void> _editAttendance(DateTime initial) async {
    var date = initial;
    final students = await StudafyDatabase.instance.students(classId);
    var old = await StudafyDatabase.instance.attendanceDetails(classId, date);
    var values = {
      for (final s in students)
        s['id'] as int:
            old[s['id']] ??
            <String, String?>{'status': 'present', 'reason': null},
    };
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OutlinedButton.icon(
                onPressed: () async {
                  final p = await showDatePicker(
                    context: context,
                    initialDate: date,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (p != null) {
                    old = await StudafyDatabase.instance.attendanceDetails(
                      classId,
                      p,
                    );
                    setSheet(() {
                      date = p;
                      values = {
                        for (final s in students)
                          s['id'] as int:
                              old[s['id']] ??
                              <String, String?>{
                                'status': 'present',
                                'reason': null,
                              },
                      };
                    });
                  }
                },
                icon: const Icon(Icons.calendar_month),
                label: Text(date.toIso8601String().substring(0, 10)),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final s in students)
                      Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _canvasColor,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${s['name']}',
                              style: const TextStyle(
                                color: _ink,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              isExpanded: true,
                              initialValue: values[s['id']]!['status'],
                              decoration: const InputDecoration(
                                labelText: 'Attendance status',
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'present',
                                  child: Text('Present'),
                                ),
                                DropdownMenuItem(
                                  value: 'absent',
                                  child: Text('Absent'),
                                ),
                                DropdownMenuItem(
                                  value: 'tardy',
                                  child: Text('Tardy'),
                                ),
                                DropdownMenuItem(
                                  value: 'excused',
                                  child: Text('Excused absence'),
                                ),
                              ],
                              onChanged: (v) => setSheet(
                                () => values[s['id'] as int]!['status'] = v,
                              ),
                            ),
                            if (values[s['id']]!['status'] == 'excused') ...[
                              const SizedBox(height: 8),
                              TextFormField(
                                initialValue: values[s['id']]!['reason'],
                                onChanged: (v) =>
                                    values[s['id'] as int]!['reason'] = v,
                                decoration: const InputDecoration(
                                  labelText: 'Reason (medical, family, approved leave…)',
                                  prefixIcon: Icon(
                                    Icons.medical_information_rounded,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              FilledButton(
                onPressed: () async {
                  await StudafyDatabase.instance.saveAttendanceDetails(
                    classId,
                    date,
                    values,
                  );
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text('Save changes'),
              ),
            ],
          ),
        ),
      ),
    );
    setState(_reloadWorkspace);
  }

  Widget _notebook() => FutureBuilder<List<Map<String, Object?>>>(
    future: _notebookFuture,
    builder: (context, snapshot) {
      final notes = snapshot.data ?? [];
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          FilledButton.icon(
            onPressed: _addNotebook,
            icon: const Icon(Icons.note_add_outlined),
            label: const Text('Add lesson notes'),
          ),
          const SizedBox(height: 16),
          const Text(
            'Digital class notebook',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: _ink,
            ),
          ),
          const Text(
            'A complete, dated record students can study from.',
            style: TextStyle(color: _muted),
          ),
          const SizedBox(height: 12),
          if (notes.isEmpty) const Text('No lesson notes yet.'),
          for (final note in notes)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: FeatureCard(
                onTap: () => _addNotebook(existing: note),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${note['day']} · Class ${note['session_number']} · Week ${_weekNumber(DateTime.parse('${note['day']}'))}',
                      style: const TextStyle(
                        color: _muted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${note['lesson']}',
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if ('${note['homework']}'.isNotEmpty) ...[
                      const Divider(),
                      Text(
                        'Practice: ${note['homework']}',
                        style: const TextStyle(color: _muted),
                      ),
                    ],
                    if ((note['attachment_count'] as int? ?? 0) > 0) ...[
                      const SizedBox(height: 9),
                      _attachmentCount(
                        note['attachment_count'],
                        onTap: () => _showAttachments(
                          context,
                          'notebook',
                          note['id'] as int,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      );
    },
  );
  int _weekNumber(DateTime date) =>
      ((date.difference(DateTime(date.year, 1, 1)).inDays) / 7).floor() + 1;
  Future<void> _addNotebook({Map<String, Object?>? existing}) async {
    var date = existing == null
        ? DateTime.now()
        : DateTime.parse('${existing['day']}');
    var sessionNumber = (existing?['session_number'] as int?) ?? 1;
    final lesson = TextEditingController(text: existing?['lesson'] as String?),
        practice = TextEditingController(
          text: existing?['homework'] as String?,
        );
    final attachments = <_AttachmentDraft>[];
    final schedule = await StudafyDatabase.instance.classSchedule(classId);
    List<Map<String, Object?>> slotsForDay() =>
        schedule.where((slot) => slot['weekday'] == date.weekday).toList();
    if (existing == null && slotsForDay().isEmpty && schedule.isNotEmpty) {
      final now = DateTime.now();
      final nearest = [...schedule]
        ..sort((a, b) {
          final ad = (now.weekday - (a['weekday'] as int) + 7) % 7;
          final bd = (now.weekday - (b['weekday'] as int) + 7) % 7;
          return ad.compareTo(bd);
        });
      final daysBack =
          (now.weekday - (nearest.first['weekday'] as int) + 7) % 7;
      date = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: daysBack));
      sessionNumber = nearest.first['session_number'] as int;
    }
    if (!mounted) return;
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: Text(
            existing == null ? 'Add lesson notes' : 'Edit lesson notes',
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedButton.icon(
                  onPressed: () async {
                    final p = await showDatePicker(
                      context: context,
                      initialDate: date,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (p != null) {
                      setDialog(() {
                        date = p;
                        final slots = slotsForDay();
                        sessionNumber = slots.isEmpty
                            ? 1
                            : slots.first['session_number'] as int;
                      });
                    }
                  },
                  icon: const Icon(Icons.calendar_month_rounded),
                  label: Text(date.toIso8601String().substring(0, 10)),
                ),
                const SizedBox(height: 12),
                if (slotsForDay().isEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _coral.withValues(alpha: .10),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Text(
                      'There is no classroom session scheduled on this day.',
                      style: TextStyle(
                        color: _coral,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                else
                  DropdownButtonFormField<int>(
                    initialValue:
                        slotsForDay().any(
                          (slot) => slot['session_number'] == sessionNumber,
                        )
                        ? sessionNumber
                        : slotsForDay().first['session_number'] as int,
                    decoration: const InputDecoration(
                      labelText: 'Class session',
                      prefixIcon: Icon(Icons.schedule_rounded),
                    ),
                    items: [
                      for (final slot in slotsForDay())
                        DropdownMenuItem(
                          value: slot['session_number'] as int,
                          child: Text(
                            'Class ${slot['session_number']} · ${slot['start_time']}–${slot['end_time']}',
                          ),
                        ),
                    ],
                    onChanged: (value) =>
                        setDialog(() => sessionNumber = value ?? 1),
                  ),
                const SizedBox(height: 12),
                TextField(
                  controller: lesson,
                  maxLines: 7,
                  decoration: const InputDecoration(
                    labelText: 'Full subject notes',
                    hintText: 'Lesson explanation, definitions, examples, board notes…',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: practice,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Practice or homework',
                  ),
                ),
                const SizedBox(height: 14),
                _AttachmentComposer(
                  items: attachments,
                  onChanged: () => setDialog(() {}),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (lesson.text.trim().isEmpty || slotsForDay().isEmpty) return;
                final noteId = await StudafyDatabase.instance.saveNotebook(
                  classId,
                  lesson.text.trim(),
                  practice.text.trim(),
                  date,
                  sessionNumber,
                );
                await StudafyDatabase.instance.addAttachments(
                  'notebook',
                  noteId,
                  attachments.map((item) => item.toMap()),
                );
                if (context.mounted) Navigator.pop(context, true);
              },
              child: const Text('Publish to class'),
            ),
          ],
        ),
      ),
    );
    if (saved == true) setState(_reloadWorkspace);
  }
}

class _GradebookPageState extends State<GradebookPage> {
  int tab = 0;
  int? classId;
  void refresh() => setState(() {});
  @override
  Widget build(BuildContext c) => Column(
    children: [
      const FeatureHeader('Gradebook'),
      Expanded(
        child: FutureBuilder(
          future: Future.wait([
            StudafyDatabase.instance.classes(),
            tab == 0
                ? StudafyDatabase.instance.assessments()
                : StudafyDatabase.instance.allAssessmentSubmissions(classId),
          ]),
          builder: (c, s) {
            final classes = s.data?[0] ?? <Map<String, Object?>>[];
            final allRows = s.data?[1] ?? <Map<String, Object?>>[];
            final rows = tab == 0 && classId != null
                ? allRows.where((r) => r['class_id'] == classId).toList()
                : allRows;
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                OutlinedButton.icon(
                  onPressed: () => showAssessmentForm(c, refresh),
                  icon: const Icon(Icons.add_task_rounded),
                  label: const Text('Create exam'),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<int?>(
                  initialValue: classId,
                  decoration: const InputDecoration(labelText: 'Class'),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('All classes'),
                    ),
                    ...classes.map(
                      (r) => DropdownMenuItem<int?>(
                        value: r['id'] as int,
                        child: Text(
                          '${r['name']} · G${r['grade']} ${r['section']}',
                        ),
                      ),
                    ),
                  ],
                  onChanged: (v) => setState(() => classId = v),
                ),
                const SizedBox(height: 14),
                Segments(
                  labels: const ['Exams', 'Submissions'],
                  index: tab,
                  onTap: (v) => setState(() => tab = v),
                ),
                const SizedBox(height: 16),
                if (s.connectionState == ConnectionState.waiting)
                  const Center(child: CircularProgressIndicator()),
                for (final r in rows)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: FeatureCard(
                      tint: tab == 0
                          ? Color((r['color'] as int?) ?? 0xFF7737EE)
                          : _cyan,
                      onTap: () async {
                        if (tab == 0) {
                          await Navigator.push(
                            c,
                            MaterialPageRoute(
                              builder: (_) =>
                                  AssessmentDetailPage(assessment: r),
                            ),
                          );
                        } else {
                          await showGradeSubmission(c, r);
                        }
                        setState(() {});
                      },
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tab == 0
                                      ? ('${r['delivery']}' == 'online'
                                            ? 'Online exam'
                                            : 'Paper exam')
                                      : '${r['student_name']}',
                                  style: const TextStyle(
                                    color: _muted,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 7),
                                Text(
                                  tab == 0
                                      ? '${r['title']}'
                                      : '${r['assessment_title']}',
                                  style: const TextStyle(
                                    color: _ink,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  tab == 0
                                      ? 'Grade ${r['grade']} ${r['section']} · max ${r['max_score']}'
                                      : 'Grade ${r['grade']} ${r['section']} · ${r['score'] == null ? 'Awaiting grade' : '${r['score']}/${r['max_score']}'}',
                                  style: const TextStyle(color: _muted),
                                ),
                              ],
                            ),
                          ),
                          StatusBadge(
                            tab == 0
                                ? '${r['status']}'
                                : r['score'] == null
                                ? 'Grade'
                                : 'Graded',
                          ),
                          if (tab == 0) ...[
                            const SizedBox(width: 8),
                            _attachmentCount(
                              r['attachment_count'],
                              onTap: () =>
                                  _showAttachments(c, 'exam', r['id'] as int),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    ],
  );
}

class AssessmentDetailPage extends StatefulWidget {
  const AssessmentDetailPage({super.key, required this.assessment});
  final Map<String, Object?> assessment;
  @override
  State<AssessmentDetailPage> createState() => _AssessmentDetailPageState();
}

class _AssessmentDetailPageState extends State<AssessmentDetailPage> {
  int tab = 0;
  late Future<List<Map<String, Object?>>> _questionsFuture;
  late Future<List<Map<String, Object?>>> _submissionsFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _questionsFuture = StudafyDatabase.instance.assessmentQuestions(
      widget.assessment['id'] as int,
    );
    _submissionsFuture = StudafyDatabase.instance.assessmentSubmissions(
      widget.assessment['id'] as int,
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _canvasColor,
    appBar: AppBar(
      backgroundColor: Colors.white,
      title: Text('${widget.assessment['title']}'),
    ),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Segments(
            labels: const ['Questions', 'Submissions'],
            index: tab,
            onTap: (v) => setState(() => tab = v),
          ),
        ),
        Expanded(child: tab == 0 ? _questions() : _submissions()),
      ],
    ),
  );
  Widget _questions() => FutureBuilder(
    future: _questionsFuture,
    builder: (context, snapshot) {
      final rows = snapshot.data ?? [];
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          FeatureCard(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${widget.assessment['delivery']}' == 'online'
                            ? 'ONLINE EXAM'
                            : 'PAPER / IN-CLASS EXAM',
                        style: const TextStyle(
                          color: _muted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Maximum grade: ${widget.assessment['max_score']}',
                        style: const TextStyle(
                          color: _ink,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                StatusBadge('${widget.assessment['status']}'),
              ],
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: _addQuestion,
            icon: const Icon(Icons.add),
            label: const Text('Add question'),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < rows.length; i)
            Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: FeatureCard(
                onTap: () => _editPreferredAnswer(rows[i]),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: _navy,
                      child: Text(
                        '${i + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${rows[i]['prompt']}',
                            style: const TextStyle(
                              color: _ink,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            rows[i]['answer'] == null ||
                                    '${rows[i]['answer']}'.isEmpty
                                ? 'Tap to add preferred answer'
                                : 'Answer key: ${rows[i]['answer']}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: _muted, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${rows[i]['points']} pts',
                      style: const TextStyle(color: _muted),
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
    },
  );
  Widget _submissions() => FutureBuilder(
    future: _submissionsFuture,
    builder: (context, snapshot) {
      final rows = snapshot.data ?? [];
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (rows.isEmpty)
            const Text('No submissions yet.', style: TextStyle(color: _muted)),
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: FeatureCard(
                onTap: () async {
                  await showGradeSubmission(context, {
                    ...row,
                    'max_score': widget.assessment['max_score'],
                    'assessment_title': widget.assessment['title'],
                    'delivery': widget.assessment['delivery'],
                  });
                  setState(() {
                    _reload();
                  });
                },
                child: Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: _navy,
                      child: Icon(Icons.person, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${row['student_name']}',
                            style: const TextStyle(
                              color: _ink,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            row['score'] == null
                                ? 'Ready for grading'
                                : '${row['score']}/${widget.assessment['max_score']} · ${row['publication_state'] ?? 'draft'}',
                            style: const TextStyle(color: _muted),
                          ),
                        ],
                      ),
                    ),
                    if (row['publication_state'] == 'reviewed')
                      IconButton(
                        tooltip: 'Publish reviewed grade',
                        onPressed: () async {
                          await StudafyDatabase.instance.publishGradeSubmission(
                            row['id'] as int,
                          );
                          if (context.mounted) setState(_reload);
                        },
                        icon: const Icon(Icons.publish_rounded, color: _navy),
                      )
                    else
                      const Icon(Icons.chevron_right, color: _muted),
                  ],
                ),
              ),
            ),
        ],
      );
    },
  );
  Future<void> _addQuestion() async {
    final prompt = TextEditingController(),
        points = TextEditingController(text: '1'),
        answer = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add question'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: prompt,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Question'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: points,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Points'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: answer,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Preferred answer / marking key',
                hintText:
                    'Include required concepts and acceptable alternatives',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              await StudafyDatabase.instance.addQuestion({
                'assessment_id': widget.assessment['id'],
                'prompt': prompt.text.trim(),
                'type': 'long_answer',
                'points': int.tryParse(points.text) ?? 1,
                'options': null,
                'answer': answer.text.trim(),
              });
              if (context.mounted) Navigator.pop(context, true);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (saved == true) {
      setState(() {
        _reload();
      });
    }
  }

  Future<void> _editPreferredAnswer(Map<String, Object?> question) async {
    final answer = TextEditingController(text: '${question['answer'] ?? ''}');
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Preferred answer'),
        content: TextField(
          controller: answer,
          maxLines: 6,
          decoration: const InputDecoration(
            hintText:
                'Required ideas, model answer and acceptable alternatives',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              await StudafyDatabase.instance.updateQuestionAnswer(
                question['id'] as int,
                answer.text.trim(),
              );
              if (context.mounted) Navigator.pop(context, true);
            },
            child: const Text('Save answer key'),
          ),
        ],
      ),
    );
    if (saved == true) setState(_reload);
  }
}

Future<void> showGradeSubmission(
  BuildContext context,
  Map<String, Object?> row,
) async {
  final score = TextEditingController(text: row['score']?.toString() ?? ''),
      feedback = TextEditingController(text: row['feedback']?.toString() ?? '');
  final questions = await StudafyDatabase.instance.assessmentQuestions(
    row['assessment_id'] as int,
  );
  final questionScores = <int, TextEditingController>{
    for (final question in questions)
      question['id'] as int: TextEditingController(),
  };
  if (!context.mounted) return;
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => StatefulBuilder(
      builder: (context, update) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          8,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 28,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${row['student_name']}',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              Text(
                '${row['assessment_title'] ?? ''}',
                style: const TextStyle(color: _muted),
              ),
              const SizedBox(height: 16),
              FeatureCard(
                child: Text(
                  '${row['answer_text'] ?? 'No answer was submitted.'}',
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0EAFF),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.auto_awesome_rounded,
                          color: Color(0xFF7737EE),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'AI-assisted paper grading',
                            style: TextStyle(
                              color: _ink,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        StatusBadge('Teacher review required'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const AiGradingContainmentControls(),
                  ],
                ),
              ),
              if (questions.isNotEmpty) ...[
                const SizedBox(height: 14),
                const Text(
                  'Question review',
                  style: TextStyle(
                    color: _ink,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                for (var i = 0; i < questions.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 9),
                    child: FeatureCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Q${i + 1}. ${questions[i]['prompt']}',
                            style: const TextStyle(
                              color: _ink,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Preferred answer: ${questions[i]['answer'] ?? 'Not supplied — add one in Questions'}',
                            style: const TextStyle(color: _muted, fontSize: 11),
                          ),
                          const SizedBox(height: 9),
                          TextField(
                            controller: questionScores[questions[i]['id']],
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText:
                                  'Mark out of ${questions[i]['points']}',
                              helperText: 'Editable teacher override',
                            ),
                            onChanged: (_) {
                              final total = questionScores.values.fold<double>(
                                0,
                                (sum, controller) =>
                                    sum +
                                    (double.tryParse(controller.text) ?? 0),
                              );
                              score.text = total.toStringAsFixed(1);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
              const SizedBox(height: 14),
              TextField(
                controller: score,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Grade out of ${row['max_score']}',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: feedback,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Feedback'),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () async {
                  final value = double.tryParse(score.text);
                  if (value == null) return;
                  await StudafyDatabase.instance.gradeSubmission(
                    row['id'] as int,
                    value,
                    feedback.text.trim(),
                  );
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text('Complete review · keep unpublished'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class AiGradingContainmentControls extends StatelessWidget {
  const AiGradingContainmentControls({super.key});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text(
        'Temporarily unavailable while secure file ownership, quarantine, malware scanning, and publication controls are built.',
        style: TextStyle(color: _muted, fontSize: 11, height: 1.35),
      ),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        key: const Key('ai-grading-upload-control'),
        onPressed: StudafyRuntime.policy.allowsAiGrading ? () {} : null,
        icon: const Icon(Icons.document_scanner_outlined),
        label: const Text('Scanned-exam uploads are temporarily unavailable'),
      ),
      const SizedBox(height: 10),
      FilledButton.icon(
        key: const Key('ai-grading-generate-control'),
        onPressed: null,
        icon: const Icon(Icons.auto_awesome_rounded),
        label: const Text('Generate proposed marks'),
      ),
    ],
  );
}

class ContentPage extends StatefulWidget {
  const ContentPage({super.key});
  @override
  State<ContentPage> createState() => _ContentPageState();
}

class _ContentPageState extends State<ContentPage> {
  int tab = 0;
  int? classId;

  @override
  Widget build(BuildContext c) => Column(
    children: [
      const FeatureHeader('Content'),
      Expanded(
        child: FutureBuilder<List<List<Map<String, Object?>>>>(
          future: Future.wait([
            StudafyDatabase.instance.classes(),
            if (tab == 0 && classId != null)
              StudafyDatabase.instance.notebooksForClass(classId!)
            else if (tab == 1)
              StudafyDatabase.instance.assignments()
            else if (tab == 2)
              StudafyDatabase.instance.assessments()
            else
              Future.value(<Map<String, Object?>>[]),
          ]),
          builder: (c, s) {
            final classes = s.data?[0] ?? [];
            final allRows = s.data?[1] ?? [];
            final rows = classId == null || tab == 0
                ? allRows
                : allRows.where((r) => r['class_id'] == classId).toList();
            return Stack(
              children: [
                ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Segments(
                      labels: const ['Notebook', 'Assignments', 'Exams'],
                      index: tab,
                      onTap: (value) => setState(() => tab = value),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<int?>(
                      initialValue: classId,
                      decoration: const InputDecoration(
                        labelText: 'Class',
                        prefixIcon: Icon(Icons.school_outlined),
                      ),
                      items: [
                        if (tab != 0)
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('All classes'),
                          ),
                        ...classes.map(
                          (r) => DropdownMenuItem<int?>(
                            value: r['id'] as int,
                            child: Text(
                              '${r['name']} · G${r['grade']} ${r['section']}',
                            ),
                          ),
                        ),
                      ],
                      onChanged: (value) => setState(() => classId = value),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            _coral.withValues(alpha: .13),
                            _sun.withValues(alpha: .12),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: _coral,
                            foregroundColor: Colors.white,
                            child: Icon(Icons.assignment_rounded),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Choose a class, then publish lesson notebook content for a specific session, assign work, or create an online exam.',
                              style: TextStyle(
                                color: _ink,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (tab == 0 && classId == null)
                      const FeatureCard(
                        tint: _cyan,
                        child: Text(
                          'Select a class to view its sessions and notebook entries.',
                        ),
                      ),
                    if (s.connectionState == ConnectionState.waiting)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(28),
                          child: CircularProgressIndicator(),
                        ),
                      ),
                    for (final r in rows)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: FeatureCard(
                          tint: Color((r['color'] as int?) ?? 0xFF241D73),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 9,
                                    height: 9,
                                    color: Color(
                                      (r['color'] as int?) ?? 0xFF241D73,
                                    ),
                                  ),
                                  const SizedBox(width: 9),
                                  Expanded(
                                    child: Text(
                                      tab == 0
                                          ? '${r['day']} · Session ${r['session_number']}'
                                          : 'Grade ${r['grade']} ${r['section']}',
                                      style: const TextStyle(
                                        color: _muted,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  _attachmentCount(
                                    r['attachment_count'],
                                    onTap: () => _showAttachments(
                                      c,
                                      'assignment',
                                      r['id'] as int,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                tab == 0 ? '${r['lesson']}' : '${r['title']}',
                                style: const TextStyle(
                                  color: _ink,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                tab == 0
                                    ? ((r['homework'] as String?)?.isNotEmpty ==
                                              true
                                          ? 'Practice: ${r['homework']}'
                                          : 'No practice assigned')
                                    : tab == 1
                                    ? 'Due ${('${r['due_at']}').substring(0, 10)} · ${r['submitted']} submitted'
                                    : '${r['status']} · ${r['max_score']} marks · ${r['delivery']}',
                                style: const TextStyle(color: _muted),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                Positioned(
                  right: 20,
                  bottom: 22,
                  child: FloatingActionButton(
                    heroTag: 'teacher-teaching-create',
                    backgroundColor: _coral,
                    foregroundColor: Colors.white,
                    onPressed: () {
                      if (tab == 0) {
                        _showContentNotebookForm(c);
                      } else if (tab == 1) {
                        showAssignmentForm(c, () => setState(() {}));
                      } else {
                        showAssessmentForm(c, () => setState(() {}));
                      }
                    },
                    child: const Icon(Icons.add_rounded),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    ],
  );

  Future<void> _showContentNotebookForm(BuildContext context) async {
    if (classId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Choose a class before adding lesson content.'),
        ),
      );
      return;
    }
    var date = DateTime.now();
    var session = 1;
    final lesson = TextEditingController();
    final practice = TextEditingController();
    final attachments = <_AttachmentDraft>[];
    final schedule = await StudafyDatabase.instance.classSchedule(classId!);
    List<Map<String, Object?>> slots() =>
        schedule.where((slot) => slot['weekday'] == date.weekday).toList();
    if (slots().isNotEmpty) session = slots().first['session_number'] as int;
    if (!context.mounted) return;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, update) => AlertDialog(
          title: const Text('Publish lesson notebook'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_month_rounded),
                  title: const Text('Lesson date'),
                  subtitle: Text(date.toIso8601String().substring(0, 10)),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: dialogContext,
                      initialDate: date,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      update(() {
                        date = picked;
                        if (slots().isNotEmpty) {
                          session = slots().first['session_number'] as int;
                        }
                      });
                    }
                  },
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  initialValue:
                      slots().any((x) => x['session_number'] == session)
                      ? session
                      : null,
                  decoration: const InputDecoration(
                    labelText: 'Class session',
                    prefixIcon: Icon(Icons.schedule_rounded),
                  ),
                  items: slots()
                      .map(
                        (slot) => DropdownMenuItem<int>(
                          value: slot['session_number'] as int,
                          child: Text(
                            'Session ${slot['session_number']} · ${slot['start_time']}–${slot['end_time']}',
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => update(() => session = value ?? 1),
                ),
                if (slots().isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'No scheduled session on this date. Choose another lesson date.',
                      style: TextStyle(color: _coral),
                    ),
                  ),
                const SizedBox(height: 12),
                TextField(
                  controller: lesson,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'Lesson content',
                    hintText: 'Summary, concepts, examples and board notes',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: practice,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Practice or follow-up',
                  ),
                ),
                const SizedBox(height: 12),
                _AttachmentComposer(
                  items: attachments,
                  onChanged: () => update(() {}),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: lesson.text.trim().isEmpty || slots().isEmpty
                  ? null
                  : () async {
                      final id = await StudafyDatabase.instance.saveNotebook(
                        classId!,
                        lesson.text.trim(),
                        practice.text.trim(),
                        date,
                        session,
                      );
                      await StudafyDatabase.instance.addAttachments(
                        'notebook',
                        id,
                        attachments.map((item) => item.toMap()),
                      );
                      if (dialogContext.mounted) {
                        Navigator.pop(dialogContext, true);
                      }
                    },
              icon: const Icon(Icons.publish_rounded),
              label: const Text('Publish to students'),
            ),
          ],
        ),
      ),
    );
    if (saved == true) setState(() {});
  }
}

class CommsPage extends StatefulWidget {
  const CommsPage({super.key});
  @override
  State<CommsPage> createState() => _CommsPageState();
}

class _CommsPageState extends State<CommsPage> {
  int tab = 0;
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const FeatureHeader('Comms'),
        Expanded(
          child: tab == 0
              ? FutureBuilder<List<Map<String, Object?>>>(
                  future: StudafyDatabase.instance.notices(),
                  builder: (context, snapshot) {
                    final rows = snapshot.data ?? [];
                    return Stack(
                      children: [
                        ListView(
                          padding: const EdgeInsets.all(20),
                          children: [
                            Segments(
                              labels: const [
                                'Announcements',
                                'Behaviour',
                                'Incident',
                              ],
                              index: tab,
                              onTap: (v) => setState(() => tab = v),
                            ),
                            const SizedBox(height: 12),
                            FilledButton.icon(
                              onPressed: () => _scheduleMeet(context),
                              icon: const Icon(Icons.video_call_rounded),
                              label: const Text('Schedule Google Meet'),
                            ),
                            const SizedBox(height: 16),
                            for (final row in rows)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: FeatureCard(
                                  tint: _sun,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Wrap(
                                        spacing: 8,
                                        children: [
                                          StatusBadge(
                                            'Grade ${row['grade']} ${row['section']}',
                                          ),
                                          if (row['mandatory'] == 1)
                                            const StatusBadge('Mandatory'),
                                          if (row['meeting_url'] != null)
                                            const StatusBadge('Google Meet'),
                                        ],
                                      ),
                                      const SizedBox(height: 11),
                                      Text(
                                        '${row['title'] ?? row['message']}',
                                        style: const TextStyle(
                                          color: _ink,
                                          fontSize: 17,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      if (row['meeting_at'] != null)
                                        Text(
                                          'Scheduled ${row['meeting_at']} · Audience: ${row['audience']}',
                                          style: const TextStyle(color: _muted),
                                        ),
                                      if (row['meeting_url'] != null)
                                        TextButton.icon(
                                          onPressed: () {
                                            Clipboard.setData(
                                              ClipboardData(
                                                text: '${row['meeting_url']}',
                                              ),
                                            );
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Google Meet link copied.',
                                                ),
                                              ),
                                            );
                                          },
                                          icon: const Icon(
                                            Icons.content_copy_rounded,
                                          ),
                                          label: const Text('Copy Meet link'),
                                        ),
                                      Text(
                                        'Reached ${row['reach']} students',
                                        style: const TextStyle(color: _muted),
                                      ),
                                      if ((row['attachment_count'] as int? ??
                                              0) >
                                          0) ...[
                                        const SizedBox(height: 8),
                                        _attachmentCount(
                                          row['attachment_count'],
                                          onTap: () => _showAttachments(
                                            context,
                                            'announcement',
                                            row['id'] as int,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                        Positioned(
                          right: 20,
                          bottom: 22,
                          child: FloatingActionButton(
                            heroTag: 'teacher-inbox-create-announcement',
                            backgroundColor: _navy,
                            foregroundColor: Colors.white,
                            onPressed: () =>
                                showNoticeForm(context, () => setState(() {})),
                            child: const Icon(Icons.add),
                          ),
                        ),
                      ],
                    );
                  },
                )
              : CommsForm(tab: tab, onTab: (v) => setState(() => tab = v)),
        ),
      ],
    );
  }

  Future<void> _scheduleMeet(BuildContext context) async {
    final classes = await StudafyDatabase.instance.classes();
    if (!context.mounted) return;
    int? selectedClass;
    var audience = 'students';
    var meetingAt = DateTime.now().add(const Duration(days: 1));
    final title = TextEditingController(text: 'Class meeting');
    final agenda = TextEditingController();
    var durationMinutes = 45;
    String? saveError;
    var saving = false;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, update) => AlertDialog(
          title: const Text('Schedule Google Meet'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  isExpanded: true,
                  initialValue: selectedClass,
                  decoration: const InputDecoration(labelText: 'Class'),
                  items: classes
                      .map(
                        (item) => DropdownMenuItem<int>(
                          value: item['id'] as int,
                          child: Text(
                            '${item['name']} · G${item['grade']} ${item['section']}',
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => update(() => selectedClass = value),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: audience,
                  decoration: const InputDecoration(labelText: 'Invite'),
                  items: const [
                    DropdownMenuItem(
                      value: 'students',
                      child: Text('Students in this class'),
                    ),
                    DropdownMenuItem(
                      value: 'parents',
                      child: Text('Parents of this class'),
                    ),
                    DropdownMenuItem(
                      value: 'both',
                      child: Text('Students and parents'),
                    ),
                  ],
                  onChanged: (value) =>
                      update(() => audience = value ?? 'students'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: title,
                  decoration: const InputDecoration(labelText: 'Meeting title'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: agenda,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Agenda or preparation',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: durationMinutes,
                  decoration: const InputDecoration(labelText: 'Duration'),
                  items: const [30, 45, 60, 90]
                      .map(
                        (minutes) => DropdownMenuItem(
                          value: minutes,
                          child: Text('$minutes minutes'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      update(() => durationMinutes = value ?? 45),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event_rounded),
                  title: const Text('Date and time'),
                  subtitle: Text(meetingAt.toString().substring(0, 16)),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: dialogContext,
                      initialDate: meetingAt,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date == null || !dialogContext.mounted) return;
                    final time = await showTimePicker(
                      context: dialogContext,
                      initialTime: TimeOfDay.fromDateTime(meetingAt),
                    );
                    if (time != null) {
                      update(
                        () => meetingAt = DateTime(
                          date.year,
                          date.month,
                          date.day,
                          time.hour,
                          time.minute,
                        ),
                      );
                    }
                  },
                ),
                const Text(
                  'Recipients are previewed from active enrollment and verified guardian links. Studafy creates a unique Calendar event and Meet room; video opens in Google Meet.',
                  style: TextStyle(color: _muted, fontSize: 10, height: 1.35),
                ),
                if (saveError != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    saveError!,
                    style: const TextStyle(color: _coral, fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (selectedClass == null ||
                    title.text.trim().isEmpty ||
                    saving) {
                  return;
                }
                update(() {
                  saving = true;
                  saveError = null;
                });
                try {
                  if (!StudafyBackend.isRemote) {
                    throw StateError(
                      'Ask your school IT team to connect Google Workspace first.',
                    );
                  }
                  final selected = classes.firstWhere(
                    (item) => item['id'] == selectedClass,
                  );
                  final remoteClassId = selected['remote_id'] as String?;
                  if (remoteClassId == null) {
                    throw StateError(
                      'This class is still syncing. Try again after sync completes.',
                    );
                  }
                  await SupabaseStudafyRepository().createGoogleMeet(
                    classroomId: remoteClassId,
                    title: title.text.trim(),
                    startsAt: meetingAt,
                    duration: Duration(minutes: durationMinutes),
                    audience: switch (audience) {
                      'parents' => MeetingAudience.guardians,
                      'both' => MeetingAudience.both,
                      _ => MeetingAudience.students,
                    },
                  );
                  if (dialogContext.mounted) Navigator.pop(dialogContext, true);
                } catch (error) {
                  update(() {
                    saving = false;
                    saveError = '$error'.replaceFirst('Bad state: ', '');
                  });
                }
              },
              child: Text(saving ? 'Creating…' : 'Create & send invitation'),
            ),
          ],
        ),
      ),
    );
    if (saved == true) setState(() {});
  }
}

class CommsForm extends StatefulWidget {
  const CommsForm({super.key, required this.tab, required this.onTab});
  final int tab;
  final ValueChanged<int> onTab;
  @override
  State<CommsForm> createState() => _CommsFormState();
}

class _CommsFormState extends State<CommsForm> {
  int? studentId;
  String choice = 'Excellent work', category = 'Behaviour', severity = 'Minor';
  final note = TextEditingController();
  final attachments = <_AttachmentDraft>[];
  @override
  Widget build(BuildContext c) => FutureBuilder(
    future: StudafyDatabase.instance.students(),
    builder: (c, s) => ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Segments(
          labels: const ['Announcements', 'Behaviour', 'Incident'],
          index: widget.tab,
          onTap: widget.onTab,
        ),
        const SizedBox(height: 20),
        DropdownButtonFormField<int>(
          initialValue: studentId,
          decoration: const InputDecoration(labelText: 'Student'),
          items: (s.data ?? [])
              .map(
                (x) => DropdownMenuItem(
                  value: x['id'] as int,
                  child: Text('${x['name']}'),
                ),
              )
              .toList(),
          onChanged: (v) => setState(() => studentId = v),
        ),
        const SizedBox(height: 18),
        if (widget.tab == 1) ...[
          const Text(
            'Positive behaviour',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 9),
          Wrap(
            spacing: 8,
            children:
                [
                      'Helped a peer',
                      'Excellent work',
                      'Leadership',
                      'Great participation',
                    ]
                    .map(
                      (x) => ChoiceChip(
                        label: Text(x),
                        selected: choice == x,
                        onSelected: (_) => setState(() => choice = x),
                      ),
                    )
                    .toList(),
          ),
        ] else ...[
          const Text('Category', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 9),
          Wrap(
            spacing: 8,
            children: ['Behaviour', 'Attendance', 'Academic', 'Safety']
                .map(
                  (x) => ChoiceChip(
                    label: Text(x),
                    selected: category == x,
                    onSelected: (_) => setState(() => category = x),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 15),
          Wrap(
            spacing: 8,
            children: ['Minor', 'Moderate', 'Serious']
                .map(
                  (x) => ChoiceChip(
                    label: Text(x),
                    selected: severity == x,
                    onSelected: (_) => setState(() => severity = x),
                  ),
                )
                .toList(),
          ),
        ],
        const SizedBox(height: 18),
        TextField(
          controller: note,
          maxLines: 4,
          decoration: InputDecoration(
            labelText: widget.tab == 1 ? 'What happened' : 'Description',
          ),
        ),
        const SizedBox(height: 14),
        _AttachmentComposer(
          items: attachments,
          onChanged: () => setState(() {}),
        ),
        const SizedBox(height: 22),
        FilledButton(
          onPressed: studentId == null || note.text.trim().isEmpty
              ? null
              : () async {
                  late final int id;
                  late final String ownerType;
                  if (widget.tab == 1) {
                    ownerType = 'behaviour';
                    id = await StudafyDatabase.instance.addBehaviour({
                      'student_id': studentId,
                      'kind': 'positive',
                      'tag': choice,
                      'note': note.text.trim(),
                      'created_at': DateTime.now().toIso8601String(),
                    });
                  } else {
                    ownerType = 'incident';
                    id = await StudafyDatabase.instance.addIncident({
                      'student_id': studentId,
                      'category': category,
                      'severity': severity,
                      'description': note.text.trim(),
                      'created_at': DateTime.now().toIso8601String(),
                    });
                  }
                  await StudafyDatabase.instance.addAttachments(
                    ownerType,
                    id,
                    attachments.map((item) => item.toMap()),
                  );
                  if (c.mounted) {
                    ScaffoldMessenger.of(c).showSnackBar(
                      const SnackBar(content: Text('Saved successfully.')),
                    );
                    note.clear();
                    setState(attachments.clear);
                  }
                },
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
          child: Text(
            widget.tab == 1 ? 'Save & notify guardians' : 'Submit report',
          ),
        ),
      ],
    ),
  );
}

Future<int?> chooseClass(BuildContext c) async {
  final rows = await StudafyDatabase.instance.classes();
  if (!c.mounted) return null;
  return showDialog<int>(
    context: c,
    builder: (c) => SimpleDialog(
      title: const Text('Choose class'),
      children: rows
          .map(
            (r) => SimpleDialogOption(
              onPressed: () => Navigator.pop(c, r['id']),
              child: Text('${r['name']} · Grade ${r['grade']} ${r['section']}'),
            ),
          )
          .toList(),
    ),
  );
}

void showAssessmentForm(BuildContext c, VoidCallback done) async {
  final classId = await chooseClass(c);
  if (classId == null || !c.mounted) return;
  final title = TextEditingController(),
      max = TextEditingController(text: '20');
  final questions = <TextEditingController>[TextEditingController()];
  final attachments = <_AttachmentDraft>[];
  var delivery = 'paper';
  showDialog(
    context: c,
    builder: (c) => StatefulBuilder(
      builder: (c, setDialog) => AlertDialog(
        title: const Text('Create exam'),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: title,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: max,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Maximum score'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: delivery,
                  decoration: const InputDecoration(
                    labelText: 'How students take this exam',
                    prefixIcon: Icon(Icons.description_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'paper',
                      child: Text('Paper / in-class exam'),
                    ),
                    DropdownMenuItem(
                      value: 'online',
                      child: Text('Online exam in Studafy'),
                    ),
                  ],
                  onChanged: (value) =>
                      setDialog(() => delivery = value ?? 'paper'),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _cyan.withValues(alpha: .09),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        delivery == 'online'
                            ? Icons.language_rounded
                            : Icons.edit_document,
                        color: _cyan,
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          delivery == 'online'
                              ? 'Students complete this exam in the app.'
                              : 'Create the exam record now, then enter each student’s paper score. Published marks appear for students and parents.',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (delivery == 'online')
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Questions',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                if (delivery == 'online') const SizedBox(height: 8),
                if (delivery == 'online')
                  for (var i = 0; i < questions.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: TextField(
                        controller: questions[i],
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: 'Question ${i + 1}',
                        ),
                      ),
                    ),
                if (delivery == 'online')
                  OutlinedButton.icon(
                    onPressed: () =>
                        setDialog(() => questions.add(TextEditingController())),
                    icon: const Icon(Icons.add),
                    label: const Text('Add question'),
                  ),
                const SizedBox(height: 14),
                _AttachmentComposer(
                  items: attachments,
                  onChanged: () => setDialog(() {}),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (title.text.trim().isEmpty) return;
              final assessmentId = await StudafyDatabase.instance.addAssessment(
                {
                  'class_id': classId,
                  'type': 'Exam',
                  'title': title.text.trim(),
                  'max_score': int.tryParse(max.text) ?? 20,
                  'status': 'Published',
                  'delivery': delivery,
                  'scheduled_at': DateTime.now()
                      .add(const Duration(days: 7))
                      .toIso8601String(),
                },
              );
              await StudafyDatabase.instance.prepareAssessmentRoster(
                assessmentId,
                classId,
              );
              final valid = questions
                  .where((q) => q.text.trim().isNotEmpty)
                  .toList();
              final total = int.tryParse(max.text) ?? 20;
              for (final q in valid) {
                await StudafyDatabase.instance.addQuestion({
                  'assessment_id': assessmentId,
                  'prompt': q.text.trim(),
                  'type': 'long_answer',
                  'points': valid.isEmpty
                      ? total
                      : (total / valid.length).round(),
                  'options': null,
                  'answer': null,
                });
              }
              await StudafyDatabase.instance.addAttachments(
                'exam',
                assessmentId,
                attachments.map((item) => item.toMap()),
              );
              if (c.mounted) Navigator.pop(c);
              done();
            },
            child: const Text('Create exam'),
          ),
        ],
      ),
    ),
  );
}

void showAssignmentForm(BuildContext c, VoidCallback done) async {
  final classId = await chooseClass(c);
  if (classId == null || !c.mounted) return;
  final missing = await StudafyDatabase.instance
      .missingNotebookSessionsThisWeek(classId);
  if (missing.isNotEmpty) {
    if (!c.mounted) return;
    await showDialog<void>(
      context: c,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.menu_book_rounded, color: _coral, size: 36),
        title: const Text('Lesson notes required'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Publish the notebook notes for every class held this week before creating an assignment.',
            ),
            const SizedBox(height: 12),
            for (final slot in missing)
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text(
                  '• ${slot['day']} · class ${slot['session_number']} · ${slot['start_time']}–${slot['end_time']}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Understood'),
          ),
        ],
      ),
    );
    return;
  }
  final title = TextEditingController();
  final attachments = <_AttachmentDraft>[];
  if (!c.mounted) return;
  showDialog(
    context: c,
    builder: (c) => StatefulBuilder(
      builder: (c, setDialog) => AlertDialog(
        title: const Text('New assignment'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: title,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              const SizedBox(height: 14),
              _AttachmentComposer(
                items: attachments,
                onChanged: () => setDialog(() {}),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (title.text.trim().isEmpty) return;
              final id = await StudafyDatabase.instance.addAssignment({
                'class_id': classId,
                'title': title.text.trim(),
                'due_at': DateTime.now()
                    .add(const Duration(days: 7))
                    .toIso8601String(),
                'kind': 'assignment',
              });
              await StudafyDatabase.instance.addAttachments(
                'assignment',
                id,
                attachments.map((item) => item.toMap()),
              );
              if (c.mounted) Navigator.pop(c);
              done();
            },
            child: const Text('Create'),
          ),
        ],
      ),
    ),
  );
}

void showNoticeForm(BuildContext c, VoidCallback done) async {
  final classId = await chooseClass(c);
  if (classId == null || !c.mounted) return;
  final message = TextEditingController();
  final attachments = <_AttachmentDraft>[];
  showDialog(
    context: c,
    builder: (c) => StatefulBuilder(
      builder: (c, setDialog) => AlertDialog(
        title: const Text('New announcement'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: message,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Message'),
              ),
              const SizedBox(height: 14),
              _AttachmentComposer(
                items: attachments,
                onChanged: () => setDialog(() {}),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (message.text.trim().isEmpty) return;
              final id = await StudafyDatabase.instance.addNotice({
                'class_id': classId,
                'message': message.text.trim(),
                'mandatory': 0,
                'created_at': DateTime.now().toIso8601String(),
              });
              await StudafyDatabase.instance.addAttachments(
                'announcement',
                id,
                attachments.map((item) => item.toMap()),
              );
              if (c.mounted) Navigator.pop(c);
              done();
            },
            child: const Text('Publish'),
          ),
        ],
      ),
    ),
  );
}

class ChatsPage extends StatefulWidget {
  const ChatsPage({super.key});
  @override
  State<ChatsPage> createState() => _ChatsPageState();
}

class _ChatsPageState extends State<ChatsPage> {
  final search = TextEditingController();
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _canvasColor,
    appBar: AppBar(title: const Text('Chats'), backgroundColor: Colors.white),
    body: FutureBuilder<List<Map<String, Object?>>>(
      future: StudafyDatabase.instance.chats(search.text.trim()),
      builder: (context, snapshot) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: search,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'Search conversations',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 18),
          if (snapshot.connectionState == ConnectionState.waiting)
            const Center(child: CircularProgressIndicator()),
          for (final chat in snapshot.data ?? <Map<String, Object?>>[])
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: FeatureCard(
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ConversationPage(chat: chat),
                    ),
                  );
                  setState(() {});
                },
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 25,
                      backgroundColor: Color(chat['color'] as int),
                      child: Text(
                        '${chat['initials']}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${chat['contact_name']}',
                            style: const TextStyle(
                              color: _ink,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if ('${chat['context']}'.isNotEmpty)
                            Text(
                              '${chat['context']}',
                              style: const TextStyle(
                                color: _muted,
                                fontSize: 12,
                              ),
                            ),
                          const SizedBox(height: 6),
                          Text(
                            '${chat['last_message'] ?? ''}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: _muted),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: _muted),
                  ],
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

const _canvasColor = Color(0xFFF7F6FE);

class ConversationPage extends StatefulWidget {
  const ConversationPage({super.key, required this.chat});
  final Map<String, Object?> chat;
  @override
  State<ConversationPage> createState() => _ConversationPageState();
}

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});
  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _canvasColor,
    appBar: AppBar(
      backgroundColor: Colors.white,
      title: const Text('Notifications'),
      actions: [
        TextButton(
          onPressed: () async {
            await StudafyDatabase.instance.markNotificationsRead();
            setState(() {});
          },
          child: const Text('Mark all read'),
        ),
      ],
    ),
    body: FutureBuilder<List<Map<String, Object?>>>(
      future: StudafyDatabase.instance.notifications(),
      builder: (context, snapshot) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          for (final row in snapshot.data ?? <Map<String, Object?>>[])
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: FeatureCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: _navy.withValues(alpha: .08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _notificationIcon('${row['kind']}'),
                        color: _navy,
                      ),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${row['title']}',
                                  style: const TextStyle(
                                    color: _ink,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              if (row['is_read'] == 0)
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF20C6E8),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '${row['body']}',
                            style: const TextStyle(color: _muted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    ),
  );
  IconData _notificationIcon(String kind) => switch (kind) {
    'submission' => Icons.upload_rounded,
    'gradebook' => Icons.check_rounded,
    'attendance' => Icons.priority_high_rounded,
    'incident' => Icons.flag_rounded,
    _ => Icons.calendar_month_outlined,
  };
}

class MyStudafyPage extends StatefulWidget {
  const MyStudafyPage({super.key});
  @override
  State<MyStudafyPage> createState() => _MyStudafyPageState();
}

class _MyStudafyPageState extends State<MyStudafyPage> {
  late Future<List<Object>> data;
  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => data = Future.wait<Object>([
    StudafyDatabase.instance.profile(),
    StudafyDatabase.instance.linkedChildren(),
  ]);
  Future<void> _photo() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 82,
      maxWidth: 1200,
    );
    if (file != null) {
      await StudafyDatabase.instance.updateProfile({'photo_path': file.path});
      setState(() {
        _reload();
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _canvasColor,
    appBar: AppBar(
      backgroundColor: Colors.white,
      title: const Text('My Studafy'),
      actions: [
        IconButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ProfilePage()),
          ),
          icon: const Icon(Icons.tune_rounded),
        ),
      ],
    ),
    body: FutureBuilder<List<Object>>(
      future: data,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final p = snapshot.data![0] as Map<String, Object?>,
            children = snapshot.data![1] as List<Map<String, Object?>>;
        final path = p['photo_path'] as String?;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF241D73), Color(0xFF4037A0)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(28),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x44241D73),
                    blurRadius: 24,
                    offset: Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: _photo,
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 34,
                              backgroundColor: Colors.white24,
                              backgroundImage: path != null
                                  ? FileImage(File(path))
                                  : null,
                              child: path == null
                                  ? const Text(
                                      'RH',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    )
                                  : null,
                            ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                padding: const EdgeInsets.all(5),
                                decoration: const BoxDecoration(
                                  color: _cyanAccent,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.camera_alt_rounded,
                                  size: 14,
                                  color: _navy,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${p['name']}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              '${p['email']}',
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white24, height: 32),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'STUDAFY ID',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Row(
                    children: [
                      Expanded(
                        child: Text(
                          'ST-2H9X-46B',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.qr_code_2_rounded,
                        color: Colors.white,
                        size: 54,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'SWITCH WORKSPACE',
              style: TextStyle(
                color: _muted,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 9),
            _workspace(
              Icons.school_rounded,
              'Teacher · Al-Noor International',
              'Classes, gradebook and communications',
              true,
              () {},
            ),
            const SizedBox(height: 10),
            _workspace(
              Icons.family_restroom_rounded,
              'Parent · My Family',
              'View linked children without another login',
              false,
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ParentWorkspacePage(children: children),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'MY CHILDREN',
                    style: TextStyle(
                      color: _muted,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () =>
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ConnectionsPage(),
                        ),
                      ).then((_) {
                        setState(() {
                          _reload();
                        });
                      }),
                  icon: const Icon(Icons.add_link_rounded),
                  label: const Text('Connect'),
                ),
              ],
            ),
            for (final child in children)
              Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: FeatureCard(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => StudentNotebookPage(student: child),
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: _navy,
                        child: Text(
                          _initials('${child['student_name']}'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${child['student_name']}',
                              style: const TextStyle(
                                color: _ink,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              '${child['studafy_id']}',
                              style: const TextStyle(color: _muted),
                            ),
                          ],
                        ),
                      ),
                      const StatusBadge('Linked'),
                      const Icon(Icons.chevron_right, color: _muted),
                    ],
                  ),
                ),
              ),
            if (children.isEmpty)
              const Text(
                'No linked children yet. Use Connect to send a request.',
                style: TextStyle(color: _muted),
              ),
          ],
        );
      },
    ),
  );
  Widget _workspace(
    IconData icon,
    String title,
    String subtitle,
    bool active,
    VoidCallback tap,
  ) => FeatureCard(
    onTap: tap,
    child: Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: active
                  ? const [_navy, Color(0xFF4A41AD)]
                  : const [Color(0xFF20C6E8), Color(0xFF0FA1C0)],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, color: Colors.white),
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
              Text(
                subtitle,
                style: const TextStyle(color: _muted, fontSize: 12),
              ),
            ],
          ),
        ),
        if (active)
          const StatusBadge('Active')
        else
          const Icon(Icons.arrow_forward_rounded, color: _navy),
      ],
    ),
  );
  String _initials(String value) =>
      value.split(' ').take(2).map((e) => e[0]).join();
}

const _cyanAccent = Color(0xFF20C6E8);

class ParentWorkspacePage extends StatelessWidget {
  const ParentWorkspacePage({super.key, required this.children});
  final List<Map<String, Object?>> children;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _canvasColor,
    appBar: AppBar(
      backgroundColor: Colors.white,
      title: const Text('My Family'),
      actions: [
        TextButton.icon(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.swap_horiz_rounded),
          label: const Text('Teacher'),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_navy, Color(0xFF4037A0)]),
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.family_restroom_rounded, color: _cyanAccent, size: 34),
              SizedBox(height: 12),
              Text(
                'Parent workspace',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                'Open a linked child’s school view without using their login.',
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        for (final child in children)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: FeatureCard(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => StudentNotebookPage(student: child),
                ),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: _navy,
                    child: Icon(Icons.person_rounded, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${child['student_name']}',
                      style: const TextStyle(
                        color: _ink,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const Icon(Icons.open_in_new_rounded, color: _navy),
                ],
              ),
            ),
          ),
        if (children.isEmpty)
          FilledButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ConnectionsPage()),
            ),
            icon: const Icon(Icons.add_link_rounded),
            label: const Text('Connect a child'),
          ),
      ],
    ),
  );
}

class StudentNotebookPage extends StatefulWidget {
  const StudentNotebookPage({super.key, required this.student});
  final Map<String, Object?> student;
  @override
  State<StudentNotebookPage> createState() => _StudentNotebookPageState();
}

class _StudentNotebookPageState extends State<StudentNotebookPage> {
  int tab = 0;
  late Future<List<Map<String, Object?>>> notes;
  @override
  void initState() {
    super.initState();
    notes = StudafyDatabase.instance.studentNotebooks(
      widget.student['student_id'] as int,
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _canvasColor,
    appBar: AppBar(
      backgroundColor: Colors.white,
      title: Text('${widget.student['student_name']}'),
    ),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Segments(
            labels: const ['Overview', 'Notebook'],
            index: tab,
            onTap: (v) => setState(() => tab = v),
          ),
        ),
        Expanded(
          child: tab == 0
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.verified_user_rounded,
                        color: _navy,
                        size: 64,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Secure linked access',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      Text(
                        '${widget.student['studafy_id']}',
                        style: const TextStyle(color: _muted),
                      ),
                    ],
                  ),
                )
              : FutureBuilder<List<Map<String, Object?>>>(
                  future: notes,
                  builder: (context, snapshot) {
                    final rows = snapshot.data ?? [];
                    return ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        const Text(
                          'Class notebook',
                          style: TextStyle(
                            color: _ink,
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Text(
                          'Published lesson notes from teachers.',
                          style: TextStyle(color: _muted),
                        ),
                        const SizedBox(height: 14),
                        if (rows.isEmpty)
                          const Text('No notes have been published yet.'),
                        for (final note in rows)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: FeatureCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${note['class_name']} · G${note['grade']} ${note['section']}',
                                    style: const TextStyle(
                                      color: _navy,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  Text(
                                    '${note['day']} · Class ${note['session_number']}',
                                    style: const TextStyle(
                                      color: _muted,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    '${note['lesson']}',
                                    style: const TextStyle(color: _ink),
                                  ),
                                  if ('${note['homework']}'.isNotEmpty) ...[
                                    const Divider(),
                                    Text(
                                      'Practice: ${note['homework']}',
                                      style: const TextStyle(color: _muted),
                                    ),
                                  ],
                                  if ((note['attachment_count'] as int? ?? 0) >
                                      0) ...[
                                    const SizedBox(height: 9),
                                    _attachmentCount(
                                      note['attachment_count'],
                                      onTap: () => _showAttachments(
                                        context,
                                        'notebook',
                                        note['id'] as int,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
        ),
      ],
    ),
  );
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool biometricLock = false;
  bool weeklyDigest = true;
  bool lessonReminders = true;
  bool compactMode = false;
  String language = 'English';

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _canvasColor,
    appBar: AppBar(
      backgroundColor: Colors.white,
      title: const Text('Settings'),
    ),
    body: FutureBuilder<Map<String, Object?>>(
      future: StudafyDatabase.instance.profile(),
      builder: (context, snapshot) {
        final p = snapshot.data;
        if (p == null) return const Center(child: CircularProgressIndicator());
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            FeatureCard(
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 30,
                    backgroundColor: _navy,
                    child: Text(
                      'RH',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${p['name']}',
                          style: const TextStyle(
                            fontSize: 18,
                            color: _ink,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          '${p['email']}',
                          style: const TextStyle(color: _muted),
                        ),
                        Text(
                          '${p['school']}',
                          style: const TextStyle(color: _muted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => _edit(context, p),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            FeatureCard(
              onTap: () {
                ActiveContextController.instance.switchRole(StudafyRole.parent);
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/parent',
                  (_) => false,
                );
              },
              child: const Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Color(0xFFEAFBFD),
                    child: Icon(Icons.swap_horiz_rounded, color: _navy),
                  ),
                  SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Switch to Parent',
                          style: TextStyle(
                            color: _ink,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Use your linked parent role without signing out',
                          style: TextStyle(color: _muted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: _muted),
                ],
              ),
            ),
            const SizedBox(height: 22),
            FeatureCard(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ConnectionsPage()),
              ),
              child: const Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Color(0xFFE7F9FC),
                    child: Icon(Icons.family_restroom, color: _navy),
                  ),
                  SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Family connections',
                          style: TextStyle(
                            color: _ink,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Connect to a child using their unique Studafy ID',
                          style: TextStyle(color: _muted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: _muted),
                ],
              ),
            ),
            const SizedBox(height: 22),
            const _SettingsLabel('TEACHING'),
            const SizedBox(height: 8),
            FeatureCard(
              child: Column(
                children: [
                  _linkSetting(
                    Icons.menu_book_outlined,
                    'Subjects',
                    'Biology, Chemistry',
                  ),
                  const Divider(),
                  _linkSetting(Icons.groups_outlined, 'Classes', '4 assigned'),
                  const Divider(),
                  _linkSetting(
                    Icons.school_outlined,
                    'Homeroom',
                    'Grade 10 · Section B',
                  ),
                  const Divider(),
                  _linkSetting(Icons.badge_outlined, 'Staff ID', 'ALN-T-0219'),
                ],
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              'NOTIFICATIONS',
              style: TextStyle(color: _muted, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            FeatureCard(
              child: Column(
                children: [
                  _setting('Do Not Disturb', 'do_not_disturb', p),
                  const Divider(),
                  _setting('New submissions', 'submissions', p),
                  const Divider(),
                  _setting('Gradebook decisions', 'gradebook', p),
                  const Divider(),
                  _setting('Messages', 'messages', p),
                  const Divider(),
                  _setting(
                    'Daily attendance reminder',
                    'attendance_reminder',
                    p,
                  ),
                  const Divider(),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Weekly teaching summary'),
                    subtitle: const Text('Delivered every Sunday morning'),
                    value: weeklyDigest,
                    onChanged: (v) => setState(() => weeklyDigest = v),
                  ),
                  const Divider(),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Lesson reminders'),
                    subtitle: const Text('15 minutes before each class'),
                    value: lessonReminders,
                    onChanged: (v) => setState(() => lessonReminders = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            const _SettingsLabel('PREFERENCES'),
            const SizedBox(height: 8),
            FeatureCard(
              child: Column(
                children: [
                  _linkSetting(
                    Icons.language_rounded,
                    'Language',
                    language,
                    onTap: _chooseLanguage,
                  ),
                  const Divider(),
                  _linkSetting(
                    Icons.schedule_rounded,
                    'School week',
                    'Sunday – Thursday',
                  ),
                  const Divider(),
                  _linkSetting(
                    Icons.accessibility_new_rounded,
                    'Accessibility',
                    'Text size & contrast',
                    onTap: () => _openInfo(
                      'Accessibility',
                      'Use your device text size, increase contrast, reduce motion, and enable screen-reader labels throughout Studafy.',
                    ),
                  ),
                  const Divider(),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    secondary: const Icon(
                      Icons.view_compact_outlined,
                      color: _navy,
                    ),
                    title: const Text('Compact class lists'),
                    value: compactMode,
                    onChanged: (v) => setState(() => compactMode = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            const _SettingsLabel('SECURITY & DATA'),
            const SizedBox(height: 8),
            FeatureCard(
              child: Column(
                children: [
                  _linkSetting(
                    Icons.password_rounded,
                    'Password & sign-in',
                    'Managed by your school',
                    onTap: () => _openInfo(
                      'Password & sign-in',
                      'Your school identity provider manages your password. Contact school IT to change it or recover access.',
                    ),
                  ),
                  const Divider(),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    secondary: const Icon(
                      Icons.fingerprint_rounded,
                      color: _navy,
                    ),
                    title: const Text('Require Face ID'),
                    subtitle: const Text('When reopening Studafy'),
                    value: biometricLock,
                    onChanged: (v) => setState(() => biometricLock = v),
                  ),
                  const Divider(),
                  _linkSetting(
                    Icons.devices_rounded,
                    'Signed-in devices',
                    '1 active',
                  ),
                  const Divider(),
                  _linkSetting(
                    Icons.download_rounded,
                    'Download my data',
                    'Request an archive',
                    onTap: () => _openInfo(
                      'Download my data',
                      'We will prepare a secure archive of your profile, classes, content, and activity. A download link will be sent to your verified email.',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            const _SettingsLabel('SUPPORT & LEGAL'),
            const SizedBox(height: 8),
            FeatureCard(
              child: Column(
                children: [
                  _linkSetting(
                    Icons.help_outline_rounded,
                    'Help centre',
                    'Guides and contact support',
                  ),
                  const Divider(),
                  _linkSetting(
                    Icons.policy_outlined,
                    'Policies',
                    'Privacy, terms & school data',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const PoliciesPage()),
                    ),
                  ),
                  const Divider(),
                  _linkSetting(
                    Icons.info_outline_rounded,
                    'About Studafy',
                    'Version 1.0.0',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            const _SettingsLabel('ACCOUNT'),
            const SizedBox(height: 8),
            FeatureCard(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.logout_rounded, color: _coral),
                title: const Text(
                  'Sign out',
                  style: TextStyle(color: _coral, fontWeight: FontWeight.w700),
                ),
                trailing: const Icon(
                  Icons.chevron_right_rounded,
                  color: _muted,
                ),
                onTap: () async {
                  await SessionService.signOut();
                  if (context.mounted) {
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      '/roles',
                      (_) => false,
                    );
                  }
                },
              ),
            ),
            const SizedBox(height: 14),
            Center(
              child: TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFA5A3B5),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DeleteAccountPage(email: '${p['email']}'),
                  ),
                ),
                child: const Text(
                  'Delete account',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                    decorationColor: Color(0xFFA5A3B5),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),
          ],
        );
      },
    ),
  );
  Widget _setting(String label, String key, Map<String, Object?> p) =>
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(label),
        value: p[key] == 1,
        onChanged: (v) async {
          await StudafyDatabase.instance.updateProfile({key: v ? 1 : 0});
          setState(() {});
        },
      );

  Widget _linkSetting(
    IconData icon,
    String label,
    String value, {
    VoidCallback? onTap,
  }) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon, color: _navy),
    title: Text(label),
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 165),
          child: Text(
            value,
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _muted, fontSize: 12),
          ),
        ),
        const SizedBox(width: 4),
        const Icon(Icons.chevron_right_rounded, color: _muted),
      ],
    ),
    onTap:
        onTap ??
        () => _openInfo(
          label,
          '$value\n\nThis information is managed by your school office.',
        ),
  );

  Future<void> _chooseLanguage() async {
    await showStudafyLanguagePicker(context);
    if (mounted) {
      setState(
        () => language =
            StudafyLocaleController.instance.locale.languageCode == 'ar'
            ? 'العربية'
            : 'English',
      );
    }
  }

  Future<void> _openInfo(String title, String body) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Done'),
        ),
      ],
    ),
  );
  Future<void> _edit(BuildContext context, Map<String, Object?> p) async {
    final name = TextEditingController(text: '${p['name']}'),
        email = TextEditingController(text: '${p['email']}');
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: email,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              await StudafyDatabase.instance.updateProfile({
                'name': name.text.trim(),
                'email': email.text.trim(),
              });
              if (context.mounted) Navigator.pop(context, true);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (saved == true) setState(() {});
  }
}

class _SettingsLabel extends StatelessWidget {
  const _SettingsLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      color: _muted,
      fontWeight: FontWeight.w700,
      letterSpacing: .5,
    ),
  );
}

class PoliciesPage extends StatelessWidget {
  const PoliciesPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _canvasColor,
    appBar: AppBar(
      backgroundColor: Colors.white,
      title: const Text('Policies'),
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'How Studafy handles your account and school data.',
          style: TextStyle(color: _muted),
        ),
        const SizedBox(height: 18),
        FeatureCard(
          child: Column(
            children: [
              _policy(
                context,
                Icons.privacy_tip_outlined,
                'Privacy Policy',
                'What we collect and how it is used',
              ),
              const Divider(),
              _policy(
                context,
                Icons.description_outlined,
                'Terms of Use',
                'Rules for using Studafy',
              ),
              const Divider(),
              _policy(
                context,
                Icons.school_outlined,
                'School data policy',
                'Ownership and retention of education records',
              ),
              const Divider(),
              _policy(
                context,
                Icons.cookie_outlined,
                'Cookie & analytics notice',
                'Diagnostics and product analytics',
              ),
              const Divider(),
              _policy(
                context,
                Icons.child_care_outlined,
                'Child safeguarding',
                'Safety and reporting commitments',
              ),
              const Divider(),
              _policy(
                context,
                Icons.update_rounded,
                'Policy updates',
                'Last updated 2 September 2026',
              ),
            ],
          ),
        ),
      ],
    ),
  );

  static Widget _policy(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
  ) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon, color: _navy),
    title: Text(title),
    subtitle: Text(subtitle),
    trailing: const Icon(Icons.chevron_right_rounded, color: _muted),
    onTap: () => Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _PolicyDetail(title: title)),
    ),
  );
}

class _PolicyDetail extends StatelessWidget {
  const _PolicyDetail({required this.title});
  final String title;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _canvasColor,
    appBar: AppBar(backgroundColor: Colors.white, title: Text(title)),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 24,
            color: _ink,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Effective 2 September 2026',
          style: TextStyle(color: _muted),
        ),
        const SizedBox(height: 24),
        const Text(
          'Your information',
          style: TextStyle(
            fontSize: 17,
            color: _ink,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Studafy processes profile, class, attendance, assessment, and communication data to provide and secure the school service. Your school controls official education records.',
        ),
        const SizedBox(height: 20),
        const Text(
          'Your choices',
          style: TextStyle(
            fontSize: 17,
            color: _ink,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'You can request a copy, correction, or deletion of eligible personal data. Some information may remain where the school has a legal, safeguarding, or academic-record obligation.',
        ),
        const SizedBox(height: 20),
        const Text(
          'Questions',
          style: TextStyle(
            fontSize: 17,
            color: _ink,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Contact your school office or privacy@studafy.app for help with a data request.',
        ),
      ],
    ),
  );
}

class DeleteAccountPage extends StatefulWidget {
  const DeleteAccountPage({super.key, required this.email});
  final String email;
  @override
  State<DeleteAccountPage> createState() => _DeleteAccountPageState();
}

class _DeleteAccountPageState extends State<DeleteAccountPage> {
  final confirmation = TextEditingController();
  String? reason;
  bool exported = false,
      transferred = false,
      understood = false,
      schoolRecords = false;
  bool get ready =>
      exported &&
      transferred &&
      understood &&
      schoolRecords &&
      reason != null &&
      confirmation.text.trim() == 'DELETE';

  @override
  void dispose() {
    confirmation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _canvasColor,
    appBar: AppBar(
      backgroundColor: Colors.white,
      title: const Text('Delete account'),
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF1F0),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFFECACA)),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.warning_amber_rounded, color: Color(0xFFB42318)),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'This affects more than your profile',
                      style: TextStyle(
                        color: Color(0xFF7A271A),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'Access to your profile, classes, messages, and personal files will end. Official school records may be retained by your school.',
                      style: TextStyle(color: Color(0xFF7A271A)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        const _SettingsLabel('BEFORE YOU CONTINUE'),
        const SizedBox(height: 8),
        FeatureCard(
          child: Column(
            children: [
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: exported,
                title: const Text('I saved what I need'),
                subtitle: const Text(
                  'Download a copy of personal data and files',
                ),
                onChanged: (v) => setState(() => exported = v ?? false),
              ),
              const Divider(),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: transferred,
                title: const Text('My school access is accounted for'),
                subtitle: const Text(
                  'Any classes, linked children, or learning access may need action from the school',
                ),
                onChanged: (v) => setState(() => transferred = v ?? false),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        const _SettingsLabel('TELL US WHY'),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: reason,
          decoration: const InputDecoration(labelText: 'Reason for leaving'),
          items: [
            'I no longer use Studafy',
            'I am changing schools',
            'Privacy concerns',
            'I have another account',
            'Prefer not to say',
          ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: (v) => setState(() => reason = v),
        ),
        const SizedBox(height: 22),
        const _SettingsLabel('ACKNOWLEDGEMENTS'),
        const SizedBox(height: 8),
        FeatureCard(
          child: Column(
            children: [
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: understood,
                title: const Text('I understand this cannot be undone'),
                subtitle: const Text('After the 14-day cancellation window'),
                onChanged: (v) => setState(() => understood = v ?? false),
              ),
              const Divider(),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: schoolRecords,
                title: const Text('I understand some records may remain'),
                subtitle: const Text(
                  'Attendance, grades, safeguarding, and audit records may be retained under school policy',
                ),
                onChanged: (v) => setState(() => schoolRecords = v ?? false),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Type DELETE to confirm deletion of ${widget.email}.',
          style: const TextStyle(color: _ink, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: confirmation,
          autocorrect: false,
          enableSuggestions: false,
          decoration: const InputDecoration(hintText: 'DELETE'),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 18),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFB42318),
          ),
          onPressed: ready ? _finalReview : null,
          child: const Text('Review deletion request'),
        ),
        const SizedBox(height: 10),
        const Text(
          'Nothing is deleted on this screen.',
          textAlign: TextAlign.center,
          style: TextStyle(color: _muted, fontSize: 12),
        ),
        const SizedBox(height: 28),
      ],
    ),
  );

  Future<void> _finalReview() async {
    final requested = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: const Icon(
          Icons.hourglass_bottom_rounded,
          color: Color(0xFFB42318),
          size: 34,
        ),
        title: const Text('Schedule account deletion?'),
        content: const Text(
          'Your account will be deactivated and queued for deletion after a 14-day recoverable grace period. Contact Studafy support during that period to cancel. Afterward, eligible personal data is removed; required school records may remain.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep my account'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB42318),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Schedule deletion'),
          ),
        ],
      ),
    );
    if (requested == true && mounted) {
      try {
        if (StudafyBackend.isRemote) {
          await SupabaseStudafyRepository().requestAccountDeletion(
            confirmation: 'DELETE',
          );
        } else {
          await StudafyDatabase.instance.requestAccountDeletion();
        }
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$error'.replaceFirst('Bad state: ', ''))),
          );
        }
        return;
      }
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          icon: const Icon(
            Icons.event_available_outlined,
            color: _navy,
            size: 36,
          ),
          title: const Text('Deletion request scheduled'),
          content: Text(
            '${widget.email} is now in a 14-day recoverable grace period. You can cancel through Studafy support before eligible personal data is removed.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
        ),
      );
    }
  }
}

class ConnectionsPage extends StatefulWidget {
  const ConnectionsPage({super.key});
  @override
  State<ConnectionsPage> createState() => _ConnectionsPageState();
}

class _ConnectionsPageState extends State<ConnectionsPage> {
  final id = TextEditingController();
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _canvasColor,
    appBar: AppBar(
      backgroundColor: Colors.white,
      title: const Text('Family connections'),
    ),
    body: FutureBuilder<List<Map<String, Object?>>>(
      future: StudafyDatabase.instance.connectionRequests(),
      builder: (context, snapshot) {
        final rows = snapshot.data ?? [];
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Connect to a child',
              style: TextStyle(
                color: _ink,
                fontSize: 21,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Enter the child’s unique Studafy ID. They must accept your request before access is granted.',
              style: TextStyle(color: _muted),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: id,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Child Studafy ID',
                hintText: 'STU-0001',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _send,
              child: const Text('Send connection request'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () async {
                final scanned = await scanStudentQr(context);
                if (scanned != null) setState(() => id.text = scanned);
              },
              icon: const Icon(Icons.qr_code_scanner_rounded),
              label: const Text('Scan student QR'),
            ),
            const SizedBox(height: 24),
            const Text(
              'Requests',
              style: TextStyle(
                color: _ink,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: FeatureCard(
                  child: Row(
                    children: [
                      const CircleAvatar(
                        backgroundColor: _navy,
                        child: Icon(Icons.person, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${row['student_name']}',
                              style: const TextStyle(
                                color: _ink,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              '${row['studafy_id']}',
                              style: const TextStyle(color: _muted),
                            ),
                          ],
                        ),
                      ),
                      StatusBadge('${row['status']}'),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );
  Future<void> _send() async {
    try {
      await StudafyDatabase.instance.requestConnection(
        'ST-2H9X-46B',
        id.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Connection request sent. Waiting for the child to accept.',
            ),
          ),
        );
        setState(() {});
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No account found with that Studafy ID.'),
          ),
        );
      }
    }
  }
}

class _ConversationPageState extends State<ConversationPage> {
  final message = TextEditingController();
  final scroll = ScrollController();
  final attachments = <_AttachmentDraft>[];
  Future<void> send() async {
    final body = message.text.trim();
    if (body.isEmpty && attachments.isEmpty) return;
    message.clear();
    final id = await StudafyDatabase.instance.sendMessage(
      widget.chat['id'] as int,
      body.isEmpty ? 'Shared attachments' : body,
    );
    await StudafyDatabase.instance.addAttachments(
      'message',
      id,
      attachments.map((item) => item.toMap()),
    );
    attachments.clear();
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scroll.hasClients) {
        scroll.animateTo(
          scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    message.dispose();
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _canvasColor,
    appBar: AppBar(
      backgroundColor: Colors.white,
      titleSpacing: 0,
      title: Row(
        children: [
          CircleAvatar(
            backgroundColor: Color(widget.chat['color'] as int),
            child: Text(
              '${widget.chat['initials']}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${widget.chat['contact_name']}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                '${widget.chat['context']}',
                style: const TextStyle(fontSize: 11, color: _muted),
              ),
            ],
          ),
        ],
      ),
    ),
    body: Column(
      children: [
        Expanded(
          child: FutureBuilder<List<Map<String, Object?>>>(
            future: StudafyDatabase.instance.messages(widget.chat['id'] as int),
            builder: (context, snapshot) => ListView(
              controller: scroll,
              padding: const EdgeInsets.all(18),
              children: [
                for (final row in snapshot.data ?? <Map<String, Object?>>[])
                  Align(
                    alignment: row['sent_by_me'] == 1
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 300),
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: row['sent_by_me'] == 1 ? _navy : Colors.white,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${row['body']}',
                            style: TextStyle(
                              color: row['sent_by_me'] == 1
                                  ? Colors.white
                                  : _ink,
                            ),
                          ),
                          if ((row['attachment_count'] as int? ?? 0) > 0) ...[
                            const SizedBox(height: 7),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.attach_file_rounded,
                                  size: 15,
                                  color: row['sent_by_me'] == 1
                                      ? Colors.white70
                                      : _violet,
                                ),
                                Text(
                                  '${row['attachment_count']} attachments',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: row['sent_by_me'] == 1
                                        ? Colors.white70
                                        : _violet,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
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
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (attachments.isNotEmpty)
                  SizedBox(
                    height: 40,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: attachments.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 6),
                      itemBuilder: (context, index) => InputChip(
                        label: Text(attachments[index].name),
                        onDeleted: () =>
                            setState(() => attachments.removeAt(index)),
                      ),
                    ),
                  ),
                Row(
                  children: [
                    IconButton(
                      onPressed: _showAttachmentPicker,
                      icon: const Icon(
                        Icons.add_circle_rounded,
                        color: _violet,
                      ),
                    ),
                    Expanded(
                      child: TextField(
                        controller: message,
                        textCapitalization: TextCapitalization.sentences,
                        onSubmitted: (_) => send(),
                        decoration: const InputDecoration(
                          hintText: 'Write a message…',
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 15,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: send,
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

  Future<void> _showAttachmentPicker() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Add to message',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 14),
              _AttachmentComposer(
                items: attachments,
                onChanged: () {
                  setSheet(() {});
                  setState(() {});
                },
              ),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
