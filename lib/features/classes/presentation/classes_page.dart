import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/result.dart';
import '../../../core/studafy_design.dart';
import '../application/class_list_interactor.dart';
import '../domain/classroom.dart';

/// Typed teacher class list (ARC-011 classes slice).
///
/// Reads through [ClassListInteractor] only — no SQL, no provider client, no
/// dynamic maps. The header and the legacy workspace navigation are injected
/// by the app shell so this feature never imports other features.
class ClassesPage extends StatefulWidget {
  const ClassesPage({
    super.key,
    required this.classes,
    required this.onOpenClassroom,
    this.header,
  });

  final ClassListInteractor classes;

  /// Opens the (still legacy) class workspace; the shell builds the bridge.
  /// Completing it means the workspace closed, so the list can refresh.
  final Future<void> Function(ClassroomSummary classroom) onOpenClassroom;

  /// Optional app-supplied header; defaults to a minimal title header.
  final Widget? header;

  @override
  State<ClassesPage> createState() => _ClassesPageState();
}

class _ClassesPageState extends State<ClassesPage> {
  Future<Result<List<ClassroomSummary>>>? _future;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _future = widget.classes.loadClasses();
    });
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      widget.header ?? const _ClassesTitleHeader(),
      Expanded(
        child: FutureBuilder<Result<List<ClassroomSummary>>>(
          future: _future,
          builder: (context, snapshot) {
            final result = snapshot.data;
            final classrooms = result?.fold(
              onSuccess: (value) => value,
              onFailure: (_) => const <ClassroomSummary>[],
            );
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Flexible(
                      child: Text(
                        'My classes',
                        style: TextStyle(
                          color: studafyInk,
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
                if (result != null && result.isFailure)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      result.fold(
                        onSuccess: (_) => '',
                        onFailure: (failure) => failure.message,
                      ),
                      style: const TextStyle(color: Color(0xFFB42318)),
                    ),
                  ),
                for (final classroom
                    in classrooms ?? const <ClassroomSummary>[])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _ClassCard(
                      classroom: classroom,
                      onTap: () async {
                        await widget.onOpenClassroom(classroom);
                        _refresh();
                      },
                      onInvite: () => _invite(context, classroom),
                    ),
                  ),
              ],
            );
          },
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
    String? createFailure;
    final sessions = <ClassSessionDraft>[
      ClassSessionDraft(weekday: 1, startTime: '08:00', endTime: '08:50'),
    ];
    const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialog) => AlertDialog(
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
                      sessions.add(
                        ClassSessionDraft(
                          weekday: sessions.last.weekday,
                          startTime: sessions.last.startTime,
                          endTime: sessions.last.endTime,
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
                        studafyCyan,
                        const Color(0xFF7737EE),
                        const Color(0xFFFF6B6B),
                        const Color(0xFF20B981),
                        const Color(0xFFFFB84D),
                      ][i % 5].withValues(alpha: .08),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Class ${i + 1}',
                          style: const TextStyle(
                            color: studafyInk,
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
                          onChanged: (value) => setDialog(
                            () => sessions[i] = ClassSessionDraft(
                              weekday: value ?? 1,
                              startTime: sessions[i].startTime,
                              endTime: sessions[i].endTime,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () async {
                                  final t = await showTimePicker(
                                    context: dialogContext,
                                    initialTime: _parseTimeOfday(
                                      sessions[i].startTime,
                                    ),
                                  );
                                  if (t != null) {
                                    setDialog(
                                      () => sessions[i] = ClassSessionDraft(
                                        weekday: sessions[i].weekday,
                                        startTime: _formatTimeOfDay(t),
                                        endTime: sessions[i].endTime,
                                      ),
                                    );
                                  }
                                },
                                child: Text(sessions[i].startTime),
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
                                    context: dialogContext,
                                    initialTime: _parseTimeOfday(
                                      sessions[i].endTime,
                                    ),
                                  );
                                  if (t != null) {
                                    setDialog(
                                      () => sessions[i] = ClassSessionDraft(
                                        weekday: sessions[i].weekday,
                                        startTime: sessions[i].startTime,
                                        endTime: _formatTimeOfDay(t),
                                      ),
                                    );
                                  }
                                },
                                child: Text(sessions[i].endTime),
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
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (name.text.trim().isEmpty || sessions.isEmpty) return;
                final draft = NewClassDraft(
                  name: name.text.trim(),
                  grade: grade,
                  section: section,
                  room: room.text.trim().isEmpty ? 'TBD' : room.text.trim(),
                  firstSessionStart: sessions.first.startTime,
                  firstSessionEnd: sessions.first.endTime,
                  weeklySessions: weeklySessions,
                  sessions: List.unmodifiable(sessions),
                );
                final result = await widget.classes.createClass(draft);
                if (!dialogContext.mounted) return;
                switch (result) {
                  case Success():
                    if (dialogContext.mounted) {
                      Navigator.pop(dialogContext, true);
                    }
                  case FailureResult(:final failure):
                    createFailure = failure.message;
                    if (dialogContext.mounted) {
                      Navigator.pop(dialogContext, false);
                    }
                }
              },
              child: const Text('Create classroom'),
            ),
          ],
        ),
      ),
    );
    if (saved == true) {
      _refresh();
    } else if (createFailure != null && context.mounted) {
      _showFailure(context, createFailure!);
    }
  }

  Future<void> _invite(BuildContext context, ClassroomSummary classroom) async {
    final result = await widget.classes.inviteLinkFor(classroom.id);
    if (!context.mounted) return;
    result.fold(
      onSuccess: (link) => _showInviteDialog(context, link),
      onFailure: (failure) => _showFailure(context, failure.message),
    );
  }

  void _showFailure(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showInviteDialog(BuildContext context, String link) async {
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
                color: studafyNavy.withValues(alpha: .06),
                borderRadius: BorderRadius.circular(14),
              ),
              child: SelectableText(
                link,
                style: const TextStyle(
                  color: studafyNavy,
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
}

class _ClassCard extends StatelessWidget {
  const _ClassCard({
    required this.classroom,
    required this.onTap,
    required this.onInvite,
  });

  final ClassroomSummary classroom;
  final VoidCallback onTap;
  final VoidCallback onInvite;

  @override
  Widget build(BuildContext context) {
    final tint = Color(classroom.colorValue ?? 0xFF241D73);
    final detail = [
      '${classroom.studentCount} students',
      if (classroom.weeklySessions != null)
        '${classroom.weeklySessions} classes/week',
      classroom.room ?? 'TBD',
    ].join(' · ');
    return FeatureCard(
      tint: tint,
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 4,
            height: 64,
            decoration: BoxDecoration(
              color: tint,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  classroom.name,
                  style: const TextStyle(
                    color: studafyInk,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'Grade ${classroom.grade} · Section ${classroom.section}',
                  style: const TextStyle(color: studafyMuted),
                ),
                Text(
                  detail,
                  style: const TextStyle(color: studafyMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onInvite,
            icon: const Icon(Icons.person_add_alt_1_outlined),
          ),
          const Icon(Icons.chevron_right, color: studafyMuted),
        ],
      ),
    );
  }
}

class _ClassesTitleHeader extends StatelessWidget {
  const _ClassesTitleHeader();

  @override
  Widget build(BuildContext context) => Container(
    color: Colors.white,
    padding: const EdgeInsets.fromLTRB(20, 12, 16, 14),
    child: SafeArea(
      bottom: false,
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Classes',
              style: const TextStyle(
                color: studafyInk,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

TimeOfDay _parseTimeOfday(String value) {
  final parts = value.split(':');
  return TimeOfDay(
    hour: int.tryParse(parts.isNotEmpty ? parts[0] : '8') ?? 8,
    minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
  );
}

String _formatTimeOfDay(TimeOfDay t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
