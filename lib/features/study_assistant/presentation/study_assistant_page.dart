import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/ai_tokens.dart';
import '../../../core/ai_usage.dart';
import '../../../core/attachment_field.dart';
import '../../../core/attachment_policy.dart';
import '../../../core/failures.dart';
import '../../../core/file_upload_repository.dart';
import '../../../core/idempotency.dart';
import '../../../core/material_selection.dart';
import '../../../core/material_unavailable_dialog.dart';
import '../../../core/navigation.dart';
import '../../../core/result.dart';
import '../../../core/studafy_components.dart';
import '../../../core/studafy_design.dart';
import '../../../core/studafy_formatting.dart';
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
    this.allowance,
    this.upgradeTo,
    this.upgradeBenefits = const [],
  });

  final String name;

  /// The AI tokens left, and when they renew (ADR-0037).
  final HelperAllowance? allowance;

  /// The next plan's name; null when there is nothing above this one.
  final String? upgradeTo;

  /// What the next plan adds, in the reader's language.
  final List<String> upgradeBenefits;

  bool get limitReached => allowance?.exhausted ?? false;

  HelperPlan withAllowance(HelperAllowance value) => HelperPlan(
    name: name,
    allowance: value,
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
    this.onBack,
    this.openWith,
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

  /// A question was refused by the student's plan - its AI tokens are used
  /// ([StudyAssistantFailure.allowanceUsed]) or photos need a higher plan
  /// ([StudyAssistantFailure.planRequired]). The host explains the limit and
  /// offers the upgrade; plans belong to another feature. Null keeps only
  /// the message under the composer.
  final Future<void> Function(BuildContext context, String failureCode)?
  onPlanLimit;

  /// The student's plan and its AI tokens. Null shows neither.
  final Future<HelperPlan?> Function()? plan;

  /// Opens the plans. Null offers no upgrade.
  final Future<void> Function()? onUpgrade;

  /// Leaves the helper. Set where it is shown full screen, without the tab
  /// bar, and the page then offers a back arrow.
  final VoidCallback? onBack;

  /// Material to start a new chat about - set when the student opens the
  /// helper from a lesson. The page clears it once used.
  final ValueNotifier<List<ChatReference>?>? openWith;

  @override
  State<StudyAssistantPage> createState() => _StudyAssistantPageState();
}

class _StudyAssistantPageState extends State<StudyAssistantPage> {
  final TextEditingController _composer = TextEditingController();
  final ScrollController _scroll = ScrollController();
  bool _asking = false;
  bool _off = false;
  String? _error;
  StudyChat? _chat;
  HelperAbilities _abilities = const HelperAbilities();
  HelperPlan? _plan;

