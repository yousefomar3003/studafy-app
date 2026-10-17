import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

import '../../../core/attachment_field.dart';
import '../../../core/attachment_opener.dart';
import '../../../core/content_links.dart';
import '../../../core/coursework_attachments.dart';
import '../../../core/failures.dart';
import '../../../core/feedback.dart';
import '../../../core/file_upload_repository.dart';
import '../../../core/idempotency.dart';
import '../../../core/navigation.dart';
import '../../../core/platform_attachment_source.dart';
import '../../../core/platform_voice_notes.dart';
import '../../../core/studafy_design.dart';
import '../../../core/studafy_formatting.dart';
import '../../../core/unsaved_changes.dart';
import '../../../core/uploads_scope.dart';
import '../../../core/voice_note.dart';
import '../../../l10n/generated/app_l10n.dart';
import '../domain/messaging.dart';
import 'blocked_people_page.dart';
import 'messaging_scope.dart';
import 'messaging_strings.dart';
import 'safety_sheets.dart';
import 'voice_note_widgets.dart';

/// One conversation. Report and block controls are always one tap away in
/// the app bar, and any message can be reported with a long press.
class ConversationPage extends StatefulWidget {
  const ConversationPage({
    super.key,
    required this.conversation,
    required this.myUserId,
    this.uploads,
    this.attachmentSource,
    this.voiceRecorder,
    this.voicePlayer,
    this.refreshEvery = const Duration(seconds: 4),
  });

  final Conversation conversation;
  final String myUserId;

  /// Lets people attach documents and photos. Null in builds with no upload
  /// pipeline, and the control is then absent rather than present and failing.
  final FileUploadRepository? uploads;

  /// Overrides the platform picker. Tests supply their own.
  final AttachmentSource? attachmentSource;

  /// Override the microphone and the speaker. Tests supply their own; the
  /// platform ones are only made when first used.
  final VoiceRecorder Function()? voiceRecorder;
  final VoicePlayer Function()? voicePlayer;

  /// How often an open chat re-reads its newest messages.
  final Duration refreshEvery;

  @override
  State<ConversationPage> createState() => _ConversationPageState();
}

class _ConversationPageState extends State<ConversationPage> {
  final _composer = TextEditingController();
  final List<ChatMessage> _messages = [];
  String? _olderCursor;

  /// A full load is under way; the poll waits for it.
  bool _loading = true;

  /// Once the chat has been shown, a reload (after a report or a block)
  /// keeps it on screen rather than blanking to a spinner.
  bool _loaded = false;
  bool _loadingOlder = false;
  bool _sending = false;
  String? _loadError;
  String? _sendError;
  List<Attachment> _attachments = const [];

  /// Replaced after a send so the field rebuilds empty: it owns its own list
  /// of staged files, and those have just been handed to a message.
  /// Replaced after each send so the field starts empty, and used by the
  /// composer's one attach button to open the picker.
  GlobalKey<AttachmentFieldState> _attachmentsKey = GlobalKey();

  bool get _uploading =>
      _attachments.any((a) => a.stage == AttachmentStage.uploading);

  /// A message typed or a file added and not sent, or a voice note kept to
  /// try again: leaving the chat asks first.
  bool get _unsaved =>
      !_sending &&
      (_composer.text.trim().isNotEmpty ||
          _attachments.isNotEmpty ||
          _unsentVoice != null);

  /// People in this school I have blocked, and people who blocked me.
  Set<String> _blockedByMe = const {};
  Set<String> _blockedMe = const {};

  /// Kept across retries of one draft, so a resend never duplicates it.
  String? _pendingClientId;

  /// Voice notes: one recording at a time, one note playing at a time.
  VoiceRecorder? _recorder;
  VoicePlayer? _player;
  bool _recording = false;
  bool _sendingVoice = false;

  /// A voice note that could not be sent, kept so it can be tried again
  /// rather than recorded again.
  RecordedVoiceNote? _unsentVoice;

