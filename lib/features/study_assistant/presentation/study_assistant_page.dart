import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/attachment_field.dart';
import '../../../core/attachment_policy.dart';
import '../../../core/failures.dart';
import '../../../core/file_upload_repository.dart';
import '../../../core/idempotency.dart';
import '../../../core/studafy_design.dart';
import '../../../core/user_content_text.dart';
import '../../../l10n/generated/app_l10n.dart';
import '../application/study_assistant_interactor.dart';
import '../domain/study_assistant_repository.dart';
import 'study_chat_history_page.dart';

/// The student's study helper, as a chat.
///
/// Each chat is kept on the student's device only ([chats]), for the account
/// signed in, and deleted when that account signs out of the device. With a
/// question the helper is sent the last few turns of the same chat, so a
/// follow-up makes sense - never older chats, and nothing about the student.
class StudyAssistantPage extends StatefulWidget {
  const StudyAssistantPage({
    super.key,
    required this.assistant,
    this.actions,
    this.switchedOn,
    this.chats,
    this.abilities,
    this.pickReferences,
    this.uploads,
    this.schoolId,
    this.attachmentSource,
    this.photoReadyTimeout = const Duration(seconds: 40),
    this.photoReadyPoll = const Duration(seconds: 2),
    this.now = DateTime.now,
    this.onPlanLimit,
  });

  final StudyAssistantInteractor assistant;
  final List<Widget>? actions;

  /// Whether this server has an AI provider behind the helper. The app
  /// always has the tab, but a server without a provider has no route, and
  /// every question would fail. Null, or an error, and the helper is tried.
  final Future<bool> Function()? switchedOn;

  /// Where chats are kept. Null keeps the open chat in memory only.
  final StudyChatStore? chats;

  /// What the student may give the helper besides a question. Null offers
  /// only questions.
  final Future<HelperAbilities> Function()? abilities;

  /// Chooses lessons and notes to answer from. They live in other features,
  /// so the host supplies the picker; [current] is what the chat has now.
  final Future<List<ChatReference>?> Function(
    BuildContext context,
    List<ChatReference> current,
  )?
  pickReferences;

  /// Where a photo is uploaded, and under which school.
  final FileUploadRepository? uploads;
  final String? schoolId;

  /// The photo picker. Tests supply their own.
  final AttachmentSource? attachmentSource;

  /// How long to wait for a photo to clear the scan, and how often to ask.
  final Duration photoReadyTimeout;
  final Duration photoReadyPoll;

  final DateTime Function() now;

  /// A question was refused by the student's plan - today's questions are
  /// used ([StudyAssistantFailure.dailyLimit]) or photos need a higher plan
  /// ([StudyAssistantFailure.planRequired]). The host explains the limit and
  /// offers the upgrade; plans belong to another feature. Null keeps only
  /// the message under the composer.
  final Future<void> Function(BuildContext context, String failureCode)?
  onPlanLimit;

  @override
  State<StudyAssistantPage> createState() => _StudyAssistantPageState();
}

class _StudyAssistantPageState extends State<StudyAssistantPage> {
  final TextEditingController _composer = TextEditingController();
  final ScrollController _scroll = ScrollController();
  bool _asking = false;
  bool _off = false;
  String? _error;
  int? _remaining;
  StudyChat? _chat;
  HelperAbilities _abilities = const HelperAbilities();

  /// Material chosen before the chat's first question.
  List<ChatReference> _draftReferences = const [];

  /// The photo to send with the next question.
  PickedAttachment? _photo;
  String? _status;

  List<ChatTurn> get _turns => _chat?.turns ?? const [];
  List<ChatReference> get _references => _chat?.references ?? _draftReferences;

  @override
  void initState() {
    super.initState();
    unawaited(_checkSwitchedOn());
    unawaited(_loadAbilities());
    unawaited(_openLatest());
  }