  /// The AI tokens are used: the server refused a question for that reason,
  /// or the plan says so.
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
    widget.openWith?.addListener(_openRequested);
    _openRequested();
  }

  /// Opened from a lesson: a new chat about that lesson.
  void _openRequested() {
    final requested = widget.openWith?.value;
    if (requested == null || requested.isEmpty) return;
    widget.openWith!.value = null;
    if (!mounted) return;
    unawaited(_refreshRecent());
    setState(() {
      _chat = null;
      _error = null;
      _photo = null;
      _draftReferences = requested;
    });
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
    widget.openWith?.removeListener(_openRequested);
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

  /// The material the chat answers from, from now on. In a chat that has
  /// begun, the change is marked where it happened, so earlier answers are
  /// not mistaken for ones made from the new material.
  void _setReferences(List<ChatReference> next) => setState(() {
    final chat = _chat;
    if (chat == null) {
      _draftReferences = next;
    } else {
      _chat = chat.withReferences(
        next,
        mark: chat.turns.isEmpty
            ? null
            : ChatContextMark(
                at: widget.now(),
                label: next.isEmpty
                    ? ''
                    : materialSummary(
                        AppL10n.of(context),
                        selectionOfReferences(next),
                      ),
              ),
      );
      unawaited(widget.chats?.save(_chat!).catchError((Object _) {}));
    }
  });

  Future<void> _changeMaterial() async {
    final pick = widget.pickReferences;
    if (pick == null) return;
    final picked = await pick(context, _references);
    if (picked != null && mounted) _setReferences(picked);
  }

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
      await _changeMaterial();
      return;
    }
    final source = widget.attachmentSource;
    if (source == null) return;
    final chosen = await source(
      choice == 'camera' ? AttachmentKind.camera : AttachmentKind.photo,
      AttachmentPolicy.assistantAttachment,
    );
    if (chosen == null || !mounted) return;
    final photo = chosen.localized(l10n);
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
    StudyAssistantFailure.allowanceUsed => switch (_plan?.allowance) {
      final allowance? => AppL10n.of(
        context,
      ).helperTokensUsedUntil(studafyMediumDate(context, allowance.resetsAt)),
      null => AppL10n.of(context).helperTokensUsed,
    },
    StudyAssistantFailure.inProgress => AppL10n.of(
      context,
    ).helperStillAnswering,
    StudyAssistantFailure.unavailable => AppL10n.of(
      context,
    ).studyAssistantUnavailable,
    StudyAssistantFailure.planRequired => AppL10n.of(context).helperPhotoPlus,
    StudyAssistantFailure.photoNotReady => AppL10n.of(
      context,
    ).helperPhotoFailed,
    StudyAssistantFailure.consentRequired => AppL10n.of(
      context,
    ).aiConsentNeeded,
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
    // One id for this question, kept through the waits below: a retry of
    // the same question is never charged twice.
    final requestId = generateUuidV4();
    final language = Localizations.localeOf(context).languageCode;
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

    // The photo is shown in the chat as itself: a small copy, made beside
    // the question and kept on the device with the chat.
    if (photo != null) unawaited(_keepThumbnail(at, photo.bytes));

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
    var skipUnavailable = false;
    while (true) {
      final result = await widget.assistant.ask(
        question,
        history: earlier,
        references: references,
        photoFileIds: photoIds,
        requestId: requestId,
        language: language,
        skipUnavailable: skipUnavailable,
      );
      if (!mounted) return;
      // Chosen files that cannot be read now are named; the student says
      // whether to go on without them. Nothing is left out quietly.
      if (result
          case FailureResult(failure: final MaterialUnavailableException gone)
          when !skipUnavailable) {
        final go = await confirmContinueWithout(
          context,
          gone,
          selection: selectionOfReferences(references),
        );
        if (!mounted) return;
        if (!go) {
          giveBack(l10n.unavailableTitle);
          return;
        }
        skipUnavailable = true;
        continue;
      }
      final retry = result.fold(
        onSuccess: (StudyAnswer value) {
          final answered = _chat!.withTurns([
            ..._chat!.turns,
            ChatTurn(
              role: ChatRole.assistant,
              text: value.answer,
              at: widget.now(),
              citations: value.citations,
              unreadable: value.unreadable,
            ),
          ]);
          setState(() {
            _asking = false;
            _status = null;
            _chat = answered;
            final plan = _plan;
            final allowance = value.allowance;
            if (plan != null && allowance != null) {
              _plan = plan.withAllowance(allowance);
            }
            _limitHit = allowance?.exhausted ?? _limitHit;
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
          if (failure.code == StudyAssistantFailure.allowanceUsed) {
            // The question and the chat stay; the plan is read again for
            // what is left and when it renews.
            setState(() => _limitHit = true);
            unawaited(
              _loadPlan().then((_) {
                if (mounted) setState(() => _limitHit = true);
              }),
            );
          }
          final onPlanLimit = widget.onPlanLimit;
          if (onPlanLimit != null &&
              (failure.code == StudyAssistantFailure.allowanceUsed ||
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

  /// A copy of [bytes] at most 480 px wide, put on the question asked at
  /// [at]. Nothing is shown in its place if it cannot be made.
  Future<void> _keepThumbnail(DateTime at, Uint8List bytes) async {
    Uint8List? thumb;
    try {
      final codec = await ui.instantiateImageCodec(bytes, targetWidth: 480);
      final frame = await codec.getNextFrame();
      final data = await frame.image.toByteData(format: ui.ImageByteFormat.png);
      thumb = data?.buffer.asUint8List();
      frame.image.dispose();
      codec.dispose();
    } on Object {
      return;
    }
    if (thumb == null || !mounted) return;
    final chat = _chat;
    if (chat == null) return;
    final turns = [
      for (final turn in chat.turns)
        turn.at == at && turn.role == ChatRole.student
            ? turn.withPhotoThumb(thumb)
            : turn,
    ];
    final next = chat.withTurns(turns);
    setState(() => _chat = next);
    unawaited(widget.chats?.save(next).catchError((Object _) {}));
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
              leading: switch (widget.onBack) {
                final back? => BackButton(onPressed: back),
                null => null,
              },
              title: l10n.studyAssistantTitle,
              subtitle: l10n.helperSubtitle,
              padding: const EdgeInsetsDirectional.fromSTEB(20, 14, 16, 8),
            ),
            // Starting afresh and going back to an earlier chat are the two
            // things a student looks for first, so both are labelled.
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 8),
              // Wraps onto a second line with the largest text sizes.
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  StudafyPillButton(
                    icon: Icons.add_comment_rounded,
                    label: l10n.studyAssistantNewChat,
                    prominent: true,
                    onPressed: _asking || _turns.isEmpty ? null : _newChat,
                  ),
                  if (widget.chats != null)
                    StudafyPillButton(
                      icon: Icons.history_rounded,
                      label: l10n.studyAssistantHistory,
                      onPressed: _openHistory,
                    ),
                ],
              ),
            ),
            // What the chat answers from stays in view whenever it uses
            // class material, and wherever material can be chosen.
            if (_canAddMaterial || _references.isNotEmpty) _contextBar(l10n),
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
    final allowance = plan.allowance;
    return PlanSummaryCard(
      eyebrow: l10n.studyPlansYourPlan,
      planName: plan.name,
      detail: allowance == null ? null : _tokensLine(l10n, allowance),
      progress: allowance?.usedFraction,
      benefitsTitle: upgrade ? l10n.planAdds(plan.upgradeTo!) : null,
      benefits: upgrade ? plan.upgradeBenefits : const [],
      actionLabel: upgrade ? l10n.upgradeButton : null,
      onAction: upgrade ? _upgrade : null,
      compact: compact,
    );
  }

  /// "Plenty available · resets 13 Oct": usage as a label, never a count.
  String _tokensLine(AppL10n l10n, HelperAllowance allowance) => aiUsageLine(
    context,
    level: aiUsageLevel(used: allowance.used, total: allowance.total),
    resetsAt: allowance.resetsAt,
  );

  /// What the helper answers from, always in view above the conversation,
  /// with the way to change it.
  Widget _contextBar(AppL10n l10n) {
    final references = _references;
    final using = references.isNotEmpty;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 8),
      child: Material(
        color: using
            ? Color.alphaBlend(studafyNavy.withValues(alpha: .06), Colors.white)
            : studafyWash,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: using ? studafyNavy : studafyHairline),
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(12, 6, 4, 6),
          child: Row(
            children: [
              Icon(
                using ? Icons.menu_book_rounded : Icons.public_rounded,
                size: 18,
                color: using ? studafyNavy : studafyMuted,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Semantics(
                  liveRegion: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        using
                            ? l10n.helperAnsweringFrom
                            : l10n.helperNoMaterial,
                        // Navy: muted grey on the wash background is under
                        // WCAG's 4.5:1 for text this small (launch plan 7.1).
                        style: const TextStyle(
                          color: studafyNavy,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (using)
                        Text(
                          materialSummary(
                            l10n,
                            selectionOfReferences(references),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: studafyInk,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (_canAddMaterial)
                TextButton(
                  onPressed: _asking ? null : _changeMaterial,
                  child: Text(
                    using
                        ? l10n.helperChangeMaterial
                        : l10n.helperChooseMaterial,
                  ),
                ),
              if (using)
                IconButton(
                  tooltip: l10n.helperRemove,
                  visualDensity: VisualDensity.compact,
                  onPressed: _asking ? null : () => _setReferences(const []),
                  icon: const Icon(Icons.close_rounded, size: 18),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _conversation(AppL10n l10n) {
    final turns = _turns;
    if (turns.isEmpty && !_asking) {
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
          if (!_off && _plan?.allowance != null)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: () => showTokenGuide(context),
                icon: const Icon(Icons.info_outline_rounded, size: 18),
                label: Text(l10n.tokensWhatAreThey),
              ),
            ),
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
                          '${studafyMediumDate(context, chat.updatedAt)} · '
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
    // Newest at the bottom, where the eye and the keyboard are. Where the
    // material changed is marked between the turns.
    final marks = _chat?.marks ?? const <ChatContextMark>[];
    final timeline = <(DateTime, Widget)>[
      for (final turn in turns) (turn.at, _Bubble(turn: turn)),
      for (final mark in marks) (mark.at, _ContextMarkRow(mark: mark)),
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    final items = [
      for (final item in timeline) item.$2,
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
    // The helper has the whole screen, with no tab bar below, so the field
    // keeps clear of the home indicator itself.
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(12, 4, 12, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // The tokens are used: say so, keep the question, and offer the
            // way on.
            if (_limitHit && !_off)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _Banner(
                  icon: Icons.hourglass_bottom_rounded,
                  // The server's own refusal when there is one; otherwise the
                  // plan says the tokens are used.
                  text:
                      _error ??
                      switch (plan?.allowance) {
                        final allowance? => l10n.helperTokensUsedUntil(
                          studafyMediumDate(context, allowance.resetsAt),
                        ),
                        null => l10n.helperTokensUsed,
                      },
                  actionLabel: _canUpgrade ? l10n.upgradeButton : null,
                  onAction: _canUpgrade ? _upgrade : null,
                ),
              )
            else if (plan?.allowance case final allowance?
                when allowance.low && !_off)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _Banner(
                  icon: Icons.battery_alert_rounded,
                  text: _tokensLine(l10n, allowance),
                  actionLabel: _canUpgrade ? l10n.upgradeButton : null,
                  onAction: _canUpgrade ? _upgrade : null,
                ),
              )
            else if (inChat && plan?.allowance != null)
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(8, 0, 4, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${plan!.name} · ${_tokensLine(l10n, plan.allowance!)}',
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
            // The photo going with the next question, removable. What the
            // chat answers from is shown above the conversation.
            if (_photo != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (_photo case final photo?)
                      InputChip(
                        avatar: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Image.memory(
                            photo.bytes,
                            width: 24,
                            height: 24,
                            fit: BoxFit.cover,
                            cacheWidth: 72,
                            errorBuilder: (_, _, _) =>
                                const Icon(Icons.image_outlined, size: 16),
                          ),
                        ),
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
              if (turn.photoThumb case final thumb?)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      thumb,
                      width: 220,
                      fit: BoxFit.cover,
                      semanticLabel: turn.photoName,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                  ),
                )
              else if (turn.photoName case final photo?)
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
              // What the material could not tell it, then where each fact
              // came from: [1] Leaf.pdf, p. 3.
              if (turn.unreadable.isNotEmpty) ...[
                const SizedBox(height: 8),
                for (final source in turn.unreadable)
                  Text(
                    l10n.helperCouldNotRead(
                      source.name,
                      readingReasonText(l10n, source.reason),
                    ),
                    style: const TextStyle(
                      color: studafyMuted,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
              ],
              if (turn.citations.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  l10n.helperSources,
                  style: const TextStyle(
                    color: studafyMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                for (final citation in turn.citations)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '[${citation.n}] ${citationLabel(l10n, citation)}',
                      style: const TextStyle(
                        color: studafySteel,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// "Leaf.pdf, p. 3", "Cells.pptx, slide 2", "Photosynthesis (lesson)".
String citationLabel(AppL10n l10n, AnswerCitation citation) {
  final where = citation.page != null
      ? l10n.helperCitationPage(citation.page!)
      : citation.slide != null
      ? l10n.helperCitationSlide(citation.slide!)
      : null;
  final name = citation.kind == 'lesson'
      ? l10n.helperCitationLesson(citation.name)
      : citation.kind == 'note'
      ? l10n.helperCitationNote(citation.name)
      : citation.name;
  return where == null ? name : '$name, $where';
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

/// "From here: Biology · 8A · Lesson: Cells · 2 attachments" - where the
/// chat's material changed.
class _ContextMarkRow extends StatelessWidget {
  const _ContextMarkRow({required this.mark});

  final ChatContextMark mark;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          const Expanded(child: Divider()),
          Flexible(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                mark.label.isEmpty
                    ? l10n.helperMaterialRemovedMark
                    : l10n.helperMaterialChangedMark(mark.label),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: studafyMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }
}
