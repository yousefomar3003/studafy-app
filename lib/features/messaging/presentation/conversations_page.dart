import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/failures.dart';
import '../../../core/studafy_design.dart';
import '../domain/messaging.dart';
import 'blocked_people_page.dart';
import 'conversation_page.dart';
import 'messaging_scope.dart';
import 'messaging_strings.dart';
import '../../../l10n/generated/app_l10n.dart';

/// Conversation list for every role, backed by authoritative `/v1`
/// messaging (MOB-070, SAFE-043). Replaces the legacy SQLite chat screens.
class ConversationsPage extends StatefulWidget {
  const ConversationsPage({
    super.key,
    this.visible = true,
    this.acknowledgeEvery = const Duration(seconds: 30),
    this.asRole,
  });

  /// The role this inbox belongs to. One account can be a teacher at one
  /// school and a parent at another; each interface then lists only the
  /// conversations it takes part in that way, so the parent's inbox does not
  /// fill with the same person's teaching conversations. Null lists all.
  final MessagingRole? asRole;

  /// How often, while the app is in the foreground, this device tells the
  /// server it has received its conversations - the second grey tick.
  final Duration acknowledgeEvery;

  /// Whether this tab is the one on screen.
  ///
  /// The shells keep every tab alive in an IndexedStack, so without this the
  /// page loads once at startup and never again: a conversation started on
  /// another device, or a school switching messaging on, stayed invisible
  /// until the app was killed and relaunched. The Notebook tab carries the
  /// same flag for the same reason.
  final bool visible;

  @override
  State<ConversationsPage> createState() => _ConversationsPageState();
}

