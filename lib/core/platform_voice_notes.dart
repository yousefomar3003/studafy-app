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
class PlatformVoicePlayer implements VoicePlayer {
  PlatformVoicePlayer() {
    _subscriptions = [
      _player.onPlayerStateChanged.listen((state) {
        _playing = state == PlayerState.playing;
        _emit();
      }),
      _player.onPositionChanged.listen((position) {
        _position = position;
        _emit();
      }),
      _player.onDurationChanged.listen((duration) {
        _duration = duration;
        _emit();
      }),
      _player.onPlayerComplete.listen((_) {
        _playing = false;
        _position = Duration.zero;
        _emit();
      }),
    ];
  }

  final AudioPlayer _player = AudioPlayer();
  final _controller = StreamController<VoicePlayback?>.broadcast();
  final Map<String, String> _files = {};
  late final List<StreamSubscription<Object?>> _subscriptions;

  String? _key;
  bool _playing = false;
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

  @override
  Stream<VoicePlayback?> get playback => _controller.stream;

  @override
  Future<void> play(String key, Uint8List bytes) async {
    if (_key == key) {
      await _player.resume();
      return;
    }
    var path = _files[key];
    if (path == null) {
      final directory = await getTemporaryDirectory();
      path = p.join(directory.path, 'play-${_files.length}-$hashCode.m4a');
      await File(path).writeAsBytes(bytes, flush: true);
      _files[key] = path;
    }
    await _player.stop();
    _key = key;
    _position = Duration.zero;
    _duration = Duration.zero;
    await _player.play(DeviceFileSource(path, mimeType: voiceNoteMediaType));
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> dispose() async {
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
