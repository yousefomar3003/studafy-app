part of '../../../teacher_features.dart';

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
