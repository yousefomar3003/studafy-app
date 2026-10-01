import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/attachment_field.dart';
import '../../../core/attachment_policy.dart';
import '../../../core/failures.dart';
import '../../../core/file_upload_repository.dart';
import '../../../core/idempotency.dart';
import '../../../core/navigation.dart';
import '../../../core/studafy_components.dart';
import '../../../core/studafy_design.dart';
import '../../../core/user_content_text.dart';
import '../../../l10n/generated/app_l10n.dart';
import '../application/study_assistant_interactor.dart';
import '../domain/study_assistant_repository.dart';
import 'study_chat_history_page.dart';

/// The student's plan, as the helper shows it. Built by the host, since
/// plans belong to another feature.
@immutable
class HelperPlan {
  const HelperPlan({
    required this.name,
    required this.askToday,
    required this.askPerDay,
    this.upgradeTo,
    this.upgradeBenefits = const [],
  });

  final String name;
  final int askToday;
  final int askPerDay;

  /// The next plan's name; null when there is nothing above this one.
  final String? upgradeTo;

  /// What the next plan adds, in the reader's language.
  final List<String> upgradeBenefits;

  bool get limitReached => askPerDay > 0 && askToday >= askPerDay;

  HelperPlan withAskToday(int value) => HelperPlan(
    name: name,
    askToday: value,
    askPerDay: askPerDay,
    upgradeTo: upgradeTo,
    upgradeBenefits: upgradeBenefits,
  );
}

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
    this.plan,
    this.onUpgrade,
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

  /// The student's plan and today's questions. Null shows neither.
  final Future<HelperPlan?> Function()? plan;

  /// Opens the plans. Null offers no upgrade.
  final Future<void> Function()? onUpgrade;

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
  HelperPlan? _plan;

  /// Today's questions are used: the server refused one for that reason, or
  /// the plan says so.
  bool _limitHit = false;
  List<StudyChat> _recent = const [];

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
    unawaited(_loadPlan());
  }

  Future<void> _loadPlan() async {
    final load = widget.plan;
    if (load == null) return;
    try {
      final plan = await load();
      if (!mounted) return;
      setState(() {
        _plan = plan;
        _limitHit = plan?.limitReached ?? false;
      });
    } on Object {
      // Without the plan there is no usage line; questions still work.
    }
  }

  Future<void> _upgrade() async {
    final open = widget.onUpgrade;
    if (open == null) return;
    await open();
    // A plan bought there lifts the limit here.
    await _loadPlan();
  }

  bool get _canUpgrade => widget.onUpgrade != null && _plan?.upgradeTo != null;

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
      if (!mounted) return;
      setState(() {
        _recent = chats;
        if (_chat == null && chats.isNotEmpty) _chat = chats.first;
      });
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

  void _newChat() {
    unawaited(_refreshRecent());
    _clearChat();
  }

  Future<void> _refreshRecent() async {
    final store = widget.chats;
    if (store == null) return;
    try {
      final chats = await store.chats();
      if (mounted) setState(() => _recent = chats);
    } on Object {
      // The list is a convenience; the history page is the full record.
    }
  }

  void _clearChat() => setState(() {
    _chat = null;
    _error = null;
    _draftReferences = const [];
    _photo = null;
    _composer.clear();
  });

  Future<void> _openHistory() async {
    final store = widget.chats;
    if (store == null) return;
    final chosen = await Navigator.of(context).pushOnce<StudyChat>(
      MaterialPageRoute<StudyChat>(
        builder: (_) => StudyChatHistoryPage(store: store),
      ),
    );
    if (!mounted) return;
    unawaited(_refreshRecent());
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
            final plan = _plan;
            if (plan != null) {
              _plan = plan.withAskToday(
                (plan.askPerDay - value.remainingToday).clamp(
                  0,
                  plan.askPerDay,
                ),
              );
            }
            _limitHit = value.remainingToday == 0;
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
          if (failure.code == StudyAssistantFailure.dailyLimit) {
            setState(() => _limitHit = true);
          }
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
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            StudafyLargeTitle(
              title: l10n.studyAssistantTitle,
              subtitle: l10n.helperSubtitle,
              padding: const EdgeInsetsDirectional.fromSTEB(20, 14, 16, 8),
            ),
            // Starting afresh and going back to an earlier chat are the two
            // things a student looks for first, so both are labelled.
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 8),
              child: Row(
                children: [
                  StudafyPillButton(
                    icon: Icons.add_comment_rounded,
                    label: l10n.studyAssistantNewChat,
                    prominent: true,
                    onPressed: _asking || _turns.isEmpty ? null : _newChat,
                  ),
                  const SizedBox(width: 8),
                  if (widget.chats != null)
                    StudafyPillButton(
                      icon: Icons.history_rounded,
                      label: l10n.studyAssistantHistory,
                      onPressed: _openHistory,
                    ),
                ],
              ),
            ),
            Expanded(child: _conversation(l10n)),
            _composerBar(l10n),
          ],
        ),
      ),
    );
  }

  /// The plan, in full on the start screen and as one line during a chat,
  /// so it never stands between the student and the conversation.
  Widget? _planCard(AppL10n l10n, {required bool compact}) {
    final plan = _plan;
    if (plan == null) return null;
    final upgrade = _canUpgrade;
    return PlanSummaryCard(
      eyebrow: l10n.studyPlansYourPlan,
      planName: plan.name,
      detail: plan.askPerDay > 0
          ? l10n.studyPlansQuestionsTodayAsktodayOfAskperday(
              plan.askToday,
              plan.askPerDay,
            )
          : null,
      progress: plan.askPerDay > 0 ? plan.askToday / plan.askPerDay : null,
      benefitsTitle: upgrade ? l10n.planAdds(plan.upgradeTo!) : null,
      benefits: upgrade ? plan.upgradeBenefits : const [],
      actionLabel: upgrade ? l10n.upgradeButton : null,
      onAction: upgrade ? _upgrade : null,
      compact: compact,
    );
  }

  Widget _conversation(AppL10n l10n) {
    final turns = _turns;
    if (turns.isEmpty && !_asking) {
      final dates = MaterialLocalizations.of(context);
      final recent = _recent.take(3).toList();
      return ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 16),
        children: [
          if (_off)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: FeatureCard(
                tint: studafyMuted,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const IconBadge(
                      icon: Icons.power_settings_new_rounded,
                      color: studafyMuted,
                      size: 40,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.helperOffTitle,
                            style: const TextStyle(
                              color: studafyInk,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            l10n.studyAssistantOff,
                            style: const TextStyle(
                              color: studafyMuted,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (!_off) ?_planCard(l10n, compact: false),
          const SizedBox(height: 12),
          FeatureCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const IconBadge(
                  icon: Icons.auto_awesome_rounded,
                  color: studafyTeal,
                  size: 40,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.studyAssistantIntro,
                    style: const TextStyle(color: studafyInk, height: 1.45),
                  ),
                ),
              ],
            ),
          ),
          if (recent.isNotEmpty) ...[
            SectionHeader(
              l10n.helperRecentChats,
              action: _recent.length > recent.length
                  ? TextButton(
                      onPressed: _openHistory,
                      child: Text(l10n.helperSeeAll),
                    )
                  : null,
            ),
            FeatureCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final (index, chat) in recent.indexed) ...[
                    if (index > 0)
                      const Divider(
                        height: 1,
                        indent: 64,
                        color: studafyHairline,
                      ),
                    ChatHistoryRow(
                      title: chat.title,
                      detail:
                          '${dates.formatMediumDate(chat.updatedAt)} · '
                          '${l10n.studyAssistantMessageCount(chat.turns.length)}',
                      onTap: () => setState(() {
                        _chat = chat;
                        _error = null;
                      }),
                    ),
                  ],
                ],
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
      padding: const EdgeInsetsDirectional.fromSTEB(12, 12, 12, 4),
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            l10n.studyAssistantCheckWork,
            textAlign: TextAlign.center,
            style: const TextStyle(color: studafyMuted, fontSize: 12),
          ),
        ),
        ...items.reversed,
      ],
    );
  }

  Widget _composerBar(AppL10n l10n) {
    final plan = _plan;
    final inChat = _turns.isNotEmpty || _asking;
    final canAdd = _canAddMaterial || widget.uploads != null;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 4, 12, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Today's questions are used: say so, and offer the way on.
          if (_limitHit && !_off)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _Banner(
                icon: Icons.hourglass_bottom_rounded,
                // The server's own refusal when there is one; otherwise the
                // plan says today's questions are used.
                text: _error ?? l10n.helperLimitReached,
                actionLabel: _canUpgrade ? l10n.upgradeButton : null,
                onAction: _canUpgrade ? _upgrade : null,
              ),
            )
          else if (inChat && plan != null && plan.askPerDay > 0)
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(8, 0, 4, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${plan.name} · '
                      '${l10n.studyPlansQuestionsTodayAsktodayOfAskperday(plan.askToday, plan.askPerDay)}',
                      style: const TextStyle(
                        color: studafyMuted,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                  if (_canUpgrade)
                    TextButton(
                      onPressed: _upgrade,
                      style: TextButton.styleFrom(
                        minimumSize: const Size(0, 36),
                        visualDensity: VisualDensity.compact,
                      ),
                      child: Text(l10n.upgradeButton),
                    ),
                ],
              ),
            )
          else if (_remaining != null)
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(8, 0, 8, 4),
              child: Text(
                l10n.studyAssistantRemaining(_remaining!),
                style: const TextStyle(color: studafyMuted, fontSize: 12.5),
              ),
            ),
          if (_error != null && !(_limitHit && !_off))
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(8, 0, 8, 6),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  _error!,
                  style: const TextStyle(color: studafyDanger, fontSize: 13),
                ),
              ),
            ),
          if (_status != null)
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(8, 0, 8, 6),
              child: Text(
                _status!,
                style: const TextStyle(color: studafyMuted, fontSize: 12.5),
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
                      style: const TextStyle(
                        color: studafyMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
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
          // One rounded field: add on the leading side, send on the other.
          DecoratedBox(
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
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (canAdd)
                    IconButton(
                      tooltip: l10n.helperAdd,
                      onPressed: _asking || _off ? null : _add,
                      icon: const Icon(
                        Icons.add_circle_outline_rounded,
                        color: studafyNavy,
                      ),
                    )
                  else
                    const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _composer,
                      enabled: !_asking && !_off,
                      minLines: 1,
                      maxLines: 6,
                      maxLength: 1000,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.newline,
                      decoration: InputDecoration(
                        hintText: l10n.studyAssistantMessageHint,
                        counterText: '',
                        isDense: true,
                        filled: false,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 12,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton.filled(
                    tooltip: l10n.studyAssistantSend,
                    onPressed: _asking || _off ? null : _send,
                    style: IconButton.styleFrom(
                      backgroundColor: studafyNavy,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: studafyHairline,
                      disabledForegroundColor: studafyMuted,
                      fixedSize: const Size(44, 44),
                    ),
                    icon: _asking
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.arrow_upward_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A notice above the composer with an optional action beside it.
class _Banner extends StatelessWidget {
  const _Banner({
    required this.icon,
    required this.text,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    container: true,
    child: Container(
      padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: studafyWash,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: studafyFrost),
      ),
      child: Row(
        children: [
          Icon(icon, color: studafySteel, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: studafyInk,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(width: 8),
            FilledButton(
              onPressed: onAction,
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 40),
                shape: const StadiumBorder(),
              ),
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    ),
  );
}

/// One earlier chat: its title, when, and how long - tap to carry on.
class ChatHistoryRow extends StatelessWidget {
  const ChatHistoryRow({
    super.key,
    required this.title,
    required this.detail,
    required this.onTap,
    this.trailing,
  });

  final String title;
  final String detail;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 8, 12),
      child: Row(
        children: [
          const IconBadge(
            icon: Icons.chat_bubble_rounded,
            color: studafyTeal,
            size: 36,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UserContentText(
                  title,
                  maxLines: 1,
                  style: const TextStyle(
                    color: studafyInk,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: const TextStyle(color: studafyMuted, fontSize: 12.5),
                ),
              ],
            ),
          ),
          trailing ?? Icon(forwardChevron(context), color: studafyMuted),
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
            border: mine ? null : Border.all(color: studafyHairline),
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
        border: Border.all(color: studafyHairline),
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