  @override
  void dispose() {
    _composer.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _checkSwitchedOn() async {
    final check = widget.switchedOn;
    if (check == null) return;
    try {
      final on = await check();
      if (mounted && !on) setState(() => _off = true);
    } on Object {
      // Unknown is not "off": the question goes to the server, which knows.
    }
  }

  Future<void> _loadAbilities() async {
    final load = widget.abilities;
    if (load == null) return;
    try {
      final abilities = await load();
      if (!mounted) return;
      setState(() {
        _abilities = abilities;
        if (!abilities.ask) _off = true;
      });
    } on Object {
      // Unknown offers questions only; the server decides the rest.
    }
  }

  void _setReferences(List<ChatReference> next) => setState(() {
    final chat = _chat;
    if (chat == null) {
      _draftReferences = next;
    } else {
      _chat = chat.withReferences(next);
      unawaited(widget.chats?.save(_chat!).catchError((Object _) {}));
    }
  });

  bool get _canAddMaterial =>
      _abilities.classMaterial && widget.pickReferences != null;
  bool get _canAddPhoto =>
      _abilities.photos && widget.uploads != null && widget.schoolId != null;

  Future<void> _add() async {
    final l10n = AppL10n.of(context);
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_canAddMaterial)
              ListTile(
                leading: const Icon(Icons.menu_book_rounded),
                title: Text(l10n.helperAddMaterial),
                subtitle: Text(l10n.helperAddMaterialDetail),
                onTap: () => Navigator.pop(sheetContext, 'material'),
              ),
            ListTile(
              leading: Icon(
                _canAddPhoto
                    ? Icons.photo_library_outlined
                    : Icons.lock_outline_rounded,
              ),
              title: Text(l10n.helperAddPhoto),
              subtitle: _canAddPhoto ? null : Text(l10n.helperPhotoPlus),
              enabled: _canAddPhoto,
              onTap: () => Navigator.pop(sheetContext, 'photo'),
            ),
            if (_canAddPhoto)
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: Text(l10n.helperTakePhoto),
                onTap: () => Navigator.pop(sheetContext, 'camera'),
              ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    if (choice == 'material') {
      final picked = await widget.pickReferences!(context, _references);
      if (picked != null && mounted) _setReferences(picked);
      return;
    }
    final source = widget.attachmentSource;
    if (source == null) return;
    final photo = await source(
      choice == 'camera' ? AttachmentKind.camera : AttachmentKind.photo,
      AttachmentPolicy.assistantAttachment,
    );
    if (photo == null || !mounted) return;
    if (AttachmentPolicy.assistantAttachment.refuse(
          mediaType: photo.mediaType,
          sizeBytes: photo.bytes.length,
        ) !=
        null) {
      setState(() => _error = l10n.helperPhotoFailed);
      return;
    }
    setState(() => _photo = photo);
  }

  /// Uploads the photo; returns its file id, or null with the error set.
  Future<String?> _uploadPhoto(PickedAttachment photo) async {
    final uploads = widget.uploads;
    final schoolId = widget.schoolId;
    if (uploads == null || schoolId == null) return null;
    try {
      final file = await uploads.upload(
        FileUploadCommand(
          attemptId: newIdempotencyKey('helper-photo'),
          schoolId: schoolId,
          purpose: FilePurpose.assistantAttachment,
          displayName: photo.displayName,
          mediaType: photo.mediaType,
          bytes: photo.bytes,
        ),
      );
      return file.id;
    } on Object {
      return null;
    }
  }

  /// Opens where the student left off.
  Future<void> _openLatest() async {
    final store = widget.chats;
    if (store == null) return;
    try {
      final chats = await store.chats();
      if (mounted && _chat == null && chats.isNotEmpty) {
        setState(() => _chat = chats.first);
      }
    } on Object {
      // A history that cannot be read still leaves a working helper.
    }
  }

  String _explain(Failure failure) => switch (failure.code) {
    StudyAssistantFailure.dailyLimit => AppL10n.of(
      context,
    ).studyAssistantDailyLimit,
    StudyAssistantFailure.unavailable => AppL10n.of(
      context,
    ).studyAssistantUnavailable,
    StudyAssistantFailure.planRequired => AppL10n.of(context).helperPhotoPlus,
    StudyAssistantFailure.photoNotReady => AppL10n.of(
      context,
    ).helperPhotoFailed,
    _ => failure.message,
  };

  void _newChat() => setState(() {
    _chat = null;
    _error = null;
    _draftReferences = const [];
    _photo = null;
    _composer.clear();
  });