  /// Notes sent from this screen, by file: the sender plays their own
  /// recording at once instead of waiting for the server's check.
  final Map<String, Uint8List> _myRecordings = {};

  VoicePlayer _voicePlayer() =>
      _player ??= (widget.voicePlayer ?? PlatformVoicePlayer.new)();

  Conversation get _conversation => widget.conversation;

  /// Re-reads the newest messages while the chat is open, so replies appear
  /// and my ticks move from one to two to blue without leaving the screen.
  Timer? _refresher;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    _refresher = Timer.periodic(widget.refreshEvery, (_) => _refreshLatest());
  }

  /// While a file in the chat is still being checked, the chat looks again
  /// every second instead of every few, so a voice note can be played the
  /// moment it is cleared. A stuck check stops this after a minute; the
  /// normal refresh carries on.
  Timer? _soon;
  int _quickLooks = 0;

  static const _stillChecking = {'quarantined', 'scanning'};

  bool get _awaitingCheck => _messages
      .take(20)
      .any(
        (m) => m.attachments.any((a) => _stillChecking.contains(a.scanState)),
      );

  void _lookAgainSoon() {
    if (!mounted || _soon != null) return;
    if (!_awaitingCheck) {
      _quickLooks = 0;
      return;
    }
    if (_quickLooks >= 60) return;
    _quickLooks++;
    _soon = Timer(const Duration(seconds: 1), () {
      _soon = null;
      unawaited(_refreshLatest());
    });
  }

  @override
  void dispose() {
    _refresher?.cancel();
    _soon?.cancel();
    _composer.dispose();
    unawaited(_recorder?.dispose());
    unawaited(_player?.dispose());
    super.dispose();
  }

  /// Opening the chat is reading it. Failure is silent: the only effect is
  /// that the sender's ticks stay grey a little longer.
  void _markRead() =>
      unawaited(MessagingScope.of(context).markRead(_conversation.id));

  bool _refreshing = false;

  /// Whether anyone can see this chat: not with the app in the background,
  /// nor with another screen (the people list, a report) on top of it.
  bool get _inView {
    // Null before the platform has reported any state: assume in view.
    final state = WidgetsBinding.instance.lifecycleState;
    return (state == null || state == AppLifecycleState.resumed) &&
        (ModalRoute.of(context)?.isCurrent ?? true);
  }

  /// Puts the newest [page] in place. The page replaces its own stretch of
  /// time - carrying the latest ticks, and dropping anything removed from
  /// it. Anything newer stays above it: a message I sent while the page was
  /// on its way is not in it, and must not vanish until the next read. With
  /// [keepOlder], older messages already loaded stay below it.
  List<ChatMessage> _withNewest(
    List<ChatMessage> page, {
    required bool keepOlder,
  }) {
    if (page.isEmpty) return keepOlder ? [..._messages] : const [];
    final fresh = {for (final m in page) m.id};
    final newest = page.first.createdAt;
    final oldest = page.last.createdAt;
    return [
      for (final m in _messages)
        if (!fresh.contains(m.id) && m.createdAt.isAfter(newest)) m,
      ...page,
      if (keepOlder)
        for (final m in _messages)
          if (!fresh.contains(m.id) && m.createdAt.isBefore(oldest)) m,
    ];
  }

  /// What the screen shows of [messages]: a poll that brings nothing new
  /// changes nothing, so it rebuilds nothing.
  static List<Object?> _shown(List<ChatMessage> messages) => [
    for (final m in messages) ...[
      m.id,
      m.status,
      m.body,
      for (final a in m.attachments) ...[a.id, a.scanState],
    ],
  ];

  Future<void> _refreshLatest() async {
    if (_refreshing || _loading || _sending || !mounted || !_inView) return;
    _refreshing = true;
    try {
      final page = await MessagingScope.of(context).messages(_conversation.id);
      if (!mounted) return;
      page.fold(
        onSuccess: (value) {
          final known = {for (final m in _messages) m.id};
          final arrived = value.items.any(
            (m) => !known.contains(m.id) && m.senderId != widget.myUserId,
          );
          final merged = _withNewest(value.items, keepOlder: true);
          if (!listEquals(_shown(merged), _shown(_messages))) {
            setState(() {
              _messages
                ..clear()
                ..addAll(merged);
            });
          }
          if (arrived) _markRead();
        },
        onFailure: (_) {},
      );
    } finally {
      _refreshing = false;
      _lookAgainSoon();
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final interactor = MessagingScope.of(context);
    // Both at once: neither waits on the other.
    final blocksRead = interactor.blocks(_conversation.schoolId);
    final page = await interactor.messages(_conversation.id);
    final blocks = await blocksRead;
    if (!mounted) return;
    setState(() {
      _loading = false;
      page.fold(
        onSuccess: (value) {
          final merged = _withNewest(value.items, keepOlder: false);
          _messages
            ..clear()
            ..addAll(merged);
          _olderCursor = value.nextCursor;
          _loadError = null;
          _loaded = true;
          _markRead();
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
    _lookAgainSoon();
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
    // An attachment still uploading would be dropped from the message, so the
    // send waits for it rather than sending half of what was meant.
    // A photo or file needs no text of its own, as a voice note does not.
    if ((text.trim().isEmpty && _attachments.isEmpty) ||
        _sending ||
        _uploading) {
      return;
    }
    final interactor = MessagingScope.of(context);
    final clientId = _pendingClientId ??= interactor.newClientMessageId();
    // In the order sent: a refusal names a file by its place in this list.
    final sent = sendableFileIds(_attachments);
    setState(() {
      _sending = true;
      _sendError = null;
    });
    final result = await interactor.send(
      _conversation.id,
      text,
      clientMessageId: clientId,
      attachmentFileIds: sent,
    );
    if (!mounted) return;
    AttachmentRefusedFailure? refusal;
    setState(() {
      _sending = false;
      result.fold(
        onSuccess: (message) {
          _messages.insert(0, message);
          _composer.clear();
          _pendingClientId = null;
          // The files now belong to the sent message; keeping them staged
          // would attach them again on the next send, which the server
          // refuses anyway.
          _attachments = const [];
          _attachmentsKey = GlobalKey();
        },
        onFailure: (failure) {
          if (failure is AttachmentRefusedFailure) {
            refusal = failure;
            // Nothing was sent, and the next send is a different message.
            _pendingClientId = null;
          }
          _sendError = failure.code == Failure.networkCode
              ? AppL10n.of(context).msgSendFailed
              : messagingFailureText(context, failure);
        },
      );
    });
    // A refused file is marked where it was attached, and is left out of
    // the next send.
    if (refusal case final refused?) {
      markRefusedFiles(
        AppL10n.of(context),
        _attachmentsKey.currentState,
        sent,
        refused.rows,
      );
    }
  }

  /// Whether the composer last showed the microphone (an empty draft)
  /// rather than send.
  bool _draftShownEmpty = true;

  /// Editing the draft means it is a new message, not a retry. The button
  /// beside it follows - send for text, a microphone for an empty draft - so
  /// the screen is rebuilt only when that flips, not on every keystroke.
  void _draftChanged(String text) {
    _pendingClientId = null;
    final empty = text.trim().isEmpty && _attachments.isEmpty;
    if (empty != _draftShownEmpty) setState(() {});
  }

  FileUploadRepository? get _uploads =>
      widget.uploads ?? UploadsScope.maybeOf(context);

  Future<void> _startRecording() async {
    if (_recording || _sendingVoice || _sending) return;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppL10n.of(context);
    final recorder = _recorder ??=
        (widget.voiceRecorder ?? PlatformVoiceRecorder.new)();
    try {
      if (!await recorder.requestPermission()) {
        messenger.showMessage(l10n.msgVoiceNoPermission);
        return;
      }
      await recorder.start();
    } on Object {
      messenger.showMessage(l10n.msgVoiceFailed);
      return;
    }
    if (mounted) {
      setState(() {
        _recording = true;
        _sendError = null;
      });
    }
  }

  Future<void> _discardRecording() async {
    setState(() => _recording = false);
    await _recorder?.cancel();
  }

  /// Stops the recording and sends it as a message of its own, with no
  /// text - the way WhatsApp does.
  Future<void> _sendRecording({required bool reachedLimit}) async {
    final recorder = _recorder;
    if (recorder == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppL10n.of(context);
    setState(() => _recording = false);
    RecordedVoiceNote? note;
    try {
      note = await recorder.stop();
    } on Object {
      note = null;
    }
    if (!mounted) return;
    if (note == null || note.duration < voiceNoteMinimum) {
      messenger.showMessage(l10n.msgVoiceTooShort);
      return;
    }
    if (reachedLimit) messenger.showMessage(l10n.msgVoiceLimit);
    await _sendVoice(note);
  }

  /// Uploads [note] as a message attachment and sends it. On failure the
  /// note is kept, with a way to try again or to throw it away.
  Future<void> _sendVoice(RecordedVoiceNote recorded) async {
    RecordedVoiceNote? note = recorded;
    final uploads = _uploads;
    if (uploads == null || _sendingVoice) return;
    final l10n = AppL10n.of(context);
    final interactor = MessagingScope.of(context);
    setState(() {
      _sendingVoice = true;
      _unsentVoice = null;
      _sendError = null;
    });
    String? error;
    try {
      final file = await uploads.upload(
        FileUploadCommand(
          attemptId: newIdempotencyKey('voice-note'),
          schoolId: _conversation.schoolId,
          purpose: FilePurpose.messageAttachment,
          displayName: l10n.msgVoiceMessage,
          mediaType: voiceNoteMediaType,
          bytes: recorded.bytes,
        ),
      );
      final result = await interactor.send(
        _conversation.id,
        '',
        clientMessageId: interactor.newClientMessageId(),
        attachmentFileIds: [file.id],
      );
      result.fold(
        onSuccess: (message) {
          if (!mounted) return;
          setState(() {
            _myRecordings[file.id] = recorded.bytes;
            _messages.insert(0, message);
          });
          _quickLooks = 0;
          _lookAgainSoon();
        },
        onFailure: (_) => error = l10n.msgVoiceFailed,
      );
    } on FileServiceUnavailable {
      // Trying again will not help until the school's server has uploads
      // switched on, so the note is not offered for another try.
      error = l10n.filesSwitchedOff;
      note = null;
    } on Object {
      error = l10n.msgVoiceFailed;
    } finally {
      if (mounted) {
        setState(() {
          _sendingVoice = false;
          _sendError = error;
          _unsentVoice = error == null ? null : note;
        });
      }
    }
  }

  String _nameOf(String userId) {
    if (userId == widget.myUserId) return AppL10n.of(context).msgYou;
    return _conversation.participantName(userId) ??
        AppL10n.of(context).msgUnknownPerson;
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
    ScaffoldMessenger.of(context)
        .showMessage(AppL10n.of(context).msgReportSent);
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
  Widget build(BuildContext context) => ListenableBuilder(
    // Follows typing without rebuilding the page.
    listenable: _composer,
    builder: (_, page) => UnsavedChangesScope(unsaved: _unsaved, child: page!),
    child: _page(context),
  );

  Widget _page(BuildContext context) {
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
        title: Text(title, overflow: TextOverflow.ellipsis),
        actions: [
          // Report and block live behind one clearly labelled menu, each
          // with its own icon, rather than a lone flag.
          PopupMenuButton<VoidCallback>(
            tooltip: AppL10n.of(context).msgOptions,
            icon: const Icon(Icons.more_horiz_rounded),
            onSelected: (action) => action(),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: _reportConversation,
                child: _MenuLine(
                  icon: Icons.report_outlined,
                  text: AppL10n.of(context).msgMenuReportConversation,
                ),
              ),
              for (final person in others) ...[
                PopupMenuItem(
                  value: () => _reportPerson(person),
                  child: _MenuLine(
                    icon: Icons.person_search_outlined,
                    text: AppL10n.of(context)
                        .msgMenuReportPerson(person.displayName),
                  ),
                ),
                if (!_blockedByMe.contains(person.userId))
                  PopupMenuItem(
                    value: () => _block(person),
                    child: _MenuLine(
                      icon: Icons.block_rounded,
                      text: AppL10n.of(context)
                          .msgMenuBlockPerson(person.displayName),
                      destructive: true,
                    ),
                  ),
              ],
              PopupMenuItem(
                value: () async {
                  await Navigator.of(context).pushOnce(
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
                child: _MenuLine(
                  icon: Icons.person_off_outlined,
                  text: AppL10n.of(context).msgMenuBlocked,
                ),
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
    if (_loading && !_loaded) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null) {
      return StudafyStatusCard(
        icon: Icons.error_outline_rounded,
        title: AppL10n.of(context).msgErrorTitle,
        message: _loadError!,
        actionLabel: AppL10n.of(context).msgRetry,
        onAction: _load,
      );
    }
    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length + (_olderCursor == null ? 0 : 1),
      // Rows follow their message when one arrives above them, so a voice
      // note that is playing keeps its place and its progress.
      findChildIndexCallback: (key) {
        if (key is! ValueKey<String>) return null;
        final index = _messages.indexWhere((m) => m.id == key.value);
        return index < 0 ? null : index;
      },
      itemBuilder: (context, index) {
        if (index == _messages.length) {
          return Center(
            child: TextButton(
              onPressed: _loadingOlder ? null : _loadOlder,
              child: Text(AppL10n.of(context).msgLoadOlder),
            ),
          );
        }
        final message = _messages[index];
        final mine = message.senderId == widget.myUserId;
        // Only photos: shown as themselves, with no bubble around them.
        final photoOnly =
            message.body.isEmpty &&
            message.attachments.isNotEmpty &&
            message.attachments.every(
              (note) => (note.mediaType ?? '').startsWith('image/'),
            );
        final onBubble = mine && !photoOnly;
        return Align(
          key: ValueKey(message.id),
          alignment: mine
              ? AlignmentDirectional.centerEnd
              : AlignmentDirectional.centerStart,
          child: GestureDetector(
            onLongPress: () => _reportMessage(message),
            child: Semantics(
              label:
                  '${_nameOf(message.senderId)}: '
                  '${message.body.isEmpty ? AppL10n.of(context).msgVoiceMessage : message.body}',
              hint: AppL10n.of(context).msgMessageReport,
              onLongPress: () => _reportMessage(message),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: photoOnly
                    ? EdgeInsets.zero
                    : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                constraints: const BoxConstraints(maxWidth: 320),
                decoration: photoOnly
                    ? null
                    : BoxDecoration(
                        gradient: mine ? studafyActionGradient : null,
                        color: mine ? null : Colors.white,
                        border: mine
                            ? null
                            : Border.all(color: studafyHairline),
                        borderRadius: BorderRadiusDirectional.only(
                          topStart: const Radius.circular(18),
                          topEnd: const Radius.circular(18),
                          bottomStart: Radius.circular(mine ? 18 : 6),
                          bottomEnd: Radius.circular(mine ? 6 : 18),
                        ),
                      ),
                child: Column(
                  crossAxisAlignment: photoOnly && mine
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
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
                    // Links in a message are links, and say where they go
                    // before they open.
                    if (message.body.isNotEmpty)
                      LinkedText(
                        message.body,
                        chat: true,
                        linkColor: mine ? Colors.white : null,
                        style: TextStyle(
                          color: mine ? Colors.white : studafyInk,
                        ),
                      ),
                    // A photo is shown as itself; tapped, it opens full size.
                    for (final note in message.attachments)
                      if ((note.mediaType ?? '').startsWith('image/'))
                        Padding(
                          padding: EdgeInsets.only(top: photoOnly ? 2 : 6),
                          child: AttachmentImage(
                            key: ValueKey('image-${note.id}'),
                            attachment: note,
                            uploads: _uploads,
                          ),
                        ),
                    for (final note in message.attachments)
                      if (isVoiceNote(note.mediaType))
                        VoiceNoteBubble(
                          key: ValueKey('voice-${note.id}'),
                          attachment: note,
                          uploads: _uploads,
                          player: _voicePlayer,
                          mine: mine,
                          localBytes: mine ? _myRecordings[note.id] : null,
                        ),
                    if (message.attachments.any(
                      (note) =>
                          !isVoiceNote(note.mediaType) &&
                          !(note.mediaType ?? '').startsWith('image/'),
                    ))
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: StoredAttachmentList(
                          attachments: [
                            for (final note in message.attachments)
                              if (!isVoiceNote(note.mediaType) &&
                                  !(note.mediaType ?? '').startsWith('image/'))
                                note,
                          ],
                          dense: true,
                          color: mine ? Colors.white70 : studafyMuted,
                        ),
                      ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          studafyTimeOfDay(
                            context,
                            TimeOfDay.fromDateTime(message.createdAt.toLocal()),
                          ),
                          style: TextStyle(
                            fontSize: 10,
                            color: onBubble ? Colors.white70 : studafyMuted,
                          ),
                        ),
                        if (mine && message.status != null) ...[
                          const SizedBox(width: 4),
                          MessageTicks(
                            status: message.status!,
                            onBubble: onBubble,
                          ),
                        ],
                      ],
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

  Widget _composerBar() {
    final l10n = AppL10n.of(context);
    final empty = _composer.text.trim().isEmpty && _attachments.isEmpty;
    _draftShownEmpty = empty;
    final unsent = _unsentVoice;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(10, 6, 10, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_sendError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _ComposerNotice(
                  text: _sendError!,
                  // A voice note that failed can be sent again as it is.
                  actionLabel: unsent == null ? null : l10n.msgRetry,
                  onAction: unsent == null ? null : () => _sendVoice(unsent),
                  onDismiss: unsent == null
                      ? null
                      : () => setState(() {
                          _unsentVoice = null;
                          _sendError = null;
                        }),
                ),
              ),
            if (_sendingVoice)
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(8, 0, 8, 8),
                child: Row(
                  children: [
                    const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      l10n.msgVoiceSending,
                      style: const TextStyle(color: studafyMuted, fontSize: 13),
                    ),
                  ],
                ),
              ),
            if (_recording)
              _ComposerShell(
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(4, 2, 4, 2),
                  child: VoiceNoteRecorderBar(
                    onDiscard: _discardRecording,
                    onSend: _sendRecording,
                  ),
                ),
              )
            else ...[
              // What has been attached, each with a way to take it back out
              // (or to try it again), shown just above the message it goes
              // with. The constructor argument wins so a test can inject a
              // fake; the scope is how the real app supplies it.
              if (_uploads case final uploads?)
                AttachmentField(
                  key: _attachmentsKey,
                  purpose: FilePurpose.messageAttachment,
                  schoolId: _conversation.schoolId,
                  uploads: uploads,
                  enabled: !_sending,
                  maximumCount: 3,
                  showAddButtons: false,
                  source: widget.attachmentSource ?? pickPlatformAttachment,
                  onChanged: (items) => setState(() => _attachments = items),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: _ComposerShell(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // One attach button, inside the field: it asks
                          // photo, camera or document.
                          if (_uploads != null)
                            IconButton(
                              tooltip: l10n.attachmentAdd,
                              onPressed: _sending
                                  ? null
                                  : () => _attachmentsKey.currentState
                                        ?.chooseAndAdd(),
                              icon: const Icon(
                                Icons.attach_file_rounded,
                                color: studafyNavy,
                              ),
                            )
                          else
                            const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _composer,
                              minLines: 1,
                              maxLines: 6,
                              maxLength: 4000,
                              textInputAction: TextInputAction.newline,
                              textCapitalization: TextCapitalization.sentences,
                              decoration: InputDecoration(
                                hintText: l10n.msgComposeHint,
                                counterText: '',
                                isDense: true,
                                filled: false,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 12,
                                ),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                              ),
                              onChanged: _draftChanged,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_sendingVoice)
                    const SizedBox(
                      width: 48,
                      height: 48,
                      child: Padding(
                        padding: EdgeInsets.all(13),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  else if (empty && _uploads != null)
                    IconButton.filled(
                      tooltip: l10n.msgVoiceRecord,
                      onPressed: _sending ? null : _startRecording,
                      style: IconButton.styleFrom(
                        backgroundColor: studafyNavy,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: studafyHairline,
                        disabledForegroundColor: studafyMuted,
                        fixedSize: const Size(48, 48),
                      ),
                      icon: const Icon(Icons.mic_rounded),
                    )
                  else
                    IconButton.filled(
                      tooltip: l10n.msgSend,
                      onPressed: _sending || _uploading ? null : _send,
                      style: IconButton.styleFrom(
                        backgroundColor: studafyNavy,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: studafyHairline,
                        disabledForegroundColor: studafyMuted,
                        fixedSize: const Size(48, 48),
                      ),
                      icon: _sending
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send_rounded),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The rounded white field the composer's controls sit in.
class _ComposerShell extends StatelessWidget {
  const _ComposerShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(26),
      border: Border.all(color: studafyHairline),
      boxShadow: [
        BoxShadow(
          color: studafyAbyss.withValues(alpha: .06),
          blurRadius: 14,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Padding(padding: const EdgeInsets.all(2), child: child),
  );
}

/// A failure above the composer, with what can be done about it.
class _ComposerNotice extends StatelessWidget {
  const _ComposerNotice({
    required this.text,
    this.actionLabel,
    this.onAction,
    this.onDismiss,
  });

  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    container: true,
    child: Container(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 6, 4, 6),
      decoration: BoxDecoration(
        color: studafyDanger.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: studafyDanger,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: studafyDanger, fontSize: 13),
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
          if (onDismiss != null)
            IconButton(
              tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
              onPressed: onDismiss,
              icon: const Icon(Icons.close_rounded, size: 18),
            ),
        ],
      ),
    ),
  );
}

/// One line of an options menu: an icon and a clear label.
class _MenuLine extends StatelessWidget {
  const _MenuLine({
    required this.icon,
    required this.text,
    this.destructive = false,
  });

  final IconData icon;
  final String text;
  final bool destructive;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 20, color: destructive ? studafyDanger : studafyInk),
      const SizedBox(width: 12),
      Flexible(
        child: Text(
          text,
          style: TextStyle(color: destructive ? studafyDanger : studafyInk),
        ),
      ),
    ],
  );
}

/// WhatsApp's ticks on one of my messages: one grey when sent, two grey when
/// it has reached everyone, two blue once everyone has read it.
class MessageTicks extends StatelessWidget {
  const MessageTicks({super.key, required this.status, this.onBubble = true});

  final MessageStatus status;

  /// On the navy bubble; false under a photo shown without one.
  final bool onBubble;

  /// Readable on the navy bubble, and close to the blue people know.
  static const readColor = Color(0xFF53BDEB);

  @override
  Widget build(BuildContext context) {
    final (icon, color, label) = switch (status) {
      MessageStatus.sent => (
        Icons.done_rounded,
        onBubble ? Colors.white70 : studafyMuted,
        AppL10n.of(context).conversationSent,
      ),
      MessageStatus.delivered => (
        Icons.done_all_rounded,
        onBubble ? Colors.white70 : studafyMuted,
        AppL10n.of(context).conversationDelivered,
      ),
      MessageStatus.read => (
        Icons.done_all_rounded,
        readColor,
        AppL10n.of(context).conversationRead,
      ),
    };
    return Semantics(
      label: label,
      child: Icon(icon, size: 16, color: color),
    );
  }
}
