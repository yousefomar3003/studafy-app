import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/core/file_upload_repository.dart';
import 'package:studafy/core/telemetry.dart';
import 'package:studafy/core/voice_note.dart';
import 'package:studafy/features/messaging/application/messaging_interactor.dart';
import 'package:studafy/features/messaging/domain/messaging.dart';
import 'package:studafy/features/messaging/presentation/conversation_page.dart';
import 'package:studafy/features/messaging/presentation/messaging_scope.dart';

import '../../support/localized_app.dart';

/// Voice notes in every chat - students, parents and teachers all use the
/// same conversation screen. Recorded on the phone, uploaded through the
/// scanned attachment pipeline, sent as a message with no text.
const _me = 'user-me';
const _teacher = 'user-teacher';

final _conversation = Conversation(
  id: 'conversation-1',
  schoolId: 'school-1',
  updatedAt: DateTime(2026, 9, 28, 10),
  lastReadAt: DateTime(2026, 9, 28, 10),
  participants: const [
    ConversationParticipant(
      userId: _me,
      displayName: 'Nadia',
      role: MessagingRole.guardian,
    ),
    ConversationParticipant(
      userId: _teacher,
      displayName: 'Rana',
      role: MessagingRole.staff,
    ),
  ],
);

void main() {
  Future<(_Chat, _Uploads, _Mic, _Speaker)> open(
    WidgetTester tester, {
    List<ChatMessage> history = const [],
    _Mic? mic,
  }) async {
    final chat = _Chat(history);
    final uploads = _Uploads();
    final microphone = mic ?? _Mic();
    final speaker = _Speaker();
    await tester.pumpWidget(
      localizedApp(
        scopes: (child) => MessagingScope(
          interactor: MessagingInteractor(
            messaging: chat,
            safety: chat,
            telemetry: const NoopTelemetry(),
          ),
          child: child,
        ),
        home: ConversationPage(
          conversation: _conversation,
          myUserId: _me,
          uploads: uploads,
          voiceRecorder: () => microphone,
          voicePlayer: () => speaker,
          refreshEvery: const Duration(days: 1),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (chat, uploads, microphone, speaker);
  }

  testWidgets('an empty draft offers the microphone; text offers send', (
    tester,
  ) async {
    await open(tester);
    expect(find.byTooltip('Record a voice note'), findsOne);

    await tester.enterText(find.byType(TextField), 'Hello');
    await tester.pump();
    expect(find.byTooltip('Record a voice note'), findsNothing);
    expect(find.byTooltip('Send'), findsOne);
  });

  testWidgets('a recorded note is uploaded as audio and sent with no text', (
    tester,
  ) async {
    final (chat, uploads, mic, _) = await open(tester);

    await tester.tap(find.byTooltip('Record a voice note'));
    await tester.pump();
    expect(mic.started, isTrue);
    expect(find.textContaining('Recording'), findsOne);

    await tester.tap(find.byTooltip('Send voice note'));
    await tester.pumpAndSettle();

    final upload = uploads.commands.single;
    expect(upload.purpose, FilePurpose.messageAttachment);
    expect(upload.mediaType, 'audio/mp4');
    expect(upload.bytes, mic.bytes);
    expect(chat.sent.single.body, '');
    expect(chat.sent.single.fileIds, ['file-1']);
    // Just sent, so still being checked - the sender cannot play it yet
    // either.
    expect(find.text('Checking voice message…'), findsOne);
  });

  testWidgets('without the microphone, nothing is recorded and it says why', (
    tester,
  ) async {
    final (_, uploads, mic, _) = await open(tester, mic: _Mic(allowed: false));

    await tester.tap(find.byTooltip('Record a voice note'));
    await tester.pump();

    expect(mic.started, isFalse);
    expect(find.textContaining('Allow microphone access'), findsOne);
    expect(uploads.commands, isEmpty);
  });

  testWidgets('a discarded recording is thrown away, not sent', (tester) async {
    final (chat, uploads, mic, _) = await open(tester);

    await tester.tap(find.byTooltip('Record a voice note'));
    await tester.pump();
    await tester.tap(find.byTooltip('Discard'));
    await tester.pumpAndSettle();

    expect(mic.cancelled, isTrue);
    expect(uploads.commands, isEmpty);
    expect(chat.sent, isEmpty);
    expect(find.byTooltip('Record a voice note'), findsOne);
  });

  testWidgets('a tap too short to say anything is not sent', (tester) async {
    final (chat, uploads, _, _) = await open(
      tester,
      mic: _Mic(duration: const Duration(milliseconds: 200)),
    );

    await tester.tap(find.byTooltip('Record a voice note'));
    await tester.pump();
    await tester.tap(find.byTooltip('Send voice note'));
    await tester.pumpAndSettle();

    expect(uploads.commands, isEmpty);
    expect(chat.sent, isEmpty);
    expect(find.text('That was too short to send.'), findsOne);
  });

  testWidgets('a cleared voice note plays; nothing else plays as one', (
    tester,
  ) async {
    final (_, uploads, _, speaker) = await open(
      tester,
      history: [
        ChatMessage(
          id: 'm1',
          conversationId: _conversation.id,
          senderId: _teacher,
          body: '',
          createdAt: DateTime(2026, 9, 28, 9),
          attachments: const [
            StoredAttachment(
              id: 'voice-1',
              displayName: 'Voice message',
              sizeBytes: 3,
              scanState: 'clean',
              mediaType: 'audio/mp4',
            ),
          ],
        ),
      ],
    );

    await tester.tap(find.byTooltip('Play voice message'));
    await tester.pumpAndSettle();

    expect(uploads.downloaded, ['voice-1']);
    expect(speaker.played, ['voice-1']);
    expect(find.byTooltip('Pause'), findsOne);
  });

  test('durations read like a clock', () {
    expect(formatVoiceDuration(const Duration(seconds: 7)), '0:07');
    expect(formatVoiceDuration(const Duration(seconds: 102)), '1:42');
  });
}

class _Mic implements VoiceRecorder {
  _Mic({this.allowed = true, this.duration = const Duration(seconds: 4)});

  final bool allowed;
  final Duration duration;
  final bytes = Uint8List.fromList([0, 0, 0, 24, 102, 116, 121, 112]);
  bool started = false;
  bool cancelled = false;

  @override
  Future<bool> requestPermission() async => allowed;
  @override
  Future<void> start() async => started = true;
  @override
  Future<RecordedVoiceNote?> stop() async =>
      RecordedVoiceNote(bytes: bytes, duration: duration);
  @override
  Future<void> cancel() async => cancelled = true;
  @override
  Future<void> dispose() async {}
}

class _Speaker implements VoicePlayer {
  final played = <String>[];
  final _states = StreamController<VoicePlayback?>.broadcast();

  @override
  Stream<VoicePlayback?> get playback => _states.stream;
  @override
  Future<void> play(String key, Uint8List bytes) async {
    played.add(key);
    _states.add(
      VoicePlayback(
        key: key,
        playing: true,
        position: Duration.zero,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Future<void> pause() async {}
  @override
  Future<void> dispose() => _states.close();
}

class _Uploads implements FileUploadRepository {
  final commands = <FileUploadCommand>[];
  final downloaded = <String>[];

  @override
  Future<QuarantinedFile> upload(FileUploadCommand command) async {
    commands.add(command);
    return QuarantinedFile(
      id: 'file-${commands.length}',
      uploadId: 'upload-${commands.length}',
      displayName: command.displayName,
      sizeBytes: command.bytes.length,
      scanState: 'pending',
    );
  }

  @override
  Future<DownloadedFile> download(String fileId) async {
    downloaded.add(fileId);
    return DownloadedFile(
      displayName: 'Voice message',
      mediaType: 'audio/mp4',
      bytes: Uint8List.fromList([1, 2, 3]),
    );
  }

  @override
  Future<String> publishToClass({
    required String fileId,
    required FileAudience audience,
  }) => throw UnimplementedError();
}

class _Chat implements MessagingRepository, SafetyRepository {
  _Chat(this.history);

  final List<ChatMessage> history;
  final sent = <({String body, List<String> fileIds})>[];

  @override
  Future<MessagePage> messages(String conversationId, {String? cursor}) async =>
      MessagePage(items: history);

  @override
  Future<ChatMessage> send(
    String conversationId,
    String body, {
    required String clientMessageId,
    List<String> attachmentFileIds = const [],
  }) async {
    sent.add((body: body, fileIds: attachmentFileIds));
    return ChatMessage(
      id: clientMessageId,
      conversationId: conversationId,
      senderId: _me,
      body: body,
      createdAt: DateTime(2026, 9, 28, 11),
      attachments: [
        for (final id in attachmentFileIds)
          StoredAttachment(
            id: id,
            displayName: 'Voice message',
            sizeBytes: 8,
            scanState: 'pending',
            mediaType: 'audio/mp4',
          ),
      ],
    );
  }

  @override
  Future<List<BlockedPerson>> blocks(String schoolId) async => const [];
  @override
  Future<void> markRead(String conversationId) async {}
  @override
  Future<void> acknowledgeDelivery() async {}
  @override
  Future<bool> messagingEnabled(String schoolId) async => true;
  @override
  Future<List<Conversation>> conversations() async => [_conversation];
  @override
  Future<void> createAnnouncement(AnnouncementDraft draft) async {}
  @override
  Future<List<Announcement>> announcements({String? classroomId}) async =>
      const [];
  @override
  Future<List<MessagingContact>> contacts(String schoolId) async => const [];
  @override
  Future<Conversation> startConversation({
    required String schoolId,
    required List<String> participantIds,
    String? subject,
  }) async => _conversation;
  @override
  Future<void> report({
    required String schoolId,
    required ReportTarget target,
    required String details,
    String? messageId,
    String? conversationId,
    String? subjectUserId,
    required bool contactConsent,
  }) async {}
  @override
  Future<BlockedPerson> block({
    required String schoolId,
    required String userId,
  }) => throw UnimplementedError();
  @override
  Future<void> unblock(String blockId) async {}
}