  Future<void> _openHistory() async {
    final store = widget.chats;
    if (store == null) return;
    final chosen = await Navigator.of(context).push<StudyChat>(
      MaterialPageRoute<StudyChat>(
        builder: (_) => StudyChatHistoryPage(store: store),
      ),
    );
    if (!mounted) return;
    if (chosen != null) {
      setState(() {
        _chat = chosen;
        _error = null;
      });
      return;
    }
    // The open chat may have been deleted there.
    final open = _chat;
    if (open == null) return;
    final still = (await store.chats()).any((chat) => chat.id == open.id);
    if (!still && mounted) setState(() => _chat = null);
  }

  Future<void> _send() async {
    // Guarded rather than only disabled: a second tap that lands in the same
    // frame would otherwise spend two of the day's questions on one.
    if (_asking || _off) return;
    final l10n = AppL10n.of(context);
    final question = _composer.text.trim();
    if (question.length < 3) {
      setState(() => _error = l10n.studyAssistantTooShort);
      return;
    }
    final at = widget.now();
    final earlier = _turns;
    final photo = _photo;
    final references = _references;
    final chat =
        _chat ??
        StudyChat(
          id: '${at.microsecondsSinceEpoch}',
          title: question.length > 60
              ? '${question.substring(0, 60)}…'
              : question,
          createdAt: at,
          updatedAt: at,
          references: references,
        );
    setState(() {
      _asking = true;
      _error = null;
      _photo = null;
      _chat = chat.withTurns([
        ...earlier,
        ChatTurn(
          role: ChatRole.student,
          text: question,
          at: at,
          photoName: photo?.displayName,
        ),
      ]);
      _composer.clear();
    });

    void giveBack(String message) => setState(() {
      // Not answered, so not part of the chat: the question - and its
      // photo - go back to try again.
      _asking = false;
      _status = null;
      _chat = earlier.isEmpty && _chat?.references.isEmpty != false
          ? null
          : chat.withTurns(earlier);
      if (_chat == null) _draftReferences = references;
      _photo = photo;
      _composer.text = question;
      _error = message;
    });

    final photoIds = <String>[];
    if (photo != null) {
      final id = await _uploadPhoto(photo);
      if (!mounted) return;
      if (id == null) {
        giveBack(l10n.helperPhotoFailed);
        return;
      }
      photoIds.add(id);
      setState(() => _status = l10n.helperPhotoChecking);
    }

    // A new photo is scanned before it can be read; wait for it.
    final deadline = DateTime.now().add(widget.photoReadyTimeout);
    while (true) {
      final result = await widget.assistant.ask(
        question,
        history: earlier,
        references: references,
        photoFileIds: photoIds,
      );
      if (!mounted) return;
      final retry = result.fold(
        onSuccess: (StudyAnswer value) {
          final answered = _chat!.withTurns([
            ..._chat!.turns,
            ChatTurn(
              role: ChatRole.assistant,
              text: value.answer,
              at: widget.now(),
            ),
          ]);
          setState(() {
            _asking = false;
            _status = null;
            _chat = answered;
            _remaining = value.remainingToday;
          });
          unawaited(widget.chats?.save(answered).catchError((Object _) {}));
          return false;
        },
        onFailure: (failure) {
          if (failure.code == StudyAssistantFailure.photoNotReady &&
              DateTime.now().isBefore(deadline)) {
            return true;
          }
          giveBack(_explain(failure));
          final onPlanLimit = widget.onPlanLimit;
          if (onPlanLimit != null &&
              (failure.code == StudyAssistantFailure.dailyLimit ||
                  failure.code == StudyAssistantFailure.planRequired)) {
            unawaited(onPlanLimit(context, failure.code));
          }
          return false;
        },
      );
      if (!retry) return;
      await Future<void>.delayed(widget.photoReadyPoll);
      if (!mounted) return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.studyAssistantTitle),
        actions: [
          if (widget.chats != null)
            IconButton(
              tooltip: l10n.studyAssistantHistory,
              icon: const Icon(Icons.history_rounded),
              onPressed: _openHistory,
            ),
          IconButton(
            tooltip: l10n.studyAssistantNewChat,
            icon: const Icon(Icons.edit_square),
            onPressed: _asking || _turns.isEmpty ? null : _newChat,
          ),
          ...?widget.actions,
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _conversation(l10n)),
            _composerBar(l10n),
          ],
        ),
      ),
    );
  }

  Widget _conversation(AppL10n l10n) {
    final turns = _turns;
    if (turns.isEmpty && !_asking) {
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            l10n.studyAssistantIntro,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (_off) ...[
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.power_off_outlined),
                title: Text(l10n.studyAssistantOff),
              ),
            ),
          ],
        ],
      );
    }
    // Newest at the bottom, where the eye and the keyboard are.
    final items = [
      for (final turn in turns) _Bubble(turn: turn),
      if (_asking) _Thinking(label: l10n.studyAssistantBusy),
    ];
    return ListView(
      controller: _scroll,
      reverse: true,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            l10n.studyAssistantCheckWork,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        ...items.reversed,
      ],
    );
  }

  Widget _composerBar(AppL10n l10n) => Material(
    color: Colors.white,
    child: Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 6, 8, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (_remaining != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                l10n.studyAssistantRemaining(_remaining!),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          if (_status != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                _status!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          // What this chat answers from, and the photo going with the next
          // question - each removable.
          if (_references.isNotEmpty || _photo != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (_references.isNotEmpty)
                    Text(
                      l10n.helperAnsweringFrom,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  for (final reference in _references)
                    InputChip(
                      avatar: Icon(
                        reference.kind == ChatReferenceKind.lesson
                            ? Icons.menu_book_rounded
                            : Icons.sticky_note_2_outlined,
                        size: 16,
                      ),
                      label: Text(reference.title),
                      deleteButtonTooltipMessage: l10n.helperRemove,
                      onDeleted: _asking
                          ? null
                          : () => _setReferences([
                              for (final other in _references)
                                if (other != reference) other,
                            ]),
                    ),
                  if (_photo case final photo?)
                    InputChip(
                      avatar: const Icon(Icons.image_outlined, size: 16),
                      label: Text(photo.displayName),
                      deleteButtonTooltipMessage: l10n.helperRemove,
                      onDeleted: _asking
                          ? null
                          : () => setState(() => _photo = null),
                    ),
                ],
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (_canAddMaterial || widget.uploads != null)
                IconButton(
                  tooltip: l10n.helperAdd,
                  onPressed: _asking || _off ? null : _add,
                  icon: const Icon(Icons.add_circle_outline_rounded),
                ),
              Expanded(
                child: TextField(
                  controller: _composer,
                  enabled: !_asking && !_off,
                  minLines: 1,
                  maxLines: 5,
                  maxLength: 1000,
                  textInputAction: TextInputAction.newline,
                  decoration: InputDecoration(
                    hintText: l10n.studyAssistantMessageHint,
                    counterText: '',
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                tooltip: l10n.studyAssistantSend,
                onPressed: _asking || _off ? null : _send,
                icon: const Icon(Icons.arrow_upward_rounded),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.turn});

  final ChatTurn turn;

  @override
  Widget build(BuildContext context) {
    final mine = turn.role == ChatRole.student;
    final l10n = AppL10n.of(context);
    return Align(
      alignment: mine
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart,
      child: Semantics(
        label: mine ? l10n.studyAssistantYou : l10n.studyAssistantHelperName,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * .82,
          ),
          decoration: BoxDecoration(
            color: mine ? studafyNavy : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: mine ? null : Border.all(color: const Color(0xFFE6E8F0)),
          ),
          // The model's reply is text somebody else produced, so it renders
          // in its own direction rather than the interface's.
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (turn.photoName case final photo?)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.image_outlined,
                        size: 16,
                        color: mine ? Colors.white70 : studafyMuted,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          photo,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: mine ? Colors.white70 : studafyMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              UserContentText(
                turn.text,
                style: TextStyle(color: mine ? Colors.white : studafyInk),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Thinking extends StatelessWidget {
  const _Thinking({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Align(
    alignment: AlignmentDirectional.centerStart,
    child: Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE6E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    ),
  );
}
