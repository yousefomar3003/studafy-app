import 'dart:io';

import '../../../core/failures.dart';
import '../../../data/contracts/v1_client.generated.dart';
import '../../../data/contracts/v1_http_transport.dart';
import '../domain/messaging.dart';

/// Server error codes the messaging screens explain in their own words.
/// Anything else becomes a generic failure, never raw server text.
const messagingFailureCodes = <String>{
  'MESSAGING_DISABLED',
  'CONTACT_NOT_ALLOWED',
  'FORBIDDEN',
  'NOT_FOUND',
  'INVALID_STATE',
  'WINDOW_CLOSED',
  'RATE_LIMITED',
};

Future<T> _guard<T>(Future<T> Function() action) async {
  try {
    return await action();
  } on V1ApiException catch (error) {
    if (error.isUnauthenticated) throw Failure.unauthorized;
    if (messagingFailureCodes.contains(error.code)) {
      throw Failure(error.code, error.code);
    }
    throw Failure.unknown;
  } on SocketException {
    throw Failure.network;
  } on HttpException {
    throw Failure.network;
  }
}

/// Authoritative `/v1` conversations, contacts, reports and blocks. Online
/// only by design: a message is never shown as sent until the server has
/// accepted it, and the client message id makes a retry land exactly once.
class ApiMessagingRepository implements MessagingRepository, SafetyRepository {
  ApiMessagingRepository(this._client);

  final V1ApiClient _client;

  @override
  Future<bool> messagingEnabled(String schoolId) => _guard(() async {
    final controls = await _client.getContentControls(schoolId: schoolId);
    return controls.messagingEnabled;
  });

  @override
  Future<List<Conversation>> conversations() => _guard(() async {
    final page = await _client.listConversations(pageSize: 100);
    return [for (final item in page.items) _conversation(item)];
  });

  @override
  Future<MessagePage> messages(String conversationId, {String? cursor}) =>
      _guard(() async {
        final page = await _client.listMessages(
          conversationId: conversationId,
          cursor: cursor,
          pageSize: 30,
        );
        return MessagePage(
          items: [for (final item in page.items) _message(item)],
          nextCursor: page.nextCursor,
        );
      });

  @override
  Future<ChatMessage> send(
    String conversationId,
    String body, {
    required String clientMessageId,
  }) => _guard(() async {
    final message = await _client.sendMessage(
      V1SendMessageRequestDto(clientMessageId: clientMessageId, body: body),
      conversationId: conversationId,
      // The client message id doubles as the idempotency key, so a retry
      // after a dropped response replays instead of posting twice.
      idempotencyKey: 'message:$clientMessageId',
    );
    return _message(message);
  });

  @override
  Future<List<MessagingContact>> contacts(String schoolId) => _guard(() async {
    final page = await _client.listContacts(schoolId: schoolId, pageSize: 100);
    return [
      for (final item in page.items)
        MessagingContact(
          userId: item.userId,
          displayName: item.displayName,
          role: messagingRoleFromWire(item.role),
          relatedStudentNames: item.relatedStudentNames,
        ),
    ];
  });

  @override
  Future<Conversation> startConversation({
    required String schoolId,
    required List<String> participantIds,
    String? subject,
  }) => _guard(() async {
    final created = await _client.createConversation(
      V1CreateConversationRequestDto(
        schoolId: schoolId,
        subject: subject == null || subject.trim().isEmpty
            ? null
            : subject.trim(),
        participantIds: participantIds,
      ),
    );
    return _conversation(created);
  });

  @override
  Future<void> report({
    required String schoolId,
    required ReportTarget target,
    required String details,
    String? messageId,
    String? conversationId,
    String? subjectUserId,
    required bool contactConsent,
  }) => _guard(() async {
    await _client.createReport(
      V1CreateReportRequestDto(
        schoolId: schoolId,
        kind: target.name,
        details: details,
        messageId: messageId,
        conversationId: conversationId,
        subjectUserId: subjectUserId,
        contactConsent: contactConsent,
      ),
    );
  });

  @override
  Future<BlockedPerson> block({
    required String schoolId,
    required String userId,
  }) => _guard(() async {
    final block = await _client.createBlock(
      V1CreateBlockRequestDto(
        schoolId: schoolId,
        blockedUserId: userId,
        scope: 'messages',
      ),
    );
    return _blocked(block);
  });

  @override
  Future<void> unblock(String blockId) => _guard(() async {
    await _client.unblockUser(
      const V1UnblockUserRequestDto(),
      blockId: blockId,
    );
  });

  @override
  Future<List<BlockedPerson>> blocks(String schoolId) => _guard(() async {
    final page = await _client.listBlocks(schoolId: schoolId, pageSize: 100);
    return [for (final item in page.items) _blocked(item)];
  });

  static Conversation _conversation(V1ConversationDto dto) => Conversation(
    id: dto.id,
    schoolId: dto.schoolId,
    subject: dto.subject,
    updatedAt: DateTime.parse(dto.updatedAt),
    lastReadAt: dto.lastReadAt == null ? null : DateTime.parse(dto.lastReadAt!),
    participants: [
      for (final participant in dto.participants)
        ConversationParticipant(
          userId: participant.userId,
          displayName: participant.displayName,
          role: messagingRoleFromWire(participant.role),
        ),
    ],
  );

  static ChatMessage _message(V1MessageDto dto) => ChatMessage(
    id: dto.id,
    conversationId: dto.conversationId,
    senderId: dto.senderId,
    body: dto.body,
    createdAt: DateTime.parse(dto.createdAt),
  );

  static BlockedPerson _blocked(V1BlockDto dto) => BlockedPerson(
    blockId: dto.id,
    schoolId: dto.schoolId,
    blockerId: dto.blockerId,
    blockedId: dto.blockedId,
    createdAt: DateTime.parse(dto.createdAt),
  );

  @override
  Future<void> createAnnouncement(AnnouncementDraft draft) => _guard(() async {
    await _client.createAnnouncement(
      V1CreateAnnouncementRequestDto(
        schoolId: draft.schoolId,
        classroomId: draft.classroomId,
        title: draft.title,
        body: draft.body,
        audience: draft.audience.name,
        important: draft.important,
      ),
      idempotencyKey: 'announcement-${DateTime.now().microsecondsSinceEpoch}'
          .hashCode
          .abs()
          .toRadixString(36)
          .padLeft(16, '0'),
    );
  });

  @override
  Future<List<Announcement>> announcements({String? classroomId}) =>
      _guard(() async {
        final items = <Announcement>[];
        String? cursor;
        do {
          final page = await _client.listAnnouncements(
            classroomId: classroomId,
            cursor: cursor,
            pageSize: 50,
          );
          for (final item in page.items) {
            items.add(
              Announcement(
                id: item.id,
                title: item.title,
                body: item.body,
                important: item.important,
                createdAt:
                    DateTime.tryParse(item.publishedAt)?.toLocal() ??
                    DateTime.now(),
                classroomId: item.classroomId,
              ),
            );
          }
          cursor = page.nextCursor;
        } while (cursor != null);
        return items;
      });
}
