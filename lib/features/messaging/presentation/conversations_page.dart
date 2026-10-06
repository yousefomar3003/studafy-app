import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/attachment_opener.dart';
import '../../../core/failures.dart';
import '../../../core/feedback.dart';
import '../../../core/navigation.dart';
import '../../../core/studafy_components.dart';
import '../../../core/studafy_design.dart';
import '../../../core/studafy_domain.dart';
import '../../../core/user_content_text.dart';
import '../../../l10n/generated/app_l10n.dart';
import '../domain/messaging.dart';
import 'blocked_people_page.dart';
import 'conversation_page.dart';
import 'messaging_scope.dart';
import 'messaging_strings.dart';

/// Conversation list for every role, backed by authoritative `/v1`
/// messaging (MOB-070, SAFE-043). Replaces the legacy SQLite chat screens.
class ConversationsPage extends StatefulWidget {
  const ConversationsPage({
    super.key,
    this.visible = true,
    this.acknowledgeEvery = const Duration(minutes: 2),
    this.asRole,
    this.onNewAnnouncement,
    this.showAnnouncements = true,
  });

  /// False where announcements have a page of their own (the parent's
  /// app), so this one is about conversations only.
  final bool showAnnouncements;

  /// Opens the announcement composer. Null for people who cannot post one;
  /// announcements are still listed for them to read.
  final VoidCallback? onNewAnnouncement;

  /// The role this inbox belongs to. One account can be a teacher at one
  /// school and a parent at another; each interface then lists only the
  /// conversations it takes part in that way, so the parent's inbox does not
  /// fill with the same person's teaching conversations. Null lists all.
  final MessagingRole? asRole;

  /// How often, while the app is in the foreground, this device tells the
  /// server it has received its conversations - the second grey tick. It is
  /// also said at once on opening the app, on returning to it, and whenever
  /// the inbox loads, so the interval only covers a quiet open app. Every
  /// open app sends it, so it is kept long: at 30 seconds, tens of thousands
  /// of users were a thousand writes a second for nothing.
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

  /// Once a list has been shown, a reload keeps it on screen and swaps in
  /// the new one when it arrives, instead of blanking to a spinner.
  bool _loaded = false;
  bool _enabled = true;
  Failure? _failure;

  /// Every shell keeps this page alive in its IndexedStack, so it is where
  /// the app says "delivered" for the whole signed-in session - the way a
  /// phone that is on receives messages whichever screen is open.
  Timer? _acknowledger;
  bool _foreground = true;

  /// Who the list was loaded for, so a different person - or someone
  /// arriving after the page was built - is loaded afresh.
  String? _loadedFor;

