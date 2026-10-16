import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/core/attachment_field.dart';
import 'package:studafy/core/file_upload_repository.dart';
import 'package:studafy/core/telemetry.dart';
import 'package:studafy/core/uploads_scope.dart';
import 'package:studafy/data/contracts/v1_client.generated.dart';
import 'package:studafy/data/contracts/v1_http_transport.dart';
import 'package:studafy/features/messaging/application/messaging_interactor.dart';
import 'package:studafy/features/messaging/data/api_messaging_repository.dart';
import 'package:studafy/features/messaging/domain/messaging.dart';
import 'package:studafy/features/messaging/presentation/conversation_page.dart';
import 'package:studafy/features/messaging/presentation/create_announcement_page.dart';
import 'package:studafy/features/messaging/presentation/messaging_scope.dart';

import '../../support/localized_app.dart';

/// A file the scan refused is not sent with a message or posted with an
/// announcement: the server refuses it by name (2026-10-15), nothing is
/// sent, and the composer marks the file so the rest can go once it is
/// taken off. A file refused after it was sent says so in the chat.
const _me = 'user-me';
const _refusedText =
    'This file did not pass the safety check. Remove it, then save again.';
const _notSent =
    'A file was not accepted, so nothing was sent. Remove the file marked, '
    'then try again.';

final _conversation = Conversation(
  id: 'conversation-1',
  schoolId: 'school-1',
  updatedAt: DateTime(2026, 10, 15, 10),
  lastReadAt: DateTime(2026, 10, 15, 10),
  participants: const [
    ConversationParticipant(
      userId: _me,
      displayName: 'Rana',
      role: MessagingRole.staff,
    ),
    ConversationParticipant(
      userId: 'user-parent',
      displayName: 'Nadia',
      role: MessagingRole.guardian,
    ),
  ],
);

PickedAttachment _pdf(String name) => PickedAttachment(
  displayName: name,
  mediaType: 'application/pdf',
  bytes: Uint8List.fromList([1, 2, 3, 4]),
);

