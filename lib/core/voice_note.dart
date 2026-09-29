import 'package:flutter/foundation.dart';

/// Voice notes in messages (2026-09-28).
///
/// Recorded as AAC in an MP4 container - `audio/mp4`, the one audio type the
/// upload pipeline accepts, for message attachments only. The server parses
/// it, refuses anything but sound tracks, and blanks its metadata before
/// anyone else can play it.
const voiceNoteMediaType = 'audio/mp4';

/// The longest voice note the app records. At [voiceNoteBitRate] that is
/// about 2.4 MB, inside the 5 MB message-attachment ceiling.
const voiceNoteMaximum = Duration(minutes: 5);

/// Speech needs no more; it keeps a five-minute note well under the ceiling.
const voiceNoteBitRate = 64000;

/// Shorter than this is a slip of the finger, not a message.
const voiceNoteMinimum = Duration(milliseconds: 700);

bool isVoiceNote(String? mediaType) => mediaType == voiceNoteMediaType;

@immutable
class RecordedVoiceNote {
  const RecordedVoiceNote({required this.bytes, required this.duration});

  final Uint8List bytes;
  final Duration duration;
}

/// The device's microphone. One recording at a time.
abstract interface class VoiceRecorder {
  /// Asks for the microphone if it has not been granted. False if refused.
  Future<bool> requestPermission();

  Future<void> start();

  /// Stops and returns what was recorded, or null if nothing was.
  Future<RecordedVoiceNote?> stop();

  /// Stops and throws the recording away.
  Future<void> cancel();

  Future<void> dispose();
}

/// Plays one voice note at a time.
abstract interface class VoicePlayer {
  /// Plays [bytes], which [key] identifies so the same note is not prepared
  /// twice.
  Future<void> play(String key, Uint8List bytes);

  Future<void> pause();

  /// The note being played, its position and length; null when idle.
  Stream<VoicePlayback?> get playback;

  Future<void> dispose();
}

@immutable
class VoicePlayback {
  const VoicePlayback({
    required this.key,
    required this.playing,
    required this.position,
    required this.duration,
  });

  final String key;
  final bool playing;
  final Duration position;
  final Duration duration;
}

/// "0:07", "1:42" - how long a voice note is, or how far into it.
String formatVoiceDuration(Duration value) {
  final seconds = value.inSeconds;
  return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
}
