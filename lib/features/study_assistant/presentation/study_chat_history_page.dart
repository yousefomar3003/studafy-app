import 'package:flutter/material.dart';

import '../../../core/studafy_components.dart';
import '../../../core/studafy_design.dart';
import '../../../l10n/generated/app_l10n.dart';
import '../domain/study_assistant_repository.dart';
import 'study_assistant_page.dart';

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

  Future<void> _delete(StudyChat chat) async {
    try {
      await widget.store.delete(chat.id);
    } on Object {
      // On this device only; the reload below shows whatever is left.
    }
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final dates = MaterialLocalizations.of(context);
    return Scaffold(
      backgroundColor: studafyCanvas,
      appBar: AppBar(title: Text(l10n.studyAssistantHistory)),
      body: FutureBuilder<List<StudyChat>>(
        future: _chats,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final chats = snapshot.data ?? const <StudyChat>[];
          if (chats.isEmpty) {
            return Center(
              child: StudafyEmptyState(
                icon: Icons.forum_outlined,
                title: l10n.studyAssistantHistoryEmpty,
              ),
            );
          }
          return ListView(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 32),
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(4, 4, 4, 12),
                child: Row(
                  children: [
                    const Icon(
                      Icons.phone_iphone_rounded,
                      size: 16,
                      color: studafyMuted,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        l10n.studyAssistantOnDevice,
                        style: const TextStyle(
                          color: studafyMuted,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              FeatureCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (final (index, chat) in chats.indexed) ...[
                      if (index > 0)
                        const Divider(
                          height: 1,
                          indent: 64,
                          color: studafyHairline,
                        ),
                      Dismissible(
                        key: ValueKey(chat.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          color: studafyDanger,
                          alignment: AlignmentDirectional.centerEnd,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: const Icon(
                            Icons.delete_outline_rounded,
                            color: Colors.white,
                          ),
                        ),
                        onDismissed: (_) => _delete(chat),
                        child: ChatHistoryRow(
                          title: chat.title,
                          detail:
                              '${dates.formatMediumDate(chat.updatedAt)} · '
                              '${l10n.studyAssistantMessageCount(chat.turns.length)}',
                          onTap: () => Navigator.pop(context, chat),
                          trailing: IconButton(
                            tooltip: l10n.studyAssistantDeleteChat,
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              color: studafyMuted,
                            ),
                            onPressed: () => _delete(chat),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: _deleteAll,
                style: OutlinedButton.styleFrom(
                  foregroundColor: studafyDanger,
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: studafyHairline),
                  minimumSize: const Size.fromHeight(50),
                ),
                icon: const Icon(Icons.delete_sweep_outlined),
                label: Text(l10n.studyAssistantDeleteAll),
              ),
            ],
          );
        },
      ),
    );
  }
}