  void _contextChanged() {
    if (!mounted) return;
    final userId = messagingIdentity()?.userId;
    if (userId == _loadedFor) return;
    if (widget.visible && userId != null) {
      unawaited(_load());
    } else {
      setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();
    ActiveContextController.instance.addListener(_contextChanged);
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
    ActiveContextController.instance.removeListener(_contextChanged);
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
    if (identity.userId != _loadedFor) {
      // Someone else's list must not stay up while theirs loads.
      _loaded = false;
      _loadedFor = identity.userId;
    }
    if (!_loaded) setState(() => _loading = true);
    final interactor = MessagingScope.of(context);
    final schoolId = identity.schoolId;
    // Whether a school has messaging switched on is a question about that
    // school. Someone acting in none - a guardian before their first link is
    // verified - has no school to ask about, and is not blocked by one
    // either: their conversation list spans every school they are a
    // participant in.
    // Both at once: neither waits on the other.
    final enabledRead = schoolId == null
        ? null
        : interactor.messagingEnabled(schoolId);
    final list = await interactor.conversations();
    final enabled = await enabledRead;
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
          _loaded = true;
          _acknowledge();
        },
        onFailure: (failure) => _failure = failure,
      );
    });
  }

  Future<void> _open(Conversation conversation, String myUserId) async {
    await Navigator.of(context).pushOnce(
      MaterialPageRoute<void>(
        builder: (_) =>
            ConversationPage(conversation: conversation, myUserId: myUserId),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _startNew(String schoolId, String myUserId) async {
    final created = await Navigator.of(context).pushOnce<Conversation>(
      MaterialPageRoute(
        builder: (_) => NewConversationPage(schoolId: schoolId),
      ),
    );
    if (created != null && mounted) await _open(created, myUserId);
  }

  _InboxPart _part = _InboxPart.messages;
  Future<List<Announcement>>? _announcements;

  Future<List<Announcement>> _loadAnnouncements() async {
    final schoolId = messagingIdentity()?.schoolId;
    // Announcements belong to a school. Someone acting in none - a guardian
    // before a link is verified - has none to read yet.
    if (schoolId == null) return const [];
    final result = await MessagingScope.of(context)
        .announcements(schoolId: schoolId);
    return result.fold(
      onSuccess: (items) =>
          [...items]..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
      onFailure: (failure) => throw failure,
    );
  }

  void _openBlocked(String schoolId, String myUserId) =>
      Navigator.of(context).pushOnce(
        MaterialPageRoute<void>(
          builder: (_) =>
              BlockedPeoplePage(schoolId: schoolId, myUserId: myUserId),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final identity = messagingIdentity();
    final schoolId = identity?.schoolId;
    final canStart =
        identity != null && schoolId != null && _enabled && !_loading;
    return Scaffold(
      appBar: AppBar(
        // The page is named as its tab is: Messages for a student, the
        // Inbox for staff, whose tab also holds announcements they post.
        title: Text(
          widget.asRole == MessagingRole.student
              ? l10n.navMessages
              : l10n.navInbox,
        ),
        actions: [
          // Labelled, and only here: announcements have their own control
          // inside their own tab, so the two never sit together.
          if (canStart)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 4),
              child: StudafyPillButton(
                icon: Icons.edit_square,
                label: l10n.msgNew,
                prominent: true,
                onPressed: () => _startNew(schoolId, identity.userId),
              ),
            ),
          if (identity != null && schoolId != null)
            PopupMenuButton<VoidCallback>(
              tooltip: l10n.msgOptions,
              icon: const Icon(Icons.more_horiz_rounded),
              onSelected: (action) => action(),
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: () => _openBlocked(schoolId, identity.userId),
                  child: Row(
                    children: [
                      const Icon(Icons.person_off_outlined, size: 20),
                      const SizedBox(width: 12),
                      Text(l10n.msgMenuBlocked),
                    ],
                  ),
                ),
              ],
            ),
          const SizedBox(width: 4),
        ],
      ),
      // No one signed in yet - the account is still being loaded or
      // switched. The page loads as soon as they are; see _contextChanged.
      body: identity == null
          ? const Center(child: CircularProgressIndicator())
          : !widget.showAnnouncements
          ? _messages(identity.userId, schoolId)
          : Column(
              children: [
                PillTabs<_InboxPart>(
                  values: _InboxPart.values,
                  selected: _part,
                  label: (part) => switch (part) {
                    _InboxPart.messages => l10n.msgTitle,
                    _InboxPart.announcements => l10n.msgAnnouncements,
                  },
                  icon: (part) => switch (part) {
                    _InboxPart.messages => Icons.forum_rounded,
                    _InboxPart.announcements => Icons.campaign_rounded,
                  },
                  onSelected: (part) => setState(() {
                    _part = part;
                    if (part == _InboxPart.announcements) {
                      _announcements = _loadAnnouncements();
                    }
                  }),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: _part == _InboxPart.messages
                      ? _messages(identity.userId, schoolId)
                      : _announcementList(),
                ),
              ],
            ),
    );
  }

  Widget _messages(String myUserId, String? schoolId) {
    final l10n = AppL10n.of(context);
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_failure != null) {
      return Center(
        child: StudafyEmptyState(
          icon: Icons.wifi_off_rounded,
          title: l10n.msgErrorTitle,
          message: messagingFailureText(context, _failure!),
          actionLabel: l10n.msgRetry,
          onAction: _load,
        ),
      );
    }
    return StudafyRefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 24),
        children: [
          if (!_enabled)
            StudafyEmptyState(
              icon: Icons.chat_bubble_outline_rounded,
              title: l10n.msgTitle,
              message: l10n.msgErrorMessagingDisabled,
            )
          else if (_conversations.isEmpty)
            // The labelled New message button in the header is the way to
            // start one, so it is not repeated here.
            StudafyEmptyState(
              icon: Icons.send_rounded,
              title: l10n.msgEmptyTitle,
              message: schoolId == null
                  ? l10n.msgEmptyAwaitingLink
                  : l10n.msgEmptyMessage,
            )
          else
            FeatureCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final (index, conversation)
                      in _conversations.indexed) ...[
                    if (index > 0)
                      const Divider(
                        height: 1,
                        indent: 76,
                        color: studafyHairline,
                      ),
                    _ConversationTile(
                      conversation: conversation,
                      myUserId: myUserId,
                      onTap: () => _open(conversation, myUserId),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _announcementList() {
    final l10n = AppL10n.of(context);
    final action = widget.onNewAnnouncement;
    return FutureBuilder<List<Announcement>>(
      future: _announcements ??= _loadAnnouncements(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: StudafyEmptyState(
              icon: Icons.wifi_off_rounded,
              title: l10n.msgAnnouncementsFailed,
              actionLabel: l10n.msgRetry,
              onAction: () => setState(() {
                _announcements = _loadAnnouncements();
              }),
            ),
          );
        }
        final items = snapshot.data ?? const <Announcement>[];
        return StudafyRefreshIndicator(
          onRefresh: () async {
            final next = _loadAnnouncements();
            setState(() => _announcements = next);
            await next.catchError((Object _) => const <Announcement>[]);
          },
          child: ListView(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 24),
            children: [
              if (action != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonalIcon(
                      onPressed: action,
                      icon: const Icon(Icons.campaign_rounded),
                      label: Text(l10n.msgNewAnnouncement),
                    ),
                  ),
                ),
              if (items.isEmpty)
                StudafyEmptyState(
                  icon: Icons.campaign_outlined,
                  title: l10n.msgAnnouncementsEmpty,
                ),
              for (final item in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: AnnouncementCard(announcement: item),
                ),
            ],
          ),
        );
      },
    );
  }
}

