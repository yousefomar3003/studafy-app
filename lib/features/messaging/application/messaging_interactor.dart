import 'dart:math';

import '../../../core/failures.dart';
import '../../../core/result.dart';
import '../../../core/telemetry.dart';
import '../domain/messaging.dart';

/// Messaging use cases. Presentation calls this, never a repository or the
/// transport directly (ARC-011). Telemetry records counts and outcomes only:
/// no message text, names or identifiers of minors ever reach it.
class MessagingInteractor {
  MessagingInteractor({
    required this.messaging,
    required this.safety,
    required this.telemetry,
    Random? random,
  }) : _random = random ?? Random.secure();

  final MessagingRepository messaging;
  final SafetyRepository safety;
  final Telemetry telemetry;
  final Random _random;

  Future<Result<bool>> messagingEnabled(String schoolId) =>
      runCatching(() => messaging.messagingEnabled(schoolId));

  Future<Result<List<Conversation>>> conversations() =>
      runCatching(messaging.conversations);

  Future<Result<MessagePage>> messages(
    String conversationId, {
    String? cursor,
  }) => runCatching(() => messaging.messages(conversationId, cursor: cursor));

  /// A fresh id per compose; pass the same id again to retry that message.
  String newClientMessageId() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  Future<Result<ChatMessage>> send(
    String conversationId,
    String body, {
    required String clientMessageId,
  }) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) {
      return Future.value(
        const Result.failure(Failure.validation('Write a message first.')),
      );
    }
    return runCatching(() async {
      final message = await messaging.send(
        conversationId,
        trimmed,
        clientMessageId: clientMessageId,
      );
      telemetry.event('message_sent', const {});
      return message;
    });
  }

  Future<Result<List<MessagingContact>>> contacts(String schoolId) =>
      runCatching(() => messaging.contacts(schoolId));

  Future<Result<Conversation>> startConversation({
    required String schoolId,
    required List<String> participantIds,
    String? subject,
  }) => runCatching(() async {
    final conversation = await messaging.startConversation(
      schoolId: schoolId,
      participantIds: participantIds,
      subject: subject,
    );
    telemetry.event('conversation_started', {
      'participants': participantIds.length,
    });
    return conversation;
  });

  /// Files a report. [reasonLabel] is the chosen reason in the reporter's
  /// language and leads the text the school's moderators read.
  Future<Result<void>> report({
    required String schoolId,
    required ReportTarget target,
    required String reasonLabel,
    required String details,
    String? messageId,
    String? conversationId,
    String? subjectUserId,
    required bool contactConsent,
  }) {
    final text = details.trim().isEmpty
        ? reasonLabel
        : '$reasonLabel: ${details.trim()}';
    // The server requires at least ten characters of explanation.
    final padded = text.length >= 10 ? text : text.padRight(10, '.');
    return runCatching(() async {
      await safety.report(
        schoolId: schoolId,
        target: target,
        details: padded,
        messageId: messageId,
        conversationId: conversationId,
        subjectUserId: subjectUserId,
        contactConsent: contactConsent,
      );
      telemetry.event('safety_report_filed', {'target': target.name});
    });
  }

  Future<Result<BlockedPerson>> block({
    required String schoolId,
    required String userId,
  }) => runCatching(() async {
    final blocked = await safety.block(schoolId: schoolId, userId: userId);
    telemetry.event('user_blocked', const {});
    return blocked;
  });

  Future<Result<void>> unblock(String blockId) => runCatching(() async {
    await safety.unblock(blockId);
    telemetry.event('user_unblocked', const {});
  });

  Future<Result<List<BlockedPerson>>> blocks(String schoolId) =>
      runCatching(() => safety.blocks(schoolId));
}
