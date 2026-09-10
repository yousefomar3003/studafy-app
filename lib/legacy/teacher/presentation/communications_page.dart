part of '../../../teacher_features.dart';

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
