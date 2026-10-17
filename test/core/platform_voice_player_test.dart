import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/core/platform_voice_notes.dart';
import 'package:studafy/core/voice_note.dart';

/// The real player against a stand-in for the native side of
/// `audioplayers`, speaking its channel protocol. What matters is what the
/// app asks the native player to do: on Android, a bare `resume` after a note
/// has finished does nothing at all - the bug of 2026-10-17.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _NativePlayer native;
  late Directory directory;

  setUp(() {
    native = _NativePlayer()..install();
    directory = Directory.systemTemp.createTempSync('voice-player-test');
  });

  tearDown(() {
    native.uninstall();
    if (directory.existsSync()) directory.deleteSync(recursive: true);
  });

  PlatformVoicePlayer player({
    Duration stallTimeout = const Duration(seconds: 30),
  }) => PlatformVoicePlayer(
    directory: () async => directory,
    stallTimeout: stallTimeout,
  );

  final bytes = Uint8List.fromList([0, 0, 0, 24, 102, 116, 121, 112]);

  test('plays a note from a temporary .m4a file', () async {
    final voice = player();
    await voice.play('voice-1', bytes);

    final source =
        native.calls.lastWhere((c) => c.method == 'setSourceUrl').arguments
            as Map<String, Object?>;
    expect(source['isLocal'], isTrue);
    expect(source['url'], endsWith('.m4a'));
    expect(File(source['url']! as String).readAsBytesSync(), bytes);
    expect(native.methods.last, 'resume');
    await voice.dispose();
  });

  test('a note that has finished plays again from its file', () async {
    final voice = player();
    await voice.play('voice-1', bytes);
    native.complete();
    await pumpEventQueue();
    native.calls.clear();

    await voice.play('voice-1', bytes);

    // Its source is set again; a bare resume would be silent on Android.
    expect(native.methods, containsAllInOrder(['setSourceUrl', 'resume']));
    await voice.dispose();
  });

  test('a paused note is resumed where it stopped', () async {
    final voice = player();
    await voice.play('voice-1', bytes);
    await voice.pause();
    native.calls.clear();

    await voice.play('voice-1', bytes);

    expect(native.methods, ['resume']);
    await voice.dispose();
  });

  test('a native error while playing reaches the playback stream', () async {
    final voice = player();
    final errors = <Object>[];
    final states = <VoicePlayback?>[];
    voice.playback.listen(states.add, onError: errors.add);
    await voice.play('voice-1', bytes);

    native.fail('AndroidAudioError', 'MEDIA_ERROR_UNKNOWN {what:1}');
    await pumpEventQueue();

    expect(errors.single, isA<PlatformException>());
    expect(
      voicePlaybackFailureCode(errors.single),
      'platform:AndroidAudioError',
    );
    expect(states.last?.playing, isFalse);
    await voice.dispose();
  });

  test('an error while starting is thrown, not reported twice', () async {
    final voice = player();
    final errors = <Object>[];
    voice.playback.listen(null, onError: errors.add);
    native.failNextSource = true;

    await expectLater(
      voice.play('voice-1', bytes),
      throwsA(isA<PlatformException>()),
    );
    await pumpEventQueue();
    expect(errors, isEmpty);
    await voice.dispose();
  });

  test('a note that says it plays but never moves is reported', () async {
    final voice = player(stallTimeout: const Duration(milliseconds: 20));
    final errors = <Object>[];
    voice.playback.listen(null, onError: errors.add);
    native.position = null;
    await voice.play('voice-1', bytes);

    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(errors.single, isA<VoicePlaybackStalled>());
    expect(voicePlaybackFailureCode(errors.single), 'stalled');
    await voice.dispose();
  });

  test('a note that is moving is left alone', () async {
    final voice = player(stallTimeout: const Duration(milliseconds: 20));
    final errors = <Object>[];
    voice.playback.listen(null, onError: errors.add);
    native.position = 1500;
    await voice.play('voice-1', bytes);

    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(errors, isEmpty);
    await voice.dispose();
  });
}

/// The native half of `audioplayers`, as far as these tests need it.
class _NativePlayer {
  static const _players = MethodChannel('xyz.luan/audioplayers');
  static const _global = MethodChannel('xyz.luan/audioplayers.global');
  static const _globalEvents = EventChannel(
    'xyz.luan/audioplayers.global/events',
  );

  final calls = <MethodCall>[];
  List<String> get methods => [for (final call in calls) call.method];

  final _sinks = <String, MockStreamHandlerEventSink>{};
  final _channels = <EventChannel>[];

  /// What `getCurrentPosition` answers, in milliseconds.
  int? position = 0;
  bool failNextSource = false;

  TestDefaultBinaryMessenger get _messenger =>
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  MockStreamHandlerEventSink get _sink => _sinks.values.single;

  void install() {
    _messenger
      ..setMockMethodCallHandler(_global, (_) async => 1)
      ..setMockStreamHandler(
        _globalEvents,
        MockStreamHandler.inline(onListen: (_, _) {}),
      )
      ..setMockMethodCallHandler(_players, _handle);
  }

  void uninstall() {
    _messenger
      ..setMockMethodCallHandler(_global, null)
      ..setMockStreamHandler(_globalEvents, null)
      ..setMockMethodCallHandler(_players, null);
    for (final channel in _channels) {
      _messenger.setMockStreamHandler(channel, null);
    }
  }

  Future<Object?> _handle(MethodCall call) async {
    final args = Map<String, Object?>.from(call.arguments as Map);
    final playerId = args['playerId']! as String;
    calls.add(MethodCall(call.method, args));
    switch (call.method) {
      case 'create':
        final channel = EventChannel('xyz.luan/audioplayers/events/$playerId');
        _channels.add(channel);
        _messenger.setMockStreamHandler(
          channel,
          MockStreamHandler.inline(
            onListen: (_, sink) => _sinks[playerId] = sink,
          ),
        );
      case 'setSourceUrl':
        if (failNextSource) {
          failNextSource = false;
          scheduleMicrotask(
            () => _sink.error(code: 'AndroidAudioError', message: 'no'),
          );
        } else {
          scheduleMicrotask(() {
            _sink
              ..success({'event': 'audio.onDuration', 'value': 13280})
              ..success({'event': 'audio.onPrepared', 'value': true});
          });
        }
      case 'getCurrentPosition':
        return position;
      case 'getDuration':
        return 13280;
    }
    return 1;
  }

  void complete() => _sink.success({'event': 'audio.onComplete'});

  void fail(String code, String message) =>
      _sink.error(code: code, message: message);
}
