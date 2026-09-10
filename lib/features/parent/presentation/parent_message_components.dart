part of '../../../parent_features.dart';

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
    await ParentRepositoryScope.read(context)
        .sendMessage(widget.chat['id'] as int, body);
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
            future: ParentRepositoryScope.read(context)
                .messages(widget.chat['id'] as int),
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