enum _InboxPart { messages, announcements }

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.conversation,
    required this.myUserId,
    required this.onTap,
  });

  final Conversation conversation;
  final String myUserId;
  final VoidCallback onTap;

  String _when(BuildContext context) {
    final at = conversation.updatedAt.toLocal();
    final now = DateTime.now();
    final localizations = MaterialLocalizations.of(context);
    if (at.year == now.year && at.month == now.month && at.day == now.day) {
      return localizations.formatTimeOfDay(TimeOfDay.fromDateTime(at));
    }
    return localizations.formatShortMonthDay(at);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final others = conversation.others(myUserId);
    final names = others.map((p) => p.displayName).join(', ');
    final unread = conversation.hasUnread;
    final title = conversation.subject ?? names;
    return Semantics(
      button: true,
      label: unread ? '$title. ${l10n.msgUnread}' : title,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 14, 12),
          child: Row(
            children: [
              InitialsAvatar(name: names, radius: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: studafyInk,
                        fontSize: 15.5,
                        fontWeight: unread ? FontWeight.w800 : FontWeight.w600,
                      ),
                    ),
                    if (conversation.subject != null)
                      Text(
                        names,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: studafyMuted,
                          fontSize: 13,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _when(context),
                    style: TextStyle(
                      color: unread ? studafyNavy : studafyMuted,
                      fontSize: 12,
                      fontWeight: unread ? FontWeight.w800 : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Unread is a dot and bold text, not a colour alone.
                  if (unread)
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: studafyNavy,
                        shape: BoxShape.circle,
                      ),
                    )
                  else
                    const SizedBox(height: 10),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One announcement: what it is, when, where from, and what came with it.
class AnnouncementCard extends StatelessWidget {
  const AnnouncementCard({super.key, required this.announcement, this.from});

  final Announcement announcement;

  /// Who it reached the reader through - a school and the reader's children
  /// there - shown under the date when the list spans several.
  final String? from;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return FeatureCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconBadge(
                icon: announcement.important
                    ? Icons.priority_high_rounded
                    : Icons.campaign_rounded,
                color: announcement.important ? studafyDanger : studafyNavy,
                size: 40,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    UserContentText(
                      announcement.title,
                      style: const TextStyle(
                        color: studafyInk,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      MaterialLocalizations.of(context)
                          .formatMediumDate(announcement.createdAt.toLocal()),
                      style: const TextStyle(color: studafyMuted, fontSize: 12),
                    ),
                    if (from case final source?)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.apartment_rounded,
                              size: 13,
                              color: studafyMuted,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: UserContentText(
                                source,
                                style: const TextStyle(
                                  color: studafyMuted,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              if (announcement.important)
                StatusPill(
                  label: l10n.msgImportant,
                  icon: Icons.priority_high_rounded,
                  color: studafyDanger,
                ),
            ],
          ),
          if (announcement.body.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            UserContentText(
              announcement.body,
              style: const TextStyle(color: studafyInk, height: 1.45),
            ),
          ],
          if (announcement.attachments.isNotEmpty)
            StoredAttachmentList(
              attachments: announcement.attachments,
              dense: true,
            ),
        ],
      ),
    );
  }
}

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
        ScaffoldMessenger.of(context)
            .showMessage(messagingFailureText(context, failure));
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
      appBar: AppBar(title: Text(AppL10n.of(context).msgNewTitle)),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: _selected.isEmpty || _starting ? null : _start,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            icon: _starting
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.send_rounded),
            label: Text(AppL10n.of(context).msgStart),
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
                    prefixIcon: const Icon(Icons.short_text_rounded),
                  ),
                ),
                TextField(
                  onChanged: (value) => setState(() => _query = value),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search_rounded),
                    hintText: AppL10n.of(context).msgNewSearch,
                  ),
                ),
                const SizedBox(height: 12),
                if (visible.isEmpty)
                  StudafyStatusCard(
                    icon: Icons.people_outline_rounded,
                    title: AppL10n.of(context).msgNewTitle,
                    message: AppL10n.of(context).msgNewEmpty,
                  ),
                if (visible.isNotEmpty)
                  FeatureCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        for (final (index, contact) in visible.indexed) ...[
                          if (index > 0)
                            const Divider(
                              height: 1,
                              indent: 72,
                              color: studafyHairline,
                            ),
                          _ContactRow(
                            name: contact.displayName,
                            detail: _detail(contact),
                            selected: _selected.contains(contact.userId),
                            onChanged: (checked) => setState(() {
                              if (checked) {
                                _selected.add(contact.userId);
                              } else {
                                _selected.remove(contact.userId);
                              }
                            }),
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

/// Someone to message: who they are, and whether they are chosen.
class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.name,
    required this.detail,
    required this.selected,
    required this.onChanged,
  });

  final String name;
  final String detail;
  final bool selected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Semantics(
    checked: selected,
    child: InkWell(
      onTap: () => onChanged(!selected),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 8, 10),
        child: Row(
          children: [
            InitialsAvatar(name: name, radius: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: studafyInk,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    detail,
                    style: const TextStyle(color: studafyMuted, fontSize: 13),
                  ),
                ],
              ),
            ),
            Checkbox(
              value: selected,
              shape: const CircleBorder(),
              onChanged: (value) => onChanged(value ?? false),
            ),
          ],
        ),
      ),
    ),
  );
}
