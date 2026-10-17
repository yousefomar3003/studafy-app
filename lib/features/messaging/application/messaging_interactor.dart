import 'dart:math';

import '../../../core/failures.dart';
import '../../../core/idempotency.dart';
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

  /// Tells the server I have opened [conversationId], so the sender's ticks
  /// turn blue. A failure changes nothing on screen and is not reported.
  Future<Result<void>> markRead(String conversationId) =>
      runCatching(() => messaging.markRead(conversationId));

  /// Tells the server my app has my conversations, so senders see two ticks.
  Future<Result<void>> acknowledgeDelivery() =>
      runCatching(messaging.acknowledgeDelivery);

  /// A voice note would not play. Only [code] is recorded - a platform
  /// error code or the kind of failure, never a message, path or note id.
  void voiceNotePlaybackFailed(String code) =>
      telemetry.event('voice_note_playback_failed', {'code': code});

  /// A fresh id per compose; pass the same id again to retry that message.
  String newClientMessageId() => generateUuidV4(random: _random);

  Future<Result<ChatMessage>> send(
    String conversationId,
    String body, {
    required String clientMessageId,
    List<String> attachmentFileIds = const [],
  }) {
    final trimmed = body.trim();
    // A voice note - or any attachment - needs no text of its own.
    if (trimmed.isEmpty && attachmentFileIds.isEmpty) {
      return Future.value(
        const Result.failure(Failure.validation('Write a message first.')),
      );
    }
    return runCatching(() async {
      final message = await messaging.send(
        conversationId,
        trimmed,
        clientMessageId: clientMessageId,
        attachmentFileIds: attachmentFileIds,
      );
      telemetry.event('message_sent', const {});
      return message;
    });
  }

  Future<Result<void>> postAnnouncement(AnnouncementDraft draft) =>
      runCatching(() async {
        await messaging.createAnnouncement(draft);
        telemetry.event('announcement_posted', {
          'audience': draft.audience.name,
          'important': draft.important,
          'classroom_scoped': draft.classroomId != null,
        });
      });

  Future<Result<List<Announcement>>> announcements({
    String? schoolId,
    String? classroomId,
  }) => runCatching(
    () => messaging.announcements(schoolId: schoolId, classroomId: classroomId),
  );

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
