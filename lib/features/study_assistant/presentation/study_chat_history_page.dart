import 'package:flutter/material.dart';

import '../../../core/user_content_text.dart';
import '../../../l10n/generated/app_l10n.dart';
import '../domain/study_assistant_repository.dart';

/// Earlier chats with the helper, newest first. Tap one to carry on with it,
/// swipe it away to delete it. Everything here is on this device only.
class StudyChatHistoryPage extends StatefulWidget {
  const StudyChatHistoryPage({super.key, required this.store});

  final StudyChatStore store;

  @override
  State<StudyChatHistoryPage> createState() => _StudyChatHistoryPageState();
}

class _StudyChatHistoryPageState extends State<StudyChatHistoryPage> {
  late Future<List<StudyChat>> _chats = widget.store.chats();

  void _reload() => setState(() => _chats = widget.store.chats());

  Future<void> _deleteAll() async {
    final l10n = AppL10n.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        content: Text(l10n.studyAssistantDeleteAllConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.studyAssistantCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.studyAssistantDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.store.deleteAll();
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final dates = MaterialLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.studyAssistantHistory),
        actions: [
          IconButton(
            tooltip: l10n.studyAssistantDeleteAll,
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: _deleteAll,
          ),
        ],
      ),
      body: FutureBuilder<List<StudyChat>>(
        future: _chats,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final chats = snapshot.data ?? const <StudyChat>[];
          if (chats.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  l10n.studyAssistantHistoryEmpty,
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    const Icon(Icons.phone_iphone_rounded, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      l10n.studyAssistantOnDevice,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              for (final chat in chats)
                Dismissible(
                  key: ValueKey(chat.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Theme.of(context).colorScheme.error,
                    alignment: AlignmentDirectional.centerEnd,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: const Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.white,
                    ),
                  ),
                  onDismissed: (_) => widget.store.delete(chat.id),
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.chat_bubble_outline_rounded),
                    ),
                    title: UserContentText(chat.title, maxLines: 1),
                    subtitle: Text(
                      '${dates.formatMediumDate(chat.updatedAt)} · '
                      '${l10n.studyAssistantMessageCount(chat.turns.length)}',
                    ),
                    trailing: IconButton(
                      tooltip: l10n.studyAssistantDeleteChat,
                      icon: const Icon(Icons.delete_outline_rounded),
                      onPressed: () async {
                        await widget.store.delete(chat.id);
                        if (mounted) _reload();
                      },
                    ),
                    onTap: () => Navigator.pop(context, chat),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
