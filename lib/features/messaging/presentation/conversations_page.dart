import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/failures.dart';
import '../../../core/studafy_design.dart';
import '../domain/messaging.dart';
import 'blocked_people_page.dart';
import 'conversation_page.dart';
import 'messaging_scope.dart';
import 'messaging_strings.dart';

/// Conversation list for every role, backed by authoritative `/v1`
/// messaging (MOB-070, SAFE-043). Replaces the legacy SQLite chat screens.
class ConversationsPage extends StatefulWidget {
  const ConversationsPage({super.key});

  @override
  State<ConversationsPage> createState() => _ConversationsPageState();
}

class _ConversationsPageState extends State<ConversationsPage> {
  List<Conversation> _conversations = const [];
  bool _loading = true;
  bool _enabled = true;
  Failure? _failure;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final identity = messagingIdentity();
    if (identity == null) {
      setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);
    final interactor = MessagingScope.of(context);
    final enabled = await interactor.messagingEnabled(identity.schoolId);
    final list = await interactor.conversations();
    if (!mounted) return;
    setState(() {
      _loading = false;
      // A school that has not switched messaging on still shows existing
      // conversations read-only, but offers no way to start a new one.
      _enabled = enabled.fold(onSuccess: (v) => v, onFailure: (_) => true);
      list.fold(
        onSuccess: (items) {
          _conversations = items;
          _failure = null;
        },
        onFailure: (failure) => _failure = failure,
      );
    });
  }

  Future<void> _open(Conversation conversation, String myUserId) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) =>
            ConversationPage(conversation: conversation, myUserId: myUserId),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _startNew(String schoolId, String myUserId) async {
    final created = await Navigator.push<Conversation>(
      context,
      MaterialPageRoute(
        builder: (_) => NewConversationPage(schoolId: schoolId),
      ),
    );
    if (created != null && mounted) await _open(created, myUserId);
  }

  @override
  Widget build(BuildContext context) {
    String t(String key) => messagingText(context, key);
    final identity = messagingIdentity();
    return Scaffold(
      backgroundColor: studafyCanvas,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(t('title')),
        actions: [
          if (identity != null)
            IconButton(
              tooltip: t('menu.blocked'),
              icon: const Icon(Icons.block_rounded),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => BlockedPeoplePage(
                    schoolId: identity.schoolId,
                    myUserId: identity.userId,
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: identity != null && _enabled && !_loading
          ? FloatingActionButton.extended(
              onPressed: () => _startNew(identity.schoolId, identity.userId),
              icon: const Icon(Icons.edit_rounded),
              label: Text(t('new')),
            )
          : null,
      body: identity == null
          ? StudafyStatusCard(
              icon: Icons.school_outlined,
              title: t('title'),
              message: t('noSchool'),
            )
          : _loading
          ? const Center(child: CircularProgressIndicator())
          : _failure != null
          ? StudafyStatusCard(
              icon: Icons.error_outline_rounded,
              title: t('error.title'),
              message: messagingFailureText(context, _failure!),
              actionLabel: t('retry'),
              onAction: _load,
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 96),
                children: [
                  if (!_enabled)
                    StudafyStatusCard(
                      icon: Icons.chat_bubble_outline_rounded,
                      title: t('title'),
                      message: t('error.MESSAGING_DISABLED'),
                    ),
                  if (_conversations.isEmpty && _enabled)
                    StudafyStatusCard(
                      icon: Icons.forum_outlined,
                      title: t('empty.title'),
                      message: t('empty.message'),
                    ),
                  for (final conversation in _conversations)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _ConversationTile(
                        conversation: conversation,
                        myUserId: identity.userId,
                        onTap: () => _open(conversation, identity.userId),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.conversation,
    required this.myUserId,
    required this.onTap,
  });

  final Conversation conversation;
  final String myUserId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final others = conversation.others(myUserId);
    final names = others.map((p) => p.displayName).join(', ');
    final unread = conversation.hasUnread;
    return FeatureCard(
      tint: unread ? studafyCyan : null,
      onTap: onTap,
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: studafyNavy.withValues(alpha: .1),
            child: Text(
              names.isEmpty ? '?' : names.characters.first.toUpperCase(),
              style: const TextStyle(color: studafyNavy),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  conversation.subject ?? names,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: studafyInk,
                    fontWeight: unread ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
                if (conversation.subject != null)
                  Text(
                    names,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: studafyMuted, fontSize: 12),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Pick people the server says this user may contact, then start talking.
class NewConversationPage extends StatefulWidget {
  const NewConversationPage({super.key, required this.schoolId});

  final String schoolId;

  @override
  State<NewConversationPage> createState() => _NewConversationPageState();
}

class _NewConversationPageState extends State<NewConversationPage> {
  List<MessagingContact> _contacts = const [];
  final Set<String> _selected = {};
  final _subject = TextEditingController();
  String _query = '';
  bool _loading = true;
  bool _starting = false;
  Failure? _failure;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _subject.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final result = await MessagingScope.of(context).contacts(widget.schoolId);
    if (!mounted) return;
    setState(() {
      _loading = false;
      result.fold(
        onSuccess: (list) {
          _contacts = list;
          _failure = null;
        },
        onFailure: (failure) => _failure = failure,
      );
    });
  }

  Future<void> _start() async {
    if (_selected.isEmpty || _starting) return;
    setState(() => _starting = true);
    final result = await MessagingScope.of(context).startConversation(
      schoolId: widget.schoolId,
      participantIds: _selected.toList(),
      subject: _subject.text,
    );
    if (!mounted) return;
    result.fold(
      onSuccess: (conversation) => Navigator.pop(context, conversation),
      onFailure: (failure) {
        setState(() => _starting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(messagingFailureText(context, failure))),
        );
      },
    );
  }

  String _detail(MessagingContact contact) {
    if (contact.role == MessagingRole.guardian &&
        contact.relatedStudentNames.isNotEmpty) {
      return messagingText(context, 'guardianOf', {
        'names': contact.relatedStudentNames.join(', '),
      });
    }
    return messagingText(context, 'role.${contact.role.name}');
  }

  @override
  Widget build(BuildContext context) {
    String t(String key) => messagingText(context, key);
    final visible = [
      for (final contact in _contacts)
        if (_query.isEmpty ||
            contact.displayName.toLowerCase().contains(_query.toLowerCase()))
          contact,
    ];
    return Scaffold(
      backgroundColor: studafyCanvas,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(t('new.title')),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: _selected.isEmpty || _starting ? null : _start,
            child: Text(t('start')),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _failure != null
          ? StudafyStatusCard(
              icon: Icons.error_outline_rounded,
              title: t('error.title'),
              message: messagingFailureText(context, _failure!),
              actionLabel: t('retry'),
              onAction: _load,
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextField(
                  controller: _subject,
                  maxLength: 160,
                  decoration: InputDecoration(
                    labelText: t('subject.hint'),
                    border: const OutlineInputBorder(),
                  ),
                ),
                TextField(
                  onChanged: (value) => setState(() => _query = value),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search_rounded),
                    hintText: t('new.search'),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                if (visible.isEmpty)
                  StudafyStatusCard(
                    icon: Icons.people_outline_rounded,
                    title: t('new.title'),
                    message: t('new.empty'),
                  ),
                for (final contact in visible)
                  CheckboxListTile(
                    value: _selected.contains(contact.userId),
                    onChanged: (checked) => setState(() {
                      if (checked ?? false) {
                        _selected.add(contact.userId);
                      } else {
                        _selected.remove(contact.userId);
                      }
                    }),
                    title: Text(contact.displayName),
                    subtitle: Text(_detail(contact)),
                  ),
              ],
            ),
    );
  }
}