void main() {
  testWidgets(
    'a message with a refused file is not sent, the file is marked, and the '
    'message goes once it is taken off',
    (tester) async {
      final names = ['notes.pdf', 'scan.pdf'];
      final chat = _Chat()
        ..failures.add(
          const AttachmentRefusedFailure({
            'attachmentFileIds.1': 'file_refused',
          }),
        );
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
            uploads: _Uploads(),
            refreshEvery: const Duration(days: 1),
            attachmentSource: (_, _) async => _pdf(names.removeAt(0)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (var i = 0; i < 2; i++) {
        await tester.tap(find.byTooltip('Attach'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Document'));
        await tester.pumpAndSettle();
      }

      await tester.tap(find.byTooltip('Send'));
      await tester.pumpAndSettle();
      expect(chat.sent.single.fileIds, ['file-1', 'file-2']);
      expect(chat.delivered, isEmpty);
      expect(find.text(_notSent), findsOne);
      expect(find.text(_refusedText), findsOne);

      // Sent again, the refused file stays behind.
      await tester.tap(find.byTooltip('Send'));
      await tester.pumpAndSettle();
      expect(chat.sent.last.fileIds, ['file-1']);
      expect(chat.delivered, hasLength(1));
      // A refusal is a new message, never a replay of the refused one.
      expect(chat.sent.last.clientId, isNot(chat.sent.first.clientId));
    },
  );

  testWidgets('a file the scan removed after it was sent says so in the chat', (
    tester,
  ) async {
    final chat = _Chat(
      history: [
        ChatMessage(
          id: 'm1',
          conversationId: _conversation.id,
          senderId: 'user-parent',
          body: 'Here it is',
          createdAt: DateTime(2026, 10, 15, 9),
          attachments: const [
            StoredAttachment(
              id: 'f1',
              displayName: 'homework.pdf',
              sizeBytes: 10,
              scanState: 'rejected',
              mediaType: 'application/pdf',
            ),
            StoredAttachment(
              id: 'f2',
              displayName: 'photo.jpg',
              sizeBytes: 10,
              scanState: 'deleted',
              mediaType: 'image/jpeg',
            ),
            StoredAttachment(
              id: 'f3',
              displayName: 'Voice message',
              sizeBytes: 10,
              scanState: 'error',
              mediaType: 'audio/mp4',
            ),
          ],
        ),
      ],
    );
    final uploads = _Uploads();
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
          refreshEvery: const Duration(days: 1),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Removed by the safety check'), findsOne);
    // The photo and the voice note, each in place.
    expect(
      find.text('This file was removed by the safety check.'),
      findsNWidgets(2),
    );
    expect(find.text('This file is still being checked.'), findsNothing);
    expect(find.text('Checking voice message…'), findsNothing);

    await tester.tap(find.text('homework.pdf'));
    await tester.pump();
    expect(
      find.text('This file was removed by the safety check.'),
      findsNWidgets(3),
    );
    // Nothing is fetched for a removed file.
    expect(uploads.downloaded, isEmpty);
  });

  testWidgets('an announcement with a refused file is not posted, and the '
      'file is marked', (tester) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final chat = _Chat()
      ..failures.add(
        const AttachmentRefusedFailure({'attachmentFileIds.0': 'file_refused'}),
      );
    await tester.pumpWidget(
      localizedApp(
        scopes: (child) => UploadsScope(uploads: _Uploads(), child: child),
        home: CreateAnnouncementPage(
          messaging: MessagingInteractor(
            messaging: chat,
            safety: chat,
            telemetry: const NoopTelemetry(),
          ),
          schoolId: 'school-1',
          classes: const [AnnouncementTarget(id: 'c1', name: 'Grade 7')],
          attachmentSource: (_, _) async => _pdf('trip.pdf'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'Trip');
    await tester.enterText(find.byType(TextField).at(1), 'Details attached.');
    await tester.tap(find.byIcon(Icons.attach_file_rounded));
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.widgetWithText(FilledButton, 'Post announcement'),
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Post announcement'));
    await tester.pumpAndSettle();
    expect(chat.posted.single.attachmentFileIds, ['file-1']);
    expect(find.text(_notSent), findsOne);
    expect(find.text(_refusedText), findsOne);

    await tester.ensureVisible(
      find.widgetWithText(FilledButton, 'Post announcement'),
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Post announcement'));
    await tester.pumpAndSettle();
    expect(chat.posted.last.attachmentFileIds, isEmpty);
  });

  test(
    'the API refusal reaches the composer with the files it names',
    () async {
      final repository = ApiMessagingRepository(
        V1ApiClient(
          _Refusing(
            const V1ApiException(
              status: 422,
              code: 'ATTACHMENT_REFUSED',
              message: 'An attachment was refused',
              fieldErrors: {'attachmentFileIds.1': 'file_refused'},
            ),
          ),
        ),
      );
      await expectLater(
        repository.send(
          'conversation-1',
          'Hi',
          clientMessageId: '5f450000-0000-4000-8000-0000000000d9',
          attachmentFileIds: const ['a', 'b'],
        ),
        throwsA(
          isA<AttachmentRefusedFailure>().having((f) => f.rows, 'rows', {
            'attachmentFileIds.1': 'file_refused',
          }),
        ),
      );
    },
  );
}

class _Refusing implements V1JsonTransport {
  _Refusing(this.failure);

  final V1ApiException failure;

  @override
  Future<Map<String, dynamic>> get(String path) async => throw failure;

  @override
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, Object?> body, {
    String? idempotencyKey,
    bool requiresIdempotency = false,
  }) async => throw failure;
}

class _Uploads implements FileUploadRepository {
  var _count = 0;
  final downloaded = <String>[];

  @override
  Future<QuarantinedFile> upload(FileUploadCommand command) async {
    _count++;
    return QuarantinedFile(
      id: 'file-$_count',
      uploadId: 'upload-$_count',
      displayName: command.displayName,
      sizeBytes: command.bytes.length,
      scanState: 'clean',
    );
  }

  @override
  Future<DownloadedFile> download(String fileId) async {
    downloaded.add(fileId);
    throw UnimplementedError();
  }

  @override
  Future<String> publishToClass({
    required String fileId,
    required FileAudience audience,
  }) => throw UnimplementedError();
}

class _Chat implements MessagingRepository, SafetyRepository {
  _Chat({this.history = const []});

  final List<ChatMessage> history;

  /// Thrown, in order, by the next sends and posts.
  final failures = <Object>[];
  final sent = <({String clientId, List<String> fileIds})>[];
  final delivered = <String>[];
  final posted = <AnnouncementDraft>[];

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
    sent.add((clientId: clientMessageId, fileIds: attachmentFileIds));
    if (failures.isNotEmpty) throw failures.removeAt(0);
    delivered.add(clientMessageId);
    return ChatMessage(
      id: clientMessageId,
      conversationId: conversationId,
      senderId: _me,
      body: body,
      createdAt: DateTime(2026, 10, 15, 11),
    );
  }

  @override
  Future<void> createAnnouncement(AnnouncementDraft draft) async {
    posted.add(draft);
    if (failures.isNotEmpty) throw failures.removeAt(0);
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
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
