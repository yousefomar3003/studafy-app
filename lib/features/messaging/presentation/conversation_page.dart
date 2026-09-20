import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/failures.dart';
import '../../../core/studafy_design.dart';
import '../domain/messaging.dart';
import 'blocked_people_page.dart';
import 'messaging_scope.dart';
import 'messaging_strings.dart';
import 'safety_sheets.dart';

/// One conversation. Report and block controls are always one tap away in
/// the app bar, and any message can be reported with a long press.
class ConversationPage extends StatefulWidget {
  const ConversationPage({
    super.key,
    required this.conversation,
    required this.myUserId,
  });

  final Conversation conversation;
  final String myUserId;

  @override
  State<ConversationPage> createState() => _ConversationPageState();
}

class _ConversationPageState extends State<ConversationPage> {
  final _composer = TextEditingController();
  final List<ChatMessage> _messages = [];
  String? _olderCursor;
  bool _loading = true;
  bool _loadingOlder = false;
  bool _sending = false;
  String? _loadError;
  String? _sendError;

  /// People in this school I have blocked, and people who blocked me.
  Set<String> _blockedByMe = const {};
  Set<String> _blockedMe = const {};

  /// Kept across retries of one draft, so a resend never duplicates it.
  String? _pendingClientId;

  Conversation get _conversation => widget.conversation;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _composer.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final interactor = MessagingScope.of(context);
    final page = await interactor.messages(_conversation.id);
    final blocks = await interactor.blocks(_conversation.schoolId);
    if (!mounted) return;
    setState(() {
      _loading = false;
      page.fold(
        onSuccess: (value) {
          _messages
            ..clear()
            ..addAll(value.items);
          _olderCursor = value.nextCursor;
          _loadError = null;
        },
        onFailure: (failure) =>
            _loadError = messagingFailureText(context, failure),
      );
      final list = blocks.fold(
        onSuccess: (value) => value,
        onFailure: (_) => const <BlockedPerson>[],
      );
      _blockedByMe = {
        for (final block in list)
          if (block.madeBy(widget.myUserId)) block.blockedId,
      };
      _blockedMe = {
        for (final block in list)
          if (!block.madeBy(widget.myUserId)) block.blockerId,
      };
    });
  }

  Future<void> _loadOlder() async {
    final cursor = _olderCursor;
    if (cursor == null || _loadingOlder) return;
    setState(() => _loadingOlder = true);
    final result = await MessagingScope.of(context)
        .messages(_conversation.id, cursor: cursor);
    if (!mounted) return;
    setState(() {
      _loadingOlder = false;
      result.fold(
        onSuccess: (page) {
          _messages.addAll(page.items);
          _olderCursor = page.nextCursor;
        },
        onFailure: (_) {},
      );
    });
  }

  Future<void> _send() async {
    final text = _composer.text;
    if (text.trim().isEmpty || _sending) return;
    final interactor = MessagingScope.of(context);
    final clientId = _pendingClientId ??= interactor.newClientMessageId();
    setState(() {
      _sending = true;
      _sendError = null;
    });
    final result = await interactor.send(
      _conversation.id,
      text,
      clientMessageId: clientId,
    );
    if (!mounted) return;
    setState(() {
      _sending = false;
      result.fold(
        onSuccess: (message) {
          _messages.insert(0, message);
          _composer.clear();
          _pendingClientId = null;
        },
        onFailure: (failure) => _sendError = failure.code == Failure.networkCode
            ? messagingText(context, 'sendFailed')
            : messagingFailureText(context, failure),
      );
    });
  }

  String _nameOf(String userId) {
    if (userId == widget.myUserId) return messagingText(context, 'you');
    return _conversation.participantName(userId) ??
        messagingText(context, 'unknownPerson');
  }

  Future<void> _reportConversation() async {
    final sent = await showReportSheet(
      context,
      schoolId: _conversation.schoolId,
      target: ReportTarget.conversation,
      conversationId: _conversation.id,
    );
    if (sent) _confirmReport();
  }

  Future<void> _reportPerson(ConversationParticipant person) async {
    final sent = await showReportSheet(
      context,
      schoolId: _conversation.schoolId,
      target: ReportTarget.user,
      conversationId: _conversation.id,
      subjectUserId: person.userId,
      subjectName: person.displayName,
    );
    if (sent) {
      _confirmReport();
      await _load();
    }
  }

  Future<void> _reportMessage(ChatMessage message) async {
    final sent = await showReportSheet(
      context,
      schoolId: _conversation.schoolId,
      target: ReportTarget.message,
      messageId: message.id,
      conversationId: _conversation.id,
      subjectUserId: message.senderId == widget.myUserId
          ? null
          : message.senderId,
      subjectName: message.senderId == widget.myUserId
          ? null
          : _nameOf(message.senderId),
    );
    if (sent) _confirmReport();
  }

  void _confirmReport() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(messagingText(context, 'report.sent'))),
    );
  }

  Future<void> _block(ConversationParticipant person) async {
    final blocked = await confirmBlock(
      context,
      schoolId: _conversation.schoolId,
      userId: person.userId,
      name: person.displayName,
    );
    if (blocked) await _load();
  }

  @override
  Widget build(BuildContext context) {
    String t(String key) => messagingText(context, key);
    final others = _conversation.others(widget.myUserId);
    final title =
        _conversation.subject ??
        others.map((person) => person.displayName).join(', ');
    final iBlocked = others.any((p) => _blockedByMe.contains(p.userId));
    final blockedHere =
        iBlocked || others.any((p) => _blockedMe.contains(p.userId));
    return Scaffold(
      backgroundColor: studafyCanvas,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(title, overflow: TextOverflow.ellipsis),
        actions: [
          PopupMenuButton<VoidCallback>(
            tooltip: t('report.title'),
            icon: const Icon(Icons.flag_outlined),
            onSelected: (action) => action(),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: _reportConversation,
                child: Text(t('menu.reportConversation')),
              ),
              for (final person in others) ...[
                PopupMenuItem(
                  value: () => _reportPerson(person),
                  child: Text(
                    messagingText(context, 'menu.reportPerson', {
                      'name': person.displayName,
                    }),
                  ),
                ),
                if (!_blockedByMe.contains(person.userId))
                  PopupMenuItem(
                    value: () => _block(person),
                    child: Text(
                      messagingText(context, 'menu.blockPerson', {
                        'name': person.displayName,
                      }),
                    ),
                  ),
              ],
              PopupMenuItem(
                value: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => BlockedPeoplePage(
                        schoolId: _conversation.schoolId,
                        myUserId: widget.myUserId,
                        knownPeople: {
                          for (final p in _conversation.participants)
                            p.userId: p.displayName,
                        },
                      ),
                    ),
                  );
                  if (mounted) await _load();
                },
                child: Text(t('menu.blocked')),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _body()),
          if (blockedHere)
            Container(
              width: double.infinity,
              color: const Color(0xFFFFFAED),
              padding: const EdgeInsets.all(12),
              // Never say who blocked whom when it was the other person.
              child: Text(t(iBlocked ? 'blocked.banner' : 'error.FORBIDDEN')),
            )
          else
            _composerBar(),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_loadError != null) {
      return StudafyStatusCard(
        icon: Icons.error_outline_rounded,
        title: messagingText(context, 'error.title'),
        message: _loadError!,
        actionLabel: messagingText(context, 'retry'),
        onAction: _load,
      );
    }
    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length + (_olderCursor == null ? 0 : 1),
      itemBuilder: (context, index) {
        if (index == _messages.length) {
          return Center(
            child: TextButton(
              onPressed: _loadingOlder ? null : _loadOlder,
              child: Text(messagingText(context, 'loadOlder')),
            ),
          );
        }
        final message = _messages[index];
        final mine = message.senderId == widget.myUserId;
        return Align(
          alignment: mine
              ? AlignmentDirectional.centerEnd
              : AlignmentDirectional.centerStart,
          child: GestureDetector(
            onLongPress: () => _reportMessage(message),
            child: Semantics(
              label: '${_nameOf(message.senderId)}: ${message.body}',
              hint: messagingText(context, 'message.report'),
              onLongPress: () => _reportMessage(message),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                constraints: const BoxConstraints(maxWidth: 320),
                decoration: BoxDecoration(
                  color: mine ? studafyNavy : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!mine)
                      Text(
                        _nameOf(message.senderId),
                        style: const TextStyle(
                          color: studafyMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    Text(
                      message.body,
                      style: TextStyle(color: mine ? Colors.white : studafyInk),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _composerBar() => SafeArea(
    top: false,
    child: Container(
      color: Colors.white,
      padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 8, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_sendError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                _sendError!,
                style: const TextStyle(color: Color(0xFFB3261E), fontSize: 12),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _composer,
                  minLines: 1,
                  maxLines: 4,
                  maxLength: 4000,
                  textInputAction: TextInputAction.newline,
                  decoration: InputDecoration(
                    hintText: messagingText(context, 'compose.hint'),
                    counterText: '',
                    border: const OutlineInputBorder(),
                  ),
                  // Editing the draft means it is a new message, not a retry.
                  onChanged: (_) => _pendingClientId = null,
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                tooltip: messagingText(context, 'send'),
                onPressed: _sending ? null : _send,
                icon: const Icon(Icons.send_rounded),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
