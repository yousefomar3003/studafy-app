import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'voice_note.dart';

/// The microphone, through the `record` plugin: AAC-LC in an M4A file.
///
/// The recording is written to the app's temporary directory, read back
/// once, and deleted - it never outlives the send.
class PlatformVoiceRecorder implements VoiceRecorder {
  final AudioRecorder _recorder = AudioRecorder();
  String? _path;
  DateTime? _startedAt;

  @override
  Future<bool> requestPermission() => _recorder.hasPermission();

  @override
  Future<void> start() async {
    final directory = await getTemporaryDirectory();
    final path = p.join(
      directory.path,
      'voice-${DateTime.now().microsecondsSinceEpoch}.m4a',
    );
    await _recorder.start(
      const RecordConfig(
        bitRate: voiceNoteBitRate,
        sampleRate: 44100,
        numChannels: 1,
      ),
      path: path,
    );
    _path = path;
    _startedAt = DateTime.now();
  }

  @override
  Future<RecordedVoiceNote?> stop() async {
    final path = await _recorder.stop() ?? _path;
    final started = _startedAt;
    _path = null;
    _startedAt = null;
    if (path == null || started == null) return null;
    final file = File(path);
    try {
      if (!file.existsSync()) return null;
      return RecordedVoiceNote(
        bytes: await file.readAsBytes(),
        duration: DateTime.now().difference(started),
      );
    } finally {
      await _delete(file);
    }
  }

  @override
  Future<void> cancel() async {
    final path = _path;
    _path = null;
    _startedAt = null;
    await _recorder.cancel();
    if (path != null) await _delete(File(path));
  }

  @override
  Future<void> dispose() async {
    await cancel();
    await _recorder.dispose();
  }

  static Future<void> _delete(File file) async {
    try {
      if (file.existsSync()) await file.delete();
    } on FileSystemException {
      // The OS clears the temporary directory in any case.
    }
  }
}

/// Playback through `audioplayers`. A note is written to a temporary file
/// once per [key] - playing from bytes is not supported on iOS - and the
/// files go when the player does.
///
/// A note that has finished, failed or been switched away from is played
/// again from its file; only a paused note is resumed. In the default
/// release mode the native player lets go of the file when a note ends, and
/// on Android a bare `resume` after that does nothing at all: no sound, no
/// error, and the player still says it is playing (2026-10-17).
///
/// Failures reach [playback] as errors: those `audioplayers` reports after
/// [play] has returned, and a note that is meant to be playing but has not
/// moved after [stallTimeout].
class PlatformVoicePlayer implements VoicePlayer {
  PlatformVoicePlayer({
    AudioPlayer? player,
    Future<Directory> Function()? directory,
    this.stallTimeout = const Duration(seconds: 6),
  }) : _player = player ?? AudioPlayer(),
       _directory = directory ?? getTemporaryDirectory {
    _subscriptions = [
      _player.onPlayerStateChanged.listen((state) {
        _playing = state == PlayerState.playing;
        _emit();
      }),
      _player.onPositionChanged.listen((position) {
        _position = position;
        _emit();
      }),
      // These two come from the native event stream, which carries its
      // errors too; they are handled once, below, not as uncaught errors.
      _player.onDurationChanged.listen((duration) {
        _duration = duration;
        _emit();
      }, onError: _ignore),
      _player.onPlayerComplete.listen((_) {
        _playing = false;
        _resumable = false;
        _position = Duration.zero;
        _emit();
      }, onError: _ignore),
      // Errors the native player reports while a note plays. One raised
      // while a note is being started is thrown by [play] instead.
      _player.eventStream.listen(
        null,
        onError: (Object error, StackTrace stack) {
          if (_starting) return;
          _fail(error, stack);
        },
      ),
    ];
  }

  final AudioPlayer _player;
  final Future<Directory> Function() _directory;

  static void _ignore(Object _) {}

  /// How long a note may say it is playing without getting anywhere before
  /// it is reported as failed.
  final Duration stallTimeout;

  final _controller = StreamController<VoicePlayback?>.broadcast();
  final Map<String, String> _files = {};
  late final List<StreamSubscription<Object?>> _subscriptions;

  String? _key;
  bool _playing = false;

  /// True only while the current note is paused part-way through, so [play]
  /// can pick it up where it stopped.
  bool _resumable = false;

  /// True while [play] is starting a note; errors then belong to it.
  bool _starting = false;
  Timer? _watchdog;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  void _emit() {
    final key = _key;
    if (_controller.isClosed) return;
    _controller.add(
      key == null
          ? null
          : VoicePlayback(
              key: key,
              playing: _playing,
              position: _position,
              duration: _duration,
            ),
    );
  }

  void _fail(Object error, StackTrace stack) {
    _watchdog?.cancel();
    _playing = false;
    _resumable = false;
    _emit();
    if (!_controller.isClosed) _controller.addError(error, stack);
    // Whatever the native player was left holding is of no further use.
    unawaited(_player.stop().catchError((Object _) {}));
  }

  @override
  Stream<VoicePlayback?> get playback => _controller.stream;

  @override
  Future<void> play(String key, Uint8List bytes) async {
    _watchdog?.cancel();
    _starting = true;
    try {
      if (_key == key && _resumable) {
        _resumable = false;
        await _player.resume();
      } else {
        var path = _files[key];
        if (path == null) {
          final directory = await _directory();
          path = p.join(directory.path, 'play-${_files.length}-$hashCode.m4a');
          await File(path).writeAsBytes(bytes, flush: true);
          _files[key] = path;
        }
        await _player.stop();
        _key = key;
        _resumable = false;
        _position = Duration.zero;
        _duration = Duration.zero;
        await _player.play(
          DeviceFileSource(path, mimeType: voiceNoteMediaType),
        );
      }
    } finally {
      _starting = false;
    }
    _watch(key);
  }

  /// Checks once, after [stallTimeout], that the note has got somewhere.
  /// Asks the player itself rather than the position stream, which only
  /// ticks while the screen is drawing.
  void _watch(String key) {
    _watchdog?.cancel();
    _watchdog = Timer(stallTimeout, () async {
      if (_key != key || !_playing) return;
      final Duration? position;
      try {
        position = await _player.getCurrentPosition();
      } on Object catch (error, stack) {
        if (_key == key && _playing) _fail(error, stack);
        return;
      }
      if (_key != key || !_playing) return;
      if (position == null || position == Duration.zero) {
        _fail(const VoicePlaybackStalled(), StackTrace.current);
      }
    });
  }

  @override
  Future<void> pause() async {
    _watchdog?.cancel();
    await _player.pause();
    _resumable = _key != null;
  }

  @override
  Future<void> dispose() async {
    _watchdog?.cancel();
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await _player.dispose();
    await _controller.close();
    for (final path in _files.values) {
      try {
        final file = File(path);
        if (file.existsSync()) await file.delete();
      } on FileSystemException {
        // Temporary anyway.
      }
    }
  }
}
