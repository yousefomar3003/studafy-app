import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/core/attachment_field.dart';
import 'package:studafy/core/coursework_attachments.dart';
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
    _Speaker? player,
    Telemetry telemetry = const NoopTelemetry(),
    AttachmentSource? attachmentSource,
  }) async {
    final chat = _Chat(history);
    final uploads = _Uploads();
    final microphone = mic ?? _Mic();
    final speaker = player ?? _Speaker();
    await tester.pumpWidget(
      localizedApp(
        scopes: (child) => MessagingScope(
          interactor: MessagingInteractor(
            messaging: chat,
            safety: chat,
            telemetry: telemetry,
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
          attachmentSource: attachmentSource,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (chat, uploads, microphone, speaker);
  }

  testWidgets('one attach button beside the input opens photo or file', (
    tester,
  ) async {
    final picked = <AttachmentKind>[];
    final (chat, uploads, _, _) = await open(
      tester,
      attachmentSource: (kind, _) async {
        picked.add(kind);
        return PickedAttachment(
          displayName: 'worksheet.pdf',
          mediaType: 'application/pdf',
          bytes: Uint8List.fromList([1, 2, 3, 4]),
        );
      },
    );
    // No separate "Attach file" and "Photo" buttons above the input.
    expect(find.text('Attach file'), findsNothing);

    await tester.tap(find.byTooltip('Attach'));
    await tester.pumpAndSettle();
    expect(find.text('Photo'), findsOne);
    expect(find.text('Camera'), findsOne);
    await tester.tap(find.text('Document'));
    await tester.pumpAndSettle();

    // The file waits above the input, removable, until the message is sent.
    expect(picked, [AttachmentKind.document]);
    expect(find.text('worksheet.pdf'), findsOne);
    expect(find.byTooltip('Send'), findsOne);
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();
    expect(chat.sent.single.fileIds, ['file-1']);
    expect(find.text('worksheet.pdf'), findsNothing);
    expect(uploads.commands.single.purpose, FilePurpose.messageAttachment);
  });

  testWidgets('an attachment can be taken back out before sending', (
    tester,
  ) async {
    final (chat, _, _, _) = await open(
      tester,
      attachmentSource: (kind, _) async => PickedAttachment(
        displayName: 'photo.jpg',
        mediaType: 'image/jpeg',
        bytes: Uint8List.fromList([1, 2, 3]),
      ),
    );
    await tester.tap(find.byTooltip('Attach'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Photo'));
    await tester.pumpAndSettle();
    expect(find.text('photo.jpg'), findsOne);

    await tester.tap(find.byTooltip('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('photo.jpg'), findsNothing);
    // Nothing to send any more: the microphone is back.
    expect(find.byTooltip('Record a voice note'), findsOne);
    expect(chat.sent, isEmpty);
  });

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
    final (chat, uploads, mic, speaker) = await open(tester);

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
    // Still being checked on the server, but the sender plays their own
    // recording from this phone at once - nothing is fetched for it.
    expect(find.text('Checking voice message…'), findsNothing);
    await tester.tap(find.byTooltip('Play voice message'));
    await tester.pumpAndSettle();
    expect(speaker.played, ['file-1']);
    expect(uploads.downloaded, isEmpty);
  });

  testWidgets("someone else's note still waits for the check", (tester) async {
    await open(
      tester,
      history: [
        ChatMessage(
          id: 'm1',
          conversationId: 'conversation-1',
          senderId: _teacher,
          body: '',
          createdAt: DateTime(2026, 9, 28, 10, 30),
          attachments: const [
            StoredAttachment(
              id: 'voice-1',
              displayName: 'Voice message',
              sizeBytes: 8,
              scanState: 'quarantined',
              mediaType: 'audio/mp4',
            ),
          ],
        ),
      ],
    );
    expect(find.text('Checking voice message…'), findsOne);
    expect(find.byTooltip('Play voice message'), findsNothing);
  });

  testWidgets('a photo in a message is shown as the photo, not a file row', (
    tester,
  ) async {
    final (_, uploads, _, _) = await open(
      tester,
      history: [
        ChatMessage(
          id: 'm1',
          conversationId: 'conversation-1',
          senderId: _teacher,
          body: 'Here is the board: www.example.com/board',
          createdAt: DateTime(2026, 9, 28, 10, 30),
          attachments: const [
            StoredAttachment(
              id: 'photo-1',
              displayName: 'image_picker_ABC.jpg',
              sizeBytes: 8,
              scanState: 'clean',
              mediaType: 'image/jpeg',
            ),
          ],
        ),
      ],
    );
    await tester.pumpAndSettle();
    expect(find.byType(AttachmentImage), findsOne);
    // Fetched to show it, and not listed by its file name as well.
    expect(uploads.downloaded, ['photo-1']);
    expect(find.text('image_picker_ABC.jpg'), findsNothing);
    // The link in the text is a link.
    await tester.tapOnText(find.textRange.ofSubstring('www.example.com/board'));
    await tester.pumpAndSettle();
    expect(find.text('Open this link?'), findsOne);
  });

  testWidgets('a photo sent on its own has no bubble around it', (
    tester,
  ) async {
    await open(
      tester,
      history: [
        ChatMessage(
          id: 'm1',
          conversationId: 'conversation-1',
          senderId: _me,
          body: '',
          createdAt: DateTime(2026, 9, 28, 10, 30),
          attachments: const [
            StoredAttachment(
              id: 'photo-1',
              displayName: 'image_picker_ABC.jpg',
              sizeBytes: 8,
              scanState: 'clean',
              mediaType: 'image/jpeg',
            ),
          ],
        ),
      ],
    );
    final framed = find.ancestor(
      of: find.byType(AttachmentImage),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.decoration is BoxDecoration &&
            (widget.decoration! as BoxDecoration).gradient != null,
      ),
    );
    expect(find.byType(AttachmentImage), findsOne);
    expect(framed, findsNothing);
  });

  testWidgets('a photo on its own is announced as a photo', (tester) async {
    final semantics = tester.ensureSemantics();
    await open(
      tester,
      history: [
        ChatMessage(
          id: 'm1',
          conversationId: 'conversation-1',
          senderId: _me,
          body: '',
          createdAt: DateTime(2026, 9, 28, 10, 30),
          attachments: const [
            StoredAttachment(
              id: 'photo-1',
              displayName: 'Photo 2026-09-28 10.29.jpg',
              sizeBytes: 8,
              scanState: 'clean',
              mediaType: 'image/jpeg',
            ),
          ],
        ),
        ChatMessage(
          id: 'm2',
          conversationId: 'conversation-1',
          senderId: _teacher,
          body: '',
          createdAt: DateTime(2026, 9, 28, 10, 20),
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
    expect(find.bySemanticsLabel(RegExp(r'^You: Photo\b')), findsOne);
    expect(find.bySemanticsLabel(RegExp(r'^You: Voice message')), findsNothing);
    expect(find.bySemanticsLabel(RegExp(r'^Rana: Voice message')), findsOne);
    semantics.dispose();
  });

  testWidgets('a voice note that failed to send is sent again as it is', (
    tester,
  ) async {
    final (chat, uploads, mic, _) = await open(tester);
    uploads.failures.add(StateError('connection dropped'));

    await tester.tap(find.byTooltip('Record a voice note'));
    await tester.pump();
    await tester.tap(find.byTooltip('Send voice note'));
    await tester.pumpAndSettle();
    expect(
      find.text('The voice note could not be sent. Please try again.'),
      findsOne,
    );
    expect(chat.sent, isEmpty);

    // No second recording: the same note goes again.
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(uploads.commands, hasLength(2));
    expect(uploads.commands.last.bytes, mic.bytes);
    expect(chat.sent.single.fileIds, ['file-2']);
    expect(find.text('Try again'), findsNothing);
  });

  testWidgets('a server with uploads switched off says so, not "try again"', (
    tester,
  ) async {
    final (chat, uploads, _, _) = await open(tester);
    uploads.failures.add(const FileServiceUnavailable());

    await tester.tap(find.byTooltip('Record a voice note'));
    await tester.pump();
    await tester.tap(find.byTooltip('Send voice note'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        "Attachments and voice notes aren't switched on for your school yet.",
      ),
      findsOne,
    );
    expect(find.text('Try again'), findsNothing);
    expect(chat.sent, isEmpty);
  });

  testWidgets('a file that failed to upload can be tried again', (
    tester,
  ) async {
    final (chat, uploads, _, _) = await open(
      tester,
      attachmentSource: (_, _) async => PickedAttachment(
        displayName: 'worksheet.pdf',
        mediaType: 'application/pdf',
        bytes: Uint8List.fromList([1, 2, 3, 4]),
      ),
    );
    uploads.failures.add(StateError('connection dropped'));

    await tester.tap(find.byTooltip('Attach'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Document'));
    await tester.pumpAndSettle();
    // Said on the file's own row, not in a snackbar over the send button.
    expect(find.text('That file could not be uploaded.'), findsOne);

    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(uploads.commands, hasLength(2));
    // The same attempt, so the server never keeps two copies.
    expect(uploads.commands.first.attemptId, uploads.commands.last.attemptId);
    expect(find.text('That file could not be uploaded.'), findsNothing);

    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();
    expect(chat.sent.single.fileIds, ['file-2']);
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

  final teacherNote = ChatMessage(
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
  );

  testWidgets('a note that will not play says so, and the failure is logged', (
    tester,
  ) async {
    final telemetry = _Telemetry();
    await open(
      tester,
      history: [teacherNote],
      telemetry: telemetry,
      player: _Speaker(
        failure: PlatformException(code: 'AndroidAudioError', message: 'x'),
      ),
    );

    await tester.tap(find.byTooltip('Play voice message'));
    await tester.pumpAndSettle();

    expect(find.text("Couldn't play this voice note."), findsOne);
    expect(find.byTooltip('Play voice message'), findsOne);
    expect(telemetry.events.single.$1, 'voice_note_playback_failed');
    expect(telemetry.events.single.$2, {'code': 'platform:AndroidAudioError'});
  });

  testWidgets('a note that fails once playing says so too', (tester) async {
    final telemetry = _Telemetry();
    final speaker = _Speaker();
    await open(
      tester,
      history: [teacherNote],
      telemetry: telemetry,
      player: speaker,
    );
    await tester.tap(find.byTooltip('Play voice message'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Pause'), findsOne);

    speaker.stall();
    await tester.pumpAndSettle();

    expect(find.text("Couldn't play this voice note."), findsOne);
    expect(find.byTooltip('Play voice message'), findsOne);
    expect(telemetry.events.single.$2, {'code': 'stalled'});
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
  _Speaker({this.failure});

  /// Thrown by [play], as a player that cannot start the note would.
  final Object? failure;
  final played = <String>[];
  final _states = StreamController<VoicePlayback?>.broadcast();
  String? _key;

  /// The note being played stops getting anywhere, as the player reports.
  void stall() {
    _states
      ..add(
        VoicePlayback(
          key: _key!,
          playing: false,
          position: Duration.zero,
          duration: const Duration(seconds: 4),
        ),
      )
      ..addError(const VoicePlaybackStalled());
  }

  @override
  Stream<VoicePlayback?> get playback => _states.stream;
  @override
  Future<void> play(String key, Uint8List bytes) async {
    played.add(key);
    _key = key;
    if (failure case final failure?) throw failure;
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

class _Telemetry implements Telemetry {
  final events = <(String, Map<String, Object?>)>[];

  @override
  void event(String name, [Map<String, Object?> fields = const {}]) =>
      events.add((name, fields));
}

class _Uploads implements FileUploadRepository {
  final commands = <FileUploadCommand>[];
  final downloaded = <String>[];

  /// Thrown, in order, by the next uploads.
  final failures = <Object>[];

  @override
  Future<QuarantinedFile> upload(FileUploadCommand command) async {
    commands.add(command);
    if (failures.isNotEmpty) throw failures.removeAt(0);
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
  Future<List<Announcement>> announcements({
    String? schoolId,
    String? classroomId,
  }) async => const [];
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
