import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/file_upload_repository.dart';
import '../../../core/studafy_design.dart';
import '../../../core/voice_note.dart';
import '../../../l10n/generated/app_l10n.dart';

/// A voice note in a chat bubble: play, pause, and how far through it is.
///
/// Until the scan has cleared it the note cannot be played - by anyone, the
/// sender included - so it says it is being checked. The bytes are fetched
/// on the first play and kept for as long as the bubble is on screen.
class VoiceNoteBubble extends StatefulWidget {
  const VoiceNoteBubble({
    super.key,
    required this.attachment,
    required this.uploads,
    required this.player,
    required this.mine,
  });

  final StoredAttachment attachment;
  final FileUploadRepository? uploads;
  final VoicePlayer Function() player;

  /// On my own (navy) bubble: light controls.
  final bool mine;

  @override
  State<VoiceNoteBubble> createState() => _VoiceNoteBubbleState();
}

class _VoiceNoteBubbleState extends State<VoiceNoteBubble> {
  StreamSubscription<VoicePlayback?>? _subscription;
  VoicePlayback? _playback;
  bool _loading = false;
  bool _failed = false;

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  VoicePlayer _listen() {
    final player = widget.player();
    _subscription ??= player.playback.listen((state) {
      if (!mounted) return;
      setState(
        () => _playback = state?.key == widget.attachment.id ? state : null,
      );
    });
    return player;
  }

  Future<void> _toggle() async {
    final uploads = widget.uploads;
    if (uploads == null || _loading) return;
    final player = _listen();
    if (_playback?.playing ?? false) {
      await player.pause();
      return;
    }
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final file = await uploads.download(widget.attachment.id);
      // The server says what it is; only a voice note is played as one.
      if (!isVoiceNote(file.mediaType)) throw StateError('not a voice note');
      await player.play(widget.attachment.id, file.bytes);
    } on Object {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final ink = widget.mine ? Colors.white : studafyInk;
    final muted = widget.mine ? Colors.white70 : studafyMuted;
    if (!widget.attachment.isReady) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.hourglass_top_rounded, size: 18, color: muted),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                l10n.msgVoiceChecking,
                style: TextStyle(color: muted, fontSize: 12),
              ),
            ),
          ],
        ),
      );
    }
    final playback = _playback;
    final playing = playback?.playing ?? false;
    final total = playback?.duration ?? Duration.zero;
    final position = playback?.position ?? Duration.zero;
    final progress = total.inMilliseconds == 0
        ? 0.0
        : (position.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
    return SizedBox(
      width: 220,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: playing ? l10n.msgVoicePause : l10n.msgVoicePlay,
                color: ink,
                onPressed: widget.uploads == null ? null : _toggle,
                icon: _loading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: ink,
                        ),
                      )
                    : Icon(
                        playing
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                      ),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 4,
                    color: ink,
                    backgroundColor: muted.withValues(alpha: .35),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                formatVoiceDuration(
                  playing || position > Duration.zero ? position : total,
                ),
                style: TextStyle(color: muted, fontSize: 12),
              ),
            ],
          ),
          if (_failed)
            Text(
              l10n.msgVoiceUnavailable,
              style: TextStyle(color: muted, fontSize: 11),
            ),
        ],
      ),
    );
  }
}

/// Replaces the composer while a voice note is being recorded: how long it
/// is so far, discard, and send. It stops by itself at [voiceNoteMaximum].
class VoiceNoteRecorderBar extends StatefulWidget {
  const VoiceNoteRecorderBar({
    super.key,
    required this.onDiscard,
    required this.onSend,
    this.maximum = voiceNoteMaximum,
  });

  final VoidCallback onDiscard;

  /// [reachedLimit] is true when the recording stopped at [maximum].
  final void Function({required bool reachedLimit}) onSend;
  final Duration maximum;

  @override
  State<VoiceNoteRecorderBar> createState() => _VoiceNoteRecorderBarState();
}

class _VoiceNoteRecorderBarState extends State<VoiceNoteRecorderBar> {
  final _clock = Stopwatch()..start();
  Timer? _ticker;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!mounted) return;
      if (_clock.elapsed >= widget.maximum) {
        _finish(reachedLimit: true);
      } else {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _finish({required bool reachedLimit}) {
    if (_done) return;
    _done = true;
    _ticker?.cancel();
    widget.onSend(reachedLimit: reachedLimit);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return Row(
      children: [
        IconButton(
          tooltip: l10n.msgVoiceDiscard,
          onPressed: _done ? null : widget.onDiscard,
          icon: const Icon(Icons.delete_outline_rounded),
        ),
        const Icon(Icons.fiber_manual_record_rounded, color: Color(0xFFB3261E)),
        const SizedBox(width: 6),
        Expanded(
          child: Semantics(
            liveRegion: true,
            child: Text(
              '${l10n.msgVoiceRecording}  '
              '${formatVoiceDuration(_clock.elapsed)}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
        IconButton.filled(
          tooltip: l10n.msgVoiceSend,
          onPressed: _done ? null : () => _finish(reachedLimit: false),
          icon: const Icon(Icons.send_rounded),
        ),
      ],
    );
  }
}