class _ConversationsPageState extends State<ConversationsPage>
    with WidgetsBindingObserver {
  List<Conversation> _conversations = const [];

  /// False while this tab is off screen: nothing is loading, so a spinner
  /// would be a lie and would never stop.
  late bool _loading = widget.visible;
  bool _enabled = true;
  Failure? _failure;

  /// Every shell keeps this page alive in its IndexedStack, so it is where
  /// the app says "delivered" for the whole signed-in session - the way a
  /// phone that is on receives messages whichever screen is open.
  Timer? _acknowledger;
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.visible) unawaited(_load());
    // After the first frame: the scope is an inherited widget.
    WidgetsBinding.instance.addPostFrameCallback((_) => _acknowledge());
    _acknowledger = Timer.periodic(
      widget.acknowledgeEvery,
      (_) => _acknowledge(),
    );
  }

  @override
  void dispose() {
    _acknowledger?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) _acknowledge();
  }

  bool _acknowledging = false;

  Future<void> _acknowledge() async {
    // One at a time: the timer, a resume and a finished load can all ask at
    // once, and overlapping requests only race each other.
    if (_acknowledging || !mounted || !_foreground) return;
    if (messagingIdentity() == null) return;
    _acknowledging = true;
    try {
      // Silent either way: a failure only means the sender's second tick
      // arrives on the next try.
      await MessagingScope.of(context).acknowledgeDelivery();
    } finally {
      _acknowledging = false;
    }
  }

  @override
  void didUpdateWidget(ConversationsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-read on the transition into view, not on every rebuild while
    // visible, which would reload on each keystroke elsewhere in the shell.
    if (widget.visible && !oldWidget.visible) unawaited(_load());
  }

  Future<void> _load() async {
    final identity = messagingIdentity();
    if (identity == null) {
      setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);
    final interactor = MessagingScope.of(context);
    final schoolId = identity.schoolId;
    // Whether a school has messaging switched on is a question about that
    // school. Someone acting in none - a guardian before their first link is
    // verified - has no school to ask about, and is not blocked by one
    // either: their conversation list spans every school they are a
    // participant in.
    final enabled = schoolId == null
        ? null
        : await interactor.messagingEnabled(schoolId);
    final list = await interactor.conversations();
    if (!mounted) return;
    setState(() {
      _loading = false;
      // A school that has not switched messaging on still shows existing
      // conversations read-only, but offers no way to start a new one.
      _enabled =
          enabled?.fold(onSuccess: (v) => v, onFailure: (_) => true) ?? true;
      list.fold(
        onSuccess: (items) {
          final role = widget.asRole;
          final me = identity.userId;
          _conversations = role == null
              ? items
              : [
                  for (final item in items)
                    if (item.participants.any(
                      (p) => p.userId == me && p.role == role,
                    ))
                      item,
                ];
          _failure = null;
          _acknowledge();
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
    final identity = messagingIdentity();
    // Picking recipients and blocking are both per school, because the
    // contact policy is. Starting a conversation therefore waits on a
    // school; reading the ones already going does not.
    final schoolId = identity?.schoolId;
    return Scaffold(
      backgroundColor: studafyCanvas,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(AppL10n.of(context).msgTitle),
        actions: [
          if (identity != null && schoolId != null)
            IconButton(
              tooltip: AppL10n.of(context).msgMenuBlocked,
              icon: const Icon(Icons.block_rounded),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => BlockedPeoplePage(
                    schoolId: schoolId,
                    myUserId: identity.userId,
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton:
          identity != null && schoolId != null && _enabled && !_loading
          ? FloatingActionButton.extended(
              // Every tab stays alive in the shell's IndexedStack, so two
              // buttons with the default hero tag coexist and break the
              // transition of every screen pushed from any tab.
              heroTag: null,
              onPressed: () => _startNew(schoolId, identity.userId),
              icon: const Icon(Icons.edit_rounded),
              label: Text(AppL10n.of(context).msgNew),
            )
          : null,
      body: identity == null
          ? StudafyStatusCard(
              icon: Icons.school_outlined,
              title: AppL10n.of(context).msgTitle,
              message: AppL10n.of(context).msgNoSchool,
            )
          : _loading
          ? const Center(child: CircularProgressIndicator())
          : _failure != null
          ? StudafyStatusCard(
              icon: Icons.error_outline_rounded,
              title: AppL10n.of(context).msgErrorTitle,
              message: messagingFailureText(context, _failure!),
              actionLabel: AppL10n.of(context).msgRetry,
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
                      title: AppL10n.of(context).msgTitle,
                      message: AppL10n.of(context).msgErrorMessagingDisabled,
                    ),
                  if (_conversations.isEmpty && _enabled)
                    StudafyStatusCard(
                      icon: Icons.forum_outlined,
                      title: AppL10n.of(context).msgEmptyTitle,
                      message: schoolId == null
                          ? AppL10n.of(context).msgEmptyAwaitingLink
                          : AppL10n.of(context).msgEmptyMessage,
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
      return AppL10n.of(context)
          .msgGuardianOf(contact.relatedStudentNames.join(', '));
    }
    return messagingText(context, 'role.${contact.role.name}');
  }

  @override
  Widget build(BuildContext context) {
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
        title: Text(AppL10n.of(context).msgNewTitle),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: _selected.isEmpty || _starting ? null : _start,
            child: Text(AppL10n.of(context).msgStart),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _failure != null
          ? StudafyStatusCard(
              icon: Icons.error_outline_rounded,
              title: AppL10n.of(context).msgErrorTitle,
              message: messagingFailureText(context, _failure!),
              actionLabel: AppL10n.of(context).msgRetry,
              onAction: _load,
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextField(
                  controller: _subject,
                  maxLength: 160,
                  decoration: InputDecoration(
                    labelText: AppL10n.of(context).msgSubjectHint,
                    border: const OutlineInputBorder(),
                  ),
                ),
                TextField(
                  onChanged: (value) => setState(() => _query = value),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search_rounded),
                    hintText: AppL10n.of(context).msgNewSearch,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                if (visible.isEmpty)
                  StudafyStatusCard(
                    icon: Icons.people_outline_rounded,
                    title: AppL10n.of(context).msgNewTitle,
                    message: AppL10n.of(context).msgNewEmpty,
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
